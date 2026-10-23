"""The pytest side of a device round: options, per-target collection, the per-target fixtures, and the hooks that
retry, capture, and record items (design sections 6, 7, 10).

A round starts when `--target`, `--mode`, or `--repeat` is given. Without any of them the plugin is inert: it loads no
catalog, parametrizes nothing, leaves collection to the low-level `--platform` path, and its fixtures read the four
low-level options as before. In a round every item under `tests/` is parametrized by `round_target`, the integration
items by `integration_file` as well, and the pairs a target does not run are deselected. Items run target by target:
`round_target` takes the target's lane and boots it before its first item, and pytest tears it down (shutdown, then
lane release) before the next target's first item. The round dir is written when the session ends, after a SIGTERM
too.
"""

from __future__ import annotations

import contextlib
import io
import os
import signal
import subprocess
import time
from collections.abc import Callable, Generator, Iterator, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from types import FrameType
from typing import Final, NoReturn

import pytest
from _pytest.runner import runtestprotocol

from stratum_e2e.android.talkback import AVD_NAME
from stratum_e2e.paths import E2E_ROOT
from stratum_e2e.round.android_boot import AndroidBooter
from stratum_e2e.round.android_host import port_directory, sdk_root
from stratum_e2e.round.app_build import AppBuild, build_argv, ensure_app_build
from stratum_e2e.round.boot import Booter, BootRecord
from stratum_e2e.round.capture import save_device_log, save_screenshot
from stratum_e2e.round.catalog import (
    TARGETS_TOML,
    Catalog,
    LaneConfig,
    RoundPlan,
    Target,
    load_catalog,
    resolve_round,
)
from stratum_e2e.round.entry import RunPlan, plan_runs, platform_files
from stratum_e2e.round.errors import CatalogError, RoundEnvError
from stratum_e2e.round.integration_run import LOG_NAME, FileResult, RunOutcome, run_plan
from stratum_e2e.round.ios_boot import HostBooter, IosBooter
from stratum_e2e.round.lane import (
    LaneBusy,
    Lease,
    acquire_lane,
    current_holder,
    host_memory_reasons,
    lane_dir,
    wait_for_memory,
)
from stratum_e2e.round.linux_docker import flutter_version
from stratum_e2e.round.results import Cell, ItemKind, Recorder, RetryLedger, RoundDir, rounds_root
from stratum_e2e.round.runner import Runner, SubprocessRunner
from stratum_e2e.selection import PLATFORMS, runs_e2e

ROUND_KEY: Final = pytest.StashKey[RoundPlan | None]()
CATALOG_KEY: Final = pytest.StashKey[Catalog]()
RUNS_KEY: Final = pytest.StashKey[dict[str, list[RunPlan]]]()

TESTS_DIR: Final = E2E_ROOT / "tests"
E2E_APP: Final = "test_app"
INTEGRATION_FOLDER: Final = "integration_test"

# (option flag, argparse dest) of the low-level options a round resolves per target (design call 1).
_LOW_LEVEL: Final = (("--platform", "platform"), ("--device", "device"), ("--app", "app"), ("--app-id", "app_id"))
# The low-level options a round writes per target; `--app` stays the user's, since `round_app` supplies the app.
_RESOLVED: Final = ("platform", "device", "app_id")

_BOOT_KEY: Final = "boot"
_BOOT_DIR: Final = "boot"
_BUILD_DIR: Final = "app build"
_ITEM_LOG: Final = "pytest.log"
_DEVICE_LOG: Final = "device.log"
_SCREENSHOT: Final = "screenshot.png"
_BLOCKED: Final = "target blocked"
_CLASS_PROPERTY: Final = "round_class"
_REASON_PROPERTY: Final = "round_reason"
_REASON_CHARS: Final = 300

_Handler = Callable[[int, FrameType | None], object] | int | None


@dataclass(frozen=True)
class RoundTarget:
    """A target its round brought up: the booted device, the app id the items use, and the `--app` override, if any."""

    target: Target
    record: BootRecord
    app_id: str
    app_path: Path | None


