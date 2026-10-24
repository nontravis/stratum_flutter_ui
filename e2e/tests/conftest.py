"""Skip hook and device fixtures for items under tests/ only.

Living here keeps unit/ runnable under any --platform and without a device. In a device round
(`--target` or `--mode`) every fixture here depends on `round_target`, so it re-creates per target,
and the round plugin (`stratum_e2e.round.plugin`) supplies the app and the low-level options; an
Appium server, install, or session failure, a Chrome launch or page failure, or a TalkBack or uhid keyboard setup
failure raises `RoundEnvError`, so the round classes it `env`.
"""

from __future__ import annotations

import contextlib
import re
import subprocess
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterator

import pytest
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.options.common import AppiumOptions
from appium.options.ios import XCUITestOptions
from appium.options.mac import Mac2Options
from playwright.sync_api import Browser, Playwright, sync_playwright
from playwright.sync_api import Error as PlaywrightError
from selenium.common.exceptions import WebDriverException
from urllib3.exceptions import HTTPError

from stratum_e2e.android.session import android_capabilities, install_apk
from stratum_e2e.android.talkback import (
    AVD_NAME,
    TalkBackLog,
    TalkBackSession,
    TalkBackSilent,
    TalkBackStuck,
    avd_name,
)
from stratum_e2e.android.uhid_keyboard import UhidKeyboard
from stratum_e2e.appium_server import AppiumServer, AppiumStartError
from stratum_e2e.ios.session import WDA_DERIVED_DATA, install_app, ios_capabilities
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.macos.session import mac_capabilities
from stratum_e2e.ports import free_port
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.plugin import ROUND_KEY, RoundTarget, item_target
from stratum_e2e.round.runner import Runner
from stratum_e2e.selection import skip_reason
from stratum_e2e.web.server import StaticServer

TESTS_DIR = Path(__file__).resolve().parent
_CONSOLE_LOCKED = re.compile(r'"CGSSessionScreenIsLocked"\s*=\s*Yes')
_IOREG_TIMEOUT_S = 30.0


def _required_option(config: pytest.Config, name: str) -> str:
    value = config.getoption(name)
    if value is None:
        pytest.fail(f"--{name.replace('_', '-')} is required for this test", pytrace=False)
    return str(value)


@pytest.fixture(scope="session")
def platform(request: pytest.FixtureRequest, round_target: RoundTarget | None) -> str:
    """The --platform leg this session runs; in a round, the target's (round_target re-creates it per target)."""
    return _required_option(request.config, "platform")


@pytest.fixture(scope="session")
def app_id(request: pytest.FixtureRequest, round_target: RoundTarget | None) -> str:
    """The --app-id of the app under test; in a round, the target's unless given."""
    return _required_option(request.config, "app_id")


@dataclass
class _Installs:
    """The (device, app) pairs installed so far, and outside a round the failed install of each pair."""

    done: set[tuple[str, Path]] = field(default_factory=set)
    failed: dict[tuple[str, Path], RoundEnvError] = field(default_factory=dict)


@pytest.fixture(scope="session")
def _installs(round_target: RoundTarget | None) -> _Installs:
    """The installs tried so far; per target in a round, since a later emulator can reuse a serial."""
    return _Installs()


@pytest.fixture
def installed_app(request: pytest.FixtureRequest, platform: str, round_app: Path, _installs: _Installs) -> None:
    """Install the app under test on --device once per (device, app) pair.

    A streamed `install -r` of a debug APK plus Flutter's asset copy after it filled a 5.8 GB
    /data within 8 tests, and with `noReset` a reinstall per test buys no isolation. In a round a
    failed install is not remembered, so the round's re-run of the item installs again; outside a
    round every later item raises it at once, so a full device is never streamed to again.
    """
    if platform == "macos":
        return  # Mac2 launches the app bundle itself through `appPath`
    device = _required_option(request.config, "device")
    pair = (device, round_app)
    if pair in _installs.done:
        return
    if pair in _installs.failed:
        raise _installs.failed[pair]
    if platform not in ("android", "ios"):
        pytest.fail(f"no driver for platform {platform!r} yet", pytrace=False)
    try:
        if platform == "android":
            install_apk(device, round_app)
        else:
            install_app(device, round_app)
    except (subprocess.CalledProcessError, OSError) as error:
        failure = RoundEnvError(f"app install on {device} failed: {error}")
        if request.config.stash.get(ROUND_KEY, None) is None:
            _installs.failed[pair] = failure
        raise failure from error
    _installs.done.add(pair)


