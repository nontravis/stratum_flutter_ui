"""Resolve the iOS runtime and device as one pair, boot and reuse simulators, and boot nothing on a host platform.

Ported from the skill's `platforms/ios.sh` (`simctl_resolve`, `ios_pin_hardware_keyboard`, `p_boot`, `p_kill`). The
booter ends only a simulator it booted itself: one found `Booted` is reused as found and left running.
"""

from __future__ import annotations

import contextlib
import json
import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path

from stratum_e2e.round.boot import Booter, BootRecord
from stratum_e2e.round.catalog import LaneConfig, Target
from stratum_e2e.round.errors import CatalogError, RoundEnvError
from stratum_e2e.round.runner import Completed, Runner

_PLATFORM = "ios"
_HOST_PLATFORMS = ("macos", "web", "linux")
_BOOTED = "Booted"
_ALREADY_BOOTED = "Unable to boot device in current state: Booted"
_ALREADY_SHUTDOWN = "Unable to shutdown device in current state: Shutdown"
_SIMULATOR_DOMAIN = "com.apple.iphonesimulator"
_KEYBOARD_KEY = "ConnectHardwareKeyboard"
_PLISTBUDDY = "/usr/libexec/PlistBuddy"
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
    """Boots each target's simulator with Connect Hardware Keyboard pinned off, and ends only the ones it booted."""

    def __init__(
        self,
        runner: Runner,
        lane: LaneConfig,
        home: Path,
        *,
        monotonic: Callable[[], float] = time.monotonic,
    ) -> None:
        self._runner = runner
        self._lane = lane
        self._plist = home / "Library" / "Preferences" / f"{_SIMULATOR_DOMAIN}.plist"
        self._monotonic = monotonic
        # The UDIDs this booter booted: the one place `shutdown` learns that a simulator is ours to end.
        self._booted: set[str] = set()

    def is_running(self, target: Target) -> bool:
        """Whether the simulator of `target`'s pair is `Booted`, so `boot` reuses it and the memory gate is skipped."""
        return self._pair(target).state == _BOOTED

    def boot(self, target: Target, log: Path) -> BootRecord:
        """Reuse a `Booted` simulator as found, else pin the keyboard key, boot it, and wait for `bootstatus`.

        `log` is unused: `simctl` keeps its own logs. One deadline of `boot_timeout_minutes` covers `simctl boot`
        and `bootstatus`. An interrupt or timeout of `simctl boot`, and once it has succeeded any failure or interrupt,
        shuts the simulator down.
        """
        pair = self._pair(target)
        if pair.state == _BOOTED:
            return BootRecord(target=target.name, platform=_PLATFORM, device_id=pair.udid, reused=True)
        self._pin_hardware_keyboard(pair.udid)
        limit = self._lane.boot_timeout_minutes * 60
        deadline = self._monotonic() + limit
        try:
            started = self._simctl("boot", pair.udid, timeout_s=limit)
        except BaseException:
            # A killed `simctl` client can leave the simulator booting, as on the timeout path below.
            self._end_quietly(pair.udid)
            raise
        # Another session booting the same simulator since the listing is a reuse, not a failure.
        reused = _ALREADY_BOOTED in started.stderr + started.stdout
        if started.status != 0 and not reused:
            if started.timed_out:
                self._end_quietly(pair.udid)
            raise RoundEnvError(f"simctl boot {pair.udid} failed (status {started.status}): {started.stderr.strip()}")
        if not reused:
            self._booted.add(pair.udid)
        try:
            self._wait_booted(target, pair, limit, deadline)
        except BaseException:
            if not reused:
                self._end_quietly(pair.udid)
            raise
        return BootRecord(target=target.name, platform=_PLATFORM, device_id=pair.udid, reused=reused)

    def before_file(self, record: BootRecord) -> None:
        """Nothing to ready: a booted simulator needs no per-file check."""

    def shutdown(self, record: BootRecord) -> None:
        """Run `simctl shutdown` for a simulator this booter booted and has not ended; any other record is left as found.

        Raises `RoundEnvError` when `simctl shutdown` fails for any reason but the simulator already being shut down.
        """
        if record.reused or record.device_id not in self._booted:
            return
        self._end(record.device_id)

    def _wait_booted(self, target: Target, pair: IosPair, limit: int, deadline: float) -> None:
        name = f"{target.device} ({pair.udid})"
        remaining = deadline - self._monotonic()
        if remaining <= 0:
            raise RoundEnvError(f"{name} did not finish booting within {limit} s")
        waited = self._simctl("bootstatus", pair.udid, "-b", timeout_s=remaining)
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

    def _pin_hardware_keyboard(self, udid: str) -> None:
        """Turn Connect Hardware Keyboard off globally and, when the device has its own dict, in that dict.

        A leaked "on" hides the OS keyboard that `keyboard_visibility_scope_mobile_test.dart` asserts. PlistBuddy edits only
        the one nested key, so the device's saved window geometry survives. A failed write fails the boot.
        """
        written = self._run(["defaults", "write", _SIMULATOR_DOMAIN, _KEYBOARD_KEY, "-bool", "false"])
        if written.status != 0 or not self._pin_device_key(udid):
            raise RoundEnvError(f"{udid}: failed to pin Connect Hardware Keyboard off before boot")

    def _pin_device_key(self, udid: str) -> bool:
        dict_key = f":DevicePreferences:{udid}"
        if self._plistbuddy(f"Print {dict_key}").status != 0:
            return True  # a device that never booted has no per-device dict, so the global key alone applies
        key = f"{dict_key}:{_KEYBOARD_KEY}"
        return self._plistbuddy(f"Set {key} false").status == 0 or self._plistbuddy(f"Add {key} bool false").status == 0

    def _plistbuddy(self, command: str) -> Completed:
        return self._run([_PLISTBUDDY, "-c", command, str(self._plist)])

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


class HostBooter(Booter):
    """Stands in for the platforms that run on the host: there is nothing to boot, ready, or end."""

    def is_running(self, target: Target) -> bool:
        """Always true: the host is already there, so the memory gate is skipped."""
        _require_host(target)
        return True

    def boot(self, target: Target, log: Path) -> BootRecord:
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
