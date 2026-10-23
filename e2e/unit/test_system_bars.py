"""Unit tests for the system-bar probe port (M3-T17).

The goldens in ``fixtures/system_bars/verdicts.txt`` are the ``PROBE PASS|FAIL``
lines that ``example/integration_test/system_style_device_test.probes.py`` printed
at ``74dc421`` for every capture folder; the port must reach the same verdict per
check.
"""

from __future__ import annotations

import struct
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence

import pytest

from stratum_e2e.system_bars import (
    DEFAULT_PACKAGE,
    ForeignFocusError,
    SystemBarsError,
    bar_fill_brightness,
    bars_hidden,
    bars_shown,
    brightness_of,
    icon_appearance,
    parse_appearance,
    read_png,
    recents_label,
)

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "system_bars"
VERDICTS = FIXTURES / "verdicts.txt"

# The fixtures were captured from the example app, not from test_app.
FIXTURE_PACKAGE = "dev.stratum.stratum_ui_example"

# Captured after the probe port, so no probe printed verdicts for it; its own tests judge it.
SPLASH_FIXTURE = "pixel_8_api37_splash"


@dataclass(frozen=True)
class Golden:
    folder: str
    platform: str
    verdicts: dict[str, bool]


def _load_goldens() -> list[Golden]:
    goldens: list[Golden] = []
    folder = platform = ""
    verdicts: dict[str, bool] = {}
    for line in VERDICTS.read_text().splitlines():
        if line.startswith("## "):
            if folder:
                goldens.append(Golden(folder, platform, verdicts))
            _, folder, platform = line.split()
            verdicts = {}
        elif line.startswith("PROBE "):
            _, word, rest = line.split(" ", 2)
            verdicts[rest.split(":", 1)[0]] = word == "PASS"
    if folder:
        goldens.append(Golden(folder, platform, verdicts))
    return goldens


GOLDENS = _load_goldens()


def _read(folder: Path, name: str, suffix: str) -> str:
    return (folder / f"{name}.{suffix}").read_text()


def _sdk(folder: Path) -> int:
    for line in (folder / "device.txt").read_text().splitlines():
        key, _, value = line.partition("=")
        if key.strip() == "sdk" and value.strip().isdigit():
            return int(value.strip())
    raise SystemBarsError("device.txt carries no sdk")


def _icon_check(folder: Path, platform: str, name: str, expected: str) -> bool:
    if platform == "android":
        actual = icon_appearance(
            platform,
            window_dump=_read(folder, name, "window.txt"),
            sdk=_sdk(folder),
            package=FIXTURE_PACKAGE,
        )
    else:
        actual = icon_appearance(platform, png=(folder / f"{name}.png").read_bytes())
    return actual == expected


def _fill_check(folder: Path, platform: str) -> bool:
    return bar_fill_brightness((folder / "dark_statusbar.png").read_bytes(), platform) == "dark"


def _bars_check(folder: Path, name: str, check: Callable[..., bool]) -> bool:
    return check(_read(folder, name, "window.txt"), package=FIXTURE_PACKAGE)


def _recents_check(folder: Path) -> bool:
    label = recents_label(_read(folder, "recents_label", "activities.txt"), package=FIXTURE_PACKAGE)
    if label is None:
        raise SystemBarsError("no activity block for the app")
    return label == "Video"


def _checks(folder: Path, platform: str) -> dict[str, Callable[[], bool]]:
    """Mirror of ``_CHECKS`` in the probe: check name to the call that decides it."""
    checks: dict[str, Callable[[], bool]] = {
        "dark_header": lambda: _icon_check(folder, platform, "dark_header", "light"),
        "white_page": lambda: _icon_check(folder, platform, "white_page", "dark"),
        "dark_statusbar": lambda: _icon_check(folder, platform, "dark_statusbar", "light"),
        "dark_statusbar_fill": lambda: _fill_check(folder, platform),
    }
    if platform == "android":
        checks["video_bars_hidden"] = lambda: _bars_check(folder, "video_bars_hidden", bars_hidden)
        checks["video_bars_shown"] = lambda: _bars_check(folder, "video_bars_shown", bars_shown)
        checks["video_back"] = lambda: _bars_check(folder, "video_back", bars_hidden)
        checks["recents_label"] = lambda: _recents_check(folder)
    return checks


