"""Restart the app under test as a real process restart (design section 5 example 5)."""

from __future__ import annotations

from typing import Any

from stratum_e2e.fixtures import open_fixture


def restart_app(driver: Any, platform: str, app_id: str, fixture_id: str) -> Any:
    """Kill the app and cold-start it on the fixture route for [fixture_id].

    Returns the live handle; every caller rebinds to it. Android returns the same
    [driver], because `open_fixture` force-stops the process and relaunches it
    outside the Appium session; iOS and macOS return the same [driver] too, because
    `open_fixture` terminates the app and launches it again inside the session.
    Web returns the same `Page`: `open_fixture` leaves the document for `about:blank`,
    which destroys the running app, then cold-loads the route, so the origin's storage
    persists while the app starts afresh. A second page in the same context would also
    keep the storage, but Playwright refuses `new_page` on the context that `browser.new_page`
    owns, and closing that page closes the context with the storage.
    Raises ValueError for a platform `open_fixture` does not support.
    """
    open_fixture(driver, platform, app_id, fixture_id)
    return driver
