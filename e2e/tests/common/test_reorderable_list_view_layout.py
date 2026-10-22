"""Reorder list on Android: TalkBack takes Alt+Up, offers valid moves, moves and speaks.

Drives the `common/reorderable_list_view_layout` fixture (FO-06 US-11). TalkBack's actions
for the focused item open through its own keyboard shortcuts on the uhid keyboard, measured
on the e2e AVD (TalkBack 15): Alt+Space opens the TalkBack menu, Alt+Enter on its `Actions`
entry opens the item's actions, Alt+Right steps through them and Alt+Enter runs the one in
focus. The menu lives in a TalkBack window Appium cannot read, so its entries are read from
the speech log.
"""

from __future__ import annotations

import re
import time
import xml.etree.ElementTree as ET
from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e.android import emu_mouse
from stratum_e2e.android.talkback import TalkBackLog, a11y_focused
from stratum_e2e.android.uhid_keyboard import KEY_UP, MOD_LALT, UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import by_id
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/reorderable_list_view_layout"
LOG_ID = "reorder.log"
ITEM_COUNT = 6
INITIAL_ORDER = [f"Item {n}" for n in range(1, ITEM_COUNT + 1)]

# USB HID usages of the keys TalkBack's menu shortcuts use.
KEY_ENTER = 0x28
KEY_SPACE = 0x2C
KEY_RIGHT = 0x4F

MOVE_UP = "Move up"
MOVE_DOWN = "Move down"
MOVE_TO_START = "Move to the start"
MOVE_TO_END = "Move to the end"
ALL_MOVES = {MOVE_UP, MOVE_DOWN, MOVE_TO_START, MOVE_TO_END}
MENU_CANCEL = "Cancel"

# One pass over the actions menu: four moves, Cancel, and the title spoken on wrap-around.
MENU_STEPS = 8
SPEECH_TIMEOUT_S = 3
SPEECH_QUIET_S = 1.2
WAIT_TIMEOUT_S = 10
POLL_INTERVAL_S = 0.25

_ITEM_LABEL = re.compile(r"Item \d+")
_BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


def _serial(driver: Any) -> str:
    return str(driver.capabilities["udid"])


def _item_nodes(driver: Any) -> list[tuple[str, int, ET.Element]]:
    """Return (label, top edge, node) of each distinct `Item <n>` node, top to bottom."""
    root = ET.fromstring(driver.page_source.encode("utf-8"))
    found: dict[str, tuple[str, int, ET.Element]] = {}
    for node in root.iter():
        label = node.get("text") or node.get("content-desc") or ""
        bounds = _BOUNDS.fullmatch(node.get("bounds") or "")
        if bounds is None or not _ITEM_LABEL.fullmatch(label):
            continue
        found.setdefault(label, (label, int(bounds.group(2)), node))
    return sorted(found.values(), key=lambda entry: entry[1])


def _order(driver: Any) -> list[str]:
    return [label for label, _, _ in _item_nodes(driver)]


def _app_log(driver: Any) -> str:
    return str(by_id(driver, "android", LOG_ID).get_attribute("content-desc"))


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until all six items are on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: _order(driver) == INITIAL_ORDER,
        "the six items on screen",
        timeout_s=WAIT_TIMEOUT_S,
    )


def _focus_by_touch(driver: Any, label: str) -> None:
    """Explore-by-touch: touch the centre of [label] so TalkBack focuses and speaks it."""
    serial = _serial(driver)
    x, y = emu_mouse.center(driver.find_element(AppiumBy.ACCESSIBILITY_ID, label).rect)
    emu_mouse.tap(serial, x, y)
    wait_until(
        lambda: a11y_focused(driver.page_source) == [label],
        f"TalkBack focus on {label}",
        timeout_s=WAIT_TIMEOUT_S,
    )


def _entry_name(utterance: str) -> str:
    """Return the menu entry an utterance names: no `selected, ` prefix, no role suffix."""
    return utterance.removeprefix("selected, ").split(", ")[0]


def _press_and_hear(
    keyboard: UhidKeyboard, talkback: TalkBackLog, usage: int, mods: int
) -> list[str]:
    """Press a key and return TalkBack's whole reply once it has been quiet for SPEECH_QUIET_S.

    TalkBack speaks a reply in parts (a name, then a hint seconds later), so the reply
    ends on silence, never on the first part. Empty after SPEECH_TIMEOUT_S of silence.
    """
    talkback.mark()
    keyboard.press(usage, mods)
    deadline = time.monotonic() + SPEECH_TIMEOUT_S
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