def _verdicts(folder: Path, platform: str) -> dict[str, bool]:
    verdicts: dict[str, bool] = {}
    for name, run in _checks(folder, platform).items():
        try:
            verdicts[name] = run()
        except (SystemBarsError, FileNotFoundError, ValueError):
            verdicts[name] = False
    return verdicts


def _capture_folders() -> set[str]:
    return {
        path.relative_to(FIXTURES).as_posix()
        for path in FIXTURES.rglob("*")
        if path.is_dir()
        and path.name != SPLASH_FIXTURE
        and any(f.suffix in {".png", ".txt"} for f in path.iterdir() if f.is_file())
    }


@pytest.mark.parametrize("golden", GOLDENS, ids=[g.folder for g in GOLDENS])
def test_port_matches_probe_verdicts(golden: Golden) -> None:
    folder = FIXTURES / golden.folder
    assert _verdicts(folder, golden.platform) == golden.verdicts


def test_every_capture_folder_has_goldens() -> None:
    assert {g.folder for g in GOLDENS} == _capture_folders() - {"."}


def test_goldens_hold_both_verdicts() -> None:
    seen = {verdict for g in GOLDENS for verdict in g.verdicts.values()}
    assert seen == {True, False}


# ---------------------------------------------------------------------------
# PNG decoder: one hand-built image per filter type
# ---------------------------------------------------------------------------


def _chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def _encode_png(
    rows: Sequence[Sequence[tuple[int, ...]]],
    *,
    color_type: int,
    filters: list[int],
    bit_depth: int = 8,
) -> bytes:
    """Encodes ``rows`` with the given per-row filter types (the inverse of the decoder)."""
    channels = {0: 1, 2: 3, 6: 4}[color_type]
    stride = len(rows[0]) * channels
    prev = bytes(stride)
    raw = bytearray()
    for row, ftype in zip(rows, filters):
        line = bytes(value for pixel in row for value in pixel)
        out = bytearray()
        for i, byte in enumerate(line):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if ftype == 0:
                predictor = 0
            elif ftype == 1:
                predictor = a
            elif ftype == 2:
                predictor = b
            elif ftype == 3:
                predictor = (a + b) // 2
            else:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                predictor = a if pa <= pb and pa <= pc else b if pb <= pc else c
            out.append((byte - predictor) & 0xFF)
        raw += bytes([ftype]) + out
        prev = line
    ihdr = struct.pack(">IIBBBBB", len(rows[0]), len(rows), bit_depth, color_type, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(bytes(raw)))
        + _chunk(b"IEND", b"")
    )


_RGBA_ROWS = [
    [(10, 20, 30, 255), (200, 100, 50, 128), (0, 255, 0, 255)],
    [(1, 2, 3, 4), (250, 251, 252, 253), (90, 80, 70, 60)],
    [(255, 0, 0, 255), (0, 0, 255, 255), (12, 34, 56, 78)],
    [(5, 5, 5, 255), (6, 6, 6, 255), (7, 7, 7, 255)],
    [(100, 150, 200, 255), (101, 151, 201, 255), (99, 149, 199, 255)],
]


@pytest.mark.parametrize("ftype", [0, 1, 2, 3, 4])
def test_read_png_unfilters_every_filter_type(ftype: int) -> None:
    png = read_png(_encode_png(_RGBA_ROWS, color_type=6, filters=[ftype] * len(_RGBA_ROWS)))
    assert (png.width, png.height) == (3, 5)
    for y, row in enumerate(_RGBA_ROWS):
        for x, pixel in enumerate(row):
            assert png.get(x, y) == pixel


def test_read_png_mixes_filter_types_across_rows() -> None:
    png = read_png(_encode_png(_RGBA_ROWS, color_type=6, filters=[0, 1, 2, 3, 4]))
    assert png.get(1, 1) == _RGBA_ROWS[1][1]
    assert png.get(2, 4) == _RGBA_ROWS[4][2]


