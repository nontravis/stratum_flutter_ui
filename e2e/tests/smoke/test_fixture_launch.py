"""Smoke: a fixture opens by route and its nodes locate by semantics id."""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import by_id


@pytest.mark.android
def test_fixture_opens_by_route_and_id_locates(
    driver: Any, platform: str, app_id: str
) -> None:
    open_fixture(driver, platform, app_id, "smoke/semantics_id")

    button = by_id(driver, platform, "smoke.button")
    assert button.is_displayed()
    button.click()

    # Flutter publishes a Text's string as the node's content-desc, not its text.
    assert by_id(driver, platform, "smoke.taps").get_attribute("content-desc") == "taps: 1"
