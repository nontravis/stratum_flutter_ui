"""Where the e2e toolchain and its test cases live (`tools/e2e/setup.sh` installs the toolchain; design section 18)."""

from __future__ import annotations

from pathlib import Path

E2E_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = E2E_ROOT.parents[1]
TESTS_DIR = REPO_ROOT / "e2e"
INTEGRATION_ITEM_DIR = E2E_ROOT / "integration"
ROUNDS_ROOT = REPO_ROOT / "tmp" / "e2e-rounds"
APPIUM_BIN = E2E_ROOT / ".tools" / "node_modules" / ".bin" / "appium"
APPIUM_HOME = E2E_ROOT / ".tools" / "appium-home"

# Each scope root maps to the folder its retry and catalog keys are relative to; the integration item keeps its
# `integration/` prefix so a key reads the same as before the move.
_KEY_BASES = {TESTS_DIR: TESTS_DIR, INTEGRATION_ITEM_DIR: E2E_ROOT}


def _under(path: Path, root: Path) -> Path | None:
    """Returns the parent of [path] that is the folder [root], else None; None too when [root] does not exist.

    Compares by file identity, since a path typed in other case on a case-insensitive volume differs from [root] as a
    string yet names the same folder.
    """
    if not root.exists():
        return None
    return next((parent for parent in path.parents if parent.exists() and parent.samefile(root)), None)


def scope_root(path: Path) -> Path | None:
    """Returns the round-scope root holding [path], or None when [path] sits outside every root."""
    resolved = path.resolve()
    return next((root for root in _KEY_BASES if _under(resolved, root) is not None), None)


def in_round_scope(path: Path) -> bool:
    """Returns whether [path] is a test case a device round selects, runs, or skips by platform."""
    return scope_root(path) is not None


def scope_key(path: Path) -> str:
    """Returns the retry and catalog key of [path]: relative to its scope root's key base, else its file name."""
    root = scope_root(path)
    if root is None:
        return path.name
    resolved = path.resolve()
    inside_root = resolved.relative_to(_under(resolved, root))
    return (root.relative_to(_KEY_BASES[root]) / inside_root).as_posix()
