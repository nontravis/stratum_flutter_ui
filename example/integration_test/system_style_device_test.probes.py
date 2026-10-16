#!/usr/bin/env python3
"""Judges the by-eye checks of `system_style_device_test.dart` with no owner.

Usage: ``python3 -I system_style_device_test.probes.py <probe_dir> <platform>``

`<probe_dir>` holds the captures the device-round script took at each
`PROBE:<name>` marker (device-test probe contract item 2,
tmp/device-round/probe-contract.md:6-9): `<name>.png` on every platform,
plus `<name>.window.txt` and `<name>.recents.txt` on android. Stdlib only
(contract item 3): PNG is decoded with `zlib`, no Pillow.

`<probe_dir>` also holds `device.txt` (contract item 2b), one `key=value`
fact per line (`sdk=` on android, `os=` on ios) -- the only real source for
the android API level (`sdk_level_for` below), since no `dumpsys window`
dump prints one.

Prints one line per check, `PROBE PASS <check>: <detail>` or
`PROBE FAIL <check>: <detail>` (contract item 3), and exits 0 only when
every check for `<platform>` passes.
"""

from __future__ import annotations

import re
import struct
import sys
import zlib
from pathlib import Path

# ---------------------------------------------------------------------------
# PNG decode (stdlib only: zlib for the IDAT stream, struct for chunk headers)
# ---------------------------------------------------------------------------


