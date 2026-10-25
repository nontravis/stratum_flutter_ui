"""Resolve the iOS runtime and device as one pair, boot and reuse simulators, and boot nothing on a host platform.

Ported from the skill's `platforms/ios.sh` (`simctl_resolve`, `p_boot`, `p_kill`). The booter ends only a simulator it
booted itself: one found `Booted` is reused and left running, with its keyboard preference pinned.
"""

from __future__ import annotations

import contextlib
import json
import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path

from stratum_e2e.round.boot import Booter, BootLog, BootRecord
from stratum_e2e.round.capture import keep_boot_log
from stratum_e2e.round.catalog import LaneConfig, Target
from stratum_e2e.round.errors import CatalogError, RoundEnvError
from stratum_e2e.round.runner import Completed, Runner

_PLATFORM = "ios"
_HOST_PLATFORMS = ("macos", "web", "linux")
_BOOTED = "Booted"
_ALREADY_BOOTED = "Unable to boot device in current state: Booted"
_ALREADY_SHUTDOWN = "Unable to shutdown device in current state: Shutdown"
_KEYBOARD_DOMAIN = "com.apple.keyboard.preferences"
_MINIMIZATION_KEY = "AutomaticMinimizationEnabled"
_DEFAULTS_FALSE = "0"
_QUERY_TIMEOUT_S = 60.0


class PairError(RoundEnvError):
    """No available iOS runtime holds an available device of the requested name."""


@dataclass(frozen=True)
class IosPair:
    """One iOS runtime and the simulator of a named device under it, as `simctl list` reported them."""

    runtime_id: str
    runtime_name: str
    udid: str
    state: str


def resolve_pair(simctl_list: Mapping[str, object], device: str, runtime: str | None) -> IosPair:
    """The newest available iOS runtime that holds an available device named `device`, with that device.

    A `runtime` name limits the search to that runtime. Raises `PairError` naming the device and the runtime (or
    that any runtime was allowed) when no pair fits, or when the listing has no shape this can read.
    """
    scope = f"runtime {runtime!r}" if runtime is not None else "any available iOS runtime"
    failure = PairError(f"no available device {device!r} under {scope}")
    try:
        runtimes = _ios_runtimes(simctl_list, runtime)
        listed = simctl_list["devices"]
        if not isinstance(listed, Mapping):
            raise failure
        for candidate in sorted(runtimes, key=_version_key, reverse=True):
            found = _available_device(listed.get(str(candidate["identifier"])), device)
            if found is not None:
                return IosPair(
                    runtime_id=str(candidate["identifier"]),
                    runtime_name=str(candidate["name"]),
                    udid=str(found["udid"]),
                    state=str(found.get("state", "")),
                )
    except (KeyError, TypeError, ValueError) as error:
        raise failure from error
    raise failure


def _ios_runtimes(simctl_list: Mapping[str, object], pinned: str | None) -> list[Mapping[str, object]]:
    listed = simctl_list["runtimes"]
    if not isinstance(listed, list):
        raise TypeError("runtimes is not a list")
    return [
        entry
        for entry in listed
        if isinstance(entry, Mapping)
        and entry.get("isAvailable") is True
        and "iOS" in str(entry["identifier"])
        and (pinned is None or entry.get("name") == pinned)
    ]


def _version_key(runtime: Mapping[str, object]) -> tuple[int, ...]:
    return tuple(int(part) for part in str(runtime.get("version", "0")).split(".") if part.isdigit())


def _available_device(devices: object, name: str) -> Mapping[str, object] | None:
    if not isinstance(devices, list):
        return None
    for entry in devices:
        if isinstance(entry, Mapping) and entry.get("name") == name and entry.get("isAvailable", True) is True:
            return entry
    return None


