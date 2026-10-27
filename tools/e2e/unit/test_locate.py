"""Unit tests for the node locators, on a recording driver (no device)."""

from __future__ import annotations

from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e import locate
from stratum_e2e.locate import by_id, by_label, by_static_text, click, label_of


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


class RecordingPage:
    def __init__(self) -> None:
        self.calls: list[tuple[str, tuple[Any, ...], dict[str, Any]]] = []

    def get_by_role(self, role: str, **options: Any) -> str:
        self.calls.append(("get_by_role", (role,), options))
        return "locator"

    def locator(self, selector: str) -> str:
        self.calls.append(("locator", (selector,), {}))
        return "locator"


def test_by_label_on_web_matches_the_button_by_its_accessible_name() -> None:
    page = RecordingPage()

    assert by_label(page, "web", "Open modal") == "locator"
    assert page.calls == [("get_by_role", ("button",), {"name": "Open modal", "exact": False})]


def test_by_label_on_web_exact_matches_the_whole_name() -> None:
    page = RecordingPage()

    by_label(page, "web", "Item 3", exact=True)

    assert page.calls == [("get_by_role", ("button",), {"name": "Item 3", "exact": True})]


def test_by_static_text_uses_the_id_where_the_platform_has_one() -> None:
    android, web = RecordingDriver(), RecordingPage()

    by_static_text(android, "android", "ink_well.log", "Log:")
    by_static_text(web, "web", "ink_well.log", "Log:")

    assert android.calls == [
        (AppiumBy.ANDROID_UIAUTOMATOR, 'new UiSelector().resourceId("ink_well.log")')
    ]
    assert web.calls == [("locator", ('[flt-semantics-identifier="ink_well.log"]',), {})]


def test_by_static_text_on_macos_matches_the_value_that_holds_the_text() -> None:
    driver = RecordingDriver()

    assert by_static_text(driver, "macos", "ink_well.log", "Log:") == "element"
    assert driver.calls == [(AppiumBy.IOS_PREDICATE, 'value CONTAINS "Log:"')]


def test_node_not_found_covers_an_appium_miss_and_a_playwright_timeout() -> None:
    from playwright.sync_api import TimeoutError as PlaywrightTimeout
    from selenium.common.exceptions import NoSuchElementException

    assert issubclass(NoSuchElementException, locate.NODE_NOT_FOUND)
    assert issubclass(PlaywrightTimeout, locate.NODE_NOT_FOUND)


class ClickableNode:
    def __init__(self) -> None:
        self.clicks: list[dict[str, Any]] = []

    def click(self, **options: Any) -> None:
        self.clicks.append(options)


def test_click_on_web_gives_up_on_a_missing_button_within_a_poll() -> None:
    node = ClickableNode()

    click(node, "web")

    assert node.clicks == [{"timeout": locate.WEB_READ_TIMEOUT_MS}]


@pytest.mark.parametrize("platform", ["android", "ios", "macos"])
def test_click_on_a_driver_platform_is_the_elements_own_click(platform: str) -> None:
    node = ClickableNode()

    click(node, platform)

    assert node.clicks == [{}]


def test_click_refuses_a_platform_without_a_driver_yet() -> None:
    with pytest.raises(ValueError, match="does not support platform 'linux'"):
        click(ClickableNode(), "linux")
