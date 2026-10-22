"""Open one test_app fixture by route id (design section 8 and 9)."""

from __future__ import annotations

import subprocess
from typing import Any

FIXTURE_ROUTE_PREFIX = "/fixture/"
ANDROID_MAIN_ACTIVITY = ".MainActivity"


def open_fixture(driver: Any, platform: str, app_id: str, fixture_id: str) -> None:
    """Cold-start [app_id] on the fixture route for [fixture_id].

    Android force-stops the app and waits for the launch, using the adb serial from
    the driver's `udid` capability. Raises ValueError for any other platform.
    """
    if platform != "android":
        raise ValueError(f"open_fixture does not support platform {platform!r} yet")
    serial = driver.capabilities["udid"]
    subprocess.run(
        [
            "adb", "-s", serial, "shell", "am", "start", "-S", "-W",
            "-n", f"{app_id}/{ANDROID_MAIN_ACTIVITY}",
            "--es", "route", f"{FIXTURE_ROUTE_PREFIX}{fixture_id}",
        ],
        check=True,
    )
