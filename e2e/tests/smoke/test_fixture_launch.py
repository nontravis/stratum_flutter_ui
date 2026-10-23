"""Smoke: a fixture opens by route and its nodes locate by semantics id."""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import by_id, by_label, by_value, is_displayed, label_of
from stratum_e2e.waits import wait_until
from stratum_e2e.web.session import accessibility_snapshot, requested_resources

WASM_ENTRY = "main.dart.wasm"
WASM_DEVICE = "chrome_wasm"


def _smoke_nodes(driver: Any, platform: str) -> tuple[Any, Any]:
    """Return the smoke button and the tap counter: by id, or on macOS by label and value."""
    if platform == "macos":
        return by_label(driver, platform, "Smoke button"), by_value(driver, platform, "taps:")
    return by_id(driver, platform, "smoke.button"), by_id(driver, platform, "smoke.taps")


@pytest.mark.android
@pytest.mark.ios
@pytest.mark.macos
@pytest.mark.web
def test_fixture_opens_by_route_and_id_locates(
    driver: Any, platform: str, app_id: str
) -> None:
    open_fixture(driver, platform, app_id, "smoke/semantics_id")

    button, taps = _smoke_nodes(driver, platform)
    assert is_displayed(button, platform)
    button.click()

    # Flutter publishes a Text's string as the node's label (content-desc on Android), not its text.
    wait_until(lambda: label_of(taps, platform) == "taps: 1", "the tap count reads 'taps: 1'")


@pytest.mark.web
def test_web_build_loads_the_renderer_the_device_names(
    driver: Any, platform: str, app_id: str, request: pytest.FixtureRequest
) -> None:
    open_fixture(driver, platform, app_id, "smoke/semantics_id")

    snapshot = accessibility_snapshot(driver)
    assert "Smoke button" in snapshot
    asked_for_wasm = any(url.endswith(WASM_ENTRY) for url in requested_resources(driver))
    assert asked_for_wasm == (request.config.getoption("--device") == WASM_DEVICE)
