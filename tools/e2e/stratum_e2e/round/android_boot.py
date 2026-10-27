"""Boot, reuse, ready, and end Android emulators for the device round, always by serial.

Ported from the skill's `platforms/android.sh` (`p_boot`, `p_ready`, `p_pre_launch`, `p_kill`). The booter ends only
an emulator it spawned itself: a running AVD is reused as found and left running, even when it fails a check. A
booted serial is the round's own only while the spawned process is alive and the serial's console has answered with
the AVD's name; until then, and once the process exits, the booter changes nothing on that serial.
"""

from __future__ import annotations

import contextlib
import subprocess
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path

from stratum_e2e.round.android_host import CONSOLE_PORTS, adb_path, avd_info, emulator_path, reserve_port
from stratum_e2e.round.android_traps import (
    anr_window_packages,
    clock_jumped,
    guest_load,
    ime_bound,
    settings_apply_argv,
    settings_restore_argv,
    settle_reasons,
)
from stratum_e2e.round.boot import Booter, BootLog, BootRecord
from stratum_e2e.round.capture import keep_boot_log
from stratum_e2e.round.catalog import LaneConfig, Target
from stratum_e2e.round.errors import CatalogError, RoundEnvError
from stratum_e2e.round.runner import Completed, Runner

_PLATFORM = "android"
_SERIAL_PREFIX = "emulator-"
_READY_STATE = "device"
_RTT_ARGS = ("shell", "ping", "-c", "1", "8.8.8.8")
_POLL_S = 1.0
_ADB_TIMEOUT_S = 60.0
# measured 2026-10-27 on Pixel_Tablet_API_35: CLOSE_SYSTEM_DIALOGS closed a hidden System UI ANR dialog within 1 s
_ANR_CLOSE_WAIT_S = 15.0
_GONE_WAIT_S = 60.0
_REAP_WAIT_S = 10.0


@dataclass
class _Spawned:
    """An emulator this booter started; `confirmed` once its serial's console answered with `avd`."""

    process: subprocess.Popen[bytes]
    avd: str
    log: Path
    confirmed: bool = False


