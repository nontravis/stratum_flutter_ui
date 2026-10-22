"""Unit tests for the dedicated e2e AVD tool (no avdmanager, no adb, no device)."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from stratum_e2e.android.talkback import AVD_NAME, TALKBACK_SERVICE, TalkBackSilent, TalkBackStuck
from tools.e2e_avd import (
    EXIT_AVD_EXISTS,
    SYSTEM_IMAGE,
    TALKBACK_PACKAGE,
    config_path,
    diagnosis_speaks,
    ini_value,
    main,
    set_ini_value,
    version_name,
)

MODULE = "tools.e2e_avd"
SERIAL = "emulator-5580"
SHARED_AVD = "Pixel_Tablet_API_35"
FRESH_CONFIG = (
    "abi.type=arm64-v8a\nfastboot.forceColdBoot=no\nfastboot.forceFastBoot=yes\n"
    "hw.keyboard=no\nhw.lcd.density=320\n"
)

# A trimmed `dumpsys package com.google.android.marvin.talkback` from the spike image.
DUMPSYS_PACKAGE = (
    "Packages:\n"
    "  Package [com.google.android.marvin.talkback] (1a2b3c):\n"
    "    versionCode=60138348 minSdk=26 targetSdk=35\n"
    "    versionName=15.0.0.639625893\n"
)


class FakeAvdManager:
    """Stands in for `avdmanager create avd`: records argv, writes the AVD files it would."""

    def __init__(self, avd_home: Path) -> None:
        self.avd_home = avd_home
        self.calls: list[list[str]] = []

    def __call__(self, argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        self.calls.append(argv)
        avd_dir = self.avd_home / f"{AVD_NAME}.avd"
        avd_dir.mkdir(parents=True)
        (self.avd_home / f"{AVD_NAME}.ini").write_text(f"path={avd_dir}\n")
        (avd_dir / "config.ini").write_text(FRESH_CONFIG)
        return subprocess.CompletedProcess(argv, 0, "", "")


@pytest.fixture
def avd_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    home = tmp_path / "avd"
    home.mkdir()
    monkeypatch.setenv("ANDROID_AVD_HOME", str(home))
    monkeypatch.setenv("ANDROID_HOME", str(tmp_path / "sdk"))
    return home


@pytest.fixture
def no_subprocess(monkeypatch: pytest.MonkeyPatch) -> list[list[str]]:
    calls: list[list[str]] = []

    def refuse(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv)
        raise AssertionError(f"unexpected subprocess: {argv}")

    monkeypatch.setattr(f"{MODULE}.subprocess.run", refuse)
    return calls


def test_set_ini_value_replaces_an_existing_key() -> None:
    assert set_ini_value("hw.keyboard=no\n", "hw.keyboard", "yes") == "hw.keyboard=yes\n"


def test_set_ini_value_appends_a_missing_key() -> None:
    assert set_ini_value("abi.type=arm64-v8a\n", "hw.keyboard", "yes") == (
        "abi.type=arm64-v8a\nhw.keyboard=yes\n"
    )


def test_set_ini_value_appends_after_a_last_line_without_newline() -> None:
    assert set_ini_value("abi.type=arm64-v8a", "hw.keyboard", "yes") == (
        "abi.type=arm64-v8a\nhw.keyboard=yes\n"
    )


def test_set_ini_value_matches_the_whole_key_and_keeps_other_lines() -> None:
    text = "hw.keyboard.lid=no\nhw.keyboard = no\nhw.lcd.density=320\n"
    assert set_ini_value(text, "hw.keyboard", "yes") == (
        "hw.keyboard.lid=no\nhw.keyboard=yes\nhw.lcd.density=320\n"
    )


def test_ini_value_reads_a_key_or_none() -> None:
    assert ini_value("hw.keyboard.lid=no\nhw.keyboard = yes\n", "hw.keyboard") == "yes"
    assert ini_value("abi.type=arm64-v8a\n", "hw.keyboard") is None


def test_version_name_reads_dumpsys_package() -> None:
    assert version_name(DUMPSYS_PACKAGE) == "15.0.0.639625893"
    assert version_name("Unable to find package: com.google.android.marvin.talkback\n") is None


def test_create_runs_avdmanager_then_sets_keyboard_and_cold_boot(
    avd_home: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fake = FakeAvdManager(avd_home)
    monkeypatch.setattr(f"{MODULE}.subprocess.run", fake)

    assert main(["create"]) == 0

    [argv] = fake.calls
    assert Path(argv[0]).name == "avdmanager"
    assert argv[1:] == [
        "create",
        "avd",
        "-n",
        AVD_NAME,
        "-k",
        SYSTEM_IMAGE,
        "-d",
        "pixel_tablet",
    ]
    config = config_path().read_text()
    assert ini_value(config, "hw.keyboard") == "yes"
    assert ini_value(config, "fastboot.forceColdBoot") == "yes"
    assert ini_value(config, "fastboot.forceFastBoot") == "no"
    assert ini_value(config, "hw.lcd.density") == "320"


def test_create_exits_2_when_the_avd_exists(avd_home: Path, no_subprocess: list[list[str]]) -> None:
    (avd_home / f"{AVD_NAME}.ini").write_text("path=/elsewhere\n")

    assert main(["create"]) == EXIT_AVD_EXISTS
    assert no_subprocess == []


@pytest.mark.parametrize("command", ["talkback", "diagnosis", "check"])
def test_device_commands_refuse_a_shared_avd(
    command: str,
    monkeypatch: pytest.MonkeyPatch,
    no_subprocess: list[list[str]],
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: SHARED_AVD)

    assert main([command, "--serial", SERIAL]) == 1
    assert no_subprocess == []
    assert SHARED_AVD in capsys.readouterr().err


def test_talkback_grants_notifications_before_turning_talkback_on(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[list[str]] = []

    def adb(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        assert argv[:3] == ["adb", "-s", SERIAL]
        calls.append(argv[3:])
        return subprocess.CompletedProcess(argv, 0, "", "")

    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: AVD_NAME)
    monkeypatch.setattr(f"{MODULE}.subprocess.run", adb)

    assert main(["talkback", "--serial", SERIAL]) == 0
    assert calls == [
        ["shell", "pm", "grant", TALKBACK_PACKAGE, "android.permission.POST_NOTIFICATIONS"],
        ["shell", "settings", "put", "secure", "enabled_accessibility_services", TALKBACK_SERVICE],
        ["shell", "settings", "put", "secure", "accessibility_enabled", "1"],
    ]


@pytest.mark.parametrize(
    ("entry_error", "speaks"),
    [(None, True), (TalkBackSilent("silent"), False), (TalkBackStuck("stuck"), False)],
)
def test_diagnosis_speaks_reads_the_talkback_session_entry(
    entry_error: Exception | None,
    speaks: bool,
    monkeypatch: pytest.MonkeyPatch,
    no_subprocess: list[list[str]],
) -> None:
    entered: list[str] = []

    class FakeSession:
        def __init__(self, serial: str) -> None:
            self.serial = serial

        def __enter__(self) -> None:
            entered.append(self.serial)
            if entry_error is not None:
                raise entry_error

        def __exit__(self, *_: object) -> None:
            pass

    monkeypatch.setattr(f"{MODULE}.TalkBackSession", FakeSession)

    assert diagnosis_speaks(SERIAL) is speaks
    assert entered == [SERIAL]
    assert no_subprocess == []


@pytest.mark.parametrize(
    ("speaks", "exit_code", "line"), [(True, 0, "diagnosis=on"), (False, 1, "diagnosis=off")]
)
def test_check_prints_keyboard_talkback_and_diagnosis(
    speaks: bool,
    exit_code: int,
    line: str,
    avd_home: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    (avd_home / f"{AVD_NAME}.avd").mkdir()
    config_path().write_text(set_ini_value(FRESH_CONFIG, "hw.keyboard", "yes"))
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: AVD_NAME)
    monkeypatch.setattr(f"{MODULE}.talkback_version", lambda serial: "15.0.0.639625893")
    monkeypatch.setattr(f"{MODULE}.diagnosis_speaks", lambda serial: speaks)

    assert main(["check", "--serial", SERIAL]) == exit_code
    assert capsys.readouterr().out.splitlines() == [
        "hw.keyboard=yes",
        "talkback=15.0.0.639625893",
        line,
    ]


def test_check_fails_on_a_keyboard_off_or_a_missing_talkback(
    avd_home: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    (avd_home / f"{AVD_NAME}.avd").mkdir()
    config_path().write_text(FRESH_CONFIG)
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: AVD_NAME)
    monkeypatch.setattr(f"{MODULE}.talkback_version", lambda serial: None)
    monkeypatch.setattr(f"{MODULE}.diagnosis_speaks", lambda serial: True)

    assert main(["check", "--serial", SERIAL]) == 1
    assert capsys.readouterr().out.splitlines()[:2] == ["hw.keyboard=no", "talkback=missing"]
