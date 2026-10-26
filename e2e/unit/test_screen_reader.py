"""Unit tests for the TalkBack driving helpers, on a fake clock (no adb, no device)."""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.android import screen_reader
from stratum_e2e.android.screen_reader import (
    MENU_STEPS,
    SPEECH_TIMEOUT_S,
    entry_name,
    focus_by_touch,
    open_actions,
    press_and_hear,
    run_action,
    settled_speech,
    step_through,
    swipe_vertically,
    vertical_swipe_points,
)
from stratum_e2e.android.uhid_keyboard import KEY_ENTER, KEY_RIGHT, KEY_SPACE, MOD_LALT

MODULE = "stratum_e2e.android.screen_reader"
SERIAL = "emulator-5554"

MENU_OPENS = ["TalkBack menu", "selected, Read from focused item, In list"]
ACTIONS_OPEN = ["Actions", "Show menu, In list"]


class FakeClock:
    """A monotonic clock that only `sleep` advances."""

    def __init__(self) -> None:
        self.now = 0.0

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


class ScriptedDevice:
    """A keyboard and a speech log in one: each key press makes the next scripted reply audible."""

    def __init__(self, replies: list[list[str]]) -> None:
        self.replies = list(replies)
        self.presses: list[tuple[int, int]] = []
        self.marks = 0
        self.idles = 0
        self._spoken: list[str] = []

    def press(self, usage: int, mods: int = 0) -> None:
        self.presses.append((usage, mods))
        self._spoken = self.replies.pop(0) if self.replies else []

    def wait_idle(self) -> None:
        self.idles += 1

    def mark(self) -> None:
        self.marks += 1
        self._spoken = []

    def since_mark(self) -> list[str]:
        return list(self._spoken)


@pytest.fixture
def clock(monkeypatch: pytest.MonkeyPatch) -> FakeClock:
    fake = FakeClock()
    monkeypatch.setattr(f"{MODULE}.time.monotonic", fake.monotonic)
    monkeypatch.setattr(f"{MODULE}.time.sleep", fake.sleep)
    return fake


def test_entry_name_drops_selected_prefix_and_role_suffix() -> None:
    assert entry_name("selected, Move up, In list") == "Move up"
    assert entry_name("Cancel, Button, Out of list") == "Cancel"
    assert entry_name("Actions") == "Actions"


def test_press_and_hear_returns_the_reply_after_it_goes_quiet(clock: FakeClock) -> None:
    device = ScriptedDevice([["Item 2", "Double-tap to activate"]])

    heard = press_and_hear(device, device, KEY_RIGHT, MOD_LALT)  # type: ignore[arg-type]

    assert heard == ["Item 2", "Double-tap to activate"]
    assert device.presses == [(KEY_RIGHT, MOD_LALT)]
    assert clock.now < SPEECH_TIMEOUT_S


def test_press_and_hear_is_empty_after_the_timeout_of_silence(clock: FakeClock) -> None:
    device = ScriptedDevice([[]])

    assert press_and_hear(device, device, KEY_RIGHT) == []  # type: ignore[arg-type]
    assert clock.now >= SPEECH_TIMEOUT_S


def test_open_actions_presses_alt_space_then_alt_enter(clock: FakeClock) -> None:
    device = ScriptedDevice([MENU_OPENS, ACTIONS_OPEN])

    assert open_actions(device, device) == ACTIONS_OPEN  # type: ignore[arg-type]
    assert device.presses == [(KEY_SPACE, MOD_LALT), (KEY_ENTER, MOD_LALT)]


def test_open_actions_fails_when_the_menu_does_not_open(clock: FakeClock) -> None:
    device = ScriptedDevice([["Item 2"]])

    with pytest.raises(AssertionError, match="TalkBack menu did not open"):
        open_actions(device, device)  # type: ignore[arg-type]


def test_open_actions_fails_when_the_actions_entry_does_not_open(clock: FakeClock) -> None:
    device = ScriptedDevice([MENU_OPENS, ["Cancel, Button"]])

    with pytest.raises(AssertionError, match="Actions entry did not open"):
        open_actions(device, device)  # type: ignore[arg-type]


def test_run_action_activates_an_action_heard_on_open(clock: FakeClock) -> None:
    device = ScriptedDevice([MENU_OPENS, ACTIONS_OPEN, []])

    run_action(device, device, "Show menu")  # type: ignore[arg-type]

    assert device.presses[-1] == (KEY_ENTER, MOD_LALT)
    assert len(device.presses) == 3


def test_run_action_steps_right_until_the_action_is_heard(clock: FakeClock) -> None:
    device = ScriptedDevice(
        [MENU_OPENS, ["Actions", "Move up, In list"], ["Move down, In list"], ["Delete, In list"], []]
    )

    run_action(device, device, "Delete")  # type: ignore[arg-type]

    assert device.presses[2:] == [(KEY_RIGHT, MOD_LALT), (KEY_RIGHT, MOD_LALT), (KEY_ENTER, MOD_LALT)]


def test_run_action_marks_just_before_the_activation(clock: FakeClock) -> None:
    device = ScriptedDevice([MENU_OPENS, ACTIONS_OPEN, ["Menu shown"]])

    run_action(device, device, "Show menu")  # type: ignore[arg-type]

    assert device.since_mark() == ["Menu shown"]


def test_run_action_fails_when_the_action_is_not_offered(clock: FakeClock) -> None:
    device = ScriptedDevice([MENU_OPENS, ACTIONS_OPEN] + [["Cancel, Button"]] * MENU_STEPS)

    with pytest.raises(AssertionError, match="'Delete' was not offered"):
        run_action(device, device, "Delete")  # type: ignore[arg-type]

    assert (KEY_ENTER, MOD_LALT) not in device.presses[2:]


def test_vertical_swipe_points_run_from_below_to_above_for_up() -> None:
    points = vertical_swipe_points(1280, 800, up=True)

    assert points[0] == (1280, 1000)
    assert points[-1] == (1280, 600)
    assert len(points) == screen_reader.SWIPE_STEPS + 1
    assert [y for _, y in points] == sorted((y for _, y in points), reverse=True)


def test_vertical_swipe_points_run_from_above_to_below_for_down() -> None:
    points = vertical_swipe_points(1280, 800, up=False)

    assert (points[0], points[-1]) == ((1280, 600), (1280, 1000))


