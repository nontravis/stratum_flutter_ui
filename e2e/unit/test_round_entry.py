"""Unit tests for the integration entry planning and generation (design section 9 and 15); no Flutter, no device."""

from __future__ import annotations

import shutil
from pathlib import Path
from types import MappingProxyType

import pytest

from stratum_e2e.round.catalog import RunSequence, Target
from stratum_e2e.round.entry import (
    ENTRY_PREFIX,
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
SPLIT_WEB = "common/split_layout_setting_web_test.dart"
KEYBOARD_MOBILE = "common/keyboard_visibility_scope_mobile_test.dart"


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
        KEYBOARD_MOBILE,
        "common/reorderable_list_view_layout_test.dart",
        "common/screen_radius_scope_test.dart",
        WEB_VIEW,
        SMOKE,
    ]
    linux = platform_files(FIXTURE, "linux")
    assert len(linux) == 7
    assert {RESTART_1, RESTART_2, SYSTEM_STYLE_LINUX} <= set(linux)


@pytest.mark.parametrize("platform", ["android", "ios", "macos", "linux"])
def test_a_web_only_file_is_absent_off_web(platform: str) -> None:
    assert SPLIT_WEB not in platform_files(FIXTURE, platform)


def test_a_web_only_file_is_present_on_web_and_no_linux_only_file_is() -> None:
    web = platform_files(FIXTURE, "web")

    assert SPLIT_WEB in web
    assert not any(name.endswith("_linux_test.dart") for name in web)
    assert len(web) == 5


@pytest.mark.parametrize("platform", ["android", "ios"])
def test_a_mobile_only_file_is_present_on_android_and_ios(platform: str) -> None:
    assert KEYBOARD_MOBILE in platform_files(FIXTURE, platform)


@pytest.mark.parametrize("platform", ["macos", "web", "linux"])
def test_a_mobile_only_file_is_absent_off_mobile(platform: str) -> None:
    assert KEYBOARD_MOBILE not in platform_files(FIXTURE, platform)


def test_chrome_and_chrome_wasm_plan_the_web_only_file() -> None:
    targets = [Target(name="chrome", platform="web", browser="chrome"),
               Target(name="chrome_wasm", platform="web", browser="chrome", wasm=True)]

    plans = plan_runs("web", targets, platform_files(FIXTURE, "web"), [], 1)

    assert all(SPLIT_WEB in plan.files for target_plans in plans.values() for plan in target_plans)


def test_platform_files_never_list_a_round_entry_or_a_wrapped_sibling(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (folder / f"{ENTRY_PREFIX}android_none-12345678_test.dart").write_text("void main() {}\n", encoding="utf-8")
    (folder / "common" / ".dt_web_view_test_x10_test.dart").write_text("void main() {}\n", encoding="utf-8")

    files = platform_files(folder, "linux")

    assert len(files) == 7
    assert not any(ENTRY_PREFIX in f or ".dt_" in f for f in files)


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
    assert f"import '{WEB_VIEW}' as f" in entry_source(pixel_8_entry)
    assert plans["small_phone"][0] is pixel_8_entry


def test_repeat_flag_sets_the_wrap_count(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (pixel_8_entry,) = _plans(20)["pixel_8"]

    path = write_run_file(pixel_8_entry, folder)

    assert (folder / "common" / ".dt_web_view_test_x20.dart").is_file()
    source = entry_source(pixel_8_entry)
    assert "import 'common/.dt_web_view_test_x20.dart' as f" in source
    assert f"import '{WEB_VIEW}'" not in source
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


def test_a_repeat_file_also_run_alone_is_an_error() -> None:
    plain = Target(name="pixel_2", platform="android",
                   plain_name=MappingProxyType({WEB_VIEW: "group B"}), repeat=MappingProxyType({WEB_VIEW: ("a",)}))
    linux = Target(name="linux", platform="linux", repeat=MappingProxyType({RESTART_1: ("a",)}))
    sequence = RunSequence(name="fo10_cold_restart", target="linux", files=(RESTART_1, RESTART_2))

    with pytest.raises(ValueError, match=WEB_VIEW):
        plan_runs("android", [plain], platform_files(FIXTURE, "android"), [], 10)
    with pytest.raises(ValueError, match=RESTART_1):
        plan_runs("linux", [linux], platform_files(FIXTURE, "linux"), [sequence], 10)


@pytest.mark.parametrize("repeat", [0, -1])
def test_a_repeat_below_one_is_an_error(repeat: int) -> None:
    with pytest.raises(ValueError, match="repeat"):
        plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], repeat)


