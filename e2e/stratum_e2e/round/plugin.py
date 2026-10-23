"""The pytest side of a device round: its options, its per-target collection, and its selection (design sections 6, 7).

A round starts when `--target`, `--mode`, or `--repeat` is given. Without any of them the plugin is inert: it loads no
catalog, parametrizes nothing, and leaves collection to the low-level `--platform` path. In a round every item under
`tests/` is parametrized by `round_target`, the integration items by `integration_file` as well, and the pairs a target
does not run are deselected.
"""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path
from typing import Final

import pytest

from stratum_e2e.paths import E2E_ROOT
from stratum_e2e.round.app_build import build_argv
from stratum_e2e.round.catalog import TARGETS_TOML, Catalog, RoundPlan, Target, load_catalog, resolve_round
from stratum_e2e.round.entry import RunPlan, plan_runs, platform_files
from stratum_e2e.round.errors import CatalogError
from stratum_e2e.selection import PLATFORMS, runs_e2e

ROUND_KEY: Final = pytest.StashKey[RoundPlan | None]()
CATALOG_KEY: Final = pytest.StashKey[Catalog]()
RUNS_KEY: Final = pytest.StashKey[dict[str, list[RunPlan]]]()

TESTS_DIR: Final = E2E_ROOT / "tests"
E2E_APP: Final = "test_app"
INTEGRATION_FOLDER: Final = "integration_test"

# (option flag, argparse dest) of the low-level options a round resolves per target (design call 1).
_LOW_LEVEL: Final = (("--platform", "platform"), ("--device", "device"), ("--app", "app"), ("--app-id", "app_id"))


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
    """Resolve the round and plan its integration runs; stay inert when no round option is given."""
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
    except (CatalogError, ValueError) as error:
        raise pytest.UsageError(str(error)) from error
    config.stash[ROUND_KEY] = round_plan
    config.stash[CATALOG_KEY] = catalog
    config.stash[RUNS_KEY] = runs


@pytest.fixture(scope="session")
def round_target(request: pytest.FixtureRequest) -> Target | None:
    """The target a parametrized item runs on; `None` where no round parametrizes it."""
    param: object = getattr(request, "param", None)
    if param is None or isinstance(param, Target):
        return param
    raise TypeError(f"round_target is parametrized with {type(param).__name__}, not a Target")


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    """Run every item under `tests/` once per round target, and each integration item once per file.

    The pair a target does not run is deselected by `pytest_collection_modifyitems`.
    """
    round_plan = metafunc.config.stash.get(ROUND_KEY, None)
    if round_plan is None or not _under_tests(metafunc.definition.path):
        return
    # Pytest 9 rejects parametrizing a fixture the item does not request, so every item requests it first.
    if "round_target" not in metafunc.fixturenames:
        metafunc.fixturenames.append("round_target")
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
        target = _item_target(item)
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


def _under_tests(path: Path) -> bool:
    return TESTS_DIR in path.resolve().parents


def _integration_dir(catalog: Catalog) -> Path:
    """The folder of the e2e app's integration tests (`apps.test_app` of the catalog)."""
    app = catalog.apps.get(E2E_APP)
    if app is None:
        raise CatalogError(f"targets.toml declares no apps.{E2E_APP}")
    return E2E_ROOT.parent / app.folder / INTEGRATION_FOLDER


def _reject_cross_platform_overrides(config: pytest.Config, round_plan: RoundPlan) -> None:
    """Refuse a low-level option that cannot hold for every platform of the round."""
    platforms = sorted({target.platform for target in round_plan.targets})
    if len(platforms) < 2:
        return
    given = [flag for flag, dest in _LOW_LEVEL if config.getoption(dest) is not None]
    if given:
        raise pytest.UsageError(
            f"{', '.join(given)} cannot apply to a round spanning {', '.join(platforms)}; "
            "name targets of one platform or drop the option"
        )


def _plan_integration(catalog: Catalog, round_plan: RoundPlan, integration_dir: Path) -> dict[str, list[RunPlan]]:
    """Plan the integration runs of every target that takes them, one `plan_runs` call per platform."""
    runs: dict[str, list[RunPlan]] = {}
    for platform in dict.fromkeys(target.platform for target in round_plan.targets):
        targets = [target for target in round_plan.targets if target.platform == platform and target.integration]
        if targets:
            files = platform_files(integration_dir, platform)
            runs |= plan_runs(platform, targets, files, list(catalog.sequences.values()), round_plan.repeat)
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


def _item_target(item: pytest.Item) -> Target | None:
    target = _params(item).get("round_target")
    return target if isinstance(target, Target) else None


def _runs(target: Target, item: pytest.Item, files_by_platform: dict[str, set[str]]) -> bool:
    """Whether `target` runs `item`: an integration item by its file, any other by `runs_e2e`."""
    file = _params(item).get("integration_file")
    if file is not None:
        return target.integration and file in files_by_platform[target.platform]
    return runs_e2e(target, {marker.name for marker in item.iter_markers()})


def _order_key(item: pytest.Item, order: dict[str, int]) -> tuple[int, int]:
    """Sort key: round position of the item's target, then integration items before the rest; others lead."""
    target = _item_target(item)
    if target is None:
        return (-1, 0)
    return (order[target.name], 0 if "integration_file" in _params(item) else 1)


def _build_lines(config: pytest.Config, round_plan: RoundPlan) -> list[str]:
    """One `round: build` line per e2e app build the round needs; none when `--app` supplies the app."""
    if config.getoption("app") is not None:
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
