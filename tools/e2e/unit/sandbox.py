"""The pytester sandbox that mirrors the repo layout the e2e plugins read their scope roots from.

`stratum_e2e.paths` derives its roots from where the package sits, so a sandbox holds a copy of the package at
`tools/e2e/` and the e2e test folders at `e2e/`, as the repo does. The copied `pytest.ini` loads the plugins by `-p`,
which imports before `pythonpath` applies, so the sandbox sets `PYTHONPATH` to its own `tools/e2e/`.
"""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

HARNESS_SOURCE = Path(__file__).resolve().parents[1]
INI = "tools/e2e/pytest.ini"
INTEGRATION_ITEM = "tools/e2e/integration/test_integration.py"


def build_sandbox(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch, *, plugin: str | None = None) -> Path:
    """Copy the harness into `<sandbox>/tools/e2e` and return it; the process moves to the sandbox root.

    [plugin] names a module of that folder, loaded last by `-p`, so its fixtures override the real ones.
    """
    harness = pytester.path / "tools" / "e2e"
    harness.mkdir(parents=True)
    shutil.copy(HARNESS_SOURCE / "pytest.ini", harness / "pytest.ini")
    shutil.copytree(HARNESS_SOURCE / "stratum_e2e", harness / "stratum_e2e", ignore=shutil.ignore_patterns("__pycache__"))
    suite_dir(pytester).mkdir()
    monkeypatch.chdir(pytester.path)
    monkeypatch.setenv("PYTHONPATH", str(harness))
    if plugin is not None:
        monkeypatch.setenv("PYTEST_ADDOPTS", f"-p {plugin}")
    return harness


def suite_dir(pytester: pytest.Pytester) -> Path:
    """The sandbox's `e2e/` folder, where the sandbox's device test files go."""
    return pytester.path / "e2e"


def run_sandbox(pytester: pytest.Pytester, *args: str) -> pytest.RunResult:
    """Run pytest in a sub-process from the sandbox root, with the copied `pytest.ini` as the real wrapper passes it."""
    return pytester.runpytest_subprocess("-c", INI, *args)
