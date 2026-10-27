"""Keys a Playwright press cannot send on its own (design O7)."""

from __future__ import annotations

from playwright.sync_api import Page

from stratum_e2e.web.browsers import browser_engine

# A real Option+T on a Mac: Alt goes down, T arrives as the key "†" with text "†" and keyCode 84, then both release.
OPTION_T_CDP_EVENTS = (
    {"type": "rawKeyDown", "key": "Alt", "code": "AltLeft", "windowsVirtualKeyCode": 18, "location": 1, "modifiers": 1},
    {"type": "keyDown", "key": "†", "code": "KeyT", "text": "†", "windowsVirtualKeyCode": 84, "modifiers": 1},
    {"type": "keyUp", "key": "†", "code": "KeyT", "windowsVirtualKeyCode": 84, "modifiers": 1},
    {"type": "keyUp", "key": "Alt", "code": "AltLeft", "windowsVirtualKeyCode": 18, "location": 1, "modifiers": 0},
)


def press_option_t(page: Page) -> bool:
    """Press Option+T in [page]; return whether a typed "†" was offered to the page.

    Chromium takes the Mac key events through CDP `Input.dispatchKeyEvent`, text included, so
    the page sees what a Mac keyboard sends and returns `True`. Any other engine gets
    `Alt+KeyT` from Playwright, which sends no text with Alt (O7), and returns `False`: a
    "†" cannot appear there, so a field that stays unchanged proves nothing about typing.
    """
    if browser_engine(page) == "chromium":
        session = page.context.new_cdp_session(page)
        for event in OPTION_T_CDP_EVENTS:
            session.send("Input.dispatchKeyEvent", event)
        return True
    page.keyboard.press("Alt+KeyT")
    return False
