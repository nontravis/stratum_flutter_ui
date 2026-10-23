"""The one door to the operating system for the device round.

Round code takes a `Runner` and never calls `subprocess` itself, so a unit test swaps in
`unit/round_fakes.py::FakeRunner` and no test boots a device.
"""

from __future__ import annotations

import contextlib
import os
import signal
import subprocess
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

_NOT_FOUND_STATUS = 127
_TIMEOUT_STATUS = -signal.SIGKILL


@dataclass(frozen=True)
class Completed:
    """One finished command: its argv, exit status, captured text, and whether the timeout killed it."""

    argv: tuple[str, ...]
    status: int
    stdout: str
    stderr: str
    timed_out: bool


class Runner(Protocol):
    """Runs a command to completion (`run`) or leaves it running (`spawn`)."""

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed: ...

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]: ...


class SubprocessRunner:
    """The real Runner. `env` overlays `os.environ`; it never replaces it."""

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        """Run `argv` and capture its output; on timeout kill its whole process group, and on any exception (an
        interrupt included) kill and reap it before the exception goes on.

        A binary that does not exist yields status 127 with the reason on stderr, as a shell would.
        With `log`, stdout then stderr are also written to that file.
        """
        command = tuple(argv)
        try:
            process = subprocess.Popen(  # noqa: S603 - argv is a list, never a shell string
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                errors="replace",
                cwd=cwd,
                env=_overlay(env),
                start_new_session=True,
            )
        except FileNotFoundError as error:
            done = Completed(command, _NOT_FOUND_STATUS, "", f"{command[0]}: {error.strerror}\n", False)
            _write_log(log, done)
            return done

        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            timed_out = True
            with contextlib.suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGKILL)
            stdout, stderr = process.communicate()
        except BaseException:
            # A KeyboardInterrupt (a round's SIGTERM) lands here; the child runs in its own session, so no signal
            # reaches it unless the group is ended before the interrupt goes on.
            with contextlib.suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise

        status = _TIMEOUT_STATUS if timed_out else process.returncode
        done = Completed(command, status, stdout or "", stderr or "", timed_out)
        _write_log(log, done)
        return done

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]:
        """Start `argv` detached from this session, its output going to `log`; the caller owns the process."""
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open("ab") as sink:
            return subprocess.Popen(  # noqa: S603 - argv is a list, never a shell string
                tuple(argv),
                stdin=subprocess.DEVNULL,
                stdout=sink,
                stderr=subprocess.STDOUT,
                cwd=cwd,
                env=_overlay(env),
                start_new_session=True,
            )


def _overlay(env: Mapping[str, str] | None) -> dict[str, str] | None:
    return None if env is None else {**os.environ, **env}


def _write_log(log: Path | None, done: Completed) -> None:
    if log is None:
        return
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(done.stdout + done.stderr, encoding="utf-8")
