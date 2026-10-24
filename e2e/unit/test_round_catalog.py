"""Unit tests for the device round catalog and round resolution (design sections 7 and 15)."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.round.catalog import (
    TARGETS_TOML,
    Catalog,
    RunSequence,
    load_catalog,
    resolve_round,
)
from stratum_e2e.round.errors import CatalogError, RoundEnvError

FULL = (
    "pixel_8", "pixel_2", "small_phone", "tablet", "iphone", "mac", "chrome", "chrome_wasm", "linux",
    "iphone_e2e", "e2e_talkback",
)


@pytest.fixture(scope="module")
def catalog() -> Catalog:
    return load_catalog()


def _names(catalog: Catalog, target_arg: str | None, mode_arg: str | None,
           repeat_arg: int | None = None) -> tuple[str, ...]:
    plan = resolve_round(catalog, target_arg, mode_arg, repeat_arg)
    assert plan is not None
    return tuple(t.name for t in plan.targets)


def test_targets_toml_is_the_e2e_sibling() -> None:
    assert TARGETS_TOML.name == "targets.toml"
    assert TARGETS_TOML.is_file()


def test_targets_toml_holds_every_design_target(catalog: Catalog) -> None:
    assert set(catalog.targets) == {*FULL, "windows"}


def test_modes(catalog: Catalog) -> None:
    assert (catalog.modes["fast"].targets, catalog.modes["fast"].repeat) == (("mac",), 1)
    assert catalog.modes["full"].targets == FULL
    assert catalog.modes["full"].repeat == 10
    assert "windows" not in catalog.modes["full"].targets


def test_alone_targets(catalog: Catalog) -> None:
    alone = {name for name, target in catalog.targets.items() if target.alone}
    assert alone == {"pixel_8", "pixel_2", "small_phone", "tablet", "e2e_talkback"}


def test_e2e_flag_per_target(catalog: Catalog) -> None:
    with_e2e = {"pixel_8", "pixel_2", "small_phone", "tablet", "mac", "chrome", "chrome_wasm", "iphone_e2e",
                "e2e_talkback"}
    for name, target in catalog.targets.items():
        assert target.e2e is (name in with_e2e), name
    assert catalog.targets["iphone"].e2e is False
    assert catalog.targets["mac"].e2e is True


def test_integration_flag_per_target(catalog: Catalog) -> None:
    without_integration = {"iphone_e2e", "e2e_talkback", "windows"}
    for name, target in catalog.targets.items():
        assert target.integration is (name not in without_integration), name


def test_target_values(catalog: Catalog) -> None:
    targets = catalog.targets
    pixel_8 = targets["pixel_8"]
    assert (pixel_8.platform, pixel_8.avd, pixel_8.build_mode) == ("android", "Pixel_8_API_37", "profile")
    assert pixel_8.emulator_args == ("-gpu", "host", "-memory", "4096")
    assert (targets["pixel_2"].avd, targets["pixel_2"].build_mode) == ("Pixel_2_API_28", "debug")
    assert (targets["small_phone"].avd, targets["small_phone"].build_mode) == ("Small_Phone_API_33", "profile")
    assert (targets["tablet"].avd, targets["tablet"].build_mode) == ("Pixel_Tablet_API_35", "profile")

    iphone = targets["iphone"]
    assert (iphone.platform, iphone.device, iphone.runtime) == ("ios", "iPhone 17", None)
    iphone_e2e = targets["iphone_e2e"]
    assert (iphone_e2e.runtime, iphone_e2e.device, iphone_e2e.integration) == ("iOS 27.1", "iPhone Duo", False)

    assert (targets["e2e_talkback"].avd, targets["e2e_talkback"].integration) == ("E2E_TalkBack_API_35", False)
    assert targets["mac"].platform == "macos"
    assert (targets["chrome"].platform, targets["chrome"].browser, targets["chrome"].wasm) == ("web", "chrome", False)
    assert (targets["chrome_wasm"].browser, targets["chrome_wasm"].wasm) == ("chrome", True)

    linux = targets["linux"]
    assert linux.apt == ("libsecret-1-dev", "libwebkit2gtk-4.1-dev")
    assert linux.e2e is False

    windows = targets["windows"]
    assert (windows.catalog_only, windows.integration, windows.e2e) == (True, False, False)


def test_lane_values(catalog: Catalog) -> None:
    lane = catalog.lane
    assert (
        lane.run_timeout_minutes,
        lane.boot_settle_timeout_seconds,
        lane.allow_level2,
        lane.heavy_processes,
        lane.lane_wait_minutes,
        lane.boot_timeout_minutes,
    ) == (20, 420, True, ("perf_abba", "perf_freeze"), 30, 10)


def test_app_ids(catalog: Catalog) -> None:
    test_app = catalog.apps["test_app"]
    assert (test_app.name, test_app.folder, test_app.android_id, test_app.apple_id, test_app.driver) == (
        "test_app", "test_app", "dev.stratum.stratum_ui_test_app", "dev.stratum.stratumUiTestApp",
        "test_driver/integration_test.dart",
    )
    example = catalog.apps["example"]
    assert (example.folder, example.android_id, example.apple_id, example.perf) == (
        "example", "dev.stratum.stratum_ui_example", "dev.stratum.stratumUiExample", "dart run tool/perf_abba.dart",
    )
    assert example.driver is None
    assert test_app.perf is None


def test_real_catalog_names_only_files_the_test_app_has() -> None:
    load_catalog(TARGETS_TOML, TARGETS_TOML.parents[1] / "test_app" / "integration_test")


def test_unknown_target_fails_naming_it(catalog: Catalog) -> None:
    with pytest.raises(CatalogError, match="'nope'"):
        resolve_round(catalog, "mac,nope", None, None)


def test_unknown_mode_fails_naming_it(catalog: Catalog) -> None:
    with pytest.raises(CatalogError, match="'slow'"):
        resolve_round(catalog, None, "slow", None)


def test_target_replaces_mode_list_and_keeps_its_repeat(catalog: Catalog) -> None:
    plan = resolve_round(catalog, "pixel_8", "full", None)
    assert plan is not None
    assert (tuple(t.name for t in plan.targets), plan.mode, plan.repeat) == (("pixel_8",), "full", 10)


def test_target_without_mode_takes_fast_repeat(catalog: Catalog) -> None:
    plan = resolve_round(catalog, "pixel_8", None, None)
    assert plan is not None
    assert (plan.mode, plan.repeat) == ("fast", 1)


def test_mode_alone_takes_its_own_list(catalog: Catalog) -> None:
    assert _names(catalog, None, "full") == FULL
    assert _names(catalog, None, "fast") == ("mac",)


def test_repeat_flag_replaces_mode_count(catalog: Catalog) -> None:
    plan = resolve_round(catalog, None, "full", 20)
    assert plan is not None
    assert plan.repeat == 20


@pytest.mark.parametrize("bad", [0, -3])
def test_repeat_below_one_fails(catalog: Catalog, bad: int) -> None:
    with pytest.raises(CatalogError, match="--repeat"):
        resolve_round(catalog, None, "full", bad)


def test_no_target_no_mode_is_the_legacy_path(catalog: Catalog) -> None:
    assert resolve_round(catalog, None, None, None) is None


def test_repeat_alone_without_target_or_mode_takes_fast(catalog: Catalog) -> None:
    plan = resolve_round(catalog, None, None, 5)
    assert plan is not None
    assert (plan.mode, plan.repeat, tuple(t.name for t in plan.targets)) == ("fast", 5, ("mac",))


def test_target_list_trims_and_dedupes(catalog: Catalog) -> None:
    assert _names(catalog, " mac , chrome,mac", None) == ("mac", "chrome")


def test_windows_is_catalog_only(catalog: Catalog) -> None:
    with pytest.raises(CatalogError, match="catalog-only"):
        resolve_round(catalog, "windows", None, None)


def test_empty_target_list_fails(catalog: Catalog) -> None:
    with pytest.raises(CatalogError, match="--target"):
        resolve_round(catalog, " , ", None, None)


def test_round_env_error_prefixes_its_reason() -> None:
    error = RoundEnvError("lane busy")
    assert error.reason == "lane busy"
    assert str(error) == "env: lane busy"


# --- catalogs written to tmp_path -------------------------------------------------------------------------------

_BASE = """
[apps.test_app]
folder = "test_app"
android_id = "a.b"
apple_id = "a.B"

