"""Unit tests for the Appium server wrapper."""

from __future__ import annotations

import socket
import time
from pathlib import Path
from typing import Any

import pytest

from stratum_e2e.appium_server import AppiumServer, AppiumStartError, default_android_home


def test_server_env_carries_android_home_and_appium_home(tmp_path: Path) -> None:
    sdk = tmp_path / "sdk"
    appium_home = tmp_path / "appium-home"
    server = AppiumServer(
        appium_bin=tmp_path / "appium",
        appium_home=appium_home,
        port=4723,
        android_home=sdk,
    )
    env = server.env()
    assert env["ANDROID_HOME"] == str(sdk)
    assert env["APPIUM_HOME"] == str(appium_home)


def test_server_env_without_android_home(tmp_path: Path) -> None:
    server = AppiumServer(
        appium_bin=tmp_path / "appium",
        appium_home=tmp_path / "appium-home",
        port=4723,
        android_home=None,
    )
    assert "ANDROID_HOME" not in server.env()


def test_start_timeout_names_port(tmp_path: Path) -> None:
    bin_path = tmp_path / "fake-appium"
    bin_path.write_text("#!/bin/sh\nsleep 30\n")
    bin_path.chmod(0o755)
    server = AppiumServer(
        appium_bin=bin_path,
        appium_home=tmp_path / "appium-home",
        port=free_test_port(),
        android_home=None,
    )
    started = time.monotonic()
    with pytest.raises(AppiumStartError, match=str(server.port)):
        server.start(timeout_s=1)
    assert time.monotonic() - started < 10


def test_start_binds_loopback_only(tmp_path: Path) -> None:
    argv_file = tmp_path / "argv.txt"
    bin_path = tmp_path / "fake-appium"
    bin_path.write_text(f'#!/bin/sh\necho "$@" > "{argv_file}"\nsleep 30\n')
    bin_path.chmod(0o755)
    server = AppiumServer(
        appium_bin=bin_path,
        appium_home=tmp_path / "appium-home",
        port=free_test_port(),
        android_home=None,
    )
    with pytest.raises(AppiumStartError):
        server.start(timeout_s=1)
    argv = argv_file.read_text().split()
    assert argv[argv.index("--address") + 1] == "127.0.0.1"
    assert server.url.startswith("http://127.0.0.1:")


def test_start_writes_output_to_the_log_and_names_it(tmp_path: Path) -> None:
    log = tmp_path / "round" / "appium.log"
    bin_path = tmp_path / "fake-appium"
    bin_path.write_text('#!/bin/sh\necho "server line"\nsleep 30\n')
    bin_path.chmod(0o755)
    server = AppiumServer(
        appium_bin=bin_path,
        appium_home=tmp_path / "appium-home",
        port=free_test_port(),
        android_home=None,
    )
    with pytest.raises(AppiumStartError, match=f"port {server.port}.+log: {log}"):
        server.start(timeout_s=1, log=log)
    assert server.log_path == log
    assert log.read_text().startswith("server line")


def test_start_without_a_log_discards_output(tmp_path: Path) -> None:
    bin_path = tmp_path / "fake-appium"
    bin_path.write_text('#!/bin/sh\necho "server line"\nsleep 30\n')
    bin_path.chmod(0o755)
    server = AppiumServer(
        appium_bin=bin_path,
        appium_home=tmp_path / "appium-home",
        port=free_test_port(),
        android_home=None,
    )
    with pytest.raises(AppiumStartError) as caught:
        server.start(timeout_s=1)
    assert "log:" not in str(caught.value)
    assert server.log_path is None


def test_start_names_the_log_when_the_server_exits(tmp_path: Path) -> None:
    log = tmp_path / "round" / "appium.log"
    bin_path = tmp_path / "fake-appium"
    bin_path.write_text('#!/bin/sh\necho "boom"\nexit 3\n')
    bin_path.chmod(0o755)
    server = AppiumServer(
        appium_bin=bin_path,
        appium_home=tmp_path / "appium-home",
        port=free_test_port(),
        android_home=None,
    )
    with pytest.raises(AppiumStartError, match=f"exited with code 3, log: {log}"):
        server.start(timeout_s=5, log=log)
    assert log.read_text() == "boom\n"


def test_start_closes_the_log_handle_when_the_spawn_raises(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    handles: list[Any] = []

    def failing_popen(*args: Any, **kwargs: Any) -> Any:
        handles.append(kwargs["stdout"])
        raise OSError("cannot exec")

    monkeypatch.setattr("stratum_e2e.appium_server.subprocess.Popen", failing_popen)
    server = AppiumServer(
        appium_bin=tmp_path / "appium",
        appium_home=tmp_path / "appium-home",
        port=free_test_port(),
        android_home=None,
    )
    with pytest.raises(OSError, match="cannot exec"):
        server.start(log=tmp_path / "appium.log")
    assert len(handles) == 1
    assert handles[0].closed
    assert server.poll() is None


def test_poll_reports_none_until_started_and_the_code_after_death(tmp_path: Path) -> None:
    bin_path = tmp_path / "fake-appium"
    bin_path.write_text('#!/bin/sh\nexit 7\n')
    bin_path.chmod(0o755)
    server = AppiumServer(
        appium_bin=bin_path,
        appium_home=tmp_path / "appium-home",
        port=free_test_port(),
        android_home=None,
    )
    assert server.poll() is None
    with pytest.raises(AppiumStartError):
        server.start(timeout_s=5)
    assert server.poll() == 7
    server.stop()
    assert server.poll() is None


def free_test_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


def test_default_android_home_env(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("ANDROID_HOME", str(tmp_path))
    assert default_android_home() == tmp_path


def test_default_android_home_fallback(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("ANDROID_HOME", raising=False)
    home = default_android_home()
    if home is not None:
        assert home == Path.home() / "Library" / "Android" / "sdk"
        assert home.is_dir()
