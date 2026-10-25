"""Unit tests for what the round captures from a device beside an item's log (design section 10)."""

from __future__ import annotations

import subprocess
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime, timedelta, timezone
from pathlib import Path
from typing import cast

import pytest

from stratum_e2e.round.boot import BootLog, BootRecord
from stratum_e2e.round.capture import (
    device_log_argv,
    keep_boot_log,
    save_device_log,
    save_screenshot,
    screenshot_argv,
)
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner

SINCE = datetime(2026, 10, 24, 1, 2, 3, 456000, tzinfo=UTC)
EPOCH = "1792803723"
PNG = b"\x89PNG\r\n\x1a\nnew"
EARLIER = b"\x89PNG\r\n\x1a\nearlier"


def _record(platform: str, device_id: str = "emulator-5556") -> BootRecord:
    return BootRecord(target=f"{platform}_target", platform=platform, device_id=device_id, reused=False)


def _done(status: int = 0, stdout: str = "") -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr="", timed_out=False)


class _ImageProcess:
    """A spawned screenshot command: appends its PNG bytes to the log path, as `SubprocessRunner.spawn` opens it, then
    exits with `status`."""

    def __init__(self, log: Path, status: int, hangs: bool) -> None:
        with log.open("ab") as sink:
            sink.write(PNG if status == 0 else b"error: device offline\n")
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
        "adb", "-s", "emulator-5556", "logcat", "-d", "-b", "main,system,crash,events", "-v", "threadtime",
        "-T", f"{EPOCH}.456",
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
    assert [argv for argv, _ in runner.spawned] == [("adb", "-s", "emulator-5556", "exec-out", "screencap", "-p")]
    assert shot.read_bytes() == PNG
    assert sorted(path.name for path in tmp_path.iterdir()) == ["screenshot.png"]


def test_android_screenshot_replaces_an_earlier_one_instead_of_appending(tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    shot.write_bytes(EARLIER)
    assert save_screenshot(_SpawnRunner(), _record("android"), shot) is True
    assert shot.read_bytes() == PNG


def test_android_screenshot_that_fails_leaves_no_file(tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    assert save_screenshot(_SpawnRunner(status=1), _record("android"), shot) is False
    assert list(tmp_path.iterdir()) == []


def test_failed_screenshot_keeps_the_earlier_one(tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    shot.write_bytes(EARLIER)
    assert save_screenshot(_SpawnRunner(status=1), _record("android"), shot) is False
    assert shot.read_bytes() == EARLIER
    assert sorted(path.name for path in tmp_path.iterdir()) == ["screenshot.png"]


def test_android_screenshot_that_hangs_is_killed(tmp_path: Path) -> None:
    runner = _SpawnRunner(hangs=True)
    shot = tmp_path / "screenshot.png"
    assert save_screenshot(runner, _record("android"), shot) is False
    assert runner.process is not None and runner.process.killed
    assert list(tmp_path.iterdir()) == []


def test_android_screenshot_without_adb_is_reported(tmp_path: Path) -> None:
    assert save_screenshot(_SpawnRunner(fails=True), _record("android"), tmp_path / "screenshot.png") is False


class _FileRunner(FakeRunner):
    """A FakeRunner whose command writes the PNG to the path it is given last, or fails and writes nothing."""

    def __init__(self, status: int = 0) -> None:
        super().__init__([])
        self._status = status

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        self.calls.append(tuple(argv))
        if self._status == 0:
            Path(argv[-1]).write_bytes(PNG)
        return _done(status=self._status)


@pytest.mark.parametrize(("platform", "prefix"), [("ios", ("xcrun", "simctl", "io", "UDID-1", "screenshot")),
                                                  ("macos", ("screencapture", "-x"))])
def test_ios_and_mac_screenshots_land_at_the_path(platform: str, prefix: tuple[str, ...], tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    shot.write_bytes(EARLIER)
    runner = _FileRunner()
    assert save_screenshot(runner, _record(platform, "UDID-1"), shot) is True
    assert [call[: len(prefix)] for call in runner.calls] == [prefix]
    assert shot.read_bytes() == PNG
    assert sorted(path.name for path in tmp_path.iterdir()) == ["screenshot.png"]


def test_failed_ios_screenshot_keeps_the_earlier_one(tmp_path: Path) -> None:
    shot = tmp_path / "screenshot.png"
    shot.write_bytes(EARLIER)
    assert save_screenshot(_FileRunner(status=1), _record("ios", "UDID-1"), shot) is False
    assert shot.read_bytes() == EARLIER


def test_screenshot_runs_nothing_on_web(tmp_path: Path) -> None:
    runner = FakeRunner([])
    assert save_screenshot(runner, _record("web", "chrome"), tmp_path / "screenshot.png") is False
    assert runner.calls == []


class _LogRunner(FakeRunner):
    """A FakeRunner whose command writes `text` to its `log`, or fails and writes nothing."""

    def __init__(self, text: str | None) -> None:
        super().__init__([])
        self._text = text

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        self.calls.append(tuple(argv))
        if self._text is not None and log is not None:
            log.write_text(self._text)
        return _done(status=0 if self._text is not None else 1)


def test_boot_logs_of_two_attempts_are_appended_under_a_header_each(tmp_path: Path) -> None:
    boot_log = BootLog(tmp_path / "device.log", SINCE)
    keep_boot_log(_LogRunner("first\n"), _record("android", "emulator-5556"), boot_log)
    keep_boot_log(_LogRunner("second\n"), _record("android", "emulator-5558"), boot_log)

    header = f"--- device log of {{}} since {SINCE.isoformat()} ---\n"
    assert (tmp_path / "device.log").read_text() == (
        header.format("emulator-5556") + "first\n" + header.format("emulator-5558") + "second\n"
    )
    assert sorted(path.name for path in tmp_path.iterdir()) == ["device.log"]


def test_a_failed_boot_log_capture_leaves_the_file_as_it_was(tmp_path: Path) -> None:
    path = tmp_path / "device.log"
    path.write_text("kept\n")

    keep_boot_log(_LogRunner(None), _record("android"), BootLog(path, SINCE))

    assert path.read_text() == "kept\n"
    assert sorted(item.name for item in tmp_path.iterdir()) == ["device.log"]


def test_no_boot_log_request_runs_no_command(tmp_path: Path) -> None:
    runner = _LogRunner("x")

    keep_boot_log(runner, _record("android"), None)

    assert runner.calls == []
