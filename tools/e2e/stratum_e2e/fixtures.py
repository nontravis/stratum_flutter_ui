"""Open one test_app fixture by route id (design section 8 and 9)."""

from __future__ import annotations

import subprocess
from typing import Any, Callable

from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e.locate import NODE_NOT_FOUND
from stratum_e2e.waits import wait_until
from stratum_e2e.web.session import open_fixture_route

FIXTURE_ROUTE_PREFIX = "/fixture/"
ANDROID_MAIN_ACTIVITY = ".MainActivity"
# The group Flutter's macOS embedder adds under the window's content group once semantics flow.
MACOS_FLUTTER_TREE = "//XCUIElementTypeWindow/XCUIElementTypeGroup/XCUIElementTypeGroup"
# How long a cold start may take before the waited-for node must be on screen: the AVD
# launched an app in 3 s at best and 26 s while the whole device ran slow (M10 gate round),
# so every open-and-wait helper below waits this long, no longer.
OPEN_WAIT_TIMEOUT_S = 10


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


def open_fixture_and_wait(
    driver: Any,
    platform: str,
    app_id: str,
    fixture_id: str,
    until: Callable[[], bool],
    what: str,
) -> None:
    """Cold-start the fixture and wait (bounded) until [until] holds.

    Each test owns its stop condition ([until] reads a node's display, or a list's order).
    A find or page-source read that misses while the app is still launching counts as
    not-yet (`NODE_NOT_FOUND`), so the error a half-open window raises never escapes the
    wait. One helper owns the cold start, the catch, and the timeout, so no per-file
    open-and-wait helper repeats them.
    """
    open_fixture(driver, platform, app_id, fixture_id)
    wait_until(
        until,
        what,
        timeout_s=OPEN_WAIT_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )


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
