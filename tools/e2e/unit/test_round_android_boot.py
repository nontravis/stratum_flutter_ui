"""Unit tests for the Android booter: boot, reuse, ready, and kill by serial, with a scripted adb and a fake clock."""

from __future__ import annotations

import subprocess
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import cast

import pytest

from stratum_e2e.round.android_boot import AndroidBooter
from stratum_e2e.round.android_host import CONSOLE_PORTS, adb_path, emulator_path, missing_avd_message, reserve_port
from stratum_e2e.round.android_traps import (
    BOOT_SETTINGS,
    settings_apply_argv,
    settings_restore_argv,
    settle_reasons,
)
from stratum_e2e.round.boot import BootLog, BootRecord
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
# An ANR window of a package other than the SYSTEMUI fixture, for last-poll naming.
_OTHER_APP_ANR = "  Window #0 Window{9f8e7d u0 Application Not Responding: com.example.app}:\n"
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


class EmulatorProcess(FakeProcess):
    """A FakeProcess that also records each bounded `wait`."""

    def __init__(self) -> None:
        super().__init__()
        self.waits: list[float | None] = []

    def wait(self, timeout: float | None = None) -> int | None:
        self.waits.append(timeout)
        return self.returncode


class EmulatorRunner(FakeRunner):
    """A FakeRunner whose spawned emulator exits on `emu kill`; with `hangs`, it ignores `emu kill` and runs on.

    `exits_after` makes the emulator exit with status 1 right after that argv is answered; `interrupt_on` makes
    that argv raise `KeyboardInterrupt`, as a Ctrl-C mid-call would.
    """

    def __init__(
        self,
        script: Sequence[Entry],
        *,
        hangs: bool = False,
        exits_after: tuple[str, ...] | None = None,
        interrupt_on: tuple[str, ...] | None = None,
    ) -> None:
        super().__init__(script)
        self.processes: list[EmulatorProcess] = []
        self._hangs = hangs
        self._exits_after = exits_after
        self._interrupt_on = interrupt_on

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]:
        self.calls.append(tuple(argv))
        process = EmulatorProcess()
        self.processes.append(process)
        return cast("subprocess.Popen[bytes]", process)

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        if tuple(argv) == self._interrupt_on:
            self.calls.append(tuple(argv))
            raise KeyboardInterrupt
        done = super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)
        if tuple(argv[-2:]) == ("emu", "kill") and not self._hangs:
            for process in self.processes:
                process.returncode = 0
        if tuple(argv) == self._exits_after:
            for process in self.processes:
                process.returncode = 1
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


def _done(stdout: str = "", status: int = 0, *, timed_out: bool = False) -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr="", timed_out=timed_out)


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


def _confirm(avd: str = AVD) -> list[Entry]:
    return [(_on(SERIAL, "emu", "avd", "name"), _done(f"{avd}\r\nOK\r\n"))]


def _rtt(ms: str) -> list[Entry]:
    return [(_on(SERIAL, *RTT), _done(f"64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time={ms} ms\n"))]


def _settle(load: str = "0.50", windows: str = FOCUS_NORMAL, ime: str = IME_BOUND) -> list[Entry]:
    uptime = f" 14:10:01 up 1 day,  1:23,  0 users,  load average: {load}, 0.40, 0.30\n"
    return [
        (_on(SERIAL, "shell", "uptime"), _done(uptime)),
        (_on(SERIAL, "shell", "dumpsys", "window", "windows"), _done(windows)),
        (_on(SERIAL, "shell", "dumpsys", "input_method"), _done(ime)),
    ]


def _windows(dump: str) -> list[Entry]:
    return [(_on(SERIAL, "shell", "dumpsys", "window", "windows"), _done(dump))]


def _settle_anr_unbound(load: str) -> list[Entry]:
    """One unsettled settle poll — high load, an ANR window, no IME — with the broadcast answer."""
    uptime = f" 14:10:01 up 1 day,  1:23,  0 users,  load average: {load}, 0.40, 0.30\n"
    return [
        (_on(SERIAL, "shell", "uptime"), _done(uptime)),
        *_windows(FOCUS_ANR),
        (_close_dialogs(), _done()),
        (_on(SERIAL, "shell", "dumpsys", "input_method"), _done(IME_UNBOUND)),
    ]


