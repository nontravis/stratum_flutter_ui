"""Unit tests for the e2e toolchain locations."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from stratum_e2e.paths import (
    APPIUM_BIN,
    APPIUM_HOME,
    E2E_ROOT,
    INTEGRATION_ITEM_DIR,
    REPO_ROOT,
    ROUNDS_ROOT,
    TESTS_DIR,
    in_round_scope,
    scope_key,
    scope_root,
)


def test_e2e_root_holds_the_package_and_pytest_ini() -> None:
    assert (E2E_ROOT / "stratum_e2e").is_dir()
    assert (E2E_ROOT / "pytest.ini").is_file()


def test_appium_lives_under_the_dot_tools_folder() -> None:
    assert APPIUM_BIN == E2E_ROOT / ".tools" / "node_modules" / ".bin" / "appium"
    assert APPIUM_HOME == E2E_ROOT / ".tools" / "appium-home"


def test_repo_root_holds_pubspec_and_tools() -> None:
    assert (REPO_ROOT / "pubspec.yaml").is_file()
    assert E2E_ROOT == REPO_ROOT / "tools" / "e2e"


def test_rounds_root_is_repo_tmp_whatever_the_cwd(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(tmp_path)
    assert ROUNDS_ROOT == REPO_ROOT / "tmp" / "e2e-rounds"


def test_scope_root_matches_the_two_roots() -> None:
    assert scope_root(REPO_ROOT / "e2e" / "common" / "test_x.py") == TESTS_DIR
    assert scope_root(E2E_ROOT / "integration" / "test_integration.py") == INTEGRATION_ITEM_DIR
    assert scope_root(E2E_ROOT / "unit" / "test_paths.py") is None


def test_in_round_scope_is_true_only_under_a_scope_root() -> None:
    assert in_round_scope(TESTS_DIR / "perf" / "test_perf_abba.py")
    assert in_round_scope(INTEGRATION_ITEM_DIR / "test_integration.py")
    assert not in_round_scope(E2E_ROOT / "unit" / "test_paths.py")


def test_e2e_holds_no_integration_folder() -> None:
    # `integration/<file>` is the integration item's key; a folder of that name under e2e/ would share it.
    assert not (TESTS_DIR / "integration").exists()


@pytest.mark.skipif(sys.platform != "darwin", reason="macOS volumes are case-insensitive by default")
def test_scope_matches_a_path_typed_in_other_case() -> None:
    typed = Path(str(REPO_ROOT).swapcase())
    if not typed.exists() or not typed.samefile(REPO_ROOT):
        pytest.skip("this volume is case-sensitive")
    other_case = typed / "e2e" / "common" / "test_x.py"
    integration = typed / "tools" / "e2e" / "integration" / "test_integration.py"
    assert in_round_scope(other_case)
    assert scope_key(other_case) == "common/test_x.py"
    assert scope_key(integration) == "integration/test_integration.py"