@dataclass
class Backends:
    """Everything a round does to the host, so a unit test swaps all of it for fakes by overriding `round_backends`.

    `booter_for` hands back one booter per platform for the whole round: the instance that boots a target is the one
    that ends it. `port_dir` holds the port reservations of the Android console and chromedriver (pre-flight F18).
    `sleep` paces the lane and memory-gate polls.
    """

    runner: Runner
    booter_for: Callable[[Target], Booter]
    build: Callable[..., AppBuild]
    run_plan: Callable[..., RunOutcome]
    memory_reasons: Callable[[], list[str]]
    now: Callable[[], datetime]
    port_dir: Path
    sleep: Callable[[float], None] = time.sleep


@dataclass(frozen=True)
class _Result:
    kind: ItemKind
    stories: tuple[str, ...]
    cell: Cell


class _RoundState:
    """What one round keeps between its fixtures and hooks: recorder, retry ledger, round dir, and per-target caches."""

    def __init__(
        self, config: pytest.Config, plan: RoundPlan, catalog: Catalog, runs: dict[str, list[RunPlan]]
    ) -> None:
        self.config = config
        self.plan = plan
        self.catalog = catalog
        self.runs = runs
        self.overrides = {dest for _, dest in _LOW_LEVEL if config.getoption(dest, None) is not None}
        self.recorder = Recorder()
        self.ledger = RetryLedger()
        self.started = time.monotonic()
        self.round_dir: RoundDir | None = None
        self.backends: Backends | None = None
        # Targets whose `round_target` failed: every item of theirs fails alike, so none is retried.
        self.down: set[str] = set()
        self.live: dict[str, RoundTarget] = {}
        self.app_builds: dict[tuple[str, bool], Path] = {}
        self.outcomes: dict[str, dict[str, FileResult]] = {}
        self.run_dirs: dict[tuple[str, str], Path] = {}
        self.flutter_version: str | None = None
        # test -> target -> result; written to the recorder at session end, when every target's stories are known.
        self.results: dict[str, dict[str, _Result]] = {}

    @property
    def lane(self) -> LaneConfig:
        return self.catalog.lane

    @property
    def app_dir(self) -> Path:
        return _app_dir(self.catalog)

    def open_round_dir(self, now: Callable[[], datetime]) -> RoundDir:
        """The round dir, created on first use, so a round that runs no item leaves none behind."""
        if self.round_dir is None:
            self.round_dir = RoundDir.create(rounds_root(), now())
        return self.round_dir

    def relative(self, path: Path) -> str:
        """`path` relative to the round dir, as a summary cell names a log; empty when the file is absent."""
        if self.round_dir is None or not path.is_file():
            return ""
        return path.relative_to(self.round_dir.path).as_posix()

    def record(self, target: str, test: str, kind: ItemKind, stories: Sequence[str], cell: Cell) -> None:
        """Keep one test's result on one target; a re-run replaces it."""
        self.results.setdefault(test, {})[target] = _Result(kind, tuple(stories), cell)

    def write(self) -> None:
        """Hand every result to the recorder, each row naming the stories of every target, then write the round dir."""
        if self.round_dir is None:
            return
        for test, by_target in self.results.items():
            stories = tuple(dict.fromkeys(story for result in by_target.values() for story in result.stories))
            for target, result in by_target.items():
                self.recorder.add(target, test, result.kind, stories, result.cell)
        self.recorder.write(self.round_dir, self.plan.mode, self.plan.repeat, time.monotonic() - self.started)


_STATE_KEY: Final = pytest.StashKey[_RoundState]()
_SIGTERM_KEY: Final = pytest.StashKey[_Handler]()
_SINCE_KEY: Final = pytest.StashKey[datetime]()
_STOPPED_KEY: Final = pytest.StashKey[bool]()


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("stratum-e2e-round")
    group.addoption(
        "--target",
        default=None,
        metavar="NAMES",
        help="Run a device round on these comma-separated e2e/targets.toml targets.",
    )
    group.addoption(
        "--mode",
        default=None,
        metavar="MODE",
        help="Run a device round on the targets of a mode of e2e/targets.toml: fast or full.",
    )
    group.addoption(
        "--repeat",
        type=int,
        default=None,
        metavar="N",
        help="Run each marked repeat block N times, replacing the mode's count.",
    )