def _close_dialogs() -> tuple[str, ...]:
    return _on(SERIAL, "shell", "-n", "am", "broadcast", "-a", "android.intent.action.CLOSE_SYSTEM_DIALOGS")


def _puts(*, failing: int | None = None) -> list[Entry]:
    """One `settings put` answer per boot setting; the row at index `failing` answers status 1."""
    argvs = settings_apply_argv(ADB, SERIAL)
    return [(tuple(argv), _done(status=1 if index == failing else 0)) for index, argv in enumerate(argvs)]


def _teardown(*, restore: bool, failing_delete: int | None = None) -> list[Entry]:
    argvs = settings_restore_argv(ADB, SERIAL) if restore else []
    deletes = [(tuple(argv), _done(status=1 if index == failing_delete else 0)) for index, argv in enumerate(argvs)]
    return [
        *deletes,
        (_on(SERIAL, "emu", "kill"), _done("OK: killing emulator, bye bye\r\n")),
        ((ADB, "devices"), _done(_devices_text(OTHER))),
    ]


def _cold_boot() -> list[Entry]:
    return [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *_settle(),
        *_windows(FOCUS_NORMAL),
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


_READS = (("get-state",), ("emu", "avd", "name"), ("shell", "pm"), RTT, ("shell", "uptime"), ("shell", "dumpsys"))


def _changes_on(calls: list[tuple[str, ...]], serial: str) -> list[tuple[str, ...]]:
    """Every adb call that changes the device on `serial`: anything but a read."""
    on_serial = [call[3:] for call in calls if call[:3] == (ADB, "-s", serial)]
    return [call for call in on_serial if not any(call[: len(read)] == read for read in _READS)]


def test_cold_boot_argv_and_record(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner(_cold_boot())
    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    spawn = (
        EMULATOR, "-avd", AVD, "-port", "5556", "-no-snapshot-load", "-no-audio", "-gpu", "host", "-memory", "4096",
    )
    assert [call for call in runner.calls if call[0] == EMULATOR] == [spawn]
    assert runner.calls.index(spawn) < runner.calls.index(_on(SERIAL, "get-state"))
    assert (record.target, record.platform, record.device_id) == ("pixel_8", "android", SERIAL)
    assert record.reused is False
    assert record.pid == runner.processes[0].pid
    assert record.port is not None
    assert record.port.port == 5556
    assert record.settings_applied is True
    record.port.release()


def test_cold_boot_carries_no_audio_once_even_when_the_target_lists_it(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    target = Target(
        name="pixel_8",
        platform="android",
        alone=True,
        avd=AVD,
        build_mode="profile",
        emulator_args=("-no-audio", "-gpu", "host"),
    )
    runner = EmulatorRunner(_cold_boot())
    _booter(runner, avd_home, clock).boot(target, tmp_path / "emulator.log")

    spawn = [call for call in runner.calls if call[0] == EMULATOR][0]
    assert spawn.count("-no-audio") == 1
    assert spawn[spawn.index("-no-audio") + 1 :] == ("-gpu", "host")


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
    runner = EmulatorRunner(
        [*_listing((OTHER, "Other_AVD")), *_ready(), *_confirm(), *_rtt("0.000"), *_teardown(restore=False)]
    )

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
    runner = EmulatorRunner([*_listing((OTHER, "Other_AVD")), *_state("offline") * 61], hangs=True)

    error = _boot_fails(_booter(runner, avd_home, clock, lane), tmp_path)

    assert f"{SERIAL} is not ready for adb (state 'offline') after 60 s" in error.reason
    assert runner.calls.count(_on(SERIAL, "get-state")) == 61
    # The serial never answered with this AVD's name, so only the pid this booter spawned is ended.
    assert _changes_on(runner.calls, SERIAL) == []
    assert runner.processes[0].returncode == -9
    assert _port_is_free(avd_home, 5556)


def test_settle_names_every_unmet_gate_at_the_bound(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    lane = LaneConfig(20, 3, True, (), 30)
    unsettled = _settle_anr_unbound(load="3.50")
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *unsettled * 4,
        *_teardown(restore=False),
    ]
    runner = EmulatorRunner(script)

    error = _boot_fails(_booter(runner, avd_home, clock, lane), tmp_path)

    assert f"{SERIAL} did not settle after boot within 3 s" in error.reason
    for reason in settle_reasons(3.5, (SYSTEMUI,), ime=False):
        assert reason in error.reason
    assert runner.calls.count(_on(SERIAL, "shell", "uptime")) == 4
    assert runner.calls.count(_close_dialogs()) == 4
    assert not _has(runner.calls, "settings")
    assert _on(SERIAL, "emu", "kill") in runner.calls


def test_settle_broadcasts_on_each_poll_that_lists_an_anr_and_keeps_polling(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    anr_poll = [
        (_on(SERIAL, "shell", "uptime"), _done(" 14:10:01 up 1 day,  1:23,  0 users,  load average: 0.50, 0.40, 0.30\n")),
        *_windows(FOCUS_ANR),
        (_close_dialogs(), _done()),
        (_on(SERIAL, "shell", "dumpsys", "input_method"), _done(IME_BOUND)),
    ]
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *anr_poll,
        *anr_poll,
        *_settle(),
        *_windows(FOCUS_NORMAL),
        *_puts(),
    ]
    runner = EmulatorRunner(script)

    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    assert runner.calls.count(_close_dialogs()) == 2
    assert runner.calls.count(_on(SERIAL, "shell", "uptime")) == 3
    assert clock.sleeps == [1.0, 1.0]
    assert record.settings_applied is True
    assert record.port is not None
    record.port.release()


def test_settle_catches_an_anr_window_that_has_no_focus_yet(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    unfocused = (FIXTURES / "windows_anr_unfocused_api35.txt").read_text()
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *_settle(windows=unfocused),
        (_close_dialogs(), _done()),
        *_settle(),
        *_windows(FOCUS_NORMAL),
        *_puts(),
    ]
    runner = EmulatorRunner(script)

    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    assert runner.calls.count(_close_dialogs()) == 1
    assert record.settings_applied is True
    record.port.release()


def test_anr_at_boot_broadcasts_close_then_rechecks(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *_settle(),
        (_on(SERIAL, "shell", "uptime"), _done(" 14:10:01 up 1 day,  1:23,  0 users,  load average: 0.50, 0.40, 0.30\n")),
        *_windows(FOCUS_ANR),
        (_close_dialogs(), _done()),
        (_on(SERIAL, "shell", "dumpsys", "input_method"), _done(IME_BOUND)),
        *_windows(FOCUS_NORMAL),
        *_puts(),
    ]
    runner = EmulatorRunner(script)

    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    window = _on(SERIAL, "shell", "dumpsys", "window", "windows")
    window_calls = [index for index, call in enumerate(runner.calls) if call == window]
    stop = runner.calls.index(_close_dialogs())
    assert window_calls[1] < stop < window_calls[2]
    assert record.settings_applied is True
    assert record.port is not None
    record.port.release()


def test_anr_still_listed_after_close_system_dialogs_is_env(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    still = [*_windows(FOCUS_ANR), (_close_dialogs(), _done())]
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *_settle(),
        *still * 17,
        *_teardown(restore=False),
    ]
    runner = EmulatorRunner(script)

    error = _boot_fails(_booter(runner, avd_home, clock), tmp_path)

    assert SYSTEMUI in error.reason
    assert "CLOSE_SYSTEM_DIALOGS" in error.reason
    assert runner.calls.count(_close_dialogs()) == 16
    assert _on(SERIAL, "emu", "kill") in runner.calls
    assert not _has(runner.calls, "settings")
    assert _port_is_free(avd_home, 5556)


def test_anr_naming_no_package_still_gets_the_broadcast(avd_home: Path, clock: FakeClock) -> None:
    still = [*_windows(FOCUS_ANR_NO_PACKAGE), (_close_dialogs(), _done())]
    runner = FakeRunner([*_state("device"), *_ready(), *still * 17])
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock).before_file(record)

    assert "still lists after CLOSE_SYSTEM_DIALOGS" in caught.value.reason
    assert "unknown" in caught.value.reason
    assert _close_dialogs() in runner.calls


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
        [*_state("offline"), (reconnect, _done()), *_state("offline"), *_ready(), *_windows(FOCUS_NORMAL)]
    )
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    _booter(runner, avd_home, clock).before_file(record)

    assert runner.calls.count(reconnect) == 1
    assert runner.calls.index(reconnect) == 1
    assert runner.calls[-1] == _on(SERIAL, "shell", "dumpsys", "window", "windows")


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
        [*_state("device"), *_ready(), *_windows(FOCUS_ANR), (_close_dialogs(), _done()), *_windows(FOCUS_NORMAL)]
    )
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    _booter(runner, avd_home, clock).before_file(record)

    assert not _has(runner.calls, "reconnect")
    assert _close_dialogs() in runner.calls


