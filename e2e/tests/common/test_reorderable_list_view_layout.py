"""Reorder list: the screen reader takes Alt+Up (TalkBack), offers valid moves, moves and speaks.

Drives the `common/reorderable_list_view_layout` fixture (FO-06 US-11). TalkBack's actions
for the focused item open through its own keyboard shortcuts on the uhid keyboard, measured
on the e2e AVD (TalkBack 15): Alt+Space opens the TalkBack menu, Alt+Enter on its `Actions`
entry opens the item's actions, Alt+Right steps through them and Alt+Enter runs the one in
focus. The menu lives in a TalkBack window Appium cannot read, so its entries are read from
the speech log.

On iOS, VoiceOver can be walked but not driven: with it on, an Appium touch does not reach
the app, and Appium has no command that runs a VoiceOver action. Level 2 therefore reads the
focus order and the speech. The drop a move announcement needs cannot happen with VoiceOver
on (measured: a drag from Item 3 above Item 2 left the order and the log unchanged, 4 of 4
attempts, while the same drag with VoiceOver off dropped), so no iOS test claims the spoken
move announcement.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e.android.screen_reader import (
    MENU_CANCEL,
    MENU_STEPS,
    entry_name,
    focus_by_touch,
    open_actions,
    press_and_hear,
    run_action,
)
from stratum_e2e.android.talkback import TalkBackLog, a11y_focused
from stratum_e2e.android.uhid_keyboard import KEY_ENTER, KEY_RIGHT, KEY_UP, MOD_LALT, UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios import tree as ios_tree
from stratum_e2e.ios.focus_order import focus_order, matches_order
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.locate import by_id
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/reorderable_list_view_layout"
LOG_ID = "reorder.log"
ITEM_COUNT = 6
INITIAL_ORDER = [f"Item {n}" for n in range(1, ITEM_COUNT + 1)]

MOVE_UP = "Move up"
MOVE_DOWN = "Move down"
MOVE_TO_START = "Move to the start"
MOVE_TO_END = "Move to the end"
ALL_MOVES = {MOVE_UP, MOVE_DOWN, MOVE_TO_START, MOVE_TO_END}
WAIT_TIMEOUT_S = 10

ACTIONS_HINT = "Actions available"
# What VoiceOver speaks in turn, item 1 to the last element on screen: each movable item
# reads as `Item <n> Button Actions available` at one stop; the disabled Item 6 reads
# `dimmed` and offers no actions; the log follows (VoiceOver cuts an utterance at 64 characters).
IOS_FOCUS_ORDER = [
    *(f"Item {n} Button {ACTIONS_HINT}" for n in range(1, ITEM_COUNT)),
    f"Item {ITEM_COUNT} dimmed Button",
    "Log: nothing yet.",
]

_ITEM_LABEL = re.compile(r"Item \d+")
_BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


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


def _ios_items(driver: Any) -> dict[str, ios_tree.Node]:
    """Return the distinct `Item <n>` buttons by label, top to bottom."""
    found: dict[str, ios_tree.Node] = {}
    for node in ios_tree.nodes(driver.page_source):
        if node.kind == "Button" and _ITEM_LABEL.fullmatch(node.label):
            found.setdefault(node.label, node)
    return dict(sorted(found.items(), key=lambda entry: entry[1].y))


def _order(driver: Any, platform: str) -> list[str]:
    if platform == "ios":
        return list(_ios_items(driver))
    return [label for label, _, _ in _item_nodes(driver)]


def _app_log(driver: Any) -> str:
    return str(by_id(driver, "android", LOG_ID).get_attribute("content-desc"))


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until all six items are on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: _order(driver, platform) == INITIAL_ORDER,
        "the six items on screen",
        timeout_s=WAIT_TIMEOUT_S,
    )


def _focus_item(driver: Any, label: str) -> None:
    """Explore-by-touch: touch [label]'s item so TalkBack focuses and speaks it."""
    focus_by_touch(driver, driver.find_element(AppiumBy.ACCESSIBILITY_ID, label), label)


def _offered_moves(keyboard: UhidKeyboard, talkback: TalkBackLog) -> set[str]:
    """Open the actions and return the moves spoken over one pass of the entries.

    A pass is complete only once Cancel was heard, the last entry of the menu.
    """
    open_actions(keyboard, talkback)
    heard: list[str] = []
    for _ in range(MENU_STEPS):
        heard += press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
    names = {entry_name(text) for text in heard}
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
        heard = press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
        if any(entry_name(text) == MENU_CANCEL for text in heard):
            keyboard.press(KEY_ENTER, MOD_LALT)
            wait_until(
                lambda: a11y_focused(driver.page_source) == [returns_to],
                f"the menu to close with TalkBack focus back on {returns_to}",
                timeout_s=WAIT_TIMEOUT_S,
            )
            return
    raise AssertionError(f"{MENU_CANCEL!r} was not offered in {MENU_STEPS} steps")


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr02/e10")
def test_talkback_takes_alt_up_before_the_app(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)
    _focus_item(driver, "Item 3")

    talkback.mark()
    keyboard.press(KEY_UP, MOD_LALT)
    wait_until(
        lambda: a11y_focused(driver.page_source) == ["Item 2"],
        "TalkBack focus on Item 2",
        timeout_s=WAIT_TIMEOUT_S,
    )

    spoken = talkback.since_mark()
    assert spoken[0].startswith("Item 2"), spoken
    assert _order(driver, platform) == INITIAL_ORDER
    assert "moved" not in _app_log(driver)


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr03/e03")
def test_talkback_offers_only_valid_moves(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)

    _focus_item(driver, "Item 1")
    first = _offered_moves(keyboard, talkback)
    assert MOVE_UP not in first
    assert MOVE_TO_START not in first
    assert {MOVE_DOWN, MOVE_TO_END} <= first

    _close_actions(driver, keyboard, talkback, returns_to="Item 1")
    _focus_item(driver, "Item 3")
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
    _focus_item(driver, "Item 3")

    run_action(keyboard, talkback, MOVE_UP)
    wait_until(
        lambda: _order(driver, platform)[1] == "Item 3",
        "Item 3 in the second slot",
        timeout_s=WAIT_TIMEOUT_S,
    )
    wait_until(
        lambda: any("Moved to position 2 of 6" in text for text in talkback.since_mark()),
        "TalkBack to speak the new position",
        timeout_s=WAIT_TIMEOUT_S,
    )

    assert _order(driver, platform) == ["Item 1", "Item 3", "Item 2", "Item 4", "Item 5", "Item 6"]
    assert _app_log(driver).count("moved") == 1


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
def test_os_tree_exposes_items_and_disabled_item_6(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    assert _order(driver, platform) == INITIAL_ORDER
    enabled = {
        label: node.get("enabled") for label, _, node in _item_nodes(driver)
    }
    assert enabled["Item 6"] == "false"
    assert {label for label, value in enabled.items() if value == "true"} == set(
        INITIAL_ORDER[:-1]
    )


@pytest.mark.ios
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
def test_ios_tree_exposes_items_and_disabled_item_6(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    items = _ios_items(driver)

    assert list(items) == INITIAL_ORDER
    assert not items["Item 6"].enabled
    assert "NotEnabled" in items["Item 6"].traits
    assert {label for label, node in items.items() if node.enabled} == set(INITIAL_ORDER[:-1])


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us11/fr03/e03")
def test_voiceover_reads_each_item_at_one_stop(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    with VoiceOver(driver) as voiceover:
        spoken = focus_order(driver, voiceover)

    assert matches_order(spoken, IOS_FOCUS_ORDER), spoken
