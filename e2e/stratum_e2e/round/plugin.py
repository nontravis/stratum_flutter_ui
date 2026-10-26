"""The pytest side of a device round: options, per-target collection, the per-target fixtures, and the hooks that
retry, capture, and record items (design sections 6, 7, 10).

A round starts when `--target`, `--mode`, or `--repeat` is given. Without any of them the plugin is inert: it loads no
catalog, parametrizes nothing, leaves collection to the low-level `--platform` path, and its fixtures read the four
low-level options as before. In a round every item under `tests/` is parametrized by `round_target`, the integration
items by `integration_file` as well, and the pairs a target does not run are deselected. Items run target by target:
`round_target` takes the target's lane and boots it before its first item, and pytest tears it down (shutdown, then
lane release) before the next target's first item. The round dir is written when the session ends, after a SIGTERM or
SIGINT too.

The hooks and fixtures live here, since `pytest_plugins` registers this module; they build on `state` (keys and round
state), `collect` (planning and selection), `bring_up` (lane, boot, backends), `runs` (resolve, build, integration
runs), and `items` (retry and recording).
"""

from __future__ import annotations

import contextlib
import signal
import sys
from collections.abc import Callable, Generator, Iterator
from datetime import UTC, datetime
from pathlib import Path
from types import FrameType
from typing import Final, NoReturn

import pytest
from _pytest.runner import runtestprotocol

from stratum_e2e.round.bring_up import bring_up, real_backends
from stratum_e2e.round.catalog import TARGETS_TOML, Target, load_catalog, resolve_round
from stratum_e2e.round.collect import (
    app_integration_dir,
    build_lines,
    is_integration,
    item_target,
    order_key,
    plan_integration,
    reject_cross_platform_overrides,
    round_files,
    run_lines,
    runs_item,
    under_tests,
)
from stratum_e2e.round.entry import platform_files
from stratum_e2e.round.errors import BuildFailure, CatalogError, RoundEnvError
from stratum_e2e.round.integration_run import FileResult
from stratum_e2e.round.items import (
    CLASS_PROPERTY,
    LOG_PROPERTY,
    REASON_PROPERTY,
    SINCE_KEY,
    capture_item,
    first_line,
    module_key,
    record_item,
    retryable,
)
from stratum_e2e.round.probe import lost_device_reason
from stratum_e2e.round.results import Recorder
from stratum_e2e.round.runs import app_build, run_with_retry
from stratum_e2e.round.state import (
    BLOCKED,
    CATALOG_KEY,
    ROUND_KEY,
    RUNS_KEY,
    STATE_KEY,
    Backends,
    RoundState,
    RoundTarget,
)

_Handler = Callable[[int, FrameType | None], object] | int | None

_STOP_SIGNALS: Final = (signal.SIGTERM, signal.SIGINT)
STOP_NOTICE: Final = "stopping: tearing every target down; a further stop signal is ignored, SIGKILL forces"
_PRIOR_HANDLERS_KEY: Final = pytest.StashKey[dict[signal.Signals, _Handler]]()
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

    In a round, the first SIGTERM or SIGINT raises `KeyboardInterrupt`, so a watch-lane stop still tears every target
    down and writes the round dir; a further stop signal is ignored until `pytest_unconfigure`. SIGINT needs its own
    handler: a non-interactive shell starts every `&` command with SIGINT ignored, and Python keeps an inherited
    ignore.
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
        reject_cross_platform_overrides(config, round_plan)
        runs = plan_integration(catalog, round_plan, app_integration_dir(catalog))
    except CatalogError as error:
        raise pytest.UsageError(str(error)) from error
    config.stash[ROUND_KEY] = round_plan
    config.stash[CATALOG_KEY] = catalog
    config.stash[RUNS_KEY] = runs
    config.stash[STATE_KEY] = RoundState(config, round_plan, catalog, runs)
    interrupt = _stop_handler(config)
    config.stash[_PRIOR_HANDLERS_KEY] = {stop: signal.signal(stop, interrupt) for stop in _STOP_SIGNALS}


def pytest_unconfigure(config: pytest.Config) -> None:
    """Give SIGTERM and SIGINT back the handlers they had before the round."""
    for stop, handler in config.stash.get(_PRIOR_HANDLERS_KEY, {}).items():
        signal.signal(stop, handler)


