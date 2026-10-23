"""Marker-driven platform selection for e2e tests (design sections 6 and 7)."""

from __future__ import annotations

from typing import TYPE_CHECKING

from stratum_e2e.android.talkback import AVD_NAME

if TYPE_CHECKING:
    from stratum_e2e.round.catalog import Target

PLATFORMS = frozenset({"android", "ios", "macos", "web"})
_TALKBACK_MARKERS = frozenset({"talkback_avd", "level2"})


def skip_reason(markers: set[str], platform: str | None) -> str | None:
    """Return why a tests/ item skips for [platform], or None when it runs.

    A test runs only when --platform names one of its platform markers; a
    platform marker with no --platform also skips, so no e2e test ever runs
    against a host nobody selected.
    """
    if platform is None:
        return "no --platform given"
    if platform not in markers:
        return f"not marked {platform}"
    return None


def runs_e2e(target: Target, markers: set[str]) -> bool:
    """Return whether the round target [target] runs a tests/ e2e item carrying [markers] (design section 7).

    A target runs the items marked for its own platform. A `perf` item runs on the macOS target only. On Android the
    dedicated TalkBack AVD runs the `talkback_avd` and `level2` items and every other Android target runs the rest.
    A target with `e2e = false` runs none.
    """
    if not target.e2e:
        return False
    if "perf" in markers:
        return target.platform == "macos"
    if target.platform not in markers:
        return False
    if target.platform != "android":
        return True
    return (target.avd == AVD_NAME) == bool(markers & _TALKBACK_MARKERS)
