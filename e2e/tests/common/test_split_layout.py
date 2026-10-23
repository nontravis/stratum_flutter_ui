"""Split divider: the OS exposes a slider at "30%", the screen reader speaks it (TalkBack adjusts it).

Drives the `common/split_layout` fixture (FO-06 US-21 FR-04). The divider has no semantics
identifier, so every step finds it by its label "Resize panes"; Android merges the value in
front of the label, so the node reads "30%, Resize panes", while iOS keeps the label
"Resize panes" and the value "30%" apart. Appium cannot swipe VoiceOver's adjustable (a touch
does not reach the app while VoiceOver is on), so iOS level 2 reads order and speech only.
"""

from __future__ import annotations

import re
from typing import Any

import pytest
from selenium.common.exceptions import WebDriverException

from stratum_e2e.android import screen_reader
from stratum_e2e.android.talkback import TalkBackLog
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios import tree as ios_tree
from stratum_e2e.ios.focus_order import focus_order, matches_order
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.locate import by_id, by_label
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/split_layout"
LIST_PANE_ID = "split.list_pane"
DETAIL_PANE_ID = "split.detail_pane"
DIVIDER_LABEL = "Resize panes"
START_PERCENT = 30
SLIDER_ROLE = "Slider"
ANDROID_SLIDER_CLASS = "android.widget.SeekBar"
IOS_ADJUSTABLE_TRAIT = "Adjustable"
# What VoiceOver speaks in turn: the list pane, the divider with its value, role and hint
# (VoiceOver cuts an utterance at 64 characters), then the detail pane, the last stop.
IOS_FOCUS_ORDER = [
    "List",
    f"{DIVIDER_LABEL} {START_PERCENT}% adjustable Swipe up or down with one finger to adjust the value",
    "Detail",
]
WAIT_TIMEOUT_S = 10

_DIVIDER_DESC = re.compile(r"(\d+)%, Resize panes")


def _divider(driver: Any, platform: str) -> Any:
    return by_label(driver, platform, DIVIDER_LABEL)


def _divider_desc(driver: Any, platform: str) -> str:
    """The divider's spoken value and label as `<percent>%, Resize panes`, whichever the platform splits."""
    divider = _divider(driver, platform)
    if platform == "ios":
        return f"{divider.get_attribute('value')}, {divider.get_attribute('label')}"
    return str(divider.get_attribute("content-desc"))


def _percent(driver: Any, platform: str) -> int | None:
    """The divider's percent, or None while the node is absent or reads no percent."""
    try:
        match = _DIVIDER_DESC.fullmatch(_divider_desc(driver, platform))
    except WebDriverException:
        return None
    return int(match.group(1)) if match else None


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until the divider reads its starting percent."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: _percent(driver, platform) == START_PERCENT,
        f"the divider to read {START_PERCENT}%",
        timeout_s=WAIT_TIMEOUT_S,
    )


def _swipe_and_read(driver: Any, platform: str, *, up: bool) -> int:
    """Swipe one finger up or down with TalkBack on the divider; return the percent it settles on."""
    before = _percent(driver, platform)
    size = driver.get_window_size()
    screen_reader.swipe_vertically(
        str(driver.capabilities["udid"]), size["width"] // 2, size["height"] // 2, up=up
    )
    wait_until(
        lambda: _percent(driver, platform) not in (None, before),
        "the divider to read a new percent",
        timeout_s=WAIT_TIMEOUT_S,
    )
    after = _percent(driver, platform)
    assert after is not None
    return after


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us21/fr04/e01")
def test_os_tree_exposes_the_divider_as_an_enabled_slider_between_the_panes(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    divider = _divider(driver, platform)
    list_pane = by_id(driver, platform, LIST_PANE_ID)
    detail_pane = by_id(driver, platform, DETAIL_PANE_ID)

    assert divider.get_attribute("class") == ANDROID_SLIDER_CLASS
    assert divider.get_attribute("content-desc") == f"{START_PERCENT}%, {DIVIDER_LABEL}"
    assert divider.get_attribute("enabled") == "true"
    assert divider.get_attribute("focusable") == "true"
    assert divider.get_attribute("clickable") == "true"
    list_right = list_pane.rect["x"] + list_pane.rect["width"]
    divider_centre = divider.rect["x"] + divider.rect["width"] // 2
    assert abs(divider_centre - list_right) <= divider.rect["width"]
    assert list_pane.rect["x"] < divider.rect["x"] <= detail_pane.rect["x"]


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us21/fr04/e01")
def test_talkback_reads_the_divider_label_slider_and_percent(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog
) -> None:
    _open(driver, platform, app_id)

    talkback.mark()
    screen_reader.focus_by_touch(
        driver, _divider(driver, platform), f"{START_PERCENT}%, {DIVIDER_LABEL}"
    )
    wait_until(
        lambda: SLIDER_ROLE in talkback.since_mark(),
        f"TalkBack to speak {SLIDER_ROLE!r}",
        timeout_s=WAIT_TIMEOUT_S,
    )

    # TalkBack speaks the value, the label, then the role; the value arrives in parts.
    spoken = " ".join(talkback.since_mark())
    assert f"{START_PERCENT}%" in spoken, spoken
    assert spoken.index(f"{START_PERCENT}%") < spoken.index(DIVIDER_LABEL) < spoken.index(SLIDER_ROLE)


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us21/fr04")
def test_talkback_increase_and_decrease_move_the_divider_and_speak_the_new_percent(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog
) -> None:
    _open(driver, platform, app_id)
    screen_reader.focus_by_touch(
        driver, _divider(driver, platform), f"{START_PERCENT}%, {DIVIDER_LABEL}"
    )

    talkback.mark()
    increased = _swipe_and_read(driver, platform, up=True)
    assert increased > START_PERCENT
    wait_until(
        lambda: any(f"{increased}%" in text for text in talkback.since_mark()),
        f"TalkBack to speak {increased}%",
        timeout_s=WAIT_TIMEOUT_S,
    )

    talkback.mark()
    decreased = _swipe_and_read(driver, platform, up=False)
    assert decreased < increased
    wait_until(
        lambda: any(f"{decreased}%" in text for text in talkback.since_mark()),
        f"TalkBack to speak {decreased}%",
        timeout_s=WAIT_TIMEOUT_S,
    )


@pytest.mark.ios
@pytest.mark.level1
@pytest.mark.req("fo06/us21/fr04/e01")
def test_ios_tree_exposes_the_divider_as_an_enabled_adjustable_between_the_panes(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    source = driver.page_source
    divider = ios_tree.find(source, DIVIDER_LABEL)
    list_pane = ios_tree.find(source, LIST_PANE_ID)
    detail_pane = ios_tree.find(source, DETAIL_PANE_ID)

    assert divider is not None and list_pane is not None and detail_pane is not None
    assert IOS_ADJUSTABLE_TRAIT in divider.traits
    assert divider.label == DIVIDER_LABEL
    assert divider.value == f"{START_PERCENT}%"
    assert divider.enabled and divider.accessible
    list_right = list_pane.x + list_pane.width
    divider_centre = divider.x + divider.width // 2
    assert abs(divider_centre - list_right) <= divider.width
    assert list_pane.x < divider.x <= detail_pane.x


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us21/fr04/e01")
def test_voiceover_reads_the_list_the_divider_label_slider_and_percent_then_the_detail(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    with VoiceOver(driver) as voiceover:
        order = focus_order(driver, voiceover)

    assert matches_order(order, IOS_FOCUS_ORDER), order