def pytest_configure(config: pytest.Config) -> None:
    """Resolve the round and plan its integration runs; stay inert when no round option is given.

    In a round, SIGTERM raises `KeyboardInterrupt`, so a watch-lane stop still tears every target down and writes the
    round dir.
    """
    config.stash[ROUND_KEY] = None
    target_arg, mode_arg, repeat_arg = (config.getoption(name) for name in ("target", "mode", "repeat"))
    if target_arg is None and mode_arg is None and repeat_arg is None:
        return
    try:
        catalog = load_catalog(TARGETS_TOML)
        round_plan = resolve_round(catalog, target_arg, mode_arg, repeat_arg)
        if round_plan is None:
            return
        _reject_cross_platform_overrides(config, round_plan)
        runs = _plan_integration(catalog, round_plan, _integration_dir(catalog))
    except CatalogError as error:
        raise pytest.UsageError(str(error)) from error
    config.stash[ROUND_KEY] = round_plan
    config.stash[CATALOG_KEY] = catalog
    config.stash[RUNS_KEY] = runs
    config.stash[_STATE_KEY] = _RoundState(config, round_plan, catalog, runs)
    config.stash[_SIGTERM_KEY] = signal.signal(signal.SIGTERM, _interrupt)


def pytest_unconfigure(config: pytest.Config) -> None:
    """Give SIGTERM back the handler it had before the round."""
    if _SIGTERM_KEY in config.stash:
        signal.signal(signal.SIGTERM, config.stash[_SIGTERM_KEY])


def _interrupt(signum: int, frame: FrameType | None) -> NoReturn:
    raise KeyboardInterrupt(f"signal {signum}")


@pytest.fixture(scope="session")
def round_backends(request: pytest.FixtureRequest) -> Backends:
    """The real backends: subprocesses, one booter per platform, the app build, the integration run, the host memory
    gate, and the UTC clock. A unit test overrides this fixture in a conftest."""
    return _real_backends(request.config)


@pytest.fixture(scope="session")
def round_recorder(request: pytest.FixtureRequest) -> Recorder:
    """The round's recorder; outside a round, a recorder nothing writes."""
    state = request.config.stash.get(_STATE_KEY, None)
    return state.recorder if state is not None else Recorder()


@pytest.fixture(scope="session")
def round_target(request: pytest.FixtureRequest) -> Iterator[RoundTarget | None]:
    """The target a parametrized item runs on, brought up for its items; `None` where no round parametrizes it.

    One instance per target, torn down before the next target's: the lane is taken, the device booted (the memory
    gate first, on a cold boot only), the TalkBack AVD checked, and the target's platform, device, and app id written
    into the low-level options unless given on the command line. Teardown ends what was booted, then frees the lane.
    Any step that fails raises `RoundEnvError`, which pytest keeps for every item of the target, so the round moves on.
    """
    param: object = getattr(request, "param", None)
    if param is None:
        yield None
        return
    if not isinstance(param, Target):
        raise TypeError(f"round_target is parametrized with {type(param).__name__}, not a Target")
    state = request.config.stash[_STATE_KEY]
    backends: Backends = request.getfixturevalue("round_backends")
    state.backends = backends
    try:
        with _brought_up(state, backends, param) as brought_up:
            yield brought_up
    except RoundEnvError:
        state.down.add(param.name)
        raise


@pytest.fixture
def round_app(request: pytest.FixtureRequest, round_target: RoundTarget | None) -> Path:
    """The app under test: `--app` when given, else the e2e app build of the target's platform, built once per round.

    Function-scoped, so pytest never keeps a failed build: the round keeps each finished build, and the re-run of an
    item whose build failed builds again (C9).
    """
    if round_target is None:
        app = request.config.getoption("app", None)
        if app is None:
            pytest.fail("--app is required for this test", pytrace=False)
        return Path(app)
    if round_target.app_path is not None:
        return round_target.app_path
    state = request.config.stash[_STATE_KEY]
    return _app_build(state, request.getfixturevalue("round_backends"), round_target.target)


@pytest.fixture(scope="session")
def integration_outcomes(request: pytest.FixtureRequest, round_target: RoundTarget | None) -> dict[str, FileResult]:
    """Each integration file's result on the target, from one run of each of its plans; empty outside a round.

    An `env` run reruns once per (target, plan key); a second `env` marks its files `env: target blocked`, blocks the
    target, and the target's later plans never launch (C9).
    """
    if round_target is None:
        return {}
    state = request.config.stash[_STATE_KEY]
    backends: Backends = request.getfixturevalue("round_backends")
    results: dict[str, FileResult] = {}
    for plan in state.runs.get(round_target.target.name, []):
        results |= _run_with_retry(state, backends, round_target, plan)
    state.outcomes[round_target.target.name] = results
    return results


