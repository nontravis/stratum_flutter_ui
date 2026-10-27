"""The stylus tap and the `dumpsys input_method` reads the stylus AVD shares (design section 8).

`adb emu event mouse` is a finger, so the stylus toolbar needs `adb shell input stylus tap`. The reads parse
`dumpsys input_method`, which needs no Appium session.
"""

from __future__ import annotations

import re

from stratum_e2e.android.adb import adb

# The key and its value in one match, so `mLastInputShown=` never reads as `mInputShown=`.
_INPUT_SHOWN = re.compile(r"(?<![A-Za-z])mInputShown=true\b")
_GBOARD_ID = "mId=com.google.android.inputmethod.latin/"
_STYLUS_HANDWRITING = re.compile(r"\bmSupportsStylusHandwriting=true\b")


def stylus_tap_args(x: int, y: int) -> list[str]:
    """Return the adb arguments after `-s <serial>` for one stylus tap at ([x], [y])."""
    return ["shell", "input", "stylus", "tap", str(x), str(y)]


def stylus_tap(serial: str, x: int, y: int) -> None:
    """Tap ([x], [y]) once with a stylus on device [serial]."""
    adb(serial, *stylus_tap_args(x, y))


def ime_input_shown(dumpsys_input_method: str) -> bool:
    """Whether `dumpsys input_method` reads `mInputShown=true`; a dump without the line reads False."""
    return _INPUT_SHOWN.search(dumpsys_input_method) is not None


def gboard_supports_stylus(dumpsys_input_method: str) -> bool:
    """Whether Gboard's `mId=` line of `dumpsys input_method` reads `mSupportsStylusHandwriting=true`.

    Another input method's line never counts, and a dump with no Gboard line reads False.
    """
    return any(
        _STYLUS_HANDWRITING.search(line) is not None
        for line in dumpsys_input_method.splitlines()
        if line.lstrip().startswith(_GBOARD_ID)
    )


def read_ime_input_shown(serial: str) -> bool:
    """Whether the IME window shows on [serial] right now (`ime_input_shown` of a fresh dump)."""
    return ime_input_shown(_dumpsys_input_method(serial))


def read_gboard_stylus_support(serial: str) -> bool:
    """Whether Gboard on [serial] supports stylus handwriting (`gboard_supports_stylus` of a fresh dump)."""
    return gboard_supports_stylus(_dumpsys_input_method(serial))


def _dumpsys_input_method(serial: str) -> str:
    return adb(serial, "shell", "-n", "dumpsys", "input_method")
