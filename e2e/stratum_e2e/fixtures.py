"""Open one test_app fixture by route id (design section 8 and 9)."""

from __future__ import annotations

import subprocess
from typing import Any

from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e.waits import wait_until
from stratum_e2e.web.session import open_fixture_route

FIXTURE_ROUTE_PREFIX = "/fixture/"
ANDROID_MAIN_ACTIVITY = ".MainActivity"
# The group Flutter's macOS embedder adds under the window's content group once semantics flow.
MACOS_FLUTTER_TREE = "//XCUIElementTypeWindow/XCUIElementTypeGroup/XCUIElementTypeGroup"


def open_fixture(driver: Any, platform: str, app_id: str, fixture_id: str) -> None:
    """Cold-start [app_id] on the fixture route for [fixture_id].

    Android force-stops the app and waits for the launch, using the adb serial from
    the driver's `udid` capability. iOS and macOS terminate the app, then relaunch it
    with a `--route=` launch argument: a launch without one shows "unknown fixture:
    null". Web ignores [app_id] and reloads [driver], a `Page`, on the route.
    Raises ValueError for any other platform.
    """
    route = f"{FIXTURE_ROUTE_PREFIX}{fixture_id}"
    if platform == "android":
        _open_android(driver, app_id, route)
    elif platform == "ios":
        _open_with_route_argument(driver, "mobile", app_id, route)
    elif platform == "macos":
        _open_with_route_argument(driver, "macos", app_id, route)
        _wait_for_macos_flutter_tree(driver)
    elif platform == "web":
        open_fixture_route(driver, fixture_id)
    else:
        raise ValueError(f"open_fixture does not support platform {platform!r} yet")


def _open_android(driver: Any, app_id: str, route: str) -> None:
    serial = driver.capabilities["udid"]
    subprocess.run(
        [
            "adb", "-s", serial, "shell", "am", "start", "-S", "-W",
            "-n", f"{app_id}/{ANDROID_MAIN_ACTIVITY}",
            "--es", "route", route,
        ],
        check=True,
    )


def _open_with_route_argument(driver: Any, command_prefix: str, bundle_id: str, route: str) -> None:
    """Terminate and relaunch [bundle_id] through the `mobile:` (iOS) or `macos:` script commands."""
    driver.execute_script(f"{command_prefix}: terminateApp", {"bundleId": bundle_id})
    driver.execute_script(
        f"{command_prefix}: launchApp",
        {"bundleId": bundle_id, "arguments": [f"--route={route}"]},
    )


def _wait_for_macos_flutter_tree(driver: Any) -> None:
    """Wait until Flutter's semantics reach XCTest: Mac2 ignores the implicit wait, so a find
    straight after the relaunch would miss the first second of nodes."""
    wait_until(
        lambda: bool(driver.find_elements(AppiumBy.XPATH, MACOS_FLUTTER_TREE)),
        "the macOS Flutter accessibility tree",
    )