@pytest.hookimpl(wrapper=True)
def pytest_pycollect_makeitem(
    collector: pytest.Module | pytest.Class, name: str, obj: object
) -> Generator[None, object, object]:
    """In a round, make every test function under `tests/` use `round_target` (pre-flight F1).

    So an item that names no device fixture (the perf item) still runs on its target, and `pytest_generate_tests`
    may parametrize the fixture. Outside a round nothing is marked, so the legacy path stays as it was.
    """
    if collector.config.stash.get(ROUND_KEY, None) is not None and _under_tests(collector.path):
        if collector.istestfunction(obj, name):
            pytest.mark.usefixtures("round_target")(obj)
    return (yield)


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    """Run every item under `tests/` once per round target, and each integration item once per file.

    The pair a target does not run is deselected by `pytest_collection_modifyitems`.
    """
    round_plan = metafunc.config.stash.get(ROUND_KEY, None)
    if round_plan is None or not _under_tests(metafunc.definition.path):
        return
    metafunc.parametrize(
        "round_target",
        round_plan.targets,
        indirect=True,
        scope="session",
        ids=[target.name for target in round_plan.targets],
    )
    if "integration_file" in metafunc.fixturenames:
        files = _round_files(metafunc.config, round_plan)
        metafunc.parametrize("integration_file", files, ids=files)


