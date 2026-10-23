"""Unit tests for the Android booter: boot, reuse, ready, and kill by serial, with a scripted adb and a fake clock."""

from __future__ import annotations

import subprocess
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import cast

import pytest

from stratum_e2e.round.android_boot import AndroidBooter
from stratum_e2e.round.android_host import CONSOLE_PORTS, adb_path, emulator_path, missing_avd_message, reserve_port
from stratum_e2e.round.android_traps import settings_apply_argv, settings_restore_argv, settle_reasons
from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.catalog import LaneConfig, Target
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeProcess, FakeRunner

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "round" / "android"
SDK = Path("/opt/android-sdk")
ADB = adb_path(SDK)
EMULATOR = emulator_path(SDK)
AVD = "Pixel_8_API_37"
SERIAL = "emulator-5556"
OTHER = "emulator-5554"
SYSTEMUI = "com.android.systemui"
RTT = ("shell", "ping", "-c", "1", "8.8.8.8")
TARGET = Target(
    name="pixel_8",
    platform="android",
    alone=True,
    avd=AVD,
    build_mode="profile",
    emulator_args=("-gpu", "host", "-memory", "4096"),
)
LANE = LaneConfig(
    run_timeout_minutes=20,
    boot_settle_timeout_seconds=420,
    allow_level2=True,
    heavy_processes=(),
    lane_wait_minutes=30,
    boot_timeout_minutes=10,
)

FOCUS_NORMAL = (FIXTURES / "focus_normal.txt").read_text()
FOCUS_ANR = (FIXTURES / "anr_title_shape.txt").read_text()
FOCUS_ANR_NO_PACKAGE = (FIXTURES / "anr_no_package.txt").read_text()
IME_BOUND = (FIXTURES / "ime_api36_bound.txt").read_text()
IME_UNBOUND = (FIXTURES / "ime_api36_null.txt").read_text()

Entry = tuple[tuple[str, ...], Completed]


class FakeClock:
    """A monotonic clock that only moves when the code under test sleeps."""

    def __init__(self) -> None:
        self.now = 0.0
        self.sleeps: list[float] = []

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.now += seconds


class EmulatorRunner(FakeRunner):
    """A FakeRunner whose spawned emulator exits on `emu kill`; with `hangs`, it ignores `emu kill` and runs on."""

    def __init__(self, script: Sequence[Entry], *, hangs: bool = False) -> None:
        super().__init__(script)
        self.processes: list[FakeProcess] = []
        self._hangs = hangs

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]:
        process = super().spawn(argv, log=log, cwd=cwd, env=env)
        self.processes.append(cast("FakeProcess", process))
        return process

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        done = super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)
        if tuple(argv[-2:]) == ("emu", "kill") and not self._hangs:
            for process in self.processes:
                process.returncode = 0
        return done


class SpawnFailsRunner(FakeRunner):
    """A FakeRunner whose emulator binary does not exist."""

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]:
        self.calls.append(tuple(argv))
        raise FileNotFoundError(2, "No such file or directory", argv[0])


def _done(stdout: str = "", status: int = 0) -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr="", timed_out=False)


def _on(serial: str, *args: str) -> tuple[str, ...]:
    return (ADB, "-s", serial, *args)


def _devices_text(*serials: str) -> str:
    return "List of devices attached\n" + "".join(f"{serial}\tdevice\n" for serial in serials) + "\n"


def _listing(*running: tuple[str, str]) -> list[Entry]:
    """`adb devices` listing each (serial, avd) as a device, then each serial's `emu avd name` answer."""
    names = [(_on(serial, "emu", "avd", "name"), _done(f"{avd}\r\nOK\r\n")) for serial, avd in running]
    return [((ADB, "devices"), _done(_devices_text(*(serial for serial, _ in running)))), *names]


def _state(state: str) -> list[Entry]:
    return [(_on(SERIAL, "get-state"), _done(f"{state}\n"))]


def _ready() -> list[Entry]:
    return [
        *_state("device"),
        (_on(SERIAL, "shell", "pm", "path", "android"), _done("package:/system/framework/a.apk\n")),
    ]


def _rtt(ms: str) -> list[Entry]:
    return [(_on(SERIAL, *RTT), _done(f"64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time={ms} ms\n"))]


def _settle(load: str = "0.50", focus: str = FOCUS_NORMAL, ime: str = IME_BOUND) -> list[Entry]:
    uptime = f" 14:10:01 up 1 day,  1:23,  0 users,  load average: {load}, 0.40, 0.30\n"
    return [
        (_on(SERIAL, "shell", "uptime"), _done(uptime)),
        (_on(SERIAL, "shell", "dumpsys", "window"), _done(focus)),
        (_on(SERIAL, "shell", "dumpsys", "input_method"), _done(ime)),
    ]


