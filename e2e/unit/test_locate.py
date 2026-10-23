"""Unit tests for the node locators, on a recording driver (no device)."""

from __future__ import annotations

from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e.locate import by_id, by_label, label_of


class RecordingDriver:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str]] = []

    def find_element(self, by: str, value: str) -> Any:
        self.calls.append((by, value))
        return "element"


def test_by_id_matches_the_resource_id_exactly() -> None:
    driver = RecordingDriver()

    assert by_id(driver, "android", "ink_well.button") == "element"
    assert driver.calls == [
        (AppiumBy.ANDROID_UIAUTOMATOR, 'new UiSelector().resourceId("ink_well.button")')
    ]


def test_by_label_matches_the_description_by_containment() -> None:
    driver = RecordingDriver()

    assert by_label(driver, "android", "Resize panes") == "element"
    assert driver.calls == [
        (AppiumBy.ANDROID_UIAUTOMATOR, 'new UiSelector().descriptionContains("Resize panes")')
    ]


def test_by_label_exact_matches_the_whole_label_on_both_platforms() -> None:
    android, ios = RecordingDriver(), RecordingDriver()

    by_label(android, "android", "Item 3", exact=True)
    by_label(ios, "ios", "Item 3", exact=True)

    assert android.calls == [(AppiumBy.ANDROID_UIAUTOMATOR, 'new UiSelector().description("Item 3")')]
    assert ios.calls == [(AppiumBy.IOS_PREDICATE, 'label == "Item 3"')]


def test_by_label_on_ios_matches_the_label_by_containment() -> None:
    driver = RecordingDriver()

    assert by_label(driver, "ios", "Resize panes") == "element"
    assert driver.calls == [(AppiumBy.IOS_PREDICATE, 'label CONTAINS "Resize panes"')]


@pytest.mark.parametrize("text", ['a"b', "a\\b"])
def test_by_label_on_ios_refuses_a_quote_or_backslash(text: str) -> None:
    driver = RecordingDriver()

    with pytest.raises(ValueError, match="quote or backslash"):
        by_label(driver, "ios", text)

    assert driver.calls == []


@pytest.mark.parametrize("locate", [by_id, by_label])
def test_locators_refuse_a_platform_without_a_driver_yet(locate: Any) -> None:
    with pytest.raises(ValueError, match="does not support platform 'linux'"):
        locate(RecordingDriver(), "linux", "x")


@pytest.mark.parametrize("locate", [by_id, by_label])
@pytest.mark.parametrize("text", ['a"b', "a\\b"])
def test_locators_refuse_a_quote_or_backslash(locate: Any, text: str) -> None:
    driver = RecordingDriver()

    with pytest.raises(ValueError, match="quote or backslash"):
        locate(driver, "android", text)

    assert driver.calls == []


class RecordingNode:
    def __init__(self) -> None:
        self.attributes: list[str] = []

    def get_attribute(self, name: str) -> str:
        self.attributes.append(name)
        return "taps: 1"


@pytest.mark.parametrize(("platform", "attribute"), [("android", "content-desc"), ("ios", "label")])
def test_label_of_reads_the_platforms_label_attribute(platform: str, attribute: str) -> None:
    node = RecordingNode()

    assert label_of(node, platform) == "taps: 1"
    assert node.attributes == [attribute]


def test_label_of_refuses_a_platform_without_a_driver_yet() -> None:
    with pytest.raises(ValueError, match="does not support platform 'linux'"):
        label_of(RecordingNode(), "linux")