def test_entries_that_wrap_different_blocks_get_different_keys_and_paths() -> None:
    first = Target(name="a", platform="android", build_mode="profile",
                   repeat=MappingProxyType({WEB_VIEW: ("co01_02/us03/s1",)}))
    second = Target(name="b", platform="android", build_mode="profile",
                    repeat=MappingProxyType({WEB_VIEW: ("co01_02/us03/s3",)}))
    files = platform_files(FIXTURE, "android")

    plans = plan_runs("android", [first, second], files, [], 10)

    assert entry_source(plans["a"][0]) == entry_source(plans["b"][0])
    assert plans["a"][0].key != plans["b"][0].key
    assert plans["a"][0] != plans["b"][0]
    assert plans["a"][0].key.startswith("profile-")


def test_the_key_does_not_move_when_nothing_is_wrapped() -> None:
    files = platform_files(FIXTURE, "android")
    plain = plan_runs("android", [Target(name="p", platform="android")], files, [], 1)["p"][0]
    marked = Target(name="m", platform="android", repeat=MappingProxyType({WEB_VIEW: ("a",)}))

    assert plan_runs("android", [marked], files, [], 1)["m"][0] == plain


def test_sequences_with_equal_files_stay_two_plans_named_by_their_sequence() -> None:
    linux = Target(name="linux", platform="linux")
    first = RunSequence(name="first", target="linux", files=(RESTART_1, RESTART_2))
    second = RunSequence(name="second", target="linux", files=(RESTART_1, RESTART_2))

    plans = plan_runs("linux", [linux], platform_files(FIXTURE, "linux"), [first, second], 10)["linux"]

    assert [(plan.kind, plan.sequence) for plan in plans] == [("entry", None), ("sequence", "first"),
                                                              ("sequence", "second")]
    assert plans[1] != plans[2]


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
    assert "import 'common/.dt_web_view_test_x10.dart'" in source


def test_entry_records_results_for_drive() -> None:
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], 1)["p"]

    source = entry_source(plan)

    assert "reportData" in source
    assert "stratum_round" in source
    assert "binding.results" in source
    assert "setUp(" in source
    assert "tearDown(" in source
    assert "setUpAll(" not in source
    assert source.count("tearDownAll(") == 1
    assert "'success'" in source
    assert "'pass'" in source
    assert "'fail'" in source


def test_each_test_puts_the_round_map_back_when_a_test_replaces_report_data() -> None:
    """A test may assign `binding.reportData = {...}`; the next `tearDown` must restore the round's map in whatever
    map is then held, or the driver's response loses every file's result (M7-T35)."""
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], 1)["p"]

    source = entry_source(plan)

    keep_round = source[source.index("void keepRound()"):source.index("keepRound();")]
    assert "(binding.reportData ??= <String, dynamic>{})['stratum_round'] = round" in keep_round
    tear_down = source[source.index("tearDown("):source.index("f0.main();")]
    assert "keepRound();" in tear_down


def test_each_test_records_a_runtime_skip_as_skip() -> None:
    """`markTestSkipped` on a drive target still leaves `results[name] == 'success'`; the live test's state tells."""
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], 1)["p"]

    source = entry_source(plan)

    assert "import 'package:test_api/src/backend/invoker.dart' show Invoker;" in source
    assert "import 'package:test_api/src/backend/state.dart' show Result;" in source
    tear_down = source[source.index("tearDown("):source.index("f0.main();")]
    assert "state.result == Result.skipped" in tear_down
    assert "'skip'" in tear_down


