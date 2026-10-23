"""Unit tests for the e2e toolchain locations."""

from __future__ import annotations

from stratum_e2e.paths import APPIUM_BIN, APPIUM_HOME, E2E_ROOT


def test_e2e_root_holds_the_package_and_pytest_ini() -> None:
    assert (E2E_ROOT / "stratum_e2e").is_dir()
    assert (E2E_ROOT / "pytest.ini").is_file()


def test_appium_lives_under_the_dot_tools_folder() -> None:
    assert APPIUM_BIN == E2E_ROOT / ".tools" / "node_modules" / ".bin" / "appium"
    assert APPIUM_HOME == E2E_ROOT / ".tools" / "appium-home"