def _session_options(config: pytest.Config, platform: str, app_id: str, app: Path) -> AppiumOptions:
    """Return the Appium options of the --platform leg's session; macOS launches `app` itself."""
    if platform == "macos":
        return Mac2Options().load_capabilities(mac_capabilities(app_id, [], app.resolve()))
    device = _required_option(config, "device")
    if platform == "ios":
        return XCUITestOptions().load_capabilities(
            ios_capabilities(device, app_id, WDA_DERIVED_DATA, free_port())
        )
    return UiAutomator2Options().load_capabilities(android_capabilities(device, app_id))


class _StaticServers:
    """Serves each web build on its own free port from its first use until the session ends."""

    def __init__(self, stack: contextlib.ExitStack) -> None:
        self._stack = stack
        self._servers: dict[Path, StaticServer] = {}

    def serve(self, root: Path) -> StaticServer:
        server = self._servers.get(root)
        if server is None:
            server = self._servers[root] = self._stack.enter_context(StaticServer(root))
        return server


@pytest.fixture(scope="session")
def _static_servers() -> Iterator[_StaticServers]:
    """The session's web build servers; always stopped afterwards."""
    with contextlib.ExitStack() as stack:
        yield _StaticServers(stack)


@pytest.fixture
def static_server(round_app: Path, _static_servers: _StaticServers) -> StaticServer:
    """The server of the web build under test, started on first use and kept for the session."""
    return _static_servers.serve(round_app)


@pytest.fixture(scope="session")
def browser(request: pytest.FixtureRequest) -> Iterator[Callable[[], Browser]]:
    """Return the getter of the headless Chrome the web leg drives; it launches on the first call and closes at
    session end.

    A failed launch raises `RoundEnvError`. In a device round the failure is not kept, so the round's re-run of an
    item launches again; outside a round every later call raises it at once.
    """
    in_round = request.config.stash.get(ROUND_KEY, None) is not None
    started: list[Playwright] = []
    launched: list[Browser] = []
    failure: list[RoundEnvError] = []
    with contextlib.ExitStack() as stack:

        def get() -> Browser:
            if failure:
                raise failure[0]
            if not launched:
                try:
                    if not started:
                        started.append(stack.enter_context(sync_playwright()))
                    launched.append(started[0].chromium.launch(channel="chrome", headless=True))
                except PlaywrightError as error:
                    env = RoundEnvError(f"chrome launch failed: {_first_line(str(error))}")
                    if not in_round:
                        failure.append(env)
                    raise env from error
                stack.callback(launched[0].close)
            return launched[0]

        yield get


@pytest.fixture
def driver(request: pytest.FixtureRequest, platform: str, app_id: str) -> Iterator[Any]:
    """The platform leg's handle on --device: an Appium session, or a Playwright `Page` on web.

    An Appium session has --app installed and is quit afterwards. A web `Page` is blank
    until `open_fixture`, resolves relative URLs against the build's server, and is
    closed afterwards.
    """
    if platform == "web":
        launch: Callable[[], Browser] = request.getfixturevalue("browser")
        chrome = launch()
        server = request.getfixturevalue("static_server")
        try:
            page = chrome.new_page(base_url=server.url)
        except PlaywrightError as error:
            raise RoundEnvError(f"chrome page failed: {_first_line(str(error))}") from error
        try:
            yield page
        finally:
            page.close()
        return
    if platform == "macos" and item_target(request.node) is not None:
        _require_unlocked_console(request.getfixturevalue("round_backends").runner)
    appium_server = _appium_server(request)
    request.getfixturevalue("installed_app")
    options = _session_options(request.config, platform, app_id, request.getfixturevalue("round_app"))
    try:
        session = webdriver.Remote(appium_server.url, options=options)
    except (WebDriverException, HTTPError, OSError) as error:
        raise RoundEnvError(f"appium session on {platform} failed: {_first_line(str(error))}") from error
    try:
        yield session
    finally:
        session.quit()


