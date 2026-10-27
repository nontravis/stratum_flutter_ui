"""Dismiss Android's first-entry immersive confirmation (M3-T19).

The first time an app enters immersive mode, Android shows a "Viewing full screen" card
that takes focus without taking the app's bar control away. While it is up, every dump
describes that window, and on an emulator it can stall system_server long enough to raise
an ANR over the app (tmp/device-round/device-results.md:3625).
"""

from __future__ import annotations

from typing import Any

IMMERSIVE_CONFIRMATION = "ImmersiveModeConfirmation"


def dismiss_immersive_confirmation(driver: Any, window_dump: str) -> bool:
    """Tap the middle of the window when [window_dump] shows the confirmation.

    Appium-Python-Client's `tap` takes a list of `(x, y)` tuples, one per finger. The tap
    lands on the app's content, which on the video page is a label with no target. Returns
    True when it tapped, so the caller re-reads the dump.
    """
    if IMMERSIVE_CONFIRMATION not in window_dump:
        return False
    size = driver.get_window_size()
    driver.tap([(size["width"] // 2, size["height"] // 2)])
    return True
