"""Unit tests for the O3 measurement: verdict helpers and exit codes (no simulator)."""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.measure_voiceover_scroll import (
    LAST_FIRST_SCREEN_ROW_LABEL,
    spoken_beyond,
    verdict,
    visible_labels,
    walk,
)

PAGE_SOURCE = """<AppiumAUT>
  <XCUIElementTypeCell visible="true" label="General"/>
  <XCUIElementTypeCell visible="false" label="Developer"/>
  <XCUIElementTypeCell visible="true"/>
</AppiumAUT>"""

FIRST_SCREEN = f"""<AppiumAUT>
  <XCUIElementTypeCell visible="true" label="General"/>
  <XCUIElementTypeCell visible="true" label="{LAST_FIRST_SCREEN_ROW_LABEL}"/>
</AppiumAUT>"""


class SettingsDriver:
    """Driver stub: a laid-out first screen and a scripted VoiceOver."""

    page_source = FIRST_SCREEN

    def __init__(self, moves: list[str | None]) -> None:
        self.moves = list(moves)

    def execute_script(self, script: str, args: dict[str, Any]) -> Any:
        if script == "mobile: isVoiceOverEnabled":
            return {"enabled": True}
        if script == "mobile: voiceOverMove":
            return {"utterance": self.moves.pop(0) if self.moves else None}
        return None


def test_visible_labels_keeps_only_visible_labeled_nodes() -> None:
    assert visible_labels(PAGE_SOURCE) == ["General"]


def test_spoken_beyond_lists_utterances_of_elements_not_visible_before() -> None:
    before = ["General", "Siri"]
    spoken = ["General Button", "Siri Button", "Screen Time Button"]

    assert spoken_beyond(before, spoken) == ["Screen Time Button"]


def test_spoken_beyond_is_empty_when_every_utterance_was_visible_before() -> None:
    assert spoken_beyond(["General"], ["General Button"]) == []


def test_verdict_blames_flutters_bridge_when_voiceover_scrolled() -> None:
    assert verdict(["Screen Time Button"]).endswith("the stop is Flutter's iOS bridge")


def test_verdict_blames_the_simulator_when_voiceover_did_not_scroll() -> None:
    assert verdict([]).endswith("the stop is the simulator's VoiceOver")


def test_walk_exits_1_when_voiceover_spoke_nothing(capsys: pytest.CaptureFixture[str]) -> None:
    assert walk(SettingsDriver([]), max_moves=3) == 1  # type: ignore[arg-type]  # stub driver

    assert "inconclusive" in capsys.readouterr().out


def test_walk_exits_0_and_prints_the_verdict(capsys: pytest.CaptureFixture[str]) -> None:
    driver = SettingsDriver(["General Button", "Screen Time Button", "Screen Time Button"])

    assert walk(driver, max_moves=5) == 0  # type: ignore[arg-type]  # stub driver

    assert "Flutter's iOS bridge" in capsys.readouterr().out
