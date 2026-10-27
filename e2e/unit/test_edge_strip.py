"""Unit tests for the edge-strip pixel judge (FO-06 US-19 FR-04 E09)."""

from __future__ import annotations

import pytest

from stratum_e2e.edge_strip import changed_points, edge_strips, strip_points
from stratum_e2e.system_bars import Png


def _rgba(*pixels: tuple[int, int, int, int]) -> Png:
    return Png(len(pixels), 1, 4, bytearray(c for pixel in pixels for c in pixel))


def test_edge_strips_finds_the_strip_right_of_the_box() -> None:
    assert edge_strips((0, 47, 382, 900), 466) == [(382, 47, 84, 900)]


def test_edge_strips_finds_both_sides() -> None:
    assert edge_strips((84, 0, 298, 1000), 466) == [(0, 0, 84, 1000), (382, 0, 84, 1000)]


def test_edge_strips_skips_a_strip_under_one_point() -> None:
    assert edge_strips((0, 0, 465.5, 1000), 466) == []


def test_strip_points_stay_inside_the_strip() -> None:
    points = strip_points((382, 47, 84, 900), 3)
    assert points
    assert all(1152 <= x < 1392 for x, _ in points), points
    assert all(147 <= y < 2835 for _, y in points), points


def test_changed_points_reports_only_points_past_the_tolerance() -> None:
    before = _rgba((10, 10, 10, 255), (10, 10, 10, 255))
    after = _rgba((13, 10, 10, 255), (11, 10, 10, 255))
    assert changed_points(before, after, [(0, 0), (1, 0)]) == [(0, 0)]


def test_strip_points_fails_on_a_strip_too_short_to_sample() -> None:
    with pytest.raises(ValueError, match="no point to sample"):
        strip_points((382, 47, 84, 3), 3)


def test_changed_points_fails_on_an_empty_point_list() -> None:
    png = _rgba((10, 10, 10, 255))
    with pytest.raises(ValueError, match="no point to compare"):
        changed_points(png, png, [])