@pytest.hookimpl(trylast=True)
def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Deselect the (target, item) pairs a target does not run, then order the rest by target, integration first."""
    round_plan = config.stash.get(ROUND_KEY, None)
    if round_plan is None:
        return
    integration_dir = _integration_dir(config.stash[CATALOG_KEY])
    files_by_platform = {
        platform: set(platform_files(integration_dir, platform))
        for platform in {target.platform for target in round_plan.targets}
    }
    kept: list[pytest.Item] = []
    deselected: list[pytest.Item] = []
    for item in items:
        target = item_target(item)
        if target is None or _runs(target, item, files_by_platform):
            kept.append(item)
        else:
            deselected.append(item)
    if deselected:
        config.hook.pytest_deselected(items=deselected)
    order = {target.name: index for index, target in enumerate(round_plan.targets)}
    items[:] = sorted(kept, key=lambda item: _order_key(item, order))


def pytest_report_collectionfinish(config: pytest.Config) -> list[str]:
    """List the app builds and integration runs of the round, so `--collect-only` shows the plan."""
    round_plan = config.stash.get(ROUND_KEY, None)
    if round_plan is None:
        return []
    return [*_build_lines(config, round_plan), *_run_lines(round_plan, config.stash[RUNS_KEY])]


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_setup(item: pytest.Item) -> None:
    """Stop an e2e item of a blocked target before any fixture runs; an integration item reports its own file."""
    state = item.config.stash.get(_STATE_KEY, None)
    target = item_target(item)
    if state is None or target is None or _is_integration(item):
        return
    if state.ledger.blocked(target.name):
        item.stash[_STOPPED_KEY] = True
        raise RoundEnvError(_BLOCKED)


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_protocol(item: pytest.Item, nextitem: pytest.Item | None) -> bool | None:
    """Run a round item, re-run an e2e item once on its first `env` per (target, module) (C9), and record its cell.

    Only the last run's reports reach the terminal; every run's reports go to the item's log.
    """
    state = item.config.stash.get(_STATE_KEY, None)
    target = item_target(item)
    if state is None or target is None:
        return None
    item.ihook.pytest_runtest_logstart(nodeid=item.nodeid, location=item.location)
    # The last item of the round tears every target down after each run, so its re-run brings its target up again.
    runs = [runtestprotocol(item, nextitem=nextitem, log=False)]
    if _retryable(item, state, target, runs[-1]) and state.ledger.record_env(target.name, _module(item)) == "retry":
        runs.append(runtestprotocol(item, nextitem=nextitem, log=False))
        if _retryable(item, state, target, runs[-1]):
            state.ledger.record_env(target.name, _module(item))
    for report in runs[-1]:
        item.ihook.pytest_runtest_logreport(report=report)
    _record_item(state, item, target, runs)
    item.ihook.pytest_runtest_logfinish(nodeid=item.nodeid, location=item.location)
    return True


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(
    item: pytest.Item, call: pytest.CallInfo[None]
) -> Generator[None, pytest.TestReport, pytest.TestReport]:
    """Class a failed phase `env` when it raised `RoundEnvError`, else `fail`; on an e2e item that ran, keep the device
    log since setup began and, on failure, a screenshot."""
    report = yield
    state = item.config.stash.get(_STATE_KEY, None)
    target = item_target(item)
    if state is None or target is None:
        return report
    if call.when == "setup":
        item.stash[_SINCE_KEY] = datetime.fromtimestamp(call.start, UTC)
    if report.failed and call.excinfo is not None:
        error = call.excinfo.value
        if isinstance(error, RoundEnvError):
            report.user_properties += [(_CLASS_PROPERTY, "env"), (_REASON_PROPERTY, error.reason)]
        else:
            reason = _first_line(call.excinfo.exconly())
            report.user_properties += [(_CLASS_PROPERTY, "fail"), (_REASON_PROPERTY, reason)]
    ran = not _is_integration(item) and not item.stash.get(_STOPPED_KEY, False)
    if ran and (call.when == "call" or report.failed):
        _capture(state, item, target, failed=report.failed)
    return report


@pytest.hookimpl(trylast=True)
def pytest_sessionfinish(session: pytest.Session) -> None:
    """Write the round dir once every target is torn down: `summary.md`, `summary.json`, beside the item logs."""
    state = session.config.stash.get(_STATE_KEY, None)
    if state is not None:
        state.write()


def item_target(item: pytest.Item) -> Target | None:
    """The round target `item` runs on; `None` outside a round."""
    target = _params(item).get("round_target")
    return target if isinstance(target, Target) else None


@contextlib.contextmanager
def _brought_up(state: _RoundState, backends: Backends, target: Target) -> Iterator[RoundTarget]:
    """Hold the lane and the booted device of `target` while the block runs; end the device, then free the lane."""
    round_dir = state.open_round_dir(backends.now)
    state.recorder.target(target.name, target.platform, "", reused=False)
    if state.ledger.blocked(target.name):
        raise RoundEnvError(_BLOCKED)
    with contextlib.ExitStack() as stack:
        stack.callback(_take_lane(state, backends, target).release)
        booter = backends.booter_for(target)
        boot_dir = round_dir.item_dir(target.name, _BOOT_DIR)
        record = _boot(state, backends, booter, target, boot_dir / "boot.log")
        # Runs after shutdown, which adds the settings that failed to restore.
        stack.callback(_record_target, state, target, record)
        stack.callback(booter.shutdown, record)
        _record_target(state, target, record)
        if target.avd == AVD_NAME:
            _check_talkback_avd(record.device_id)
        brought_up = _resolve(state, target, record)
        stack.callback(_restore_options, state.config, {dest: getattr(state.config.option, dest) for dest in _RESOLVED})
        _write_options(state, target, record)
        state.live[target.name] = brought_up
        stack.callback(state.live.pop, target.name, None)
        yield brought_up


def _take_lane(state: _RoundState, backends: Backends, target: Target) -> Lease:
    try:
        return acquire_lane(
            target.name, target.alone, state.lane.lane_wait_minutes * 60, lane_dir(), current_holder(),
            sleep=backends.sleep,
        )
    except LaneBusy as error:
        raise RoundEnvError("lane busy") from error


def _boot(state: _RoundState, backends: Backends, booter: Booter, target: Target, log: Path) -> BootRecord:
    """Boot `target`, passing the memory gate first on a cold boot; an `env` boot retries once, then blocks (C9)."""
    while True:
        if not booter.is_running(target):
            reasons = wait_for_memory(backends.memory_reasons, state.lane.lane_wait_minutes * 60, sleep=backends.sleep)
            if reasons:
                raise RoundEnvError(f"memory pressure: {'; '.join(reasons)}")
        try:
            return booter.boot(target, log)
        except RoundEnvError as error:
            # `boot` ends what it booted before it raises, so the retry starts from nothing.
            if state.ledger.record_env(target.name, _BOOT_KEY) == "block":
                raise RoundEnvError(_BLOCKED) from error


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


def _record_target(state: _RoundState, target: Target, record: BootRecord) -> None:
    """Record the target's device and the boot settings that failed so far (T4: they never fail the boot)."""
    state.recorder.target(target.name, target.platform, record.device_id, record.reused, record.setting_failures)


