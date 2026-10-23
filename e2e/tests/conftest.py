"""Skip hook and device fixtures for items under tests/ only.

Living here keeps unit/ runnable under any --platform and without a device.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Iterator

import pytest
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.options.common import AppiumOptions
from appium.options.ios import XCUITestOptions

from stratum_e2e.android.session import android_capabilities, install_apk
from stratum_e2e.android.talkback import AVD_NAME, TalkBackLog, TalkBackSession, avd_name
from stratum_e2e.android.uhid_keyboard import UhidKeyboard
from stratum_e2e.appium_server import AppiumServer
from stratum_e2e.ios.session import WDA_DERIVED_DATA, install_app, ios_capabilities
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.ports import free_port
from stratum_e2e.selection import skip_reason

TESTS_DIR = Path(__file__).resolve().parent


def _required_option(config: pytest.Config, name: str) -> str:
    value = config.getoption(name)
    if value is None:
        pytest.fail(f"--{name.replace('_', '-')} is required for this test", pytrace=False)
    return str(value)


@pytest.fixture(scope="session")
def platform(request: pytest.FixtureRequest) -> str:
    """The --platform leg this session runs."""
    return _required_option(request.config, "platform")


@pytest.fixture(scope="session")
def app_id(request: pytest.FixtureRequest) -> str:
    """The --app-id of the app under test."""
    return _required_option(request.config, "app_id")


@pytest.fixture(scope="session")
def installed_app(request: pytest.FixtureRequest, platform: str) -> None:
    """Install --app on --device once per session (--device and --app are fixed per session).

    A streamed `install -r` of a debug APK plus Flutter's asset copy after it filled a 5.8 GB
    /data within 8 tests, and with `noReset` a reinstall per test buys no isolation.
    """
    device = _required_option(request.config, "device")
    app = Path(_required_option(request.config, "app"))
    if platform == "android":
        install_apk(device, app)
    elif platform == "ios":
        install_app(device, app)
    else:
        pytest.fail(f"no driver for platform {platform!r} yet", pytrace=False)


def _session_options(platform: str, device: str, app_id: str) -> AppiumOptions:
    """Return the Appium options of the --platform leg's session on [device]."""
    if platform == "ios":
        return XCUITestOptions().load_capabilities(
            ios_capabilities(device, app_id, WDA_DERIVED_DATA, free_port())
        )
    return UiAutomator2Options().load_capabilities(android_capabilities(device, app_id))


@pytest.fixture
def driver(
    request: pytest.FixtureRequest,
    platform: str,
    app_id: str,
    appium_server: AppiumServer,
    installed_app: None,
) -> Iterator[Any]:
    """An Appium session on --device with --app installed; always quit afterwards."""
    device = _required_option(request.config, "device")
    options = _session_options(platform, device, app_id)
    session = webdriver.Remote(appium_server.url, options=options)
    try:
        yield session
    finally:
        session.quit()


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
    """Skip a `talkback_avd` test unless --device is the AVD named AVD_NAME.

    Runs before the driver fixture, so a shared target never gets an Appium session.
    """
    if TESTS_DIR not in Path(str(item.path)).resolve().parents:
        return
    if item.get_closest_marker("talkback_avd") is None or item.get_closest_marker("skip"):
        return
    device = item.config.getoption("--device")
    if device is None:
        pytest.skip("no --device given")
    name = avd_name(str(device))
    if name != AVD_NAME:
        pytest.skip(f"talkback_avd: {device} is AVD {name!r}, not {AVD_NAME!r}")


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    platform = config.getoption("--platform")
    for item in items:
        if TESTS_DIR not in Path(str(item.path)).resolve().parents:
            continue
        markers = {marker.name for marker in item.iter_markers()}
        reason = skip_reason(markers, platform)
        if reason is not None:
            item.add_marker(pytest.mark.skip(reason=reason))