def test_read_png_rgb_has_opaque_alpha() -> None:
    rows = [[(1, 2, 3), (4, 5, 6)], [(7, 8, 9), (10, 11, 12)]]
    png = read_png(_encode_png(rows, color_type=2, filters=[0, 0]))
    assert png.get(1, 1) == (10, 11, 12, 255)


def test_read_png_gray_expands_to_rgb() -> None:
    png = read_png(_encode_png([[(10,), (20,)]], color_type=0, filters=[0]))
    assert png.get(1, 0) == (20, 20, 20, 255)


@pytest.mark.parametrize(
    ("data", "message"),
    [
        (b"not a png at all", "bad signature"),
        (b"\x89PNG\r\n\x1a\n" + _chunk(b"IEND", b""), "missing IHDR"),
    ],
)
def test_read_png_rejects_malformed(data: bytes, message: str) -> None:
    with pytest.raises(ValueError, match=message):
        read_png(data)


def test_read_png_rejects_16_bit() -> None:
    data = _encode_png([[(1, 2, 3)]], color_type=2, filters=[0], bit_depth=16)
    with pytest.raises(ValueError, match="bit depth"):
        read_png(data)


def test_read_png_rejects_unsupported_color_type() -> None:
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 3, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", zlib.compress(b"\x00\x00"))
    )
    with pytest.raises(ValueError, match="color type"):
        read_png(data)


def test_read_png_rejects_interlaced() -> None:
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 1)
    data = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", zlib.compress(b"\x00abc"))
    with pytest.raises(ValueError, match="interlaced"):
        read_png(data)


def test_read_png_rejects_unknown_filter_type() -> None:
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", zlib.compress(b"\x09\x00"))
    )
    with pytest.raises(ValueError, match="filter type 9"):
        read_png(data)


# ---------------------------------------------------------------------------
# Brightness and status-bar sampling
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("rgb", "expected"),
    [
        ((255, 255, 255), "light"),
        ((0, 0, 0), "dark"),
        ((128, 128, 128), "light"),
        ((127, 127, 127), "dark"),
    ],
)
def test_brightness_of_splits_at_mid_luma(rgb: tuple[int, int, int], expected: str) -> None:
    assert brightness_of(rgb) == expected


def _solid_png(width: int, height: int, fill: tuple[int, int, int]) -> bytes:
    return _encode_png([[fill] * width] * height, color_type=2, filters=[0] * height)


def test_bar_fill_brightness_reads_the_dominant_strip_color() -> None:
    assert bar_fill_brightness(_solid_png(100, 100, (10, 10, 10)), "android") == "dark"
    assert bar_fill_brightness(_solid_png(100, 100, (240, 240, 240)), "ios") == "light"


def test_bar_fill_brightness_on_a_narrow_image_falls_back_to_the_whole_strip() -> None:
    assert bar_fill_brightness(_solid_png(2, 40, (240, 240, 240)), "android") == "light"


WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def _png_with_marks(width: int, marks: dict[tuple[int, int], tuple[int, int, int]]) -> bytes:
    """A white 100px-tall screenshot with ``marks`` painted in; the strip is rows 1-4."""
    rows = [[marks.get((x, y), WHITE) for x in range(width)] for y in range(100)]
    return _encode_png(rows, color_type=2, filters=[0] * len(rows))


def test_icon_appearance_ios_picks_a_mark_inside_the_icon_margin() -> None:
    png = _png_with_marks(100, {(5, 2): BLACK})
    assert icon_appearance("ios", png=png) == "dark"


def test_icon_appearance_ios_ignores_a_mark_between_the_margin_and_the_cutout() -> None:
    png = _png_with_marks(100, {(30, 2): BLACK})
    with pytest.raises(SystemBarsError, match="no visible status-bar icons"):
        icon_appearance("ios", png=png)


def test_icon_appearance_ios_ignores_a_mark_inside_the_cutout() -> None:
    png = _png_with_marks(100, {(50, 2): BLACK})
    with pytest.raises(SystemBarsError, match="no visible status-bar icons"):
        icon_appearance("ios", png=png)


def test_bar_fill_brightness_ignores_a_dark_cutout() -> None:
    marks = {(x, y): BLACK for x in range(42, 58) for y in range(0, 6)}
    assert bar_fill_brightness(_png_with_marks(100, marks), "ios") == "light"


