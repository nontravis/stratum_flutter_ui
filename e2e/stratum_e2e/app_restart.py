"""Restart the app under test as a real process restart (design section 5 example 5)."""

from __future__ import annotations

from typing import Any

from stratum_e2e.fixtures import open_fixture


def restart_app(driver: Any, platform: str, app_id: str, fixture_id: str) -> Any:
    """Kill the app and cold-start it on the fixture route for [fixture_id].

    Returns the live handle; every caller rebinds to it. Android returns the same
    [driver], because `open_fixture` force-stops the process and relaunches it
    outside the Appium session; iOS returns the same [driver] too, because
    `open_fixture` terminates the app and launches it again inside the session.
    Web returns a new `Page` once M5-T28 adds it.
    Raises ValueError for web, and for any platform `open_fixture` does not
    support yet (M5-T28 adds the other platforms).
    """
    if platform == "web":
        raise ValueError("restart_app does not support platform 'web' yet")
    open_fixture(driver, platform, app_id, fixture_id)
    return driver
