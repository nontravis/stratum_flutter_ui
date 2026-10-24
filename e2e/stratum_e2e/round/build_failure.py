"""Class a failed app build (design section 10): code under test that does not compile reads `fail`; anything else
(CMake, Gradle, Xcode, the toolchain, a timeout) is a tool failure and reads `env`."""

from __future__ import annotations

import re
from typing import Final

from stratum_e2e.round.errors import CompileFailure, RoundEnvError
from stratum_e2e.round.runner import Completed

# A Dart compiler diagnostic: `<path>.dart:<line>:<column>: Error: <message>`, the path relative or absolute.
_DART_ERROR: Final = re.compile(r"^\s*(?P<line>\S.*?\.dart:\d+:\d+: Error: .*?)\s*$", re.MULTILINE)
_TAIL_LINES: Final = 3


def build_failure(command: str, completed: Completed) -> CompileFailure | RoundEnvError:
    """The error to raise for a build of `command` that ended `completed` with a non-zero exit.

    The first Dart compiler error in the output makes it `CompileFailure("app build: <that line>")`, whatever else
    failed beside it. Otherwise, and always after a timeout, it is `RoundEnvError` naming the exit and the last lines
    of the output (stderr when there is any).
    """
    if not completed.timed_out:
        diagnostic = _DART_ERROR.search(f"{completed.stdout}\n{completed.stderr}")
        if diagnostic is not None:
            return CompileFailure(f"app build: {diagnostic.group('line')}")
    how = "timed out" if completed.timed_out else f"exit {completed.status}"
    return RoundEnvError(f"{command} failed ({how}): {error_tail(completed.stderr or completed.stdout)}")


def error_tail(text: str) -> str:
    """The last few non-empty lines of `text`, joined on one line."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return " | ".join(lines[-_TAIL_LINES:])
