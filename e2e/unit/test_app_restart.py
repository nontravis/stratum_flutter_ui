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

    def find_elements(self, by: str, value: str) -> list[str]:
        return ["flutter group"]  # the macOS tree is up at once


class ScriptPage:
    def __init__(self) -> None:
        self.visited: list[str] = []
        self.waited_for: list[str] = []

    def goto(self, url: str) -> None:
        self.visited.append(url)

    def wait_for_selector(self, selector: str, **options: Any) -> None:
        self.waited_for.append(selector)


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


def test_macos_restart_terminates_the_app_then_launches_it_on_the_fixture_route() -> None:
    driver = ScriptDriver()

    assert restart_app(driver, "macos", BUNDLE_ID, "common/page_layout") is driver
    assert driver.scripts == [
        ("macos: terminateApp", {"bundleId": BUNDLE_ID}),
        (
            "macos: launchApp",
            {"bundleId": BUNDLE_ID, "arguments": ["--route=/fixture/common/page_layout"]},
        ),
    ]


def test_web_restart_leaves_the_document_then_loads_the_route_in_the_same_page() -> None:
    page = ScriptPage()

    assert restart_app(page, "web", BUNDLE_ID, "common/page_layout") is page
    assert page.visited == ["about:blank", "/#/fixture/common/page_layout"]
    assert page.waited_for == ["flt-semantics"]


def test_restart_refuses_a_platform_open_fixture_does_not_support() -> None:
    driver = ScriptDriver()

    with pytest.raises(ValueError, match="platform 'linux'"):
        restart_app(driver, "linux", BUNDLE_ID, "common/page_layout")

    assert driver.scripts == []
