"""Unit tests for what the round captures from a device beside an item's log (design section 10)."""

from __future__ import annotations

import subprocess
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime, timedelta, timezone
from pathlib import Path
from typing import cast

import pytest

from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.capture import device_log_argv, save_device_log, save_screenshot, screenshot_argv
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner

SINCE = datetime(2026, 10, 24, 1, 2, 3, 456000, tzinfo=UTC)
EPOCH = "1792803723"


def _record(platform: str, device_id: str = "emulator-5556") -> BootRecord:
    return BootRecord(target=f"{platform}_target", platform=platform, device_id=device_id, reused=False)


def _done(status: int = 0, stdout: str = "") -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr="", timed_out=False)


class _ImageProcess:
    """A spawned screenshot command: writes its PNG bytes to the log path, then exits with `status`."""

    def __init__(self, log: Path, status: int, hangs: bool) -> None:
        log.write_bytes(b"\x89PNG\r\n\x1a\n")
        self._status = status
        self._hangs = hangs
        self.killed = False

    def wait(self, timeout: float | None = None) -> int:
        if self._hangs and not self.killed:
            raise subprocess.TimeoutExpired("adb", timeout or 0.0)
        return self._status

    def kill(self) -> None:
        self.killed = True


class _SpawnRunner(FakeRunner):
    """A FakeRunner whose `spawn` hands back an `_ImageProcess` and remembers the log path it wrote to."""

    def __init__(self, status: int = 0, hangs: bool = False, fails: bool = False) -> None:
        super().__init__([])
        self._status = status
        self._hangs = hangs
        self._fails = fails
        self.spawned: list[tuple[tuple[str, ...], Path]] = []
        self.process: _ImageProcess | None = None

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]:
        if self._fails:
            raise FileNotFoundError(2, "No such file or directory", "adb")
        self.spawned.append((tuple(argv), log))
        self.process = _ImageProcess(log, self._status, self._hangs)
        return cast("subprocess.Popen[bytes]", self.process)


def test_android_device_log_reads_logcat_since_the_epoch_second() -> None:
    assert device_log_argv(_record("android"), SINCE) == [
        "adb", "-s", "emulator-5556", "logcat", "-d", "-v", "threadtime", "-T", f"{EPOCH}.456",
    ]


def test_ios_device_log_reads_the_simulator_log_since_the_epoch_second() -> None:
    assert device_log_argv(_record("ios", "UDID-1"), SINCE) == [
        "xcrun", "simctl", "spawn", "UDID-1", "log", "show", "--style", "compact", "--start", f"@{EPOCH}",
    ]


def test_device_log_start_is_the_same_instant_in_any_time_zone() -> None:
    bangkok = SINCE.astimezone(timezone(timedelta(hours=7)))
    assert device_log_argv(_record("android"), bangkok) == device_log_argv(_record("android"), SINCE)


@pytest.mark.parametrize("platform", ["macos", "web", "linux"])
def test_host_platforms_have_no_device_log(platform: str) -> None:
    assert device_log_argv(_record(platform, platform), SINCE) is None


def test_device_log_refuses_a_naive_start() -> None:
    with pytest.raises(ValueError, match="timezone-aware"):
        device_log_argv(_record("android"), datetime(2026, 10, 24, 1, 2, 3))


def test_screenshot_argv_per_platform(tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    assert screenshot_argv(_record("android"), shot) == ["adb", "-s", "emulator-5556", "exec-out", "screencap", "-p"]
    ios = ["xcrun", "simctl", "io", "UDID-1", "screenshot", str(shot)]
    assert screenshot_argv(_record("ios", "UDID-1"), shot) == ios
    assert screenshot_argv(_record("macos", "mac"), shot) == ["screencapture", "-x", str(shot)]


@pytest.mark.parametrize("platform", ["web", "linux"])
def test_web_and_linux_take_no_screenshot(platform: str, tmp_path: Path) -> None:
    assert screenshot_argv(_record(platform, platform), tmp_path / "screenshot.png") is None


def test_save_device_log_writes_the_command_output_to_the_log(tmp_path: Path) -> None:
    runner = FakeRunner([(("adb", "-s", "emulator-5556", "logcat"), _done(stdout="I/flutter: hi\n"))])
    log = tmp_path / "device.log"
    assert save_device_log(runner, _record("android"), SINCE, log) is True
    assert runner.calls == [tuple(device_log_argv(_record("android"), SINCE) or ())]


def test_save_device_log_reports_a_failed_command(tmp_path: Path) -> None:
    runner = FakeRunner([(("xcrun",), _done(status=1))])
    assert save_device_log(runner, _record("ios", "UDID-1"), SINCE, tmp_path / "device.log") is False


def test_save_device_log_runs_nothing_on_a_host_platform(tmp_path: Path) -> None:
    runner = FakeRunner([])
    assert save_device_log(runner, _record("web", "chrome"), SINCE, tmp_path / "device.log") is False
    assert runner.calls == []


def test_android_screenshot_streams_the_png_bytes_into_the_file(tmp_path: Path) -> None:
    runner = _SpawnRunner()
    shot = tmp_path / "screenshot.png"
    assert save_screenshot(runner, _record("android"), shot) is True
    assert runner.spawned == [(("adb", "-s", "emulator-5556", "exec-out", "screencap", "-p"), shot)]
    assert shot.read_bytes().startswith(b"\x89PNG")


def test_android_screenshot_that_fails_leaves_no_file(tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    assert save_screenshot(_SpawnRunner(status=1), _record("android"), shot) is False
    assert not shot.exists()


def test_android_screenshot_that_hangs_is_killed(tmp_path: Path) -> None:
    runner = _SpawnRunner(hangs=True)
    shot = tmp_path / "screenshot.png"
    assert save_screenshot(runner, _record("android"), shot) is False
    assert runner.process is not None and runner.process.killed
    assert not shot.exists()


def test_android_screenshot_without_adb_is_reported(tmp_path: Path) -> None:
    assert save_screenshot(_SpawnRunner(fails=True), _record("android"), tmp_path / "screenshot.png") is False


def test_ios_screenshot_runs_simctl_io(tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    runner = FakeRunner([(("xcrun", "simctl", "io"), _done())])
    assert save_screenshot(runner, _record("ios", "UDID-1"), shot) is True
    assert runner.calls == [("xcrun", "simctl", "io", "UDID-1", "screenshot", str(shot))]


def test_screenshot_runs_nothing_on_web(tmp_path: Path) -> None:
    runner = FakeRunner([])
    assert save_screenshot(runner, _record("web", "chrome"), tmp_path / "screenshot.png") is False
    assert runner.calls == []
