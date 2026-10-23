"""TalkBack on the e2e AVD: session, logcat speech, page-source focus (design section 8)."""

from __future__ import annotations

import re
import subprocess
import time
from types import TracebackType

from stratum_e2e.android.tree import labels_with

AVD_NAME = "E2E_TalkBack_API_35"
TALKBACK_SERVICE = (
    "com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService"
)

FIRST_UTTERANCE_TIMEOUT_S = 20
UNBIND_TIMEOUT_S = 10
POLL_INTERVAL_S = 0.5

_SERVICES_SETTING = "enabled_accessibility_services"
_ENABLED_SETTING = "accessibility_enabled"
_UNSET = "null"
_UTTERANCE = re.compile(r'Speaking fragment text="([^"]*)"')


class TalkBackSilent(RuntimeError):
    """TalkBack spoke nothing within the first-utterance timeout."""


class TalkBackStuck(RuntimeError):
    """TalkBack stayed bound after the session turned it off."""


def avd_name(serial: str) -> str:
    """Return the AVD name of emulator [serial], or an empty string when it has none."""
    lines = _adb(serial, "emu", "avd", "name").splitlines()
    return lines[0].strip() if lines else ""


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
        """Drop everything logged so far; `since_mark` reads only what follows."""
        _adb(self._serial, "logcat", "-c")

    def since_mark(self) -> list[str]:
        """Return the utterances spoken since the last `mark`, in order."""
        return utterances(_adb(self._serial, "logcat", "-d"))


class TalkBackSession:
    """Restarts TalkBack for the block and restores the accessibility settings on exit.

    TalkBack speaks a first utterance only on a fresh start, so entry turns it off, waits
    until it unbinds, then turns it on. `__enter__` returns a TalkBackLog marked after
    that first utterance. Raises ValueError unless [serial] is the AVD named AVD_NAME,
    TalkBackStuck when TalkBack stays bound for 10 s, and TalkBackSilent when it speaks
    nothing in 20 s; the last two restore the settings first.
    """

    def __init__(self, serial: str) -> None:
        self._serial = serial
        self._saved: dict[str, str] = {}

    def __enter__(self) -> TalkBackLog:
        name = avd_name(self._serial)
        if name != AVD_NAME:
            raise ValueError(
                f"refusing {self._serial}: AVD is {name!r}, TalkBack runs only on {AVD_NAME!r}"
            )
        self._saved = {
            setting: _get_secure(self._serial, setting)
            for setting in (_SERVICES_SETTING, _ENABLED_SETTING)
        }
        try:
            return self._enable()
        except BaseException:
            self._restore()
            raise

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self._restore()

    def _enable(self) -> TalkBackLog:
        self._stop()
        log = TalkBackLog(self._serial)
        log.mark()
        _put_secure(self._serial, _SERVICES_SETTING, TALKBACK_SERVICE)
        _put_secure(self._serial, _ENABLED_SETTING, "1")
        self._wait_first_utterance()
        log.mark()
        return log

    def _stop(self) -> None:
        _put_secure(self._serial, _ENABLED_SETTING, "0")
        _adb(self._serial, "shell", "settings", "delete", "secure", _SERVICES_SETTING)
        deadline = time.monotonic() + UNBIND_TIMEOUT_S
        while _talkback_bound(self._serial):
            if time.monotonic() >= deadline:
                raise TalkBackStuck(
                    f"TalkBack still bound on {self._serial} after {UNBIND_TIMEOUT_S} s"
                )
            time.sleep(POLL_INTERVAL_S)

    def _wait_first_utterance(self) -> None:
        deadline = time.monotonic() + FIRST_UTTERANCE_TIMEOUT_S
        while not utterances(_adb(self._serial, "logcat", "-d")):
            if time.monotonic() >= deadline:
                raise TalkBackSilent(
                    f"no TalkBack utterance in {FIRST_UTTERANCE_TIMEOUT_S} s: "
                    "Diagnosis mode off or TalkBack not running"
                )
            time.sleep(POLL_INTERVAL_S)

    def _restore(self) -> None:
        for setting, value in self._saved.items():
            if value == _UNSET:
                _adb(self._serial, "shell", "settings", "delete", "secure", setting)
            else:
                _put_secure(self._serial, setting, value)


def _talkback_bound(serial: str) -> bool:
    return "label=TalkBack" in _adb(serial, "shell", "dumpsys", "accessibility")


def _get_secure(serial: str, setting: str) -> str:
    return _adb(serial, "shell", "settings", "get", "secure", setting).strip()


def _put_secure(serial: str, setting: str, value: str) -> None:
    _adb(serial, "shell", "settings", "put", "secure", setting, value)


def _adb(serial: str, *args: str) -> str:
    result = subprocess.run(
        ["adb", "-s", serial, *args],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout
