"""Bring a round target up and down: its lane, the memory gate, the boot, the TalkBack AVD check, and the low-level
options; plus the real backends of a round (design sections 6.3, 6.4, and 6.8)."""

from __future__ import annotations

import contextlib
import io
import os
import subprocess
from collections.abc import Callable, Iterator
from datetime import UTC, datetime
from pathlib import Path
from typing import Final

import pytest

from stratum_e2e.android.talkback import AVD_NAME
from stratum_e2e.round.android_boot import AndroidBooter
from stratum_e2e.round.android_host import port_directory, sdk_root
from stratum_e2e.round.app_build import ensure_app_build, resolve_app_packages
from stratum_e2e.round.boot import Booter, BootLog, BootRecord
from stratum_e2e.round.catalog import Catalog, LaneConfig, Target
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.integration_run import run_plan
from stratum_e2e.round.ios_boot import HostBooter, IosBooter
from stratum_e2e.round.items import first_line
from stratum_e2e.round.lane import (
    LaneBusy,
    Lease,
    acquire_lane,
    current_holder,
    host_memory_reasons,
    lane_dir,
    wait_for_memory,
)
from stratum_e2e.round.runner import Runner, SubprocessRunner
from stratum_e2e.round.state import BLOCKED, CATALOG_KEY, E2E_APP, Backends, RoundState, RoundTarget, e2e_app_dir

# The low-level options a round writes per target; `--app` stays the user's, since `round_app` supplies the app.
_RESOLVED: Final = ("platform", "device", "app_id")

_BOOT_KEY: Final = "boot"
_BOOT_DIR: Final = "boot"
_BOOT_LOG: Final = "boot.log"


@contextlib.contextmanager
def bring_up(state: RoundState, backends: Backends, target: Target) -> Iterator[RoundTarget]:
    """Hold the lane and the booted device of `target` while the block runs; end the device, then free the lane.

    A failed shutdown or lane release is recorded on `target` and never raised (`_tear_down`).
    """
    round_dir = state.open_round_dir(backends.now)
    past_failures = state.past_setting_failures.get(target.name, ())
    state.recorder.target(target.name, target.platform, "", reused=False, setting_failures=past_failures)
    if state.ledger.blocked(target.name):
        raise RoundEnvError(BLOCKED)
    with contextlib.ExitStack() as stack:
        stack.callback(_tear_down, state, target, "lane release", _take_lane(state, backends, target).release)
        booter = backends.booter_for(target)
        boot_dir = round_dir.item_dir(target.name, _BOOT_DIR)
        record = _boot(state, backends, booter, target, boot_dir / "boot.log", round_dir.target_dir(target.name))
        # Runs after shutdown, which adds the settings that failed to restore.
        stack.callback(_record_target, state, target, record, finished=True)
        stack.callback(_tear_down, state, target, "shutdown", booter.shutdown, record)
        _record_target(state, target, record)
        if target.avd == AVD_NAME:
            _check_talkback_avd(record.device_id)
        brought_up = _resolve(state, target, record)
        stack.callback(_restore_options, state.config, {dest: getattr(state.config.option, dest) for dest in _RESOLVED})
        _write_options(state, target, record)
        state.live[target.name] = brought_up
        stack.callback(state.live.pop, target.name, None)
        yield brought_up


def _tear_down(
    state: RoundState, target: Target, step: str, action: Callable[..., object], *args: object
) -> None:
    """Run one teardown step of `target`, recording a failure on `target` instead of raising it.

    pytest finishes a target inside the setup of the next target's first item, so a raise here would fail that item
    on a target that has run nothing.
    """
    try:
        action(*args)
    except Exception as error:
        reason = error.reason if isinstance(error, RoundEnvError) else first_line(f"{type(error).__name__}: {error}")
        state.recorder.teardown_failure(target.name, f"{step} failed: {reason}")


def _take_lane(state: RoundState, backends: Backends, target: Target) -> Lease:
    try:
        return acquire_lane(
            target.name, target.alone, state.lane.lane_wait_minutes * 60, lane_dir(), current_holder(),
            sleep=backends.sleep,
        )
    except LaneBusy as error:
        raise RoundEnvError("lane busy") from error