def _focus(focus: str) -> list[Entry]:
    return [(_on(SERIAL, "shell", "dumpsys", "window"), _done(focus))]


def _force_stop(package: str) -> tuple[str, ...]:
    return _on(SERIAL, "shell", "-n", "am", "force-stop", package)


def _puts() -> list[Entry]:
    return [(tuple(argv), _done()) for argv in settings_apply_argv(ADB, SERIAL)]


def _teardown(*, restore: bool) -> list[Entry]:
    deletes = [(tuple(argv), _done()) for argv in settings_restore_argv(ADB, SERIAL)] if restore else []
    return [
        *deletes,
        (_on(SERIAL, "emu", "kill"), _done("OK: killing emulator, bye bye\r\n")),
        ((ADB, "devices"), _done(_devices_text(OTHER))),
    ]


def _cold_boot() -> list[Entry]:
    return [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_rtt("12.3"),
        *_settle(),
        *_focus(FOCUS_NORMAL),
        *_puts(),
    ]


@pytest.fixture
def avd_home(tmp_path: Path) -> Path:
    home = tmp_path / "avd"
    home.mkdir()
    (home / f"{AVD}.ini").write_text(f"avd.ini.encoding=UTF-8\npath={home / AVD}.avd\ntarget=android-37\n")
    return home


@pytest.fixture
def clock() -> FakeClock:
    return FakeClock()


def _booter(runner: FakeRunner, avd_home: Path, clock: FakeClock, lane: LaneConfig = LANE) -> AndroidBooter:
    return AndroidBooter(
        runner, SDK, lane, avd_home, avd_home.parent / "ports", sleep=clock.sleep, monotonic=clock.monotonic
    )


def _port_is_free(avd_home: Path, port: int) -> bool:
    """Whether a fresh reservation, skipping every lower console port, gets `port`."""
    _, low, _, step = CONSOLE_PORTS
    reservation = reserve_port(*CONSOLE_PORTS, set(range(low, port, step)), avd_home.parent / "ports")
    reservation.release()
    return reservation.port == port


def _boot_fails(booter: AndroidBooter, tmp_path: Path) -> RoundEnvError:
    with pytest.raises(RoundEnvError) as caught:
        booter.boot(TARGET, tmp_path / "emulator.log")
    return caught.value


def _has(calls: list[tuple[str, ...]], word: str) -> bool:
    return any(word in call for call in calls)


def test_cold_boot_argv_and_record(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner(_cold_boot())
    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    spawn = (EMULATOR, "-avd", AVD, "-port", "5556", "-no-snapshot-load", "-gpu", "host", "-memory", "4096")
    assert [call for call in runner.calls if call[0] == EMULATOR] == [spawn]
    assert runner.calls.index(spawn) < runner.calls.index(_on(SERIAL, "get-state"))
    assert (record.target, record.platform, record.device_id) == ("pixel_8", "android", SERIAL)
    assert record.reused is False
    assert record.pid == runner.processes[0].pid
    assert record.port is not None
    assert record.port.port == 5556
    assert record.settings_applied is True
    record.port.release()


def test_running_avd_is_reused_after_rtt_and_gets_no_settings(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_listing((OTHER, "Other_AVD"), (SERIAL, AVD)), *_rtt("12.3")])
    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    assert record.reused is True
    assert record.device_id == SERIAL
    assert (record.pid, record.port, record.settings_applied) == (None, None, False)
    assert runner.calls[-1] == _on(SERIAL, *RTT)
    assert not _has(runner.calls, "settings")
    assert not _has(runner.calls, EMULATOR)


def test_is_running_is_true_only_for_a_running_avd(avd_home: Path, clock: FakeClock) -> None:
    runner = FakeRunner(
        [
            *_listing((OTHER, "Other_AVD"), (SERIAL, AVD)),
            *_listing((OTHER, "Other_AVD")),
            *_listing(),
        ]
    )
    booter = _booter(runner, avd_home, clock)

    assert booter.is_running(TARGET) is True
    assert booter.is_running(TARGET) is False
    assert booter.is_running(TARGET) is False


def test_running_serial_names_the_serial_of_the_avd(avd_home: Path, clock: FakeClock) -> None:
    runner = FakeRunner([*_listing((OTHER, "Other_AVD"), (SERIAL, AVD))])
    assert _booter(runner, avd_home, clock).running_serial(AVD) == SERIAL


def test_reused_record_shutdown_touches_nothing(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_listing((SERIAL, AVD)), *_rtt("12.3")])
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")
    booted_calls = len(runner.calls)

    booter.shutdown(record)

    assert runner.calls[booted_calls:] == []


