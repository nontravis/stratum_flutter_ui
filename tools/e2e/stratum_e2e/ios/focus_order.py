"""The focus order VoiceOver walks on the iOS simulator (design section 8, iOS limits).

VoiceOver opens an app on a first stop whose speech starts with the app's name, then each
forward move reaches the next stop; the last stop repeats. The order is the first stop
(without the app name) followed by the forward walk.
"""

from __future__ import annotations

from typing import Any

from stratum_e2e.ios.tree import nodes
from stratum_e2e.ios.voiceover import VoiceOver, matches_prefix
from stratum_e2e.waits import wait_until

FIRST_STOP_TIMEOUT_S = 10


def strip_app_name(utterance: str | None, app_name: str) -> str:
    """Return [utterance] without the leading [app_name]; "" when it spoke only the name or nothing."""
    if utterance is None:
        return ""
    return utterance.removeprefix(app_name).strip()


def focus_order(driver: Any, voiceover: VoiceOver) -> list[str]:
    """Return the speech of every stop, from VoiceOver's first stop to the last on screen.

    VoiceOver speaks its first stop a moment after it turns on, so the read polls until the
    speech holds more than the app name. The first stop is dropped when it never does. Raises
    VoiceOverSilent when the forward walk spoke nothing.
    """
    app_name = next(
        node.label for node in nodes(driver.page_source) if node.kind == "Application"
    )
    try:
        wait_until(
            lambda: strip_app_name(voiceover.current(), app_name) != "",
            "VoiceOver to speak its first stop",
            timeout_s=FIRST_STOP_TIMEOUT_S,
        )
    except AssertionError:
        pass  # a first stop that never speaks is no stop; the walk below still has to
    first = strip_app_name(voiceover.current(), app_name)
    walked = voiceover.walk_forward()
    return [first, *walked] if first else walked


def matches_order(spoken: list[str], expected: list[str]) -> bool:
    """Return whether [spoken] and [expected] have the same length and each pair matches by prefix.

    A pair matches as `voiceover.matches_prefix` does: VoiceOver's utterance stops at 64 characters.
    """
    return len(spoken) == len(expected) and all(
        matches_prefix(utterance, wanted) for utterance, wanted in zip(spoken, expected)
    )
