"""The round's output: one round dir with `summary.md`, `summary.json`, the per-item logs, and the retry ledger.

Design section 10 owns the grid and its classes; C9 owns the retry rule. A cell is keyed by target name, because
`Target` is not hashable.
"""

from __future__ import annotations

import hashlib
import json
import os
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal
from urllib.parse import quote

from stratum_e2e.paths import E2E_ROOT

ROUNDS_ROOT = E2E_ROOT.parent / "tmp" / "e2e-rounds"
ROUNDS_DIR_ENV = "STRATUM_E2E_ROUNDS_DIR"

SUMMARY_MD = "summary.md"
SUMMARY_JSON = "summary.json"

NO_CELL = "—"

_STAMP_FORMAT = "%Y%m%dT%H%M%SZ"
_MAX_SEGMENT = 120
_HASH_LENGTH = 12
_BLOCK_AT = 2

CellClass = Literal["pass", "fail", "env"]
ItemKind = Literal["integration", "e2e", "perf"]


def rounds_root(environ: Mapping[str, str] = os.environ) -> Path:
    """Return the folder that holds the round dirs: the env override when set and non-empty, else `ROUNDS_ROOT`."""
    override = environ.get(ROUNDS_DIR_ENV, "")
    return Path(override) if override else ROUNDS_ROOT


def _segment(name: str) -> str:
    """Encode `name` as one path segment that never climbs out of its parent and never merges with another name."""
    if not name:
        raise ValueError("an item dir name must not be empty")
    encoded = quote(name, safe="").replace(".", "%2E")
    if len(encoded) <= _MAX_SEGMENT:
        return encoded
    digest = hashlib.sha256(name.encode("utf-8")).hexdigest()[:_HASH_LENGTH]
    return f"{encoded[: _MAX_SEGMENT - _HASH_LENGTH - 1]}-{digest}"


@dataclass(frozen=True)
class RoundDir:
    """One round's output folder, named by the UTC second the round started."""

    path: Path

    @classmethod
    def create(cls, root: Path, now: datetime) -> RoundDir:
        """Create `root/<UTC stamp>`; a name another round took gets `-2`, `-3`, and so on."""
        if now.tzinfo is None:
            raise ValueError("a round starts at a timezone-aware datetime")
        stamp = now.astimezone(UTC).strftime(_STAMP_FORMAT)
        root.mkdir(parents=True, exist_ok=True)
        attempt = 1
        while True:
            name = stamp if attempt == 1 else f"{stamp}-{attempt}"
            try:
                (root / name).mkdir()
            except FileExistsError:
                attempt += 1
                continue
            return cls(root / name)

    def item_dir(self, target: str, test: str) -> Path:
        """Create and return the folder for one target's run of one test; it holds that item's logs."""
        folder = self.path / _segment(target) / _segment(test)
        folder.mkdir(parents=True, exist_ok=True)
        return folder


@dataclass(frozen=True)
class Cell:
    """One test on one target: its class, how many of its runs passed, why it did not, and where its log is."""

    cls: CellClass
    passed: int
    runs: int
    reason: str
    log: str

    def __post_init__(self) -> None:
        if self.runs < 1:
            raise ValueError(f"a cell holds at least one run, got runs={self.runs}")
        if self.cls == "pass" and self.passed != self.runs:
            raise ValueError(f"a pass cell passes every run, got {self.passed}/{self.runs}")
        if self.cls != "pass" and self.passed == self.runs:
            raise ValueError(f"a {self.cls} cell cannot pass every run, got {self.passed}/{self.runs}")


def cell_text(cell: Cell | None) -> str:
    """Return the grid text of a cell.

    A pass reads `n/N`. A repeat block that did not pass reads `n/N` and its class (`0/10 env`, `7/10 fail`), so a
    tool failure never looks like a widget result. A single run that did not pass reads `fail` or `env`; none is `—`.
    """
    if cell is None:
        return NO_CELL
    if cell.cls == "pass":
        return f"{cell.passed}/{cell.runs}"
    if cell.runs > 1:
        return f"{cell.passed}/{cell.runs} {cell.cls}"
    return cell.cls


@dataclass
class _Row:
    kind: ItemKind
    stories: tuple[str, ...]
    cells: dict[str, Cell]


@dataclass(frozen=True)
class _Target:
    name: str
    platform: str
    device_id: str
    reused: bool
    setting_failures: tuple[str, ...]


@dataclass(frozen=True)
class _Build:
    target: str
    command: tuple[str, ...]
    seconds: float
    reused: bool


