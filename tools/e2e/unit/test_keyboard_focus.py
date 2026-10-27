"""Unit tests for the Tab walk helpers, on a fake clock and a scripted tree (no device)."""

from __future__ import annotations

import pytest

from stratum_e2e.android import keyboard_focus
from stratum_e2e.android.keyboard_focus import (
    LandedElsewhere,
    focus_label,
    tab_to_first_label,
    tab_to_next_label,
)

WAITS = "stratum_e2e.waits"
SERIAL = "emulator-5580"


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


@pytest.fixture(autouse=True)
def clock(monkeypatch: pytest.MonkeyPatch) -> FakeClock:
    fake = FakeClock()
    monkeypatch.setattr(f"{WAITS}.time.monotonic", fake.monotonic)
    monkeypatch.setattr(f"{WAITS}.time.sleep", fake.sleep)
    return fake


class ScriptedTree:
    """A driver whose keyboard focus changes only when `press_tab` runs: one script entry per press.

    While `touch` is true the next Tab only ends touch mode and moves no focus, as on Android.
    """

    def __init__(
        self, script: list[list[str]], focused: list[str] | None = None, touch: bool = False
    ) -> None:
        self.script = list(script)
        self.focused = focused or []
        self.touch = touch
        self.presses = 0
        self.capabilities = {"udid": SERIAL}

    def press_tab(self) -> None:
        self.presses += 1
        if self.touch:
            self.touch = False
            return
        self.focused = self.script.pop(0) if self.script else self.focused

    @property
    def page_source(self) -> str:
        nodes = "".join(f'<node content-desc="{label}" focused="true"/>' for label in self.focused)
        return f"<hierarchy>{nodes}</hierarchy>"


def test_focus_label_is_the_one_labeled_focused_node() -> None:
    assert focus_label(ScriptedTree([], ["Choose A"])) == "Choose A"


def test_focus_label_is_none_for_no_node_or_several() -> None:
    assert focus_label(ScriptedTree([])) is None
    assert focus_label(ScriptedTree([], ["Choose A", "Close"])) is None


def first_label(
    tree: ScriptedTree, expected: str, monkeypatch: pytest.MonkeyPatch, asked: list[str] | None = None
) -> None:
    def touch_mode(serial: str) -> bool:
        if asked is not None:
            asked.append(serial)
        return tree.touch

    monkeypatch.setattr(keyboard_focus, "touch_mode", touch_mode)
    tab_to_first_label(tree, tree.press_tab, expected)


def test_first_label_presses_one_tab_when_touch_mode_is_off(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    tree = ScriptedTree([["Choose A"]])
    asked: list[str] = []

    first_label(tree, "Choose A", monkeypatch, asked)

    assert tree.presses == 1
    assert asked[0] == SERIAL


def test_first_label_exits_touch_mode_with_one_tab_before_the_first_tab(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    tree = ScriptedTree([["Choose A"]], touch=True)

    first_label(tree, "Choose A", monkeypatch)

    assert tree.presses == 2
    assert tree.focused == ["Choose A"]


def test_first_label_fails_when_touch_mode_never_ends(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class Stuck(ScriptedTree):
        def press_tab(self) -> None:
            self.presses += 1

    tree = Stuck([["Choose A"]], touch=True)

    with pytest.raises(AssertionError, match="touch mode to end"):
        first_label(tree, "Choose A", monkeypatch)

    assert tree.presses == 1


def test_first_label_never_presses_again_when_the_first_tab_lands_nowhere(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    tree = ScriptedTree([[], ["Choose A"]])

    with pytest.raises(AssertionError, match="keyboard focus on 'Choose A' after a first Tab"):
        first_label(tree, "Choose A", monkeypatch)

    assert tree.presses == 1


def test_first_label_fails_at_once_when_another_label_takes_focus(
    clock: FakeClock, monkeypatch: pytest.MonkeyPatch
) -> None:
    tree = ScriptedTree([["Choose B"], ["Choose A"]])

    with pytest.raises(LandedElsewhere, match="landed on 'Choose B', expected 'Choose A'"):
        first_label(tree, "Choose A", monkeypatch)

    assert tree.presses == 1
    assert clock.now == 0.0


def test_first_label_fails_when_focus_leaves_the_label_within_the_hold(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class Drifting(ScriptedTree):
        reads = 0

        @property
        def page_source(self) -> str:
            Drifting.reads += 1
            self.focused = ["Choose A"] if Drifting.reads < 4 else ["Close"]
            return super().page_source

    tree = Drifting([["Choose A"]])

    with pytest.raises(AssertionError, match="to stay on 'Choose A'"):
        first_label(tree, "Choose A", monkeypatch)


def test_next_label_passes_when_focus_moves_to_the_expected_label() -> None:
    tree = ScriptedTree([["Choose B"]], ["Choose A"])

    tab_to_next_label(tree, tree.press_tab, "Choose A", "Choose B")

    assert tree.presses == 1


def test_next_label_fails_when_focus_skips_to_another_label() -> None:
    tree = ScriptedTree([["Close"]], ["Choose A"])

    with pytest.raises(AssertionError, match="keyboard focus on 'Choose B' after 'Choose A'"):
        tab_to_next_label(tree, tree.press_tab, "Choose A", "Choose B")


def test_next_label_fails_when_focus_stays_on_the_previous() -> None:
    tree = ScriptedTree([["Choose A"]], ["Choose A"])

    with pytest.raises(AssertionError, match="keyboard focus on 'Choose B'"):
        tab_to_next_label(tree, tree.press_tab, "Choose A", "Choose B")
