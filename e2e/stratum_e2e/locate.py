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
