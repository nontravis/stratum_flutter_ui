"""The e2e app's package resolve and build, once per round, and each integration plan's run with its one `env`
retry (design sections 6.5 and 6.6, C9)."""

from __future__ import annotations

from pathlib import Path
from typing import Final

from stratum_e2e.paths import E2E_ROOT
from stratum_e2e.round.capture import save_device_log
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.entry import RunPlan
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.integration_run import FileResult, env_files
from stratum_e2e.round.linux_docker import flutter_version
from stratum_e2e.round.runner import Runner
from stratum_e2e.round.state import BLOCKED, DEVICE_LOG, Backends, RoundState, RoundTarget

_BUILD_DIR: Final = "app build"
_RESOLVE_DIR: Final = "pub get"


def _resolve_app(state: RoundState, backends: Backends, target: Target) -> None:
    """Resolve the e2e app's packages before the round's first host build or run; a failure raises `RoundEnvError`.

    Once per round: a later call returns at once, and a failed resolve is tried again by the next caller.
    """
    if state.resolved:
        return
    log = state.open_round_dir(backends.now).item_dir(target.name, _RESOLVE_DIR) / "pub_get.log"
    version = _flutter_version(state, backends.runner)
    backends.resolve(state.app_dir, E2E_ROOT.parent, version, backends.runner, log)
    state.resolved = True


def app_build(state: RoundState, backends: Backends, target: Target) -> Path:
    """The e2e app build of the target's platform; the first target of a platform builds it for the rest."""
    key = (target.platform, target.wasm)
    path = state.app_builds.get(key)
    if path is None:
        _resolve_app(state, backends, target)
        round_dir = state.open_round_dir(backends.now)
        log = round_dir.item_dir(target.name, _BUILD_DIR) / "build.log"
        build = backends.build(state.app_dir, E2E_ROOT.parent, target.platform, target.wasm, backends.runner, log)
        state.recorder.build(target.name, build.argv, build.seconds, build.reused)
        path = state.app_builds[key] = build.path
    return path


def run_with_retry(
    state: RoundState, backends: Backends, round_target: RoundTarget, plan: RunPlan
) -> dict[str, FileResult]:
    name = round_target.target.name
    while not state.ledger.blocked(name):
        files = _run_once(state, backends, round_target, plan)
        if all(result.cls != "env" for result in files.values()):
            return files
        if state.ledger.record_env(name, plan.key) == "block":
            break
    return env_files(plan, BLOCKED)


def _run_once(
    state: RoundState, backends: Backends, round_target: RoundTarget, plan: RunPlan
) -> dict[str, FileResult]:
    """Run `plan` once; a launched run is recorded as a build entry (pre-flight F7) and keeps its device log."""
    target, record = round_target.target, round_target.record
    run_dir = state.open_round_dir(backends.now).item_dir(target.name, plan.key)
    for file in plan.files:
        state.run_dirs[(target.name, file)] = run_dir
    try:
        # A Linux run resolves inside its container, against the container's own paths.
        if target.platform == "linux":
            version = _flutter_version(state, backends.runner)
        else:
            version = None
            _resolve_app(state, backends, target)
    except RoundEnvError as error:
        return env_files(plan, error.reason)
    since = backends.now()
    outcome = backends.run_plan(
        plan, target, record, backends.booter_for(target), state.app_dir, run_dir, backends.runner,
        state.lane.run_timeout_minutes * 60, backends.port_dir, flutter_version=version,
    )
    if outcome.argv:
        state.recorder.build(target.name, outcome.argv, outcome.seconds, reused=False)
        save_device_log(backends.runner, record, since, run_dir / DEVICE_LOG)
    return outcome.files


def _flutter_version(state: RoundState, runner: Runner) -> str:
    """The host's Flutter version, read once per round (pre-flight F16)."""
    if state.flutter_version is None:
        state.flutter_version = flutter_version(runner)
    return state.flutter_version