def _resolve(state: _RoundState, target: Target, record: BootRecord) -> RoundTarget:
    app_id = state.config.getoption("app_id", None) or _app_id(state.catalog, target)
    app = state.config.getoption("app", None)
    return RoundTarget(target, record, str(app_id), Path(app) if app is not None else None)


def _write_options(state: _RoundState, target: Target, record: BootRecord) -> None:
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


def _app_build(state: _RoundState, backends: Backends, target: Target) -> Path:
    """The e2e app build of the target's platform; the first target of a platform builds it for the rest."""
    key = (target.platform, target.wasm)
    path = state.app_builds.get(key)
    if path is None:
        round_dir = state.open_round_dir(backends.now)
        log = round_dir.item_dir(target.name, _BUILD_DIR) / "build.log"
        build = backends.build(state.app_dir, E2E_ROOT.parent, target.platform, target.wasm, backends.runner, log)
        state.recorder.build(target.name, build.argv, build.seconds, build.reused)
        path = state.app_builds[key] = build.path
    return path


def _run_with_retry(
    state: _RoundState, backends: Backends, round_target: RoundTarget, plan: RunPlan
) -> dict[str, FileResult]:
    name = round_target.target.name
    while not state.ledger.blocked(name):
        files = _run_once(state, backends, round_target, plan)
        if all(result.cls != "env" for result in files.values()):
            return files
        if state.ledger.record_env(name, plan.key) == "block":
            break
    return _env_files(plan, _BLOCKED)


def _run_once(
    state: _RoundState, backends: Backends, round_target: RoundTarget, plan: RunPlan
) -> dict[str, FileResult]:
    """Run `plan` once; a launched run is recorded as a build entry (pre-flight F7) and keeps its device log."""
    target, record = round_target.target, round_target.record
    run_dir = state.open_round_dir(backends.now).item_dir(target.name, plan.key)
    for file in plan.files:
        state.run_dirs[(target.name, file)] = run_dir
    try:
        version = _flutter_version(state, backends.runner) if target.platform == "linux" else None
    except RoundEnvError as error:
        return _env_files(plan, error.reason)
    since = backends.now()
    outcome = backends.run_plan(
        plan, target, record, backends.booter_for(target), state.app_dir, run_dir, backends.runner,
        state.lane.run_timeout_minutes * 60, backends.port_dir, flutter_version=version,
    )
    if outcome.argv:
        state.recorder.build(target.name, outcome.argv, outcome.seconds, reused=False)
        save_device_log(backends.runner, record, since, run_dir / _DEVICE_LOG)
    return outcome.files


def _flutter_version(state: _RoundState, runner: Runner) -> str:
    """The host's Flutter version, read once per round (pre-flight F16)."""
    if state.flutter_version is None:
        state.flutter_version = flutter_version(runner)
    return state.flutter_version


def _env_files(plan: RunPlan, reason: str) -> dict[str, FileResult]:
    """Every file of `plan` classed `env`, with as many runs as a launched run would have had (`integration_run`)."""
    return {
        file: FileResult("env", 0, plan.repeat if file in plan.wrapped else 1, reason, ()) for file in plan.files
    }


def _retryable(item: pytest.Item, state: _RoundState, target: Target, reports: Sequence[pytest.TestReport]) -> bool:
    """Whether this run of an e2e item ended `env` on its own, not because its target is down or blocked."""
    if _is_integration(item) or target.name in state.down or state.ledger.blocked(target.name):
        return False
    outcome = _outcome(reports)
    return outcome is not None and outcome[0] == "env"


def _capture(state: _RoundState, item: pytest.Item, target: Target, *, failed: bool) -> None:
    """Keep the device log since the item's setup began and, on failure, a screenshot, in the item's dir."""
    brought_up = state.live.get(target.name)
    if brought_up is None or state.round_dir is None or state.backends is None:
        return
    item_dir = state.round_dir.item_dir(target.name, _test_name(item, target))
    since = item.stash.get(_SINCE_KEY, None) or state.backends.now()
    save_device_log(state.backends.runner, brought_up.record, since, item_dir / _DEVICE_LOG)
    if failed:
        save_screenshot(state.backends.runner, brought_up.record, item_dir / _SCREENSHOT)