class AndroidBooter(Booter):
    """Boots each target's AVD cold on a reserved console port, and ends only the emulators it booted."""

    def __init__(
        self,
        runner: Runner,
        sdk: Path,
        lane: LaneConfig,
        avd_home: Path,
        port_dir: Path,
        *,
        sleep: Callable[[float], None] = time.sleep,
        monotonic: Callable[[], float] = time.monotonic,
    ) -> None:
        self._runner = runner
        self._adb = adb_path(sdk)
        self._emulator = emulator_path(sdk)
        self._lane = lane
        self._avd_home = avd_home
        self._port_dir = port_dir
        self._sleep = sleep
        self._monotonic = monotonic
        # Keyed by serial: the one place `before_file` and `shutdown` learn that this booter spawned the emulator.
        self._spawned: dict[str, _Spawned] = {}

    def running_serial(self, avd: str) -> str | None:
        """The serial of the running emulator whose AVD is `avd`: `adb devices`, then `adb -s <serial> emu avd name`."""
        return self._serial_of(avd, self._attached())

    def is_running(self, target: Target) -> bool:
        """Whether the AVD of `target` already runs, so `boot` reuses it and the memory gate is skipped."""
        return self.running_serial(_avd(target)) is not None

    def boot(self, target: Target, log: Path, device_log: BootLog | None = None) -> BootRecord:
        """Reuse the running AVD of `target` after the rtt check, else cold boot it with emulator output in `log`.

        A cold boot saves its logcat to `device_log` once settled, or, when the boot fails, before the emulator ends.
        """
        avd = _avd(target)
        attached = self._attached()
        serial = self._serial_of(avd, attached)
        if serial is not None:
            return self._reuse(target, serial)
        return self._cold_boot(target, avd, attached, log, device_log)

    def before_file(self, record: BootRecord) -> None:
        """Give a serial not in state `device` one `adb reconnect offline`, wait until ready, then clear an ANR.

        A booted record whose emulator exited, or that this booter does not hold, raises before any adb call.
        """
        serial = record.device_id
        if not record.reused:
            spawned = self._owned(record)
            if spawned is None:
                raise RoundEnvError(f"{serial} is not an emulator this booter has running")
            self._check_alive(serial)
        if self._state(serial) != _READY_STATE:
            self._on(serial, "reconnect", "offline")
        self._ready_wait(serial)
        self._clear_anr(serial)

    def shutdown(self, record: BootRecord) -> None:
        """Restore the boot settings, `emu kill` the serial, wait for it to go, kill the pid, and release the port.

        Does nothing for a reused record, and nothing for a record whose serial and pid this booter did not spawn
        or already ended. The serial gets no adb call unless it is still the round's own (see the module docstring);
        the spawned pid is killed and reaped and the port released on every path.
        """
        spawned = self._owned(record)
        if record.reused or spawned is None:
            return
        del self._spawned[record.device_id]
        process = spawned.process
        try:
            if spawned.confirmed and process.poll() is None:
                self._end_on_serial(record, process)
        finally:
            if process.poll() is None:
                process.kill()
                with contextlib.suppress(subprocess.TimeoutExpired):
                    process.wait(timeout=_REAP_WAIT_S)
            if record.port is not None:
                record.port.release()

    def _owned(self, record: BootRecord) -> _Spawned | None:
        spawned = self._spawned.get(record.device_id)
        if spawned is None or spawned.process.pid != record.pid:
            return None
        return spawned

    def _end_on_serial(self, record: BootRecord, process: subprocess.Popen[bytes]) -> None:
        serial = record.device_id
        if record.settings_applied:
            self._write_settings(record, settings_restore_argv(self._adb, serial))
            record.settings_applied = False
        self._on(serial, "emu", "kill")
        self._wait_gone(serial, process)

    def _reuse(self, target: Target, serial: str) -> BootRecord:
        if self._clock_jumped(serial):
            raise RoundEnvError(
                f"clock-jump: ping rtt read 0.000 on {serial}, which ran before the round, so it is left running"
            )
        return BootRecord(target=target.name, platform=_PLATFORM, device_id=serial, reused=True)

    def _cold_boot(
        self, target: Target, avd: str, attached: Mapping[str, str], log: Path, device_log: BootLog | None
    ) -> BootRecord:
        avd_info(avd, self._avd_home)
        taken = {port for port in map(_console_port, attached) if port is not None}
        reservation = reserve_port(*CONSOLE_PORTS, taken, self._port_dir)
        serial = f"{_SERIAL_PREFIX}{reservation.port}"
        # WORKAROUND: Android Emulator 37.2.12's virtio-snd deadlocks holding the QEMU big lock in CoreAudio
        # and its hang detector kills the emulator (R3 e2e_talkback boot); remove when an emulator release
        # fixes it.
        audio_args = () if "-no-audio" in target.emulator_args else ("-no-audio",)
        argv = [
            self._emulator, "-avd", avd, "-port", str(reservation.port), "-no-snapshot-load",
            *audio_args, *target.emulator_args,
        ]
        record = BootRecord(target=target.name, platform=_PLATFORM, device_id=serial, reused=False, port=reservation)
        try:
            try:
                process = self._runner.spawn(argv, log=log)
            except OSError as error:
                raise RoundEnvError(f"cannot start {self._emulator}: {error}") from error
            self._spawned[serial] = _Spawned(process=process, avd=avd, log=log)
            record.pid = process.pid
            self._bring_up(record)
            keep_boot_log(self._runner, record, device_log)
        except BaseException:
            try:
                if record.pid is not None:
                    keep_boot_log(self._runner, record, device_log)
                self.shutdown(record)
            finally:
                reservation.release()
            raise
        return record

    def _bring_up(self, record: BootRecord) -> None:
        serial = record.device_id
        self._ready_wait(serial)
        self._confirm_avd(serial)
        if self._clock_jumped(serial):
            raise RoundEnvError(f"clock-jump: ping rtt read 0.000 on {serial}")
        self._settle_wait(serial)
        self._clear_anr(serial)
        record.settings_applied = True
        self._write_settings(record, settings_apply_argv(self._adb, serial))

    def _confirm_avd(self, serial: str) -> None:
        """Prove the serial is the spawned emulator before the first change: its console must name the AVD."""
        spawned = self._spawned[serial]
        name = self._avd_name(serial)
        if name != spawned.avd:
            raise RoundEnvError(
                f"{serial} answers as AVD {name!r}, not {spawned.avd!r}: another emulator holds the port, "
                "so the round leaves it alone"
            )
        spawned.confirmed = True

    def _check_alive(self, serial: str) -> None:
        """Raise once the emulator this booter spawned on `serial` has exited; a serial it did not spawn passes."""
        spawned = self._spawned.get(serial)
        if spawned is None:
            return
        status = spawned.process.poll()
        if status is not None:
            raise RoundEnvError(
                f"the emulator this round booted on {serial} exited with status {status}; see {spawned.log}"
            )

    def _ready_wait(self, serial: str) -> None:
        """Wait for state `device` and an answer from `pm path android`.

        `sys.boot_completed` alone can leave adb `offline` on a serial an earlier emulator used.
        """
        limit = self._lane.boot_timeout_minutes * 60
        deadline = self._monotonic() + limit
        while True:
            self._check_alive(serial)
            state = self._state(serial)
            if state == _READY_STATE and self._on(serial, "shell", "pm", "path", "android").status == 0:
                return
            if self._monotonic() >= deadline:
                raise RoundEnvError(f"{serial} is not ready for adb (state {state!r}) after {limit} s")
            self._sleep(_POLL_S)

    def _settle_wait(self, serial: str) -> None:
        """Poll the settle gates; on each poll that lists an ANR window, broadcast CLOSE_SYSTEM_DIALOGS once."""
        limit = self._lane.boot_settle_timeout_seconds
        deadline = self._monotonic() + limit
        while True:
            self._check_alive(serial)
            load = guest_load(self._on(serial, "shell", "uptime").stdout)
            anr = self._anr_packages(serial)
            reasons = settle_reasons(load, anr, ime_bound(self._on(serial, "shell", "dumpsys", "input_method").stdout))
            if not reasons:
                return
            if anr:
                self._close_anr_dialogs(serial)
            if self._monotonic() >= deadline:
                raise RoundEnvError(f"{serial} did not settle after boot within {limit} s: {'; '.join(reasons)}")
            self._sleep(_POLL_S)

    def _clear_anr(self, serial: str) -> None:
        """Broadcast CLOSE_SYSTEM_DIALOGS, then poll until no ANR window lists or the wait runs out.

        The broadcast maps to FORCE_CLOSE on the ANR dialog's receiver for any package, focused or not,
        so no package name is needed; each poll that still lists an ANR window sends it again.
        """
        deadline = self._monotonic() + _ANR_CLOSE_WAIT_S
        packages = self._anr_packages(serial)
        while packages:
            self._close_anr_dialogs(serial)
            if self._monotonic() >= deadline:
                raise RoundEnvError(
                    f"{serial}: an ANR window of {', '.join(packages)} still lists after CLOSE_SYSTEM_DIALOGS"
                )
            self._sleep(_POLL_S)
            packages = self._anr_packages(serial)

    def _write_settings(self, record: BootRecord, argvs: Sequence[list[str]]) -> None:
        """Run each `settings` row; a failed row never fails the boot or the shutdown, it lands on the record."""
        for argv in argvs:
            done = self._run(argv)
            if done.status != 0:
                row = " ".join(argv[4:])
                record.setting_failures.append(f"{row} (status {done.status}: {done.stderr.strip()})")

    def _wait_gone(self, serial: str, process: subprocess.Popen[bytes]) -> None:
        """Wait, bounded, for the serial to leave `adb devices` and the emulator process to exit."""
        deadline = self._monotonic() + _GONE_WAIT_S
        listed = True
        while True:
            if listed:
                with contextlib.suppress(RoundEnvError):
                    listed = serial in self._attached()
            if not listed and process.poll() is not None:
                return
            if self._monotonic() >= deadline:
                return
            self._sleep(_POLL_S)

    def _close_anr_dialogs(self, serial: str) -> None:
        self._on(
            serial, "shell", "-n", "am", "broadcast", "-a", "android.intent.action.CLOSE_SYSTEM_DIALOGS"
        )

    def _clock_jumped(self, serial: str) -> bool:
        return clock_jumped(self._on(serial, *_RTT_ARGS).stdout)

    def _anr_packages(self, serial: str) -> tuple[str, ...]:
        return anr_window_packages(self._on(serial, "shell", "dumpsys", "window", "windows").stdout)

    def _state(self, serial: str) -> str:
        return self._on(serial, "get-state").stdout.strip() or "none"

    def _avd_name(self, serial: str) -> str | None:
        """The AVD name the serial's emulator console reports; None when the console does not answer."""
        done = self._on(serial, "emu", "avd", "name")
        names = done.stdout.splitlines()
        return names[0].strip() if done.status == 0 and names else None

    def _serial_of(self, avd: str, attached: Mapping[str, str]) -> str | None:
        for serial in attached:
            if _console_port(serial) is not None and self._avd_name(serial) == avd:
                return serial
        return None

    def _attached(self) -> dict[str, str]:
        """Every serial `adb devices` lists, with its state."""
        done = self._run([self._adb, "devices"])
        if done.status != 0:
            raise RoundEnvError(f"adb devices failed (status {done.status}): {done.stderr.strip()}")
        attached: dict[str, str] = {}
        for line in done.stdout.splitlines():
            serial, _, state = line.partition("\t")
            if serial and state:
                attached[serial] = state.strip()
        return attached

    def _on(self, serial: str, *args: str) -> Completed:
        return self._run([self._adb, "-s", serial, *args])

    def _run(self, argv: list[str]) -> Completed:
        return self._runner.run(argv, timeout_s=_ADB_TIMEOUT_S)


def _avd(target: Target) -> str:
    if target.avd is None:
        raise CatalogError(f"android target {target.name!r} names no avd in e2e/targets.toml")
    return target.avd


def _console_port(serial: str) -> int | None:
    """The console port an `emulator-<port>` serial names; None for any other serial."""
    port = serial.removeprefix(_SERIAL_PREFIX)
    return int(port) if port != serial and port.isdigit() else None
