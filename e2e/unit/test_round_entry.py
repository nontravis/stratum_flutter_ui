"""Unit tests for the integration entry planning and generation (design section 9 and 15); no Flutter, no device."""

from __future__ import annotations

import shutil
from pathlib import Path
from types import MappingProxyType

import pytest

from stratum_e2e.round.catalog import RunSequence, Target
from stratum_e2e.round.entry import (
    RunPlan,
    cleanup,
    entry_source,
    plan_runs,
    platform_files,
    write_run_file,
)

FIXTURE = Path(__file__).parent / "fixtures" / "round" / "integration_test"
WEB_VIEW = "common/web_view_test.dart"
SMOKE = "smoke/semantics_id_test.dart"
RESTART_1 = "common/page_layout_restart_1_linux_test.dart"
RESTART_2 = "common/page_layout_restart_2_linux_test.dart"
SYSTEM_STYLE_LINUX = "themes/system_style_linux_test.dart"


def _android_targets() -> list[Target]:
    return [
        Target(name="pixel_8", platform="android", build_mode="profile",
               repeat=MappingProxyType({WEB_VIEW: ("co01_02/us03/s1",)})),
        Target(name="pixel_2", platform="android", build_mode="debug",
               plain_name=MappingProxyType({WEB_VIEW: "group B, native only"})),
        Target(name="small_phone", platform="android", build_mode="profile"),
        Target(name="tablet", platform="android", build_mode="profile"),
    ]


def _plans(repeat: int) -> dict[str, list[RunPlan]]:
    return plan_runs("android", _android_targets(), platform_files(FIXTURE, "android"), [], repeat)


def test_platform_files_skip_linux_only_off_linux() -> None:
    android = platform_files(FIXTURE, "android")

    assert android == [
        "common/keyboard_visibility_scope_test.dart",
        "common/reorderable_list_view_layout_test.dart",
        "common/screen_radius_scope_test.dart",
        "common/split_layout_setting_test.dart",
        WEB_VIEW,
        SMOKE,
    ]
    linux = platform_files(FIXTURE, "linux")
    assert len(linux) == 9
    assert {RESTART_1, RESTART_2, SYSTEM_STYLE_LINUX} <= set(linux)


