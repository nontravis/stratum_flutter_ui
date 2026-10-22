"""Android dumpsys captures for the system-bar checks (M3-T19).

The same three facts the probe contract read from files
(``<name>.window.txt``, ``<name>.activities.txt``, ``device.txt``'s
``sdk=``), captured live: each call runs one ``adb -s <serial> shell``
command and returns its stdout. The output feeds
``stratum_e2e.system_bars``, never a ``grep -q`` pipe: the parsers need
the whole dump, and a pipe would also hide adb's own exit code.
"""

from __future__ import annotations

import subprocess


def window_dump(serial: str) -> str:
    """Return the full ``dumpsys window`` output on [serial].

    The window dump is the Android verdict source of the icon and
    bar-visibility checks (``system_bars.icon_appearance``,
    ``bars_hidden``, ``bars_shown``).
    """
    return _adb(serial, "shell", "-n", "dumpsys", "window")


def activities_dump(serial: str) -> str:
    """Return the full ``dumpsys activity activities`` output on [serial].

    The activities dump is the only dump whose ActivityRecord block
    carries the ``taskDescription: label=`` the recents-label check reads;
    ``dumpsys activity recents`` does not reach it (android.sh:848-850).
    """
    return _adb(serial, "shell", "-n", "dumpsys", "activity", "activities")


def sdk_level(serial: str) -> int:
    """Return the Android API level of [serial] (``device.txt``'s ``sdk=``).

    The appearance parser reads ``apr=`` on API 30+ and the legacy
    ``vsysui=`` below, so the level picks the read.
    """
    level = _adb(serial, "shell", "-n", "getprop", "ro.build.version.sdk")
    stripped = level.strip()
    if not stripped.isdigit():
        raise ValueError(f"ro.build.version.sdk on {serial!r} is not a level: {stripped!r}")
    return int(stripped)


def _adb(serial: str, *args: str) -> str:
    """Run one adb command on [serial]; raises CalledProcessError on failure."""
    result = subprocess.run(
        ["adb", "-s", serial, *args],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout
