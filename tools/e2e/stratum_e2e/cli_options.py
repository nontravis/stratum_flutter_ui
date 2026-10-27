"""Pytest plugin of the e2e suite: the CLI options and the session's Appium server fixture (design section 18).

Loaded by `-p` from `pytest.ini`. The platform skip hook lives in `stratum_e2e.device_fixtures`, scoped to the
round-scope test folders, so `unit/` runs under any `--platform`.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from types import TracebackType
from typing import Iterator

import pytest

from stratum_e2e.appium_server import AppiumServer, AppiumStartError, default_android_home
from stratum_e2e.paths import APPIUM_BIN, APPIUM_HOME
from stratum_e2e.ports import free_port
from stratum_e2e.round.state import ROUND_KEY, STATE_KEY


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("stratum-e2e")
    group.addoption(
        "--platform",
        choices=("android", "ios", "macos", "web"),
        default=None,
        help="Platform leg to run: android, ios, macos, or web. Without it, the e2e folders skip.",
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
    group.addoption(
        "--host-voiceover",
        dest="host_voiceover",
        action="store_true",
        default=False,
        help=(
            "Run the level2_host legs, which start VoiceOver on this Mac (owner command only, ruling O1). "
            "Without it they skip, whatever -m selects."
        ),
    )


@pytest.fixture(scope="session")
def appium_server(request: pytest.FixtureRequest) -> Iterator[Callable[[], AppiumServer]]:
    """Return the getter of the session's Appium server; every server it started stops at session end.

    The getter starts the server on its first call, with its output in the round dir's `appium.log` in a
    round. A server that died is restarted once per session; a second death raises AppiumStartError naming
    the died server's log, so the round reads `env` with the log path, and every later call of the session
    raises it again at once, starting no third server. A failed start is unkept in a round,
    so the round's re-run starts the server again; outside a round every later call raises it at once, so a
    leg never waits out the start timeout twice.
    """
    in_round = request.config.stash.get(ROUND_KEY, None) is not None
    started: list[AppiumServer] = []
    failure: list[tuple[Exception, TracebackType | None]] = []
    restarts = 0
    gave_up: list[AppiumStartError] = []

    def log_path() -> Path | None:
        state = request.config.stash.get(STATE_KEY, None)
        if state is None or state.round_dir is None:
            return None
        return state.round_dir.path / "appium.log"

    def get() -> AppiumServer:
        nonlocal restarts
        if failure:
            error, traceback = failure[0]
            raise error.with_traceback(traceback)
        if gave_up:
            raise gave_up[0]
        if started and started[0].poll() is not None:
            died = started.pop(0)
            note = f", log: {died.log_path}" if died.log_path is not None else ""
            died.stop()
            if restarts >= 1:
                gave_up.append(AppiumStartError(f"appium on port {died.port} died again{note}"))
                raise gave_up[0]
            restarts += 1
        if not started:
            server = AppiumServer(
                appium_bin=APPIUM_BIN,
                appium_home=APPIUM_HOME,
                port=free_port(),
                android_home=default_android_home(),
            )
            try:
                server.start(log=log_path())
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
