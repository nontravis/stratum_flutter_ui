"""Unit tests for the tests/-only skip hook, run through pytester."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

E2E_ROOT = Path(__file__).resolve().parents[1]

TESTS_DIR_SOURCE = """\
import pytest


@pytest.mark.android
def test_marked_android(): pass


def test_unmarked(): pass
"""

UNIT_DIR_SOURCE = "def test_unit_side(): pass\n"


def _make_tree(pytester: pytest.Pytester) -> None:
    """Mirror the real e2e layout: conftest, pytest.ini, package, tests/, unit/."""
    shutil.copy(E2E_ROOT / "pytest.ini", pytester.path / "pytest.ini")
    shutil.copy(E2E_ROOT / "conftest.py", pytester.path / "conftest.py")
    shutil.copytree(E2E_ROOT / "stratum_e2e", pytester.path / "stratum_e2e")
    tests_dir = pytester.path / "tests"
    tests_dir.mkdir()
    shutil.copy(E2E_ROOT / "tests" / "conftest.py", tests_dir / "conftest.py")
    (tests_dir / "test_e2e.py").write_text(TESTS_DIR_SOURCE)
    unit_dir = pytester.path / "unit"
    unit_dir.mkdir()
    (unit_dir / "test_unit.py").write_text(UNIT_DIR_SOURCE)


def test_hook_skips_only_tests_dir(pytester: pytest.Pytester) -> None:
    """Under --platform android the tests/ item marked android runs, the unmarked
    tests/ item skips, and the unit/ item still runs."""
    _make_tree(pytester)
    result = pytester.runpytest_subprocess("--platform", "android")
    result.assert_outcomes(passed=2, skipped=1)


def test_hook_skips_wrong_platform_in_tests_dir(pytester: pytest.Pytester) -> None:
    """Under --platform ios both tests/ items skip; unit/ still runs."""
    _make_tree(pytester)
    result = pytester.runpytest_subprocess("--platform", "ios")
    result.assert_outcomes(passed=1, skipped=2)
