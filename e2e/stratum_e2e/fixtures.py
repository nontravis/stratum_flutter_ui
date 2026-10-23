"""Open one test_app fixture by route id (design section 8 and 9)."""

from __future__ import annotations

import subprocess
from typing import Any

FIXTURE_ROUTE_PREFIX = "/fixture/"
ANDROID_MAIN_ACTIVITY = ".MainActivity"


def open_fixture(driver: Any, platform: str, app_id: str, fixture_id: str) -> None:
    """Cold-start [app_id] on the fixture route for [fixture_id].

    Android force-stops the app and waits for the launch, using the adb serial from
    the driver's `udid` capability. iOS terminates the app, then relaunches it with
    a `--route=` launch argument: a launch without one shows "unknown fixture: null".
    Raises ValueError for any other platform.
    """
    route = f"{FIXTURE_ROUTE_PREFIX}{fixture_id}"
    if platform == "android":
        _open_android(driver, app_id, route)
    elif platform == "ios":
        _open_ios(driver, app_id, route)
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


def _open_ios(driver: Any, bundle_id: str, route: str) -> None:
    driver.execute_script("mobile: terminateApp", {"bundleId": bundle_id})
    driver.execute_script(
        "mobile: launchApp", {"bundleId": bundle_id, "arguments": [f"--route={route}"]}
    )
