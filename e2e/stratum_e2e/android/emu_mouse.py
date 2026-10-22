"""Kernel touch through the emulator console `adb emu event mouse` (design section 8)."""

from __future__ import annotations

import subprocess
import time

TAP_HOLD_S = 0.05


def center(rect: dict[str, int]) -> tuple[int, int]:
    """Return the integer centre of an Appium element rect (`x`, `y`, `width`, `height`)."""
    return rect["x"] + rect["width"] // 2, rect["y"] + rect["height"] // 2


def emu_mouse_args(x: int, y: int, down: bool) -> list[str]:
    """Return the adb arguments after `-s <serial>` for one mouse event at ([x], [y])."""
    return ["emu", "event", "mouse", str(x), str(y), "0", "1" if down else "0"]


def tap(serial: str, x: int, y: int) -> None:
    """Touch ([x], [y]) once on device [serial]."""
    _send(serial, x, y, down=True)
    time.sleep(TAP_HOLD_S)
    _send(serial, x, y, down=False)


def double_tap(serial: str, x: int, y: int) -> None:
    """Touch ([x], [y]) twice in quick succession: TalkBack's activate gesture."""
    for _ in range(2):
        _send(serial, x, y, down=True)
        _send(serial, x, y, down=False)


def swipe(serial: str, points: list[tuple[int, int]]) -> None:
    """Drag through [points] in order, lifting at the last one.

    Raises ValueError for fewer than two points.
    """
    if len(points) < 2:
        raise ValueError("a swipe needs at least two points")
    for x, y in points:
        _send(serial, x, y, down=True)
    last_x, last_y = points[-1]
    _send(serial, last_x, last_y, down=False)


def _send(serial: str, x: int, y: int, *, down: bool) -> None:
    subprocess.run(
        ["adb", "-s", serial, *emu_mouse_args(x, y, down)],
        check=True,
        capture_output=True,
        text=True,
    )