def _record_item(
    state: _RoundState, item: pytest.Item, target: Target, runs: Sequence[Sequence[pytest.TestReport]]
) -> None:
    """Record the cell of the item's last run; an e2e item's log holds the reports of every run."""
    if state.round_dir is None:
        return
    test = _test_name(item, target)
    file = _params(item).get("integration_file")
    if isinstance(file, str):
        result = state.outcomes.get(target.name, {}).get(file)
        run_dir = state.run_dirs.get((target.name, file))
        log = state.relative(run_dir / LOG_NAME) if run_dir is not None else ""
        if result is not None:
            cell = Cell(result.cls, result.passed, result.runs, result.reason, log)
            state.record(target.name, test, "integration", result.tags, cell)
            return
        cell_or_none = _cell(runs[-1], log)
        if cell_or_none is not None:
            state.record(target.name, test, "integration", (), cell_or_none)
        return
    item_log = state.round_dir.item_dir(target.name, test) / _ITEM_LOG
    _write_item_log(item_log, runs)
    cell_or_none = _cell(runs[-1], state.relative(item_log))
    if cell_or_none is not None:
        kind: ItemKind = "perf" if item.get_closest_marker("perf") is not None else "e2e"
        stories = [str(marker.args[0]) for marker in item.iter_markers("req") if marker.args]
        state.record(target.name, test, kind, stories, cell_or_none)


def _cell(reports: Sequence[pytest.TestReport], log: str) -> Cell | None:
    """The cell of one run: `env` or `fail` from its first failed phase, `pass`, or `None` for a skipped item."""
    outcome = _outcome(reports)
    if outcome is not None:
        cls, reason = outcome
        return Cell("env" if cls == "env" else "fail", 0, 1, reason, log)
    if any(report.skipped for report in reports):
        return None
    return Cell("pass", 1, 1, "", log)


def _outcome(reports: Sequence[pytest.TestReport]) -> tuple[str, str] | None:
    """The class and reason of the first failed phase of one run; `None` when no phase failed."""
    for report in reports:
        if report.failed:
            properties = dict(report.user_properties)
            return str(properties.get(_CLASS_PROPERTY, "fail")), str(properties.get(_REASON_PROPERTY, ""))
    return None


def _write_item_log(path: Path, runs: Sequence[Sequence[pytest.TestReport]]) -> None:
    lines: list[str] = []
    for number, reports in enumerate(runs, start=1):
        for report in reports:
            lines.append(f"== run {number}, {report.when}: {report.outcome}")
            if report.longrepr:
                lines.append(report.longreprtext)
            for title, content in report.sections:
                lines += [f"-- {title}", content]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _test_name(item: pytest.Item, target: Target) -> str:
    """The summary row of `item`: its integration file, else its module and function, with any id but the target's."""
    file = _params(item).get("integration_file")
    if isinstance(file, str):
        return file
    name = f"{_module(item)}::{getattr(item, 'originalname', item.name)}"
    callspec = getattr(item, "callspec", None)
    ids = _without(str(callspec.id), target.name) if callspec is not None else ""
    return f"{name}[{ids}]" if ids else name


def _without(ids: str, target_id: str) -> str:
    """`ids` (pytest joins parameter ids with `-`) without the round target's id."""
    if ids == target_id:
        return ""
    if ids.startswith(f"{target_id}-"):
        return ids[len(target_id) + 1 :]
    if ids.endswith(f"-{target_id}"):
        return ids[: -len(target_id) - 1]
    return ids


def _module(item: pytest.Item) -> str:
    """The item's module path under `tests/`, the key of the e2e retry rule."""
    path = Path(str(item.path)).resolve()
    return path.relative_to(TESTS_DIR.resolve()).as_posix() if _under_tests(path) else path.name


def _first_line(text: str) -> str:
    line = next((line for line in text.splitlines() if line.strip()), "")
    return line[:_REASON_CHARS]


def _real_backends(config: pytest.Config) -> Backends:
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

        sdk = sdk_root(_app_dir(catalog), os.environ, Path.home())
        return AndroidBooter(runner, sdk, catalog.lane, e2e_avd.avd_home(), port_dir)
    if platform == "ios":
        return IosBooter(runner, catalog.lane, Path.home())
    return HostBooter()


def _under_tests(path: Path) -> bool:
    return TESTS_DIR in path.resolve().parents


