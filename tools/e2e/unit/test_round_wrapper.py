"""Behaviour of the `tools/e2e/round` wrapper, driven as a real subprocess.

Every run is `--collect-only -q` with no `--target` or `--platform`, so no device, Appium, or emulator starts.
Set `E2E_ROUND_BASELINE_DIR` to a folder holding `nodes-e2e.txt` and `nodes-unit.txt` (pytest `--collect-only -q`
output from before the layout move) to also compare the collected node lists with that baseline.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

from stratum_e2e.paths import E2E_ROOT, PLAYWRIGHT_BROWSERS_DIR, REPO_ROOT

WRAPPER = E2E_ROOT / "round"
SUITE_PREFIX = re.compile(r"^.*?(?=(?:common|feedback|perf|smoke|themes|integration|unit)/)")
NODE_LINE = re.compile(r"^(?:tests/|e2e/|tools/e2e/)?(?:common|feedback|perf|smoke|themes|integration|unit)/[\w./-]+\.py::")
SUMMARY = re.compile(r"^\d+(?:/\d+)? tests? collected")
BASELINE_DIR = os.environ.get("E2E_ROUND_BASELINE_DIR")


def collect(*args: str, wrapper: Path = WRAPPER) -> tuple[list[str], str]:
    """Run the wrapper with `--collect-only -q`; return its node ids (prefix-normalised) and the summary line."""
    done = subprocess.run(
        [str(wrapper), *args, "--collect-only", "-q"],
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


def test_unit_then_a_path_narrows_the_unit_dir() -> None:
    nodes, _ = collect("unit", "tools/e2e/unit/test_paths.py")
    assert nodes
    assert all(node.startswith("unit/test_paths.py::") for node in nodes)


def test_empty_string_argument_is_dropped() -> None:
    # pytest reads "" as the cwd, which would suppress the default suites and add the unit suite.
    _, summary = collect("")
    _, default_summary = collect()
    assert count_of(summary) == count_of(default_summary)


def test_wrapper_through_a_symlink_finds_its_own_folder(tmp_path: Path) -> None:
    link = tmp_path / "round"
    link.symlink_to(WRAPPER)
    nodes, summary = collect(wrapper=link)
    assert any(node.startswith("common/test_") for node in nodes)
    assert count_of(summary) == count_of(collect()[1])


def test_setup_through_a_symlink_checks_its_own_toolchain(tmp_path: Path) -> None:
    link = tmp_path / "setup.sh"
    link.symlink_to(E2E_ROOT / "setup.sh")
    direct = subprocess.run([str(E2E_ROOT / "setup.sh"), "--check"], capture_output=True, text=True, timeout=120, check=False)
    linked = subprocess.run([str(link), "--check"], capture_output=True, text=True, timeout=120, check=False)
    assert linked.stdout == direct.stdout
    assert linked.returncode == direct.returncode


def test_setup_installs_firefox_where_the_harness_points_playwright() -> None:
    assert 'BROWSERS_DIR="${TOOLS_DIR}/ms-playwright"' in (E2E_ROOT / "setup.sh").read_text()
    assert PLAYWRIGHT_BROWSERS_DIR == E2E_ROOT / ".tools" / "ms-playwright"
    assert "/tools/e2e/.tools/ms-playwright/" in (REPO_ROOT / ".gitignore").read_text().splitlines()


@pytest.mark.skipif(sys.platform != "darwin", reason="macOS volumes are case-insensitive by default")
def test_working_directory_typed_in_other_case_keeps_defaults() -> None:
    # Bash keeps the typed case in `pwd -P` while pytest reads the real case from `os.getcwd()`.
    typed = Path(str(REPO_ROOT).swapcase())
    if not typed.exists() or not typed.samefile(REPO_ROOT):
        pytest.skip("this volume is case-sensitive")
    done = subprocess.run(
        ["bash", "-c", 'cd "$1" && exec tools/e2e/round --collect-only -q', "bash", str(typed)],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    summary = next(line for line in done.stdout.splitlines() if SUMMARY.match(line))
    assert done.returncode == 0, done.stdout + done.stderr
    assert count_of(summary) == count_of(collect()[1])
