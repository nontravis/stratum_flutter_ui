"""Unit tests for the VoiceOver helper, on a scripted driver (no simulator)."""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.ios.voiceover import (
    UTTERANCE_LIMIT,
    VoiceOver,
    VoiceOverNoEdge,
    VoiceOverNotEnabled,
    VoiceOverSilent,
    matches_prefix,
)


class FakeDriver:
    """Driver stub: `moves` feeds voiceOverMove, `enabled` answers isVoiceOverEnabled."""

    def __init__(self, moves: list[str | None] | None = None, enabled: bool = True) -> None:
        self.moves = list(moves or [])
        self.enabled = enabled
        self.calls: list[tuple[str, dict[str, Any] | None]] = []

    def execute_script(self, script: str, args: dict[str, Any] | None = None) -> Any:
        self.calls.append((script, args))
        if script == "mobile: isVoiceOverEnabled":
            return {"enabled": self.enabled}
        if script == "mobile: voiceOverMove":
            return {"utterance": self.moves.pop(0)}
        if script == "mobile: voiceOverCurrentSpeech":
            return {"utterance": "current words"}
        return None

    def scripts(self) -> list[str]:
        return [script for script, _ in self.calls]


def test_enter_enables_then_checks_and_exit_disables() -> None:
    driver = FakeDriver()

    with VoiceOver(driver):
        pass

    assert driver.scripts() == [
        "mobile: enableVoiceOver",
        "mobile: isVoiceOverEnabled",
        "mobile: disableVoiceOver",
    ]


def test_disable_runs_on_exception() -> None:
    driver = FakeDriver()

    with pytest.raises(KeyError):
        with VoiceOver(driver):
            raise KeyError("boom")

    assert driver.scripts()[-1] == "mobile: disableVoiceOver"


def test_enter_refuses_a_voiceover_that_did_not_start_and_still_disables() -> None:
    driver = FakeDriver(enabled=False)

    with pytest.raises(VoiceOverNotEnabled):
        with VoiceOver(driver):
            pytest.fail("the with block must not run")

    assert driver.scripts()[-1] == "mobile: disableVoiceOver"


def test_current_returns_the_spoken_text() -> None:
    with VoiceOver(FakeDriver()) as voiceover:
        assert voiceover.current() == "current words"


@pytest.mark.parametrize("direction", ["forward", "backward"])
def test_move_sends_the_direction_and_returns_the_utterance(direction: str) -> None:
    driver = FakeDriver(moves=["Item 1 Button"])

    with VoiceOver(driver) as voiceover:
        spoken = voiceover.move(direction)  # type: ignore[arg-type]  # str stands in for the Literal

    assert spoken == "Item 1 Button"
    assert ("mobile: voiceOverMove", {"direction": direction}) in driver.calls


def test_move_returns_none_for_a_silent_move() -> None:
    with VoiceOver(FakeDriver(moves=[None])) as voiceover:
        assert voiceover.move("forward") is None


def test_walk_stops_on_repeat() -> None:
    driver = FakeDriver(moves=["A", None, "B", "B"])

    with VoiceOver(driver) as voiceover:
        assert voiceover.walk_forward() == ["A", "B"]


def test_walk_keeps_a_label_that_returns_after_another() -> None:
    driver = FakeDriver(moves=["A", "B", "A", "A"])

    with VoiceOver(driver) as voiceover:
        assert voiceover.walk_forward() == ["A", "B", "A"]


def test_walk_stops_at_max_moves() -> None:
    driver = FakeDriver(moves=["A", "B", "C", "D"])

    with VoiceOver(driver) as voiceover:
        assert voiceover.walk_forward(max_moves=3) == ["A", "B", "C"]


def test_walk_all_none_raises_voiceover_silent() -> None:
    driver = FakeDriver(moves=[None] * 30)

    with VoiceOver(driver) as voiceover:
        with pytest.raises(VoiceOverSilent):
            voiceover.walk_forward()


def test_walk_backward_returns_the_first_stop_then_each_move_until_a_repeat() -> None:
    driver = FakeDriver(moves=["B", "A", "A"])

    with VoiceOver(driver) as voiceover:
        assert voiceover.walk_backward("C") == ["C", "B", "A"]

    moves = [args for script, args in driver.calls if script == "mobile: voiceOverMove"]
    assert moves == [{"direction": "backward"}] * 3


def test_walk_backward_skips_a_silent_move() -> None:
    driver = FakeDriver(moves=[None, "A", None, "A"])

    with VoiceOver(driver) as voiceover:
        assert voiceover.walk_backward("B") == ["B", "A"]


def test_walk_backward_ends_at_once_when_the_first_stop_is_the_edge() -> None:
    driver = FakeDriver(moves=["C"])

    with VoiceOver(driver) as voiceover:
        assert voiceover.walk_backward("C") == ["C"]


def test_walk_backward_fails_when_the_cap_is_hit_with_no_repeat() -> None:
    driver = FakeDriver(moves=["A", "B", "C", "D"])

    with VoiceOver(driver) as voiceover:
        with pytest.raises(VoiceOverNoEdge):
            voiceover.walk_backward("Z", max_moves=3)


def test_walk_backward_fails_when_every_move_is_silent() -> None:
    driver = FakeDriver(moves=[None] * 30)

    with VoiceOver(driver) as voiceover:
        with pytest.raises(VoiceOverNoEdge):
            voiceover.walk_backward("Z")


def test_matches_prefix_truncates_expected_to_64() -> None:
    expected = "x" * 70

    assert UTTERANCE_LIMIT == 64
    assert matches_prefix(expected[:64], expected)


def test_matches_prefix_accepts_the_full_utterance_with_role_and_hint() -> None:
    assert matches_prefix("Item 1 Button Actions available", "Item 1")


def test_matches_prefix_rejects_a_different_start() -> None:
    assert not matches_prefix("Item 2 Button", "Item 1")


class FailingEnableDriver(FakeDriver):
    """Driver whose enable command raises after VoiceOver may already have toggled."""

    def execute_script(self, script: str, args: dict[str, Any] | None = None) -> Any:
        result = super().execute_script(script, args)
        if script == "mobile: enableVoiceOver":
            raise ConnectionError("lost the reply")
        return result


def test_enter_disables_when_the_enable_command_raises() -> None:
    driver = FailingEnableDriver()

    with pytest.raises(ConnectionError):
        with VoiceOver(driver):
            pytest.fail("the with block must not run")

    assert driver.scripts() == ["mobile: enableVoiceOver", "mobile: disableVoiceOver"]