def test_icon_appearance_ios_ignores_the_debug_banner_on_a_device_sized_image() -> None:
    png = _png_with_marks(600, {(590, 2): BLACK})
    with pytest.raises(SystemBarsError, match="no visible status-bar icons"):
        icon_appearance("ios", png=png)


def test_icon_appearance_ios_keeps_a_mark_left_of_the_debug_banner() -> None:
    png = _png_with_marks(600, {(10, 2): BLACK, (590, 2): BLACK})
    assert icon_appearance("ios", png=png) == "dark"


def test_icon_appearance_ios_without_visible_icon_raises() -> None:
    with pytest.raises(SystemBarsError, match="no visible status-bar icons"):
        icon_appearance("ios", png=_solid_png(150, 100, (255, 255, 255)))


def test_icon_appearance_ios_requires_png() -> None:
    with pytest.raises(ValueError, match="png"):
        icon_appearance("ios")


def test_icon_appearance_android_requires_dump_and_sdk() -> None:
    with pytest.raises(ValueError, match="window_dump"):
        icon_appearance("android", sdk=36)
    with pytest.raises(ValueError, match="sdk"):
        icon_appearance("android", window_dump="")


def test_icon_appearance_rejects_unknown_platform() -> None:
    with pytest.raises(ValueError, match="platform"):
        icon_appearance("web")


# ---------------------------------------------------------------------------
# Android dump parsing
# ---------------------------------------------------------------------------


def _window_dump(
    *, focus: str, apr: str = "", vsysui: str = "", package: str = DEFAULT_PACKAGE, inset: str = ""
) -> str:
    return (
        "WINDOW MANAGER WINDOWS (dumpsys window windows)\n"
        f"  Window #0 Window{{abc u0 {package}/.MainActivity}}:\n"
        f"    package={package} appop=NONE\n"
        f"    mAttrs={{(0,0)(fillxfill) apr={apr} vsysui={vsysui}}}\n"
        f"  mCurrentFocus=Window{{abc u0 {focus}}}\n"
        f"{inset}"
        "WINDOW MANAGER LAST ANR (dumpsys window lastanr)\n"
    )


_STATUS_HIDDEN = "type=statusBars frame=[0,0][1,1] visible=false\n"
_NAV_HIDDEN = "type=navigationBars frame=[0,0][1,1] visible=false\n"


def test_default_package_is_the_test_app() -> None:
    assert DEFAULT_PACKAGE == "dev.stratum.stratum_ui_test_app"


def test_icon_appearance_android_reads_light_status_bars_bit() -> None:
    dump = _window_dump(focus=f"{DEFAULT_PACKAGE}/.MainActivity", apr="LIGHT_STATUS_BARS")
    assert icon_appearance("android", window_dump=dump, sdk=36) == "dark"
    dump = _window_dump(focus=f"{DEFAULT_PACKAGE}/.MainActivity", apr="")
    assert icon_appearance("android", window_dump=dump, sdk=36) == "light"


def test_icon_appearance_android_below_api_30_reads_vsysui() -> None:
    dump = _window_dump(focus=f"{DEFAULT_PACKAGE}/.MainActivity", vsysui="LIGHT_STATUS_BAR")
    assert icon_appearance("android", window_dump=dump, sdk=28) == "dark"
    assert icon_appearance("android", window_dump=dump, sdk=36) == "light"


def test_icon_appearance_android_reads_the_package_it_is_given() -> None:
    dump = _window_dump(focus="other.app/.A", apr="LIGHT_STATUS_BARS", package="other.app")
    assert icon_appearance("android", window_dump=dump, sdk=36, package="other.app") == "dark"


def test_icon_appearance_android_reads_light_when_the_package_has_no_window_block() -> None:
    dump = _window_dump(focus="", apr="LIGHT_STATUS_BARS", package="other.app")
    dump = dump.replace("  mCurrentFocus=Window{abc u0 }\n", "")
    assert icon_appearance("android", window_dump=dump, sdk=36) == "light"


def test_the_default_package_treats_the_example_app_as_foreign() -> None:
    dump = _window_dump(focus=f"{FIXTURE_PACKAGE}/.MainActivity", package=FIXTURE_PACKAGE)
    with pytest.raises(ForeignFocusError):
        icon_appearance("android", window_dump=dump, sdk=36)


