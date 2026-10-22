"""Unit tests for the Appium server wrapper."""

from __future__ import annotations

import socket
import time
from pathlib import Path

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
