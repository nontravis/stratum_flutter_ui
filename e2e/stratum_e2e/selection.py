"""Marker-driven platform selection for e2e tests (design sections 6 and 7)."""

from __future__ import annotations

PLATFORMS = frozenset({"android", "ios", "macos", "web"})


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
