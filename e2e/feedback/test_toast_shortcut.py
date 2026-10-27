"""The notice's keyboard shortcut moves focus to its button and Esc brings it back (CO-05.07 US-01).

Drives the `feedback/toast_shortcut` fixture (US-01 FR-05 E06 and E13, FR-04 E06; design O1).
The fixture holds the text field `Note`, a line `Echo: <text>` that shows the field's text as
the framework holds it, the button `Show notice`, and the notice `Note saved` with its action
`Undo`. A user types `abc` into the field, shows the notice, and presses Option+T: focus moves
to `Undo` and the field still reads `abc`, with no "†". Esc closes the notice and focus returns
to the field, its text intact. The same steps repeat with F8, the Mac's second key. The notice
closes 8 s after it shows (FR-04), so the press follows the click at once.

FR-05 E06 reads: "Tab on the last control of a page that keeps focus at its edge, on the web in
an app with its own page stack -> focus leaves for the browser, never into the notice; the
shortcut moves focus into it." The leg proves the second half and the "never into the notice"
clause of the first: Tab from `Show notice` with the notice open never puts focus inside the
notice. Chrome then hands focus to the browser; headless Firefox keeps it on `Show notice`, so
the leg asserts "outside the notice" for both and does not require the document to lose focus.

The keys come from inside the browser, not from a physical keyboard (O4), so the leg does
not prove that a person's key press yields the same key. On chromium Option+T goes through
CDP as a real Mac key event with text "†" (O7), so an unblocked field reads `abc†` and the
text check can fail. On firefox Playwright sends no text with Alt (O7): the leg proves the
focus move and the Esc return, not that no "†" is typed.

The shortcut fires through the framework's key path, not its text connection, so a "†" the
framework never read would still pass a check on the page alone. Before each press the leg
therefore proves the framework reads typed text (a positive control): a probe character must
reach the `Echo` line and Backspace must take it away. The no-"†" check reads both that line
and the browser's input.

The hint check (FR-05 E13) covers the Mac order only: it expects `Press Option+T to reach it`,
which Flutter web shows where it detects macOS; on Linux the hint reads F8 and the leg fails.
It reads only what the engine's announcement element (`flt-announcement-*`) carries.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import NODE_NOT_FOUND
from stratum_e2e.waits import wait_until, wait_until_held
from stratum_e2e.web import snapshot as web_snapshot
from stratum_e2e.web.browsers import browser_engine
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
PROBE = "x"
ECHO_PREFIX = "Echo:"

# Installed before the route loads: records every string the engine's announcement element
# (`flt-announcement-polite` or `-assertive`) holds, so a live region that clears itself still
# leaves its announcement to read. Text shown elsewhere on the page is never recorded.
_ANNOUNCEMENT = "flt-announcement-polite, flt-announcement-assertive"
_RECORD_TEXT = """
window.__stratumTexts = [];
new MutationObserver((mutations) => {
  for (const m of mutations) {
    const target = m.target.nodeType === 1 ? m.target : m.target.parentElement;
    if (!target || !target.closest('__ANNOUNCEMENT__')) continue;
    window.__stratumTexts.push(target.textContent || '');
  }
}).observe(document, {subtree: true, childList: true, characterData: true});
""".replace("__ANNOUNCEMENT__", _ANNOUNCEMENT)
# Counts the Tab key presses that reach the page, so a Tab the browser lost cannot pass as "focus stayed out".
_COUNT_TABS = """
window.__stratumTabs = 0;
document.addEventListener('keydown', (e) => { if (e.key === 'Tab') window.__stratumTabs += 1; }, true);
"""


def _has_action(page: Any) -> bool:
    return any(
        node.role == "button" and node.name == ACTION_LABEL
        for node in web_snapshot.nodes(accessibility_snapshot(page))
    )


def _echo(page: Any) -> str | None:
    """Return the text after `Echo:` in the fixture's echo line, the field's text as the framework holds it.

    `None` when the line is not on the page.
    """
    for text in web_snapshot.texts(accessibility_snapshot(page)):
        if text.startswith(ECHO_PREFIX):
            return text[len(ECHO_PREFIX):].strip()
    return None


def _field_settled(page: Any) -> None:
    """Click the field, wait out Flutter's hand-off, and prove the framework reads what is typed now.

    A probe character must reach the echo line and Backspace must take it away again; a probe
    that never lands fails here, not as a missing "†" later.
    """
    page.get_by_label(FIELD_LABEL, exact=True).click(timeout=1_000)
    # `settle_frames` is a guess at the hand-off; the probe below is the per-run proof it was long enough.
    settle_frames(page)
    page.keyboard.type(PROBE)
    wait_until(
        lambda: _echo(page) == TYPED + PROBE,
        f"the framework reads the probe {PROBE!r}: the echo shows {TYPED + PROBE!r}",
        catch=NODE_NOT_FOUND,
    )
    page.keyboard.press("Backspace")
    wait_until(
        lambda: _echo(page) == TYPED and field_text(page, FIELD_LABEL) == TYPED,
        f"Backspace removes the probe: the echo and the field read {TYPED!r}",
        catch=NODE_NOT_FOUND,
    )


def _show_notice_and_focus_field(page: Any) -> None:
    """Click `Show notice`, wait for its `Undo` button, then focus the field with the framework reading it."""
    page.get_by_role("button", name=SHOW_LABEL, exact=True).click(timeout=1_000)
    wait_until(lambda: _has_action(page), f"the `{ACTION_LABEL}` button shows", catch=NODE_NOT_FOUND)
    _field_settled(page)


def _focus_outside_notice(page: Any) -> bool:
    """Whether keyboard focus sits on the field, on `Show notice`, or outside the Flutter view."""
    left_view = page.evaluate("!document.hasFocus() || document.activeElement === document.body")
    return bool(left_view) or focused_name(page) in (FIELD_LABEL, SHOW_LABEL)


def _tab_from_last_control_skips_the_notice(page: Any) -> None:
    """FR-05 E06: with the notice open, Tab from the last control never puts focus inside the notice.

    Chrome hands focus to the browser (the document loses focus); Firefox keeps it on `Show notice`.
    Either way focus stays out of the notice, and the press is counted so a lost Tab cannot pass.
    """
    page.get_by_role("button", name=SHOW_LABEL, exact=True).click(timeout=1_000)
    wait_until(lambda: _has_action(page), f"the `{ACTION_LABEL}` button shows", catch=NODE_NOT_FOUND)
    wait_until(
        lambda: focused_name(page) == SHOW_LABEL,
        f"focus sits on `{SHOW_LABEL}`, the last control, before Tab",
        catch=NODE_NOT_FOUND,
    )
    tabs_before = page.evaluate("window.__stratumTabs")
    page.keyboard.press("Tab")
    wait_until(
        lambda: page.evaluate("window.__stratumTabs") == tabs_before + 1,
        "the page receives the Tab key press",
    )
    wait_until_held(
        lambda: _has_action(page) and _focus_outside_notice(page),
        f"Tab leaves focus outside the notice, never on `{ACTION_LABEL}`, while the notice is open",
        hold_s=HOLD_S,
        catch=NODE_NOT_FOUND,
    )
    page.get_by_role("button", name=ACTION_LABEL, exact=True).click(timeout=1_000)
    wait_until(lambda: not _has_action(page), "the notice closes", catch=NODE_NOT_FOUND)


@pytest.mark.web
@pytest.mark.req("co05_07/us01/fr05/e06")
@pytest.mark.req("co05_07/us01/fr04/e06")
@pytest.mark.req("co05_07/us01/fr05/e13")
def test_option_t_then_f8_reach_the_notice_and_esc_returns_to_the_field(
    driver: Any, platform: str, app_id: str
) -> None:
    page = driver
    page.add_init_script(_RECORD_TEXT)
    page.add_init_script(_COUNT_TABS)
    open_fixture(page, platform, app_id, FIXTURE_ID)
    page.get_by_label(FIELD_LABEL, exact=True).click(timeout=1_000)
    settle_frames(page)
    page.keyboard.type(TYPED)
    wait_until(
        lambda: _echo(page) == TYPED and field_text(page, FIELD_LABEL) == TYPED,
        f"the framework reads {TYPED!r}: the echo and the field read it",
        catch=NODE_NOT_FOUND,
    )

    _tab_from_last_control_skips_the_notice(page)

    def press_f8() -> bool:
        page.keyboard.press("F8")
        return False

    # Only chromium offers the "†" a Mac sends; a firefox pass proves the focus move, not "no †".
    engine = browser_engine(page)
    for name, press, expect_offered in (
        ("Option+T", lambda: press_option_t(page), engine == "chromium"),
        ("F8", press_f8, False),
    ):
        _show_notice_and_focus_field(page)
        offered = press()
        assert offered == expect_offered, f"{name} on {engine} offered a typed \u2020: {offered}, expected {expect_offered}"
        wait_until(
            lambda: focused_name(page) == ACTION_LABEL or field_text(page, FIELD_LABEL) != TYPED,
            f"{name} moves focus to `{ACTION_LABEL}` or changes the field",
            catch=NODE_NOT_FOUND,
        )
        assert field_text(page, FIELD_LABEL) == TYPED, (
            f"{name} typed into the field: it reads {field_text(page, FIELD_LABEL)!r}"
        )
        wait_until_held(
            lambda: (
                focused_name(page) == ACTION_LABEL
                and field_text(page, FIELD_LABEL) == TYPED
                and _echo(page) == TYPED
            ),
            f"{name} keeps focus on `{ACTION_LABEL}` with the field and the echo at {TYPED!r}",
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
        assert _echo(page) == TYPED

    texts = page.evaluate("window.__stratumTexts")
    assert any(text.strip().endswith(HINT) and MESSAGE in text for text in texts), (
        f"no announcement of {MESSAGE!r} ends with {HINT!r}; the announcement element held {texts!r}"
    )
