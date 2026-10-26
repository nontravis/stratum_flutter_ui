"""The splash announces its loading frames to a screen reader (FO-03 US-12 FR-08).

Both tests drive the `common/splash_screen` fixture, whose splash restarts every 7 s and
holds its loading frame about 4 s before it draws `Started`. The loading frame sits under
a live region labelled with the built-in `Loading` and no role (INV-32), so a reader
turned on after launch still catches a later cycle's announcement.
"""

from __future__ import annotations

import time
from typing import Any

import pytest

from stratum_e2e.android.talkback import TalkBackLog
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios.voiceover import VoiceOver, matches_prefix
from stratum_e2e.locate import NODE_NOT_FOUND, by_id, is_displayed
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/splash_screen"
# The splash's built-in loading label (English): the fixture passes no loadingLabel.
LOADING_LABEL = "Loading"
# The semantics id of the fixture's done frame (text `Started`).
DONE_ID = "splash_screen.done"
# The fixture restarts the splash every 7 s, so 20 s holds two cycles and more, with room
# for TalkBack or VoiceOver to come up.
ANNOUNCE_TIMEOUT_S = 20


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo03/us12/fr08")
def test_talkback_announces_loading_while_the_splash_holds_the_start(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog
) -> None:
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    # Wait for the done frame before the mark: cycle 1's Loading is spoken by then, so the
    # next Loading after the mark is cycle 2's, never the cold launch's.
    wait_until(
        lambda: is_displayed(by_id(driver, platform, DONE_ID), platform),
        f"the done frame {DONE_ID!r} to show after the cold launch's Loading",
        timeout_s=ANNOUNCE_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )
    # mark waits for TalkBack's queue to drain, so the cold launch's reads stay before it.
    talkback.mark()

    try:
        wait_until(
            lambda: any(text.startswith(LOADING_LABEL) for text in talkback.since_mark()),
            f"TalkBack to announce {LOADING_LABEL!r} while the splash holds the start",
            timeout_s=ANNOUNCE_TIMEOUT_S,
        )
    except AssertionError as error:
        raise AssertionError(f"{error}; heard since the mark: {talkback.since_mark()}") from error


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo03/us12/fr08")
def test_voiceover_announces_loading_while_the_splash_holds_the_start(
    driver: Any, platform: str, app_id: str
) -> None:
    open_fixture(driver, platform, app_id, FIXTURE_ID)
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
                f"VoiceOver to announce {LOADING_LABEL!r} while the splash holds the start",
                timeout_s=ANNOUNCE_TIMEOUT_S,
            )
        except AssertionError as error:
            raise AssertionError(f"{error}; current() polls (seconds, speech): {polls}") from error
