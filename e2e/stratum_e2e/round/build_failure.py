"""Name a failed app build (design section 10). Every failed build reads `build`, a class that claims no blame, so
the only choice made here is the line a reader sees first."""

from __future__ import annotations

import re
from collections.abc import Sequence
from pathlib import Path
from typing import Final

from stratum_e2e.round.errors import BuildFailure
from stratum_e2e.round.runner import Completed

_TAIL_LINES: Final = 3
_ERROR_WORD: Final = re.compile(r"\berror\b", re.IGNORECASE)


def build_failure(
    command: str, argv: Sequence[str], completed: Completed, seconds: float, log: Path
) -> BuildFailure:
    """The `BuildFailure` of `argv` (shown as `command`), which ended `completed` after `seconds` with a non-zero exit
    or a timeout, its output in `log`.

    The reason is the output's first error line (`first_error_line`, stdout before stderr), or the exit when no line
    says error. A timeout says so whatever the output holds.
    """
    if completed.timed_out:
        reason = f"{command} timed out"
    else:
        line = first_error_line(f"{completed.stdout}\n{completed.stderr}")
        reason = line if line is not None else f"{command} failed (exit {completed.status})"
    return BuildFailure(reason, log, tuple(argv), seconds)


def first_error_line(text: str) -> str | None:
    """The first line of `text` that says `error`, stripped; `None` when none does.

    It names a failure for a reader and nothing else: a poor pick changes the reason text, never a class.
    """
    return next((line.strip() for line in text.splitlines() if _ERROR_WORD.search(line)), None)


def error_tail(text: str) -> str:
    """The last few non-empty lines of `text`, joined on one line."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return " | ".join(lines[-_TAIL_LINES:])
