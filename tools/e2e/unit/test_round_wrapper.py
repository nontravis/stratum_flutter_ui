"""Behaviour of the `tools/e2e/round` wrapper, driven as a real subprocess.

Every run is `--collect-only -q` with no `--target` or `--platform`, so no device, Appium, or emulator starts.
Set `E2E_ROUND_BASELINE_DIR` to a folder holding `nodes-e2e.txt` and `nodes-unit.txt` (pytest `--collect-only -q`
output from before the layout move) to also compare the collected node lists with that baseline.
"""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import pytest

from stratum_e2e.paths import E2E_ROOT, REPO_ROOT

WRAPPER = E2E_ROOT / "round"
SUITE_PREFIX = re.compile(r"^.*?(?=(?:common|feedback|perf|smoke|themes|integration|unit)/)")
NODE_LINE = re.compile(r"^(?:tests/|e2e/|tools/e2e/)?(?:common|feedback|perf|smoke|themes|integration|unit)/[\w./-]+\.py::")
SUMMARY = re.compile(r"^\d+(?:/\d+)? tests? collected")
BASELINE_DIR = os.environ.get("E2E_ROUND_BASELINE_DIR")


def collect(*args: str) -> tuple[list[str], str]:
    """Run the wrapper with `--collect-only -q`; return its node ids (prefix-normalised) and the summary line."""
    done = subprocess.run(
        [str(WRAPPER), *args, "--collect-only", "-q"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    assert done.returncode == 0, done.stdout + done.stderr
    lines = [line for line in done.stdout.splitlines() if line.strip()]
    nodes = [SUITE_PREFIX.sub("", line, count=1) for line in lines if NODE_LINE.match(line)]
    summary = next(line for line in lines if SUMMARY.match(line))
    return nodes, summary


def node_functions(nodes: list[str]) -> set[str]:
    """Node ids cut at the first `[`: a parametrised id can hold newlines that `-q` splits over several lines."""
    return {node.split("[", 1)[0] for node in nodes}


def baseline_nodes(name: str) -> list[str]:
    assert BASELINE_DIR is not None
    lines = (Path(BASELINE_DIR) / name).read_text().splitlines()
    return [SUITE_PREFIX.sub("", line, count=1) for line in lines if NODE_LINE.match(line)]


def count_of(summary: str) -> str:
    return summary.split(" in ")[0]


def test_no_args_collects_e2e_and_integration_item() -> None:
    nodes, summary = collect()
    assert any(node.startswith("common/test_") for node in nodes)
    assert any(node.startswith("integration/test_integration.py::") for node in nodes)
    assert not any(node.startswith("unit/") for node in nodes)
    if BASELINE_DIR is not None:
        assert node_functions(nodes) == node_functions(baseline_nodes("nodes-e2e.txt"))
        baseline_summary = next(
            line for line in (Path(BASELINE_DIR) / "nodes-e2e.txt").read_text().splitlines() if SUMMARY.match(line)
        )
        assert count_of(summary) == count_of(baseline_summary)


def test_one_path_collects_only_that_path() -> None:
    nodes, _ = collect("e2e/smoke")
    assert nodes
    assert all(node.startswith("smoke/") for node in nodes)


def test_unit_collects_the_unit_dir() -> None:
    nodes, _ = collect("unit")
    assert any(node.startswith("unit/test_paths.py::") for node in nodes)
    assert not any(node.startswith(("common/", "integration/")) for node in nodes)
    if BASELINE_DIR is not None:
        assert node_functions(baseline_nodes("nodes-unit.txt")) <= node_functions(nodes)


def test_unit_in_front_of_an_option_value_is_still_the_unit_dir() -> None:
    nodes, _ = collect("unit", "-k", "paths")
    assert nodes
    assert all(node.startswith("unit/") for node in nodes)


@pytest.mark.parametrize("option", ["--app", "--app-id", "--device"])
def test_option_value_path_keeps_defaults(option: str) -> None:
    # A collect-only run never reads these options; the values only have to be parsed as option values.
    nodes, _ = collect(option, "/tmp/x.apk")
    assert any(node.startswith("common/test_") for node in nodes)
    assert any(node.startswith("integration/test_integration.py::") for node in nodes)


def test_option_equals_value_keeps_defaults() -> None:
    nodes, _ = collect("--app=/tmp/x.apk")
    assert any(node.startswith("common/test_") for node in nodes)


def test_node_id_path_arg_replaces_defaults() -> None:
    nodes, _ = collect("e2e/smoke", "--app", "/tmp/x.apk")
    assert nodes
    assert all(node.startswith("smoke/") for node in nodes)
