"""Unit tests for marker-driven platform selection."""

from __future__ import annotations

import pytest

from stratum_e2e.android.adb import STYLUS_AVD, TALKBACK_AVD
from stratum_e2e.round.catalog import Target
from stratum_e2e.selection import PLATFORMS, runs_e2e, skip_reason


def test_skip_reason_none_when_marker_matches() -> None:
    assert skip_reason({"android", "level1"}, "android") is None


def test_skip_reason_names_platform() -> None:
    assert skip_reason({"ios"}, "android") == "not marked android"


def test_skip_reason_without_platform() -> None:
    assert skip_reason({"android"}, None) == "no --platform given"


def test_skip_reason_web_ignored_without_platform() -> None:
    assert skip_reason({"web", "level2"}, None) == "no --platform given"


def test_skip_reason_skips_a_perf_item_even_on_its_platform() -> None:
    assert skip_reason({"perf", "macos"}, "macos") == "perf runs only in a device round"


@pytest.mark.parametrize("platform", sorted(PLATFORMS))
def test_skip_reason_each_platform(platform: str) -> None:
    assert skip_reason({platform}, platform) is None
    assert all(skip_reason({platform}, other) is not None for other in PLATFORMS - {platform})


def _target(
    name: str,
    platform: str,
    *,
    avd: str | None = None,
    integration: bool = True,
    e2e: bool = True,
    browser: str | None = None,
    wasm: bool = False,
) -> Target:
    return Target(name=name, platform=platform, avd=avd, integration=integration, e2e=e2e, browser=browser, wasm=wasm)


SHARED_ANDROID = _target("pixel_8", "android", avd="Pixel_8_API_37")
TALKBACK = _target("e2e_talkback", "android", avd=TALKBACK_AVD, integration=False)
STYLUS = _target("e2e_stylus", "android", avd=STYLUS_AVD, integration=False)


def test_runs_e2e_shared_android_runs_plain_and_level1_items() -> None:
    assert runs_e2e(SHARED_ANDROID, {"android"})
    assert runs_e2e(SHARED_ANDROID, {"android", "level1"})


@pytest.mark.parametrize("marker", ["talkback_avd", "level2"])
def test_runs_e2e_shared_android_never_runs_talkback_or_level2(marker: str) -> None:
    assert not runs_e2e(SHARED_ANDROID, {"android", marker})
    assert not runs_e2e(SHARED_ANDROID, {"android", "talkback_avd", "level2"})


@pytest.mark.parametrize("markers", [{"android", "talkback_avd"}, {"android", "level2"}, {"android", "level2", "talkback_avd"}])
def test_runs_e2e_talkback_target_runs_talkback_and_level2_items(markers: set[str]) -> None:
    assert runs_e2e(TALKBACK, markers)


def test_runs_e2e_talkback_target_skips_plain_android_items() -> None:
    assert not runs_e2e(TALKBACK, {"android"})
    assert not runs_e2e(TALKBACK, {"android", "level1"})


def test_runs_e2e_shared_android_never_runs_stylus_items() -> None:
    assert not runs_e2e(SHARED_ANDROID, {"android", "stylus_avd"})


def test_runs_e2e_stylus_target_runs_only_stylus_items() -> None:
    assert runs_e2e(STYLUS, {"android", "stylus_avd"})
    assert runs_e2e(STYLUS, {"android", "stylus_avd", "level1"})


@pytest.mark.parametrize("markers", [{"android"}, {"android", "level1"}, {"android", "talkback_avd"}, {"android", "level2"}])
def test_runs_e2e_stylus_target_skips_every_other_android_item(markers: set[str]) -> None:
    assert not runs_e2e(STYLUS, markers)


@pytest.mark.parametrize("markers", [{"android", "stylus_avd"}, {"android", "stylus_avd", "level2"}])
def test_runs_e2e_talkback_target_skips_items_marked_for_the_stylus_avd(markers: set[str]) -> None:
    assert not runs_e2e(TALKBACK, markers)


