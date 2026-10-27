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
# The actions menu's command name: "actions" is the English name ScreenReader maps to
# Global.showActionsMenu in /System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/
# Resources/SCRStringsToCommandsMap.scrconfig; `perform command` takes it (sdef).
_PERFORM_ACTIONS = 'tell application "VoiceOver" to perform command "actions"'
_MOVE_MENU_ENTRY_DOWN = 'tell application "VoiceOver" to tell vo cursor to move down'
_CLOSE_MENU = 'tell application "VoiceOver" to close menu'


RUN_TIMEOUT_SECONDS = 10.0
READY_TIMEOUT_SECONDS = 15.0
STOP_TIMEOUT_SECONDS = 10.0
POLL_INTERVAL_SECONDS = 0.25
ACTIONS_MENU_MAX_ENTRIES = 30
MENU_PHRASE_TIMEOUT_SECONDS = 3.0
MENU_QUIET_SECONDS = 0.25


class HostVoiceOverError(RuntimeError):
    """osascript or pgrep failed, timed out, or is missing while the helper drove VoiceOver."""


class HostVoiceOverAlreadyRunning(HostVoiceOverError):
    """VoiceOver was on before the helper started; the helper never takes it over."""


class HostVoiceOverNotReady(HostVoiceOverError):
    """VoiceOver launched but never answered an AppleScript read within the bound."""


class HostVoiceOverNotStopped(HostVoiceOverError):
    """VoiceOver still ran after `quit` and the bounded wait."""


class HostVoiceOverSilent(HostVoiceOverError):
    """A driven step never changed what VoiceOver spoke within its bound."""


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

    def actions_menu(self) -> list[str]:
        """Open VoiceOver's actions menu on the VO cursor's item and return its entries, spoken.

        The menu opens with `perform command "actions"`. Every entry, the first included, is
        taken with the quiet-read discipline (N2): two phrase reads MENU_QUIET_SECONDS apart
        must agree before it is recorded and before the next move, so a hint that lands late is
        neither recorded as an entry nor skips one. The walk ends at the first entry whose
        settled phrase repeats, and `close menu` always runs; its failure after a broken walk is
        suppressed, so it cannot mask the walk's error. Raises `HostVoiceOverSilent` when the
        menu never opens, so a wrong command name fails loudly instead of reading the item's
        own phrase back as one unchanging entry.
        """
        entries: list[str] = []
        walk_error: BaseException | None = None
        try:
            before = self._quiet_phrase()
            self._osascript(_PERFORM_ACTIONS)
            entries.append(self._settled_new_phrase(before, "the actions menu to open"))
            while len(entries) < ACTIONS_MENU_MAX_ENTRIES:
                self._osascript(_MOVE_MENU_ENTRY_DOWN)
                try:
                    entry = self._settled_new_phrase(entries[-1], "the next menu entry")
                except HostVoiceOverSilent:
                    # The last entry repeats its phrase; a menu that does not wrap ends here.
                    break
                if entry == entries[-1]:
                    break
                entries.append(entry)
        except BaseException as error:
            walk_error = error
            raise
        finally:
            try:
                self._osascript(_CLOSE_MENU)
            except HostVoiceOverError:
                if walk_error is None:
                    raise

        return entries

    def _quiet_phrase(self) -> str:
        """Return the phrase once two reads MENU_QUIET_SECONDS apart agree, or the newest read."""
        deadline = self._clock() + MENU_PHRASE_TIMEOUT_SECONDS
        phrase = self.last_phrase()
        while self._clock() + MENU_QUIET_SECONDS < deadline:
            self._sleep(MENU_QUIET_SECONDS)
            current = self.last_phrase()
            if current == phrase:
                break
            phrase = current
        return phrase

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

    def _settled_new_phrase(self, previous: str, what: str) -> str:
        """Return the first settled phrase after [previous]; raise `HostVoiceOverSilent` if none."""
        deadline = self._clock() + MENU_PHRASE_TIMEOUT_SECONDS
        while True:
            settled = self._quiet_phrase()
            if settled != previous and settled != "":
                return settled
            if self._clock() >= deadline:
                raise HostVoiceOverSilent(
                    f"VoiceOver never spoke {what} within {MENU_PHRASE_TIMEOUT_SECONDS:g}s"
                    f" (last phrase: {settled or previous!r})"
                )
            self._sleep(POLL_INTERVAL_SECONDS)

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
