"""TalkBack on the e2e AVD: session, logcat speech, page-source focus (design section 8)."""

from __future__ import annotations

import re
import time
from types import TracebackType

from stratum_e2e.android.adb import (
    TALKBACK_AVD,
    adb,
    avd_name,
    delete_secure,
    get_secure,
    put_secure,
    restore_secure,
)
from stratum_e2e.android.tree import labels_with

__all__ = ["TALKBACK_AVD", "avd_name"]
TALKBACK_SERVICE = (
    "com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService"
)

FIRST_UTTERANCE_TIMEOUT_S = 20
UNBIND_TIMEOUT_S = 10
POLL_INTERVAL_S = 0.5
# A window title can take 3.4 s to speak (measured on the e2e AVD) with reads queued behind it.
IDLE_QUIET_S = 1.2
IDLE_TIMEOUT_S = 20
IDLE_POLL_INTERVAL_S = 0.25

_SERVICES_SETTING = "enabled_accessibility_services"
_ENABLED_SETTING = "accessibility_enabled"
_UTTERANCE = re.compile(r'Speaking fragment text="([^"]*)"')
_STARTED = re.compile(r'Speaking fragment text="[^"]*", utteranceId=(\S+?),')
_FINISHED = re.compile(r'Received callback for "([^"]+)"')


class TalkBackSilent(RuntimeError):
    """TalkBack spoke nothing within the first-utterance timeout."""


class TalkBackStuck(RuntimeError):
    """TalkBack stayed bound after the session turned it off."""


class TalkBackNotIdle(RuntimeError):
    """TalkBack still held a started utterance, or kept starting new ones, after the idle timeout."""


def utterances(logcat: str) -> list[str]:
    """Return the texts TalkBack spoke in [logcat], in order (Diagnosis mode lines)."""
    return _UTTERANCE.findall(logcat)


def a11y_focused(page_source: str) -> list[str]:
    """Return the labels of nodes TalkBack holds accessibility focus on in [page_source]."""
    return labels_with(page_source, "a11y-focused")


class TalkBackLog:
    """TalkBack speech on device [serial] since the last `mark`."""

    def __init__(self, serial: str) -> None:
        self._serial = serial

    def mark(self) -> None:
        """Wait until TalkBack is idle, then drop everything logged so far.

        `since_mark` reads only what follows. TalkBack speaks first in, first out and logs an
        utterance only when it starts to play, so a mark taken while earlier reads are queued
        lets one of them cross it. Raises TalkBackNotIdle as `wait_idle` does.
        """
        self.wait_idle()
        _clear_logcat(self._serial)

    def wait_idle(
        self, quiet_s: float = IDLE_QUIET_S, timeout_s: float = IDLE_TIMEOUT_S
    ) -> None:
        """Return once every started utterance has its TTS callback and none started for [quiet_s].

        Polls the log, so [quiet_s] is measured from the poll that first saw the newest start.
        Raises TalkBackNotIdle naming the unfinished utterances after [timeout_s].
        """
        deadline = time.monotonic() + timeout_s
        started_count = -1
        quiet_since = time.monotonic()
        while True:
            log = adb(self._serial, "logcat", "-d")
            started = _STARTED.findall(log)
            pending = set(started) - set(_FINISHED.findall(log))
            now = time.monotonic()
            if len(started) != started_count:
                started_count, quiet_since = len(started), now
            elif not pending and now - quiet_since >= quiet_s:
                return
            if now >= deadline:
                raise TalkBackNotIdle(
                    f"TalkBack not idle after {timeout_s} s on {self._serial}: "
                    f"unfinished {sorted(pending) or 'none'}, {len(started)} started"
                )
            time.sleep(IDLE_POLL_INTERVAL_S)

    def since_mark(self) -> list[str]:
        """Return the utterances spoken since the last `mark`, in order."""
        return utterances(adb(self._serial, "logcat", "-d"))


