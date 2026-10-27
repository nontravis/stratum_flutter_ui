"""Collection helpers of the device round: the integration runs it plans, which (target, item) pairs it keeps, their
order, and the plan lines `--collect-only` shows (design sections 6 and 7)."""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

import pytest

from stratum_e2e.round.app_build import build_argv
from stratum_e2e.round.catalog import Catalog, RoundPlan, Target
from stratum_e2e.round.entry import RunPlan, plan_runs, platform_files
from stratum_e2e.round.errors import CatalogError
from stratum_e2e.round.integration_run import check_runnable
from stratum_e2e.round.state import CATALOG_KEY, INTEGRATION_FOLDER, LOW_LEVEL, TESTS_DIR, e2e_app_dir
from stratum_e2e.selection import PLATFORMS, runs_e2e


def item_target(item: pytest.Item) -> Target | None:
    """The round target `item` runs on; `None` outside a round."""
    target = item_params(item).get("round_target")
    return target if isinstance(target, Target) else None


def under_tests(path: Path) -> bool:
    return TESTS_DIR in path.resolve().parents


def app_integration_dir(catalog: Catalog) -> Path:
    """The folder of the e2e app's integration tests."""
    return e2e_app_dir(catalog) / INTEGRATION_FOLDER


def reject_cross_platform_overrides(config: pytest.Config, round_plan: RoundPlan) -> None:
    """Refuse a low-level option that cannot hold for every platform of the round."""
    platforms = sorted({target.platform for target in round_plan.targets})
    if len(platforms) < 2:
        return
    given = [flag for flag, dest in LOW_LEVEL if config.getoption(dest, None) is not None]
    if given:
        raise pytest.UsageError(
            f"{', '.join(given)} cannot apply to a round spanning {', '.join(platforms)}; "
            "name targets of one platform or drop the option"
        )


def plan_integration(catalog: Catalog, round_plan: RoundPlan, integration_dir: Path) -> dict[str, list[RunPlan]]:
    """Plan the integration runs of every target that takes them, one `plan_runs` call per platform.

    A target that marks a file its platform does not run, or a run `check_runnable` refuses, is the catalog's error,
    so it reads as a usage error before any target boots.
    """
    runs: dict[str, list[RunPlan]] = {}
    for platform in dict.fromkeys(target.platform for target in round_plan.targets):
        targets = [target for target in round_plan.targets if target.platform == platform and target.integration]
        if targets:
            files = platform_files(integration_dir, platform)
            try:
                planned = plan_runs(platform, targets, files, list(catalog.sequences.values()), round_plan.repeat)
                for target in targets:
                    for plan in planned[target.name]:
                        check_runnable(plan, target, integration_dir)
            except ValueError as error:
                raise CatalogError(str(error)) from error
            runs |= planned
    return runs


def round_files(config: pytest.Config, round_plan: RoundPlan) -> list[str]:
    """Every integration file some target of the round runs, sorted; the pairs a target lacks are deselected later."""
    integration_dir = app_integration_dir(config.stash[CATALOG_KEY])
    platforms = {target.platform for target in round_plan.targets}
    return sorted({file for platform in platforms for file in platform_files(integration_dir, platform)})


def item_params(item: pytest.Item) -> dict[str, object]:
    """The parametrized values of `item`, empty for an item nothing parametrizes."""
    callspec = getattr(item, "callspec", None)
    return dict(callspec.params) if callspec is not None else {}


def is_integration(item: pytest.Item) -> bool:
    return "integration_file" in item_params(item)


def runs_item(target: Target, item: pytest.Item, files_by_platform: dict[str, set[str]]) -> bool:
    """Whether `target` runs `item`: an integration item by its file, any other by `runs_e2e`."""
    file = item_params(item).get("integration_file")
    if file is not None:
        return target.integration and file in files_by_platform[target.platform]
    markers = {marker.name for marker in item.iter_markers()}
    return runs_e2e(target, markers, host_voiceover=bool(item.config.getoption("host_voiceover")))


def order_key(item: pytest.Item, order: dict[str, int]) -> tuple[int, int]:
    """Sort key: round position of the item's target, then integration items before the rest; others lead."""
    target = item_target(item)
    if target is None:
        return (-1, 0)
    return (order[target.name], 0 if is_integration(item) else 1)


def build_lines(config: pytest.Config, round_plan: RoundPlan) -> list[str]:
    """One `round: build` line per e2e app build the round needs; none when `--app` supplies the app."""
    if config.getoption("app", None) is not None:
        return []
    builds = dict.fromkeys(
        (target.platform, target.wasm)
        for target in round_plan.targets
        if target.e2e and target.platform in PLATFORMS
    )
    return [f"round: build {platform} {build_argv(platform, wasm)}" for platform, wasm in builds]


def run_lines(round_plan: RoundPlan, runs: dict[str, list[RunPlan]]) -> list[str]:
    """One `round: run` line per distinct run plan, naming the targets that share it."""
    sharing: dict[RunPlan, list[str]] = {}
    for target in round_plan.targets:
        for plan in runs.get(target.name, ()):
            sharing.setdefault(plan, []).append(target.name)
    return [_run_line(plan, names) for plan, names in sharing.items()]


def _run_line(plan: RunPlan, names: Sequence[str]) -> str:
    return f"round: run {plan.key} {plan.kind} {','.join(names)} {','.join(plan.files)}"