def test_foreign_focus_raises_instead_of_reading_another_windows_fields() -> None:
    dump = _window_dump(
        focus=f"Application Not Responding: {DEFAULT_PACKAGE}", apr="LIGHT_STATUS_BARS"
    )
    with pytest.raises(ForeignFocusError, match="Application Not Responding"):
        icon_appearance("android", window_dump=dump, sdk=36)
    with pytest.raises(ForeignFocusError):
        bars_hidden(dump)
    with pytest.raises(ForeignFocusError):
        bars_shown(dump)


def test_immersive_mode_confirmation_focus_is_not_a_violation() -> None:
    dump = _window_dump(focus="ImmersiveModeConfirmation", apr="LIGHT_STATUS_BARS")
    assert icon_appearance("android", window_dump=dump, sdk=36) == "dark"


def test_dump_without_focus_line_is_not_a_violation() -> None:
    dump = "".join(
        line
        for line in _window_dump(focus="x", apr="LIGHT_STATUS_BARS").splitlines(keepends=True)
        if "mCurrentFocus" not in line
    )
    assert icon_appearance("android", window_dump=dump, sdk=36) == "dark"


def test_m_focused_window_is_read_when_current_focus_is_absent() -> None:
    dump = _window_dump(focus="x", apr="LIGHT_STATUS_BARS").replace(
        "mCurrentFocus", "mFocusedWindow"
    )
    with pytest.raises(ForeignFocusError):
        icon_appearance("android", window_dump=dump, sdk=36)


def test_bars_hidden_and_shown_read_inset_sources() -> None:
    focus = f"{DEFAULT_PACKAGE}/.MainActivity"
    hidden = _window_dump(focus=focus, inset=_STATUS_HIDDEN + _NAV_HIDDEN)
    shown = _window_dump(
        focus=focus,
        inset=_STATUS_HIDDEN.replace("false", "true") + _NAV_HIDDEN.replace("false", "true"),
    )
    mixed = _window_dump(focus=focus, inset=_STATUS_HIDDEN + _NAV_HIDDEN.replace("false", "true"))
    assert bars_hidden(hidden) and not bars_shown(hidden)
    assert bars_shown(shown) and not bars_hidden(shown)
    assert not bars_hidden(mixed) and not bars_shown(mixed)


def test_bars_fall_back_to_vsysui_below_api_30() -> None:
    focus = f"{DEFAULT_PACKAGE}/.MainActivity"
    assert bars_hidden(_window_dump(focus=focus, vsysui="FULLSCREEN HIDE_NAVIGATION"))
    assert bars_shown(_window_dump(focus=focus, vsysui="LIGHT_STATUS_BAR"))


def test_bars_unparseable_dump_raises() -> None:
    with pytest.raises(SystemBarsError, match="could not parse"):
        bars_hidden("WINDOW MANAGER WINDOWS (dumpsys window windows)\n")
    with pytest.raises(SystemBarsError, match="could not parse"):
        bars_shown("")


_ACTIVITIES = (
    "  Task id #7\n"
    "    * Hist #0: ActivityRecord{1a u0 {package}/.MainActivity t7}\n"
    '        taskDescription: label="{label}" icon=null\n'
    "    * Hist #1: ActivityRecord{2b u0 other.app/.A t8}\n"
    '        taskDescription: label="Other"\n'
)


def test_recents_label_reads_the_apps_own_block() -> None:
    dump = _ACTIVITIES.replace("{package}", DEFAULT_PACKAGE).replace("{label}", "Video")
    assert recents_label(dump) == "Video"


def test_recents_label_is_empty_when_the_block_sets_none() -> None:
    dump = f"    * Hist #0: ActivityRecord{{1a u0 {DEFAULT_PACKAGE}/.MainActivity t7}}\n        other: x\n"
    assert recents_label(dump) == ""


def test_recents_label_is_none_when_the_block_is_missing() -> None:
    assert recents_label("    * Hist #0: ActivityRecord{1a u0 other.app/.A t7}\n") is None


