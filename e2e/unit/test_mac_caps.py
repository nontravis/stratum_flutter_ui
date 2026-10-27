"""Unit tests for the macOS Mac2 capabilities, fixture launch, and locators."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e import fixtures, locate
from stratum_e2e.macos.session import NEW_COMMAND_TIMEOUT_S, mac_capabilities

BUNDLE_ID = "dev.stratum.stratumUiTestApp"
APP = Path("/builds/stratum_ui_test_app.app")


class ScriptDriver:
    """Driver stub that records execute_script and find_element calls."""

    def __init__(self) -> None:
        self.scripts: list[tuple[str, dict[str, Any]]] = []
        self.finds: list[tuple[str, str]] = []
        self.tree_polls: list[list[str]] = []  # one entry per poll; empty means "not yet"

    def find_elements(self, by: str, value: str) -> list[str]:
        self.finds.append((by, value))
        return self.tree_polls.pop(0) if self.tree_polls else ["flutter group"]

    def execute_script(self, script: str, args: dict[str, Any]) -> None:
        self.scripts.append((script, args))

    def find_element(self, by: str, value: str) -> str:
        self.finds.append((by, value))
        return "node"


def test_mac_caps_name_the_mac2_driver_on_the_mac_platform() -> None:
    caps = mac_capabilities(BUNDLE_ID, [], APP)

    assert caps["platformName"] == "mac"
    assert caps["appium:automationName"] == "Mac2"


def test_mac_caps_launch_the_bundle_with_the_given_arguments() -> None:
    caps = mac_capabilities(BUNDLE_ID, ["--route=/fixture/smoke/semantics_id"], APP)

    assert caps["appium:bundleId"] == BUNDLE_ID
    assert caps["appium:arguments"] == ["--route=/fixture/smoke/semantics_id"]


def test_mac_caps_launch_the_build_the_app_path_names() -> None:
    caps = mac_capabilities(BUNDLE_ID, [], APP)

    assert caps["appium:appPath"] == str(APP)


def test_mac_caps_copy_the_arguments_so_a_later_edit_does_not_leak_in() -> None:
    arguments = ["--a"]
    caps = mac_capabilities(BUNDLE_ID, arguments, APP)

    arguments.append("--b")

    assert caps["appium:arguments"] == ["--a"]


def test_mac_caps_outlast_the_host_voiceover_walk() -> None:
    """The host VoiceOver leg sends Mac2 nothing for minutes; Appium's default 60 s would end the session."""
    caps = mac_capabilities(BUNDLE_ID, [], APP)

    assert caps["appium:newCommandTimeout"] == NEW_COMMAND_TIMEOUT_S
    assert NEW_COMMAND_TIMEOUT_S > 60


def test_open_fixture_terminates_then_relaunches_on_the_route() -> None:
    driver = ScriptDriver()

    fixtures.open_fixture(driver, "macos", BUNDLE_ID, "smoke/semantics_id")

    assert driver.scripts == [
        ("macos: terminateApp", {"bundleId": BUNDLE_ID}),
        (
            "macos: launchApp",
            {"bundleId": BUNDLE_ID, "arguments": ["--route=/fixture/smoke/semantics_id"]},
        ),
    ]


def test_open_fixture_on_macos_waits_for_the_flutter_tree_after_the_relaunch() -> None:
    driver = ScriptDriver()
    driver.tree_polls = [[], [], ["flutter group"]]

    fixtures.open_fixture(driver, "macos", BUNDLE_ID, "smoke/semantics_id")

    assert driver.finds == [(AppiumBy.XPATH, fixtures.MACOS_FLUTTER_TREE)] * 3
    assert [name for name, _ in driver.scripts] == ["macos: terminateApp", "macos: launchApp"]


def test_by_id_on_macos_names_the_missing_identifier_instead_of_searching() -> None:
    driver = ScriptDriver()

    with pytest.raises(ValueError, match="AXIdentifier"):
        locate.by_id(driver, "macos", "smoke.button")

    assert driver.finds == []


def test_by_label_on_macos_matches_the_label_by_containment_or_equality() -> None:
    contains, exact = ScriptDriver(), ScriptDriver()

    assert locate.by_label(contains, "macos", "Smoke button") == "node"
    locate.by_label(exact, "macos", "Smoke button", exact=True)

    assert contains.finds == [(AppiumBy.IOS_PREDICATE, 'label CONTAINS "Smoke button"')]
    assert exact.finds == [(AppiumBy.IOS_PREDICATE, 'label == "Smoke button"')]


def test_by_value_on_macos_matches_a_static_text_by_its_value() -> None:
    driver = ScriptDriver()

    assert locate.by_value(driver, "macos", "taps:") == "node"
    assert driver.finds == [(AppiumBy.IOS_PREDICATE, 'value CONTAINS "taps:"')]


@pytest.mark.parametrize("text", ['a"b', "a\\b"])
def test_by_value_refuses_a_quote_or_backslash(text: str) -> None:
    driver = ScriptDriver()

    with pytest.raises(ValueError, match="quote or backslash"):
        locate.by_value(driver, "macos", text)

    assert driver.finds == []


def test_by_value_refuses_a_platform_that_publishes_text_as_a_label() -> None:
    with pytest.raises(ValueError, match="does not support platform 'ios'"):
        locate.by_value(ScriptDriver(), "ios", "x")


def test_label_of_on_macos_reads_the_label_of_a_control() -> None:
    class Node:
        def get_attribute(self, name: str) -> str:
            return {"label": "Smoke button", "value": ""}[name]

    assert locate.label_of(Node(), "macos") == "Smoke button"


def test_label_of_on_macos_falls_back_to_the_value_of_a_static_text() -> None:
    class Node:
        def get_attribute(self, name: str) -> str:
            return {"label": "", "value": "taps: 1"}[name]

    assert locate.label_of(Node(), "macos") == "taps: 1"


@pytest.mark.parametrize("platform", ["macos", "web"])
def test_is_displayed_asks_a_driver_node_on_macos_and_a_locator_on_web(platform: str) -> None:
    class DriverNode:
        def is_displayed(self) -> bool:
            return True

    class Locator:
        def is_visible(self) -> bool:
            return True

    node: Any = DriverNode() if platform == "macos" else Locator()

    assert locate.is_displayed(node, platform) is True