def _stop_handler(config: pytest.Config) -> Callable[[int, FrameType | None], NoReturn]:
    """The handler of a round's stop signals; `pytest_unconfigure` gives the prior handlers back."""

    def _interrupt(signum: int, frame: FrameType | None) -> NoReturn:
        """Stop the round on its first stop signal and ignore the rest, so a second cannot cut the teardown short.

        The notice bypasses pytest's capture, which would otherwise hold it back from the terminal. It is best effort:
        the stop is raised whether or not the notice could be written.
        """
        for stop in _STOP_SIGNALS:
            signal.signal(stop, signal.SIG_IGN)
        try:
            capture = config.pluginmanager.get_plugin("capturemanager")
            with capture.global_and_fixture_disabled() if capture is not None else contextlib.nullcontext():
                print(STOP_NOTICE, file=sys.stderr, flush=True)
        finally:
            raise KeyboardInterrupt(f"signal {signum}")

    return _interrupt


def _lost_or_fail(state: RoundState, target: Target, call: pytest.CallInfo[None]) -> tuple[str, str]:
    """A failed phase's class and reason: `env` naming the probe result when the target's device reads lost, else
    `fail` with the error's first line."""
    reason = first_line(call.excinfo.exconly()) if call.excinfo is not None else ""
    brought_up = state.live.get(target.name)
    if brought_up is not None and state.backends is not None:
        probe = lost_device_reason(state.backends.runner, brought_up.record)
        if probe is not None:
            return "env", f"device lost ({probe})"
    return "fail", reason


@pytest.fixture(scope="session")
def round_backends(request: pytest.FixtureRequest) -> Backends:
    """The real backends: subprocesses, one booter per platform, the app build, the integration run, the host memory
    gate, and the UTC clock. A unit test overrides this fixture in a conftest."""
    return real_backends(request.config)


@pytest.fixture(scope="session")
def round_recorder(request: pytest.FixtureRequest) -> Recorder:
    """The round's recorder; outside a round, a recorder nothing writes."""
    state = request.config.stash.get(STATE_KEY, None)
    return state.recorder if state is not None else Recorder()


@pytest.fixture(scope="session")
def round_target(request: pytest.FixtureRequest) -> Iterator[RoundTarget | None]:
    """The target a parametrized item runs on, brought up for its items; `None` where no round parametrizes it.

    One instance per target, torn down before the next target's: the lane is taken, the device booted (the memory
    gate first, on a cold boot only), the TalkBack AVD checked, and the target's platform, device, and app id written
    into the low-level options unless given on the command line. Teardown ends what was booted, then frees the lane;
    a teardown failure is recorded on the target, never raised into the next target's first item.
    Any bring-up step that fails raises `RoundEnvError`, which pytest keeps for every item of the target, so the round
    moves on.
    """
    param: object = getattr(request, "param", None)
    if param is None:
        yield None
        return
    if not isinstance(param, Target):
        raise TypeError(f"round_target is parametrized with {type(param).__name__}, not a Target")
    state = request.config.stash[STATE_KEY]
    backends: Backends = request.getfixturevalue("round_backends")
    state.backends = backends
    try:
        with bring_up(state, backends, param) as brought_up:
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
    state = request.config.stash[STATE_KEY]
    return app_build(state, request.getfixturevalue("round_backends"), round_target.target)


@pytest.fixture(scope="session")
def integration_outcomes(request: pytest.FixtureRequest, round_target: RoundTarget | None) -> dict[str, FileResult]:
    """Each integration file's result on the target, from one run of each of its plans; empty outside a round.

    An `env` run reruns once per (target, plan key); a second `env` marks its files `env: target blocked`, blocks the
    target, and the target's later plans never launch (C9).
    """
    if round_target is None:
        return {}
    state = request.config.stash[STATE_KEY]
    backends: Backends = request.getfixturevalue("round_backends")
    results: dict[str, FileResult] = {}
    for plan in state.runs.get(round_target.target.name, []):
        results |= run_with_retry(state, backends, round_target, plan)
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
    if collector.config.stash.get(ROUND_KEY, None) is not None and under_tests(collector.path):
        if collector.istestfunction(obj, name):
            pytest.mark.usefixtures("round_target")(obj)
    return (yield)


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    """Run every item under `tests/` once per round target, and each integration item once per file.

    The pair a target does not run is deselected by `pytest_collection_modifyitems`.
    """
    round_plan = metafunc.config.stash.get(ROUND_KEY, None)
    if round_plan is None or not under_tests(metafunc.definition.path):
        return
    metafunc.parametrize(
        "round_target",
        round_plan.targets,
        indirect=True,
        scope="session",
        ids=[target.name for target in round_plan.targets],
    )
    if "integration_file" in metafunc.fixturenames:
        files = round_files(metafunc.config, round_plan)
        metafunc.parametrize("integration_file", files, ids=files)


