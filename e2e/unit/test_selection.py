"""Unit tests for marker-driven platform selection."""

from __future__ import annotations

import pytest

from stratum_e2e.selection import PLATFORMS, skip_reason


def test_skip_reason_none_when_marker_matches() -> None:
    assert skip_reason({"android", "level1"}, "android") is None


def test_skip_reason_names_platform() -> None:
    assert skip_reason({"ios"}, "android") == "not marked android"


def test_skip_reason_without_platform() -> None:
    assert skip_reason({"android"}, None) == "no --platform given"


def test_skip_reason_web_ignored_without_platform() -> None:
    assert skip_reason({"web", "level2"}, None) == "no --platform given"


@pytest.mark.parametrize("platform", sorted(PLATFORMS))
def test_skip_reason_each_platform(platform: str) -> None:
    assert skip_reason({platform}, platform) is None
    assert all(skip_reason({platform}, other) is not None for other in PLATFORMS - {platform})
