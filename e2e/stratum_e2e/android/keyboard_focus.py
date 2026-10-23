"""Walk keyboard focus with Tab and read where it lands (design section 6, level 1 and 2).

Each Tab goes in only after the last move has held, and the focus it lands on must be the
one the caller expects; landing on any other labeled node fails at once. A Tab is never
pressed again to make up for one that did not land.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from stratum_e2e.android.dumps import touch_mode
from stratum_e2e.android.tree import key_focused
from stratum_e2e.waits import wait_until, wait_until_held

TAB_TIMEOUT_S = 10


def focus_label(driver: Any) -> str | None:
    """The one labeled node holding keyboard focus, or None while no labeled node or several do."""
    focused = key_focused(driver.page_source)
    return focused[0] if len(focused) == 1 else None


class LandedElsewhere(AssertionError):
    """A Tab put keyboard focus on a labeled node other than the expected one."""


def _landed(driver: Any, expected: str) -> bool:
    """Whether [expected] holds focus; raise LandedElsewhere when another labeled node does."""
    label = focus_label(driver)
    if label is not None and label != expected:
        raise LandedElsewhere(f"Tab landed on {label!r}, expected {expected!r}")
    return label == expected


def tab_to_first_label(driver: Any, press_tab: Callable[[], None], expected: str) -> None:
    """Press the first Tab and require [expected] to take keyboard focus and hold it.

    A window opened by touch is in touch mode: ViewRootImpl leaves it on the first navigation
    key and consumes that key, so Flutter never sees it. When the device reads touch mode, one
    Tab goes in first as the touch-mode exit and the walk waits until the device leaves touch
    mode; the next Tab is then the first one Flutter sees. Raises LandedElsewhere at once when
    another labeled node takes focus, and AssertionError when touch mode does not end or the
    first Tab does not put focus on [expected].
    """
    serial = str(driver.capabilities["udid"])
    if touch_mode(serial):
        press_tab()
        wait_until(
            lambda: not touch_mode(serial),
            "touch mode to end after a Tab",
            timeout_s=TAB_TIMEOUT_S,
        )
    press_tab()
    wait_until(
        lambda: _landed(driver, expected),
        f"keyboard focus on {expected!r} after a first Tab",
        timeout_s=TAB_TIMEOUT_S,
    )
    wait_until_held(
        lambda: focus_label(driver) == expected,
        f"keyboard focus to stay on {expected!r}",
        timeout_s=TAB_TIMEOUT_S,
    )


def tab_to_next_label(
    driver: Any, press_tab: Callable[[], None], previous: str, expected: str
) -> None:
    """Press Tab once and require [expected] to take keyboard focus from [previous].

    Raises AssertionError when another node, or none, holds focus after TAB_TIMEOUT_S.
    """
    press_tab()
    wait_until_held(
        lambda: focus_label(driver) == expected,
        f"keyboard focus on {expected!r} after {previous!r}",
        timeout_s=TAB_TIMEOUT_S,
    )
