"""Android settle traps ported from the skill's `platforms/android.sh`: pure functions over adb text."""

from __future__ import annotations

import math
import re

LOAD_LIMIT = 2.0

BOOT_SETTINGS: tuple[tuple[str, str], ...] = (
    ("stylus_handwriting_enabled", "0"),
    ("immersive_mode_confirmations", "confirmed"),
)

_CURRENT_ID = "mCurId="
_BOUND_TO_METHOD = "mBoundToMethod=true"
_CURRENT_FOCUS = "mCurrentFocus="
_UNKNOWN_PACKAGE = "unknown"
_ANR_MARKERS = ("Application Not Responding", "isn't responding")
_ANR_TITLE = re.compile(r"Application Not Responding: ([A-Za-z0-9_.]+)")
_ANR_ISNT_RESPONDING = re.compile(r"([A-Za-z0-9_.]+) isn't responding")
_LOAD_AVERAGE = re.compile(r"load average: ([0-9]+\.[0-9]+)")
_PING_TIME = re.compile(r"time=([0-9.]+)")
_DRIVE_PREFIX = re.compile(r"^[VDIWEF]/flutter \([ \t]*[0-9]+\): ")


def _first_line_with(text: str, needle: str) -> str | None:
    return next((line for line in text.splitlines() if needle in line), None)


def ime_bound(dumpsys_input_method: str) -> bool:
    """Whether `dumpsys input_method` shows a bound IME, in either shape it prints.

    Through API 36 the IME sits on an `mCurId=` line (never empty, never `null`); API 37 drops that line and prints
    `mBoundToMethod=true` once an IME is bound. A reply with neither, or `mBoundToMethod=false`, is not bound.
    """
    current = _first_line_with(dumpsys_input_method, _CURRENT_ID)
    if current is not None:
        ime = current.split(_CURRENT_ID, 1)[1].split(maxsplit=1)
        return bool(ime) and ime[0] != "null"
    return _BOUND_TO_METHOD in dumpsys_input_method


def focused_anr_package(dumpsys_window: str) -> str | None:
    """The package named by an ANR dialog that holds window focus; None when no ANR dialog has focus.

    Reads the first `mCurrentFocus=` line only and matches both AOSP titles: `Application Not Responding: <pkg>` and
    `<pkg> isn't responding`. An ANR title that names no package returns `"unknown"`, so the device still reads as
    unsettled.
    """
    focus = _first_line_with(dumpsys_window, _CURRENT_FOCUS)
    if focus is None or not any(marker in focus for marker in _ANR_MARKERS):
        return None
    match = _ANR_TITLE.search(focus) or _ANR_ISNT_RESPONDING.search(focus)
    return match.group(1) if match else _UNKNOWN_PACKAGE


def guest_load(uptime_out: str) -> float:
    """The one-minute load average in `adb shell uptime` output; infinity when the output carries none."""
    match = _LOAD_AVERAGE.search(uptime_out)
    return float(match.group(1)) if match else math.inf


def settle_reasons(load: float, anr_package: str | None, ime: bool) -> list[str]:
    """One line per unmet settle gate (load above `LOAD_LIMIT`, an ANR window focused, no IME bound); empty when settled."""
    reasons: list[str] = []
    if load > LOAD_LIMIT:
        shown = "unknown" if math.isinf(load) else f"{load:g}"
        reasons.append(f"guest load {shown} > {LOAD_LIMIT:g}")
    if anr_package is not None:
        reasons.append(f"an ANR window holds focus: {anr_package}")
    if not ime:
        reasons.append("no IME is bound (dumpsys input_method)")
    return reasons


def clock_jumped(ping_out: str) -> bool:
    """Whether the first ping time reads zero, the sign of a guest clock jump."""
    match = _PING_TIME.search(ping_out)
    return match is not None and float(match.group(1)) == 0.0


def settings_apply_argv(adb: str, serial: str) -> list[list[str]]:
    """One `settings put secure` command per `BOOT_SETTINGS` row."""
    return [[adb, "-s", serial, "shell", "settings", "put", "secure", key, value] for key, value in BOOT_SETTINGS]


def settings_restore_argv(adb: str, serial: str) -> list[list[str]]:
    """One `settings delete secure` command per `BOOT_SETTINGS` key; the AVDs are shared with manual use."""
    return [[adb, "-s", serial, "shell", "settings", "delete", "secure", key] for key, _ in BOOT_SETTINGS]


def strip_drive_prefix(text: str) -> str:
    """Remove the `<L>/flutter ( <pid>): ` logcat prefix once per line, and the CR that adb logcat may end a line with."""
    stripped: list[str] = []
    for line in text.split("\n"):
        line = line.removesuffix("\r")
        stripped.append(_DRIVE_PREFIX.sub("", line, count=1))
    return "\n".join(stripped)