def test_clear_anr_polls_until_the_dialog_leaves_the_window_list(avd_home: Path, clock: FakeClock) -> None:
    still = [*_windows(FOCUS_ANR), (_close_dialogs(), _done())]
    runner = FakeRunner(
        [
            *_state("device"),
            *_ready(),
            *still,
            *still,
            *_windows(FOCUS_NORMAL),
        ]
    )
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    _booter(runner, avd_home, clock).before_file(record)

    assert runner.calls.count(_close_dialogs()) == 2
    assert clock.sleeps == [1.0, 1.0]


def test_clear_anr_raises_after_the_close_wait_and_names_the_packages(avd_home: Path, clock: FakeClock) -> None:
    first = [*_windows(FOCUS_ANR), (_close_dialogs(), _done())]
    later = [*_windows(_OTHER_APP_ANR), (_close_dialogs(), _done())]
    runner = FakeRunner([*_state("device"), *_ready(), *first, *later * 16])
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock).before_file(record)

    assert "still lists after CLOSE_SYSTEM_DIALOGS" in caught.value.reason
    assert "com.example.app" in caught.value.reason
    assert clock.now >= 15.0


def test_clear_anr_names_the_packages_the_last_poll_listed_not_the_entry_ones(
    avd_home: Path, clock: FakeClock
) -> None:
    first = [*_windows(FOCUS_ANR), (_close_dialogs(), _done())]
    later = [*_windows(_OTHER_APP_ANR), (_close_dialogs(), _done())]
    runner = FakeRunner([*_state("device"), *_ready(), *first, *later * 16])
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock).before_file(record)

    reason = caught.value.reason
    assert SYSTEMUI not in reason.split("still lists")[-1]
    assert "com.example.app" in reason


