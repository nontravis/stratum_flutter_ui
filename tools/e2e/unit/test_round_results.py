"""Unit tests for the round dir, the summary writers, and the retry ledger."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta, timezone
from pathlib import Path
from typing import Literal

import pytest

from stratum_e2e.paths import REPO_ROOT
from stratum_e2e.round.results import (
    ROUNDS_DIR_ENV,
    ROUNDS_ROOT,
    Cell,
    Recorder,
    RetryLedger,
    RoundDir,
    cell_text,
    rounds_root,
)

_NOON = datetime(2026, 10, 23, 12, 0, 0, tzinfo=UTC)


def _cell(
    cls: Literal["pass", "fail", "env", "build"] = "pass",
    passed: int = 1,
    runs: int = 1,
    reason: str = "",
    log: str = "mac/x/flutter.log",
) -> Cell:
    return Cell(cls=cls, passed=passed, runs=runs, reason=reason, log=log)


def test_rounds_root_defaults_under_the_repo_tmp_dir() -> None:
    assert ROUNDS_ROOT == REPO_ROOT / "tmp" / "e2e-rounds"
    assert rounds_root({}) == ROUNDS_ROOT


def test_rounds_root_honors_the_env_override(tmp_path: Path) -> None:
    assert rounds_root({ROUNDS_DIR_ENV: str(tmp_path)}) == tmp_path


def test_rounds_root_ignores_an_empty_override() -> None:
    assert rounds_root({ROUNDS_DIR_ENV: ""}) == ROUNDS_ROOT


def test_round_dir_name_is_utc_stamp(tmp_path: Path) -> None:
    made = RoundDir.create(tmp_path, _NOON)
    assert made.path == tmp_path / "20261023T120000Z"
    assert made.path.is_dir()


def test_round_dir_converts_a_local_clock_to_utc(tmp_path: Path) -> None:
    bangkok = timezone(timedelta(hours=7))
    made = RoundDir.create(tmp_path, datetime(2026, 10, 23, 19, 0, 0, tzinfo=bangkok))
    assert made.path.name == "20261023T120000Z"


def test_round_dir_refuses_a_naive_clock(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="timezone"):
        RoundDir.create(tmp_path, datetime(2026, 10, 23, 12, 0, 0))  # noqa: DTZ001


def test_round_dir_creates_missing_parents(tmp_path: Path) -> None:
    made = RoundDir.create(tmp_path / "tmp" / "e2e-rounds", _NOON)
    assert made.path.is_dir()


def test_same_second_rounds_get_distinct_dirs(tmp_path: Path) -> None:
    first = RoundDir.create(tmp_path, _NOON)
    second = RoundDir.create(tmp_path, _NOON)
    third = RoundDir.create(tmp_path, _NOON)
    assert [d.path.name for d in (first, second, third)] == [
        "20261023T120000Z",
        "20261023T120000Z-2",
        "20261023T120000Z-3",
    ]


def test_item_dir_is_created_and_stable_per_target_and_test(tmp_path: Path) -> None:
    made = RoundDir.create(tmp_path, _NOON)
    item = made.item_dir("pixel_8", "smoke/semantics_id_test.dart")
    assert item.is_dir()
    assert item.parent == made.path / "pixel_8"
    assert made.item_dir("pixel_8", "smoke/semantics_id_test.dart") == item


def test_item_dir_never_escapes_the_round_dir(tmp_path: Path) -> None:
    made = RoundDir.create(tmp_path, _NOON)
    item = made.item_dir("../evil", "../../etc/passwd")
    assert made.path in item.resolve().parents


def test_item_dir_keeps_names_that_sanitize_alike_apart(tmp_path: Path) -> None:
    made = RoundDir.create(tmp_path, _NOON)
    assert made.item_dir("mac", "t[a b]") != made.item_dir("mac", "t[a_b]")
    assert made.item_dir("mac", "a/b") != made.item_dir("mac", "a_b")


def test_item_dir_refuses_an_empty_name(tmp_path: Path) -> None:
    made = RoundDir.create(tmp_path, _NOON)
    with pytest.raises(ValueError, match="empty"):
        made.item_dir("mac", "")


def test_item_dir_shortens_a_long_name_and_keeps_two_long_names_apart(tmp_path: Path) -> None:
    made = RoundDir.create(tmp_path, _NOON)
    first = made.item_dir("mac", "x" * 400 + "a")
    second = made.item_dir("mac", "x" * 400 + "b")
    assert first != second
    assert len(first.name) < 200


def test_cell_text() -> None:
    assert cell_text(_cell("pass", 10, 10)) == "10/10"
    assert cell_text(_cell("pass", 1, 1)) == "1/1"
    assert cell_text(_cell("fail", 0, 1)) == "fail"
    assert cell_text(_cell("env", 0, 1)) == "env"
    assert cell_text(_cell("build", 0, 1)) == "build"
    assert cell_text(Cell("xfail", 0, 1, "known gap", "")) == "—"
    assert cell_text(Cell("xpass", 1, 1, "fix landed", "")) == "1/1"
    assert cell_text(None) == "—"


def test_cell_text_of_a_repeat_block_reads_n_over_N_whatever_its_class() -> None:
    assert cell_text(_cell("fail", 9, 10)) == "9/10 fail"
    assert cell_text(_cell("env", 0, 10)) == "0/10 env"
    assert cell_text(_cell("build", 0, 10)) == "0/10 build"
    assert cell_text(_cell("pass", 10, 10)) == "10/10"


def test_env_and_fail_repeat_cells_read_differently() -> None:
    assert cell_text(_cell("env", 0, 10)) != cell_text(_cell("fail", 0, 10))


def _recorder() -> Recorder:
    rec = Recorder()
    rec.target("mac", "macos", "macos", reused=False)
    rec.target("chrome", "web", "chrome", reused=False)
    return rec


def _write(tmp_path: Path, rec: Recorder, *, mode: str = "full", repeat: int = 10, wall: float = 12.5) -> RoundDir:
    made = RoundDir.create(tmp_path, _NOON)
    rec.write(made, mode, repeat, wall)
    return made


def test_summary_md_grid(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "smoke/a_test.dart", "integration", ["us01", "us02"], _cell("pass", 1, 1))
    rec.add("chrome", "smoke/a_test.dart", "integration", ["us01", "us02"], _cell("fail", 0, 1, "boom"))
    rec.add("mac", "tests/test_b.py::test_b", "e2e", [], _cell("pass", 10, 10))
    lines = (_write(tmp_path, rec).path / "summary.md").read_text(encoding="utf-8").splitlines()
    assert lines[0] == "| test | mac | chrome | stories |"
    assert lines[1].startswith("|") and set(lines[1]) <= set("|- ")
    assert "| smoke/a_test.dart | 1/1 | fail | us01, us02 |" in lines
    assert "| tests/test_b.py::test_b | 10/10 | — |  |" in lines


def test_summary_md_lists_the_reason_of_each_failing_or_env_cell(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.dart", "integration", [], _cell("pass"))
    rec.add("chrome", "t.dart", "integration", [], _cell("env", 0, 1, "env: target blocked", "chrome/t/flutter.log"))
    rec.add("mac", "u.dart", "integration", [], _cell("fail", 0, 1, "expected 1 got 2", "mac/u/flutter.log"))
    text = (_write(tmp_path, rec).path / "summary.md").read_text(encoding="utf-8")
    assert "- `t.dart` on `chrome` [env]: env: target blocked (chrome/t/flutter.log)" in text
    assert "- `u.dart` on `mac` [fail]: expected 1 got 2 (mac/u/flutter.log)" in text
    assert text.count("on `mac`") == 1


def test_an_expected_failure_reads_no_cell_and_keeps_its_reason(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.py::gap", "e2e", [], Cell("xfail", 0, 1, "known gap", "mac/gap/pytest.log"))
    rec.add("mac", "t.py::fixed", "e2e", [], Cell("xpass", 1, 1, "fix landed", "mac/fixed/pytest.log"))
    made = _write(tmp_path, rec)
    lines = (made.path / "summary.md").read_text(encoding="utf-8").splitlines()
    assert "| t.py::gap | — | — |  |" in lines
    assert "| t.py::fixed | 1/1 | — |  |" in lines
    assert "- `t.py::gap` on `mac` [xfail]: known gap (mac/gap/pytest.log)" in lines
    assert "- `t.py::fixed` on `mac` [xpass]: fix landed (mac/fixed/pytest.log)" in lines
    data = json.loads((made.path / "summary.json").read_text(encoding="utf-8"))
    assert [row["cells"]["mac"]["class"] for row in data["rows"]] == ["xfail", "xpass"]


def test_summary_md_without_a_failure_has_no_reason_list(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.dart", "integration", [], _cell("pass"))
    text = (_write(tmp_path, rec).path / "summary.md").read_text(encoding="utf-8")
    assert "- `" not in text


def test_summary_md_escapes_a_pipe_in_a_test_name(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.py::test[a|b]", "e2e", [], _cell("pass"))
    text = (_write(tmp_path, rec).path / "summary.md").read_text(encoding="utf-8")
    assert "| t.py::test[a\\|b] | 1/1 | — |  |" in text


def test_summary_json_holds_builds_and_wall_time(tmp_path: Path) -> None:
    rec = _recorder()
    rec.build("mac", ["flutter", "build", "macos", "--debug"], 3.5, reused=False, ok=False)
    rec.build("mac", ["flutter", "build", "macos", "--debug"], 41.5, reused=False)
    rec.add("mac", "smoke/a_test.dart", "integration", ["us01"], _cell("pass", 1, 1, "", "mac/a/flutter.log"))
    data = json.loads((_write(tmp_path, rec).path / "summary.json").read_text(encoding="utf-8"))
    assert data["round"] == "20261023T120000Z"
    assert (data["mode"], data["repeat"], data["wall_seconds"]) == ("full", 10, 12.5)
    assert data["builds"] == [
        {"target": "mac", "command": ["flutter", "build", "macos", "--debug"], "seconds": 3.5, "reused": False,
         "ok": False},
        {"target": "mac", "command": ["flutter", "build", "macos", "--debug"], "seconds": 41.5, "reused": False,
         "ok": True},
    ]
    assert data["rows"] == [
        {
            "test": "smoke/a_test.dart",
            "kind": "integration",
            "stories": ["us01"],
            "cells": {"mac": {"class": "pass", "passed": 1, "runs": 1, "reason": "", "log": "mac/a/flutter.log"}},
        }
    ]
    assert "engine" not in json.dumps(data)


def test_reused_target_is_recorded(tmp_path: Path) -> None:
    rec = Recorder()
    rec.target("pixel_8", "android", "emulator-5556", reused=True)
    data = json.loads((_write(tmp_path, rec).path / "summary.json").read_text(encoding="utf-8"))
    assert data["targets"] == [
        {
            "name": "pixel_8", "platform": "android", "device": "emulator-5556", "reused": True,
            "setting_failures": [], "teardown_failures": [],
        }
    ]
    assert data["targets"][0]["reused"] is True


def test_teardown_failures_reach_both_summaries_and_outlive_a_later_target_call(tmp_path: Path) -> None:
    rec = Recorder()
    rec.target("iphone", "ios", "udid-1", reused=False)
    rec.target("mac", "macos", "mac", reused=False)
    failure = "shutdown failed: simctl shutdown udid-1 failed (status 1): busy"
    rec.teardown_failure("iphone", failure)
    rec.target("iphone", "ios", "udid-1", reused=False, setting_failures=["s"])
    made = _write(tmp_path, rec)
    data = json.loads((made.path / "summary.json").read_text(encoding="utf-8"))
    assert [t["teardown_failures"] for t in data["targets"]] == [[failure], []]
    text = (made.path / "summary.md").read_text(encoding="utf-8")
    assert f"- teardown of `iphone`: {failure}" in text
    assert "teardown of `mac`" not in text


def test_teardown_failure_for_an_unknown_target_is_refused() -> None:
    with pytest.raises(ValueError, match="iphone"):
        Recorder().teardown_failure("iphone", "shutdown failed: x")


def test_setting_failures_reach_both_summaries(tmp_path: Path) -> None:
    rec = Recorder()
    rec.target("pixel_8", "android", "emulator-5556", reused=False)
    failures = [
        "global window_animation_scale 0 (status 255: denied)",
        "secure show_ime_with_hard_keyboard 1 (status 1: )",
    ]
    rec.target("pixel_8", "android", "emulator-5556", reused=False, setting_failures=failures)
    rec.target("mac", "macos", "mac", reused=False)
    made = _write(tmp_path, rec)
    data = json.loads((made.path / "summary.json").read_text(encoding="utf-8"))
    assert [t["setting_failures"] for t in data["targets"]] == [failures, []]
    text = (made.path / "summary.md").read_text(encoding="utf-8")
    assert f"- boot setting on `pixel_8` failed: {failures[0]}" in text
    assert f"- boot setting on `pixel_8` failed: {failures[1]}" in text
    assert "`mac` failed" not in text


def test_targets_keep_round_order_and_a_second_call_updates_in_place(tmp_path: Path) -> None:
    rec = Recorder()
    rec.target("b", "web", "chrome", reused=False)
    rec.target("a", "macos", "macos", reused=False)
    rec.target("b", "web", "chrome", reused=True)
    data = json.loads((_write(tmp_path, rec).path / "summary.json").read_text(encoding="utf-8"))
    assert [(t["name"], t["reused"]) for t in data["targets"]] == [("b", True), ("a", False)]


def test_rows_keep_first_seen_order_across_targets(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "b.dart", "integration", [], _cell())
    rec.add("mac", "a.dart", "integration", [], _cell())
    rec.add("chrome", "b.dart", "integration", [], _cell())
    data = json.loads((_write(tmp_path, rec).path / "summary.json").read_text(encoding="utf-8"))
    assert [r["test"] for r in data["rows"]] == ["b.dart", "a.dart"]
    assert list(data["rows"][0]["cells"]) == ["mac", "chrome"]


def test_add_for_an_unknown_target_is_refused() -> None:
    with pytest.raises(ValueError, match="pixel_8"):
        _recorder().add("pixel_8", "t.dart", "integration", [], _cell())


def test_add_with_a_different_kind_for_one_test_is_refused() -> None:
    rec = _recorder()
    rec.add("mac", "t", "integration", [], _cell())
    with pytest.raises(ValueError, match="kind"):
        rec.add("chrome", "t", "e2e", [], _cell())


def test_add_with_different_stories_for_one_test_is_refused() -> None:
    rec = _recorder()
    rec.add("mac", "t", "integration", ["us01"], _cell())
    with pytest.raises(ValueError, match="stories"):
        rec.add("chrome", "t", "integration", ["us02"], _cell())


def test_a_second_add_for_one_cell_replaces_it_in_place(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t", "integration", [], _cell("env", 0, 1, "lane busy"))
    rec.add("mac", "t", "integration", [], _cell("pass"))
    data = json.loads((_write(tmp_path, rec).path / "summary.json").read_text(encoding="utf-8"))
    assert [r["cells"]["mac"]["class"] for r in data["rows"]] == ["pass"]


def test_build_for_an_unknown_target_is_refused() -> None:
    with pytest.raises(ValueError, match="pixel_8"):
        _recorder().build("pixel_8", ["flutter"], 1.0, reused=False)


def test_retry_once_then_block() -> None:
    ledger = RetryLedger()
    assert ledger.blocked("pixel_8") is False
    assert ledger.record_env("pixel_8", "smoke/a_test.dart") == "retry"
    assert ledger.blocked("pixel_8") is False
    assert ledger.record_env("pixel_8", "smoke/a_test.dart") == "block"
    assert ledger.blocked("pixel_8") is True
    assert ledger.blocked("mac") is False


def test_a_block_stays_after_more_env_results() -> None:
    ledger = RetryLedger()
    for _ in range(2):
        ledger.record_env("pixel_8", "a")
    assert ledger.record_env("pixel_8", "a") == "block"
    assert ledger.blocked("pixel_8") is True


def test_block_on_one_file_does_not_need_two_env_on_another() -> None:
    ledger = RetryLedger()
    assert ledger.record_env("pixel_8", "a.dart") == "retry"
    assert ledger.record_env("pixel_8", "b.dart") == "retry"
    assert ledger.blocked("pixel_8") is False
    assert ledger.record_env("pixel_8", "a.dart") == "block"


def test_same_key_on_two_targets_is_counted_apart() -> None:
    ledger = RetryLedger()
    assert ledger.record_env("pixel_8", "a.dart") == "retry"
    assert ledger.record_env("mac", "a.dart") == "retry"
    assert ledger.blocked("mac") is False


def test_reason_line_shows_the_class_when_the_reason_has_no_env_prefix(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.dart", "integration", [], _cell("env", 0, 1, "install failed", "mac/t/flutter.log"))
    text = (_write(tmp_path, rec).path / "summary.md").read_text(encoding="utf-8")
    assert "- `t.dart` on `mac` [env]: install failed (mac/t/flutter.log)" in text


def test_reason_line_without_a_reason_or_log_is_just_the_class(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.dart", "integration", [], _cell("fail", 0, 1, "", ""))
    text = (_write(tmp_path, rec).path / "summary.md").read_text(encoding="utf-8")
    assert "- `t.dart` on `mac` [fail]\n" in text


def test_summary_json_keeps_fail_and_env_classes_apart(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.dart", "integration", [], _cell("fail", 0, 1, "boom"))
    rec.add("chrome", "t.dart", "integration", [], _cell("env", 0, 1, "install failed"))
    data = json.loads((_write(tmp_path, rec).path / "summary.json").read_text(encoding="utf-8"))
    cells = data["rows"][0]["cells"]
    assert (cells["mac"]["class"], cells["chrome"]["class"]) == ("fail", "env")


def test_record_env_for_a_blocked_target_blocks_a_new_key() -> None:
    ledger = RetryLedger()
    ledger.record_env("pixel_8", "a.dart")
    ledger.record_env("pixel_8", "a.dart")
    assert ledger.record_env("pixel_8", "b.dart") == "block"
    assert ledger.record_env("mac", "b.dart") == "retry"


@pytest.mark.parametrize(
    ("cls", "passed", "runs"),
    [
        ("pass", 1, 0),
        ("fail", 0, 0),
        ("pass", 9, 10),
        ("pass", 0, 1),
        ("fail", 10, 10),
        ("fail", 1, 1),
        ("env", 1, 1),
        ("env", 3, 3),
    ],
)
def test_cell_rejects_incoherent_values(cls: Literal["pass", "fail", "env"], passed: int, runs: int) -> None:
    with pytest.raises(ValueError, match="cell"):
        Cell(cls=cls, passed=passed, runs=runs, reason="", log="")


def test_write_leaves_no_temp_file(tmp_path: Path) -> None:
    rec = _recorder()
    rec.add("mac", "t.dart", "integration", [], _cell())
    made = _write(tmp_path, rec)
    assert sorted(p.name for p in made.path.iterdir()) == ["summary.json", "summary.md"]


def test_write_replaces_an_earlier_summary(tmp_path: Path) -> None:
    rec = _recorder()
    made = RoundDir.create(tmp_path, _NOON)
    rec.add("mac", "t.dart", "integration", [], _cell("env", 0, 1, "x"))
    rec.write(made, "full", 1, 1.0)
    rec.add("mac", "t.dart", "integration", [], _cell("pass"))
    rec.write(made, "full", 1, 2.0)
    data = json.loads((made.path / "summary.json").read_text(encoding="utf-8"))
    assert data["wall_seconds"] == 2.0
    assert data["rows"][0]["cells"]["mac"]["class"] == "pass"
    assert sorted(p.name for p in made.path.iterdir()) == ["summary.json", "summary.md"]


def test_summary_md_lists_reused_targets_above_the_grid(tmp_path: Path) -> None:
    rec = Recorder()
    rec.target("pixel_8", "android", "emulator-5556", reused=True)
    rec.target("chrome", "web", "chrome", reused=False)
    rec.target("mac", "macos", "macos", reused=True)
    lines = (_write(tmp_path, rec).path / "summary.md").read_text(encoding="utf-8").splitlines()
    assert lines[:3] == ["Reused: pixel_8, mac", "", "| test | pixel_8 | chrome | mac | stories |"]


def test_summary_md_has_no_reused_line_when_nothing_is_reused(tmp_path: Path) -> None:
    text = (_write(tmp_path, _recorder()).path / "summary.md").read_text(encoding="utf-8")
    assert "Reused" not in text