def test_shutdown_ends_nothing_this_booter_did_not_boot(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_cold_boot(), *_teardown(restore=True)])
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")
    booted_calls = len(runner.calls)

    booter.shutdown(BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=False, pid=4242))
    booter.shutdown(BootRecord(target="pixel_8", platform="android", device_id=OTHER, reused=False, pid=4242))
    assert runner.calls[booted_calls:] == []
    assert runner.processes[0].returncode is None

    booter.shutdown(record)
    after_first = len(runner.calls)
    booter.shutdown(record)
    assert runner.calls[after_first:] == []


def test_clock_jump_kills_and_raises_env(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_listing((OTHER, "Other_AVD")), *_ready(), *_rtt("0.000"), *_teardown(restore=False)])

    error = _boot_fails(_booter(runner, avd_home, clock), tmp_path)

    assert error.reason.startswith("clock-jump")
    assert SERIAL in error.reason
    assert _on(SERIAL, "emu", "kill") in runner.calls
    assert not _has(runner.calls, "settings")
    assert not _has(runner.calls, "uptime")
    assert _port_is_free(avd_home, 5556)


def test_reused_clock_jump_is_env_without_kill(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_listing((OTHER, "Other_AVD"), (SERIAL, AVD)), *_rtt("0.000")])

    error = _boot_fails(_booter(runner, avd_home, clock), tmp_path)

    assert error.reason.startswith("clock-jump")
    assert not _has(runner.calls, "kill")
    assert not _has(runner.calls, EMULATOR)
    assert runner.processes == []


def test_missing_avd_is_env_naming_avdmanager(tmp_path: Path, clock: FakeClock) -> None:
    empty_home = tmp_path / "avd"
    empty_home.mkdir()
    runner = EmulatorRunner([*_listing()])

    error = _boot_fails(_booter(runner, empty_home, clock), tmp_path)

    assert missing_avd_message(AVD) in error.reason
    assert "avdmanager create avd" in error.reason
    assert runner.processes == []
    assert _port_is_free(empty_home, 5554)


