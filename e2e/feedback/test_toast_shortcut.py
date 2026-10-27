"""The notice's keyboard shortcut moves focus to its button and Esc brings it back (CO-05.07 US-01).

Drives the `feedback/toast_shortcut` fixture (US-01 FR-05 E06 and FR-04 E06; design O1).
The fixture holds the text field `Note`, the button `Show notice`, and the notice
`Note saved` with its action `Undo`. A user types `abc` into the field, shows the notice,
and presses Option+T: focus moves to `Undo` and the field still reads `abc`, with no
"†". Esc closes the notice and focus returns to the field, its text intact. The same steps
repeat with F8, the Mac's second key. The notice closes 8 s after it shows (FR-04), so the
press follows the click at once.

The keys come from inside the browser, not from a physical keyboard (O4), so the leg does
not prove that a person's key press yields the same key. On chromium Option+T goes through
CDP as a real Mac key event with text "†" (O7), so an unblocked field reads `abc†` and the
text check can fail. On firefox Playwright sends no text with Alt (O7): the leg proves the
focus move and the Esc return, not that no "†" is typed.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import NODE_NOT_FOUND
from stratum_e2e.waits import wait_until, wait_until_held
from stratum_e2e.web import snapshot as web_snapshot
from stratum_e2e.web.keys import press_option_t
from stratum_e2e.web.session import accessibility_snapshot, field_text, focused_name, settle_frames

FIXTURE_ID = "feedback/toast_shortcut"
FIELD_LABEL = "Note"
SHOW_LABEL = "Show notice"
MESSAGE = "Note saved"
ACTION_LABEL = "Undo"
TYPED = "abc"
HINT = "Press Option+T to reach it"
HOLD_S = 1.0

# Installed before the route loads: records every string the page shows in a node's text or label,
# so a live region that clears itself still leaves its announcement to read.
_RECORD_TEXT = """
window.__stratumTexts = [];
new MutationObserver((mutations) => {
  for (const m of mutations) {
    if (m.type === 'attributes') window.__stratumTexts.push(m.target.getAttribute(m.attributeName) || '');
    else if (m.type === 'characterData') window.__stratumTexts.push(m.target.data || '');
    else for (const n of m.addedNodes) window.__stratumTexts.push(n.textContent || '');
  }
}).observe(document, {subtree: true, childList: true, characterData: true, attributes: true,
                      attributeFilter: ['aria-label']});
"""


def _has_action(page: Any) -> bool:
    return any(
        node.role == "button" and node.name == ACTION_LABEL
        for node in web_snapshot.nodes(accessibility_snapshot(page))
    )


def _show_notice_and_focus_field(page: Any, platform: str) -> None:
    """Click `Show notice`, wait for its `Undo` button, then click the field so focus sits there."""
    page.get_by_role("button", name=SHOW_LABEL, exact=True).click(timeout=1_000)
    wait_until(lambda: _has_action(page), f"the `{ACTION_LABEL}` button shows", catch=NODE_NOT_FOUND)
    page.get_by_label(FIELD_LABEL, exact=True).click(timeout=1_000)
    # Flutter opens the field's text connection a frame or two after the click; a key sent sooner is lost.
    settle_frames(page)


@pytest.mark.web
@pytest.mark.req("co05_07/us01/fr05/e06")
@pytest.mark.req("co05_07/us01/fr04/e06")
@pytest.mark.req("co05_07/us01/fr05/e13")
def test_option_t_then_f8_reach_the_notice_and_esc_returns_to_the_field(
    driver: Any, platform: str, app_id: str
) -> None:
    page = driver
    page.add_init_script(_RECORD_TEXT)
    open_fixture(page, platform, app_id, FIXTURE_ID)
    page.get_by_label(FIELD_LABEL, exact=True).click(timeout=1_000)
    page.keyboard.type(TYPED)

    for name, press in (("Option+T", lambda: press_option_t(page)), ("F8", lambda: page.keyboard.press("F8"))):
        _show_notice_and_focus_field(page, platform)
        press()
        wait_until(
            lambda: focused_name(page) == ACTION_LABEL or field_text(page, FIELD_LABEL) != TYPED,
            f"{name} moves focus to `{ACTION_LABEL}` or changes the field",
            catch=NODE_NOT_FOUND,
        )
        assert field_text(page, FIELD_LABEL) == TYPED, (
            f"{name} typed into the field: it reads {field_text(page, FIELD_LABEL)!r}"
        )
        wait_until_held(
            lambda: focused_name(page) == ACTION_LABEL and field_text(page, FIELD_LABEL) == TYPED,
            f"{name} keeps focus on `{ACTION_LABEL}` with the field at {TYPED!r}",
            hold_s=HOLD_S,
            catch=NODE_NOT_FOUND,
        )
        page.keyboard.press("Escape")
        wait_until(
            lambda: not _has_action(page) and focused_name(page) == FIELD_LABEL,
            f"Esc closes the notice and focus returns to `{FIELD_LABEL}` after {name}",
            catch=NODE_NOT_FOUND,
        )
        assert field_text(page, FIELD_LABEL) == TYPED

    texts = page.evaluate("window.__stratumTexts")
    assert any(text.strip().endswith(HINT) and MESSAGE in text for text in texts), (
        f"no announcement of {MESSAGE!r} ends with {HINT!r}; the page showed {texts!r}"
    )
