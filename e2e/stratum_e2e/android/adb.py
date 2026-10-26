"""The one adb call and secure-setting accessors the Android e2e harness shares."""

from __future__ import annotations

import shlex
import subprocess

AVD_NAME = "E2E_TalkBack_API_35"
UNSET = "null"


def adb(serial: str, *args: str) -> str:
    """Run `adb -s [serial] [args]` and return its stdout; raise on a non-zero exit."""
    result = subprocess.run(
        ["adb", "-s", serial, *args],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout


def avd_name(serial: str) -> str:
    """Return the AVD name of emulator [serial], or an empty string when it has none."""
    lines = adb(serial, "emu", "avd", "name").splitlines()
    return lines[0].strip() if lines else ""


def get_secure(serial: str, key: str) -> str:
    """Return the value of secure setting [key] on [serial]; `null` (UNSET) when it is unset."""
    return adb(serial, "shell", "settings", "get", "secure", key).strip()


def put_secure(serial: str, key: str, value: str) -> None:
    """Set secure setting [key] to [value], which may be empty."""
    # `adb shell` joins its arguments into one remote shell line, so quote the
    # value: an empty argument otherwise vanishes and `settings put` gets no value.
    adb(serial, "shell", "settings", "put", "secure", key, shlex.quote(value))


def delete_secure(serial: str, key: str) -> None:
    """Delete secure setting [key], returning it to unset."""
    adb(serial, "shell", "settings", "delete", "secure", key)


def restore_secure(serial: str, key: str, saved: str) -> None:
    """Put [key] back to [saved] as `get_secure` read it: delete when it was unset."""
    if saved == UNSET:
        delete_secure(serial, key)
    else:
        put_secure(serial, key, saved)
