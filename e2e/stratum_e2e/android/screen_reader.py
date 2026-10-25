"""Drive TalkBack from outside the app: speech replies, the actions menu, touch focus, swipes.

TalkBack's keyboard shortcuts run on the uhid keyboard, measured on the e2e AVD (TalkBack 15):
Alt+Space opens the TalkBack menu, Alt+Enter on its `Actions` entry opens the focused node's
actions, Alt+Right steps through them and Alt+Enter runs the one in focus. The menu lives in a
TalkBack window Appium cannot read, so its entries are read from the speech log.
"""

from __future__ import annotations

import time
from typing import Any

from stratum_e2e.android import emu_mouse
from stratum_e2e.android.talkback import TalkBackLog, a11y_focused
from stratum_e2e.android.uhid_keyboard import (
    KEY_ENTER,
    KEY_RIGHT,
    KEY_SPACE,
    MOD_LALT,
    UhidKeyboard,
)
from stratum_e2e.waits import wait_until

SPEECH_TIMEOUT_S = 3
SPEECH_QUIET_S = 1.2
POLL_INTERVAL_S = 0.25
FOCUS_TIMEOUT_S = 10

# One pass over an actions menu: its actions, Cancel, and the title spoken on wrap-around.
MENU_STEPS = 8
MENU_TITLE = "TalkBack menu"
MENU_ACTIONS_ENTRY = "Actions"
MENU_CANCEL = "Cancel"

# One-finger vertical drag: TalkBack reads a fast up or down swipe on a slider as increase or decrease.
SWIPE_DISTANCE_PX = 400
SWIPE_STEPS = 6


def entry_name(utterance: str) -> str:
    """Return the menu entry an utterance names: no `selected, ` prefix, no role suffix."""
    return utterance.removeprefix("selected, ").split(", ")[0]


def settled_speech(talkback: TalkBackLog, timeout_s: float = SPEECH_TIMEOUT_S) -> list[str]:
    """Return the speech since the last mark once it is non-empty and has been quiet for SPEECH_QUIET_S.

    TalkBack speaks in parts (a name, then a hint seconds later), so a reply ends on silence,
    never on the first part. Polls every POLL_INTERVAL_S, never a fixed sleep. Returns what
    was heard when [timeout_s] passes first: empty after [timeout_s] of silence, so a caller
    that needs speech asserts on the result.
    """
    deadline = time.monotonic() + timeout_s
    spoken: list[str] = []
    quiet_since = time.monotonic()
    while time.monotonic() < deadline:
        time.sleep(POLL_INTERVAL_S)
        now = talkback.since_mark()
        if now != spoken:
            spoken, quiet_since = now, time.monotonic()
        elif spoken and time.monotonic() - quiet_since >= SPEECH_QUIET_S:
            break
    return spoken


def press_and_hear(
    keyboard: UhidKeyboard, talkback: TalkBackLog, usage: int, mods: int = 0
) -> list[str]:
    """Press a key and return TalkBack's whole reply once it has been quiet for SPEECH_QUIET_S.

    Empty after SPEECH_TIMEOUT_S of silence (see `settled_speech`).
    """
    talkback.mark()
    keyboard.press(usage, mods)
    return settled_speech(talkback)


def step_through(
    driver: Any, keyboard: UhidKeyboard, talkback: TalkBackLog, steps: int
) -> tuple[list[str], list[str]]:
    """Move TalkBack's focus forward [steps] times with Alt+Right and record what it did.

    Each step presses Alt+Right and waits for the reply to go quiet (`press_and_hear`), then
    reads the node that holds accessibility focus. Return `(heard, focused)`: every utterance
    of every step in order, and one entry per step holding the label of the focused node
    (the first when several hold it, "" when none does). Starts from the focus TalkBack holds
    now; the caller puts it on the starting node first. Reused by every test that walks a
    screen's reading order.
    """
    heard: list[str] = []
    focused: list[str] = []
    for _ in range(steps):
        heard.extend(press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT))
        holders = a11y_focused(driver.page_source)
        focused.append(holders[0] if holders else "")
    return heard, focused


def open_actions(keyboard: UhidKeyboard, talkback: TalkBackLog) -> list[str]:
    """Open the focused node's actions: TalkBack menu, then its `Actions` entry.

    Return the reply of the second step: the `Actions` title and the first action.
    Raises AssertionError when either step does not speak its entry.
    """
    menu = press_and_hear(keyboard, talkback, KEY_SPACE, MOD_LALT)
    assert MENU_TITLE in menu, f"TalkBack menu did not open, heard {menu}"
    actions = press_and_hear(keyboard, talkback, KEY_ENTER, MOD_LALT)
    assert any(entry_name(text) == MENU_ACTIONS_ENTRY for text in actions), (
        f"the Actions entry did not open, heard {actions}"
    )
    return actions


def run_action(keyboard: UhidKeyboard, talkback: TalkBackLog, name: str) -> None:
    """Open the focused node's actions, step to [name] and activate it.

    Leaves a mark just before the activation, so `talkback.since_mark()` reads what the
    action made TalkBack say. Raises AssertionError when [name] is not offered within
    one pass of the menu.
    """
    heard = open_actions(keyboard, talkback)
    for _ in range(MENU_STEPS):
        if any(entry_name(text) == name for text in heard):
            talkback.mark()
            keyboard.press(KEY_ENTER, MOD_LALT)
            return
        heard = press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
    raise AssertionError(f"{name!r} was not offered in {MENU_STEPS} steps")


def focus_by_touch(driver: Any, element: Any, label: str) -> None:
    """Explore-by-touch: touch the centre of [element] and wait until TalkBack holds focus on [label]."""
    x, y = emu_mouse.center(element.rect)
    emu_mouse.tap(str(driver.capabilities["udid"]), x, y)
    wait_until(
        lambda: a11y_focused(driver.page_source) == [label],
        f"TalkBack focus on {label}",
        timeout_s=FOCUS_TIMEOUT_S,
    )


def vertical_swipe_points(x: int, y: int, *, up: bool) -> list[tuple[int, int]]:
    """Return the drag points of a vertical swipe centred on ([x], [y]); `up` drags upward."""
    start = y + SWIPE_DISTANCE_PX // 2 if up else y - SWIPE_DISTANCE_PX // 2
    end = y - SWIPE_DISTANCE_PX // 2 if up else y + SWIPE_DISTANCE_PX // 2
    return [(x, start + (end - start) * step // SWIPE_STEPS) for step in range(SWIPE_STEPS + 1)]


def swipe_vertically(serial: str, x: int, y: int, *, up: bool) -> None:
    """Drag one finger up or down across ([x], [y]) on device [serial]."""
    emu_mouse.swipe(serial, vertical_swipe_points(x, y, up=up))
