"""Unit tests for the tests/-only setup hooks, run through pytester."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from stratum_e2e.host_load import BASELINE_NAME
from stratum_e2e.round.results import _segment
from unit.test_host_load import HOST_TARGETS_TOML
from unit.test_host_load import _make_tree as _make_round_tree

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


TALKBACK_TESTS_SOURCE = """\
import pytest


@pytest.mark.android
@pytest.mark.talkback_avd
def test_talkback_only(): pass
"""


def test_talkback_avd_skip_still_fires_with_baseline_hook(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A direct run on a non-e2e AVD skips the talkback_avd item even with the baseline hook present.

    Two same-named `pytest_runtest_setup` defs rebind the module attribute, and pluggy registers only the last
    one, so the skip must live in the same function as the baseline write. The copied adb answers every
    `avd name` with a non-e2e AVD, so no emulator is needed.
    """
    root = _make_round_tree(pytester)
    adb_copy = root / "stratum_e2e" / "android" / "adb.py"
    adb_copy.write_text(
        adb_copy.read_text().replace(
            'lines = adb(serial, "emu", "avd", "name").splitlines()\n    return lines[0].strip() if lines else ""',
            'return "Pixel_8_API_37"',
        )
    )
    (root / "tests" / "test_talkback_only.py").write_text(TALKBACK_TESTS_SOURCE)
    monkeypatch.setenv("STRATUM_E2E_ROUNDS_DIR", str(pytester.path / "rounds"))
    monkeypatch.setenv("STRATUM_E2E_LANE_DIR", str(pytester.path / "lanes"))
    monkeypatch.chdir(root)
    result = pytester.runpytest_subprocess(
        "tests/test_talkback_only.py",
        "-p",
        "no:cacheprovider",
        "--platform",
        "android",
        "--device",
        "emulator-5554",
        "-p",
        "no:randomly",
    )
    result.assert_outcomes(skipped=1)


def test_baseline_folder_name_matches_round_segment(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The baseline lands in the folder the round's own `_segment` rule names, digest included over 120 chars."""
    long_target = "host_fake_" + "x" * 200
    root = _make_round_tree(pytester)
    (root / "targets.toml").write_text(HOST_TARGETS_TOML.replace("host_fake", long_target))
    rounds = pytester.path / "rounds"
    monkeypatch.setenv("STRATUM_E2E_ROUNDS_DIR", str(rounds))
    monkeypatch.setenv("STRATUM_E2E_LANE_DIR", str(pytester.path / "lanes"))
    monkeypatch.chdir(root)
    result = pytester.runpytest_subprocess(
        "tests", "-p", "no:cacheprovider", "--target", long_target, "-p", "no:randomly"
    )
    result.assert_outcomes(passed=1, failed=1, errors=1)
    baseline = list(rounds.rglob(BASELINE_NAME))
    assert len(baseline) == 1
    assert baseline[0].parent.name == _segment(long_target)
