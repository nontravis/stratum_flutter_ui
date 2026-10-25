"""Group label: a screen reader reads the wrapped group's label before its field.

Drives the `common/focus_builder` fixture (FO-06 US-16 scenario 7; FR-04 E01). A heading,
then a `FocusBuilder` whose `semantics` label is the address group around one plain text field
labeled `ถนน`, as the demo builds it. Group and field merge into one node, so they read at ONE
stop: the label `ที่อยู่จัดส่ง`, then `ถนน`, with the text-field flags. The test reads the speech
of the walk from the heading on and checks the order of the two texts, and on Android that the
one focused stop holds both. The heading carries an id and is the walk's starting point; the
group and the field carry none (an id would split a node's label from its role).

On iOS, VoiceOver can be walked but not driven: with it on, an Appium touch does not reach
the app, so the test only reads the focus order VoiceOver speaks.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.android.screen_reader import focus_by_touch, settled_speech, step_through
from stratum_e2e.android.talkback import TalkBackLog
from stratum_e2e.android.uhid_keyboard import UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios.focus_order import focus_order
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.locate import NODE_NOT_FOUND, by_id, is_displayed
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/focus_builder"
HEADING_ID = "focus_builder.heading"
HEADING = "Delivery form"
GROUP, FIELD = "ที่อยู่จัดส่ง", "ถนน"
# Heading to the one group stop takes one forward move; one more covers a stop that wraps.
STEPS = 2
FOCUS_TIMEOUT_S = 10
WAIT_TIMEOUT_S = 10
SEPARATOR = " | "


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until its heading is on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: is_displayed(by_id(driver, platform, HEADING_ID), platform),
        "the Delivery form heading on screen",
        timeout_s=WAIT_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )


def _assert_group_read_before_field(spoken: str) -> None:
    assert GROUP in spoken, spoken
    assert FIELD in spoken, spoken
    assert spoken.index(GROUP) < spoken.index(FIELD), spoken


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us16/s7")
def test_talkback_reads_the_group_label_before_the_street_field(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)
    talkback.mark()
    focus_by_touch(driver, by_id(driver, platform, HEADING_ID), HEADING)
    assert settled_speech(talkback, FOCUS_TIMEOUT_S), "TalkBack spoke nothing after the focus"
    talkback.mark()

    heard, focused = step_through(driver, keyboard, talkback, STEPS)

    _assert_group_read_before_field(SEPARATOR.join(heard))
    stops = [label for label in focused if GROUP in label]
    assert stops, focused
    assert FIELD in stops[0], focused
    assert stops[0].index(GROUP) < stops[0].index(FIELD), focused


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us16/s7")
def test_voiceover_reads_the_group_label_before_the_street_field(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    with VoiceOver(driver) as voiceover:
        spoken = SEPARATOR.join(focus_order(driver, voiceover))

    _assert_group_read_before_field(spoken)
