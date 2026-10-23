"""Shortcut-bearing button on Android: the menu key and TalkBack's `Show menu` action run the secondary tap.

Drives the `common/ink_well` fixture (FO-06 US-05 FR-01). The button's id sits on the
focusable child node; the button role and the custom action sit on its parent, so level 2
checks that TalkBack offers the action on the node it actually focuses.
"""

from __future__ import annotations

from typing import Any

import pytest
from selenium.common.exceptions import WebDriverException

from stratum_e2e.android.keyboard_focus import tab_to_first_label
from stratum_e2e.android.screen_reader import focus_by_touch, run_action
from stratum_e2e.android.talkback import TalkBackLog
from stratum_e2e.android.tree import key_focused, parent_attributes
from stratum_e2e.android.uhid_keyboard import KEY_MENU, KEY_TAB, UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import by_id
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/ink_well"
BUTTON_ID = "ink_well.button"
LOG_ID = "ink_well.log"
BUTTON_LABEL = "Menu target"
LOG_NOTHING = "Log: nothing yet."
LOG_MENU = "Log: menu"
MENU_ACTION = "Show menu"
WAIT_TIMEOUT_S = 10

ANDROID_BUTTON_CLASS = "android.widget.Button"


def _log(driver: Any) -> str:
    return str(by_id(driver, "android", LOG_ID).get_attribute("content-desc"))


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until the button and the untouched log are on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: _log(driver) == LOG_NOTHING,
        f"the log to read {LOG_NOTHING!r}",
        timeout_s=WAIT_TIMEOUT_S,
        catch=(WebDriverException,),
    )


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us05/fr01")
def test_os_tree_exposes_a_focusable_enabled_button_under_a_button_node(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    node = by_id(driver, platform, BUTTON_ID)
    parent = parent_attributes(driver.page_source, BUTTON_ID)

    assert node.get_attribute("content-desc") == BUTTON_LABEL
    assert node.get_attribute("enabled") == "true"
    assert node.get_attribute("focusable") == "true"
    assert node.get_attribute("clickable") == "true"
    assert parent is not None and parent["class"] == ANDROID_BUTTON_CLASS


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
        lambda: _log(driver) == LOG_MENU,
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
    focus_by_touch(driver, by_id(driver, platform, BUTTON_ID), BUTTON_LABEL)
    wait_until(
        lambda: any(text.startswith(BUTTON_LABEL) for text in talkback.since_mark()),
        f"TalkBack to speak {BUTTON_LABEL}",
        timeout_s=WAIT_TIMEOUT_S,
    )
    assert _log(driver) == LOG_NOTHING

    run_action(keyboard, talkback, MENU_ACTION)

    wait_until(
        lambda: _log(driver) == LOG_MENU,
        f"the log to read {LOG_MENU!r} after {MENU_ACTION!r}",
        timeout_s=WAIT_TIMEOUT_S,
    )
