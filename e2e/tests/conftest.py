"""Skip hook for items under tests/ only, so unit/ runs under any --platform."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.selection import skip_reason

TESTS_DIR = Path(__file__).resolve().parent


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    platform = config.getoption("--platform")
    for item in items:
        if TESTS_DIR not in Path(str(item.path)).resolve().parents:
            continue
        markers = {marker.name for marker in item.iter_markers()}
        reason = skip_reason(markers, platform)
        if reason is not None:
            item.add_marker(pytest.mark.skip(reason=reason))
