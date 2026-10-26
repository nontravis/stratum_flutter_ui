"""An open drawer reads alone: its own named screen, its scrim as a dismiss control, no page.

Drives the `common/page_drawer` fixture (FO-06 US-19 FR-05; design section 10, US-13 scenario 3).
`PageLayout` shows `left` as a drawer on every window. The page behind it holds `Page body`,
`Open drawer`, and `Open drawer when VoiceOver is on`. The drawer reads `Navigation menu`, holds
`Drawer link A` and `Drawer link B`, and its scrim reads `Dismiss`. A screen reader reads those and
never the page words.

On Android the test walks TalkBack through the drawer, then taps the scrim's strip beside the
drawer and double-taps to activate it: the drawer closes. On iOS, with VoiceOver on, an Appium
touch does not reach the app, so the button that arms the drawer is clicked while VoiceOver is
off. The test then enables VoiceOver, waits for its first read in the app (a page word, with the
drawer still closed), and makes one forward move, which the fixture opens the drawer on.
VoiceOver is only read: once the drawer is up, the walk back to the first stop and forward to
the last.

On iOS VoiceOver speaks no drawer name when the drawer opens (owner ruling 2026-10-25: follow the
iOS convention, as Material's own Drawer does on iOS; an owner listening test found no spoken name
on PageDrawer and on Material's Drawer alike). The iOS test proves the drawer's name from the page
source, and the scrim and the hidden page from the walks.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.android import emu_mouse
from stratum_e2e.android.screen_reader import focus_by_touch, settled_speech, step_through
from stratum_e2e.android.talkback import TalkBackLog, a11y_focused
from stratum_e2e.android.tree import bounds, parent_attributes
from stratum_e2e.android.uhid_keyboard import UhidKeyboard
from stratum_e2e.fixtures import open_fixture_and_wait
from stratum_e2e.ios.voiceover import VoiceOver, matches_prefix
from stratum_e2e.ios.tree import labels
from stratum_e2e.locate import NODE_NOT_FOUND, by_id, by_label, click, is_displayed
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/page_drawer"
LINK_A_ID = "page_drawer.link_a"
OPEN_DRAWER = "Open drawer"
OPEN_DRAWER_LATER = "Open drawer when VoiceOver is on"
DRAWER, SCRIM = "Navigation menu", "Dismiss"
DRAWER_WORDS = {DRAWER, "Drawer link A", "Drawer link B", SCRIM}
PAGE_WORDS = ("Page body", OPEN_DRAWER)
# Past the drawer panel's right edge, to land on the scrim.
SCRIM_MARGIN_PX = 48
# One lap over the drawer's stops (the drawer, two links, the scrim) with room for a wrap.
STEPS = 8
WAIT_TIMEOUT_S = 10
FOCUS_TIMEOUT_S = 10
# VoiceOver's start-up focus in the app comes 3-6 s after it is enabled (measured).
SCREEN_CHANGE_TIMEOUT_S = 20


def _link_a_on_screen(driver: Any, platform: str) -> bool:
    try:
        return is_displayed(by_id(driver, platform, LINK_A_ID), platform)
    except NODE_NOT_FOUND:
        return False


def _open_fixture(driver: Any, platform: str, app_id: str, opener: str) -> None:
    """Cold-start the fixture and wait until the button [opener] is on screen."""
    open_fixture_and_wait(
        driver,
        platform,
        app_id,
        FIXTURE_ID,
        lambda: is_displayed(by_label(driver, platform, opener, exact=True), platform),
        f"the {opener!r} button on screen",
    )


def _drawer_in_tree(driver: Any) -> bool:
    """Whether the iOS tree holds the drawer by its name."""
    return any(label.startswith(DRAWER) for label in labels(driver.page_source))


def _page_in_tree(driver: Any) -> bool:
    """Whether the iOS tree still holds a page word."""
    return any(_starts_with_any(label, PAGE_WORDS) for label in labels(driver.page_source))


def _starts_with_any(utterance: str, words: tuple[str, ...]) -> bool:
    return any(matches_prefix(utterance, word) for word in words)


def _mentions_any(utterance: str, words: set[str]) -> bool:
    """Whether [utterance] holds a word anywhere: VoiceOver can prefix the app name."""
    return any(word in utterance for word in words)


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us19/fr05")
def test_talkback_reads_the_drawer_and_its_scrim_and_never_the_page(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open_fixture(driver, platform, app_id, OPEN_DRAWER)
    serial = str(driver.capabilities["udid"])

    talkback.mark()
    click(by_label(driver, platform, OPEN_DRAWER, exact=True), platform)
    wait_until(
        lambda: _link_a_on_screen(driver, platform),
        "the drawer's first link on screen",
        timeout_s=WAIT_TIMEOUT_S,
    )
    opening = settled_speech(talkback, FOCUS_TIMEOUT_S)

    talkback.mark()
    focus_by_touch(driver, by_id(driver, platform, LINK_A_ID), "Drawer link A", talkback)
    touched = settled_speech(talkback, FOCUS_TIMEOUT_S)
    talkback.mark()
    heard, path = step_through(driver, keyboard, talkback, STEPS)

    spoken = opening + touched + heard
    assert any(text.startswith(DRAWER) for text in spoken), spoken
    assert any(text.startswith(SCRIM) for text in heard), heard
    assert not [text for text in spoken if _starts_with_any(text, PAGE_WORDS)], spoken
    assert set(path) <= DRAWER_WORDS, path

    # The scrim is the strip right of the drawer panel: touch a margin past the panel's right
    # edge, then activate what TalkBack holds. The `Navigation menu` node is the pane-title
    # wrapper and spans the whole window (measured), so the panel is link A's parent.
    panel = parent_attributes(driver.page_source, LINK_A_ID)
    assert panel is not None, "link A has no parent in the tree"
    _, _, drawer_right, _ = bounds(panel)
    scrim_left, scrim_top, scrim_right, scrim_bottom = bounds(
        {"bounds": by_label(driver, platform, SCRIM, exact=True).get_attribute("bounds")}
    )
    x, y = drawer_right + SCRIM_MARGIN_PX, (scrim_top + scrim_bottom) // 2
    assert x > drawer_right, (x, panel)
    assert scrim_left <= x < scrim_right and scrim_top <= y < scrim_bottom, (x, y, drawer_right)
    emu_mouse.tap(serial, x, y)
    wait_until(
        lambda: a11y_focused(driver.page_source) == [SCRIM],
        "TalkBack focus on the scrim",
        timeout_s=FOCUS_TIMEOUT_S,
    )
    emu_mouse.double_tap(serial, x, y)
    wait_until(
        lambda: not _link_a_on_screen(driver, platform),
        "the drawer to close after the scrim is activated",
        timeout_s=WAIT_TIMEOUT_S,
    )


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us19/fr05")
def test_voiceover_reads_the_drawer_and_its_scrim_and_never_the_page(
    driver: Any, platform: str, app_id: str
) -> None:
    _open_fixture(driver, platform, app_id, OPEN_DRAWER_LATER)
    click(by_label(driver, platform, OPEN_DRAWER_LATER, exact=True), platform)

    # A tap on the arm button makes the fixture open the drawer on the first focus move after
    # VoiceOver's start-up focus, so the drawer never opens while VoiceOver is still starting.
    # The test waits for VoiceOver's first read in the app (a page word, drawer still closed),
    # then makes that move itself; a drawer word in VoiceOver's own speech below proves
    # VoiceOver was on and inside the open drawer.
    with VoiceOver(driver) as voiceover:
        wait_until(
            lambda: "Page body" in (voiceover.current() or ""),
            "VoiceOver's first read in the app, on the page",
            timeout_s=SCREEN_CHANGE_TIMEOUT_S,
        )
        assert not _link_a_on_screen(driver, platform), "drawer opened before the first read"
        voiceover.move("forward")
        wait_until(
            lambda: _mentions_any(voiceover.current() or "", DRAWER_WORDS),
            "VoiceOver to speak a drawer word once the drawer opens",
            timeout_s=SCREEN_CHANGE_TIMEOUT_S,
        )
        assert _drawer_in_tree(driver), labels(driver.page_source)
        assert not _page_in_tree(driver), labels(driver.page_source)
        first_stop = voiceover.current() or ""
        backward = voiceover.walk_backward(first_stop)
        forward = voiceover.walk_forward()

    stops = backward + forward
    assert any(matches_prefix(stop, SCRIM) for stop in stops), stops
    assert not [stop for stop in stops if _starts_with_any(stop, PAGE_WORDS)], stops
