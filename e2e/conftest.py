"""Shared pytest plugins and options for the e2e suite (design section 18).

The tests/-only skip hook lives in ``tests/conftest.py`` so ``unit/`` runs under
any ``--platform``; this root conftest only adds the CLI options and the
session-scoped Appium server fixture.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterator

import pytest

from stratum_e2e.appium_server import AppiumServer, default_android_home
from stratum_e2e.ports import free_port

pytest_plugins = ["pytester"]  # unit/test_conftest_hook.py runs the hook in a sandbox

E2E_ROOT = Path(__file__).resolve().parent
APPIUM_BIN = E2E_ROOT / ".tools" / "node_modules" / ".bin" / "appium"
APPIUM_HOME = E2E_ROOT / ".tools" / "appium-home"


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("stratum-e2e")
    group.addoption(
        "--platform",
        choices=("android", "ios", "macos", "web"),
        default=None,
        help="Platform leg to run: android, ios, macos, or web. Without it, tests/ skips.",
    )
    group.addoption(
        "--device",
        default=None,
        metavar="TARGET",
        help="Device target: an adb serial, an iOS udid, 'mac', 'chrome', or 'chrome_wasm'.",
    )
    group.addoption(
        "--app",
        default=None,
        metavar="PATH",
        help="App under test: an APK, a .app bundle, or a web build directory.",
    )
    group.addoption(
        "--app-id",
        dest="app_id",
        default=None,
        metavar="ID",
        help="Android package name or iOS bundle id of the app under test.",
    )


@pytest.fixture(scope="session")
def appium_server() -> Iterator[AppiumServer]:
    """Start one Appium server for the session; always stopped afterwards."""
    server = AppiumServer(
        appium_bin=APPIUM_BIN,
        appium_home=APPIUM_HOME,
        port=free_port(),
        android_home=default_android_home(),
    )
    server.start()
    try:
        yield server
    finally:
        server.stop()
