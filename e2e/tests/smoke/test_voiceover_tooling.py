"""Tooling guard: what an Appium tap does while VoiceOver is on (design section 8, iOS limits).

Proves no requirement. It pins a measured driver behaviour, so a driver or OS change
that flips it fails loudly and the iOS level 2 recipe gets re-read.
"""

from __future__ import annotations

import time
from typing import Any

import pytest

from stratum_e2e.fixtures import open_fixture
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.locate import by_id, label_of

SETTLE_S = 2  # measured: the label stays `taps: 0` at 0, 2, and 5 s after the click

# Measured 2026-10-23 on iOS 27.1 (Appium 3.8.0, xcuitest 12.19.1): 3 of 3 runs.
TAPS_AFTER_CLICK_WITH_VOICEOVER = "taps: 0"


@pytest.mark.ios
@pytest.mark.level2
def test_appium_click_does_not_reach_the_app_while_voiceover_is_on(
    driver: Any, platform: str, app_id: str, voiceover: VoiceOver
) -> None:
    open_fixture(driver, platform, app_id, "smoke/semantics_id")
    assert label_of(by_id(driver, platform, "smoke.taps"), platform) == "taps: 0"

    by_id(driver, platform, "smoke.button").click()
    time.sleep(SETTLE_S)

    assert (
        label_of(by_id(driver, platform, "smoke.taps"), platform)
        == TAPS_AFTER_CLICK_WITH_VOICEOVER
    )