@pytest.hookimpl(trylast=True)
def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Deselect the (target, item) pairs a target does not run, then order the rest by target, integration first."""
    round_plan = config.stash.get(ROUND_KEY, None)
    if round_plan is None:
        return
    integration_dir = app_integration_dir(config.stash[CATALOG_KEY])
    files_by_platform = {
        platform: set(platform_files(integration_dir, platform))
        for platform in {target.platform for target in round_plan.targets}
    }
    kept: list[pytest.Item] = []
    deselected: list[pytest.Item] = []
    for item in items:
        target = item_target(item)
        if target is None or runs_item(target, item, files_by_platform):
            kept.append(item)
        else:
            deselected.append(item)
    if deselected:
        config.hook.pytest_deselected(items=deselected)
    order = {target.name: index for index, target in enumerate(round_plan.targets)}
    items[:] = sorted(kept, key=lambda item: order_key(item, order))


def pytest_report_collectionfinish(config: pytest.Config) -> list[str]:
    """List the app builds and integration runs of the round, so `--collect-only` shows the plan."""
    round_plan = config.stash.get(ROUND_KEY, None)
    if round_plan is None:
        return []
    return [*build_lines(config, round_plan), *run_lines(round_plan, config.stash[RUNS_KEY])]


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_setup(item: pytest.Item) -> None:
    """Stop an e2e item of a blocked target before any fixture runs; an integration item reports its own file."""
    state = item.config.stash.get(STATE_KEY, None)
    target = item_target(item)
    if state is None or target is None or is_integration(item):
        return
    if state.ledger.blocked(target.name):
        item.stash[_STOPPED_KEY] = True
        raise RoundEnvError(BLOCKED)


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_protocol(item: pytest.Item, nextitem: pytest.Item | None) -> bool | None:
    """Run a round item, re-run an e2e item once on its first `env` per (target, module) (C9), and record its cell.

    Only the last run's reports reach the terminal; every run's reports go to the item's log.
    """
    state = item.config.stash.get(STATE_KEY, None)
    target = item_target(item)
    if state is None or target is None:
        return None
    item.ihook.pytest_runtest_logstart(nodeid=item.nodeid, location=item.location)
    # The last item of the round tears every target down after each run, so its re-run brings its target up again.
    runs = [runtestprotocol(item, nextitem=nextitem, log=False)]
    if retryable(item, state, target, runs[-1]) and state.ledger.record_env(target.name, module_key(item)) == "retry":
        runs.append(runtestprotocol(item, nextitem=nextitem, log=False))
        if retryable(item, state, target, runs[-1]):
            state.ledger.record_env(target.name, module_key(item))
    for report in runs[-1]:
        item.ihook.pytest_runtest_logreport(report=report)
    record_item(state, item, target, runs)
    item.ihook.pytest_runtest_logfinish(nodeid=item.nodeid, location=item.location)
    return True


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(
    item: pytest.Item, call: pytest.CallInfo[None]
) -> Generator[None, pytest.TestReport, pytest.TestReport]:
    """Class a failed phase `env` when it raised `RoundEnvError`, `build` with the build's reason and log when it
    raised `BuildFailure`, else `fail`; on an e2e item that ran, keep the device log since setup began and, on failure,
    a screenshot."""
    report = yield
    state = item.config.stash.get(STATE_KEY, None)
    target = item_target(item)
    if state is None or target is None:
        return report
    if call.when == "setup":
        item.stash[SINCE_KEY] = datetime.fromtimestamp(call.start, UTC)
    if report.failed and call.excinfo is not None:
        error = call.excinfo.value
        if isinstance(error, RoundEnvError):
            report.user_properties += [(CLASS_PROPERTY, "env"), (REASON_PROPERTY, error.reason)]
        elif isinstance(error, BuildFailure):
            report.user_properties += [
                (CLASS_PROPERTY, "build"), (REASON_PROPERTY, error.reason), (LOG_PROPERTY, state.relative(error.log)),
            ]
        else:
            reason = _lost_or_fail(state, target, call)
            report.user_properties += [(CLASS_PROPERTY, reason[0]), (REASON_PROPERTY, reason[1])]
    elif report.failed:
        # A phase that failed with no exception, such as a strict unexpected pass (`[XPASS(strict)] <reason>`).
        report.user_properties += [(CLASS_PROPERTY, "fail"), (REASON_PROPERTY, first_line(report.longreprtext))]
    ran = not is_integration(item) and not item.stash.get(_STOPPED_KEY, False)
    if ran and (call.when == "call" or report.failed):
        capture_item(state, item, target, failed=report.failed)
    return report


@pytest.hookimpl(trylast=True)
def pytest_sessionfinish(session: pytest.Session) -> None:
    """Write the round dir once every target is torn down: `summary.md`, `summary.json`, beside the item logs."""
    state = session.config.stash.get(STATE_KEY, None)
    if state is not None:
        state.write()
