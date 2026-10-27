"""Unit tests for the setup hooks scoped to the e2e test folders, run through pytester."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.host_load import BASELINE_NAME
from stratum_e2e.round.results import _segment
from unit.sandbox import INTEGRATION_ITEM, build_sandbox, run_sandbox, suite_dir
from unit.test_host_load import HOST_TARGETS_TOML
from unit.test_host_load import _make_tree as _make_round_tree

TESTS_DIR_SOURCE = """\
import pytest


@pytest.mark.android
def test_marked_android(): pass


def test_unmarked(): pass
"""

UNIT_DIR_SOURCE = "def test_unit_side(): pass\n"
INTEGRATION_ITEM_SOURCE = "def test_integration_unmarked(): pass\n"


def _make_tree(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Build the repo-shaped sandbox with one e2e file and one unit file; returns its `tools/e2e` folder."""
    root = build_sandbox(pytester, monkeypatch)
    (suite_dir(pytester) / "test_e2e.py").write_text(TESTS_DIR_SOURCE)
    (root / "unit").mkdir()
    (root / "unit" / "test_unit.py").write_text(UNIT_DIR_SOURCE)
    return root


def test_hook_skips_only_tests_dir(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    """Under --platform android the e2e item marked android runs, the unmarked
    e2e item skips, and the unit/ item still runs."""
    _make_tree(pytester, monkeypatch)
    result = run_sandbox(pytester, "tools/e2e/unit", "e2e", "--platform", "android")
    result.assert_outcomes(passed=2, skipped=1)


def test_hook_skips_wrong_platform_in_tests_dir(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    """Under --platform ios both e2e items skip; unit/ still runs."""
    _make_tree(pytester, monkeypatch)
    result = run_sandbox(pytester, "tools/e2e/unit", "e2e", "--platform", "ios")
    result.assert_outcomes(passed=1, skipped=2)


def test_hook_skips_the_integration_item_by_platform(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    """The integration item lives outside `e2e/` yet skips under --platform like an e2e item; unit/ still runs."""
    root = _make_tree(pytester, monkeypatch)
    (root / "integration").mkdir()
    (root / "integration" / "test_integration.py").write_text(INTEGRATION_ITEM_SOURCE)
    result = run_sandbox(pytester, INTEGRATION_ITEM, "tools/e2e/unit", "--platform", "android")
    result.assert_outcomes(passed=1, skipped=1)


HOST_LEG_SOURCE = """\
import pytest


@pytest.mark.macos
@pytest.mark.level2
@pytest.mark.level2_host
def test_host_leg(): pass


@pytest.mark.macos
@pytest.mark.level2
def test_level2_leg(): pass
"""


def _make_host_leg_tree(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    (suite_dir(pytester) / "test_host_leg.py").write_text(HOST_LEG_SOURCE)


def test_a_replaced_marker_expression_skips_the_host_leg_without_the_opt_in(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    """`-m level2` replaces the addopts `not level2_host`; the hook still skips the host leg (no VoiceOver starts)."""
    _make_host_leg_tree(pytester, monkeypatch)
    result = run_sandbox(pytester, "e2e/test_host_leg.py", "-m", "level2", "--platform", "macos", "-rs")
    result.assert_outcomes(passed=1, skipped=1)
    result.stdout.fnmatch_lines(["*level2_host runs only with --host-voiceover*"])


def test_the_opt_in_runs_the_host_leg(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_host_leg_tree(pytester, monkeypatch)
    result = run_sandbox(
        pytester, "e2e/test_host_leg.py", "-m", "level2", "--platform", "macos", "--host-voiceover"
    )
    result.assert_outcomes(passed=2)


def test_the_default_marker_expression_deselects_the_host_leg_even_with_the_opt_in(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_host_leg_tree(pytester, monkeypatch)
    result = run_sandbox(pytester, "e2e/test_host_leg.py", "--platform", "macos", "--host-voiceover")
    result.assert_outcomes(passed=1, deselected=1)


DEDICATED_TESTS_SOURCE = """\
import pytest


@pytest.mark.android
@pytest.mark.talkback_avd
def test_talkback_only(): pass


@pytest.mark.android
@pytest.mark.stylus_avd
def test_stylus_only(): pass


@pytest.mark.android
def test_plain_android(): pass
"""


@pytest.mark.parametrize(
    ("avd", "outcomes"),
    [
        ("Pixel_8_API_37", {"passed": 1, "skipped": 2}),
        ("E2E_TalkBack_API_35", {"passed": 2, "skipped": 1}),
        ("E2E_Stylus_API_36", {"passed": 2, "skipped": 1}),
    ],
)
def test_dedicated_avd_skip_still_fires_with_baseline_hook(
    avd: str, outcomes: dict[str, int], pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A direct run skips a dedicated-marker item on any AVD but its own, even with the baseline hook present.

    Two same-named `pytest_runtest_setup` defs rebind the module attribute, and pluggy registers only the last
    one, so the skip must live in the same function as the baseline write. The copied adb answers every
    `avd name` with [avd], so no emulator is needed.
    """
    root = _make_round_tree(pytester, monkeypatch)
    adb_copy = root / "stratum_e2e" / "android" / "adb.py"
    adb_copy.write_text(
        adb_copy.read_text().replace(
            'lines = adb(serial, "emu", "avd", "name").splitlines()\n    return lines[0].strip() if lines else ""',
            f'return "{avd}"',
        )
    )
    (suite_dir(pytester) / "test_dedicated_only.py").write_text(DEDICATED_TESTS_SOURCE)
    monkeypatch.setenv("STRATUM_E2E_ROUNDS_DIR", str(pytester.path / "rounds"))
    monkeypatch.setenv("STRATUM_E2E_LANE_DIR", str(pytester.path / "lanes"))
    result = run_sandbox(
        pytester,
        "e2e/test_dedicated_only.py",
        "-p",
        "no:cacheprovider",
        "--platform",
        "android",
        "--device",
        "emulator-5554",
        "-p",
        "no:randomly",
    )
    result.assert_outcomes(**outcomes)


TWO_AVD_TESTS_SOURCE = """\
import pytest


@pytest.mark.android
@pytest.mark.talkback_avd
@pytest.mark.stylus_avd
def test_marked_for_both(): pass
"""

TWO_AVD_LEVEL2_SOURCE = TWO_AVD_TESTS_SOURCE.replace("@pytest.mark.talkback_avd", "@pytest.mark.level2")


@pytest.mark.parametrize("source", [TWO_AVD_TESTS_SOURCE, TWO_AVD_LEVEL2_SOURCE], ids=["talkback_avd", "level2"])
def test_an_item_marked_for_two_dedicated_avds_fails_collection(
    source: str, pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Such an item matches no AVD, so it would vanish from every run; collection names it instead."""
    build_sandbox(pytester, monkeypatch)
    (suite_dir(pytester) / "test_two_avds.py").write_text(source)

    result = run_sandbox(pytester, "e2e/test_two_avds.py", "-p", "no:cacheprovider", "--platform", "android")

    assert result.ret == pytest.ExitCode.USAGE_ERROR
    result.stderr.fnmatch_lines(["*test_marked_for_both is marked for more than one dedicated AVD*stylus_avd*"])


def test_baseline_folder_name_matches_round_segment(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The baseline lands in the folder the round's own `_segment` rule names, digest included over 120 chars."""
    long_target = "host_fake_" + "x" * 200
    root = _make_round_tree(pytester, monkeypatch)
    (suite_dir(pytester) / "targets.toml").write_text(HOST_TARGETS_TOML.replace("host_fake", long_target))
    rounds = pytester.path / "rounds"
    monkeypatch.setenv("STRATUM_E2E_ROUNDS_DIR", str(rounds))
    monkeypatch.setenv("STRATUM_E2E_LANE_DIR", str(pytester.path / "lanes"))
    result = run_sandbox(pytester, "e2e", "-p", "no:cacheprovider", "--target", long_target, "-p", "no:randomly")
    result.assert_outcomes(passed=1, failed=1, errors=1)
    baseline = list(rounds.rglob(BASELINE_NAME))
    assert len(baseline) == 1
    assert baseline[0].parent.name == _segment(long_target)