class TalkBackSession:
    """Restarts TalkBack for the block and restores the accessibility settings on exit.

    TalkBack speaks a first utterance only on a fresh start, so entry turns it off, waits
    until it unbinds, then turns it on. `__enter__` returns a TalkBackLog marked after
    that first utterance. Raises ValueError unless [serial] is the AVD named TALKBACK_AVD,
    TalkBackStuck when TalkBack stays bound for 10 s, and TalkBackSilent when it speaks
    nothing in 20 s; the last two restore the settings first.
    """

    def __init__(self, serial: str) -> None:
        self._serial = serial
        self._saved: dict[str, str] = {}

    def __enter__(self) -> TalkBackLog:
        name = avd_name(self._serial)
        if name != TALKBACK_AVD:
            raise ValueError(
                f"refusing {self._serial}: AVD is {name!r}, TalkBack runs only on {TALKBACK_AVD!r}"
            )
        self._saved = _read_accessibility_settings(self._serial)
        try:
            return self._enable()
        except BaseException:
            _restore_secure(self._serial, self._saved)
            raise

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        _restore_secure(self._serial, self._saved)

    def _enable(self) -> TalkBackLog:
        _stop_talkback(self._serial)
        log = TalkBackLog(self._serial)
        _clear_logcat(self._serial)  # TalkBack is off here: nothing to wait for
        put_secure(self._serial, _SERVICES_SETTING, TALKBACK_SERVICE)
        put_secure(self._serial, _ENABLED_SETTING, "1")
        self._wait_first_utterance()
        log.mark()
        return log

    def _wait_first_utterance(self) -> None:
        deadline = time.monotonic() + FIRST_UTTERANCE_TIMEOUT_S
        while not utterances(adb(self._serial, "logcat", "-d")):
            if time.monotonic() >= deadline:
                raise TalkBackSilent(
                    f"no TalkBack utterance in {FIRST_UTTERANCE_TIMEOUT_S} s: "
                    "Diagnosis mode off or TalkBack not running"
                )
            time.sleep(POLL_INTERVAL_S)


class TalkBackOff:
    """Turns TalkBack off for the block, so one console tap focuses a field.

    The e2e AVD runs touch exploration at baseline, so a tap only moves accessibility
    focus while TalkBack is on; with it off the tap reaches the field (t49-e04-probe-c2
    line 19). Writes the two accessibility settings `TalkBackSession` touches, waits
    until TalkBack unbinds, and restores both on success and on an exception; raises
    ValueError unless [serial] is the AVD named TALKBACK_AVD, and TalkBackStuck when
    TalkBack stays bound for 10 s (after restoring).
    """

    def __init__(self, serial: str) -> None:
        self._serial = serial
        self._saved: dict[str, str] = {}

    def __enter__(self) -> None:
        name = avd_name(self._serial)
        if name != TALKBACK_AVD:
            raise ValueError(
                f"refusing {self._serial}: AVD is {name!r}, TalkBack runs only on {TALKBACK_AVD!r}"
            )
        self._saved = _read_accessibility_settings(self._serial)
        try:
            _stop_talkback(self._serial)
        except BaseException:
            _restore_secure(self._serial, self._saved)
            raise

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        _restore_secure(self._serial, self._saved)


def _read_accessibility_settings(serial: str) -> dict[str, str]:
    return {
        setting: get_secure(serial, setting)
        for setting in (_SERVICES_SETTING, _ENABLED_SETTING)
    }


def _restore_secure(serial: str, saved: dict[str, str]) -> None:
    for setting, value in saved.items():
        restore_secure(serial, setting, value)


def _stop_talkback(serial: str) -> None:
    put_secure(serial, _ENABLED_SETTING, "0")
    delete_secure(serial, _SERVICES_SETTING)
    deadline = time.monotonic() + UNBIND_TIMEOUT_S
    while _talkback_bound(serial):
        if time.monotonic() >= deadline:
            raise TalkBackStuck(f"TalkBack still bound on {serial} after {UNBIND_TIMEOUT_S} s")
        time.sleep(POLL_INTERVAL_S)


def _talkback_bound(serial: str) -> bool:
    return "label=TalkBack" in adb(serial, "shell", "dumpsys", "accessibility")


def _clear_logcat(serial: str) -> None:
    adb(serial, "logcat", "-c")