class Png:
    """A decoded 8-bit, non-interlaced PNG: `get(x, y)` returns `(r, g, b, a)`."""

    def __init__(self, width: int, height: int, channels: int, pixels: bytearray):
        self.width = width
        self.height = height
        self._channels = channels
        self._pixels = pixels

    def get(self, x: int, y: int) -> tuple[int, int, int, int]:
        i = (y * self.width + x) * self._channels
        if self._channels == 1:
            v = self._pixels[i]
            return (v, v, v, 255)
        if self._channels == 3:
            return (self._pixels[i], self._pixels[i + 1], self._pixels[i + 2], 255)
        return (
            self._pixels[i],
            self._pixels[i + 1],
            self._pixels[i + 2],
            self._pixels[i + 3],
        )


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _unfilter(ftype: int, line: bytearray, prev: bytearray, channels: int) -> None:
    n = len(line)
    if ftype == 0:  # None
        return
    if ftype == 1:  # Sub
        for i in range(n):
            a = line[i - channels] if i >= channels else 0
            line[i] = (line[i] + a) & 0xFF
    elif ftype == 2:  # Up
        for i in range(n):
            line[i] = (line[i] + prev[i]) & 0xFF
    elif ftype == 3:  # Average
        for i in range(n):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            line[i] = (line[i] + (a + b) // 2) & 0xFF
    elif ftype == 4:  # Paeth
        for i in range(n):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            line[i] = (line[i] + _paeth(a, b, c)) & 0xFF
    else:
        raise ValueError(f"unsupported PNG filter type {ftype}")


def read_png(path: Path) -> Png:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG (bad signature)")
    pos = 8
    width = height = bit_depth = color_type = interlace = None
    idat = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        ctype = data[pos + 4 : pos + 8]
        cdata = data[pos + 8 : pos + 8 + length]
        pos += 12 + length  # length + type + data + crc
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filt, interlace = (
                struct.unpack(">IIBBBBB", cdata)
            )
        elif ctype == b"IDAT":
            idat += cdata
        elif ctype == b"IEND":
            break
    if width is None:
        raise ValueError(f"{path}: missing IHDR chunk")
    if bit_depth != 8:
        raise ValueError(f"{path}: unsupported bit depth {bit_depth} (need 8)")
    if interlace:
        raise ValueError(f"{path}: interlaced PNG unsupported")
    channels = {0: 1, 2: 3, 6: 4}.get(color_type)
    if channels is None:
        raise ValueError(f"{path}: unsupported color type {color_type}")
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    pixels = bytearray(width * height * channels)
    prev = bytearray(stride)
    rpos = 0
    for y in range(height):
        ftype = raw[rpos]
        rpos += 1
        line = bytearray(raw[rpos : rpos + stride])
        rpos += stride
        _unfilter(ftype, line, prev, channels)
        pixels[y * stride : (y + 1) * stride] = line
        prev = line
    return Png(width, height, channels, pixels)


# ---------------------------------------------------------------------------
# Status/navigation bar strip sampling (contract item 3: "samples the
# status-bar strip color from the PNG")
# ---------------------------------------------------------------------------

# A status bar is a thin band across the top of the screen; this height
# fraction is an approximation (no device metrics are captured), kept
# generous so a real device's status bar height falls inside the sample.
_STRIP_HEIGHT_FRACTION = 0.035
_MIN_STRIP_PX = 6

# The clock (left) and system icons (right) live in the strip's side
# margins, not its center -- a notched/island/punch-hole device's center-top
# cutout sits where a naive center-band sample would land (critical finding,
# tmp/device-round/review-probe.findings.md:5-16). Icon luma is therefore
# searched ONLY in these two margins, scoped from the image width.
_ICON_ZONE_FRACTION = 0.20

# The center-top cutout to exclude from BOTH the fill sample and the icon
# zones, scoled from the image width per platform: the iPhone 17
# (`.claude/device-test.toml:23`) Dynamic Island is roughly 30-35% of
# screen width (review-probe.findings.md:10-13); an android punch-hole
# camera (pixel_8) is much narrower, but devices with no cutout at all
# (pixel_2) still tolerate losing this sliver of the fill sample.
_CUTOUT_FRACTION = {
    "ios": 0.34,
    "android": 0.12,
}


def _luma(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def sample_status_bar(
    png: Png, platform: str
) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    """Returns `(fill_color, icon_color)` sampled from the top strip.

    `fill_color` is the strip's most common color OUTSIDE the icon margins
    and the center cutout (US-14 FR-02:9 -- the fill under the bar, or the
    bar color FR-01 paints over it as the topmost layer). `icon_color` is
    the highest-luma-delta-from-`fill_color` pixel searched ONLY inside the
    left/right icon margins (FR-02:49 defines the icon as the higher-
    contrast element against what lies beneath it), so a center cutout can
    never masquerade as the fill or get picked as the icon.
    """
    strip_h = max(_MIN_STRIP_PX, round(png.height * _STRIP_HEIGHT_FRACTION))
    strip_h = min(strip_h, png.height)
    y0 = 1 if strip_h > 2 else 0
    y1 = max(y0 + 1, strip_h - 1)

    icon_zone_w = max(1, min(round(png.width * _ICON_ZONE_FRACTION), png.width // 2))
    cutout_frac = _CUTOUT_FRACTION.get(platform, _CUTOUT_FRACTION["android"])
    cutout_half = round(png.width * cutout_frac / 2)
    cx = png.width // 2
    cutout_x0, cutout_x1 = max(0, cx - cutout_half), min(png.width, cx + cutout_half)

    def in_cutout(x: int) -> bool:
        return cutout_x0 <= x < cutout_x1

    def in_icon_zone(x: int) -> bool:
        return x < icon_zone_w or x >= png.width - icon_zone_w

    def fill_counts(skip_icon_zones: bool) -> dict[tuple[int, int, int], int]:
        counts: dict[tuple[int, int, int], int] = {}
        for y in range(y0, y1):
            for x in range(png.width):
                if in_cutout(x) or (skip_icon_zones and in_icon_zone(x)):
                    continue
                rgb = png.get(x, y)[:3]
                counts[rgb] = counts.get(rgb, 0) + 1
        return counts

    counts = fill_counts(skip_icon_zones=True)
    if not counts:
        # A narrow image can leave nothing between the icon zones and the
        # cutout; fall back to everything outside the cutout alone.
        counts = fill_counts(skip_icon_zones=False)
    fill = max(counts, key=lambda c: counts[c])
    fill_luma = _luma(fill)

    icon = fill
    best_delta = -1.0
    for y in range(y0, y1):
        for x in range(png.width):
            if in_cutout(x) or not in_icon_zone(x):
                continue
            rgb = png.get(x, y)[:3]
            delta = abs(_luma(rgb) - fill_luma)
            if delta > best_delta:
                best_delta = delta
                icon = rgb
    return fill, icon


def brightness_of(rgb: tuple[int, int, int]) -> str:
    """`'light'` or `'dark'`, split at the mid luma (sRGB 0-255 scale)."""
    return "light" if _luma(rgb) >= 127.5 else "dark"


# ---------------------------------------------------------------------------
# Android window.txt / recents.txt parsing
#
# `dumpsys window` carries two generations of this state, and a real capture
# on this round's two android targets (`.claude/device-test.toml:8-19`) can
# land in either: pixel_8 is API 36 (modern, `WindowInsetsController`-era);
# pixel_2 is API 28 (legacy, pre-`WindowInsetsController`). Every parser
# below tries modern first, then the legacy shape, citing the AOSP dump()
# method it matches.
# ---------------------------------------------------------------------------

# android/app/build.gradle.kts:20 -- scopes a legacy per-window field (one
# that AOSP dumps once per window, unlike the single display-wide modern
# fields below) to this app's own window, never a system bar/IME/keyguard
# window (important finding, review-probe.findings.md:29-36).
_PACKAGE = "dev.stratum.stratum_ui_example"


def _app_window_block(window_txt: str) -> str | None:
    """Isolates the text of this app's own `Window #N ...:` block.

    `WindowManagerService.dump()` (frameworks/base/services/core/java/com/
    android/server/wm/WindowManagerService.java) prints one such block per
    window via `WindowState.dump()`, which prints that window's own
    `package=` field (frameworks/base/services/core/java/com/android/
    server/wm/WindowState.java, android-9.0.0_r22 tag); splitting on the
    `Window #N` headers and keeping the block naming `_PACKAGE` is what
    scopes a legacy per-window field to the app under test.
    """
    blocks = re.split(r"(?=^ *Window #\d+)", window_txt, flags=re.MULTILINE)
    for block in blocks:
        if re.search(rf"package\s*=\s*{re.escape(_PACKAGE)}\b", block):
            return block
    return None


def parse_bar_visible(window_txt: str, bar: str) -> bool | None:
    """Whether `bar` (`'statusBars'` or `'navigationBars'`) is visible.

    Modern (API 30+, covers the pixel_8/API 36 target): `InsetsSource.dump`
    (frameworks/base/core/java/android/view/InsetsSource.java) prints
    `type=<name> ... visible=<bool>`, `<name>` from `WindowInsets.Type.
    toString` (frameworks/base/core/java/android/view/WindowInsets.java) --
    literally `statusBars`/`navigationBars`. This is the display's single
    resolved `InsetsState`, so no per-window scoping applies.
    """
    m = re.search(rf"type\s*=\s*{bar}\b[^\n]*?visible\s*=\s*(true|false)", window_txt)
    if m is not None:
        return m.group(1) == "true"

    # Legacy (pre-30, covers the pixel_2/API 28 target, where
    # `WindowInsetsController` does not exist yet): `WindowState.dump`
    # (android-9.0.0_r22 tag) prints `mSystemUiVisibility=0x<hex>`; a set
    # bit HIDES the bar (android.view.View: `SYSTEM_UI_FLAG_FULLSCREEN` =
    # 0x4 hides statusBars, `SYSTEM_UI_FLAG_HIDE_NAVIGATION` = 0x2 hides
    # navigationBars). Scoped to the app's own window since every window
    # carries its own copy of this field.
    block = _app_window_block(window_txt)
    if block is None:
        return None
    m = re.search(r"mSystemUiVisibility\s*=\s*0x([0-9a-fA-F]+)", block)
    if m is None:
        return None
    flags = int(m.group(1), 16)
    hide_bit = _SYSTEM_UI_FLAG_FULLSCREEN if bar == "statusBars" else _SYSTEM_UI_FLAG_HIDE_NAVIGATION
    return (flags & hide_bit) == 0


_SYSTEM_UI_FLAG_HIDE_NAVIGATION = 0x00000002  # android.view.View
_SYSTEM_UI_FLAG_FULLSCREEN = 0x00000004  # android.view.View
_SYSTEM_UI_FLAG_LIGHT_STATUS_BAR = 0x00002000  # android.view.View, API 23+
_SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR = 0x00000010  # android.view.View, API 26+

_LIGHT_STATUS_BARS_NAME = "LIGHT_STATUS_BARS"
_LIGHT_NAVIGATION_BARS_NAME = "LIGHT_NAVIGATION_BARS"


def parse_appearance(window_txt: str, bar: str) -> bool:
    """Whether the platform paints DARK content for `bar` ('statusBars' or
    'navigationBars') because that bar's LIGHT_* appearance bit is set.

    Modern (API 30+): `DisplayPolicy.dump` (frameworks/base/services/core/
    java/com/android/server/wm/DisplayPolicy.java) prints `mLastAppearance=`
    only when non-zero, naming each set bit via `InsetsFlags`'s ViewDebug
    flag mapping (frameworks/base/core/java/android/view/InsetsFlags.java):
    `LIGHT_STATUS_BARS` / `LIGHT_NAVIGATION_BARS`. This is one line for the
    whole display (not per window), so -- unlike the legacy fallback below
    -- no other window's state can stand in for it (important finding,
    review-probe.findings.md:29-36). No line means appearance == 0: neither
    bar requests dark content.
    """
    m = re.search(r"mLastAppearance=([^\n]*)", window_txt)
    if m is not None:
        name = _LIGHT_STATUS_BARS_NAME if bar == "statusBars" else _LIGHT_NAVIGATION_BARS_NAME
        return name in m.group(1)

    # Legacy (pre-30): the equivalent request is this app's own
    # `SYSTEM_UI_FLAG_LIGHT_STATUS_BAR` (0x2000) / `SYSTEM_UI_FLAG_
    # LIGHT_NAVIGATION_BAR` (0x10) bit inside its `mSystemUiVisibility`
    # (the same per-window field `parse_bar_visible` reads), so it needs
    # the same app-window scoping.
    block = _app_window_block(window_txt)
    if block is None:
        return False
    m = re.search(r"mSystemUiVisibility\s*=\s*0x([0-9a-fA-F]+)", block)
    if m is None:
        return False
    flags = int(m.group(1), 16)
    bit = _SYSTEM_UI_FLAG_LIGHT_STATUS_BAR if bar == "statusBars" else _SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
    return (flags & bit) != 0


def parse_recents_label(recents_txt: str) -> str | None:
    """The app-switcher label AOSP actually dumps for the top recent task.

    `ActivityRecord.dump` prints `taskDescription: label="<text>"` whenever
    a task carries a `TaskDescription` (API 28: frameworks/base/services/
    core/java/com/android/server/am/ActivityRecord.java; API 29+: the same
    method moved to .../wm/ActivityRecord.java, same literal shape). A null
    label still dumps the literal text `"null"`, always quoted.
    """
    m = re.search(r'taskDescription:\s*label\s*=\s*"([^"]*)"', recents_txt)
    if m is None:
        return None
    return m.group(1)


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

# Android API level at and above which an app targeting API 36 has its
# immersive bar modes ignored by the platform (US-14 FR-03 E05,
# docs/prds/.../fr03_apply_bar_mode_and_rotation_lock.md:41; the test file's
# own head comment, example/integration_test/system_style_device_test.dart:
# 16-19, names this the pixel_8 / Android 16 exception -- design R8).
_BARS_STAY_VISIBLE_SDK = 36

# No `dumpsys window` dump prints an API level (confirmed against
# `InsetsSource.java`, `WindowState.java`, `ActivityRecord.java`: none of
# their dump() methods print `mTargetSdk`/`targetSdk`/`sdkInt` -- important
# finding, review-probe.findings.md:18-27). The device-round watcher instead
# writes `<probe dir>/device.txt` once per run (probe-contract.md item 2b):
# one `key=value` fact per line, `sdk=<ro.build.version.sdk>` on android,
# `os=<simctl runtime version>` on ios -- the real source for both.


def _read_device_facts(probe_dir: Path) -> dict[str, str] | None:
    """Parses `<probe dir>/device.txt` (probe-contract.md item 2b) into a
    `key=value` dict, or `None` when the file is missing."""
    path = probe_dir / "device.txt"
    if not path.exists():
        return None
    facts: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        key, _, value = line.partition("=")
        facts[key.strip()] = value.strip()
    return facts


def sdk_level_for(probe_dir: Path) -> int | None:
    facts = _read_device_facts(probe_dir)
    if facts is None:
        return None
    sdk = facts.get("sdk")
    if sdk is None or not sdk.isdigit():
        return None
    return int(sdk)


def _require(probe_dir: Path, name: str, suffix: str) -> str:
    path = probe_dir / f"{name}.{suffix}"
    if not path.exists():
        raise FileNotFoundError(str(path))
    return path.read_text()


def _check_icon(
    probe_dir: Path, name: str, platform: str, expected: str, cite: str
) -> tuple[bool, str]:
    """Icon brightness against the fill under the status bar.

    `expected` is `'light'` or `'dark'`; `cite` names the PRD line that
    sets it. On android, `window.txt`'s appearance state is authoritative
    (it is always resolvable, never ambiguous -- `parse_appearance`); the
    PNG is the only signal on ios, which has no such capture.
    """
    if platform == "android":
        window_txt = _require(probe_dir, name, "window.txt")
        light = parse_appearance(window_txt, "statusBars")
        actual = "dark" if light else "light"
        detail = f"LIGHT_STATUS_BARS {'set' if light else 'unset'} -> {actual} icons ({cite})"
    else:
        png = read_png(probe_dir / f"{name}.png")
        _fill, icon = sample_status_bar(png, platform)
        actual = brightness_of(icon)
        detail = f"png icon sample {actual} ({cite})"
    return actual == expected, f"expected {expected}, got {actual}: {detail}"


def _check_bar_color(
    probe_dir: Path, name: str, platform: str, expected: str, cite: str
) -> tuple[bool, str]:
    png = read_png(probe_dir / f"{name}.png")
    fill, _icon = sample_status_bar(png, platform)
    actual = brightness_of(fill)
    return (
        actual == expected,
        f"expected {expected} fill, got {actual} fill {fill} ({cite})",
    )


def _check_bars_hidden(
    probe_dir: Path, name: str, platform: str, cite: str
) -> tuple[bool, str]:
    if platform != "android":
        raise ValueError("bar-visibility checks need window.txt (android only)")
    window_txt = _require(probe_dir, name, "window.txt")
    status_visible = parse_bar_visible(window_txt, "statusBars")
    nav_visible = parse_bar_visible(window_txt, "navigationBars")
    if status_visible is None or nav_visible is None:
        return False, (
            f"could not parse statusBars/navigationBars visibility in "
            f"{name}.window.txt (tried InsetsSource type=/visible= and legacy "
            f"mSystemUiVisibility=) ({cite})"
        )
    sdk = sdk_level_for(probe_dir)
    if sdk is None:
        return False, f"device.txt missing ({cite})"
    stays_visible = sdk >= _BARS_STAY_VISIBLE_SDK
    expected_visible = stays_visible
    actual_visible = status_visible or nav_visible
    ok = actual_visible == expected_visible
    detail = (
        f"sdk={sdk} expected visible={expected_visible} (stay-visible exception "
        f"{'applies' if stays_visible else 'does not apply'}), "
        f"got statusBars={status_visible} navigationBars={nav_visible} ({cite})"
    )
    return ok, detail


def _check_bars_shown(probe_dir: Path, name: str, platform: str, cite: str) -> tuple[bool, str]:
    if platform != "android":
        raise ValueError("bar-visibility checks need window.txt (android only)")
    window_txt = _require(probe_dir, name, "window.txt")
    status_visible = parse_bar_visible(window_txt, "statusBars")
    nav_visible = parse_bar_visible(window_txt, "navigationBars")
    if status_visible is None or nav_visible is None:
        return False, (
            f"could not parse statusBars/navigationBars visibility in "
            f"{name}.window.txt (tried InsetsSource type=/visible= and legacy "
            f"mSystemUiVisibility=) ({cite})"
        )
    ok = bool(status_visible) and bool(nav_visible)
    return ok, f"expected both visible, got statusBars={status_visible} navigationBars={nav_visible} ({cite})"


def _check_recents_label(
    probe_dir: Path, name: str, platform: str, expected: str, cite: str
) -> tuple[bool, str]:
    if platform != "android":
        raise ValueError("the recents-label check needs recents.txt (android only)")
    recents_txt = _require(probe_dir, name, "recents.txt")
    label = parse_recents_label(recents_txt)
    if label is None:
        return False, f"could not parse taskDescription label in {name}.recents.txt ({cite})"
    ok = label == expected
    return ok, f"expected label={expected!r}, got {label!r} ({cite})"


# Each check: (name, platforms it runs on, the function that runs it).
_CHECKS: list[tuple[str, tuple[str, ...], object]] = [
    (
        "dark_header",
        ("android", "ios"),
        lambda d, p: _check_icon(
            d,
            "dark_header",
            p,
            "light",
            "USER_STORY.md:32-35 Scenario 3; fr02_pick_bar_icons_against_the_fill.md:9,40",
        ),
    ),
    (
        "white_page",
        ("android", "ios"),
        lambda d, p: _check_icon(
            d,
            "white_page",
            p,
            "dark",
            "USER_STORY.md:42-45 Scenario 5; fr02_pick_bar_icons_against_the_fill.md:9,42",
        ),
    ),
    (
        "dark_statusbar",
        ("android", "ios"),
        lambda d, p: _check_icon(
            d,
            "dark_statusbar",
            p,
            "light",
            "USER_STORY.md:97-100 Scenario 16; fr02_pick_bar_icons_against_the_fill.md:46",
        ),
    ),
    (
        "dark_statusbar_fill",
        ("android", "ios"),
        lambda d, p: _check_bar_color(
            d,
            "dark_statusbar",
            p,
            "dark",
            "USER_STORY.md:97-100 Scenario 16; fr01_merge_the_system_bar_style.md (statusBarColor painted as the topmost fill)",
        ),
    ),
    (
        "video_bars_hidden",
        ("android",),
        lambda d, p: _check_bars_hidden(
            d,
            "video_bars_hidden",
            p,
            "USER_STORY.md:52-55 Scenario 7; fr03_apply_bar_mode_and_rotation_lock.md:41 E05",
        ),
    ),
    (
        "video_bars_shown",
        ("android",),
        lambda d, p: _check_bars_shown(
            d,
            "video_bars_shown",
            p,
            "USER_STORY.md:57-60 Scenario 8; fr03_apply_bar_mode_and_rotation_lock.md:38 E02",
        ),
    ),
    (
        "video_back",
        ("android",),
        lambda d, p: _check_bars_hidden(
            d,
            "video_back",
            p,
            "USER_STORY.md:62-65 Scenario 9; fr03_apply_bar_mode_and_rotation_lock.md:39 E03,41 E05",
        ),
    ),
    (
        "recents_label",
        ("android",),
        lambda d, p: _check_recents_label(
            d,
            "recents_label",
            p,
            "Video",
            "fr04_show_the_page_label_in_the_app_switcher.md:9,22",
        ),
    ),
]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {argv[0]} <probe_dir> <platform>", file=sys.stderr)
        return 2
    probe_dir = Path(argv[1])
    platform = argv[2]
    if platform not in ("android", "ios"):
        print(f"unsupported platform {platform!r} (want android or ios)", file=sys.stderr)
        return 2
    if not probe_dir.is_dir():
        print(f"no such probe directory: {probe_dir}", file=sys.stderr)
        return 2

    all_passed = True
    ran_any = False
    for check_name, platforms, run in _CHECKS:
        if platform not in platforms:
            continue
        ran_any = True
        try:
            ok, detail = run(probe_dir, platform)
        except FileNotFoundError as exc:
            ok, detail = False, f"missing capture: {exc}"
        except ValueError as exc:
            ok, detail = False, str(exc)
        word = "PASS" if ok else "FAIL"
        print(f"PROBE {word} {check_name}: {detail}")
        all_passed = all_passed and ok

    if not ran_any:
        print(f"no checks run for platform {platform!r}", file=sys.stderr)
        return 2
    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
