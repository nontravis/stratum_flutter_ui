"""Unit tests for how `runs._run_once` records a run's launches in the summary's builds; no round, no device."""

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

from stratum_e2e.round import runs
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.entry import RunPlan
from stratum_e2e.round.integration_run import FileResult, Launch, RunOutcome

LINUX = Target(name="linux", platform="linux", apt=(), e2e=False)
FILES = ("common/restart_1_linux_test.dart", "common/restart_2_linux_test.dart")
PASS = FileResult("pass", 1, 1, "", ())


class Recorder:
    def __init__(self) -> None:
        self.builds: list[tuple[str, tuple[str, ...], float, bool, bool]] = []

    def build(self, target: str, argv: tuple[str, ...], seconds: float, reused: bool, ok: bool = True) -> None:
        self.builds.append((target, tuple(argv), seconds, reused, ok))


def run_once(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, outcome: RunOutcome) -> Recorder:
    recorder = Recorder()
    plan = RunPlan("sequence-0000abcd", "linux", None, "sequence", FILES, {}, 1, sequence="s")
    round_dir: Any = SimpleNamespace(item_dir=lambda target, name: tmp_path / name)
    state: Any = SimpleNamespace(
        open_round_dir=lambda now: round_dir, run_dirs={}, flutter_version="3.47.7", recorder=recorder,
        linux_built=set(), app_dir=tmp_path, lane=SimpleNamespace(run_timeout_minutes=1),
    )
    backends: Any = SimpleNamespace(
        now=lambda: 0.0, run_plan=lambda *args, **kwargs: outcome, booter_for=lambda target: None, runner=None,
        port_dir=tmp_path,
    )
    monkeypatch.setattr(runs, "save_device_log", lambda *args: None)
    round_target: Any = SimpleNamespace(target=LINUX, record=None)
    runs._run_once(state, backends, round_target, plan)
    return recorder


def test_a_sequence_records_one_build_entry_per_launch_with_its_own_command_and_seconds(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    first, second = ("docker", "run", "one"), ("docker", "run", "two")
    outcome = RunOutcome(
        second, 7.0, dict.fromkeys(FILES, PASS), exit_status=0,
        launches=(Launch(first, 3.0, True), Launch(second, 4.0, True)),
    )

    recorder = run_once(tmp_path, monkeypatch, outcome)

    assert recorder.builds == [("linux", first, 3.0, False, True), ("linux", second, 4.0, False, True)]


def test_a_launch_none_of_whose_tests_started_is_recorded_as_not_ok(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    only = ("docker", "run", "one")
    outcome = RunOutcome(only, 3.0, dict.fromkeys(FILES, PASS), launches=(Launch(only, 3.0, False),))

    assert run_once(tmp_path, monkeypatch, outcome).builds == [("linux", only, 3.0, False, False)]


def test_a_single_launch_run_records_its_argv_and_seconds(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    argv = ("docker", "run", "entry")

    recorder = run_once(tmp_path, monkeypatch, RunOutcome(argv, 2.5, dict.fromkeys(FILES, PASS), exit_status=0))

    assert recorder.builds == [("linux", argv, 2.5, False, True)]
