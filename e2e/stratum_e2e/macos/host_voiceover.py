"""Host VoiceOver on this Mac through AppleScript (design sections 6 and 8, ruling O1).

The helper uses VoiceOver's AppleScript dictionary (`sdef /System/Library/CoreServices/VoiceOver.app`):
the `quit` command stops it, `move` with the `right` direction moves the VO cursor to the next
item, and the `content` property of the `last phrase` object reads what it last spoke. The
standard `launch` verb starts it. VoiceOver answers only when "Allow VoiceOver to be controlled
with AppleScript" is on in VoiceOver Utility, a host setting this helper never changes.
"""

from __future__ import annotations

import contextlib
import subprocess
import time
from collections.abc import Callable
from types import TracebackType
from typing import Any

SETTING = "Allow VoiceOver to be controlled with AppleScript"
AUTOMATION_SETTING = "System Settings > Privacy & Security > Automation"
_NOT_AUTHORIZED = "-1743"
_MISSING_VALUE = "missing value"

_START = 'tell application "VoiceOver" to launch'
_STOP = 'tell application "VoiceOver" to quit'
_MOVE_NEXT = 'tell application "VoiceOver" to tell vo cursor to move right'
_PGREP = ["pgrep", "-x", "VoiceOver"]
_LAST_PHRASE = 'tell application "VoiceOver" to return content of last phrase'


RUN_TIMEOUT_SECONDS = 10.0
READY_TIMEOUT_SECONDS = 15.0
STOP_TIMEOUT_SECONDS = 10.0
POLL_INTERVAL_SECONDS = 0.25


class HostVoiceOverError(RuntimeError):
    """osascript or pgrep failed, timed out, or is missing while the helper drove VoiceOver."""


class HostVoiceOverAlreadyRunning(HostVoiceOverError):
    """VoiceOver was on before the helper started; the helper never takes it over."""


class HostVoiceOverNotReady(HostVoiceOverError):
    """VoiceOver launched but never answered an AppleScript read within the bound."""


class HostVoiceOverNotStopped(HostVoiceOverError):
    """VoiceOver still ran after `quit` and the bounded wait."""


def osascript_args(script: str) -> list[str]:
    """Return the argv that runs the AppleScript [script] through `osascript`."""
    return ["osascript", "-e", script]


class HostVoiceOver:
    """Host VoiceOver started for the block and always stopped at its end.

    [runner] has the signature of `subprocess.run`; tests pass a fake so no real
    VoiceOver starts. [sleep] and [clock] pace the bounded waits for readiness and shutdown.
    The helper never takes over a VoiceOver that already runs: it raises before it touches it.
    """

    def __init__(
        self,
        runner: Callable[..., Any] = subprocess.run,
        *,
        sleep: Callable[[float], None] = time.sleep,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._runner = runner
        self._sleep = sleep
        self._clock = clock

    def __enter__(self) -> HostVoiceOver:
        if self._is_running():
            raise HostVoiceOverAlreadyRunning(
                "VoiceOver is already on; the helper never takes over a running VoiceOver"
            )
        try:
            self._osascript(_START)
            self._wait_until_ready()
        except BaseException:
            # The start failure is the cause; a failing stop on top of it must not hide it.
            with contextlib.suppress(HostVoiceOverError):
                self._stop()
            raise
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        try:
            self._stop()
        except HostVoiceOverError:
            # A raising body is the cause; its exception must surface over a stop failure.
            if exc_type is None:
                raise

    def move_next(self) -> None:
        """Move the VO cursor to the next item."""
        self._osascript(_MOVE_NEXT)

    def last_phrase(self) -> str:
        """Return the text VoiceOver last spoke, or "" when it has spoken nothing yet."""
        phrase = self._osascript(_LAST_PHRASE).strip()
        return "" if phrase == _MISSING_VALUE else phrase

    def _wait_until_ready(self) -> None:
        """Poll a dictionary read until VoiceOver answers; raise NotReady on timeout."""
        last_error: HostVoiceOverError | None = None

        def answers() -> bool:
            nonlocal last_error
            try:
                self._osascript(_LAST_PHRASE)
            except HostVoiceOverError as error:
                last_error = error
                return False
            return True

        if not self._wait_until(answers, READY_TIMEOUT_SECONDS):
            raise HostVoiceOverNotReady(
                f"VoiceOver did not answer AppleScript within {READY_TIMEOUT_SECONDS:g}s; "
                f"last failure: {last_error}"
            ) from last_error

    def _stop(self) -> None:
        """Quit VoiceOver, then wait until no VoiceOver process remains."""
        self._osascript(_STOP)
        if not self._wait_until(lambda: not self._is_running(), STOP_TIMEOUT_SECONDS):
            raise HostVoiceOverNotStopped(
                f"VoiceOver still runs {STOP_TIMEOUT_SECONDS:g}s after quit"
            )

    def _wait_until(self, done: Callable[[], bool], timeout: float) -> bool:
        """Return whether [done] became true within [timeout] seconds, polling it."""
        deadline = self._clock() + timeout
        while not done():
            if self._clock() >= deadline:
                return False
            self._sleep(POLL_INTERVAL_SECONDS)
        return True

    def _is_running(self) -> bool:
        """Return whether `pgrep -x VoiceOver` prints a process id."""
        result = self._execute(_PGREP)
        if result.returncode not in (0, 1):
            raise HostVoiceOverError(
                f"pgrep exited {result.returncode}. stderr: {_text(result.stderr)}"
            )
        return bool(_text(result.stdout))

    def _osascript(self, script: str) -> str:
        """Run [script] and return its stdout; raise HostVoiceOverError on a non-zero exit."""
        result = self._execute(osascript_args(script))
        if result.returncode != 0:
            stderr = _text(result.stderr)
            if _NOT_AUTHORIZED in stderr:
                hint = (
                    "allow the process that runs the suite (terminal or IDE) under "
                    f"{AUTOMATION_SETTING}"
                )
            else:
                hint = f"check that '{SETTING}' is on in VoiceOver Utility"
            raise HostVoiceOverError(
                f"osascript exited {result.returncode} for {script!r}; {hint}. stderr: {stderr}"
            )
        return _text(result.stdout)

    def _execute(self, args: list[str]) -> Any:
        """Run [args] through the runner; a timeout or missing program raises the typed error."""
        try:
            return self._runner(
                args,
                capture_output=True,
                encoding="utf-8",
                check=False,
                timeout=RUN_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as error:
            raise HostVoiceOverError(
                f"{args[0]} timed out after {RUN_TIMEOUT_SECONDS:g}s; a pending macOS "
                f"Automation prompt for the process that runs the suite can block osascript"
            ) from error
        except FileNotFoundError as error:
            raise HostVoiceOverError(f"{args[0]} not found") from error


def _text(stream: str | None) -> str:
    """Return [stream] stripped, reading a missing stream as an empty one."""
    return (stream or "").strip()
