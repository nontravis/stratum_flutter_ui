"""Unit tests for the Android settle traps ported from the skill's platforms/android.sh (text in, value out)."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.android.adb import STYLUS_AVD, TALKBACK_AVD
from stratum_e2e.round.android_traps import (
    BOOT_SETTINGS,
    LOAD_LIMIT,
    anr_window_packages,
    clock_jumped,
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


def test_anr_window_packages() -> None:
    assert anr_window_packages(_fixture("anr_title_shape.txt")) == ("com.android.systemui",)
    assert anr_window_packages(_fixture("anr_isnt_responding_shape.txt")) == ("com.android.systemui",)
    assert anr_window_packages(_fixture("focus_normal.txt")) == ()
    assert anr_window_packages("") == ()


def test_anr_window_packages_see_an_unfocused_anr_window() -> None:
    unfocused = _fixture("windows_anr_unfocused_api35.txt")
    focused = _fixture("windows_anr_focused_api35.txt")
    assert anr_window_packages(unfocused) == ("com.android.systemui",)
    assert anr_window_packages(focused) == ("com.android.systemui",)


def test_anr_window_packages_report_unknown_for_an_anr_title_without_a_package() -> None:
    packages = anr_window_packages(_fixture("anr_no_package.txt"))
    assert packages == ("unknown",)
    assert settle_reasons(0.5, packages, True) != []


def test_anr_window_packages_skip_a_stale_last_anr_section() -> None:
    assert anr_window_packages(_fixture("anr_stale_lastanr.txt")) == ()


def test_anr_window_packages_list_every_anr_window_deduped_in_window_order() -> None:
    assert anr_window_packages(_fixture("anr_two_windows.txt")) == ("com.android.systemui", "com.example.app")


def test_anr_window_packages_count_an_exiting_anr_window() -> None:
    assert anr_window_packages(_fixture("anr_exiting.txt")) == ("com.android.systemui",)


def test_guest_load_from_uptime() -> None:
    assert guest_load(_fixture("uptime.txt")) == 0.50


def test_guest_load_is_infinite_when_unreadable() -> None:
    assert guest_load("uptime: permission denied\n") == float("inf")


def test_settle_reasons_name_every_unmet_gate() -> None:
    assert len(settle_reasons(2.4, ("com.x",), False)) == 3
    assert settle_reasons(1.9, (), True) == []
    assert settle_reasons(LOAD_LIMIT, (), True) == []


def test_settle_reasons_name_the_value_behind_each_gate() -> None:
    load, anr, ime = settle_reasons(2.4, ("com.x", "com.y"), False)
    assert "2.4" in load and "2" in load
    assert anr == "an ANR window is open: com.x, com.y"
    assert "IME" in ime
    assert "unknown" in settle_reasons(float("inf"), (), True)[0]


def test_settle_reasons_name_an_anr_window_the_focus_line_misses() -> None:
    unfocused = _fixture("windows_anr_unfocused_api35.txt")
    reasons = settle_reasons(1.27, anr_window_packages(unfocused), True)
    assert reasons == ["an ANR window is open: com.android.systemui"]


def test_settle_reasons_hold_on_an_unreadable_window_list() -> None:
    assert settle_reasons(0.5, None, True) == ["the window list is unreadable (dumpsys window windows)"]


def test_anr_title_regex_reads_a_process_suffix_package() -> None:
    assert anr_window_packages("  Window #0 Window{a1 u0 Application Not Responding: com.foo:bar}:\n") == ("com.foo:bar",)
    assert anr_window_packages("  Window #0 Window{b2 u0 com.foo:bar isn't responding}:\n") == ("com.foo:bar",)


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
    assert settings_apply_argv("adb", "emulator-5554", "Pixel_8_API_37") == [
        ["adb", "-s", "emulator-5554", "shell", "settings", "put", "secure", "stylus_handwriting_enabled", "0"],
        ["adb", "-s", "emulator-5554", "shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed"],
    ]
    assert settings_restore_argv("adb", "emulator-5554", "Pixel_8_API_37") == [
        ["adb", "-s", "emulator-5554", "shell", "settings", "delete", "secure", "stylus_handwriting_enabled"],
        ["adb", "-s", "emulator-5554", "shell", "settings", "delete", "secure", "immersive_mode_confirmations"],
    ]


@pytest.mark.parametrize("avd", ["Pixel_8_API_37", TALKBACK_AVD])
def test_boot_settings_keep_both_keys_off_the_stylus_avd(avd: str) -> None:
    put_keys = [argv[-2] for argv in settings_apply_argv("adb", "emulator-5554", avd)]
    delete_keys = [argv[-1] for argv in settings_restore_argv("adb", "emulator-5554", avd)]
    assert put_keys == delete_keys == [key for key, _ in BOOT_SETTINGS]


def test_boot_settings_leave_the_stylus_key_alone_on_the_stylus_avd() -> None:
    assert [argv[-2:] for argv in settings_apply_argv("adb", "emulator-5554", STYLUS_AVD)] == [
        ["immersive_mode_confirmations", "confirmed"]
    ]
    assert [argv[-1] for argv in settings_restore_argv("adb", "emulator-5554", STYLUS_AVD)] == [
        "immersive_mode_confirmations"
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
