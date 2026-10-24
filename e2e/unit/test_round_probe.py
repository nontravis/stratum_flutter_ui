"""Unit tests for the device probe that classes a failed e2e item `env` when its device is lost."""

from __future__ import annotations

import json
from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest

from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.probe import lost_device_reason
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner

Entry = tuple[tuple[str, ...], Completed]

_SERIAL = "emulator-5556"
_UDID = "11111111-2222-3333-4444-555555555555"


def _record(platform: str, device_id: str = _SERIAL) -> BootRecord:
    return BootRecord(target=f"{platform}_t", platform=platform, device_id=device_id, reused=False)


def _done(stdout: str = "", status: int = 0, *, stderr: str = "", timed_out: bool = False) -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr=stderr, timed_out=timed_out)


def _adb_state(state: str) -> list[Entry]:
    return [(("adb", "-s", _SERIAL, "get-state"), _done(state))]


def _simctl_list(state: str | None) -> list[Entry]:
    entry = {"udid": _UDID, "state": state} if state is not None else {}
    listed = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-18-0": [entry]}}
    return [(("xcrun", "simctl", "list", "-j"), _done(json.dumps(listed)))]


@pytest.mark.parametrize(
    ("answer", "expected"),
    [
        ("device\n", None),
        ("offline\n", "adb get-state: offline"),
        ("unknown\n", "adb get-state: unknown"),
        ("error: device not found\n", "adb get-state: error: device not found"),
    ],
)
def test_android_probe_reads_get_state(answer: str, expected: str | None) -> None:
    assert lost_device_reason(FakeRunner(_adb_state(answer)), _record("android")) == expected


@pytest.mark.parametrize("platform", ["macos", "web", "linux"])
def test_host_platforms_are_never_lost(platform: str) -> None:
    """A host platform has no device, so the runner is asked nothing."""
    runner = FakeRunner([])
    assert lost_device_reason(runner, _record(platform, platform)) is None
    assert runner.calls == []


def test_ios_probe_reads_the_booted_state() -> None:
    assert lost_device_reason(FakeRunner(_simctl_list("Booted")), _record("ios", _UDID)) is None


def test_ios_probe_names_a_shutdown_simulator() -> None:
    runner = FakeRunner(_simctl_list("Shutdown"))
    assert lost_device_reason(runner, _record("ios", _UDID)) == "simctl state: Shutdown"


def test_ios_probe_names_an_unlisted_simulator() -> None:
    assert lost_device_reason(FakeRunner(_simctl_list("Booted")), _record("ios", "00000000-0000-0000-0000-000000000000")) \
        == "simctl list: 00000000-0000-0000-0000-000000000000 not listed"


def test_ios_probe_reads_not_lost_when_the_listing_cannot_be_read() -> None:
    """A probe that itself failed never pointed at the device, so the item stays `fail`."""
    for stdout in ("not json", '"a string"', "5"):
        runner = FakeRunner([(("xcrun", "simctl", "list", "-j"), _done(stdout))])
        assert lost_device_reason(runner, _record("ios", _UDID)) is None


def test_android_probe_reads_adb_stderr_when_stdout_is_empty() -> None:
    """Real adb prints `error: device ... not found` on stderr with status 1."""
    answer = _done("", 1, stderr="error: device 'emulator-5556' not found\n")
    runner = FakeRunner([(("adb", "-s", _SERIAL, "get-state"), answer)])
    assert lost_device_reason(runner, _record("android")) == "adb get-state: error: device 'emulator-5556' not found"


@pytest.mark.parametrize(
    "answer",
    [
        _done("", -9, timed_out=True),
        _done("", 127, stderr="adb: No such file or directory\n"),
        _done("", 1),
        _done("", 0),
    ],
    ids=["timed-out", "adb-missing", "no-answer-status-1", "no-answer-status-0"],
)
def test_android_probe_that_itself_failed_reads_not_lost(answer: Completed) -> None:
    """A probe with no readable answer never pointed at the device, so the item stays `fail`."""
    runner = FakeRunner([(("adb", "-s", _SERIAL, "get-state"), answer)])
    assert lost_device_reason(runner, _record("android")) is None


class _BoundRunner(FakeRunner):
    """Records the `timeout_s` each call carries."""

    def __init__(self, script: list[Entry]) -> None:
        super().__init__(script)
        self.timeouts: list[float | None] = []

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        self.timeouts.append(timeout_s)
        return super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)


@pytest.mark.parametrize(
    ("platform", "device", "script"),
    [("android", _SERIAL, _adb_state("device")), ("ios", _UDID, _simctl_list("Booted"))],
)
def test_probe_bounds_every_command(platform: str, device: str, script: list[Entry]) -> None:
    """The probe bounds itself, so a hung adb or simctl cannot hang the report hook."""
    runner = _BoundRunner(script)
    lost_device_reason(runner, _record(platform, device))
    assert len(runner.timeouts) == 1
    assert runner.timeouts[0] is not None and 0 < runner.timeouts[0] <= 30