def _boot(
    state: RoundState, backends: Backends, booter: Booter, target: Target, log: Path, target_dir: Path
) -> BootRecord:
    """Boot `target`, passing the memory gate first on a cold boot; an `env` boot retries once, then blocks (C9).

    A booted device keeps its device log from the boot command on in `<target_dir>/boot.log`; the retry's log goes to
    `boot-2.log`, so it never replaces the failed attempt's.
    """
    attempt = 0
    while True:
        if not booter.is_running(target):
            reasons = wait_for_memory(backends.memory_reasons, state.lane.lane_wait_minutes * 60, sleep=backends.sleep)
            if reasons:
                raise RoundEnvError(f"memory pressure: {'; '.join(reasons)}")
        attempt += 1
        device_log = BootLog(target_dir / (_BOOT_LOG if attempt == 1 else f"boot-{attempt}.log"), backends.now())
        try:
            return booter.boot(target, log, device_log)
        except RoundEnvError as error:
            # `boot` ends what it booted before it raises, so the retry starts from nothing.
            if state.ledger.record_env(target.name, _BOOT_KEY) == "block":
                raise RoundEnvError(BLOCKED) from error


def _check_talkback_avd(serial: str) -> None:
    """Refuse the dedicated TalkBack AVD unless `tools.e2e_avd check` passes on it (pre-flight F12)."""
    # Imported on use: `tools/` imports this package, and only a TalkBack round needs it.
    from tools import e2e_avd

    printed = io.StringIO()
    try:
        with contextlib.redirect_stdout(printed):
            status = e2e_avd.check(serial)
    except (OSError, subprocess.SubprocessError) as error:
        raise RoundEnvError(f"tools.e2e_avd check failed on {serial}: {error}") from error
    if status != 0:
        raise RoundEnvError(f"tools.e2e_avd talkback|diagnosis: {' '.join(printed.getvalue().split())}")


def _record_target(state: RoundState, target: Target, record: BootRecord, *, finished: bool = False) -> None:
    """Record the target's device and every boot setting that failed on it so far (T4: they never fail the boot).

    `finished` closes the bring-up of `record`, so a later bring-up of the target keeps its failures.
    """
    past = state.past_setting_failures.setdefault(target.name, [])
    failures = [*past, *record.setting_failures]
    state.recorder.target(target.name, target.platform, record.device_id, record.reused, failures)
    if finished:
        past.extend(record.setting_failures)


def _resolve(state: RoundState, target: Target, record: BootRecord) -> RoundTarget:
    app_id = state.config.getoption("app_id", None) or _app_id(state.catalog, target)
    app = state.config.getoption("app", None)
    return RoundTarget(target, record, str(app_id), Path(app) if app is not None else None)


def _write_options(state: RoundState, target: Target, record: BootRecord) -> None:
    """Write the target's platform, device, and app id into the low-level options, except those given (C1)."""
    resolved = {"platform": target.platform, "device": record.device_id, "app_id": _app_id(state.catalog, target)}
    for dest, value in resolved.items():
        if dest not in state.overrides:
            setattr(state.config.option, dest, value)


def _restore_options(config: pytest.Config, previous: dict[str, object]) -> None:
    for dest, value in previous.items():
        setattr(config.option, dest, value)


def _app_id(catalog: Catalog, target: Target) -> str:
    """The e2e app's id on `target`: the Android package, else the Apple bundle id (web and linux ignore it)."""
    app = catalog.apps[E2E_APP]
    return app.android_id if target.platform == "android" else app.apple_id


def real_backends(config: pytest.Config) -> Backends:
    runner = SubprocessRunner()
    port_dir = port_directory()
    booters: dict[str, Booter] = {}

    def lane() -> LaneConfig:
        return config.stash[CATALOG_KEY].lane

    def booter_for(target: Target) -> Booter:
        booter = booters.get(target.platform)
        if booter is None:
            booter = booters[target.platform] = _platform_booter(target.platform, runner, config, port_dir)
        return booter

    return Backends(
        runner=runner,
        booter_for=booter_for,
        resolve=resolve_app_packages,
        build=ensure_app_build,
        run_plan=run_plan,
        memory_reasons=lambda: host_memory_reasons(runner, lane()),
        now=lambda: datetime.now(UTC),
        port_dir=port_dir,
    )


def _platform_booter(platform: str, runner: Runner, config: pytest.Config, port_dir: Path) -> Booter:
    catalog = config.stash[CATALOG_KEY]
    if platform == "android":
        # Imported on use: `tools/` imports this package.
        from tools import e2e_avd

        sdk = sdk_root(e2e_app_dir(catalog), os.environ, Path.home())
        return AndroidBooter(runner, sdk, catalog.lane, e2e_avd.avd_home(), port_dir)
    if platform == "ios":
        return IosBooter(runner, catalog.lane)
    return HostBooter()