def test_spawn_failure_is_env_and_releases_the_port(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = SpawnFailsRunner([*_listing((OTHER, "Other_AVD"))])

    error = _boot_fails(_booter(runner, avd_home, clock), tmp_path)

    assert EMULATOR in error.reason
    assert not _has(runner.calls, "kill")
    assert _port_is_free(avd_home, 5556)


def test_offline_then_device_passes_the_ready_wait(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    script = _cold_boot()
    first_state = script.index(_state("device")[0])
    script[first_state:first_state] = _state("offline")
    runner = EmulatorRunner(script)

    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    assert runner.calls.count(_on(SERIAL, "get-state")) == 2
    assert clock.sleeps == [1.0]
    assert record.device_id == SERIAL
    assert record.port is not None
    record.port.release()


def test_ready_wait_bound_raises_env_naming_state(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    lane = LaneConfig(20, 420, True, (), 30, boot_timeout_minutes=1)
    runner = EmulatorRunner(
        [*_listing((OTHER, "Other_AVD")), *_state("offline") * 61, *_teardown(restore=False)], hangs=True
    )

    error = _boot_fails(_booter(runner, avd_home, clock, lane), tmp_path)

    assert f"{SERIAL} is not ready for adb (state 'offline') after 60 s" in error.reason
    assert runner.calls.count(_on(SERIAL, "get-state")) == 61
    assert _on(SERIAL, "emu", "kill") in runner.calls
    assert runner.processes[0].returncode == -9
    assert _port_is_free(avd_home, 5556)


def test_settle_names_every_unmet_gate_at_the_bound(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    lane = LaneConfig(20, 3, True, (), 30)
    unsettled = _settle(load="3.50", focus=FOCUS_ANR, ime=IME_UNBOUND)
    runner = EmulatorRunner(
        [*_listing((OTHER, "Other_AVD")), *_ready(), *_rtt("12.3"), *unsettled * 4, *_teardown(restore=False)]
    )

    error = _boot_fails(_booter(runner, avd_home, clock, lane), tmp_path)

    assert f"{SERIAL} did not settle after boot within 3 s" in error.reason
    for reason in settle_reasons(3.5, SYSTEMUI, ime=False):
        assert reason in error.reason
    assert runner.calls.count(_on(SERIAL, "shell", "uptime")) == 4
    assert not _has(runner.calls, "force-stop")
    assert not _has(runner.calls, "settings")
    assert _on(SERIAL, "emu", "kill") in runner.calls


def test_anr_at_boot_force_stops_its_package_then_rechecks(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_rtt("12.3"),
        *_settle(),
        *_focus(FOCUS_ANR),
        (_force_stop(SYSTEMUI), _done()),
        *_focus(FOCUS_NORMAL),
        *_puts(),
    ]
    runner = EmulatorRunner(script)

    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    window = _on(SERIAL, "shell", "dumpsys", "window")
    window_calls = [index for index, call in enumerate(runner.calls) if call == window]
    stop = runner.calls.index(_force_stop(SYSTEMUI))
    assert window_calls[1] < stop < window_calls[2]
    assert record.settings_applied is True
    assert record.port is not None
    record.port.release()


def test_anr_still_focused_after_force_stop_is_env(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_rtt("12.3"),
        *_settle(),
        *_focus(FOCUS_ANR),
        (_force_stop(SYSTEMUI), _done()),
        *_focus(FOCUS_ANR),
        *_teardown(restore=False),
    ]
    runner = EmulatorRunner(script)

    error = _boot_fails(_booter(runner, avd_home, clock), tmp_path)

    assert SYSTEMUI in error.reason
    assert "force-stop" in error.reason
    assert _on(SERIAL, "emu", "kill") in runner.calls
    assert not _has(runner.calls, "settings")
    assert _port_is_free(avd_home, 5556)


def test_anr_naming_no_package_is_never_force_stopped(avd_home: Path, clock: FakeClock) -> None:
    runner = FakeRunner([*_state("device"), *_ready(), *_focus(FOCUS_ANR_NO_PACKAGE), *_focus(FOCUS_ANR_NO_PACKAGE)])
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock).before_file(record)

    assert "names no package" in caught.value.reason
    assert not _has(runner.calls, "force-stop")


def test_settings_applied_after_settle_and_restored_before_kill(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    runner = EmulatorRunner([*_cold_boot(), *_teardown(restore=True)])
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")
    booted_calls = len(runner.calls)

    booter.shutdown(record)

    puts = [tuple(argv) for argv in settings_apply_argv(ADB, SERIAL)]
    deletes = [tuple(argv) for argv in settings_restore_argv(ADB, SERIAL)]
    settle_end = runner.calls.index(_on(SERIAL, "shell", "dumpsys", "input_method"))
    assert runner.calls[booted_calls - len(puts) : booted_calls] == puts
    assert settle_end < booted_calls - len(puts)
    assert runner.calls[booted_calls:] == [*deletes, _on(SERIAL, "emu", "kill"), (ADB, "devices")]
    assert record.settings_applied is False


def test_shutdown_kills_only_the_recorded_serial(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_cold_boot(), *_teardown(restore=True)])
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")
    booted_calls = len(runner.calls)

    booter.shutdown(record)

    shutdown_calls = runner.calls[booted_calls:]
    for call in shutdown_calls:
        assert call == (ADB, "devices") or call[:3] == (ADB, "-s", SERIAL), call
    assert shutdown_calls.count(_on(SERIAL, "emu", "kill")) == 1
    assert not any(OTHER in call for call in shutdown_calls)
    assert runner.processes[0].returncode == 0
    assert _port_is_free(avd_home, 5556)


def test_shutdown_kills_the_pid_when_emu_kill_leaves_it_running(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    runner = EmulatorRunner([*_cold_boot(), *_teardown(restore=True)], hangs=True)
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")

    booter.shutdown(record)

    assert runner.processes[0].returncode == -9
    assert clock.now >= 60
    assert _port_is_free(avd_home, 5556)


def test_before_file_reconnects_an_offline_serial_once(avd_home: Path, clock: FakeClock) -> None:
    reconnect = _on(SERIAL, "reconnect", "offline")
    runner = FakeRunner(
        [*_state("offline"), (reconnect, _done()), *_state("offline"), *_ready(), *_focus(FOCUS_NORMAL)]
    )
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    _booter(runner, avd_home, clock).before_file(record)

    assert runner.calls.count(reconnect) == 1
    assert runner.calls.index(reconnect) == 1
    assert runner.calls[-1] == _on(SERIAL, "shell", "dumpsys", "window")


def test_before_file_still_offline_at_the_bound_is_env_after_one_reconnect(avd_home: Path, clock: FakeClock) -> None:
    lane = LaneConfig(20, 420, True, (), 30, boot_timeout_minutes=1)
    reconnect = _on(SERIAL, "reconnect", "offline")
    runner = FakeRunner([*_state("offline"), (reconnect, _done()), *_state("offline") * 61])
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock, lane).before_file(record)

    assert "not ready for adb (state 'offline')" in caught.value.reason
    assert runner.calls.count(reconnect) == 1


def test_before_file_clears_an_anr_on_a_ready_device(avd_home: Path, clock: FakeClock) -> None:
    runner = FakeRunner(
        [*_state("device"), *_ready(), *_focus(FOCUS_ANR), (_force_stop(SYSTEMUI), _done()), *_focus(FOCUS_NORMAL)]
    )
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    _booter(runner, avd_home, clock).before_file(record)

    assert not _has(runner.calls, "reconnect")
    assert _force_stop(SYSTEMUI) in runner.calls
