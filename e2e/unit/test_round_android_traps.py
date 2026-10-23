"""Unit tests for the Android settle traps ported from the skill's platforms/android.sh (text in, value out)."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.round.android_traps import (
    BOOT_SETTINGS,
    LOAD_LIMIT,
    clock_jumped,
    focused_anr_package,
    guest_load,
    ime_bound,
    settings_apply_argv,
    settings_restore_argv,
    settle_reasons,
    strip_drive_prefix,
)

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "round" / "android"
PADDING = "a" * (128 * 1024 + 1)


def _fixture(name: str) -> str:
    return (FIXTURES / name).read_text()


def test_ime_bound_api36_and_api37() -> None:
    assert ime_bound(_fixture("ime_api36_bound.txt")) is True
    assert ime_bound(_fixture("ime_api37_bound.txt")) is True
    assert ime_bound(_fixture("ime_api37_unbound.txt")) is False


def test_ime_bound_reads_mcurid_null_as_unbound() -> None:
    assert ime_bound(_fixture("ime_api36_null.txt")) is False
    assert ime_bound("") is False
    assert ime_bound("no input method lines at all\n") is False


def test_ime_bound_reads_a_dump_past_128_kib() -> None:
    api37 = f"mBindingController:\n{PADDING}\nmBoundToMethod=true\n"
    api36 = f"mCurId=com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME\n{PADDING}\n"
    assert ime_bound(api37) is True
    assert ime_bound(api36) is True


def test_ime_bound_prefers_the_mcurid_line_over_mboundtomethod() -> None:
    assert ime_bound("mCurId=null\nmBoundToMethod=true\n") is False


def test_focused_anr_package() -> None:
    assert focused_anr_package(_fixture("anr_title_shape.txt")) == "com.android.systemui"
    assert focused_anr_package(_fixture("anr_isnt_responding_shape.txt")) == "com.android.systemui"
    assert focused_anr_package(_fixture("focus_normal.txt")) is None


def test_focused_anr_package_reads_only_the_first_focus_line() -> None:
    dump = _fixture("focus_normal.txt") + _fixture("anr_title_shape.txt")
    assert focused_anr_package(dump) is None
    assert focused_anr_package("") is None


def test_guest_load_from_uptime() -> None:
    assert guest_load(_fixture("uptime.txt")) == 0.50


def test_guest_load_is_infinite_when_unreadable() -> None:
    assert guest_load("uptime: permission denied\n") == float("inf")


def test_settle_reasons_name_every_unmet_gate() -> None:
    assert len(settle_reasons(2.4, "com.x", False)) == 3
    assert settle_reasons(1.9, None, True) == []
    assert settle_reasons(LOAD_LIMIT, None, True) == []


def test_settle_reasons_name_the_value_behind_each_gate() -> None:
    load, anr, ime = settle_reasons(2.4, "com.x", False)
    assert "2.4" in load and "2" in load
    assert "com.x" in anr
    assert "IME" in ime
    assert "unknown" in settle_reasons(float("inf"), None, True)[0]


def test_clock_jump_sign() -> None:
    assert clock_jumped(_fixture("ping_clock_jump.txt")) is True
    assert clock_jumped("64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=0.412 ms") is False
    assert clock_jumped(_fixture("ping_normal.txt")) is False
    assert clock_jumped("") is False


def test_boot_settings_apply_and_restore() -> None:
    assert BOOT_SETTINGS == (
        ("stylus_handwriting_enabled", "0"),
        ("immersive_mode_confirmations", "confirmed"),
    )
    assert settings_apply_argv("adb", "emulator-5554") == [
        ["adb", "-s", "emulator-5554", "shell", "settings", "put", "secure", "stylus_handwriting_enabled", "0"],
        ["adb", "-s", "emulator-5554", "shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed"],
    ]
    assert settings_restore_argv("adb", "emulator-5554") == [
        ["adb", "-s", "emulator-5554", "shell", "settings", "delete", "secure", "stylus_handwriting_enabled"],
        ["adb", "-s", "emulator-5554", "shell", "settings", "delete", "secure", "immersive_mode_confirmations"],
    ]


def test_strip_drive_prefix() -> None:
    assert strip_drive_prefix("I/flutter ( 4242): REPEAT co01_02/us03/s1 1/10 ok") == "REPEAT co01_02/us03/s1 1/10 ok"


def test_strip_drive_prefix_works_per_line_and_only_once() -> None:
    text = "I/flutter (  42): a\nplain line\nE/flutter (1234): I/flutter ( 1): nested\n"
    assert strip_drive_prefix(text) == "a\nplain line\nI/flutter ( 1): nested\n"


@pytest.mark.parametrize("level", ["V", "D", "I", "W", "E", "F"])
def test_strip_drive_prefix_accepts_every_log_level(level: str) -> None:
    assert strip_drive_prefix(f"{level}/flutter ( 7): x") == "x"


def test_strip_drive_prefix_drops_a_trailing_carriage_return() -> None:
    assert strip_drive_prefix("I/flutter ( 7): x\r\ny\r\n") == "x\ny\n"