[targets.pixel_2]
platform = "android"
avd = "Pixel_2_API_28"
alone = true
build_mode = "debug"
{extra}

[modes.fast]
targets = ["pixel_2"]
repeat = 1

[lane]
run_timeout_minutes = 20
boot_settle_timeout_seconds = 420
allow_level2 = true
heavy_processes = []
lane_wait_minutes = 30
{sequences}
"""


def _write(tmp_path: Path, extra: str = "", sequences: str = "") -> Path:
    path = tmp_path / "targets.toml"
    path.write_text(_BASE.format(extra=extra, sequences=sequences), encoding="utf-8")
    return path


def _integration_dir(tmp_path: Path, *files: str) -> Path:
    root = tmp_path / "integration_test"
    for relative in files:
        file = root / relative
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text("void main() {}\n", encoding="utf-8")
    root.mkdir(exist_ok=True)
    return root


def test_base_catalog_loads(tmp_path: Path) -> None:
    assert list(load_catalog(_write(tmp_path)).targets) == ["pixel_2"]


@pytest.mark.parametrize(
    ("extra", "match"),
    [
        ("nope = 1", r"targets\.pixel_2 has unknown key 'nope'"),
        ('\n[targets.x]\nplatform = "amiga"', r"targets\.x\.platform 'amiga' is not one of"),
        ('\n[targets.x]\nplatform = 3', r"targets\.x\.platform must be a non-empty string"),
        ('\n[targets.x]\nplatform = "android"\navd = "A"\nbuild_mode = "fast"', r"build_mode 'fast'"),
        ('\n[targets.x]\nplatform = "android"', r"targets\.x\.avd must be a non-empty string"),
        ('\n[targets.x]\nplatform = "ios"', r"targets\.x\.device must be a non-empty string"),
        ('wasm = "yes"', r"targets\.pixel_2\.wasm must be true or false"),
        ('emulator_args = "-gpu host"', r"targets\.pixel_2\.emulator_args must be a list of strings"),
        (
            '\n[targets.w]\nplatform = "windows"\ncatalog_only = true\n\n[modes.full]\ntargets = ["w"]\nrepeat = 1',
            r"modes\.full\.targets names catalog-only target 'w'",
        ),
        ('\n[modes.full]\ntargets = ["nope"]\nrepeat = 1', r"modes\.full\.targets names unknown target 'nope'"),
        ('\n[modes.full]\ntargets = ["pixel_2"]\nrepeat = 0', r"modes\.full\.repeat must be at least 1"),
        ('\n[modes.full]\ntargets = ["pixel_2"]\nrepeat = "10"', r"modes\.full\.repeat must be an integer"),
    ],
    ids=[
        "unknown-key", "bad-platform", "platform-not-a-string", "bad-build-mode", "android-without-avd",
        "ios-without-device", "bool-as-string", "list-as-string", "catalog-only-in-a-mode", "unknown-target-in-a-mode",
        "mode-repeat-below-one", "mode-repeat-as-string",
    ],
)
def test_loader_rejects_a_bad_catalog_naming_the_table_and_key(tmp_path: Path, extra: str, match: str) -> None:
    with pytest.raises(CatalogError, match=match):
        load_catalog(_write(tmp_path, extra=extra))


def test_plain_name_feature_loads_for_an_existing_file(tmp_path: Path) -> None:
    path = _write(tmp_path, extra='[targets.pixel_2.plain_name]\n"common/web_view_test.dart" = "group B, native only"')
    integration = _integration_dir(tmp_path, "common/web_view_test.dart")
    target = load_catalog(path, integration).targets["pixel_2"]
    assert dict(target.plain_name) == {"common/web_view_test.dart": "group B, native only"}


def test_repeat_feature_loads_prefixes_in_order(tmp_path: Path) -> None:
    path = _write(tmp_path, extra='[targets.pixel_2.repeat]\n"common/web_view_test.dart" = ["f01/us08/s3", "f01/us08/fr01"]')
    integration = _integration_dir(tmp_path, "common/web_view_test.dart")
    target = load_catalog(path, integration).targets["pixel_2"]
    assert dict(target.repeat) == {"common/web_view_test.dart": ("f01/us08/s3", "f01/us08/fr01")}


def test_feature_naming_a_missing_file_fails(tmp_path: Path) -> None:
    path = _write(tmp_path, extra='[targets.pixel_2.plain_name]\n"common/gone_test.dart" = "group B"')
    integration = _integration_dir(tmp_path, "common/other_test.dart")
    with pytest.raises(CatalogError, match="common/gone_test.dart"):
        load_catalog(path, integration)


def test_repeat_feature_naming_a_missing_file_fails(tmp_path: Path) -> None:
    path = _write(tmp_path, extra='[targets.pixel_2.repeat]\n"common/gone_test.dart" = ["p"]')
    with pytest.raises(CatalogError, match="common/gone_test.dart"):
        load_catalog(path, _integration_dir(tmp_path))


def test_features_are_not_checked_without_an_integration_dir(tmp_path: Path) -> None:
    path = _write(tmp_path, extra='[targets.pixel_2.plain_name]\n"common/gone_test.dart" = "group B"')
    assert "common/gone_test.dart" in load_catalog(path).targets["pixel_2"].plain_name


def test_sequence_parses_files_in_order(tmp_path: Path) -> None:
    first, second = "common/r1_linux_test.dart", "common/r2_linux_test.dart"
    sequences = f'\n[sequences.fo10_cold_restart]\ntarget = "pixel_2"\nfiles = ["{first}", "{second}"]\n'
    path = _write(tmp_path, sequences=sequences)
    integration = _integration_dir(tmp_path, first, second)
    assert load_catalog(path, integration).sequences["fo10_cold_restart"] == RunSequence(
        "fo10_cold_restart", "pixel_2", (first, second)
    )


def test_sequence_naming_a_missing_file_fails(tmp_path: Path) -> None:
    sequences = '\n[sequences.s]\ntarget = "pixel_2"\nfiles = ["common/gone_test.dart"]\n'
    path = _write(tmp_path, sequences=sequences)
    with pytest.raises(CatalogError, match="common/gone_test.dart"):
        load_catalog(path, _integration_dir(tmp_path))


def test_sequence_naming_an_unknown_target_fails(tmp_path: Path) -> None:
    sequences = '\n[sequences.s]\ntarget = "nope"\nfiles = ["a_test.dart"]\n'
    with pytest.raises(CatalogError, match="'nope'"):
        load_catalog(_write(tmp_path, sequences=sequences))


def test_mode_naming_an_unknown_target_fails(tmp_path: Path) -> None:
    path = _write(tmp_path)
    path.write_text(path.read_text(encoding="utf-8").replace('targets = ["pixel_2"]', 'targets = ["ghost"]'),
                    encoding="utf-8")
    with pytest.raises(CatalogError, match="'ghost'"):
        load_catalog(path)


def test_missing_catalog_file_fails_naming_the_path(tmp_path: Path) -> None:
    with pytest.raises(CatalogError, match="absent.toml"):
        load_catalog(tmp_path / "absent.toml")


def test_malformed_toml_fails_as_a_catalog_error(tmp_path: Path) -> None:
    path = tmp_path / "targets.toml"
    path.write_text("[targets\n", encoding="utf-8")
    with pytest.raises(CatalogError, match="targets.toml"):
        load_catalog(path)
