"""An open drawer paints nothing on the strip beside `PageLayout`'s box.

Drives the `common/page_drawer_in_safe_area` fixture (FO-06 US-19 FR-04 E09). `PageLayout` sits
in a box narrower than the window (the iPhone Duo's side inset). Opening its drawer must leave
the strip beside the box as the closed screen shows it: no scrim, no dimmed page. The test shoots
the screen closed and open and compares the pixels on that strip, and on a column just inside the
box's edge, where the dimmed page must show. Level 1: it finds nodes through the OS accessibility
tree and reads screenshots; no screen reader runs.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.edge_strip import Strip, changed_points, edge_strips, strip_points
from stratum_e2e.fixtures import open_fixture_and_wait
from stratum_e2e.locate import NODE_NOT_FOUND, by_id, by_label, click, is_displayed
from stratum_e2e.system_bars import Png, read_png
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/page_drawer_in_safe_area"
BOX_ID = "page_drawer_in_safe_area.box"
LINK_A_ID = "page_drawer_in_safe_area.link_a"
OPEN_DRAWER = "Open drawer"
DRAWER_LINK_A = "Drawer link A"
# Width of the column just inside each strip's box edge, where the dimmed page shows.
INNER_COLUMN_PT = 8.0
SETTLE_TIMEOUT_S = 10
REPORTED_POINTS = 5


def _shot(driver: Any) -> Png:
    return read_png(driver.get_screenshot_as_png())


def _settled_shot(driver: Any, points: list[tuple[int, int]], what: str) -> Png:
    """Shoot until two consecutive shots agree on [points]; a poll interval apart, so a
    running animation or route transition cannot agree with itself."""
    shots: list[Png] = []

    def settled() -> bool:
        shots.append(_shot(driver))
        return len(shots) >= 2 and not changed_points(shots[-2], shots[-1], points)

    wait_until(settled, f"two {what} screenshots that agree", timeout_s=SETTLE_TIMEOUT_S)
    return shots[-1]


def _inner_column(strip: Strip) -> Strip:
    """The [INNER_COLUMN_PT] column of the box just inside [strip]'s box edge."""
    x, y, width, height = strip
    # A strip at x 0 is the left one: its box edge is its right side.
    inner_x = width if x == 0 else x - INNER_COLUMN_PT
    return (inner_x, y, INNER_COLUMN_PT, height)


def _on_screen(driver: Any, platform: str, label: str) -> bool:
    return is_displayed(by_label(driver, platform, label, exact=True), platform)


def _link_a_on_screen(driver: Any, platform: str) -> bool:
    try:
        return is_displayed(by_id(driver, platform, LINK_A_ID), platform)
    except NODE_NOT_FOUND:
        return False


@pytest.mark.ios
@pytest.mark.level1
@pytest.mark.req("fo06/us19/fr04/e09")
def test_an_open_drawer_paints_nothing_on_the_strip_beside_the_box(
    driver: Any, platform: str, app_id: str
) -> None:
    open_fixture_and_wait(
        driver,
        platform,
        app_id,
        FIXTURE_ID,
        lambda: _on_screen(driver, platform, OPEN_DRAWER),
        f"the {OPEN_DRAWER!r} button on screen",
    )
    rect = by_id(driver, platform, BOX_ID).rect
    box: Strip = (rect["x"], rect["y"], rect["width"], rect["height"])
    window_width = driver.get_window_size()["width"]
    strips = edge_strips(box, window_width)
    assert strips, "no strip beside the box: the device reports no side inset, so the probe proves nothing"

    scale = _shot(driver).width / window_width
    strip_pts = [p for strip in strips for p in strip_points(strip, scale)]
    inner_pts = [p for strip in strips for p in strip_points(_inner_column(strip), scale)]
    closed = _settled_shot(driver, strip_pts + inner_pts, "closed")

    click(by_label(driver, platform, OPEN_DRAWER, exact=True), platform)
    wait_until(
        lambda: _link_a_on_screen(driver, platform),
        f"{DRAWER_LINK_A!r} on screen",
        timeout_s=SETTLE_TIMEOUT_S,
    )

    opened = _settled_shot(driver, strip_pts + inner_pts, "open")

    painted = changed_points(closed, opened, strip_pts)
    assert not painted, (
        f"scrim or page painted on the strip beside the box at {painted[:REPORTED_POINTS]} "
        "(FO-06 US-19 FR-04 E09)"
    )
    assert changed_points(closed, opened, inner_pts), (
        "the dimmed page did not show inside the box; the shot missed the open drawer"
    )