class IosBooter(Booter):
    """Boots each target's simulator, pins its soft keyboard to show, and ends only the ones it booted.

    The pin is a device preference written through `simctl spawn`; the round writes no host setting for the keyboard.
    A headless boot attaches the simulator's virtual hardware keyboard whatever the host's `ConnectHardwareKeyboard`
    says, and `AutomaticMinimizationEnabled` = true then shows the soft keyboard minimized at 0 pt. A file that needs
    the minimized state must set the preference itself. A simulator found `Booted` is left running, with that
    preference pinned.
    """

    def __init__(
        self,
        runner: Runner,
        lane: LaneConfig,
        *,
        monotonic: Callable[[], float] = time.monotonic,
    ) -> None:
        self._runner = runner
        self._lane = lane
        self._monotonic = monotonic
        # The UDIDs this booter booted: the one place `shutdown` learns that a simulator is ours to end.
        self._booted: set[str] = set()
        # Boots begun per log file, so a retry's lines in the shared `boot.log` are told from attempt 1's.
        self._attempts: dict[Path, int] = {}

    def is_running(self, target: Target) -> bool:
        """Whether the simulator of `target`'s pair is `Booted`, so `boot` reuses it and the memory gate is skipped."""
        return self._pair(target).state == _BOOTED

    def boot(self, target: Target, log: Path, device_log: BootLog | None = None) -> BootRecord:
        """Reuse a `Booted` simulator, else boot it and wait for `bootstatus`; then pin the soft keyboard either way.

        A reused simulator is left running, with only its keyboard preference changed. A simulator this call booted
        saves its simulator log to `device_log` once booted; a failed boot saves none, since `simctl spawn` cannot
        read a simulator that is not up.

        Appends each attempt's `simctl boot` stderr, `bootstatus` output, pin read-back, and error to `log`. One
        deadline of `boot_timeout_minutes` covers `simctl boot` and `bootstatus`. Any failure or interrupt of
        `simctl boot`, and once it has succeeded any failure or interrupt, shuts the simulator down: a boot that
        failed can leave a half-started simulator that a retry would only hang on.
        """
        attempt = self._attempts.get(log, 0) + 1
        self._attempts[log] = attempt
        _note(log, f"boot attempt {attempt}: {target.name}")
        try:
            return self._boot(target, log, device_log)
        except BaseException as error:
            _note(log, f"boot attempt {attempt} failed: {error!r}")
            raise

    def _boot(self, target: Target, log: Path, device_log: BootLog | None) -> BootRecord:
        pair = self._pair(target)
        if pair.state == _BOOTED:
            self._pin_soft_keyboard(pair.udid, log)
            return BootRecord(target=target.name, platform=_PLATFORM, device_id=pair.udid, reused=True)
        limit = self._lane.boot_timeout_minutes * 60
        deadline = self._monotonic() + limit
        try:
            started = self._simctl("boot", pair.udid, timeout_s=limit)
        except BaseException:
            # A killed `simctl` client can leave the simulator booting, as on the failure path below.
            self._end_quietly(pair.udid)
            raise
        _note(
            log,
            f"simctl boot: status {started.status}, stdout {started.stdout.strip()!r}, "
            f"stderr {started.stderr.strip()!r}",
        )
        # Another session booting the same simulator since the listing is a reuse, not a failure.
        reused = _ALREADY_BOOTED in started.stderr + started.stdout
        if started.status != 0 and not reused:
            self._end_quietly(pair.udid)
            raise RoundEnvError(f"simctl boot {pair.udid} failed (status {started.status}): {started.stderr.strip()}")
        if not reused:
            self._booted.add(pair.udid)
        try:
            self._wait_booted(target, pair, limit, deadline, log)
            self._pin_soft_keyboard(pair.udid, log)
        except BaseException:
            if not reused:
                self._end_quietly(pair.udid)
            raise
        record = BootRecord(target=target.name, platform=_PLATFORM, device_id=pair.udid, reused=reused)
        if not reused:
            keep_boot_log(self._runner, record, device_log)
        return record

    def before_file(self, record: BootRecord) -> None:
        """Nothing to ready: a booted simulator needs no per-file check."""

    def shutdown(self, record: BootRecord) -> None:
        """Run `simctl shutdown` for a simulator this booter booted and has not ended; any other record is left as found.

        Raises `RoundEnvError` when `simctl shutdown` fails for any reason but the simulator already being shut down.
        """
        if record.reused or record.device_id not in self._booted:
            return
        self._end(record.device_id)

    def _wait_booted(self, target: Target, pair: IosPair, limit: int, deadline: float, log: Path) -> None:
        name = f"{target.device} ({pair.udid})"
        remaining = deadline - self._monotonic()
        if remaining <= 0:
            raise RoundEnvError(f"{name} did not finish booting within {limit} s")
        waited = self._simctl("bootstatus", pair.udid, "-b", timeout_s=remaining)
        printed = (waited.stdout + waited.stderr).strip()
        _note(log, f"simctl bootstatus: status {waited.status}, output {printed!r}")
        if waited.timed_out:
            raise RoundEnvError(f"{name} did not finish booting within {limit} s")
        if waited.status != 0:
            raise RoundEnvError(f"{name} bootstatus failed (status {waited.status}): {waited.stderr.strip()}")

    def _pair(self, target: Target) -> IosPair:
        if target.device is None:
            raise CatalogError(f"ios target {target.name!r} names no device in e2e/targets.toml")
        listed = self._simctl("list", "-j", timeout_s=_QUERY_TIMEOUT_S)
        if listed.status != 0:
            raise RoundEnvError(f"simctl list failed (status {listed.status}): {listed.stderr.strip()}")
        try:
            parsed = json.loads(listed.stdout)
        except json.JSONDecodeError as error:
            raise RoundEnvError(f"simctl list -j printed no JSON: {error}") from error
        if not isinstance(parsed, dict):
            raise RoundEnvError("simctl list -j printed no JSON object")
        return resolve_pair(parsed, target.device, target.runtime)

    def _pin_soft_keyboard(self, udid: str, log: Path) -> None:
        """Set the device's `AutomaticMinimizationEnabled` to false, read it back, and write the value to `log`.

        Raises `RoundEnvError` when the write or the read fails or the read-back is not false; the soft keyboard
        that `keyboard_visibility_scope_mobile_test.dart` asserts would otherwise open at 0 pt.
        """
        written = self._device_defaults(udid, "write", _MINIMIZATION_KEY, "-bool", "false")
        read = self._device_defaults(udid, "read", _MINIMIZATION_KEY)
        value = read.stdout.strip()
        _note(log, f"{_KEYBOARD_DOMAIN} {_MINIMIZATION_KEY} read back: {value!r}")
        if written.status != 0 or read.status != 0 or value != _DEFAULTS_FALSE:
            raise RoundEnvError(
                f"{udid}: {_KEYBOARD_DOMAIN} {_MINIMIZATION_KEY} did not pin to false "
                f"(write status {written.status}, read status {read.status}, read back {value!r})"
            )

    def _device_defaults(self, udid: str, verb: str, *args: str) -> Completed:
        return self._simctl("spawn", udid, "defaults", verb, _KEYBOARD_DOMAIN, *args, timeout_s=_QUERY_TIMEOUT_S)

    def _end(self, udid: str) -> None:
        """Forget `udid` as ours, then `simctl shutdown` it; a simulator already shut down is not an error."""
        self._booted.discard(udid)
        done = self._simctl("shutdown", udid, timeout_s=_QUERY_TIMEOUT_S)
        if done.status != 0 and _ALREADY_SHUTDOWN not in done.stderr + done.stdout:
            raise RoundEnvError(f"simctl shutdown {udid} failed (status {done.status}): {done.stderr.strip()}")

    def _end_quietly(self, udid: str) -> None:
        """End `udid` on a failure path, where the error being raised matters more than a failed shutdown."""
        with contextlib.suppress(RoundEnvError):
            self._end(udid)

    def _simctl(self, *args: str, timeout_s: float) -> Completed:
        return self._run(["xcrun", "simctl", *args], timeout_s=timeout_s)

    def _run(self, argv: list[str], *, timeout_s: float = _QUERY_TIMEOUT_S) -> Completed:
        return self._runner.run(argv, timeout_s=timeout_s)


def _note(log: Path, line: str) -> None:
    """Append `line` to `log`, creating the file and its folder when absent."""
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("a", encoding="utf-8") as sink:
        sink.write(line + "\n")


class HostBooter(Booter):
    """Stands in for the platforms that run on the host: there is nothing to boot, ready, or end."""

    def is_running(self, target: Target) -> bool:
        """Always true: the host is already there, so the memory gate is skipped."""
        _require_host(target)
        return True

    def boot(self, target: Target, log: Path, device_log: BootLog | None = None) -> BootRecord:
        """Record the target by name, which is today's `--device` value (`mac`, `chrome`, `chrome_wasm`, `linux`)."""
        _require_host(target)
        return BootRecord(target=target.name, platform=target.platform, device_id=target.name, reused=True)

    def before_file(self, record: BootRecord) -> None:
        """Nothing to ready."""

    def shutdown(self, record: BootRecord) -> None:
        """Nothing to end."""


def _require_host(target: Target) -> None:
    if target.platform not in _HOST_PLATFORMS:
        raise CatalogError(f"target {target.name!r} is a {target.platform!r} target, not a host platform")
