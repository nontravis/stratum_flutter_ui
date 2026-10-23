"""Split divider on Android: the OS exposes a slider at "30%", TalkBack speaks it and adjusts it.

Drives the `common/split_layout` fixture (FO-06 US-21 FR-04). The divider has no semantics
identifier, so every step finds it by its label "Resize panes"; Flutter merges the value in
front of the label, so the node reads "30%, Resize panes".
"""

from __future__ import annotations

import re
from typing import Any

import pytest
from selenium.common.exceptions import WebDriverException

from stratum_e2e.android import screen_reader
from stratum_e2e.android.talkback import TalkBackLog
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import by_id, by_label
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/split_layout"
LIST_PANE_ID = "split.list_pane"
DETAIL_PANE_ID = "split.detail_pane"
DIVIDER_LABEL = "Resize panes"
START_PERCENT = 30
SLIDER_ROLE = "Slider"
ANDROID_SLIDER_CLASS = "android.widget.SeekBar"
WAIT_TIMEOUT_S = 10

_DIVIDER_DESC = re.compile(r"(\d+)%, Resize panes")


def _divider(driver: Any, platform: str) -> Any:
    return by_label(driver, platform, DIVIDER_LABEL)


def _percent(driver: Any, platform: str) -> int | None:
    """The divider's percent, or None while the node is absent or reads no percent."""
    try:
        match = _DIVIDER_DESC.fullmatch(str(_divider(driver, platform).get_attribute("content-desc")))
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
