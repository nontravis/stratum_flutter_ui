"""Unit tests for the node locators, on a recording driver (no device)."""

from __future__ import annotations

from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e.locate import by_id, by_label


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


@pytest.mark.parametrize("locate", [by_id, by_label])
def test_locators_refuse_a_platform_without_a_driver_yet(locate: Any) -> None:
    with pytest.raises(ValueError, match="does not support platform 'ios'"):
        locate(RecordingDriver(), "ios", "x")


@pytest.mark.parametrize("locate", [by_id, by_label])
@pytest.mark.parametrize("text", ['a"b', "a\\b"])
def test_locators_refuse_a_quote_or_backslash(locate: Any, text: str) -> None:
    driver = RecordingDriver()

    with pytest.raises(ValueError, match="quote or backslash"):
        locate(driver, "android", text)

    assert driver.calls == []
