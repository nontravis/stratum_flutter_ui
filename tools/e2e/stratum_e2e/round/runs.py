"""The e2e app's package resolve and build, once per round, and each integration plan's run with its one `env`
retry (design sections 6.5 and 6.6, C9)."""

from __future__ import annotations

from pathlib import Path
from typing import Final

from stratum_e2e.paths import REPO_ROOT
from stratum_e2e.round.app_build import AppBuild
from stratum_e2e.round.capture import save_device_log
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.entry import RunPlan
from stratum_e2e.round.errors import BuildFailure, RoundEnvError
from stratum_e2e.round.integration_run import FileResult, Launch, env_files
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
    backends.resolve(state.app_dir, REPO_ROOT, version, backends.runner, log)
    state.resolved = True


def app_build(state: RoundState, backends: Backends, target: Target) -> Path:
    """The e2e app build of the target's platform; the first target of a platform builds it for the rest.

    A failed build (`BuildFailure`) gets one plain rebuild. A second failure is kept and raised again for the
    platform's later items, since the sources do not change within a round; it reads `build`, so it never reaches the
    retry ledger. Every build command, a failed one too, lands in the summary's builds.
    """
    key = (target.platform, target.wasm)
    failure = state.build_failures.get(key)
    if failure is not None:
        raise failure
    path = state.app_builds.get(key)
    if path is None:
        _resolve_app(state, backends, target)
        round_dir = state.open_round_dir(backends.now)
        log = round_dir.item_dir(target.name, _BUILD_DIR) / "build.log"
        try:
            build = _build_once_more_on_failure(state, backends, target, log)
        except BuildFailure as failed:
            state.build_failures[key] = failed
            raise
        state.recorder.build(target.name, build.argv, build.seconds, build.reused)
        path = state.app_builds[key] = build.path
    return path


def _build_once_more_on_failure(state: RoundState, backends: Backends, target: Target, log: Path) -> AppBuild:
    """Build the target's platform; after a `BuildFailure`, recorded as a build, build once more with no clean."""
    try:
        return backends.build(state.app_dir, REPO_ROOT, target.platform, target.wasm, backends.runner, log)
    except BuildFailure as failed:
        state.recorder.build(target.name, failed.argv, failed.seconds, reused=False, ok=False)
    try:
        return backends.build(state.app_dir, REPO_ROOT, target.platform, target.wasm, backends.runner, log)
    except BuildFailure as failed:
        state.recorder.build(target.name, failed.argv, failed.seconds, reused=False, ok=False)
        raise


def run_with_retry(
    state: RoundState, backends: Backends, round_target: RoundTarget, plan: RunPlan
) -> dict[str, FileResult]:
    """Run `plan` until its files hold no `env`, each `env` run recorded in the retry ledger until it blocks the
    target. A run whose every file reads `build` runs once more, plainly and with no ledger record; that second
    result sticks (design section 10)."""
    name = round_target.target.name
    rebuilt = False
    while not state.ledger.blocked(name):
        files = _run_once(state, backends, round_target, plan)
        if not rebuilt and _built_nothing(files):
            rebuilt = True
            continue
        if all(result.cls != "env" for result in files.values()):
            return files
        if state.ledger.record_env(name, plan.key) == "block":
            break
    return env_files(plan, BLOCKED)


def _run_once(
    state: RoundState, backends: Backends, round_target: RoundTarget, plan: RunPlan
) -> dict[str, FileResult]:
    """Run `plan` once; a launched run is recorded as a build entry (pre-flight F7) and keeps its device log.

    A Linux target builds its app in its own step before its first run of the round, and again after a build or a
    launch that failed: the container wipes its native build dir after any failed exit, so the next native build must
    go through the step, where its failure is classed. The build is recorded as a build entry too. A run of several
    launches (a Linux sequence) records one build entry per launch, each with its own command and seconds.
    """
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
        build_first=target.platform == "linux" and target.name not in state.linux_built,
    )
    if outcome.build_argv:
        state.recorder.build(target.name, outcome.build_argv, outcome.build_seconds, reused=False,
                             ok=not outcome.build_failed)
        if not outcome.build_failed:
            state.linux_built.add(target.name)
    if outcome.exit_status not in (None, 0):
        state.linux_built.discard(target.name)
    if outcome.argv:
        for launch in outcome.launches or (Launch(outcome.argv, outcome.seconds, not _built_nothing(outcome.files)),):
            state.recorder.build(target.name, launch.argv, launch.seconds, reused=False, ok=launch.ok)
        save_device_log(backends.runner, record, since, run_dir / DEVICE_LOG)
    return outcome.files


def _built_nothing(files: dict[str, FileResult]) -> bool:
    """Whether a run's every file reads `build`: the app was not built, or none of its tests started."""
    return all(result.cls == "build" for result in files.values())


def _flutter_version(state: RoundState, runner: Runner) -> str:
    """The host's Flutter version, read once per round (pre-flight F16)."""
    if state.flutter_version is None:
        state.flutter_version = flutter_version(runner)
    return state.flutter_version
