"""Unit tests for the round options and per-target collection, run through pytester (design sections 6 and 7)."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from stratum_e2e.round.results import ROUNDS_DIR_ENV

E2E_ROOT = Path(__file__).resolve().parents[1]
INTEGRATION_FIXTURE = Path(__file__).parent / "fixtures" / "round" / "integration_test"
WEB_VIEW = "common/web_view_test.dart"
SMOKE = "smoke/semantics_id_test.dart"
RESTART_1 = "common/page_layout_restart_1_linux_test.dart"
SYSTEM_STYLE_LINUX = "themes/system_style_linux_test.dart"
MOBILE_FILES = 5
MAC_FILES = 4
LINUX_FILES = 7

TARGETS_TOML = f"""\
[apps.test_app]
folder = "test_app"
android_id = "dev.stratum.stratum_ui_test_app"
apple_id = "dev.stratum.stratumUiTestApp"

[targets.pixel_8]
platform = "android"
avd = "Pixel_8_API_37"
alone = true
build_mode = "profile"

[targets.pixel_8.repeat]
"{WEB_VIEW}" = ["co01_02/us03/s1"]

[targets.pixel_2]
platform = "android"
avd = "Pixel_2_API_28"
alone = true
build_mode = "debug"

[targets.pixel_2.plain_name]
"{WEB_VIEW}" = "group B, native only"

[targets.small_phone]
platform = "android"
avd = "Small_Phone_API_33"
alone = true
build_mode = "profile"

[targets.tablet]
platform = "android"
avd = "Pixel_Tablet_API_35"
alone = true
build_mode = "profile"

[targets.e2e_talkback]
platform = "android"
avd = "E2E_TalkBack_API_35"
alone = true
integration = false

[targets.iphone]
platform = "ios"
device = "iPhone 17"
e2e = false

[targets.iphone_e2e]
platform = "ios"
device = "iPhone Duo"
integration = false

[targets.mac]
platform = "macos"

[targets.chrome]
platform = "web"
browser = "chrome"

[targets.chrome_wasm]
platform = "web"
browser = "chrome"
wasm = true

[targets.linux]
platform = "linux"
e2e = false

[sequences.fo10_cold_restart]
target = "linux"
files = ["{RESTART_1}", "common/page_layout_restart_2_linux_test.dart"]

[modes.fast]
targets = ["mac"]
repeat = 1

[modes.full]
targets = ["pixel_8", "pixel_2", "small_phone", "tablet", "iphone", "mac", "chrome", "chrome_wasm", "linux"]
repeat = 10

[lane]
allow_level2 = true
run_timeout_minutes = 20
boot_settle_timeout_seconds = 420
heavy_processes = ["perf_abba"]
lane_wait_minutes = 30
"""

LEGS_SOURCE = """\
import pytest


@pytest.mark.android
def test_android_plain(): pass


@pytest.mark.android
@pytest.mark.level1
def test_android_level1(): pass


@pytest.mark.android
@pytest.mark.talkback_avd
def test_android_talkback(): pass


@pytest.mark.android
@pytest.mark.level2
def test_android_level2(): pass


@pytest.mark.ios
def test_ios(): pass


@pytest.mark.macos
def test_macos(): pass


@pytest.mark.web
def test_web(): pass
"""

INTEGRATION_SOURCE = """\
def test_integration_file(round_target, integration_file): pass
"""

PERF_SOURCE = """\
import pytest