# ---------------------------------------------------------------------------
# A starting window of the app is never judged
#
# Android draws the status bar from the app's exiting system splash window
# (``ty=APPLICATION_STARTING``) for a moment after launch; the splash is white, so
# it asks for dark icons while the app already asks for light ones.
# ---------------------------------------------------------------------------

_SPLASH_DUMPS = ("splash_exiting", "splash_starting")


def _splash_dump(name: str) -> str:
    return _read(FIXTURES / SPLASH_FIXTURE, name, "window.txt")


def _raises_starting_window(call: Callable[[], object]) -> None:
    with pytest.raises(SystemBarsError, match="starting window") as caught:
        call()
    assert not isinstance(caught.value, ForeignFocusError)


@pytest.mark.parametrize("name", _SPLASH_DUMPS)
def test_icon_appearance_refuses_a_dump_with_a_starting_window(name: str) -> None:
    dump = _splash_dump(name)
    _raises_starting_window(
        lambda: icon_appearance("android", window_dump=dump, sdk=37, package=FIXTURE_PACKAGE)
    )


@pytest.mark.parametrize("name", _SPLASH_DUMPS)
def test_bars_refuse_a_dump_with_a_starting_window(name: str) -> None:
    dump = _splash_dump(name)
    _raises_starting_window(lambda: bars_shown(dump, package=FIXTURE_PACKAGE))
    _raises_starting_window(lambda: bars_hidden(dump, package=FIXTURE_PACKAGE))


@pytest.mark.parametrize("name", _SPLASH_DUMPS)
def test_parse_appearance_reads_the_activity_window_not_the_splash(name: str) -> None:
    dump = _splash_dump(name)
    assert parse_appearance(dump, "statusBars", 37, package=FIXTURE_PACKAGE) is False


def test_icon_appearance_reads_light_once_the_splash_is_gone() -> None:
    dump = _splash_dump("settled")
    assert icon_appearance("android", window_dump=dump, sdk=37, package=FIXTURE_PACKAGE) == "light"


_ANR_HEADER = "WINDOW MANAGER LAST ANR (dumpsys window lastanr)\n"


def _with_window(dump: str, block: str) -> str:
    return dump.replace(_ANR_HEADER, block + _ANR_HEADER)


def test_a_starting_window_of_another_package_blocks_the_judge() -> None:
    other_splash = (
        "  Window #1 Window{def u0 Splash Screen other.app}:\n"
        "    package=other.app appop=NONE\n"
        "    mAttrs={(0,0)(fillxfill) ty=APPLICATION_STARTING apr=LIGHT_STATUS_BARS}\n"
    )
    dump = _with_window(_window_dump(focus=f"{DEFAULT_PACKAGE}/.MainActivity"), other_splash)
    _raises_starting_window(lambda: icon_appearance("android", window_dump=dump, sdk=36))
    _raises_starting_window(lambda: bars_shown(dump))


def test_a_snapshot_starting_window_owned_by_android_blocks_the_judge() -> None:
    snapshot = (
        "  Window #1 Window{def u0 SnapshotStartingWindow for taskId=21}:\n"
        "    package=android appop=NONE\n"
        "    mAttrs={(0,0)(fillxfill) ty=APPLICATION_STARTING apr=LIGHT_STATUS_BARS}\n"
    )
    dump = _with_window(_window_dump(focus=f"{DEFAULT_PACKAGE}/.MainActivity"), snapshot)
    with pytest.raises(SystemBarsError, match="SnapshotStartingWindow"):
        icon_appearance("android", window_dump=dump, sdk=36)


# ---------------------------------------------------------------------------
# The status-bar appearance region decides what SystemUI draws
# ---------------------------------------------------------------------------


def _with_regions(dump: str, *regions: str) -> str:
    body = "".join(f"      AppearanceRegion{{{region}}}\n" for region in regions)
    return dump.replace(
        "WINDOW MANAGER WINDOWS (dumpsys window windows)\n",
        "WINDOW MANAGER DISPLAY CONTENTS (dumpsys window displays)\n"
        f"    mLastStatusBarAppearanceRegions=\n{body}"
        "    mLastLetterboxDetails=\n"
        "WINDOW MANAGER WINDOWS (dumpsys window windows)\n",
        1,
    )


