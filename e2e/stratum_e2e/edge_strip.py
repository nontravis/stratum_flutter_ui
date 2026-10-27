"""Edge-strip pixel judge for the e2e suite: does anything paint beside a box?

`PageLayout` in a box smaller than the window must leave the strip outside the box
untouched when its drawer opens (FO-06 US-19 FR-04, E09). The probe shoots the screen
closed and open and compares the pixels on that strip. Stdlib only, as `system_bars.py`.
"""

from __future__ import annotations

from stratum_e2e.system_bars import Png

# x, y, width, height in points.
Strip = tuple[float, float, float, float]

MIN_STRIP_WIDTH_PT = 1.0


def edge_strips(box: Strip, window_width: float) -> list[Strip]:
    """Returns the strips left and right of [box] over the box's own vertical span.

    The span keeps the status bar and the home indicator out. A side narrower than one
    point is no strip.
    """
    x, y, width, height = box
    strips: list[Strip] = []
    if x >= MIN_STRIP_WIDTH_PT:
        strips.append((0.0, y, x, height))
    right = x + width
    if window_width - right >= MIN_STRIP_WIDTH_PT:
        strips.append((right, y, window_width - right, height))
    return strips


def strip_points(
    strip: Strip, scale: float, step_pt: float = 24.0, margin_pt: float = 2.0
) -> list[tuple[int, int]]:
    """Returns screenshot pixels inside [strip], [margin_pt] in from each edge.

    The points sit on the strip's center column, every [step_pt] down.

    Raises:
        ValueError: When [strip] is too short to hold one point, so a check on it would
            sample nothing and pass.
    """
    x, y, width, height = strip
    column = round((x + width / 2) * scale)
    points: list[tuple[int, int]] = []
    offset = margin_pt
    while offset <= height - margin_pt:
        points.append((column, round((y + offset) * scale)))
        offset += step_pt
    if not points:
        raise ValueError(f"strip {strip} is under {2 * margin_pt} pt tall: no point to sample")
    return points


def changed_points(
    before: Png, after: Png, points: list[tuple[int, int]], tolerance: int = 2
) -> list[tuple[int, int]]:
    """Returns the [points] where any RGBA channel differs by more than [tolerance].

    Raises:
        ValueError: When [points] is empty, so the comparison would sample nothing and pass.
    """
    if not points:
        raise ValueError("no point to compare: the check would pass without sampling")
    return [
        (x, y)
        for x, y in points
        if any(abs(a - b) > tolerance for a, b in zip(before.get(x, y), after.get(x, y)))
    ]
