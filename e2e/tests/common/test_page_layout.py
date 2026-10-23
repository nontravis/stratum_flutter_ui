"""PageLayout remembers the left pane width across a real process restart (FO-10 US-01).

Drives the `common/page_layout` fixture. The restart happens outside the app, so the
answer lives at this level: the first frame after the second cold start must already
hold the width the first run stored.
"""

from __future__ import annotations

import re
from typing import Any

import pytest
from selenium.common.exceptions import WebDriverException

from stratum_e2e.app_restart import restart_app
from stratum_e2e.locate import by_id, by_label, label_of
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/page_layout"
# pageLayoutFixtureStoredLeftWidth in test_app: fits a 360 dp phone window.
STORED_LEFT_WIDTH = "300"
SET_WIDTH_LABEL = f"Set left width to {STORED_LEFT_WIDTH}"
RESET_LABEL = "Reset settings"
# The first frame's width is a layout constraint divided by the device pixel ratio, so a
# stored 300 can read 299.99999999999994 (measured on Pixel_2_API_28); compare as a number.
WIDTH_TOLERANCE_DP = 0.01
_FIRST_FRAME_WIDTH = re.compile(r"first frame left width: (\d+(?:\.\d+)?)")


def _text(driver: Any, platform: str, identifier: str) -> str | None:
    """The node's text, or None while the node is not on screen yet."""
    try:
        return label_of(by_id(driver, platform, identifier), platform)
    except WebDriverException:
        return None


def _wait_for_text(driver: Any, platform: str, identifier: str, expected: str) -> None:
    wait_until(
        lambda: _text(driver, platform, identifier) == expected,
        f"{identifier} to read {expected!r} (last: {_text(driver, platform, identifier)!r})",
    )


def _first_frame_width(driver: Any, platform: str) -> float | None:
    """The width the first-frame text reports, or None while it is absent or not a width."""
    match = _FIRST_FRAME_WIDTH.fullmatch(_text(driver, platform, "page_layout.first_frame_width") or "")
    return float(match.group(1)) if match else None


def _click_when_present(driver: Any, platform: str, label: str) -> None:
    """Click the button labeled [label] once it is on screen (a button carries no id)."""

    def clicked() -> bool:
        try:
            by_label(driver, platform, label).click()
        except WebDriverException:
            return False
        return True

    wait_until(clicked, f"{label!r} to be clickable")


@pytest.mark.android
@pytest.mark.ios
@pytest.mark.req("fo10/us01/s2")
def test_left_pane_width_survives_a_real_restart(
    driver: Any, platform: str, app_id: str
) -> None:
    # reset: start from an empty store, whatever an earlier run left on the device.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    _click_when_present(driver, platform, RESET_LABEL)
    _wait_for_text(driver, platform, "page_layout.stored", "stored left width: none")

    # first run: store the width, and wait for the write to land before the process dies.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    _click_when_present(driver, platform, SET_WIDTH_LABEL)
    _wait_for_text(
        driver, platform, "page_layout.stored", f"stored left width: {STORED_LEFT_WIDTH}"
    )

    # second run: the pane must open at the stored width on its very first frame.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    expected = float(STORED_LEFT_WIDTH)
    wait_until(
        lambda: abs((_first_frame_width(driver, platform) or -1.0) - expected) <= WIDTH_TOLERANCE_DP,
        f"first frame left width to be {expected} dp "
        f"(last: {_text(driver, platform, 'page_layout.first_frame_width')!r})",
    )
