"""Unit tests for the Android SDK, AVD, and console port helpers (no adb, no emulator, no device)."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

from stratum_e2e import appium_server
from stratum_e2e.appium_server import default_android_home
from stratum_e2e.round.android_host import (
    CONSOLE_PORTS,
    adb_path,
    avd_info,
    emulator_path,
    missing_avd_message,
    port_directory,
    reserve_port,
    sdk_root,
)
from stratum_e2e.round.errors import RoundEnvError

E2E_DIR = Path(__file__).resolve().parents[1]
AVD_FIXTURES = Path(__file__).resolve().parent / "fixtures" / "round" / "android" / "avd"


def _sdk(path: Path) -> Path:
    path.mkdir(parents=True)
    return path


def _write_properties(app_dir: Path, text: str) -> None:
    (app_dir / "android").mkdir(parents=True)
    (app_dir / "android" / "local.properties").write_text(text)


def test_sdk_root_order(tmp_path: Path) -> None:
    home_sdk = _sdk(tmp_path / "home" / "Library" / "Android" / "sdk")
    props_sdk = _sdk(tmp_path / "props")
    root_sdk = _sdk(tmp_path / "root")
    home_env = _sdk(tmp_path / "env")
    app_dir = tmp_path / "app"
    _write_properties(app_dir, f"sdk.dir={props_sdk}\n")
    home = tmp_path / "home"

    assert sdk_root(app_dir, {"ANDROID_HOME": str(home_env), "ANDROID_SDK_ROOT": str(root_sdk)}, home) == home_env
    assert sdk_root(app_dir, {"ANDROID_SDK_ROOT": str(root_sdk)}, home) == root_sdk
    assert sdk_root(app_dir, {}, home) == props_sdk
    (app_dir / "android" / "local.properties").unlink()
    assert sdk_root(app_dir, {}, home) == home_sdk


def test_sdk_root_skips_a_place_that_is_not_a_directory(tmp_path: Path) -> None:
    real = _sdk(tmp_path / "real")
    environ = {"ANDROID_HOME": str(tmp_path / "gone"), "ANDROID_SDK_ROOT": str(real)}
    assert sdk_root(tmp_path / "app", environ, tmp_path / "home") == real


def test_sdk_root_reads_a_properties_path_with_escaped_colons(tmp_path: Path) -> None:
    sdk = _sdk(tmp_path / "sdk")
    app_dir = tmp_path / "app"
    _write_properties(app_dir, f"flutter.sdk=/x\nsdk.dir={str(sdk).replace(':', chr(92) + ':')}\n")
    assert sdk_root(app_dir, {}, tmp_path / "home") == sdk


def test_sdk_root_passes_over_a_properties_file_that_is_not_utf8(tmp_path: Path) -> None:
    home_sdk = _sdk(tmp_path / "home" / "Library" / "Android" / "sdk")
    app_dir = tmp_path / "app"
    (app_dir / "android").mkdir(parents=True)
    (app_dir / "android" / "local.properties").write_bytes(b"sdk.dir=/Users/caf\xe9/sdk\n")
    assert sdk_root(app_dir, {}, tmp_path / "home") == home_sdk


def test_sdk_root_passes_over_a_properties_file_it_cannot_read(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home_sdk = _sdk(tmp_path / "home" / "Library" / "Android" / "sdk")
    app_dir = tmp_path / "app"
    _write_properties(app_dir, f"sdk.dir={tmp_path / 'props'}\n")
    real_read = Path.read_text

    def refuse(path: Path, *args: object, **kwargs: object) -> str:
        if path.name == "local.properties":
            raise PermissionError(13, "Permission denied", str(path))
        return real_read(path, *args, **kwargs)  # type: ignore[arg-type]  # forwards read_text's own arguments

    monkeypatch.setattr(Path, "read_text", refuse)
    assert sdk_root(app_dir, {}, tmp_path / "home") == home_sdk


def test_sdk_root_names_all_four_places_when_none_exists(tmp_path: Path) -> None:
    with pytest.raises(RoundEnvError) as caught:
        sdk_root(tmp_path / "app", {}, tmp_path / "home")
    message = str(caught.value)
    assert message.startswith("env: ")
    for place in ("ANDROID_HOME", "ANDROID_SDK_ROOT", "local.properties", str(tmp_path / "home" / "Library" / "Android" / "sdk")):
        assert place in message


def test_adb_on_path_wins_else_sdk_platform_tools(tmp_path: Path) -> None:
    assert adb_path(tmp_path, which=lambda name: "/usr/bin/adb") == "adb"
    assert adb_path(tmp_path, which=lambda name: None) == str(tmp_path / "platform-tools" / "adb")


def test_emulator_path_is_under_the_sdk(tmp_path: Path) -> None:
    assert emulator_path(tmp_path) == str(tmp_path / "emulator" / "emulator")


def test_avd_api_reads_the_ini_target() -> None:
    info = avd_info("api28", AVD_FIXTURES)
    assert (info.name, info.api, info.folder) == ("api28", 28, Path("/tmp/api28.avd"))
    assert avd_info("api36", AVD_FIXTURES).api == 36


def test_avd_info_of_a_missing_ini_raises_with_the_creation_line(tmp_path: Path) -> None:
    with pytest.raises(RoundEnvError) as caught:
        avd_info("ghost", tmp_path)
    assert missing_avd_message("ghost") in str(caught.value)
    assert str(tmp_path) in str(caught.value)


def test_avd_info_of_an_ini_without_a_target_raises(tmp_path: Path) -> None:
    (tmp_path / "odd.ini").write_text("path=/tmp/odd.avd\n")
    with pytest.raises(RoundEnvError, match="odd"):
        avd_info("odd", tmp_path)


def test_missing_avd_names_the_avdmanager_line() -> None:
    message = missing_avd_message("api36")
    assert "avdmanager create avd" in message
    assert "api36" in message


def test_port_is_free_even_and_reserved(tmp_path: Path) -> None:
    first = reserve_port("console", 5554, 5584, 2, {5554}, tmp_path)
    assert first.port == 5556
    second = reserve_port("console", 5554, 5584, 2, {5554}, tmp_path)
    assert second.port == 5558
    first.release()
    third = reserve_port("console", 5554, 5584, 2, {5554}, tmp_path)
    assert third.port == 5556
    assert third.path == tmp_path / "console-5556.lock"
    for held in (second, third):
        held.release()


def test_port_creates_its_directory_on_first_use(tmp_path: Path) -> None:
    directory = tmp_path / "ports"
    reservation = reserve_port("console", 5554, 5584, 2, set(), directory)
    assert reservation.path.is_file()
    reservation.release()


def test_release_twice_is_harmless(tmp_path: Path) -> None:
    reservation = reserve_port("console", 5554, 5584, 2, set(), tmp_path)
    reservation.release()
    reservation.release()


def test_every_port_taken_raises(tmp_path: Path) -> None:
    with pytest.raises(RoundEnvError, match="5554"):
        reserve_port("console", 5554, 5558, 2, {5554, 5556, 5558}, tmp_path)


def test_android_console_ports_are_the_even_range() -> None:
    assert CONSOLE_PORTS == ("console", 5554, 5584, 2)


def test_port_directory_sits_under_the_lane_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("STRATUM_E2E_LANE_DIR", str(tmp_path))
    assert port_directory() == tmp_path / "ports"


_HOLDER = """
import sys, time
from pathlib import Path
from stratum_e2e.round.android_host import reserve_port
held = reserve_port("console", 5554, 5584, 2, set(), Path(sys.argv[1]))
print(held.port, flush=True)
time.sleep(60)
"""


def test_port_reservation_is_a_flock_not_a_directory(tmp_path: Path) -> None:
    child = subprocess.Popen(
        [sys.executable, "-c", _HOLDER, str(tmp_path)],
        cwd=E2E_DIR,
        stdout=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        assert child.stdout.readline().strip() == "5554"
        beside = reserve_port("console", 5554, 5584, 2, set(), tmp_path)
        assert beside.port == 5556
        beside.release()
    finally:
        child.kill()
        child.wait()
    after = reserve_port("console", 5554, 5584, 2, set(), tmp_path)
    assert after.port == 5554
    assert after.path == tmp_path / "console-5554.lock"
    after.release()


def test_default_android_home_honors_android_sdk_root_and_local_properties(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("ANDROID_HOME", raising=False)
    monkeypatch.delenv("ANDROID_SDK_ROOT", raising=False)
    monkeypatch.setattr(Path, "home", lambda: tmp_path / "no-home")
    monkeypatch.setattr(appium_server, "E2E_ROOT", tmp_path / "e2e")
    app_dir = tmp_path / "test_app"

    root_sdk = _sdk(tmp_path / "root")
    monkeypatch.setenv("ANDROID_SDK_ROOT", str(root_sdk))
    assert default_android_home() == root_sdk

    monkeypatch.delenv("ANDROID_SDK_ROOT")
    assert default_android_home() is None

    props_sdk = _sdk(tmp_path / "props")
    _write_properties(app_dir, f"sdk.dir={props_sdk}\n")
    assert default_android_home() == props_sdk


def test_default_android_home_last_place_needs_a_directory(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("ANDROID_HOME", raising=False)
    monkeypatch.delenv("ANDROID_SDK_ROOT", raising=False)
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    monkeypatch.setattr(appium_server, "E2E_ROOT", tmp_path / "e2e")
    assert default_android_home() is None
    fallback = _sdk(tmp_path / "Library" / "Android" / "sdk")
    assert default_android_home() == fallback