def _failed_windows(status: int = 1, *, timed_out: bool = False) -> list[Entry]:
    return [
        (
            _on(SERIAL, "shell", "dumpsys", "window", "windows"),
            _done("error: dump failed\n", status, timed_out=timed_out),
        )
    ]


def test_settle_holds_on_a_nonzero_window_dump_and_raises_at_the_deadline(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    lane = LaneConfig(20, 3, True, (), 30)
    bad_poll = [
        (_on(SERIAL, "shell", "uptime"), _done(" 14:10:01 up 1 day,  1:23,  0 users,  load average: 0.50, 0.40, 0.30\n")),
        *_failed_windows(),
        (_on(SERIAL, "shell", "dumpsys", "input_method"), _done(IME_BOUND)),
    ]
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *bad_poll * 4,
        *_teardown(restore=False),
    ]
    runner = EmulatorRunner(script)

    error = _boot_fails(_booter(runner, avd_home, clock, lane), tmp_path)

    assert "did not settle after boot within 3 s" in error.reason
    assert "the window list is unreadable" in error.reason
    assert not _has(runner.calls, "broadcast")


def test_settle_holds_on_an_empty_window_dump_and_raises_at_the_deadline(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    lane = LaneConfig(20, 3, True, (), 30)
    empty_poll = [
        (_on(SERIAL, "shell", "uptime"), _done(" 14:10:01 up 1 day,  1:23,  0 users,  load average: 0.50, 0.40, 0.30\n")),
        (_on(SERIAL, "shell", "dumpsys", "window", "windows"), _done("")),
        (_on(SERIAL, "shell", "dumpsys", "input_method"), _done(IME_BOUND)),
    ]
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *empty_poll * 4,
        *_teardown(restore=False),
    ]
    runner = EmulatorRunner(script)

    error = _boot_fails(_booter(runner, avd_home, clock, lane), tmp_path)

    assert "the window list is unreadable" in error.reason


