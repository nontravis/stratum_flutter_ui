"""Locate a node by its Flutter semantics identifier (design section 9 bullet 1)."""

from __future__ import annotations

from typing import Any

from appium.webdriver.common.appiumby import AppiumBy

_FORBIDDEN_IN_SELECTOR = ('"', "\\")


def by_id(driver: Any, platform: str, identifier: str) -> Any:
    """Find the node whose semantics identifier is [identifier].

    Android matches the node's resource-id exactly through a UiSelector, because
    neither `AppiumBy.ID` form (bare id or `<app_id>:id/<id>`) reaches a Flutter
    identifier: Flutter publishes it as a bare resource-id with no package prefix.
    Raises ValueError for any other platform, or for an identifier holding a quote
    or backslash.
    """
    if platform != "android":
        raise ValueError(f"by_id does not support platform {platform!r} yet")
    if any(char in identifier for char in _FORBIDDEN_IN_SELECTOR):
        raise ValueError(f"identifier {identifier!r} holds a quote or backslash")
    return driver.find_element(
        AppiumBy.ANDROID_UIAUTOMATOR, f'new UiSelector().resourceId("{identifier}")'
    )


def by_label(driver: Any, platform: str, label: str) -> Any:
    """Find the node whose accessibility label contains [label].

    For a node with no semantics identifier. Android matches `content-desc` through a
    UiSelector `descriptionContains`, since Flutter merges a node's value into its label
    (`30%, Resize panes`). Raises ValueError for any other platform, or for a label
    holding a quote or backslash.
    """
    if platform != "android":
        raise ValueError(f"by_label does not support platform {platform!r} yet")
    if any(char in label for char in _FORBIDDEN_IN_SELECTOR):
        raise ValueError(f"label {label!r} holds a quote or backslash")
    return driver.find_element(
        AppiumBy.ANDROID_UIAUTOMATOR, f'new UiSelector().descriptionContains("{label}")'
    )
