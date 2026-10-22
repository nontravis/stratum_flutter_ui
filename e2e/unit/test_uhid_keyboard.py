"""Unit tests for the uhid keyboard helper (no adb, no device)."""

from __future__ import annotations

import json
import subprocess
from collections.abc import Callable

import pytest

from stratum_e2e.android.uhid_keyboard import (
    KEY_DOWN,
    KEY_TAB,
    KEY_UP,
    MAX_HOLD_MS,
    MOD_LALT,
    UhidKeyboard,
    key_report,
    register_line,
    report_line,
)

MODULE = "stratum_e2e.android.uhid_keyboard"
SERIAL = "emulator-5554"


class FakeStdin:
    """Stdin pipe that records every written line and the order of close."""

    def __init__(self, events: list[str]) -> None:
        self._events = events
        self.lines: list[str] = []
        self.closed = False

    def write(self, text: str) -> int:
        self.lines.append(text)
        self._events.append("write")
        return len(text)

    def flush(self) -> None:
        self._events.append("flush")

    def close(self) -> None:
        self.closed = True
        self._events.append("close")


class FakeProcess:
    """Popen stand-in: records argv, stdin lines, wait and kill."""

    def __init__(self, argv: list[str], events: list[str], hang_on_wait: bool) -> None:
        self.argv = argv
        self.stdin = FakeStdin(events)
        self.killed = False
        self._hang_on_wait = hang_on_wait

    def wait(self, timeout: float | None = None) -> int:
        if self._hang_on_wait:
            raise subprocess.TimeoutExpired(self.argv, timeout or 0)
        return 0

    def kill(self) -> None:
        self.killed = True


class FakeHid:
    """Everything the keyboard touched: the process, the sleeps, the event order."""

    def __init__(self) -> None:
        self.processes: list[FakeProcess] = []
        self.sleeps: list[float] = []
        self.events: list[str] = []
        self.hang_on_wait = False

    @property
    def process(self) -> FakeProcess:
        return self.processes[0]

    @property
    def reports(self) -> list[list[int]]:
        sent = [json.loads(line) for line in self.process.stdin.lines]
        return [m["report"] for m in sent if m["command"] == "report"]


@pytest.fixture
def fake_hid(monkeypatch: pytest.MonkeyPatch) -> FakeHid:
    hid = FakeHid()

    def popen(argv: list[str], **_: object) -> FakeProcess:
        process = FakeProcess(argv, hid.events, hid.hang_on_wait)
        hid.processes.append(process)
        return process

    def sleep(seconds: float) -> None:
        hid.sleeps.append(seconds)
        hid.events.append("sleep")

    monkeypatch.setattr(f"{MODULE}.subprocess.Popen", popen)
    monkeypatch.setattr(f"{MODULE}.time.sleep", sleep)
    return hid


def test_alt_up_report() -> None:
    assert key_report(MOD_LALT, KEY_UP) == [0x04, 0, 0x52, 0, 0, 0, 0, 0]


def test_key_constants() -> None:
    assert (KEY_TAB, KEY_UP, KEY_DOWN, MOD_LALT, MAX_HOLD_MS) == (0x2B, 0x52, 0x51, 0x04, 20)


def test_report_line_is_one_json_line() -> None:
    line = report_line(key_report(0, KEY_TAB))

    assert "\n" not in line
    assert json.loads(line) == {"id": 1, "command": "report", "report": [0, 0, 0x2B, 0, 0, 0, 0, 0]}


def test_register_line_describes_a_usb_boot_keyboard() -> None:
    message = json.loads(register_line())

    assert "\n" not in register_line()
    assert message["command"] == "register"
    assert message["bus"] == "usb"
    assert (message["vid"], message["pid"]) == (4660, 22136)
    assert message["descriptor"][:4] == [5, 1, 9, 6]
    assert all(isinstance(byte, int) and 0 <= byte <= 255 for byte in message["descriptor"])


def test_enter_opens_one_hid_shell_and_waits_after_register(fake_hid: FakeHid) -> None:
    with UhidKeyboard(SERIAL):
        assert fake_hid.process.argv == ["adb", "-s", SERIAL, "shell", "hid", "-"]
        assert json.loads(fake_hid.process.stdin.lines[0])["command"] == "register"
        assert fake_hid.events == ["write", "flush", "sleep"]
        assert fake_hid.sleeps == [2.5]

    assert len(fake_hid.processes) == 1


def test_exit_closes_stdin_without_kill(fake_hid: FakeHid) -> None:
    with UhidKeyboard(SERIAL):
        pass

    assert fake_hid.process.stdin.closed
    assert not fake_hid.process.killed


def test_exit_kills_a_process_that_will_not_stop(fake_hid: FakeHid) -> None:
    fake_hid.hang_on_wait = True

    with UhidKeyboard(SERIAL):
        pass

    assert fake_hid.process.killed


def test_exit_still_closes_when_the_body_raises(fake_hid: FakeHid) -> None:
    with pytest.raises(RuntimeError, match="boom"), UhidKeyboard(SERIAL):
        raise RuntimeError("boom")

    assert fake_hid.process.stdin.closed


def test_press_sends_down_then_release(fake_hid: FakeHid) -> None:
    with UhidKeyboard(SERIAL) as keyboard:
        keyboard.press(KEY_TAB)

    assert fake_hid.reports == [key_report(0, KEY_TAB), key_report(0, 0)]
    assert 0.010 in fake_hid.sleeps


def test_press_with_modifier_holds_it_around_the_key(fake_hid: FakeHid) -> None:
    with UhidKeyboard(SERIAL) as keyboard:
        keyboard.press(KEY_UP, mods=MOD_LALT)

    assert fake_hid.reports == [
        key_report(MOD_LALT, 0),
        key_report(MOD_LALT, KEY_UP),
        key_report(MOD_LALT, 0),
        key_report(0, 0),
    ]


def test_press_holds_the_key_for_hold_ms(fake_hid: FakeHid) -> None:
    with UhidKeyboard(SERIAL) as keyboard:
        keyboard.press(KEY_TAB, hold_ms=MAX_HOLD_MS)

    assert 0.020 in fake_hid.sleeps


@pytest.mark.parametrize("hold_ms", [MAX_HOLD_MS + 1, 80, 0, -1])
def test_press_rejects_hold_outside_one_to_20_ms(fake_hid: FakeHid, hold_ms: int) -> None:
    with UhidKeyboard(SERIAL) as keyboard, pytest.raises(ValueError, match="hold_ms"):
        keyboard.press(KEY_TAB, hold_ms=hold_ms)

    assert fake_hid.reports == []


def test_press_outside_the_context_raises(fake_hid: FakeHid) -> None:
    press: Callable[[int], None] = UhidKeyboard(SERIAL).press

    with pytest.raises(RuntimeError, match="context"):
        press(KEY_TAB)

    assert fake_hid.processes == []
