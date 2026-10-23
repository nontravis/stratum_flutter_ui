"""Kernel-level USB keyboard on an Android guest through `hid` and /dev/uhid (design section 8)."""

from __future__ import annotations

import json
import subprocess
import time
from types import TracebackType
from typing import IO

MOD_LALT = 0x04
KEY_ENTER = 0x28
KEY_TAB = 0x2B
KEY_SPACE = 0x2C
KEY_RIGHT = 0x4F
KEY_UP = 0x52
KEY_DOWN = 0x51
KEY_MENU = 0x65
MAX_HOLD_MS = 20

REGISTER_SETTLE_S = 2.5
MODIFIER_SETTLE_S = 0.08
RELEASE_SETTLE_S = 0.1
CLOSE_TIMEOUT_S = 10

# USB HID boot-keyboard report descriptor: 8 modifier bits, 1 reserved byte, 5 LEDs, 6 key slots.
_BOOT_KEYBOARD_DESCRIPTOR = [
    5, 1, 9, 6, 161, 1, 5, 7, 25, 224, 41, 231, 21, 0, 37, 1, 117, 1, 149, 8, 129, 2, 149, 1, 117, 8,
    129, 1, 149, 5, 117, 1, 5, 8, 25, 1, 41, 5, 145, 2, 149, 1, 117, 3, 145, 1, 149, 6, 117, 8, 21, 0,
    37, 101, 5, 7, 25, 0, 41, 101, 129, 0, 192,
]
_VENDOR_ID = 0x1234
_PRODUCT_ID = 0x5678


def key_report(mods: int, usage: int) -> list[int]:
    """Return the 8-byte boot-keyboard report holding [mods] and one key [usage]."""
    return [mods, 0, usage, 0, 0, 0, 0, 0]


def register_line() -> str:
    """Return the one-line JSON that registers the keyboard with `hid`."""
    return json.dumps(
        {
            "id": 1,
            "command": "register",
            "name": "Spike HID Keyboard",
            "vid": _VENDOR_ID,
            "pid": _PRODUCT_ID,
            "bus": "usb",
            "descriptor": _BOOT_KEYBOARD_DESCRIPTOR,
        }
    )


def report_line(report: list[int]) -> str:
    """Return the one-line JSON that sends [report] to the registered keyboard."""
    return json.dumps({"id": 1, "command": "report", "report": report})


class UhidKeyboard:
    """One long-lived `adb shell hid -` process holding a registered keyboard.

    Use as a context manager. Raises RuntimeError from `press` outside the `with` block.
    """

    def __init__(self, serial: str) -> None:
        self._serial = serial
        self._process: subprocess.Popen[str] | None = None

    def __enter__(self) -> UhidKeyboard:
        self._process = subprocess.Popen(
            ["adb", "-s", self._serial, "shell", "hid", "-"],
            stdin=subprocess.PIPE,
            text=True,
        )
        self._send(register_line())
        time.sleep(REGISTER_SETTLE_S)
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        process, self._process = self._process, None
        if process is None:
            return
        try:
            if process.stdin is not None:
                process.stdin.close()
            process.wait(timeout=CLOSE_TIMEOUT_S)
        except subprocess.TimeoutExpired:
            process.kill()

    def press(self, usage: int, mods: int = 0, hold_ms: int = 10) -> None:
        """Press key [usage] with modifier bits [mods], holding it [hold_ms] milliseconds.

        Raises ValueError when [hold_ms] is outside 1..MAX_HOLD_MS: a longer hold can repeat.
        """
        if not 1 <= hold_ms <= MAX_HOLD_MS:
            raise ValueError(f"hold_ms must be 1..{MAX_HOLD_MS}, got {hold_ms}")
        if mods:
            self._send(report_line(key_report(mods, 0)))
            time.sleep(MODIFIER_SETTLE_S)
        self._send(report_line(key_report(mods, usage)))
        time.sleep(hold_ms / 1000)
        self._send(report_line(key_report(mods, 0)))
        if mods:
            self._send(report_line(key_report(0, 0)))
        time.sleep(RELEASE_SETTLE_S)

    def _send(self, line: str) -> None:
        stdin = self._stdin()
        stdin.write(line + "\n")
        stdin.flush()

    def _stdin(self) -> IO[str]:
        if self._process is None or self._process.stdin is None:
            raise RuntimeError("UhidKeyboard is used inside its `with` context only")
        return self._process.stdin
