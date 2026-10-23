"""Where the e2e toolchain lives (`e2e/tools/setup.sh` installs it; design section 18)."""

from __future__ import annotations

from pathlib import Path

E2E_ROOT = Path(__file__).resolve().parents[1]
APPIUM_BIN = E2E_ROOT / ".tools" / "node_modules" / ".bin" / "appium"
APPIUM_HOME = E2E_ROOT / ".tools" / "appium-home"