def test_runs_e2e_an_item_marked_for_both_dedicated_avds_runs_on_neither() -> None:
    markers = {"android", "stylus_avd", "talkback_avd"}
    assert not runs_e2e(STYLUS, markers)
    assert not runs_e2e(TALKBACK, markers)
    assert not runs_e2e(SHARED_ANDROID, markers)


def test_runs_e2e_android_target_skips_other_platform_items() -> None:
    assert not runs_e2e(SHARED_ANDROID, {"ios"})
    assert not runs_e2e(SHARED_ANDROID, {"macos", "web"})


def test_runs_e2e_ios_target_runs_ios_items_only_with_e2e() -> None:
    assert runs_e2e(_target("iphone_e2e", "ios", integration=False), {"ios"})
    assert not runs_e2e(_target("iphone_e2e", "ios"), {"android"})
    assert not runs_e2e(_target("iphone", "ios", e2e=False), {"ios"})


def test_runs_e2e_mac_runs_macos_items() -> None:
    mac = _target("mac", "macos")
    assert runs_e2e(mac, {"macos"})
    assert not runs_e2e(mac, {"web"})


@pytest.mark.parametrize("wasm", [False, True])
def test_runs_e2e_web_targets_run_web_items(wasm: bool) -> None:
    chrome = _target("chrome", "web", browser="chrome", wasm=wasm)
    assert runs_e2e(chrome, {"web"})
    assert not runs_e2e(chrome, {"macos"})


def test_runs_e2e_perf_items_run_only_on_mac() -> None:
    assert runs_e2e(_target("mac", "macos"), {"perf"})
    assert runs_e2e(_target("mac", "macos"), {"macos", "perf"})
    assert not runs_e2e(SHARED_ANDROID, {"perf"})
    assert not runs_e2e(_target("chrome", "web", browser="chrome"), {"web", "perf"})


def test_runs_e2e_target_without_e2e_runs_nothing() -> None:
    assert not runs_e2e(_target("linux", "linux", e2e=False), {"android", "ios", "macos", "web", "perf"})
    assert not runs_e2e(_target("mac", "macos", e2e=False), {"macos", "perf"})


HOST_MARKERS = {"level2", "level2_host"}


@pytest.mark.parametrize("platform", ["macos", "web"])
def test_skip_reason_skips_a_level2_host_item_without_the_opt_in(platform: str) -> None:
    """A command-line `-m` replaces the addopts default; only --host-voiceover lets a host leg start VoiceOver."""
    assert skip_reason({platform, *HOST_MARKERS}, platform) == "level2_host runs only with --host-voiceover"
    assert skip_reason({platform, *HOST_MARKERS}, platform, host_voiceover=False) is not None


@pytest.mark.parametrize("platform", ["macos", "web"])
def test_skip_reason_runs_a_level2_host_item_with_the_opt_in(platform: str) -> None:
    assert skip_reason({platform, *HOST_MARKERS}, platform, host_voiceover=True) is None
    assert skip_reason({platform, *HOST_MARKERS}, None, host_voiceover=True) == "no --platform given"


def test_skip_reason_opt_in_never_runs_a_perf_item() -> None:
    assert skip_reason({"perf", "macos"}, "macos", host_voiceover=True) == "perf runs only in a device round"


@pytest.mark.parametrize(
    ("target", "platform"),
    [(_target("mac", "macos"), "macos"), (_target("chrome", "web", browser="chrome"), "web")],
)
def test_runs_e2e_runs_a_level2_host_item_only_with_the_opt_in(target: Target, platform: str) -> None:
    assert not runs_e2e(target, {platform, *HOST_MARKERS})
    assert not runs_e2e(target, {platform, *HOST_MARKERS}, host_voiceover=False)
    assert runs_e2e(target, {platform, *HOST_MARKERS}, host_voiceover=True)


def test_runs_e2e_opt_in_runs_no_level2_host_item_on_android() -> None:
    assert not runs_e2e(TALKBACK, {"macos", *HOST_MARKERS}, host_voiceover=True)
    assert not runs_e2e(SHARED_ANDROID, {"web", *HOST_MARKERS}, host_voiceover=True)