@pytest.mark.perf
def test_perf(): pass
"""


def _make_tree(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch, *, catalog: bool = True) -> Path:
    """Mirror the e2e layout under `e2e/` with a fixture catalog and a `test_app/integration_test` beside it.

    Moves the process into `e2e/` so the sub-process pytest finds the copied `pytest.ini`, and points the round
    folder at a path that must stay absent for a plan-only run.
    """
    root = pytester.path / "e2e"
    root.mkdir()
    shutil.copy(E2E_ROOT / "pytest.ini", root / "pytest.ini")
    shutil.copy(E2E_ROOT / "conftest.py", root / "conftest.py")
    shutil.copytree(E2E_ROOT / "stratum_e2e", root / "stratum_e2e", ignore=shutil.ignore_patterns("__pycache__"))
    tests = root / "tests"
    (tests / "z_integration").mkdir(parents=True)  # sorts after test_legs.py, so ordering is the plugin's work
    (tests / "perf").mkdir()
    shutil.copy(E2E_ROOT / "tests" / "conftest.py", tests / "conftest.py")
    (tests / "test_legs.py").write_text(LEGS_SOURCE)
    (tests / "z_integration" / "test_integration.py").write_text(INTEGRATION_SOURCE)
    (tests / "perf" / "test_perf.py").write_text(PERF_SOURCE)
    shutil.copytree(INTEGRATION_FIXTURE, pytester.path / "test_app" / "integration_test")
    if catalog:
        (root / "targets.toml").write_text(TARGETS_TOML)
    monkeypatch.chdir(root)
    monkeypatch.setenv(ROUNDS_DIR_ENV, str(pytester.path / "rounds"))
    return root


def _collect(pytester: pytest.Pytester, *args: str) -> pytest.RunResult:
    return pytester.runpytest_subprocess("tests", "--collect-only", "-q", *args)


def _ids(result: pytest.RunResult) -> list[str]:
    """The collected node ids as `<test file stem>::<test function>[<params>]`, in collection order."""
    ids: list[str] = []
    for line in result.outlines:
        path, separator, rest = line.partition("::")
        if separator:
            ids.append(f"{Path(path).name}::{rest}")
    return ids


def _lines(result: pytest.RunResult, prefix: str) -> list[str]:
    return [line for line in result.outlines if line.startswith(prefix)]


def test_target_option_parametrizes_items_per_target(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "mac,chrome")
    assert result.ret == 0
    ids = _ids(result)
    assert "test_legs.py::test_macos[mac]" in ids
    assert "test_legs.py::test_web[chrome]" in ids
    assert "test_legs.py::test_macos[chrome]" not in ids
    assert "test_legs.py::test_web[mac]" not in ids


def test_items_group_by_target_in_round_order(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "chrome,mac")
    assert result.ret == 0
    ids = _ids(result)
    targets = [_target_of(item) for item in ids]
    assert targets == ["chrome"] * targets.count("chrome") + ["mac"] * targets.count("mac")
    for target in ("chrome", "mac"):
        kinds = ["test_integration_file" in item for item in ids if _target_of(item) == target]
        assert kinds == sorted(kinds, reverse=True), f"{target}: integration items come first"
        assert kinds[0] and not kinds[-1]


def _target_of(item: str) -> str:
    """The target name in a node id's `[target]` or `[target-file]` suffix."""
    return item.split("[", 1)[1].rstrip("]").split("-")[0]


def test_integration_items_follow_platform_files(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "mac,linux")
    ids = _ids(result)
    mac = [item for item in ids if "test_integration_file[mac-" in item]
    linux = [item for item in ids if "test_integration_file[linux-" in item]
    assert len(mac) == MAC_FILES
    assert len(linux) == LINUX_FILES
    assert f"test_integration.py::test_integration_file[mac-{SMOKE}]" in mac
    assert not any(RESTART_1 in item for item in mac)
    assert any(SYSTEM_STYLE_LINUX in item for item in linux)


