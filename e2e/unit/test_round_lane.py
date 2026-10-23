"""Unit tests for the machine-wide lane locks and the memory-pressure gate (design sections 6 and 15)."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
from pathlib import Path

import pytest

from stratum_e2e.round.catalog import LaneConfig
from stratum_e2e.round.lane import (
    LANE_DIR_ENV,
    Holder,
    LaneBusy,
    acquire_lane,
    current_holder,
    heavy_pattern,
    host_memory_reasons,
    lane_dir,
    memory_gate_reasons,
    parse_free_pct,
    wait_for_memory,
)
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner

E2E_DIR = Path(__file__).resolve().parents[1]
HOLDER_A = Holder(pid=111, session="aaaaaaaa", started="2026-10-23T09:00:00+00:00")
HOLDER_B = Holder(pid=222, session="bbbbbbbb", started="2026-10-23T09:01:00+00:00")
HOLDER_C = Holder(pid=333, session="cccccccc", started="2026-10-23T09:02:00+00:00")


def _done(stdout: str = "", status: int = 0) -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr="", timed_out=False)


class FakeClock:
    """A clock whose `sleep` advances `monotonic`, so a wait loop runs without real time."""

    def __init__(self) -> None:
        self.now = 0.0
        self.sleeps: list[float] = []

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.now += seconds


# --- lane locks ---


def test_second_holder_waits_then_reports_lane_busy(tmp_path: Path) -> None:
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        with pytest.raises(LaneBusy, match="pid 111"):
            acquire_lane("pixel_8", True, 0.2, tmp_path, HOLDER_B, poll_s=0.05)


def test_lane_busy_names_the_session_and_start(tmp_path: Path) -> None:
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        with pytest.raises(LaneBusy, match=r"session aaaaaaaa.*2026-10-23T09:00:00\+00:00"):
            acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_B)


def test_waiting_holder_gets_the_lane_once_it_frees(tmp_path: Path) -> None:
    lease = acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A)
    clock = FakeClock()

    def free_after_two_polls(seconds: float) -> None:
        clock.sleep(seconds)
        if len(clock.sleeps) == 2:
            lease.release()

    with acquire_lane(
        "pixel_8", True, 60, tmp_path, HOLDER_B,
        poll_s=5, sleep=free_after_two_polls, monotonic=clock.monotonic,
    ):
        assert clock.sleeps == [5, 5]


def test_wait_sleeps_only_the_time_left(tmp_path: Path) -> None:
    clock = FakeClock()
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        with pytest.raises(LaneBusy):
            acquire_lane(
                "pixel_8", True, 7, tmp_path, HOLDER_B,
                poll_s=5, sleep=clock.sleep, monotonic=clock.monotonic,
            )
    assert clock.sleeps == [5, 2]


def test_dead_holder_never_strands_the_target(tmp_path: Path) -> None:
    child = subprocess.Popen(
        [
            sys.executable, "-c",
            "import sys, time\n"
            "from pathlib import Path\n"
            "from stratum_e2e.round.lane import acquire_lane, current_holder\n"
            "acquire_lane('pixel_8', True, 0, Path(sys.argv[1]), current_holder())\n"
            "print('held', flush=True)\n"
            "time.sleep(60)\n",
            str(tmp_path),
        ],
        cwd=E2E_DIR,
        env={**os.environ, "PYTHONPATH": str(E2E_DIR)},
        stdout=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        assert child.stdout.readline().strip() == "held"
        with pytest.raises(LaneBusy):
            acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_B)
        child.send_signal(signal.SIGKILL)
        child.wait(timeout=10)
        with acquire_lane("pixel_8", True, 1.0, tmp_path, HOLDER_B, poll_s=0.05):
            pass
    finally:
        child.kill()
        child.wait(timeout=10)


def test_alone_target_excludes_every_other_target(tmp_path: Path) -> None:
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        with pytest.raises(LaneBusy, match="pixel_8"):
            acquire_lane("mac", False, 0, tmp_path, HOLDER_B)


def test_two_shared_targets_run_side_by_side(tmp_path: Path) -> None:
    with acquire_lane("mac", False, 0, tmp_path, HOLDER_A):
        with acquire_lane("chrome", False, 0, tmp_path, HOLDER_B):
            pass


def test_shared_target_blocks_an_alone_target(tmp_path: Path) -> None:
    with acquire_lane("mac", False, 0, tmp_path, HOLDER_A):
        with pytest.raises(LaneBusy, match="mac"):
            acquire_lane("tablet", True, 0, tmp_path, HOLDER_B)


def test_timeout_releases_the_target_lock(tmp_path: Path) -> None:
    with acquire_lane("mac", False, 0, tmp_path, HOLDER_A):
        with pytest.raises(LaneBusy):
            acquire_lane("tablet", True, 0, tmp_path, HOLDER_B)
        # Holder B timed out on the machine lock; the target lock it took first must be free again.
        with acquire_lane("tablet", False, 0, tmp_path, HOLDER_C):
            pass
    with acquire_lane("tablet", True, 0, tmp_path, HOLDER_C):
        pass


def test_release_frees_both_locks_and_is_idempotent(tmp_path: Path) -> None:
    lease = acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A)
    lease.release()
    lease.release()
    with acquire_lane("mac", False, 0, tmp_path, HOLDER_B):
        pass
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_C):
        pass


def test_context_exit_releases_the_lane(tmp_path: Path) -> None:
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        pass
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_B):
        pass


def test_holder_file_names_pid_session_start(tmp_path: Path) -> None:
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        written = json.loads((tmp_path / "pixel_8.holder.json").read_text())
    assert written == {"pid": 111, "session": "aaaaaaaa", "started": "2026-10-23T09:00:00+00:00"}


def test_release_removes_the_holder_file(tmp_path: Path) -> None:
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        pass
    assert not (tmp_path / "pixel_8.holder.json").exists()


def test_stale_holder_file_is_overwritten_by_the_next_holder(tmp_path: Path) -> None:
    (tmp_path / "pixel_8.holder.json").write_text(json.dumps({"pid": 1, "session": "dead", "started": "x"}))
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_B):
        written = json.loads((tmp_path / "pixel_8.holder.json").read_text())
    assert written["pid"] == 222


def test_busy_message_survives_an_unreadable_holder_file(tmp_path: Path) -> None:
    with acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_A):
        (tmp_path / "pixel_8.holder.json").write_text("not json")
        with pytest.raises(LaneBusy, match="holder unknown"):
            acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_B)


def test_stale_holder_files_are_not_named_for_the_machine_lock(tmp_path: Path) -> None:
    (tmp_path / "tablet.holder.json").write_text(json.dumps({"pid": 1, "session": "dead", "started": "x"}))
    with acquire_lane("mac", False, 0, tmp_path, HOLDER_A):
        with pytest.raises(LaneBusy) as busy:
            acquire_lane("pixel_8", True, 0, tmp_path, HOLDER_B)
    assert "tablet" not in str(busy.value)
    assert "mac" in str(busy.value)


def test_directory_is_created_on_demand(tmp_path: Path) -> None:
    nested = tmp_path / "a" / "b"
    with acquire_lane("mac", False, 0, nested, HOLDER_A):
        assert (nested / "mac.lock").exists()


@pytest.mark.parametrize("target", ["../escape", "a/b", "", "with space"])
def test_target_name_cannot_leave_the_lane_directory(tmp_path: Path, target: str) -> None:
    with pytest.raises(ValueError, match="target"):
        acquire_lane(target, False, 0, tmp_path, HOLDER_A)


def test_session_id_reads_claude_session(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", "651e0437abcd")
    assert current_holder().session == "651e0437"


def test_session_id_is_none_without_claude_session(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CLAUDE_CODE_SESSION_ID", raising=False)
    assert current_holder().session == "none"


def test_current_holder_names_this_process_in_utc() -> None:
    holder = current_holder()
    assert holder.pid == os.getpid()
    assert holder.started.endswith("+00:00")


def test_lane_dir_defaults_outside_every_checkout(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.delenv(LANE_DIR_ENV, raising=False)
    monkeypatch.setenv("HOME", str(tmp_path))
    assert lane_dir() == tmp_path / ".cache" / "stratum_e2e" / "lanes"


def test_lane_dir_env_overrides_the_default(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv(LANE_DIR_ENV, str(tmp_path / "custom"))
    assert lane_dir() == tmp_path / "custom"


# --- memory gate ---


def test_memory_gate_level2_needs_30_percent() -> None:
    assert memory_gate_reasons("2", 29, True, None) == ["pressure level 2 needs at least 30% free, has 29%"]
    assert memory_gate_reasons("2", 30, True, None) == []


def test_memory_gate_level1_needs_20_percent() -> None:
    assert memory_gate_reasons("1", 19, True, None) == ["pressure level 1 needs at least 20% free, has 19%"]
    assert memory_gate_reasons("1", 20, True, None) == []


def test_memory_gate_level2_fails_when_not_allowed() -> None:
    assert memory_gate_reasons("2", 90, False, None) == ["pressure level 2 is not 1"]


def test_memory_gate_rejects_other_levels() -> None:
    assert memory_gate_reasons("4", 90, True, None) == ["pressure level 4 is not 1 or 2"]
    assert memory_gate_reasons("unknown", 90, False, None) == ["pressure level unknown is not 1"]


def test_memory_gate_waits_while_a_heavy_process_runs() -> None:
    assert memory_gate_reasons("1", 50, True, "4242 perf_abba") == ["a heavy process is running: 4242 perf_abba"]


def test_memory_gate_reports_pressure_and_heavy_process_together() -> None:
    assert memory_gate_reasons("1", 10, True, "4242 qemu-system") == [
        "pressure level 1 needs at least 20% free, has 10%",
        "a heavy process is running: 4242 qemu-system",
    ]


def test_heavy_pattern_appends_project_terms() -> None:
    assert heavy_pattern(("perf_abba", "perf_freeze")).endswith("|perf_abba|perf_freeze")


def test_heavy_pattern_keeps_the_engine_terms_first() -> None:
    assert heavy_pattern(()) == "qemu-system|flutter_tools.snapshot (drive|test integration_test)|chromedriver"


def test_parse_free_pct_reads_the_free_percentage_line() -> None:
    out = "The system has 17179869184 (1048576 pages)\n\nSystem-wide memory free percentage: 42%\n"
    assert parse_free_pct(out) == 42


def test_parse_free_pct_is_zero_without_a_percentage() -> None:
    assert parse_free_pct("") == 0
    assert parse_free_pct("no number here\n") == 0


LANE = LaneConfig(
    run_timeout_minutes=60,
    boot_settle_timeout_seconds=120,
    allow_level2=True,
    heavy_processes=("perf_abba", "perf_freeze"),
    lane_wait_minutes=30,
)


def _probe_script(level: str, free: str, heavy: str, *, level_status: int = 0, heavy_status: int = 0):
    pattern = heavy_pattern(LANE.heavy_processes)
    return [
        (("memory_pressure",), _done(f"System-wide memory free percentage: {free}%\n")),
        (("sysctl", "-n", "kern.memorystatus_vm_pressure_level"), _done(f"{level}\n", level_status)),
        (("pgrep", "-fl", pattern), _done(heavy, heavy_status)),
    ]


def test_host_memory_reasons_reads_three_probes() -> None:
    runner = FakeRunner(_probe_script("2", "25", "4242 perf_abba --flag\n9999 other\n"))
    reasons = host_memory_reasons(runner, LANE)
    assert set(runner.calls) == {
        ("memory_pressure",),
        ("sysctl", "-n", "kern.memorystatus_vm_pressure_level"),
        ("pgrep", "-fl", heavy_pattern(LANE.heavy_processes)),
    }
    assert reasons == memory_gate_reasons("2", 25, True, "4242 perf_abba --flag")


def test_host_memory_reasons_passes_on_a_calm_host() -> None:
    runner = FakeRunner(_probe_script("1", "55", "", heavy_status=1))
    assert host_memory_reasons(runner, LANE) == []


def test_host_memory_reasons_cuts_a_long_heavy_line_to_160_characters() -> None:
    runner = FakeRunner(_probe_script("1", "55", "4242 " + "x" * 400 + "\n"))
    (reason,) = host_memory_reasons(runner, LANE)
    assert reason == "a heavy process is running: " + ("4242 " + "x" * 400)[:160]


def test_host_memory_reasons_reads_a_failed_sysctl_as_unknown_level() -> None:
    runner = FakeRunner(_probe_script("", "55", "", level_status=1, heavy_status=1))
    assert host_memory_reasons(runner, LANE) == ["pressure level unknown is not 1 or 2"]


def test_host_memory_reasons_honors_allow_level2_off() -> None:
    lane = LaneConfig(60, 120, False, (), 30)
    runner = FakeRunner([
        (("memory_pressure",), _done("System-wide memory free percentage: 90%\n")),
        (("sysctl", "-n", "kern.memorystatus_vm_pressure_level"), _done("2\n")),
        (("pgrep", "-fl", heavy_pattern(())), _done("", 1)),
    ])
    assert host_memory_reasons(runner, lane) == ["pressure level 2 is not 1"]


# --- wait_for_memory ---


def test_wait_for_memory_returns_reasons_at_timeout() -> None:
    clock = FakeClock()
    probes: list[int] = []

    def probe() -> list[str]:
        probes.append(1)
        return [f"pressure level 4 is not 1 or 2 (probe {len(probes)})"]

    reasons = wait_for_memory(probe, 12, poll_s=5, sleep=clock.sleep, monotonic=clock.monotonic)
    assert reasons == ["pressure level 4 is not 1 or 2 (probe 4)"]
    assert clock.sleeps == [5, 5, 2]


def test_wait_for_memory_returns_empty_once_the_probe_passes() -> None:
    clock = FakeClock()
    answers = iter([["busy"], ["busy"], []])
    assert wait_for_memory(lambda: next(answers), 60, poll_s=5, sleep=clock.sleep, monotonic=clock.monotonic) == []
    assert clock.sleeps == [5, 5]


def test_wait_for_memory_probes_once_when_the_wait_is_zero() -> None:
    clock = FakeClock()
    assert wait_for_memory(lambda: ["busy"], 0, sleep=clock.sleep, monotonic=clock.monotonic) == ["busy"]
    assert clock.sleeps == []
