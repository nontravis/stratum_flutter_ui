"""PageLayout remembers the left pane width across a real process restart (FO-10 US-01),
and a screen reader announces the busy page (FO-06 US-18 scenario 7).

The restart test drives the `common/page_layout` fixture. The restart happens outside the
app, so the answer lives at this level: the first frame after the second cold start must
already hold the width the first run stored.

The two announce tests drive the `common/page_layout_loading` fixture, whose `loading` is
false for 3 s, then true for 4 s, and cycles. A reader turned on after launch still catches
a later turn to loading, and hears the busy layer's `Loading` label.
"""

from __future__ import annotations

import re
import time
from typing import Any

import pytest

from stratum_e2e.android.talkback import TalkBackLog
from stratum_e2e.app_restart import restart_app
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios.voiceover import VoiceOver, matches_prefix
from stratum_e2e.locate import NODE_NOT_FOUND, by_label, by_static_text, click, label_of
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/page_layout"
LOADING_FIXTURE_ID = "common/page_layout_loading"
# The busy layer's built-in label (English). The fixture cycles 3 s idle, 4 s busy, so 20 s
# holds two cycles and more, with room for TalkBack or VoiceOver to come up.
LOADING_LABEL = "Loading"
ANNOUNCE_TIMEOUT_S = 20
# pageLayoutFixtureStoredLeftWidth in test_app: fits a 360 dp phone window.
STORED_LEFT_WIDTH = "300"
SET_WIDTH_LABEL = f"Set left width to {STORED_LEFT_WIDTH}"
RESET_LABEL = "Reset settings"
# The first frame's width is a layout constraint divided by the device pixel ratio, so a
# stored 300 can read 299.99999999999994 (measured on Pixel_2_API_28); compare as a number.
WIDTH_TOLERANCE_DP = 0.01
STORED_ID = "page_layout.stored"
FIRST_FRAME_ID = "page_layout.first_frame_width"
# What each text reads before its number, for the macOS find by value.
MAC_TEXT_START = {STORED_ID: "stored left width", FIRST_FRAME_ID: "first frame left width"}
_FIRST_FRAME_WIDTH = re.compile(r"first frame left width: (\d+(?:\.\d+)?)")


def _text(driver: Any, platform: str, identifier: str) -> str | None:
    """The node's text, or None while the node is not on screen yet.

    macOS has no id locator, so it finds the text by the words that open it.
    """
    try:
        node = by_static_text(driver, platform, identifier, MAC_TEXT_START[identifier])
        return label_of(node, platform)
    except NODE_NOT_FOUND:
        return None


def _wait_for_text(driver: Any, platform: str, identifier: str, expected: str) -> None:
    wait_until(
        lambda: _text(driver, platform, identifier) == expected,
        f"{identifier} to read {expected!r} (last: {_text(driver, platform, identifier)!r})",
    )


def _first_frame_width(driver: Any, platform: str) -> float | None:
    """The width the first-frame text reports, or None while it is absent or not a width."""
    match = _FIRST_FRAME_WIDTH.fullmatch(_text(driver, platform, FIRST_FRAME_ID) or "")
    return float(match.group(1)) if match else None


def _click_when_present(driver: Any, platform: str, label: str) -> None:
    """Click the button labeled [label] once it is on screen (a button carries no id)."""

    def clicked() -> bool:
        try:
            click(by_label(driver, platform, label), platform)
        except NODE_NOT_FOUND:
            return False
        return True

    wait_until(clicked, f"{label!r} to be clickable")


@pytest.mark.android
@pytest.mark.ios
@pytest.mark.macos
@pytest.mark.web
@pytest.mark.req("fo10/us01/s2")
def test_left_pane_width_survives_a_real_restart(
    driver: Any, platform: str, app_id: str
) -> None:
    # reset: start from an empty store, whatever an earlier run left on the device.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    _click_when_present(driver, platform, RESET_LABEL)
    _wait_for_text(driver, platform, STORED_ID, "stored left width: none")

    # first run: store the width, and wait for the write to land before the process dies.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    _click_when_present(driver, platform, SET_WIDTH_LABEL)
    _wait_for_text(
        driver, platform, STORED_ID, f"stored left width: {STORED_LEFT_WIDTH}"
    )

    # second run: the pane must open at the stored width on its very first frame.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    expected = float(STORED_LEFT_WIDTH)
    wait_until(
        lambda: abs((_first_frame_width(driver, platform) or -1.0) - expected) <= WIDTH_TOLERANCE_DP,
        f"first frame left width to be {expected} dp "
        f"(last: {_text(driver, platform, 'page_layout.first_frame_width')!r})",
    )


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us18/s7")
def test_talkback_announces_the_busy_page_when_loading_turns_on(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog
) -> None:
    open_fixture(driver, platform, app_id, LOADING_FIXTURE_ID)
    # mark waits for TalkBack's queue to drain, so the cold launch's reads stay before it.
    talkback.mark()

    try:
        wait_until(
            lambda: any(text.startswith(LOADING_LABEL) for text in talkback.since_mark()),
            f"TalkBack to announce {LOADING_LABEL!r} when loading turns on",
            timeout_s=ANNOUNCE_TIMEOUT_S,
        )
    except AssertionError as error:
        raise AssertionError(f"{error}; heard since the mark: {talkback.since_mark()}") from error


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us18/s7")
def test_voiceover_announces_the_busy_page_when_loading_turns_on(
    driver: Any, platform: str, app_id: str
) -> None:
    open_fixture(driver, platform, app_id, LOADING_FIXTURE_ID)
    polls: list[tuple[float, str | None]] = []

    with VoiceOver(driver) as voiceover:
        started = time.monotonic()

        def announced() -> bool:
            # voiceOverCurrentSpeech can skip an utterance, so keep every read for the failure text.
            utterance = voiceover.current()
            polls.append((round(time.monotonic() - started, 2), utterance))
            return matches_prefix(utterance or "", LOADING_LABEL)

        try:
            wait_until(
                announced,
                f"VoiceOver to announce {LOADING_LABEL!r} when loading turns on",
                timeout_s=ANNOUNCE_TIMEOUT_S,
            )
        except AssertionError as error:
            raise AssertionError(f"{error}; current() polls (seconds, speech): {polls}") from error