def test_platform_files_never_list_the_round_folder_or_a_wrapped_sibling(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (folder / ".round").mkdir()
    (folder / ".round" / "android_none-12345678_test.dart").write_text("void main() {}\n", encoding="utf-8")
    (folder / "common" / ".dt_web_view_test_x10_test.dart").write_text("void main() {}\n", encoding="utf-8")

    files = platform_files(folder, "linux")

    assert len(files) == 9
    assert not any(".round" in f or ".dt_" in f for f in files)


def test_android_full_makes_three_entries() -> None:
    plans = _plans(10)

    all_plans = [plan for runs in plans.values() for plan in runs]
    assert len({plan.key for plan in all_plans if plan.kind == "entry"}) == 3

    pixel_2_entry, pixel_2_alone = plans["pixel_2"]
    assert pixel_2_entry.kind == "entry"
    assert pixel_2_entry.build_mode == "debug"
    assert WEB_VIEW not in pixel_2_entry.files
    assert pixel_2_entry.wrapped == {}
    assert pixel_2_alone.kind == "plain_name"
    assert pixel_2_alone.files == (WEB_VIEW,)
    assert pixel_2_alone.plain_name == "group B, native only"

    (pixel_8_entry,) = plans["pixel_8"]
    assert pixel_8_entry.build_mode == "profile"
    assert WEB_VIEW in pixel_8_entry.files
    assert pixel_8_entry.wrapped == {WEB_VIEW: ("co01_02/us03/s1",)}
    assert pixel_8_entry.repeat == 10

    assert plans["small_phone"][0] is plans["tablet"][0]
    assert plans["small_phone"][0].build_mode == "profile"
    assert plans["small_phone"][0].wrapped == {}
    assert plans["small_phone"][0] is not pixel_8_entry


def test_the_key_is_the_build_mode_and_eight_hex_of_the_entry_sources_sha1() -> None:
    plans = _plans(10)

    assert plans["pixel_2"][0].key.startswith("debug-")
    assert plans["pixel_8"][0].key.startswith("profile-")
    suffix = plans["pixel_8"][0].key.split("-", 1)[1]
    assert len(suffix) == 8
    assert all(char in "0123456789abcdef" for char in suffix)


def test_a_target_without_a_build_mode_keys_with_none() -> None:
    (plan,) = plan_runs("macos", [Target(name="mac", platform="macos")], [SMOKE], [], 1)["mac"]

    assert plan.key.startswith("none-")
    assert plan.build_mode is None


def test_fast_runs_the_block_unwrapped() -> None:
    plans = _plans(1)

    (pixel_8_entry,) = plans["pixel_8"]
    assert pixel_8_entry.wrapped == {}
    assert WEB_VIEW in pixel_8_entry.files
    assert f"import '../{WEB_VIEW}' as f" in entry_source(pixel_8_entry)
    assert plans["small_phone"][0] is pixel_8_entry


def test_repeat_flag_sets_the_wrap_count(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (pixel_8_entry,) = _plans(20)["pixel_8"]

    path = write_run_file(pixel_8_entry, folder)

    assert (folder / "common" / ".dt_web_view_test_x20.dart").is_file()
    source = entry_source(pixel_8_entry)
    assert "import '../common/.dt_web_view_test_x20.dart' as f" in source
    assert f"import '../{WEB_VIEW}'" not in source
    assert path.is_file()


def test_linux_sequence_runs_alone_in_order() -> None:
    linux = Target(name="linux", platform="linux")
    sequence = RunSequence(name="fo10_cold_restart", target="linux", files=(RESTART_1, RESTART_2))
    files = platform_files(FIXTURE, "linux")

    plans = plan_runs("linux", [linux], files, [sequence], 10)

    entry, alone = plans["linux"]
    assert entry.kind == "entry"
    assert RESTART_1 not in entry.files
    assert RESTART_2 not in entry.files
    assert SYSTEM_STYLE_LINUX in entry.files
    assert alone.kind == "sequence"
    assert alone.files == (RESTART_1, RESTART_2)


def test_a_sequence_of_another_target_leaves_this_targets_entry_whole() -> None:
    linux = Target(name="linux", platform="linux")
    other = RunSequence(name="elsewhere", target="other_linux", files=(RESTART_1, RESTART_2))

    (entry,) = plan_runs("linux", [linux], platform_files(FIXTURE, "linux"), [other], 10)["linux"]

    assert RESTART_1 in entry.files
    assert RESTART_2 in entry.files


def test_a_marked_file_the_platform_does_not_run_is_an_error() -> None:
    target = Target(name="pixel_2", platform="android",
                    plain_name=MappingProxyType({"common/not_there_test.dart": "group B"}))

    with pytest.raises(ValueError, match="common/not_there_test.dart"):
        plan_runs("android", [target], platform_files(FIXTURE, "android"), [], 1)


def test_a_repeat_file_the_platform_does_not_run_is_an_error() -> None:
    target = Target(name="pixel_8", platform="android", repeat=MappingProxyType({RESTART_1: ("us01",)}))

    with pytest.raises(ValueError, match=RESTART_1):
        plan_runs("android", [target], platform_files(FIXTURE, "android"), [], 10)


def test_a_target_of_another_platform_is_an_error() -> None:
    with pytest.raises(ValueError, match="pixel_8"):
        plan_runs("linux", _android_targets(), platform_files(FIXTURE, "linux"), [], 1)


def test_entry_groups_each_file_by_its_path() -> None:
    (plan,) = plan_runs("android", [Target(name="p", platform="android")],
                        platform_files(FIXTURE, "android"), [], 1)["p"]

    source = entry_source(plan)

    assert "group('smoke/semantics_id_test.dart'" in source
    assert "group('common/web_view_test.dart'" in source
    assert source.count("IntegrationTestWidgetsFlutterBinding.ensureInitialized()") == 1
    for index in range(len(plan.files)):
        assert f" as f{index};" in source
        assert f"f{index}.main();" in source


def test_a_wrapped_file_is_grouped_by_its_original_path() -> None:
    (plan,) = _plans(10)["pixel_8"]

    source = entry_source(plan)

    assert "group('common/web_view_test.dart'" in source
    assert "'../common/.dt_web_view_test_x10.dart'" in source


def test_entry_records_results_for_drive() -> None:
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], 1)["p"]

    source = entry_source(plan)

    assert "reportData" in source
    assert "stratum_round" in source
    assert "binding.results" in source
    assert "setUpAll" in source
    assert "tearDownAll" in source
    assert "'success'" in source
    assert "'pass'" in source
    assert "'fail'" in source


def test_a_path_is_escaped_in_the_group_name() -> None:
    plan = RunPlan(key="none-x", platform="android", build_mode=None, kind="entry",
                   files=("odd/it's_$x_test.dart",), wrapped=MappingProxyType({}), repeat=1)

    source = entry_source(plan)

    assert "group('odd/it\\'s_\\$x_test.dart'" in source


def test_write_run_file_names_the_entry_by_platform_and_key(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (plan,) = plan_runs("android", [Target(name="p", platform="android", build_mode="debug")],
                        platform_files(FIXTURE, "android"), [], 1)["p"]

    path = write_run_file(plan, folder)

    assert path == folder / ".round" / f"android_{plan.key}_test.dart"
    assert path.read_text(encoding="utf-8") == entry_source(plan)


def test_a_sequence_has_no_entry_file(tmp_path: Path) -> None:
    sequence = RunSequence(name="fo10_cold_restart", target="linux", files=(RESTART_1, RESTART_2))
    _, alone = plan_runs("linux", [Target(name="linux", platform="linux")],
                         platform_files(FIXTURE, "linux"), [sequence], 1)["linux"]

    with pytest.raises(ValueError, match="sequence"):
        write_run_file(alone, tmp_path)


def test_cleanup_removes_round_folder_and_siblings(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (pixel_8_entry,) = _plans(10)["pixel_8"]
    entry = write_run_file(pixel_8_entry, folder)
    sibling = folder / "common" / ".dt_web_view_test_x10.dart"
    assert entry.is_file()
    assert sibling.is_file()

    cleanup(folder)

    assert not (folder / ".round").exists()
    assert not sibling.exists()
    assert sorted(path.relative_to(folder).as_posix() for path in folder.rglob("*.dart")) == sorted(
        platform_files(folder, "linux"),
    )


def test_cleanup_on_a_clean_folder_is_a_no_op(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)

    cleanup(folder)

    assert len(platform_files(folder, "linux")) == 9