class Recorder:
    """Collects what the round ran, in the order it ran it, and writes the summary files at the end."""

    def __init__(self) -> None:
        self._targets: dict[str, _Target] = {}
        self._builds: list[_Build] = []
        self._rows: dict[str, _Row] = {}

    def target(
        self, name: str, platform: str, device_id: str, reused: bool, setting_failures: Sequence[str] = ()
    ) -> None:
        """Record a target and the boot settings that failed to apply or restore on it.

        A repeat call for one name updates it and keeps its column.
        """
        self._targets[name] = _Target(name, platform, device_id, reused, tuple(setting_failures))

    def build(self, target: str, argv: Sequence[str], seconds: float, reused: bool) -> None:
        """Record one app build or integration run command and how long it took."""
        self._require_target(target)
        self._builds.append(_Build(target, tuple(argv), seconds, reused))

    def add(self, target: str, test: str, kind: ItemKind, stories: Sequence[str], cell: Cell) -> None:
        """Record one test's result on one target; a second call for the same cell replaces it."""
        self._require_target(target)
        row = self._rows.get(test)
        if row is None:
            row = self._rows[test] = _Row(kind, tuple(stories), {})
        elif row.kind != kind:
            raise ValueError(f"{test}: kind {kind} contradicts the recorded kind {row.kind}")
        elif row.stories != tuple(stories):
            raise ValueError(f"{test}: stories {list(stories)} contradict the recorded stories {list(row.stories)}")
        row.cells[target] = cell

    def write(self, round_dir: RoundDir, mode: str, repeat: int, wall_seconds: float) -> None:
        """Write `summary.md` and `summary.json` into the round dir."""
        data = self._data(round_dir.path.name, mode, repeat, wall_seconds)
        text = json.dumps(data, indent=2, ensure_ascii=False)
        _write_atomically(round_dir.path / SUMMARY_MD, self._markdown())
        _write_atomically(round_dir.path / SUMMARY_JSON, text + "\n")

    def _require_target(self, name: str) -> None:
        if name not in self._targets:
            raise ValueError(f"unknown target {name}; record it with target() first")

    def _markdown(self) -> str:
        names = list(self._targets)
        header = ["test", *names, "stories"]
        lines = [_md_row(header), _md_row(["---"] * len(header))]
        reused = [t.name for t in self._targets.values() if t.reused]
        if reused:
            lines = [f"Reused: {', '.join(reused)}", "", *lines]
        reasons: list[str] = []
        for test, row in self._rows.items():
            texts = [cell_text(row.cells.get(name)) for name in names]
            lines.append(_md_row([test, *texts, ", ".join(row.stories)]))
            for name in names:
                cell = row.cells.get(name)
                if cell is not None and cell.cls != "pass":
                    reasons.append(_reason_line(test, name, cell))
        settings = [
            f"- boot setting on `{t.name}` failed: {failure}"
            for t in self._targets.values()
            for failure in t.setting_failures
        ]
        if reasons or settings:
            lines += ["", *reasons, *settings]
        return "\n".join(lines) + "\n"

    def _data(self, stamp: str, mode: str, repeat: int, wall_seconds: float) -> dict[str, object]:
        names = list(self._targets)
        return {
            "round": stamp,
            "mode": mode,
            "repeat": repeat,
            "wall_seconds": wall_seconds,
            "targets": [
                {
                    "name": t.name,
                    "platform": t.platform,
                    "device": t.device_id,
                    "reused": t.reused,
                    "setting_failures": list(t.setting_failures),
                }
                for t in self._targets.values()
            ],
            "builds": [
                {"target": b.target, "command": list(b.command), "seconds": b.seconds, "reused": b.reused}
                for b in self._builds
            ],
            "rows": [
                {
                    "test": test,
                    "kind": row.kind,
                    "stories": list(row.stories),
                    "cells": {
                        name: {
                            "class": row.cells[name].cls,
                            "passed": row.cells[name].passed,
                            "runs": row.cells[name].runs,
                            "reason": row.cells[name].reason,
                            "log": row.cells[name].log,
                        }
                        for name in names
                        if name in row.cells
                    },
                }
                for test, row in self._rows.items()
            ],
        }


def _md_row(cells: Sequence[str]) -> str:
    return "| " + " | ".join(cell.replace("|", "\\|") for cell in cells) + " |"


def _write_atomically(path: Path, text: str) -> None:
    """Write `text` to a temp name beside `path`, then replace `path`, so a reader never sees half a file."""
    temp = path.with_name(f".{path.name}.tmp")
    temp.write_text(text, encoding="utf-8")
    temp.replace(path)


def _reason_line(test: str, target: str, cell: Cell) -> str:
    line = f"- `{test}` on `{target}` [{cell.cls}]"
    if cell.reason:
        line += f": {cell.reason}"
    return f"{line} ({cell.log})" if cell.log else line


class RetryLedger:
    """Counts `env` results per target and key: the first retries, the second blocks the target (C9)."""

    def __init__(self) -> None:
        self._env_counts: dict[tuple[str, str], int] = {}
        self._blocked: set[str] = set()

    def record_env(self, target: str, key: str) -> Literal["retry", "block"]:
        """Record one `env` result; the second on one (target, key) blocks the target for the rest of the round."""
        if target in self._blocked:
            return "block"
        count = self._env_counts.get((target, key), 0) + 1
        self._env_counts[(target, key)] = count
        if count >= _BLOCK_AT:
            self._blocked.add(target)
            return "block"
        return "retry"

    def blocked(self, target: str) -> bool:
        """Whether a second `env` has stopped this target's remaining items."""
        return target in self._blocked
