"""Shortcut-bearing button: the menu key and the screen reader's action run the secondary tap.

Drives the `common/ink_well` fixture (FO-06 US-05 FR-01). The button carries no id (an id
would split its role and action from its label onto two nodes), so every step finds it by its
label `Menu target`: one node with the label, the button role, the tap and the `Show menu`
action. Level 2 checks that the screen reader offers the action on the node it focuses; on
iOS that is the stop that speaks the button's name. Appium cannot run a VoiceOver action
(a tap does not reach the app while VoiceOver is on), so iOS level 2 reads speech only.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.android.keyboard_focus import tab_to_first_label
from stratum_e2e.android.screen_reader import focus_by_touch, run_action
from stratum_e2e.android.talkback import TalkBackLog
from stratum_e2e.android.tree import key_focused
from stratum_e2e.android.uhid_keyboard import KEY_MENU, KEY_TAB, UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios import tree as ios_tree
from stratum_e2e.ios.focus_order import focus_order
from stratum_e2e.ios.voiceover import VoiceOver, matches_prefix
from stratum_e2e.locate import NODE_NOT_FOUND, by_label, by_static_text, label_of
from stratum_e2e.macos import tree as mac_tree
from stratum_e2e.waits import wait_until
from stratum_e2e.web import snapshot as web_snapshot
from stratum_e2e.web.session import accessibility_snapshot

FIXTURE_ID = "common/ink_well"
LOG_ID = "ink_well.log"
BUTTON_LABEL = "Menu target"
LOG_START = "Log:"  # macOS finds the log by the value that opens it
LOG_NOTHING = "Log: nothing yet."
LOG_MENU = "Log: menu"
MENU_ACTION = "Show menu"
WAIT_TIMEOUT_S = 10

ANDROID_BUTTON_CLASS = "android.widget.Button"
ACTIONS_HINT = "Actions available"


def _log(driver: Any, platform: str) -> str:
    return label_of(by_static_text(driver, platform, LOG_ID, LOG_START), platform)


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until the button and the untouched log are on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: _log(driver, platform) == LOG_NOTHING,
        f"the log to read {LOG_NOTHING!r}",
        timeout_s=WAIT_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us05/fr01")
def test_os_tree_exposes_one_focusable_enabled_button_node_with_the_label(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    node = by_label(driver, platform, BUTTON_LABEL)

    assert node.get_attribute("content-desc") == BUTTON_LABEL
    assert node.get_attribute("class") == ANDROID_BUTTON_CLASS
    assert node.get_attribute("enabled") == "true"
    assert node.get_attribute("focusable") == "true"
    assert node.get_attribute("clickable") == "true"


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us05/fr01")
def test_os_tree_marks_the_button_focused_after_tab_and_the_menu_key_runs_the_secondary_tap(
    driver: Any, platform: str, app_id: str, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)
    assert BUTTON_LABEL not in key_focused(driver.page_source)

    tab_to_first_label(driver, lambda: keyboard.press(KEY_TAB), BUTTON_LABEL)
    assert key_focused(driver.page_source) == [BUTTON_LABEL]

    keyboard.press(KEY_MENU)
    wait_until(
        lambda: _log(driver, platform) == LOG_MENU,
        f"the log to read {LOG_MENU!r}",
        timeout_s=WAIT_TIMEOUT_S,
    )


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us05/fr01")
def test_talkback_speaks_the_button_and_offers_show_menu_on_the_node_it_focuses(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)

    talkback.mark()
    focus_by_touch(driver, by_label(driver, platform, BUTTON_LABEL), BUTTON_LABEL, talkback)
    wait_until(
        lambda: any(text.startswith(BUTTON_LABEL) for text in talkback.since_mark()),
        f"TalkBack to speak {BUTTON_LABEL}",
        timeout_s=WAIT_TIMEOUT_S,
    )
    assert _log(driver, platform) == LOG_NOTHING

    run_action(keyboard, talkback, MENU_ACTION)

    wait_until(
        lambda: _log(driver, platform) == LOG_MENU,
        f"the log to read {LOG_MENU!r} after {MENU_ACTION!r}",
        timeout_s=WAIT_TIMEOUT_S,
    )


@pytest.mark.ios
@pytest.mark.level1
@pytest.mark.req("fo06/us05/fr01")
def test_ios_tree_exposes_one_enabled_button_node_with_the_label(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    nodes = [node for node in ios_tree.nodes(driver.page_source) if node.label == BUTTON_LABEL]

    assert len(nodes) == 1, nodes
    assert nodes[0].kind == "Button"
    assert nodes[0].enabled and nodes[0].accessible
    assert "Button" in nodes[0].traits


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us05/fr01")
def test_voiceover_speaks_the_button_name_and_offers_its_actions_at_one_stop(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    with VoiceOver(driver) as voiceover:
        order = focus_order(driver, voiceover)

    assert any(
        matches_prefix(stop, f"{BUTTON_LABEL} Button {ACTIONS_HINT}") for stop in order
    ), order


@pytest.mark.macos
@pytest.mark.level1
@pytest.mark.req("fo06/us05/fr01")
def test_macos_tree_exposes_one_enabled_button_node_with_the_label(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    nodes = [node for node in mac_tree.nodes(driver.page_source) if node.label == BUTTON_LABEL]

    assert len(nodes) == 1, nodes
    assert nodes[0].kind == "Button"
    assert nodes[0].enabled


@pytest.mark.web
@pytest.mark.level1
@pytest.mark.req("fo06/us05/fr01")
def test_web_snapshot_exposes_one_enabled_button_node_with_the_label(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    nodes = [
        node
        for node in web_snapshot.nodes(accessibility_snapshot(driver))
        if node.name == BUTTON_LABEL
    ]

    assert len(nodes) == 1, nodes
    assert nodes[0].role == "button"
    assert "disabled" not in nodes[0].flags