def _require_unlocked_console(runner: Runner) -> None:
    """Raise `RoundEnvError` while the macOS console is locked.

    XCTest lists the app and its menu bar but no window of a locked session, so the Flutter tree never appears and
    the item would wait out its timeout and read `fail`. An `ioreg` that answers nothing readable leaves the item to run.
    """
    done = runner.run(["ioreg", "-n", "Root", "-d1"], timeout_s=_IOREG_TIMEOUT_S)
    if done.status == 0 and _CONSOLE_LOCKED.search(done.stdout):
        raise RoundEnvError("macOS console locked: XCTest lists no app windows; unlock the Mac and run again")


def _appium_server(request: pytest.FixtureRequest) -> AppiumServer:
    """The session's Appium server; a start that fails raises `RoundEnvError`, and the next call starts it again."""
    start: Callable[[], AppiumServer] = request.getfixturevalue("appium_server")
    try:
        return start()
    except (AppiumStartError, OSError) as error:
        raise RoundEnvError(f"appium server did not start: {_first_line(str(error))}") from error


def _first_line(text: str) -> str:
    return next((line.strip() for line in text.splitlines() if line.strip()), "")


@pytest.fixture
def talkback(request: pytest.FixtureRequest) -> Iterator[TalkBackLog]:
    """TalkBack freshly restarted on --device for the test, its settings restored afterwards.

    A restart that fails (`TalkBackStuck`, `TalkBackSilent`, adb) raises `RoundEnvError`.
    """
    serial = _required_option(request.config, "device")
    with contextlib.ExitStack() as stack:
        yield _set_up(stack, TalkBackSession(serial), f"talkback setup on {serial}")


@pytest.fixture
def voiceover(driver: Any) -> Iterator[VoiceOver]:
    """VoiceOver on inside the iOS simulator for the test, switched off afterwards."""
    with VoiceOver(driver) as running:
        yield running


@pytest.fixture
def keyboard(request: pytest.FixtureRequest) -> Iterator[UhidKeyboard]:
    """A registered uhid USB keyboard on --device, closed afterwards; a failed registration raises `RoundEnvError`."""
    serial = _required_option(request.config, "device")
    with contextlib.ExitStack() as stack:
        yield _set_up(stack, UhidKeyboard(serial), f"uhid keyboard setup on {serial}")


def _set_up[T](stack: contextlib.ExitStack, tool: contextlib.AbstractContextManager[T], what: str) -> T:
    """Enter a device tool into `stack`; a failure raises `RoundEnvError`, since no widget has been touched yet."""
    try:
        return stack.enter_context(tool)
    except (TalkBackStuck, TalkBackSilent, subprocess.SubprocessError, OSError) as error:
        raise RoundEnvError(f"{what} failed: {_first_line(str(error))}") from error


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_setup(item: pytest.Item) -> None:
    """Skip a `talkback_avd` test unless --device (in a round, the item's target) is the AVD named AVD_NAME.

    Runs before the driver fixture, so a shared target never gets an Appium session.
    """
    if TESTS_DIR not in Path(str(item.path)).resolve().parents:
        return
    if item.get_closest_marker("talkback_avd") is None or item.get_closest_marker("skip"):
        return
    target = item_target(item)
    if target is not None:
        if target.avd != AVD_NAME:
            pytest.skip(f"talkback_avd: target {target.name} is AVD {target.avd!r}, not {AVD_NAME!r}")
        return
    device = item.config.getoption("--device")
    if device is None:
        pytest.skip("no --device given")
    name = avd_name(str(device))
    if name != AVD_NAME:
        pytest.skip(f"talkback_avd: {device} is AVD {name!r}, not {AVD_NAME!r}")


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Skip a tests/ item --platform does not run; a round selects its own items, so this stays out of one."""
    if config.stash.get(ROUND_KEY, None) is not None:
        return
    platform = config.getoption("--platform")
    for item in items:
        if TESTS_DIR not in Path(str(item.path)).resolve().parents:
            continue
        markers = {marker.name for marker in item.iter_markers()}
        reason = skip_reason(markers, platform)
        if reason is not None:
            item.add_marker(pytest.mark.skip(reason=reason))
