"""Modal: Tab and the screen reader never reach the page behind an open modal.

Drives the `common/modal_layout` fixture (FO-06 US-20 FR-02 E03 and E04). The fixture's
page holds `Page control`, `page taps`, `Open modal` and `result`; the open modal holds
`Choose A`, `Choose B` and the built-in `Close`, over a `Dismiss` scrim. The buttons carry no
id (an id would split a button's label from its tap), so every step finds one by its label.
The OS tree drops the page's nodes while the modal is open, and VoiceOver walks the modal only.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.android.keyboard_focus import tab_to_first_label, tab_to_next_label
from stratum_e2e.android.screen_reader import press_and_hear
from stratum_e2e.android.talkback import TalkBackLog, a11y_focused
from stratum_e2e.android.tree import key_focused, labels as android_labels
from stratum_e2e.android.uhid_keyboard import KEY_RIGHT, KEY_TAB, MOD_LALT, UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios import tree as ios_tree
from stratum_e2e.ios.focus_order import focus_order, matches_order
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.locate import by_label
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/modal_layout"
OPEN_MODAL = "Open modal"
# What TalkBack speaks for the page nodes; the modal's own words never contain these.
PAGE_WORDS = ("Page control", "page taps", "Open modal", "result")
CHOOSE_A = "Choose A"
CHOOSE_B = "Choose B"
CLOSE = "Close"
SCRIM = "Dismiss"
MODAL_TAB_ORDER = [CHOOSE_A, CHOOSE_B, CLOSE]
# Alt+Right steps in the TalkBack pass: past the last node and round to the first again.
TALKBACK_STEPS = 8
WAIT_TIMEOUT_S = 10
ANDROID_BUTTON_CLASS = "android.widget.Button"
# What VoiceOver speaks in turn once the modal is up: the scrim's button, the controls in
# reading order, then the scrim's text as the last stop. The walk does not wrap round.
IOS_FOCUS_ORDER = [f"{SCRIM} Button", f"{CLOSE} Button", f"{CHOOSE_A} Button", f"{CHOOSE_B} Button", SCRIM]


def _labels(driver: Any, platform: str) -> list[str]:
    """The labels the OS tree exposes right now, in tree order."""
    if platform == "ios":
        return ios_tree.labels(driver.page_source)
    return android_labels(driver.page_source)


def _open_modal(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture, open the modal and wait until its controls are on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: OPEN_MODAL in _labels(driver, platform),
        "the page's Open modal button",
        timeout_s=WAIT_TIMEOUT_S,
    )
    by_label(driver, platform, OPEN_MODAL).click()
    wait_until(
        lambda: CHOOSE_A in _labels(driver, platform),
        "the modal's Choose A button",
        timeout_s=WAIT_TIMEOUT_S,
    )


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us20/fr02/e04")
def test_os_tree_holds_only_the_modal_controls_while_the_modal_is_open(
    driver: Any, platform: str, app_id: str
) -> None:
    _open_modal(driver, platform, app_id)

    page_labels = [label for label in _labels(driver, platform) if label.startswith(PAGE_WORDS)]
    assert not page_labels, f"page nodes still in the tree: {page_labels}"
    for label in (CHOOSE_A, CHOOSE_B):
        control = by_label(driver, platform, label, exact=True)
        assert control.get_attribute("class") == ANDROID_BUTTON_CLASS
        assert control.get_attribute("enabled") == "true"
    focused = key_focused(driver.page_source) + a11y_focused(driver.page_source)
    assert not [label for label in focused if label.startswith(PAGE_WORDS)], focused


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us20/fr02/e03")
def test_tab_cycles_inside_the_modal_and_never_reaches_the_page(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open_modal(driver, platform, app_id)

    def press_tab() -> None:
        keyboard.press(KEY_TAB)

    tab_to_first_label(driver, press_tab, MODAL_TAB_ORDER[0])
    for previous, expected in zip(MODAL_TAB_ORDER, MODAL_TAB_ORDER[1:]):
        tab_to_next_label(driver, press_tab, previous, expected)
    # The Tab after the last control is the claim: focus comes round to the first, never the page.
    tab_to_next_label(driver, press_tab, MODAL_TAB_ORDER[-1], MODAL_TAB_ORDER[0])


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us20/fr02/e04")
def test_talkback_swiping_past_the_last_modal_node_never_reads_the_page(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open_modal(driver, platform, app_id)
    wait_until(
        lambda: a11y_focused(driver.page_source) == [CHOOSE_A],
        f"TalkBack focus on {CHOOSE_A}",
        timeout_s=WAIT_TIMEOUT_S,
    )

    heard: list[str] = []
    focus_path: list[str] = []
    for _ in range(TALKBACK_STEPS):
        heard += press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
        focus_path += a11y_focused(driver.page_source)

    assert heard, "TalkBack spoke nothing while stepping through the modal"
    assert not [text for text in heard if text.startswith(PAGE_WORDS)], heard
    assert set(focus_path) <= {CHOOSE_A, CHOOSE_B, CLOSE, SCRIM}, focus_path
    # Focus started on Choose A; the wrap proof is Choose B, then Close, then Choose A again.
    walk = [CHOOSE_A, *focus_path]
    second_a = [i for i, label in enumerate(walk) if label == CHOOSE_A][1:]
    assert second_a, f"focus never came round to {CHOOSE_A}: {focus_path}"
    before_wrap = walk[: second_a[0]]
    assert CHOOSE_B in before_wrap and CLOSE in before_wrap, focus_path
    assert before_wrap.index(CHOOSE_B) < before_wrap.index(CLOSE), focus_path


@pytest.mark.ios
@pytest.mark.level1
@pytest.mark.req("fo06/us20/fr02/e04")
def test_ios_tree_holds_only_the_modal_controls_while_the_modal_is_open(
    driver: Any, platform: str, app_id: str
) -> None:
    _open_modal(driver, platform, app_id)

    page_labels = [label for label in _labels(driver, platform) if label.startswith(PAGE_WORDS)]
    assert not page_labels, f"page nodes still in the tree: {page_labels}"
    for label in (CHOOSE_A, CHOOSE_B):
        # One node carries the label and the button role.
        found = [node for node in ios_tree.nodes(driver.page_source) if node.label == label]
        assert len(found) == 1, found
        assert found[0].kind == "Button" and found[0].enabled and found[0].accessible


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us20/fr02/e04")
def test_voiceover_walks_the_modal_controls_and_never_reads_the_page(
    driver: Any, platform: str, app_id: str
) -> None:
    _open_modal(driver, platform, app_id)

    with VoiceOver(driver) as voiceover:
        order = focus_order(driver, voiceover)

    assert not [stop for stop in order if stop.startswith(PAGE_WORDS)], order
    assert matches_order(order, IOS_FOCUS_ORDER), order
