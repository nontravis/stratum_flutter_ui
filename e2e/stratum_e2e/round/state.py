"""What one device round keeps between its fixtures and hooks: the stash keys, a brought-up target, the backends a
unit test swaps for fakes, and the round state (design sections 6 and 10)."""

from __future__ import annotations

import time
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Final

import pytest

from stratum_e2e.paths import E2E_ROOT
from stratum_e2e.round.app_build import AppBuild
from stratum_e2e.round.boot import Booter, BootRecord
from stratum_e2e.round.catalog import Catalog, LaneConfig, RoundPlan, Target
from stratum_e2e.round.entry import RunPlan
from stratum_e2e.round.errors import BuildFailure, CatalogError
from stratum_e2e.round.integration_run import FileResult, RunOutcome
from stratum_e2e.round.results import Cell, ItemKind, Recorder, RetryLedger, RoundDir, rounds_root
from stratum_e2e.round.runner import Runner

ROUND_KEY: Final = pytest.StashKey[RoundPlan | None]()
CATALOG_KEY: Final = pytest.StashKey[Catalog]()
RUNS_KEY: Final = pytest.StashKey[dict[str, list[RunPlan]]]()

TESTS_DIR: Final = E2E_ROOT / "tests"
E2E_APP: Final = "test_app"
INTEGRATION_FOLDER: Final = "integration_test"

# (option flag, argparse dest) of the low-level options a round resolves per target (design call 1).
LOW_LEVEL: Final = (("--platform", "platform"), ("--device", "device"), ("--app", "app"), ("--app-id", "app_id"))

DEVICE_LOG: Final = "device.log"
BLOCKED: Final = "target blocked"


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

    `resolve` resolves an app folder's packages before the round's first host build or run of it. `booter_for` hands
    back one booter per platform for the whole round: the instance that boots a target is the one that ends it.
    `port_dir` holds the port reservations of the Android console and chromedriver (pre-flight F18). `sleep` paces the
    lane and memory-gate polls.
    """

    runner: Runner
    booter_for: Callable[[Target], Booter]
    resolve: Callable[[Path, Path, str, Runner, Path], None]
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


class RoundState:
    """What one round keeps between its fixtures and hooks: recorder, retry ledger, round dir, and per-target caches."""

    def __init__(
        self, config: pytest.Config, plan: RoundPlan, catalog: Catalog, runs: dict[str, list[RunPlan]]
    ) -> None:
        self.config = config
        self.plan = plan
        self.catalog = catalog
        self.runs = runs
        self.overrides = {dest for _, dest in LOW_LEVEL if config.getoption(dest, None) is not None}
        self.recorder = Recorder()
        self.ledger = RetryLedger()
        self.started = time.monotonic()
        self.round_dir: RoundDir | None = None
        self.backends: Backends | None = None
        # Targets whose `round_target` failed: every item of theirs fails alike, so none is retried.
        self.down: set[str] = set()
        self.live: dict[str, RoundTarget] = {}
        self.app_builds: dict[tuple[str, bool], Path] = {}
        # (platform, wasm) -> the app build that failed twice, raised again for the platform's later items.
        self.build_failures: dict[tuple[str, bool], BuildFailure] = {}
        # Linux targets whose app built in its own container step this round (`integration_run.run_plan`).
        self.linux_built: set[str] = set()
        self.resolved = False
        self.outcomes: dict[str, dict[str, FileResult]] = {}
        self.run_dirs: dict[tuple[str, str], Path] = {}
        self.flutter_version: str | None = None
        # target -> boot settings that failed in its finished bring-ups (the last item's re-run brings one up twice).
        self.past_setting_failures: dict[str, list[str]] = {}
        # test -> target -> result; written to the recorder at session end, when every target's stories are known.
        self.results: dict[str, dict[str, _Result]] = {}

    @property
    def lane(self) -> LaneConfig:
        return self.catalog.lane

    @property
    def app_dir(self) -> Path:
        return e2e_app_dir(self.catalog)

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


STATE_KEY: Final = pytest.StashKey[RoundState]()


def e2e_app_dir(catalog: Catalog) -> Path:
    """The folder of the e2e app (`apps.test_app` of the catalog)."""
    app = catalog.apps.get(E2E_APP)
    if app is None:
        raise CatalogError(f"targets.toml declares no apps.{E2E_APP}")
    return E2E_ROOT.parent / app.folder
