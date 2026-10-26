"""The update gate's full screen replaces the app and its dialog reads alone (CO-05.09).

Drives the `feedback/update_gate` fixture (US-01 FR-02 E06 and US-02 FR-01 E07; design
section 10, US-13 scenario 6). The gate page holds `Gate page`, `Offer update`, and
`Require update in 10 s`. `Require update in 10 s` makes the checker answer `required`
after 10 s, and the gate replaces the whole app with its full screen: `Update required`
and `Install the new version to go on.`. `Offer update` makes it answer `available`
at once and shows the update dialog: `Update available` and `Later`.

A screen reader announces the full screen because its route scope replaces the app
(a route announcement plus a focus move, no live region), and focus moves into it, so
no utterance of the gate page crosses the swap. While the dialog shows, Flutter's
modal route hides the page behind from semantics, so every stop the reader reaches
is the dialog's own.

On iOS, with VoiceOver on, an Appium touch does not reach the app, so each test
clicks its button before `VoiceOver(driver)` enters and the fixture's own timer
(the 10 s require delay) does the rest. The E06 leg keeps every `current()` poll with
its time in the failure text: `mobile: voiceOverCurrentSpeech` holds the last
utterance only and can skip one, so the list is what the stop condition is judged on.
"""

from __future__ import annotations

import time
from typing import Any

import pytest

from stratum_e2e.android.screen_reader import focus_by_touch, step_through
from stratum_e2e.android.talkback import TalkBackLog, a11y_focused
from stratum_e2e.android.uhid_keyboard import UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios.focus_order import focus_order
from stratum_e2e.ios.voiceover import VoiceOver, matches_prefix
from stratum_e2e.locate import NODE_NOT_FOUND, by_id, by_label, click, is_displayed
from stratum_e2e.waits import wait_until

FIXTURE_ID = "feedback/update_gate"
REQUIRE_LABEL = "Require update in 10 s"
OFFER_LABEL = "Offer update"
GATE_PAGE = "Gate page"
PAGE_WORDS = (GATE_PAGE, OFFER_LABEL, REQUIRE_LABEL)
# The screen's own texts; every focused node after the swap starts with one of them.
SCREEN_WORDS = ("Update required", "Install the new version")
DIALOG_TITLE_ID = "update_gate.dialog_title"
# The label TalkBack reads for the title node above (it speaks labels, never ids).
DIALOG_TITLE = "Update available"
DIALOG_WORDS = {"Update available", "Later"}
# The require button's checker answers after 10 s; 25 s covers it plus the reader.
SWAP_TIMEOUT_S = 25
# Focus settling after the swap (Android) and VoiceOver's first read (iOS).
FOCUS_TIMEOUT_S = 10
# One lap over the dialog's stops (title, body, Later) with room for a wrap.
DIALOG_STEPS = 6


def _starts_with_any(utterance: str, words: tuple[str, ...] | set[str]) -> bool:
    """Whether [utterance] starts with one of [words] (VoiceOver stops at 64 characters)."""
    return any(matches_prefix(utterance, word) for word in words)


def _open_fixture(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until the require button is on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: is_displayed(by_label(driver, platform, REQUIRE_LABEL, exact=True), platform),
        f"the {REQUIRE_LABEL!r} button on screen",
        timeout_s=FOCUS_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )


def _dialog_title_on_screen(driver: Any, platform: str) -> bool:
    try:
        return is_displayed(by_id(driver, platform, DIALOG_TITLE_ID), platform)
    except NODE_NOT_FOUND:
        return False