def test_a_light_status_bars_region_decides_dark_even_when_the_app_window_lacks_it() -> None:
    settled = _splash_dump("settled")
    region_line = "      AppearanceRegion{ bounds=[0,0][1080,2400]}"
    assert region_line in settled
    dump = settled.replace(region_line, "      AppearanceRegion{LIGHT_STATUS_BARS bounds=[0,0][1080,2400]}")
    assert icon_appearance("android", window_dump=dump, sdk=37, package=FIXTURE_PACKAGE) == "dark"


def test_a_region_without_the_flag_decides_light_even_when_the_app_window_has_it() -> None:
    focus = f"{DEFAULT_PACKAGE}/.MainActivity"
    dump = _with_regions(
        _window_dump(focus=focus, apr="LIGHT_STATUS_BARS"), " bounds=[0,0][1080,2400]"
    )
    assert icon_appearance("android", window_dump=dump, sdk=36) == "light"


def test_the_region_under_the_top_centre_of_the_widest_span_decides() -> None:
    focus = f"{DEFAULT_PACKAGE}/.MainActivity"
    dump = _with_regions(
        _window_dump(focus=focus),
        "LIGHT_STATUS_BARS bounds=[0,0][400,100]",
        " bounds=[400,0][1000,100]",
    )
    assert icon_appearance("android", window_dump=dump, sdk=36) == "light"
    dump = _with_regions(
        _window_dump(focus=focus),
        " bounds=[0,0][400,100]",
        "LIGHT_STATUS_BARS bounds=[400,0][1000,100]",
    )
    assert icon_appearance("android", window_dump=dump, sdk=36) == "dark"


def test_the_app_window_bit_decides_when_no_region_contains_the_top_centre() -> None:
    focus = f"{DEFAULT_PACKAGE}/.MainActivity"
    dump = _with_regions(
        _window_dump(focus=focus, apr="LIGHT_STATUS_BARS"),
        " bounds=[0,50][400,100]",
        " bounds=[600,50][1000,100]",
    )
    assert icon_appearance("android", window_dump=dump, sdk=36) == "dark"


def test_regions_are_ignored_below_api_30() -> None:
    focus = f"{DEFAULT_PACKAGE}/.MainActivity"
    dump = _with_regions(
        _window_dump(focus=focus, vsysui="LIGHT_STATUS_BAR"), " bounds=[0,0][1080,2400]"
    )
    assert icon_appearance("android", window_dump=dump, sdk=28) == "dark"


def test_a_region_with_a_negative_bound_still_decides() -> None:
    focus = f"{DEFAULT_PACKAGE}/.MainActivity"
    dump = _with_regions(
        _window_dump(focus=focus), "LIGHT_STATUS_BARS bounds=[-100,0][980,2400]"
    )
    assert icon_appearance("android", window_dump=dump, sdk=36) == "dark"


def test_the_region_path_raises_when_the_dump_has_no_app_window() -> None:
    dump = _window_dump(focus="", package="com.launcher").replace(
        "  mCurrentFocus=Window{abc u0 }\n", ""
    )
    dump = _with_regions(dump, "LIGHT_STATUS_BARS bounds=[0,0][1080,2400]")
    with pytest.raises(SystemBarsError, match="no window of"):
        icon_appearance("android", window_dump=dump, sdk=36)


def test_a_live_activity_window_beats_an_exiting_one_above_it() -> None:
    live = (
        f"  Window #1 Window{{def u0 {DEFAULT_PACKAGE}/.MainActivity}}:\n"
        f"    package={DEFAULT_PACKAGE} appop=NONE\n"
        "    mAttrs={(0,0)(fillxfill) apr=LIGHT_STATUS_BARS vsysui=}\n"
    )
    dump = _window_dump(focus=f"{DEFAULT_PACKAGE}/.MainActivity").replace(
        f"Window{{abc u0 {DEFAULT_PACKAGE}/.MainActivity}}",
        f"Window{{abc u0 {DEFAULT_PACKAGE}/.MainActivity EXITING}}",
    )
    dump = _with_window(dump, live)
    assert parse_appearance(dump, "statusBars", 36) is True
