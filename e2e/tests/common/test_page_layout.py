"""PageLayout remembers the left pane width across a real process restart (FO-10 US-01).

Drives the `common/page_layout` fixture. The restart happens outside the app, so the
answer lives at this level: the first frame after the second cold start must already
hold the width the first run stored.
"""

from __future__ import annotations

import re
import time
from typing import Any, Callable

import pytest
from selenium.common.exceptions import WebDriverException

from stratum_e2e.app_restart import restart_app
from stratum_e2e.locate import by_id

FIXTURE_ID = "common/page_layout"
# pageLayoutFixtureStoredLeftWidth in test_app: fits a 360 dp phone window.
STORED_LEFT_WIDTH = "300"
WAIT_TIMEOUT_S = 20
POLL_INTERVAL_S = 0.25
# The first frame's width is a layout constraint divided by the device pixel ratio, so a
# stored 300 can read 299.99999999999994 (measured on Pixel_2_API_28); compare as a number.
WIDTH_TOLERANCE_DP = 0.01
_FIRST_FRAME_WIDTH = re.compile(r"first frame left width: (\d+(?:\.\d+)?)")


def _text(driver: Any, platform: str, identifier: str) -> str | None:
    """The node's text, or None while the node is not on screen yet."""
    try:
        return str(by_id(driver, platform, identifier).get_attribute("content-desc"))
    except WebDriverException:
        return None


def _wait_for(condition: Callable[[], bool], what: str) -> None:
    deadline = time.monotonic() + WAIT_TIMEOUT_S
    while not condition():
        if time.monotonic() > deadline:
            raise AssertionError(f"timed out after {WAIT_TIMEOUT_S}s waiting for {what}")
        time.sleep(POLL_INTERVAL_S)


def _wait_for_text(driver: Any, platform: str, identifier: str, expected: str) -> None:
    _wait_for(
        lambda: _text(driver, platform, identifier) == expected,
        f"{identifier} to read {expected!r} (last: {_text(driver, platform, identifier)!r})",
    )


def _first_frame_width(driver: Any, platform: str) -> float | None:
    """The width the first-frame text reports, or None while it is absent or not a width."""
    match = _FIRST_FRAME_WIDTH.fullmatch(_text(driver, platform, "page_layout.first_frame_width") or "")
    return float(match.group(1)) if match else None


def _click_when_present(driver: Any, platform: str, identifier: str) -> None:
    def clicked() -> bool:
        try:
            by_id(driver, platform, identifier).click()
        except WebDriverException:
            return False
        return True

    _wait_for(clicked, f"{identifier} to be clickable")


@pytest.mark.android
@pytest.mark.req("fo10/us01/s2")
def test_left_pane_width_survives_a_real_restart(
    driver: Any, platform: str, app_id: str
) -> None:
    # reset: start from an empty store, whatever an earlier run left on the device.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    _click_when_present(driver, platform, "page_layout.reset")
    _wait_for_text(driver, platform, "page_layout.stored", "stored left width: none")

    # first run: store the width, and wait for the write to land before the process dies.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    _click_when_present(driver, platform, "page_layout.set_400")
    _wait_for_text(
        driver, platform, "page_layout.stored", f"stored left width: {STORED_LEFT_WIDTH}"
    )

    # second run: the pane must open at the stored width on its very first frame.
    driver = restart_app(driver, platform, app_id, FIXTURE_ID)
    expected = float(STORED_LEFT_WIDTH)
    _wait_for(
        lambda: abs((_first_frame_width(driver, platform) or -1.0) - expected) <= WIDTH_TOLERANCE_DP,
        f"first frame left width to be {expected} dp "
        f"(last: {_text(driver, platform, 'page_layout.first_frame_width')!r})",
    )
