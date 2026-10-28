"""Unit tests for the one marker-to-AVD map of the dedicated e2e AVDs (ruling Q3 amendment, 2026-10-27)."""

from __future__ import annotations

import pytest

from stratum_e2e.android.adb import (
    DEDICATED_AVD_BY_MARKER,
    DEDICATED_AVDS,
    STYLUS_AVD,
    TALKBACK_AVD,
    dedicated_avds,
)


def test_the_map_names_the_two_dedicated_avds() -> None:
    assert TALKBACK_AVD == "E2E_TalkBack_API_35"
    assert STYLUS_AVD == "E2E_Stylus_API_36"
    assert dict(DEDICATED_AVD_BY_MARKER) == {
        "talkback_avd": TALKBACK_AVD,
        "level2": TALKBACK_AVD,
        "stylus_avd": STYLUS_AVD,
    }
    assert DEDICATED_AVDS == {TALKBACK_AVD, STYLUS_AVD}


@pytest.mark.parametrize(
    ("markers", "expected"),
    [
        ({"android"}, set()),
        ({"android", "level1"}, set()),
        ({"android", "talkback_avd"}, {TALKBACK_AVD}),
        ({"android", "level2"}, {TALKBACK_AVD}),
        ({"android", "level2", "talkback_avd"}, {TALKBACK_AVD}),
        ({"android", "stylus_avd"}, {STYLUS_AVD}),
        ({"android", "stylus_avd", "talkback_avd"}, {STYLUS_AVD, TALKBACK_AVD}),
    ],
)
def test_dedicated_avds_names_the_avd_of_every_marker_the_item_carries(
    markers: set[str], expected: set[str]
) -> None:
    assert dedicated_avds(markers) == expected