def _open_actions(keyboard: UhidKeyboard, talkback: TalkBackLog) -> None:
    """Open the focused item's actions: TalkBack menu, then its `Actions` entry."""
    menu = _press_and_hear(keyboard, talkback, KEY_SPACE, MOD_LALT)
    assert "TalkBack menu" in menu, f"TalkBack menu did not open, heard {menu}"
    actions = _press_and_hear(keyboard, talkback, KEY_ENTER, MOD_LALT)
    assert any(_entry_name(text) == "Actions" for text in actions), (
        f"the Actions entry did not open, heard {actions}"
    )


def _offered_moves(keyboard: UhidKeyboard, talkback: TalkBackLog) -> set[str]:
    """Open the actions and return the moves spoken over one pass of the entries.

    A pass is complete only once Cancel was heard, the last entry of the menu.
    """
    _open_actions(keyboard, talkback)
    heard: list[str] = []
    for _ in range(MENU_STEPS):
        heard += _press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
    names = {_entry_name(text) for text in heard}
    assert MENU_CANCEL in names, f"the pass did not reach Cancel, heard {heard}"
    return names & ALL_MOVES


def _close_actions(
    driver: Any, keyboard: UhidKeyboard, talkback: TalkBackLog, returns_to: str
) -> None:
    """Close the open actions menu through the keyboard: step to Cancel, then activate it.

    Proof of closing: TalkBack's focus is back on [returns_to], an app node, which the
    menu's own window cannot hold.
    """
    for _ in range(MENU_STEPS):
        heard = _press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
        if any(_entry_name(text) == MENU_CANCEL for text in heard):
            keyboard.press(KEY_ENTER, MOD_LALT)
            wait_until(
                lambda: a11y_focused(driver.page_source) == [returns_to],
                f"the menu to close with TalkBack focus back on {returns_to}",
                timeout_s=WAIT_TIMEOUT_S,
            )
            return
    raise AssertionError(f"{MENU_CANCEL!r} was not offered in {MENU_STEPS} steps")


def _run_move(keyboard: UhidKeyboard, talkback: TalkBackLog, move: str) -> None:
    """Open the actions, step to [move], and activate it."""
    _open_actions(keyboard, talkback)
    for _ in range(MENU_STEPS):
        heard = _press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
        if any(_entry_name(text) == move for text in heard):
            talkback.mark()
            keyboard.press(KEY_ENTER, MOD_LALT)
            return
    raise AssertionError(f"{move!r} was not offered in {MENU_STEPS} steps")


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr02/e10")
def test_talkback_takes_alt_up_before_the_app(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)
    _focus_by_touch(driver, "Item 3")

    talkback.mark()
    keyboard.press(KEY_UP, MOD_LALT)
    wait_until(
        lambda: a11y_focused(driver.page_source) == ["Item 2"],
        "TalkBack focus on Item 2",
        timeout_s=WAIT_TIMEOUT_S,
    )

    spoken = talkback.since_mark()
    assert spoken[0].startswith("Item 2"), spoken
    assert _order(driver) == INITIAL_ORDER
    assert "moved" not in _app_log(driver)


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr03/e03")
def test_talkback_offers_only_valid_moves(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)

    _focus_by_touch(driver, "Item 1")
    first = _offered_moves(keyboard, talkback)
    assert MOVE_UP not in first
    assert MOVE_TO_START not in first
    assert {MOVE_DOWN, MOVE_TO_END} <= first

    _close_actions(driver, keyboard, talkback, returns_to="Item 1")
    _focus_by_touch(driver, "Item 3")
    middle = _offered_moves(keyboard, talkback)
    assert middle == ALL_MOVES


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr03/e03")
@pytest.mark.req("fo06/us11/fr06/e01")
def test_talkback_move_up_moves_item_and_speaks_position(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)
    _focus_by_touch(driver, "Item 3")

    _run_move(keyboard, talkback, MOVE_UP)
    wait_until(
        lambda: _order(driver)[1] == "Item 3",
        "Item 3 in the second slot",
        timeout_s=WAIT_TIMEOUT_S,
    )
    wait_until(
        lambda: any("Moved to position 2 of 6" in text for text in talkback.since_mark()),
        "TalkBack to speak the new position",
        timeout_s=WAIT_TIMEOUT_S,
    )

    assert _order(driver) == ["Item 1", "Item 3", "Item 2", "Item 4", "Item 5", "Item 6"]
    assert _app_log(driver).count("moved") == 1


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
def test_os_tree_exposes_items_and_disabled_item_6(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    assert _order(driver) == INITIAL_ORDER
    enabled = {
        label: node.get("enabled") for label, _, node in _item_nodes(driver)
    }
    assert enabled["Item 6"] == "false"
    assert {label for label, value in enabled.items() if value == "true"} == set(
        INITIAL_ORDER[:-1]
    )
