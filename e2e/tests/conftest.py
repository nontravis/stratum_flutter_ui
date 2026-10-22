"""Skip hook and device fixtures for items under tests/ only.

Living here keeps unit/ runnable under any --platform and without a device.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Iterator

import pytest
from appium import webdriver
from appium.options.android import UiAutomator2Options

from stratum_e2e.android.session import android_capabilities, install_apk
from stratum_e2e.appium_server import AppiumServer
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


@pytest.fixture
def driver(
    request: pytest.FixtureRequest,
    platform: str,
    app_id: str,
    appium_server: AppiumServer,
) -> Iterator[Any]:
    """An Appium session on --device with --app installed; always quit afterwards."""
    if platform != "android":
        pytest.fail(f"no driver for platform {platform!r} yet", pytrace=False)
    serial = _required_option(request.config, "device")
    install_apk(serial, Path(_required_option(request.config, "app")))
    options = UiAutomator2Options().load_capabilities(android_capabilities(serial, app_id))
    session = webdriver.Remote(appium_server.url, options=options)
    try:
        yield session
    finally:
        session.quit()


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    platform = config.getoption("--platform")
    for item in items:
        if TESTS_DIR not in Path(str(item.path)).resolve().parents:
            continue
        markers = {marker.name for marker in item.iter_markers()}
        reason = skip_reason(markers, platform)
        if reason is not None:
            item.add_marker(pytest.mark.skip(reason=reason))