def _app_dir(catalog: Catalog) -> Path:
    """The folder of the e2e app (`apps.test_app` of the catalog)."""
    app = catalog.apps.get(E2E_APP)
    if app is None:
        raise CatalogError(f"targets.toml declares no apps.{E2E_APP}")
    return E2E_ROOT.parent / app.folder


def _integration_dir(catalog: Catalog) -> Path:
    """The folder of the e2e app's integration tests."""
    return _app_dir(catalog) / INTEGRATION_FOLDER


def _reject_cross_platform_overrides(config: pytest.Config, round_plan: RoundPlan) -> None:
    """Refuse a low-level option that cannot hold for every platform of the round."""
    platforms = sorted({target.platform for target in round_plan.targets})
    if len(platforms) < 2:
        return
    given = [flag for flag, dest in _LOW_LEVEL if config.getoption(dest, None) is not None]
    if given:
        raise pytest.UsageError(
            f"{', '.join(given)} cannot apply to a round spanning {', '.join(platforms)}; "
            "name targets of one platform or drop the option"
        )


def _plan_integration(catalog: Catalog, round_plan: RoundPlan, integration_dir: Path) -> dict[str, list[RunPlan]]:
    """Plan the integration runs of every target that takes them, one `plan_runs` call per platform.

    A target that marks a file its platform does not run is the catalog's error, so it reads as a usage error.
    """
    runs: dict[str, list[RunPlan]] = {}
    for platform in dict.fromkeys(target.platform for target in round_plan.targets):
        targets = [target for target in round_plan.targets if target.platform == platform and target.integration]
        if targets:
            files = platform_files(integration_dir, platform)
            try:
                runs |= plan_runs(platform, targets, files, list(catalog.sequences.values()), round_plan.repeat)
            except ValueError as error:
                raise CatalogError(str(error)) from error
    return runs


def _round_files(config: pytest.Config, round_plan: RoundPlan) -> list[str]:
    """Every integration file some target of the round runs, sorted; the pairs a target lacks are deselected later."""
    integration_dir = _integration_dir(config.stash[CATALOG_KEY])
    platforms = {target.platform for target in round_plan.targets}
    return sorted({file for platform in platforms for file in platform_files(integration_dir, platform)})


def _params(item: pytest.Item) -> dict[str, object]:
    """The parametrized values of `item`, empty for an item nothing parametrizes."""
    callspec = getattr(item, "callspec", None)
    return dict(callspec.params) if callspec is not None else {}


def _is_integration(item: pytest.Item) -> bool:
    return "integration_file" in _params(item)


def _runs(target: Target, item: pytest.Item, files_by_platform: dict[str, set[str]]) -> bool:
    """Whether `target` runs `item`: an integration item by its file, any other by `runs_e2e`."""
    file = _params(item).get("integration_file")
    if file is not None:
        return target.integration and file in files_by_platform[target.platform]
    return runs_e2e(target, {marker.name for marker in item.iter_markers()})


def _order_key(item: pytest.Item, order: dict[str, int]) -> tuple[int, int]:
    """Sort key: round position of the item's target, then integration items before the rest; others lead."""
    target = item_target(item)
    if target is None:
        return (-1, 0)
    return (order[target.name], 0 if _is_integration(item) else 1)


def _build_lines(config: pytest.Config, round_plan: RoundPlan) -> list[str]:
    """One `round: build` line per e2e app build the round needs; none when `--app` supplies the app."""
    if config.getoption("app", None) is not None:
        return []
    builds = dict.fromkeys(
        (target.platform, target.wasm)
        for target in round_plan.targets
        if target.e2e and target.platform in PLATFORMS
    )
    return [f"round: build {platform} {build_argv(platform, wasm)}" for platform, wasm in builds]


def _run_lines(round_plan: RoundPlan, runs: dict[str, list[RunPlan]]) -> list[str]:
    """One `round: run` line per distinct run plan, naming the targets that share it."""
    sharing: dict[RunPlan, list[str]] = {}
    for target in round_plan.targets:
        for plan in runs.get(target.name, ()):
            sharing.setdefault(plan, []).append(target.name)
    return [_run_line(plan, names) for plan, names in sharing.items()]


def _run_line(plan: RunPlan, names: Sequence[str]) -> str:
    return f"round: run {plan.key} {plan.kind} {','.join(names)} {','.join(plan.files)}"
