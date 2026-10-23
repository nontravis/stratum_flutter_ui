"""VoiceOver on the iOS simulator through Appium's `mobile:` commands (design section 8).

An utterance reads `<label> <role> <hint>` and stops at 64 characters. A move that
speaks nothing returns None: WebDriverAgent drops Apple's error, so None hides whether
focus reached the end, hit an unlabeled node, or VoiceOver failed.
"""

from __future__ import annotations

from types import TracebackType
from typing import Any, Literal

UTTERANCE_LIMIT = 64
DEFAULT_MAX_MOVES = 30

Direction = Literal["forward", "backward"]


class VoiceOverSilent(RuntimeError):
    """Every move of a walk returned no speech."""


class VoiceOverNotEnabled(RuntimeError):
    """`mobile: isVoiceOverEnabled` reported VoiceOver off right after the enable."""


def matches_prefix(utterance: str, expected: str) -> bool:
    """Return whether [utterance] starts with the first 64 characters of [expected]."""
    return utterance.startswith(expected[:UTTERANCE_LIMIT])


class VoiceOver:
    """VoiceOver turned on for the block and always turned off at its end."""

    def __init__(self, driver: Any) -> None:
        self._driver = driver

    def __enter__(self) -> VoiceOver:
        try:
            self._driver.execute_script("mobile: enableVoiceOver", {})
            state = self._driver.execute_script("mobile: isVoiceOverEnabled", {})
            if state != {"enabled": True}:
                raise VoiceOverNotEnabled(f"isVoiceOverEnabled returned {state!r}")
        except BaseException:
            self._disable()
            raise
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self._disable()

    def current(self) -> str | None:
        """Return what VoiceOver last spoke, or None when it spoke nothing."""
        return self._utterance("mobile: voiceOverCurrentSpeech", {})

    def move(self, direction: Direction) -> str | None:
        """Move focus one element in [direction]; return its utterance, or None when silent."""
        return self._utterance("mobile: voiceOverMove", {"direction": direction})

    def walk_forward(self, max_moves: int = DEFAULT_MAX_MOVES) -> list[str]:
        """Move forward up to [max_moves] times; return the spoken utterances in order.

        Skips silent moves and stops when an utterance repeats the previous one, which
        is the last element on screen. Raises VoiceOverSilent when no move spoke.
        """
        spoken: list[str] = []
        for _ in range(max_moves):
            utterance = self.move("forward")
            if utterance is None:
                continue
            if spoken and utterance == spoken[-1]:
                break
            spoken.append(utterance)
        if not spoken:
            raise VoiceOverSilent(f"{max_moves} forward moves spoke nothing")
        return spoken

    def _utterance(self, script: str, args: dict[str, Any]) -> str | None:
        reply = self._driver.execute_script(script, args)
        utterance = reply["utterance"]
        return None if utterance is None else str(utterance)

    def _disable(self) -> None:
        self._driver.execute_script("mobile: disableVoiceOver", {})