def _focused_starts_with_screen(page_source: str) -> bool:
    """Whether TalkBack holds focus on nodes that all start with a screen word."""
    focused = a11y_focused(page_source)
    return bool(focused) and all(_starts_with_any(label, SCREEN_WORDS) for label in focused)


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("co05_09/us01/fr02/e06")
def test_talkback_announces_the_full_screen_and_focus_moves_into_it(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog
) -> None:
    _open_fixture(driver, platform, app_id)

    talkback.mark()
    click(by_label(driver, platform, REQUIRE_LABEL, exact=True), platform)
    # The checker answers `required` after 10 s, the gate replaces the app, and TalkBack
    # announces the screen. Before the swap the page is still the app and its remount on
    # the click can read `Gate page`, so the ban starts at the first screen word.
    heard: list[str] = []

    def _swap_spoken_and_focus_moved() -> bool:
        # What TalkBack spoke since the mark as of this poll, not a growing copy.
        heard[:] = talkback.since_mark()
        announced = any(_starts_with_any(text, SCREEN_WORDS) for text in heard)
        return announced and _focused_starts_with_screen(driver.page_source)

    try:
        wait_until(
            _swap_spoken_and_focus_moved,
            "TalkBack to announce the full screen and move focus into it",
            timeout_s=SWAP_TIMEOUT_S + FOCUS_TIMEOUT_S,
        )
    except AssertionError as error:
        raise AssertionError(
            f"{error}; heard since the mark: {' | '.join(heard)}; "
            f"focused: {a11y_focused(driver.page_source)}"
        ) from error
    first_screen = next(
        i for i, text in enumerate(heard) if _starts_with_any(text, SCREEN_WORDS)
    )
    assert not [
        text for text in heard[first_screen:] if _starts_with_any(text, PAGE_WORDS)
    ], " | ".join(heard)


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("co05_09/us01/fr02/e06")
def test_voiceover_announces_the_full_screen_and_focus_moves_into_it(
    driver: Any, platform: str, app_id: str
) -> None:
    _open_fixture(driver, platform, app_id)
    # VoiceOver would eat the click, so it is armed before entering: the checker answers
    # `required` 10 s later, on the fixture's own timer, while VoiceOver is on.
    click(by_label(driver, platform, REQUIRE_LABEL, exact=True), platform)
    polls: list[tuple[float, str | None]] = []

    with VoiceOver(driver) as voiceover:
        started = time.monotonic()

        def _screen_spoken() -> bool:
            polls.append((round(time.monotonic() - started, 2), voiceover.current()))
            return any(
                _starts_with_any(speech or "", SCREEN_WORDS) for _, speech in polls
            )

        try:
            wait_until(
                _screen_spoken,
                "VoiceOver to announce the full screen",
                timeout_s=SWAP_TIMEOUT_S,
            )
        except AssertionError as error:
            # The list is the stop condition's evidence: `current()` holds the last
            # utterance only and can skip one.
            raise AssertionError(f"{error}; polled: {polls}") from error
        stops = voiceover.walk_forward()
    assert not [stop for stop in stops if _starts_with_any(stop, PAGE_WORDS)], stops


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("co05_09/us02/fr01/e07")
def test_talkback_reads_the_update_dialog_alone(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open_fixture(driver, platform, app_id)

    click(by_label(driver, platform, OFFER_LABEL, exact=True), platform)
    wait_until(
        lambda: _dialog_title_on_screen(driver, platform),
        f"the dialog title {DIALOG_TITLE_ID!r} on screen",
        timeout_s=FOCUS_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )

    talkback.mark()
    focus_by_touch(driver, by_id(driver, platform, DIALOG_TITLE_ID), DIALOG_TITLE)
    heard, path = step_through(driver, keyboard, talkback, DIALOG_STEPS)
    assert not [text for text in heard if _starts_with_any(text, PAGE_WORDS)], (
        " | ".join(heard)
    )
    assert set(path) <= DIALOG_WORDS, " | ".join(path)


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("co05_09/us02/fr01/e07")
def test_voiceover_reads_the_update_dialog_alone(
    driver: Any, platform: str, app_id: str
) -> None:
    _open_fixture(driver, platform, app_id)
    click(by_label(driver, platform, OFFER_LABEL, exact=True), platform)
    wait_until(
        lambda: _dialog_title_on_screen(driver, platform),
        f"the dialog title {DIALOG_TITLE_ID!r} on screen",
        timeout_s=FOCUS_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )

    with VoiceOver(driver) as voiceover:
        order = focus_order(driver, voiceover)
    assert any(matches_prefix(stop, DIALOG_TITLE) for stop in order), order
    assert not [stop for stop in order if _starts_with_any(stop, PAGE_WORDS)], order
