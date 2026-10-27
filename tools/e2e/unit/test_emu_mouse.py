"""Unit tests for the emulator-console mouse helper (no adb, no device)."""

from __future__ import annotations

import subprocess

import pytest

from stratum_e2e.android.emu_mouse import (
    center,
    double_tap,
    emu_mouse_args,
    swipe,
    tap,
)

MODULE = "stratum_e2e.android.emu_mouse"
SERIAL = "emulator-5554"


class RecordingRun:
    """subprocess.run stand-in that records every argv and its kwargs."""

    def __init__(self) -> None:
        self.calls: list[list[str]] = []
        self.kwargs: list[dict[str, object]] = []
        self.fail = False

    def __call__(self, argv: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        self.calls.append(argv)
        self.kwargs.append(kwargs)
        if self.fail and kwargs.get("check"):
            raise subprocess.CalledProcessError(1, argv)
        return subprocess.CompletedProcess(argv, 0, "OK\n", "")

    def mouse_events(self) -> list[list[str]]:
        """Return the arguments after `adb -s <serial>` for each call."""
        return [call[3:] for call in self.calls]


@pytest.fixture
def run(monkeypatch: pytest.MonkeyPatch) -> RecordingRun:
    recorder = RecordingRun()
    sleeps: list[float] = []
    monkeypatch.setattr(f"{MODULE}.subprocess.run", recorder)
    monkeypatch.setattr(f"{MODULE}.time.sleep", sleeps.append)
    return recorder


def test_center_of_rect() -> None:
    assert center({"x": 48, "y": 728, "width": 2464, "height": 96}) == (1280, 776)


def test_center_floors_odd_sizes() -> None:
    assert center({"x": 0, "y": 0, "width": 5, "height": 3}) == (2, 1)


def test_emu_mouse_args_down() -> None:
    assert emu_mouse_args(1280, 776, True) == ["emu", "event", "mouse", "1280", "776", "0", "1"]


def test_emu_mouse_args_up() -> None:
    assert emu_mouse_args(1280, 776, False) == ["emu", "event", "mouse", "1280", "776", "0", "0"]


def test_tap_is_down_then_up_at_one_point(run: RecordingRun) -> None:
    tap(SERIAL, 10, 20)

    assert run.calls[0][:3] == ["adb", "-s", SERIAL]
    assert run.mouse_events() == [
        emu_mouse_args(10, 20, True),
        emu_mouse_args(10, 20, False),
    ]


def test_double_tap_is_two_down_up_pairs(run: RecordingRun) -> None:
    double_tap(SERIAL, 10, 20)

    down, up = emu_mouse_args(10, 20, True), emu_mouse_args(10, 20, False)
    assert run.mouse_events() == [down, up, down, up]


def test_swipe_holds_down_through_every_point_then_lifts_at_the_last(run: RecordingRun) -> None:
    swipe(SERIAL, [(900, 1000), (1100, 1000), (1700, 1000)])

    assert run.mouse_events() == [
        emu_mouse_args(900, 1000, True),
        emu_mouse_args(1100, 1000, True),
        emu_mouse_args(1700, 1000, True),
        emu_mouse_args(1700, 1000, False),
    ]


@pytest.mark.parametrize("points", [[], [(1, 2)]])
def test_swipe_needs_two_points(run: RecordingRun, points: list[tuple[int, int]]) -> None:
    with pytest.raises(ValueError, match="two points"):
        swipe(SERIAL, points)

    assert run.calls == []


def test_a_failing_adb_call_raises(run: RecordingRun) -> None:
    run.fail = True

    with pytest.raises(subprocess.CalledProcessError):
        tap(SERIAL, 1, 2)
