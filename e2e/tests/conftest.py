"""Skip hook and device fixtures for items under tests/ only.

Living here keeps unit/ runnable under any --platform and without a device. In a device round
(`--target` or `--mode`) every fixture here depends on `round_target`, so it re-creates per target,
and the round plugin (`stratum_e2e.round.plugin`) supplies the app and the low-level options; an
Appium server, install, or session failure raises `RoundEnvError`, so the round classes it `env`.
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any, Iterator

import pytest
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.options.common import AppiumOptions
from appium.options.ios import XCUITestOptions
from appium.options.mac import Mac2Options
from playwright.sync_api import Browser, sync_playwright
from selenium.common.exceptions import WebDriverException
from urllib3.exceptions import HTTPError

from stratum_e2e.android.session import android_capabilities, install_apk
from stratum_e2e.android.talkback import AVD_NAME, TalkBackLog, TalkBackSession, avd_name
from stratum_e2e.android.uhid_keyboard import UhidKeyboard
from stratum_e2e.appium_server import AppiumServer, AppiumStartError
from stratum_e2e.ios.session import WDA_DERIVED_DATA, install_app, ios_capabilities
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.macos.session import mac_capabilities
from stratum_e2e.ports import free_port
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.plugin import ROUND_KEY, RoundTarget, item_target
from stratum_e2e.selection import skip_reason
from stratum_e2e.web.server import StaticServer

TESTS_DIR = Path(__file__).resolve().parent


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


@pytest.fixture(scope="session")
def _installed() -> set[tuple[str, Path]]:
    """The (device, app) pairs this session installed."""
    return set()


@pytest.fixture
def installed_app(
    request: pytest.FixtureRequest, platform: str, round_app: Path, _installed: set[tuple[str, Path]]
) -> None:
    """Install the app under test on --device once per (device, app) pair.

    A streamed `install -r` of a debug APK plus Flutter's asset copy after it filled a 5.8 GB
    /data within 8 tests, and with `noReset` a reinstall per test buys no isolation. A failed
    install is not remembered, so the round's re-run of the item installs again.
    """
    if platform == "macos":
        return  # Mac2 launches the app bundle itself through `appPath`
    device = _required_option(request.config, "device")
    if (device, round_app) in _installed:
        return
    if platform not in ("android", "ios"):
        pytest.fail(f"no driver for platform {platform!r} yet", pytrace=False)
    try:
        if platform == "android":
            install_apk(device, round_app)
        else:
            install_app(device, round_app)
    except (subprocess.CalledProcessError, OSError) as error:
        raise RoundEnvError(f"app install on {device} failed: {error}") from error
    _installed.add((device, round_app))


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


@pytest.fixture(scope="session")
def static_server(round_app: Path) -> Iterator[StaticServer]:
    """Serve the web build under test on a free port, per target in a round; always stopped afterwards."""
    with StaticServer(round_app) as server:
        yield server


@pytest.fixture(scope="session")
def browser() -> Iterator[Browser]:
    """The Chrome the web leg drives, headless, for the session; always closed afterwards."""
    with sync_playwright() as playwright:
        chrome = playwright.chromium.launch(channel="chrome", headless=True)
        try:
            yield chrome
        finally:
            chrome.close()


@pytest.fixture
def driver(request: pytest.FixtureRequest, platform: str, app_id: str) -> Iterator[Any]:
    """The platform leg's handle on --device: an Appium session, or a Playwright `Page` on web.

    An Appium session has --app installed and is quit afterwards. A web `Page` is blank
    until `open_fixture`, resolves relative URLs against the build's server, and is
    closed afterwards.
    """
    if platform == "web":
        browser = request.getfixturevalue("browser")
        server = request.getfixturevalue("static_server")
        page = browser.new_page(base_url=server.url)
        try:
            yield page
        finally:
            page.close()
        return
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


def _appium_server(request: pytest.FixtureRequest) -> AppiumServer:
    """The session's Appium server; one that never started raises `RoundEnvError`."""
    try:
        server: AppiumServer = request.getfixturevalue("appium_server")
    except (AppiumStartError, OSError) as error:
        raise RoundEnvError(f"appium server did not start: {_first_line(str(error))}") from error
    return server


def _first_line(text: str) -> str:
    return next((line.strip() for line in text.splitlines() if line.strip()), "")


@pytest.fixture
def talkback(request: pytest.FixtureRequest) -> Iterator[TalkBackLog]:
    """TalkBack freshly restarted on --device for the test, its settings restored afterwards."""
    serial = _required_option(request.config, "device")
    with TalkBackSession(serial) as log:
        yield log


@pytest.fixture
def voiceover(driver: Any) -> Iterator[VoiceOver]:
    """VoiceOver on inside the iOS simulator for the test, switched off afterwards."""
    with VoiceOver(driver) as running:
        yield running


@pytest.fixture
def keyboard(request: pytest.FixtureRequest) -> Iterator[UhidKeyboard]:
    """A registered uhid USB keyboard on --device, closed afterwards."""
    serial = _required_option(request.config, "device")
    with UhidKeyboard(serial) as registered:
        yield registered


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