def test_shared_android_never_runs_talkback_or_level2(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    ids = _ids(_collect(pytester, "--target", "pixel_8"))
    assert "test_legs.py::test_android_plain[pixel_8]" in ids
    assert "test_legs.py::test_android_level1[pixel_8]" in ids
    assert not any("test_android_talkback" in item or "test_android_level2" in item for item in ids)


def test_talkback_target_runs_talkback_avd_only(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    ids = _ids(_collect(pytester, "--target", "e2e_talkback"))
    assert sorted(ids) == [
        "test_legs.py::test_android_level2[e2e_talkback]",
        "test_legs.py::test_android_talkback[e2e_talkback]",
    ]


def test_linux_and_iphone_run_no_e2e(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    ids = _ids(_collect(pytester, "--target", "linux,iphone"))
    assert ids
    assert all("test_integration_file[" in item for item in ids)
    assert len([item for item in ids if "[iphone-" in item]) == MOBILE_FILES
    assert len([item for item in ids if "[linux-" in item]) == LINUX_FILES


def test_target_without_integration_gets_no_integration_item(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_tree(pytester, monkeypatch)
    ids = _ids(_collect(pytester, "--target", "iphone_e2e"))
    assert ids == ["test_legs.py::test_ios[iphone_e2e]"]


def test_perf_is_out_of_default_runs(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    assert "test_perf.py::test_perf[mac]" not in _ids(_collect(pytester, "--target", "mac"))
    selected = _ids(_collect(pytester, "-m", "perf", "--target", "mac,chrome"))
    assert selected == ["test_perf.py::test_perf[mac]"]


HOST_LEG_SOURCE = """\
import pytest


@pytest.mark.macos
@pytest.mark.web
@pytest.mark.level2
@pytest.mark.level2_host
def test_host_leg(): pass
"""


def test_a_round_runs_the_host_leg_only_with_the_opt_in(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    """A round's `-m level2` replaces the addopts default; only --host-voiceover selects the host leg."""
    root = _make_tree(pytester, monkeypatch)
    (root / "tests" / "test_host_leg.py").write_text(HOST_LEG_SOURCE)
    without = _ids(_collect(pytester, "-m", "level2", "--target", "mac,chrome"))
    assert not [item for item in without if item.startswith("test_host_leg.py::")]
    with_opt_in = _ids(_collect(pytester, "-m", "level2", "--target", "mac,chrome", "--host-voiceover"))
    assert sorted(item for item in with_opt_in if item.startswith("test_host_leg.py::")) == [
        "test_host_leg.py::test_host_leg[chrome]",
        "test_host_leg.py::test_host_leg[mac]",
    ]


def test_collect_only_prints_the_round_plan(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "pixel_8,pixel_2,small_phone,tablet", "--mode", "full")
    assert result.ret == 0
    assert _lines(result, "round: build") == ["round: build android ['flutter', 'build', 'apk', '--debug']"]
    runs = _lines(result, "round: run")
    assert [line.split()[3] for line in runs] == ["entry", "entry", "plain_name", "entry"]
    shared = [line for line in runs if "small_phone,tablet" in line]
    assert len(shared) == 1
    assert shared[0].split()[3] == "entry"
    plain = [line for line in runs if " plain_name " in line]
    assert plain[0].split()[4:] == ["pixel_2", WEB_VIEW]
    assert not (root.parent / "rounds").exists()
    assert not (root.parent / "tmp").exists()


def test_collect_only_builds_once_per_platform_and_wasm(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "mac,chrome,chrome_wasm,linux,iphone,iphone_e2e")
    builds = _lines(result, "round: build")
    assert builds == [
        "round: build macos ['flutter', 'build', 'macos', '--debug']",
        "round: build web ['flutter', 'build', 'web', '-o', 'build/web_js']",
        "round: build web ['flutter', 'build', 'web', '--wasm', '-o', 'build/web_wasm']",
        "round: build ios ['flutter', 'build', 'ios', '--simulator', '--debug']",
    ]


def test_unknown_target_is_a_usage_error_with_no_round_dir(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "pixle_8")
    assert result.ret == 4
    assert "unknown target 'pixle_8'" in result.stderr.str()
    assert not (root.parent / "rounds").exists()
    assert not (root.parent / "tmp").exists()


def test_unknown_mode_is_a_usage_error(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--mode", "nightly")
    assert result.ret == 4
    assert "unknown mode 'nightly'" in result.stderr.str()


def test_target_marking_a_file_its_platform_does_not_run_is_a_usage_error(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch)
    (pytester.path / "test_app" / "integration_test" / WEB_VIEW).unlink()
    result = _collect(pytester, "--target", "pixel_2")
    assert result.ret == 4
    assert WEB_VIEW in result.stderr.str()
    assert not (root.parent / "rounds").exists()


def test_plain_name_on_a_flutter_drive_target_is_a_usage_error(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch)
    catalog = TARGETS_TOML.replace(
        "[targets.pixel_8.repeat]", f'[targets.pixel_8.plain_name]\n"{SMOKE}" = "group A"\n\n[targets.pixel_8.repeat]'
    )
    (root / "targets.toml").write_text(catalog)
    result = _collect(pytester, "--target", "pixel_8")
    assert result.ret == 4
    error = result.stderr.str()
    assert "pixel_8" in error
    assert "--plain-name" in error
    assert not (root.parent / "rounds").exists()


def test_repeat_prefix_naming_no_block_is_a_usage_error(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch)
    (root / "targets.toml").write_text(TARGETS_TOML.replace('["co01_02/us03/s1"]', '["co99/us99/s9"]'))
    result = _collect(pytester, "--target", "pixel_8", "--repeat", "3")  # a repeat of 1 wraps nothing
    assert result.ret == 4
    error = result.stderr.str()
    assert "co99/us99/s9" in error
    assert WEB_VIEW in error


def test_override_spanning_platforms_fails(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "pixel_8,mac", "--app", "/x.app")
    assert result.ret == 4
    error = result.stderr.str()
    assert "--app" in error
    assert "android" in error
    assert "macos" in error


@pytest.mark.parametrize(
    ("option", "value"),
    [("--platform", "android"), ("--device", "emulator-5554"), ("--app", "/x.apk"), ("--app-id", "dev.x")],
)
def test_every_low_level_option_is_refused_across_platforms(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch, option: str, value: str
) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--mode", "full", option, value)
    assert result.ret == 4
    assert option in result.stderr.str()


def test_override_on_one_platform_is_kept(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "mac", "--app", "/x.app")
    assert result.ret == 0
    assert "test_legs.py::test_macos[mac]" in _ids(result)


def test_repeat_alone_starts_a_round_on_the_fast_mode(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--repeat", "3")
    assert result.ret == 0
    assert "test_legs.py::test_macos[mac]" in _ids(result)


def test_repeat_below_one_is_a_usage_error(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch)
    result = _collect(pytester, "--target", "mac", "--repeat", "0")
    assert result.ret == 4
    assert "--repeat" in result.stderr.str()


def test_legacy_path_is_inert_without_target_or_mode(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch, catalog=False)
    result = _collect(pytester, "--platform", "android")
    assert result.ret == 0
    ids = _ids(result)
    assert "test_legs.py::test_android_plain" in ids
    assert not any("[" in item for item in ids if "test_legs.py" in item)
    used = pytester.runpytest_subprocess("tests/test_legs.py", "--fixtures-per-test", "--platform", "android")
    assert "round_target" not in used.stdout.str()
