"""Locate a node by its Flutter semantics identifier (design section 9 bullet 1)."""

from __future__ import annotations

from typing import Any

from appium.webdriver.common.appiumby import AppiumBy

_FORBIDDEN_IN_SELECTOR = ('"', "\\")


def by_id(driver: Any, platform: str, identifier: str) -> Any:
    """Find the node whose semantics identifier is [identifier].

    [driver] is an Appium driver, or a Playwright `Page` on web. Android matches the
    node's resource-id exactly through a UiSelector, because neither `AppiumBy.ID` form
    (bare id or `<app_id>:id/<id>`) reaches a Flutter identifier: Flutter publishes it as
    a bare resource-id with no package prefix. iOS matches the accessibility id, which
    Flutter fills from the identifier. Web returns a `Locator` on the
    `flt-semantics-identifier` attribute. macOS has no id locator: Flutter's macOS
    embedder maps no identifier to `AXIdentifier`, so use `by_label` or `by_value`.
    Raises ValueError for macOS or any other platform, or for an Android or web
    identifier holding a quote or backslash.
    """
    if platform == "ios":
        return driver.find_element(AppiumBy.ACCESSIBILITY_ID, identifier)
    if platform == "macos":
        raise ValueError(
            "by_id has no macOS locator: the macOS embedder exposes no AXIdentifier; "
            "use by_label or by_value"
        )
    if platform not in ("android", "web"):
        raise ValueError(f"by_id does not support platform {platform!r} yet")
    if any(char in identifier for char in _FORBIDDEN_IN_SELECTOR):
        raise ValueError(f"identifier {identifier!r} holds a quote or backslash")
    if platform == "web":
        return driver.locator(f'[flt-semantics-identifier="{identifier}"]')
    return driver.find_element(
        AppiumBy.ANDROID_UIAUTOMATOR, f'new UiSelector().resourceId("{identifier}")'
    )


def by_label(driver: Any, platform: str, label: str, *, exact: bool = False) -> Any:
    """Find the node whose accessibility label contains [label], or equals it when [exact].

    For a node with no semantics identifier: Flutter splits a node that carries one, so an
    actionable node (a button, a row, a slider) is found by its label. Android matches
    `content-desc` through a UiSelector `descriptionContains`, or `description` when
    [exact], since Flutter merges a node's value into its label (`30%, Resize panes`).
    iOS and macOS match `label` through a predicate `CONTAINS`, or `==` when [exact];
    Flutter keeps a value apart from the label there (`Resize panes`, value `30%`). Use [exact]
    when another node's label contains this one (`Item 3` inside `Log: Item 3 moved`).
    Raises ValueError for any other platform, or for a label holding a quote or backslash.
    """
    if platform not in ("android", "ios", "macos"):
        raise ValueError(f"by_label does not support platform {platform!r} yet")
    if any(char in label for char in _FORBIDDEN_IN_SELECTOR):
        raise ValueError(f"label {label!r} holds a quote or backslash")
    if platform in ("ios", "macos"):
        operator = "==" if exact else "CONTAINS"
        return driver.find_element(AppiumBy.IOS_PREDICATE, f'label {operator} "{label}"')
    method = "description" if exact else "descriptionContains"
    return driver.find_element(
        AppiumBy.ANDROID_UIAUTOMATOR, f'new UiSelector().{method}("{label}")'
    )


def by_value(driver: Any, platform: str, text: str) -> Any:
    """Find the macOS node whose accessibility value contains [text].

    Flutter's macOS embedder publishes a static text's string as the value and leaves its
    label empty, so `by_label` cannot reach it.
    Raises ValueError for any other platform, or for [text] holding a quote or backslash.
    """
    if platform != "macos":
        raise ValueError(f"by_value does not support platform {platform!r} yet")
    if any(char in text for char in _FORBIDDEN_IN_SELECTOR):
        raise ValueError(f"text {text!r} holds a quote or backslash")
    return driver.find_element(AppiumBy.IOS_PREDICATE, f'value CONTAINS "{text}"')


def label_of(node: Any, platform: str) -> str:
    """Return the text Flutter publishes for [node].

    That is `content-desc` on Android, `label` on iOS, and on web the text content of the
    `flt-semantics` element. On macOS it is the `label` of a control, or the `value` of a
    static text whose label is empty.
    Raises ValueError for any other platform.
    """
    if platform == "web":
        return str(node.text_content())
    if platform == "macos":
        return str(node.get_attribute("label") or node.get_attribute("value"))
    attributes = {"android": "content-desc", "ios": "label"}
    if platform not in attributes:
        raise ValueError(f"label_of does not support platform {platform!r} yet")
    return str(node.get_attribute(attributes[platform]))


def is_displayed(node: Any, platform: str) -> bool:
    """Return whether [node] is on screen: a driver element's `is_displayed`, a Locator's `is_visible`.

    Raises ValueError for any other platform.
    """
    if platform == "web":
        return bool(node.is_visible())
    if platform not in ("android", "ios", "macos"):
        raise ValueError(f"is_displayed does not support platform {platform!r} yet")
    return bool(node.is_displayed())