def test_swipe_vertically_drags_the_points_on_the_device(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: list[Any] = []
    monkeypatch.setattr(f"{MODULE}.emu_mouse.swipe", lambda serial, points: seen.append((serial, points)))

    swipe_vertically(SERIAL, 10, 20, up=True)

    assert seen == [(SERIAL, vertical_swipe_points(10, 20, up=True))]


class FakeElement:
    rect = {"x": 100, "y": 200, "width": 40, "height": 20}


class FakeDriver:
    capabilities = {"udid": SERIAL}

    def __init__(self, focused: list[str]) -> None:
        self.focused = focused

    @property
    def page_source(self) -> str:
        nodes = "".join(f'<node content-desc="{label}" a11y-focused="true"/>' for label in self.focused)
        return f"<hierarchy>{nodes}</hierarchy>"


class WalkingDriver:
    """A driver whose accessibility focus is the next scripted label on each page-source read."""

    def __init__(self, labels: list[str]) -> None:
        self.labels = list(labels)

    @property
    def page_source(self) -> str:
        label = self.labels.pop(0) if self.labels else ""
        node = f'<node content-desc="{label}" a11y-focused="true"/>' if label else ""
        return f"<hierarchy>{node}</hierarchy>"


def test_step_through_presses_alt_right_and_collects_speech_and_focus(clock: FakeClock) -> None:
    device = ScriptedDevice([["Heading", "Heading text"], ["Group"], ["Street, text field"]])
    driver = WalkingDriver(["Heading", "Group", "Street"])

    heard, focused = step_through(driver, device, device, 3)  # type: ignore[arg-type]

    assert device.presses == [(KEY_RIGHT, MOD_LALT)] * 3
    assert heard == ["Heading", "Heading text", "Group", "Street, text field"]
    assert focused == ["Heading", "Group", "Street"]


def test_step_through_reads_an_empty_focus_when_no_node_holds_it(clock: FakeClock) -> None:
    device = ScriptedDevice([["Heading"], []])
    driver = WalkingDriver(["Heading"])

    heard, focused = step_through(driver, device, device, 2)  # type: ignore[arg-type]

    assert heard == ["Heading"]
    assert focused == ["Heading", ""]


def test_step_through_with_zero_steps_presses_nothing(clock: FakeClock) -> None:
    device = ScriptedDevice([["Heading"]])

    assert step_through(WalkingDriver([]), device, device, 0) == ([], [])  # type: ignore[arg-type]
    assert device.presses == []


def test_settled_speech_returns_the_speech_once_it_has_gone_quiet(clock: FakeClock) -> None:
    device = ScriptedDevice([])
    device._spoken = ["Heading"]

    assert settled_speech(device) == ["Heading"]  # type: ignore[arg-type]
    assert clock.now >= screen_reader.SPEECH_QUIET_S
    assert clock.now < SPEECH_TIMEOUT_S


def test_settled_speech_waits_for_late_speech_before_it_counts_as_quiet(clock: FakeClock) -> None:
    class LateSpeech:
        def since_mark(self) -> list[str]:
            if clock.now < 1.0:
                return []
            return ["Heading"] if clock.now < 2.0 else ["Heading", "Group"]

    assert settled_speech(LateSpeech(), timeout_s=10) == ["Heading", "Group"]  # type: ignore[arg-type]


def test_settled_speech_is_empty_after_the_timeout_of_silence(clock: FakeClock) -> None:
    device = ScriptedDevice([])

    assert settled_speech(device, timeout_s=5) == []  # type: ignore[arg-type]
    assert clock.now >= 5


def test_step_through_reads_the_first_node_when_several_hold_focus(clock: FakeClock) -> None:
    device = ScriptedDevice([["Heading"]])

    _, focused = step_through(FakeDriver(["A", "B"]), device, device, 1)  # type: ignore[arg-type]

    assert focused == ["A"]


def test_focus_by_touch_taps_the_centre_and_waits_for_the_label(
    clock: FakeClock, monkeypatch: pytest.MonkeyPatch
) -> None:
    taps: list[tuple[str, int, int]] = []
    monkeypatch.setattr(f"{MODULE}.emu_mouse.tap", lambda s, x, y: taps.append((s, x, y)))
    talkback = ScriptedDevice([])

    focus_by_touch(FakeDriver(["Menu target"]), FakeElement(), "Menu target", talkback)  # type: ignore[arg-type]

    assert taps == [(SERIAL, 120, 210)]
    assert talkback.idles == 1


def test_focus_by_touch_waits_for_idle_before_it_taps(
    clock: FakeClock, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The touch lands only once a node holds focus and TalkBack finished the window's speech."""
    order: list[str] = []

    class LateFocusDriver:
        capabilities = {"udid": SERIAL}

        def __init__(self, label: str) -> None:
            self._label = label

        @property
        def page_source(self) -> str:
            order.append("page_source")
            return f'<hierarchy><node content-desc="{self._label}" a11y-focused="true"/></hierarchy>'

    class RecordingTalkBack(ScriptedDevice):
        def wait_idle(self) -> None:  # type: ignore[override]
            order.append("wait_idle")
            super().wait_idle()

    def tap(serial: str, x: int, y: int) -> None:
        order.append("tap")

    monkeypatch.setattr(f"{MODULE}.emu_mouse.tap", tap)
    talkback = RecordingTalkBack([])
    driver = LateFocusDriver("Menu target")

    focus_by_touch(driver, FakeElement(), "Menu target", talkback)  # type: ignore[arg-type]

    assert order == ["page_source", "wait_idle", "tap", "page_source"]


def test_focus_by_touch_times_out_when_no_node_ever_holds_focus(
    clock: FakeClock, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(f"{MODULE}.emu_mouse.tap", lambda s, x, y: pytest.fail("tapped before focus"))
    talkback = ScriptedDevice([])
    driver = FakeDriver(["", "", "", "", ""])

    with pytest.raises(AssertionError, match="a11y focus to land"):
        focus_by_touch(driver, FakeElement(), "Menu target", talkback)  # type: ignore[arg-type]
    assert talkback.idles == 0


def test_focus_by_touch_times_out_when_another_node_holds_focus(
    clock: FakeClock, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(f"{MODULE}.emu_mouse.tap", lambda s, x, y: None)

    with pytest.raises(AssertionError, match="TalkBack focus on Menu target"):
        focus_by_touch(
            FakeDriver(["Elsewhere"]), FakeElement(), "Menu target", ScriptedDevice([])
        )  # type: ignore[arg-type]
