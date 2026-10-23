"""What the round keeps from a device beside an item's log: the device log since the item started, and a screenshot.

Design section 10: an item's logs hold its output, the device log (logcat on Android, the simulator log on iOS), and a
screenshot on failure. A capture that fails never changes the item's class, so the savers report whether they got
anything and never raise for a failed command.
"""

from __future__ import annotations

import subprocess
from datetime import datetime
from pathlib import Path
from typing import Final

from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.runner import Runner

_LOG_TIMEOUT_S: Final = 60.0
_SCREENSHOT_TIMEOUT_S: Final = 30.0


def device_log_argv(record: BootRecord, since: datetime) -> list[str] | None:
    """The command that prints the device log of `record` from `since` on; `None` on a host platform.

    Both commands take the start as Unix epoch seconds, so neither the device's nor the host's time zone shifts it.
    """
    if since.tzinfo is None:
        raise ValueError("a device log starts at a timezone-aware datetime")
    if record.platform == "android":
        return ["adb", "-s", record.device_id, "logcat", "-d", "-v", "threadtime", "-T", f"{since.timestamp():.3f}"]
    if record.platform == "ios":
        start = f"@{int(since.timestamp())}"
        return ["xcrun", "simctl", "spawn", record.device_id, "log", "show", "--style", "compact", "--start", start]
    return None


def screenshot_argv(record: BootRecord, path: Path) -> list[str] | None:
    """The command that takes a screenshot of `record`'s screen into `path`; `None` on web and linux.

    The Android command prints the PNG to stdout instead of writing `path`.
    """
    if record.platform == "android":
        return ["adb", "-s", record.device_id, "exec-out", "screencap", "-p"]
    if record.platform == "ios":
        return ["xcrun", "simctl", "io", record.device_id, "screenshot", str(path)]
    if record.platform == "macos":
        return ["screencapture", "-x", str(path)]
    return None


def save_device_log(runner: Runner, record: BootRecord, since: datetime, path: Path) -> bool:
    """Write the device log of `record` since `since` to `path`; whether the command ran and passed."""
    argv = device_log_argv(record, since)
    if argv is None:
        return False
    return runner.run(argv, timeout_s=_LOG_TIMEOUT_S, log=path).status == 0


def save_screenshot(runner: Runner, record: BootRecord, path: Path) -> bool:
    """Take a screenshot of `record`'s screen into `path`; whether one was taken.

    A failed Android capture leaves no file behind.
    """
    argv = screenshot_argv(record, path)
    if argv is None:
        return False
    if record.platform != "android":
        return runner.run(argv, timeout_s=_SCREENSHOT_TIMEOUT_S).status == 0
    # `run` decodes stdout as text; `spawn` hands the PNG bytes to the file untouched.
    try:
        process = runner.spawn(argv, log=path)
    except OSError:
        return False
    try:
        taken = process.wait(timeout=_SCREENSHOT_TIMEOUT_S) == 0
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        taken = False
    if not taken:
        path.unlink(missing_ok=True)
    return taken