def test_clear_anr_raises_after_the_wait_on_an_unreadable_window_list(
    avd_home: Path, clock: FakeClock
) -> None:
    runner = FakeRunner([*_state("device"), *_ready(), *_failed_windows() * 17])
    record = BootRecord(target="pixel_8", platform="android", device_id=SERIAL, reused=True)

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock).before_file(record)

    assert "the window list is unreadable" in caught.value.reason
    assert not _has(runner.calls, "broadcast")
    assert clock.now >= 15.0


def test_clear_anr_raises_promptly_when_the_emulator_exits_mid_poll(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    still = [*_windows(FOCUS_ANR), (_close_dialogs(), _done())]
    runner = EmulatorRunner(
        [*_listing((OTHER, "Other_AVD")), *_ready(), *_confirm(), *_rtt("12.3"), *_settle(), *still],
        exits_after=_close_dialogs(),
    )
    log = tmp_path / "emulator.log"

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock).boot(TARGET, log)

    assert "exited with status 1" in caught.value.reason


def test_emulator_exiting_during_the_ready_wait_is_env_with_no_change_on_its_serial(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    runner = EmulatorRunner(
        [*_listing((OTHER, "Other_AVD")), *_state("offline") * 3], exits_after=_on(SERIAL, "get-state")
    )
    log = tmp_path / "emulator.log"

    with pytest.raises(RoundEnvError) as caught:
        _booter(runner, avd_home, clock).boot(TARGET, log)

    assert "exited with status 1" in caught.value.reason
    assert str(log) in caught.value.reason
    assert runner.calls.count(_on(SERIAL, "get-state")) == 1
    assert _changes_on(runner.calls, SERIAL) == []
    assert runner.processes[0].returncode == 1
    assert _port_is_free(avd_home, 5556)


def test_emulator_exiting_during_the_settle_wait_is_env_with_no_change_on_its_serial(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    unsettled = _settle(load="3.50")
    script = [*_listing((OTHER, "Other_AVD")), *_ready(), *_confirm(), *_rtt("12.3"), *unsettled * 2]
    runner = EmulatorRunner(script, exits_after=_on(SERIAL, "shell", "dumpsys", "input_method"))

    error = _boot_fails(_booter(runner, avd_home, clock), tmp_path)

    assert "exited with status 1" in error.reason
    assert runner.calls.count(_on(SERIAL, "shell", "uptime")) == 1
    assert _changes_on(runner.calls, SERIAL) == []
    assert _port_is_free(avd_home, 5556)


def test_serial_answering_another_avd_is_env_and_left_alone(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_listing((OTHER, "Other_AVD")), *_ready(), *_confirm("Foreign_AVD")])

    error = _boot_fails(_booter(runner, avd_home, clock), tmp_path)

    assert "Foreign_AVD" in error.reason
    assert _changes_on(runner.calls, SERIAL) == []
    assert not _has(runner.calls, "ping")
    assert runner.processes[0].returncode == -9
    assert _port_is_free(avd_home, 5556)


def test_shutdown_after_the_emulator_exited_touches_no_serial(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner(_cold_boot())
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")
    booted_calls = len(runner.calls)
    runner.processes[0].returncode = 139

    booter.shutdown(record)

    assert runner.calls[booted_calls:] == []
    assert runner.processes[0].returncode == 139
    assert runner.processes[0].waits == []
    assert _port_is_free(avd_home, 5556)


def test_before_file_on_an_exited_emulator_is_env_with_no_change(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    runner = EmulatorRunner(_cold_boot())
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")
    booted_calls = len(runner.calls)
    runner.processes[0].returncode = 139

    with pytest.raises(RoundEnvError) as caught:
        booter.before_file(record)

    assert "exited with status 139" in caught.value.reason
    assert runner.calls[booted_calls:] == []
    booter.shutdown(record)


def test_failed_setting_put_is_recorded_and_the_boot_succeeds(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    script = _cold_boot()
    script[-len(BOOT_SETTINGS) :] = _puts(failing=0)
    runner = EmulatorRunner(script)

    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    assert len(record.setting_failures) == 1
    assert BOOT_SETTINGS[0][0] in record.setting_failures[0]
    assert "status 1" in record.setting_failures[0]
    assert runner.calls[-len(BOOT_SETTINGS) :] == [tuple(argv) for argv in settings_apply_argv(ADB, SERIAL)]
    assert record.settings_applied is True
    assert record.port is not None
    record.port.release()


def test_failed_setting_delete_is_recorded_and_the_kill_still_runs(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    runner = EmulatorRunner([*_cold_boot(), *_teardown(restore=True, failing_delete=1)])
    booter = _booter(runner, avd_home, clock)
    record = booter.boot(TARGET, tmp_path / "emulator.log")

    booter.shutdown(record)

    assert len(record.setting_failures) == 1
    assert BOOT_SETTINGS[1][0] in record.setting_failures[0]
    assert _on(SERIAL, "emu", "kill") in runner.calls
    assert _port_is_free(avd_home, 5556)


def test_interrupt_during_the_ready_wait_kills_waits_and_releases(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    runner = EmulatorRunner([*_listing((OTHER, "Other_AVD"))], interrupt_on=_on(SERIAL, "get-state"))

    with pytest.raises(KeyboardInterrupt):
        _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log")

    process = runner.processes[0]
    assert process.returncode == -9
    assert len(process.waits) == 1
    assert process.waits[0] is not None
    assert _changes_on(runner.calls, SERIAL) == []
    assert _port_is_free(avd_home, 5556)


SINCE = datetime(2026, 10, 24, 1, 2, 3, 456000, tzinfo=UTC)
LOGCAT = (
    ADB, "-s", SERIAL, "logcat", "-d", "-b", "main,system,crash,events", "-v", "threadtime", "-T", "1792803723.456"
)


def _boot_log(tmp_path: Path) -> BootLog:
    return BootLog(tmp_path / "boot.log", SINCE)


def _logcat() -> list[Entry]:
    return [(LOGCAT, _done("am_anr line\n"))]


def test_cold_boot_saves_the_device_log_from_the_boot_start_once_settled(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    runner = EmulatorRunner([*_cold_boot(), *_logcat()])

    record = _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log", _boot_log(tmp_path))

    assert runner.calls.count(LOGCAT) == 1
    assert runner.calls.index(LOGCAT) > runner.calls.index(_on(SERIAL, "shell", "dumpsys", "input_method"))
    assert record.port is not None
    record.port.release()


def test_a_settle_failure_saves_the_device_log_before_the_emulator_ends_and_still_raises(
    tmp_path: Path, avd_home: Path, clock: FakeClock
) -> None:
    lane = LaneConfig(20, 3, True, (), 30)
    unsettled = _settle_anr_unbound(load="3.50")
    script = [
        *_listing((OTHER, "Other_AVD")),
        *_ready(),
        *_confirm(),
        *_rtt("12.3"),
        *unsettled * 4,
        *_logcat(),
        *_teardown(restore=False),
    ]
    runner = EmulatorRunner(script)

    with pytest.raises(RoundEnvError, match="did not settle"):
        _booter(runner, avd_home, clock, lane).boot(TARGET, tmp_path / "emulator.log", _boot_log(tmp_path))

    assert runner.calls.count(LOGCAT) == 1
    assert runner.calls.index(LOGCAT) < runner.calls.index(_on(SERIAL, "emu", "kill"))


def test_a_reused_emulator_saves_no_device_log(tmp_path: Path, avd_home: Path, clock: FakeClock) -> None:
    runner = EmulatorRunner([*_listing((OTHER, "Other_AVD"), (SERIAL, AVD)), *_rtt("12.3")])

    _booter(runner, avd_home, clock).boot(TARGET, tmp_path / "emulator.log", _boot_log(tmp_path))

    assert not _has(runner.calls, "logcat")
