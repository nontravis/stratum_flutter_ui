"""Poll-until helpers for the e2e tests (design section 8: poll with a timeout, never sleep())."""

from __future__ import annotations

import time
from typing import Callable

DEFAULT_TIMEOUT_S = 20
POLL_INTERVAL_S = 0.25
# How long an OS-state read must keep holding before it counts as settled: a style write that
# lands and is then reverted by the platform shows up inside this window.
DEFAULT_HOLD_S = 1.5


def wait_until(
    condition: Callable[[], bool],
    what: str,
    *,
    timeout_s: float = DEFAULT_TIMEOUT_S,
    poll_interval_s: float = POLL_INTERVAL_S,
    catch: tuple[type[Exception], ...] = (),
) -> None:
    """Poll [condition] until it holds or [timeout_s] passes; raise AssertionError naming [what].

    An exception of a type in [catch] counts as "not yet"; the timeout text names it only when the
    last read raised. Any other exception propagates.
    """
    deadline = time.monotonic() + timeout_s
    last_error: Exception | None = None
    while True:
        try:
            holds = condition()
            last_error = None
            if holds:
                return
        except catch as error:
            last_error = error
        if time.monotonic() > deadline:
            raise AssertionError(_timeout_text(timeout_s, what, last_error))
        time.sleep(poll_interval_s)


def wait_until_held(
    condition: Callable[[], bool],
    what: str,
    *,
    hold_s: float = DEFAULT_HOLD_S,
    timeout_s: float = DEFAULT_TIMEOUT_S,
    poll_interval_s: float = POLL_INTERVAL_S,
    catch: tuple[type[Exception], ...] = (),
) -> None:
    """Return once [condition] has read true across reads spanning [hold_s], without a false read.

    The hold starts at the first true read and restarts at every false read or caught error.
    Raise AssertionError naming [what] when [timeout_s] passes first, so a state that lands and
    then reverts never settles. An exception of a type in [catch] counts as a false read; the
    timeout text names it only when the last read raised. Any other exception propagates.
    """
    deadline = time.monotonic() + timeout_s
    held_since: float | None = None
    last_error: Exception | None = None
    while True:
        now = time.monotonic()
        try:
            holds = condition()
            last_error = None
        except catch as error:
            holds = False
            last_error = error
        if not holds:
            held_since = None
        elif held_since is None:
            held_since = now
        elif now - held_since >= hold_s:
            return
        if time.monotonic() > deadline:
            raise AssertionError(_timeout_text(timeout_s, f"{what} to hold {hold_s}s", last_error))
        time.sleep(poll_interval_s)


def _timeout_text(timeout_s: float, what: str, last_error: Exception | None) -> str:
    text = f"timed out after {timeout_s}s waiting for {what}"
    if last_error is not None:
        text += f" (last error: {type(last_error).__name__}: {last_error})"
    return text
