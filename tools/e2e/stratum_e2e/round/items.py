"""Per-item helpers of the device round: the e2e retry rule, the device log and screenshot, and each item's summary
cell and log (design section 10, C9)."""

from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime
from pathlib import Path
from typing import Final

import pytest

from stratum_e2e.paths import scope_key
from stratum_e2e.round.capture import save_device_log, save_screenshot
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.collect import is_integration, item_params
from stratum_e2e.round.integration_run import LOG_NAME
from stratum_e2e.round.results import Cell, CellClass, ItemKind
from stratum_e2e.round.state import DEVICE_LOG, RoundState

# The report properties `pytest_runtest_makereport` writes and `_outcome` reads; a `build` names its build log.
CLASS_PROPERTY: Final = "round_class"
REASON_PROPERTY: Final = "round_reason"
LOG_PROPERTY: Final = "round_log"
# The classes a failed phase reads besides `fail`.
_FAILED_CLASSES: Final[dict[str, CellClass]] = {"env": "env", "build": "build"}
# When the item's setup began, so its device log starts there.
SINCE_KEY: Final = pytest.StashKey[datetime]()

_ITEM_LOG: Final = "pytest.log"
_SCREENSHOT: Final = "screenshot.png"
_REASON_CHARS: Final = 300


def retryable(item: pytest.Item, state: RoundState, target: Target, reports: Sequence[pytest.TestReport]) -> bool:
    """Whether this run of an e2e item ended `env` on its own, not because its target is down or blocked."""
    if is_integration(item) or target.name in state.down or state.ledger.blocked(target.name):
        return False
    outcome = _outcome(reports)
    return outcome is not None and outcome[0] == "env"


def capture_item(state: RoundState, item: pytest.Item, target: Target, *, failed: bool) -> None:
    """Keep the device log since the item's setup began and, on failure, a screenshot, in the item's dir."""
    brought_up = state.live.get(target.name)
    if brought_up is None or state.round_dir is None or state.backends is None:
        return
    item_dir = state.round_dir.item_dir(target.name, _test_name(item, target))
    since = item.stash.get(SINCE_KEY, None) or state.backends.now()
    save_device_log(state.backends.runner, brought_up.record, since, item_dir / DEVICE_LOG)
    if failed:
        save_screenshot(state.backends.runner, brought_up.record, item_dir / _SCREENSHOT)


def record_item(
    state: RoundState, item: pytest.Item, target: Target, runs: Sequence[Sequence[pytest.TestReport]]
) -> None:
    """Record the cell of the item's last run; an e2e item's log holds the reports of every run."""
    if state.round_dir is None:
        return
    test = _test_name(item, target)
    file = item_params(item).get("integration_file")
    if isinstance(file, str):
        result = state.outcomes.get(target.name, {}).get(file)
        run_dir = state.run_dirs.get((target.name, file))
        log_name = result.log if result is not None else LOG_NAME
        log = state.relative(run_dir / log_name) if run_dir is not None else ""
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
    """The cell of one run: `env`, `build`, or `fail` from its first failed phase, `pass`, or `None` for a skipped
    item. A `build` cell's log is the build log.

    An item pytest expected to fail gets its row too, its reason the expectation's: `xfail` when it failed, `xpass`
    when it passed. A strict unexpected pass is a failed phase, so it reads `fail`.
    """
    outcome = _outcome(reports)
    if outcome is not None:
        cls, reason, outcome_log = outcome
        return Cell(_FAILED_CLASSES.get(cls, "fail"), 0, 1, reason, outcome_log or log)
    expected = next((report for report in reports if hasattr(report, "wasxfail")), None)
    if expected is not None:
        if expected.skipped:
            return Cell("xfail", 0, 1, str(expected.wasxfail), log)
        return Cell("xpass", 1, 1, str(expected.wasxfail), log)
    if any(report.skipped for report in reports):
        return None
    return Cell("pass", 1, 1, "", log)


def _outcome(reports: Sequence[pytest.TestReport]) -> tuple[str, str, str] | None:
    """The class, reason, and own log (empty for none) of the first failed phase of one run; `None` when no phase
    failed."""
    for report in reports:
        if report.failed:
            properties = dict(report.user_properties)
            return (
                str(properties.get(CLASS_PROPERTY, "fail")),
                str(properties.get(REASON_PROPERTY, "")),
                str(properties.get(LOG_PROPERTY, "")),
            )
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
    file = item_params(item).get("integration_file")
    if isinstance(file, str):
        return file
    name = f"{module_key(item)}::{getattr(item, 'originalname', item.name)}"
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


def module_key(item: pytest.Item) -> str:
    """The item's module path under its scope root, the key of the e2e retry rule."""
    return scope_key(Path(str(item.path)))


def first_line(text: str) -> str:
    line = next((line for line in text.splitlines() if line.strip()), "")
    return line[:_REASON_CHARS]
