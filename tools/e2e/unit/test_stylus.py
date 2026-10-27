"""Unit tests for the stylus helper: the stylus tap argv and the `dumpsys input_method` reads."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from stratum_e2e.android.stylus import (
    gboard_supports_stylus,
    ime_input_shown,
    read_gboard_stylus_support,
    read_ime_input_shown,
    stylus_tap,
    stylus_tap_args,
)

ADB_MODULE = "stratum_e2e.android.adb"
SERIAL = "emulator-5554"
IME_FIXTURES = Path(__file__).resolve().parent / "fixtures" / "ime"

# Trimmed copies of two `dumpsys input_method` captures on the API 36 stylus AVD (Gboard 15.1.08), real lines kept.
FULL_KEYBOARD = (IME_FIXTURES / "api36_full_keyboard.txt").read_text()
STYLUS_TOOLBAR = (IME_FIXTURES / "api36_stylus_toolbar.txt").read_text()
GBOARD_ID = "mId=com.google.android.inputmethod.latin/"

# API 37 drops `mCurId=`, so the shown flag alone has to carry the read.
IME_API37_SHOWN = (
    "  mBindingController:\n"
    "    mBoundToMethod=true\n"
    "  mInputShown=true\n"
)


def _gboard_line_without_stylus(dump: str) -> str:
    """[dump] with Gboard's `mSupportsStylusHandwriting` flipped to false; the TTS line is left as it was."""
    return "".join(
        line.replace("mSupportsStylusHandwriting=true", "mSupportsStylusHandwriting=false")
        if line.lstrip().startswith(GBOARD_ID)
        else line
        for line in dump.splitlines(keepends=True)
    )


def test_stylus_tap_args_name_the_input_stylus_tap_command() -> None:
    assert stylus_tap_args(540, 210) == ["shell", "input", "stylus", "tap", "540", "210"]


def test_stylus_tap_runs_it_on_the_serial(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    def run(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv)
        return subprocess.CompletedProcess(argv, 0, "", "")

    monkeypatch.setattr(f"{ADB_MODULE}.subprocess.run", run)

    stylus_tap(SERIAL, 540, 210)

    assert calls == [["adb", "-s", SERIAL, "shell", "input", "stylus", "tap", "540", "210"]]


@pytest.mark.parametrize("dump", [FULL_KEYBOARD, STYLUS_TOOLBAR], ids=["full_keyboard", "stylus_toolbar"])
def test_ime_input_shown_is_true_on_both_captured_dumps(dump: str) -> None:
    assert ime_input_shown(dump) is True


@pytest.mark.parametrize("dump", [FULL_KEYBOARD, STYLUS_TOOLBAR], ids=["full_keyboard", "stylus_toolbar"])
def test_ime_input_shown_is_false_once_the_captured_dump_reads_not_shown(dump: str) -> None:
    hidden = dump.replace("mInputShown=true", "mInputShown=false")

    assert hidden != dump
    assert ime_input_shown(hidden) is False


@pytest.mark.parametrize(
    ("dump", "shown"),
    [
        (IME_API37_SHOWN, True),
        ("", False),
        ("no input method lines at all\n", False),
        ("  mInputShown=false\n  mBoundToMethod=true\n", False),
    ],
)
def test_ime_input_shown_reads_the_dumpsys_line(dump: str, shown: bool) -> None:
    assert ime_input_shown(dump) is shown


def test_ime_input_shown_reads_a_dump_past_128_kib() -> None:
    padding = "a" * (128 * 1024 + 1)

    assert ime_input_shown(f"{padding}\n  mInputShown=true\n") is True


def test_ime_input_shown_ignores_a_longer_key_that_ends_the_same() -> None:
    assert ime_input_shown("  mLastInputShown=true\n") is False


def test_read_ime_input_shown_dumps_input_method_on_the_serial(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    def run(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv)
        return subprocess.CompletedProcess(argv, 0, STYLUS_TOOLBAR, "")

    monkeypatch.setattr(f"{ADB_MODULE}.subprocess.run", run)

    assert read_ime_input_shown(SERIAL) is True
    assert calls == [["adb", "-s", SERIAL, "shell", "-n", "dumpsys", "input_method"]]


@pytest.mark.parametrize("dump", [FULL_KEYBOARD, STYLUS_TOOLBAR], ids=["full_keyboard", "stylus_toolbar"])
def test_gboard_supports_stylus_reads_the_captured_gboard_line(dump: str) -> None:
    assert gboard_supports_stylus(dump) is True


def test_gboard_supports_stylus_is_false_when_gboard_reports_false() -> None:
    assert gboard_supports_stylus(_gboard_line_without_stylus(STYLUS_TOOLBAR)) is False


def test_gboard_supports_stylus_ignores_another_input_method_reporting_true() -> None:
    other_true = _gboard_line_without_stylus(STYLUS_TOOLBAR).replace(
        "mSupportsStylusHandwriting=false", "mSupportsStylusHandwriting=true", 1
    )

    assert "mSupportsStylusHandwriting=true" in other_true
    assert gboard_supports_stylus(other_true) is False


def test_gboard_supports_stylus_is_false_without_a_gboard_line() -> None:
    no_gboard = "".join(
        line for line in STYLUS_TOOLBAR.splitlines(keepends=True) if not line.lstrip().startswith(GBOARD_ID)
    )

    assert gboard_supports_stylus(no_gboard) is False
    assert gboard_supports_stylus("") is False


def test_read_gboard_stylus_support_dumps_input_method_on_the_serial(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    def run(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv)
        return subprocess.CompletedProcess(argv, 0, FULL_KEYBOARD, "")

    monkeypatch.setattr(f"{ADB_MODULE}.subprocess.run", run)

    assert read_gboard_stylus_support(SERIAL) is True
    assert calls == [["adb", "-s", SERIAL, "shell", "-n", "dumpsys", "input_method"]]
