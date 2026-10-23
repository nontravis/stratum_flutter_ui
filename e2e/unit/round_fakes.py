"""Fakes for the device round's unit tests: a scripted Runner that never touches the OS."""

from __future__ import annotations

import itertools
import subprocess
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import cast

from stratum_e2e.round.runner import Completed


class FakeProcess:
    """Stands in for `subprocess.Popen`: alive until `kill()`, then exited with -9."""

    _pids = itertools.count(1000)

    def __init__(self) -> None:
        self.pid: int = next(self._pids)
        self.returncode: int | None = None

    def poll(self) -> int | None:
        return self.returncode

    def kill(self) -> None:
        self.returncode = -9


class FakeRunner:
    """Answers `run` from a script; each entry answers one call.

    A call takes the first unconsumed entry whose argv is a prefix of the call's argv, so a repeated answer to
    one argv is a repeated entry, in order. A call with no such entry raises `AssertionError` naming its argv.
    `spawn` records the call in `calls` and returns a `FakeProcess`; it consumes no entry.
    """

    def __init__(self, script: Sequence[tuple[tuple[str, ...], Completed]]) -> None:
        self._pending: list[tuple[tuple[str, ...], Completed]] = list(script)
        self.calls: list[tuple[str, ...]] = []

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        call = tuple(argv)
        self.calls.append(call)
        for index, (prefix, answer) in enumerate(self._pending):
            if call[: len(prefix)] == prefix:
                del self._pending[index]
                return answer
        raise AssertionError(f"no unconsumed scripted answer for argv: {' '.join(call)}")

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]:
        self.calls.append(tuple(argv))
        return cast("subprocess.Popen[bytes]", FakeProcess())
