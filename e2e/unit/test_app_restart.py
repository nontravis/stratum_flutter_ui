"""Unit tests for the real process restart, on a recording driver (no device)."""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.app_restart import restart_app

BUNDLE_ID = "dev.stratum.stratumUiTestApp"


class ScriptDriver:
    def __init__(self) -> None:
        self.scripts: list[tuple[str, dict[str, Any]]] = []

    def execute_script(self, script: str, args: dict[str, Any]) -> None:
        self.scripts.append((script, args))


def test_ios_restart_terminates_the_app_then_launches_it_on_the_fixture_route() -> None:
    driver = ScriptDriver()

    assert restart_app(driver, "ios", BUNDLE_ID, "common/page_layout") is driver
    assert driver.scripts == [
        ("mobile: terminateApp", {"bundleId": BUNDLE_ID}),
        (
            "mobile: launchApp",
            {"bundleId": BUNDLE_ID, "arguments": ["--route=/fixture/common/page_layout"]},
        ),
    ]


def test_restart_refuses_web_before_it_touches_the_driver() -> None:
    driver = ScriptDriver()

    with pytest.raises(ValueError, match="platform 'web'"):
        restart_app(driver, "web", BUNDLE_ID, "common/page_layout")

    assert driver.scripts == []
