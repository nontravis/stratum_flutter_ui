"""Unit tests for the dedicated e2e AVD tool (no avdmanager, no adb, no device)."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from stratum_e2e.android.adb import STYLUS_AVD, TALKBACK_AVD
from stratum_e2e.android.talkback import TALKBACK_SERVICE, TalkBackSilent, TalkBackStuck
from stratum_e2e.e2e_avd import (
    EXIT_AVD_EXISTS,
    PROFILES,
    STYLUS_SYSTEM_IMAGE,
    SYSTEM_IMAGE,
    KEY_REPEAT_TIMEOUT_MS,
    TALKBACK_PACKAGE,
    config_path,
    diagnosis_speaks,
    ini_value,
    key_repeat_timeout,
    main,
    set_ini_value,
    version_name,
)

MODULE = "stratum_e2e.e2e_avd"
# A trimmed `dumpsys input_method` capture from the API 36 stylus AVD (toolbar up), real lines kept.
STYLUS_TOOLBAR_DUMP = (Path(__file__).resolve().parent / "fixtures" / "ime" / "api36_stylus_toolbar.txt").read_text()
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
        name = argv[argv.index("-n") + 1]
        avd_dir = self.avd_home / f"{name}.avd"
        avd_dir.mkdir(parents=True)
        (self.avd_home / f"{name}.ini").write_text(f"path={avd_dir}\n")
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
        TALKBACK_AVD,
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
    (avd_home / f"{TALKBACK_AVD}.ini").write_text("path=/elsewhere\n")

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


def test_talkback_sets_the_key_repeat_timeout_before_turning_talkback_on(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[list[str]] = []

    def adb(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv[3:])
        return subprocess.CompletedProcess(argv, 0, "", "")

    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: TALKBACK_AVD)
    monkeypatch.setattr(f"{MODULE}.subprocess.run", adb)

    assert main(["talkback", "--serial", SERIAL]) == 0
    put = ["shell", "settings", "put", "secure", "key_repeat_timeout", str(KEY_REPEAT_TIMEOUT_MS)]
    enable = [call for call in calls if "accessibility_enabled" in call]
    assert calls.index(put) < calls.index(enable[0])
    assert KEY_REPEAT_TIMEOUT_MS == 10000


@pytest.mark.parametrize(
    ("printed", "expected"), [("10000\n", 10000), ("400\n", 400), ("null\n", None), ("", None)]
)
def test_key_repeat_timeout_reads_the_secure_setting(
    printed: str, expected: int | None, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[list[str]] = []

    def adb(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv[3:])
        return subprocess.CompletedProcess(argv, 0, printed, "")

    monkeypatch.setattr(f"{MODULE}.subprocess.run", adb)

    assert key_repeat_timeout(SERIAL) == expected
    assert calls == [["shell", "settings", "get", "secure", "key_repeat_timeout"]]


def test_talkback_grants_notifications_before_turning_talkback_on(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[list[str]] = []

    def adb(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        assert argv[:3] == ["adb", "-s", SERIAL]
        calls.append(argv[3:])
        return subprocess.CompletedProcess(argv, 0, "", "")

    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: TALKBACK_AVD)
    monkeypatch.setattr(f"{MODULE}.subprocess.run", adb)

    assert main(["talkback", "--serial", SERIAL]) == 0
    assert calls == [
        ["shell", "pm", "grant", TALKBACK_PACKAGE, "android.permission.POST_NOTIFICATIONS"],
        ["shell", "settings", "put", "secure", "key_repeat_timeout", "10000"],
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
    (avd_home / f"{TALKBACK_AVD}.avd").mkdir()
    config_path().write_text(set_ini_value(FRESH_CONFIG, "hw.keyboard", "yes"))
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: TALKBACK_AVD)
    monkeypatch.setattr(f"{MODULE}.talkback_version", lambda serial: "15.0.0.639625893")
    monkeypatch.setattr(f"{MODULE}.key_repeat_timeout", lambda serial: 10000)
    monkeypatch.setattr(f"{MODULE}.diagnosis_speaks", lambda serial: speaks)

    assert main(["check", "--serial", SERIAL]) == exit_code
    assert capsys.readouterr().out.splitlines() == [
        "hw.keyboard=yes",
        "talkback=15.0.0.639625893",
        "key_repeat_timeout=10000",
        line,
    ]


def test_check_fails_on_a_keyboard_off_or_a_missing_talkback(
    avd_home: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    (avd_home / f"{TALKBACK_AVD}.avd").mkdir()
    config_path().write_text(FRESH_CONFIG)
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: TALKBACK_AVD)
    monkeypatch.setattr(f"{MODULE}.talkback_version", lambda serial: None)
    monkeypatch.setattr(f"{MODULE}.key_repeat_timeout", lambda serial: 10000)
    monkeypatch.setattr(f"{MODULE}.diagnosis_speaks", lambda serial: True)

    assert main(["check", "--serial", SERIAL]) == 1
    assert capsys.readouterr().out.splitlines()[:2] == ["hw.keyboard=no", "talkback=missing"]


@pytest.mark.parametrize(("timeout", "printed"), [(None, "unset"), (400, "400")])
def test_check_fails_on_a_missing_or_wrong_key_repeat_timeout(
    timeout: int | None,
    printed: str,
    avd_home: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    (avd_home / f"{TALKBACK_AVD}.avd").mkdir()
    config_path().write_text(set_ini_value(FRESH_CONFIG, "hw.keyboard", "yes"))
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: TALKBACK_AVD)
    monkeypatch.setattr(f"{MODULE}.talkback_version", lambda serial: "15.0.0.639625893")
    monkeypatch.setattr(f"{MODULE}.key_repeat_timeout", lambda serial: timeout)
    monkeypatch.setattr(f"{MODULE}.diagnosis_speaks", lambda serial: True)

    assert main(["check", "--serial", SERIAL]) == 1
    assert f"key_repeat_timeout={printed}" in capsys.readouterr().out.splitlines()


def test_the_profiles_cover_both_dedicated_avds_and_keep_the_talkback_one() -> None:
    assert set(PROFILES) == {TALKBACK_AVD, STYLUS_AVD}
    talkback = PROFILES[TALKBACK_AVD]
    assert (talkback.system_image, talkback.device) == (SYSTEM_IMAGE, "pixel_tablet")
    assert talkback.config["hw.keyboard"] == "yes"


def test_the_stylus_profile_is_the_measured_one() -> None:
    stylus = PROFILES[STYLUS_AVD]
    assert STYLUS_SYSTEM_IMAGE == "system-images;android-36;google_apis_playstore;arm64-v8a"
    assert (stylus.system_image, stylus.device) == (STYLUS_SYSTEM_IMAGE, "pixel_8")
    assert stylus.config["hw.keyboard"] == "no"
    assert stylus.config["disk.dataPartition.size"] == "16G"
    assert stylus.config["hw.ramSize"] == "4096"
    assert stylus.config["hw.gpu.mode"] == "host"
    assert stylus.config["PlayStore.enabled"] == "true"


def test_create_builds_the_stylus_avd_from_its_own_profile(
    avd_home: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fake = FakeAvdManager(avd_home)
    monkeypatch.setattr(f"{MODULE}.subprocess.run", fake)

    assert main(["create", "--avd", STYLUS_AVD]) == 0

    [argv] = fake.calls
    assert argv[1:] == ["create", "avd", "-n", STYLUS_AVD, "-k", STYLUS_SYSTEM_IMAGE, "-d", "pixel_8"]
    config = config_path(STYLUS_AVD).read_text()
    assert ini_value(config, "hw.keyboard") == "no"
    assert ini_value(config, "disk.dataPartition.size") == "16G"
    assert ini_value(config, "hw.ramSize") == "4096"
    assert ini_value(config, "hw.gpu.mode") == "host"
    assert ini_value(config, "hw.lcd.density") == "320"


def test_create_exits_2_when_the_stylus_avd_exists_and_leaves_the_talkback_one_alone(
    avd_home: Path, no_subprocess: list[list[str]]
) -> None:
    (avd_home / f"{STYLUS_AVD}.ini").write_text("path=/elsewhere\n")

    assert main(["create", "--avd", STYLUS_AVD]) == EXIT_AVD_EXISTS
    assert no_subprocess == []


def test_create_refuses_an_avd_with_no_profile(no_subprocess: list[list[str]]) -> None:
    with pytest.raises(SystemExit):
        main(["create", "--avd", SHARED_AVD])
    assert no_subprocess == []


@pytest.mark.parametrize(("command", "refused"), [("talkback", STYLUS_AVD), ("diagnosis", STYLUS_AVD)])
def test_a_setup_command_refuses_the_other_dedicated_avd(
    command: str,
    refused: str,
    monkeypatch: pytest.MonkeyPatch,
    no_subprocess: list[list[str]],
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: refused)

    assert main([command, "--serial", SERIAL]) == 1
    assert no_subprocess == []
    assert refused in capsys.readouterr().err


def test_there_is_no_stylus_command(capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit):
        main(["stylus", "--serial", SERIAL])
    assert "invalid choice" in capsys.readouterr().err


def test_the_help_lists_the_four_commands_only(capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit):
        main(["--help"])
    assert "{create,talkback,diagnosis,check}" in capsys.readouterr().out


def _stylus_check_config(avd_home: Path, keyboard: str) -> None:
    (avd_home / f"{STYLUS_AVD}.avd").mkdir()
    config_path(STYLUS_AVD).write_text(set_ini_value(FRESH_CONFIG, "hw.keyboard", keyboard))


def _stylus_dumpsys(monkeypatch: pytest.MonkeyPatch, dump: str) -> list[list[str]]:
    """Answer every adb call with [dump] as `dumpsys input_method` text; return the argv list the calls land in."""
    monkeypatch.setattr(f"{MODULE}.avd_name", lambda serial: STYLUS_AVD)
    calls: list[list[str]] = []

    def run(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv)
        return subprocess.CompletedProcess(argv, 0, dump, "")

    monkeypatch.setattr("stratum_e2e.android.adb.subprocess.run", run)
    return calls


def test_check_on_the_stylus_avd_passes_on_keyboard_off_and_gboard_stylus_support(
    avd_home: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _stylus_check_config(avd_home, "no")
    calls = _stylus_dumpsys(monkeypatch, STYLUS_TOOLBAR_DUMP)

    assert main(["check", "--serial", SERIAL]) == 0

    assert capsys.readouterr().out.splitlines() == ["hw.keyboard=no", "gboard_stylus_handwriting=supported"]
    assert calls == [["adb", "-s", SERIAL, "shell", "-n", "dumpsys", "input_method"]]


def test_check_on_the_stylus_avd_fails_when_gboard_lacks_stylus_support(
    avd_home: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _stylus_check_config(avd_home, "no")
    unsupported = STYLUS_TOOLBAR_DUMP.replace("mSupportsStylusHandwriting=true", "mSupportsStylusHandwriting=false")
    _stylus_dumpsys(monkeypatch, unsupported)

    assert main(["check", "--serial", SERIAL]) == 1

    assert capsys.readouterr().out.splitlines() == ["hw.keyboard=no", "gboard_stylus_handwriting=missing"]


def test_check_on_the_stylus_avd_fails_on_a_hardware_keyboard(
    avd_home: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _stylus_check_config(avd_home, "yes")
    _stylus_dumpsys(monkeypatch, STYLUS_TOOLBAR_DUMP)

    assert main(["check", "--serial", SERIAL]) == 1

    assert capsys.readouterr().out.splitlines()[0] == "hw.keyboard=yes"