def test_a_failing_live_state_records_fail_before_skip_before_pass() -> None:
    """An error in a test's own `tearDown` never reaches the binding, which keeps 'success'; the live state fails."""
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], 1)["p"]

    source = entry_source(plan)

    tear_down = source[source.index("tearDown("):source.index("f0.main();")]
    assert "Invoker.current!.liveTest.state" in tear_down
    assert "state.result.isFailing" in tear_down
    assert "Result.skipped" in tear_down
    assert tear_down.index("isFailing") < tear_down.index("Result.skipped") < tear_down.index("'pass'")


def test_an_entry_level_tear_down_all_keeps_the_round_map() -> None:
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], 1)["p"]

    source = entry_source(plan)

    assert source.count("tearDownAll(keepRound);") == 1
    assert source.index("tearDownAll(keepRound);") > source.index("f0.main();")


def test_the_template_names_the_nested_set_up_all_limit() -> None:
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [SMOKE], [], 1)["p"]

    assert "a nested group's setUpAll that fails" in entry_source(plan)


def test_each_file_records_its_own_results_when_two_files_share_a_test_name() -> None:
    """Both files may declare `testWidgets('same name')`; `binding.results` is keyed by that bare name alone."""
    first, second = KEYBOARD_MOBILE, "common/screen_radius_scope_test.dart"
    (plan,) = plan_runs("android", [Target(name="p", platform="android")], [first, second], [], 1)["p"]

    source = entry_source(plan)

    for index, path in enumerate((first, second)):
        group = source[source.index(f"group('{path}'"):]
        group = group[: group.index(f"f{index}.main();")]
        assert f"round['{path}'] = file;" in group
        assert "binding.results.clear();" in group
        assert "file[result.key] = 'fail';" in group
        assert "file[result.key] = 'pass';" in group
    assert source.count("round['") == 2
    assert source.count("final file = <String, String>{};") == 2
    assert "seen" not in source


def test_a_path_is_escaped_in_the_group_name() -> None:
    plan = RunPlan(key="none-x", platform="android", build_mode=None, kind="entry",
                   files=("odd/it's_$x_test.dart",), wrapped=MappingProxyType({}), repeat=1)

    source = entry_source(plan)

    assert "group('odd/it\\'s_\\$x_test.dart'" in source


def test_write_run_file_puts_the_entry_beside_the_files_it_imports(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (plan,) = plan_runs("android", [Target(name="p", platform="android", build_mode="debug")],
                        platform_files(FIXTURE, "android"), [], 1)["p"]

    path = write_run_file(plan, folder)

    # A web run roots `org-dartlang-app:///` at the entry's own folder, so an import may never climb above it.
    assert path == folder / f"{ENTRY_PREFIX}android_{plan.key}_test.dart"
    assert path.read_text(encoding="utf-8") == entry_source(plan)


def test_a_sequence_has_no_entry_file(tmp_path: Path) -> None:
    sequence = RunSequence(name="fo10_cold_restart", target="linux", files=(RESTART_1, RESTART_2))
    _, alone = plan_runs("linux", [Target(name="linux", platform="linux")],
                         platform_files(FIXTURE, "linux"), [sequence], 1)["linux"]

    with pytest.raises(ValueError, match="sequence"):
        write_run_file(alone, tmp_path)


def test_cleanup_removes_the_entry_and_siblings(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)
    (pixel_8_entry,) = _plans(10)["pixel_8"]
    entry = write_run_file(pixel_8_entry, folder)
    sibling = folder / "common" / ".dt_web_view_test_x10.dart"
    assert entry.is_file()
    assert sibling.is_file()

    cleanup(folder)

    assert not entry.exists()
    assert not sibling.exists()
    assert sorted(path.relative_to(folder).as_posix() for path in folder.rglob("*.dart")) == sorted(
        {*platform_files(folder, "linux"), *platform_files(folder, "web"), *platform_files(folder, "android")},
    )


def test_cleanup_on_a_clean_folder_is_a_no_op(tmp_path: Path) -> None:
    folder = tmp_path / "integration_test"
    shutil.copytree(FIXTURE, folder)

    cleanup(folder)

    assert len(platform_files(folder, "linux")) == 7
