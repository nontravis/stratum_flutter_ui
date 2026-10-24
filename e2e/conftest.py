"""Shared pytest plugins and options for the e2e suite (design section 18).

The tests/-only skip hook lives in ``tests/conftest.py`` so ``unit/`` runs under
any ``--platform``; this root conftest only adds the CLI options and the
session's Appium server fixture.
"""

from __future__ import annotations

from collections.abc import Callable
from types import TracebackType
from typing import Iterator

import pytest

from stratum_e2e.appium_server import AppiumServer, default_android_home
from stratum_e2e.paths import APPIUM_BIN, APPIUM_HOME
from stratum_e2e.ports import free_port
from stratum_e2e.round.state import ROUND_KEY

pytest_plugins = ["pytester", "stratum_e2e.round.plugin"]  # pytester: unit/ tests run the hooks in a sandbox


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
def appium_server(request: pytest.FixtureRequest) -> Iterator[Callable[[], AppiumServer]]:
    """Return the getter of the session's Appium server; every server it started stops at session end.

    The getter starts the server on its first call. A failed start raises AppiumStartError (or OSError).
    In a device round the failure is not kept, so the round's re-run of an item starts the server again;
    outside a round every later call raises it at once, so a leg never waits out the start timeout twice.
    """
    in_round = request.config.stash.get(ROUND_KEY, None) is not None
    started: list[AppiumServer] = []
    failure: list[tuple[Exception, TracebackType | None]] = []

    def get() -> AppiumServer:
        if failure:
            error, traceback = failure[0]
            raise error.with_traceback(traceback)
        if not started:
            server = AppiumServer(
                appium_bin=APPIUM_BIN,
                appium_home=APPIUM_HOME,
                port=free_port(),
                android_home=default_android_home(),
            )
            try:
                server.start()
            except Exception as error:
                if not in_round:
                    failure.append((error, error.__traceback__))
                raise
            started.append(server)
        return started[0]

    try:
        yield get
    finally:
        for server in started:
            server.stop()
