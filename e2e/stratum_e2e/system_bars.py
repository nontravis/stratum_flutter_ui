"""System-bar checks for the e2e suite: screenshot sampling and Android dump parsing.

Port of the parsers in ``example/integration_test/system_style_device_test.probes.py``
(``74dc421``); ``unit/fixtures/system_bars/verdicts.txt`` pins the port to that probe's
verdicts. Stdlib only: a screenshot is decoded with ``zlib``, no Pillow.
"""

from __future__ import annotations

import re
import struct
import zlib
from typing import Final, Literal

Brightness = Literal["light", "dark"]
Bar = Literal["statusBars", "navigationBars"]
Rgb = tuple[int, int, int]

# The app under test; fixtures captured from the example app pass their own package.
DEFAULT_PACKAGE: Final = "dev.stratum.stratum_ui_test_app"


class SystemBarsError(Exception):
    """A capture cannot answer the question asked of it."""


class ForeignFocusError(SystemBarsError):
    """A window other than the app owns focus, so the dump describes that window."""


class StartingWindowError(SystemBarsError):
    """A starting window is up, so SystemUI may draw the bars from the splash."""


# ---------------------------------------------------------------------------
# PNG decode
# ---------------------------------------------------------------------------

_PNG_SIGNATURE: Final = b"\x89PNG\r\n\x1a\n"
_CHANNELS_BY_COLOR_TYPE: Final = {0: 1, 2: 3, 6: 4}


class Png:
    """A decoded 8-bit, non-interlaced PNG."""

    def __init__(self, width: int, height: int, channels: int, pixels: bytearray) -> None:
        self.width = width
        self.height = height
        self._channels = channels
        self._pixels = pixels

    def get(self, x: int, y: int) -> tuple[int, int, int, int]:
        """Returns ``(r, g, b, a)`` at ``(x, y)``; gray expands to RGB, RGB is opaque."""
        i = (y * self.width + x) * self._channels
        if self._channels == 1:
            v = self._pixels[i]
            return (v, v, v, 255)
        if self._channels == 3:
            return (self._pixels[i], self._pixels[i + 1], self._pixels[i + 2], 255)
        return (self._pixels[i], self._pixels[i + 1], self._pixels[i + 2], self._pixels[i + 3])


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
    if ftype == 0:
        return
    if ftype == 1:
        for i in range(n):
            a = line[i - channels] if i >= channels else 0
            line[i] = (line[i] + a) & 0xFF
    elif ftype == 2:
        for i in range(n):
            line[i] = (line[i] + prev[i]) & 0xFF
    elif ftype == 3:
        for i in range(n):
            a = line[i - channels] if i >= channels else 0
            line[i] = (line[i] + (a + prev[i]) // 2) & 0xFF
    elif ftype == 4:
        for i in range(n):
            a = line[i - channels] if i >= channels else 0
            c = prev[i - channels] if i >= channels else 0
            line[i] = (line[i] + _paeth(a, prev[i], c)) & 0xFF
    else:
        raise ValueError(f"unsupported PNG filter type {ftype}")


def read_png(data: bytes) -> Png:
    """Decodes an 8-bit gray, RGB, or RGBA non-interlaced PNG.

    Raises:
        ValueError: On a bad signature, a missing header, or an unsupported layout.
    """
    if data[:8] != _PNG_SIGNATURE:
        raise ValueError("not a PNG (bad signature)")
    pos = 8
    header: tuple[int, int, int, int, int] | None = None
    idat = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length  # length + type + data + crc
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filt, interlace = struct.unpack(
                ">IIBBBBB", body
            )
            header = (width, height, bit_depth, color_type, interlace)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
    if header is None:
        raise ValueError("missing IHDR chunk")
    width, height, bit_depth, color_type, interlace = header
    if bit_depth != 8:
        raise ValueError(f"unsupported bit depth {bit_depth} (need 8)")
    if interlace:
        raise ValueError("interlaced PNG unsupported")
    channels = _CHANNELS_BY_COLOR_TYPE.get(color_type)
    if channels is None:
        raise ValueError(f"unsupported color type {color_type}")
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
# Status-bar strip sampling
# ---------------------------------------------------------------------------

# No device metrics are captured, so the strip height is an approximation kept
# generous enough to cover a real status bar.
_STRIP_HEIGHT_FRACTION: Final = 0.035
_MIN_STRIP_PX: Final = 6

# The clock and system icons sit in the side margins; a center-top cutout sits
# where a naive center-band sample would land.
_ICON_ZONE_FRACTION: Final = 0.20

# Center-top cutout excluded from the fill and icon samples: the Dynamic Island
# is about 30-35% of the width, an Android punch hole is far narrower.
_CUTOUT_FRACTION: Final = {"ios": 0.34, "android": 0.12}

# Flutter's debug banner sits in the right icon zone and would be picked as the
# icon. The exclusion is an absolute width, gated to device-sized screenshots,
# because the 150px synthetic fixtures put their own icon marker 10px from the edge.
_DEBUG_BANNER_MIN_IMAGE_WIDTH_PX: Final = 500
_DEBUG_BANNER_WIDTH_PX: Final = 130

_MID_LUMA: Final = 127.5


def _luma(rgb: Rgb) -> float:
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def sample_status_bar(png: Png, platform: str) -> tuple[Rgb, Rgb | None]:
    """Returns ``(fill_color, icon_color)`` sampled from the status-bar strip.

    The fill is the strip's most common color outside the icon margins and the
    cutout; the icon is the margin pixel whose luma differs most from the fill, or
    ``None`` when no margin pixel differs at all (the icon is invisible on this page).
    """
    strip_h = min(max(_MIN_STRIP_PX, round(png.height * _STRIP_HEIGHT_FRACTION)), png.height)
    y0 = 1 if strip_h > 2 else 0
    y1 = max(y0 + 1, strip_h - 1)

    icon_zone_w = max(1, min(round(png.width * _ICON_ZONE_FRACTION), png.width // 2))
    cutout_frac = _CUTOUT_FRACTION.get(platform, _CUTOUT_FRACTION["android"])
    cutout_half = round(png.width * cutout_frac / 2)
    cx = png.width // 2
    cutout_x0, cutout_x1 = max(0, cx - cutout_half), min(png.width, cx + cutout_half)
    banner_w = _DEBUG_BANNER_WIDTH_PX if png.width >= _DEBUG_BANNER_MIN_IMAGE_WIDTH_PX else 0

    def in_cutout(x: int) -> bool:
        return cutout_x0 <= x < cutout_x1

    def in_icon_zone(x: int) -> bool:
        return x < icon_zone_w or x >= png.width - icon_zone_w

    def in_banner(x: int) -> bool:
        return x >= png.width - banner_w

    def fill_counts(skip_icon_zones: bool) -> dict[Rgb, int]:
        counts: dict[Rgb, int] = {}
        for y in range(y0, y1):
            for x in range(png.width):
                if in_cutout(x) or (skip_icon_zones and in_icon_zone(x)):
                    continue
                r, g, b, _a = png.get(x, y)
                counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
        return counts

    counts = fill_counts(skip_icon_zones=True)
    if not counts:
        # A narrow image leaves nothing between the icon zones and the cutout.
        counts = fill_counts(skip_icon_zones=False)
    fill = max(counts, key=lambda c: counts[c])
    fill_luma = _luma(fill)

    icon: Rgb | None = None
    best_delta = 0.0
    for y in range(y0, y1):
        for x in range(png.width):
            if in_cutout(x) or not in_icon_zone(x) or in_banner(x):
                continue
            r, g, b, _a = png.get(x, y)
            delta = abs(_luma((r, g, b)) - fill_luma)
            if delta > best_delta:
                best_delta = delta
                icon = (r, g, b)
    return fill, icon


def brightness_of(rgb: Rgb) -> Brightness:
    """Returns ``"light"`` or ``"dark"``, split at the mid luma of the 0-255 scale."""
    return "light" if _luma(rgb) >= _MID_LUMA else "dark"


# ---------------------------------------------------------------------------
# Android dump parsing
#
# `dumpsys window` carries two generations of this state: API 30+ prints
# InsetsSource and `apr=`; older builds print neither, so each parser tries the
# modern shape first, then the legacy `vsysui=` flags.
# ---------------------------------------------------------------------------

_VSYSUI_HIDE_NAVIGATION: Final = "HIDE_NAVIGATION"
_VSYSUI_FULLSCREEN: Final = "FULLSCREEN"
_VSYSUI_LIGHT_STATUS_BAR: Final = "LIGHT_STATUS_BAR"
_VSYSUI_LIGHT_NAVIGATION_BAR: Final = "LIGHT_NAVIGATION_BAR"
_LIGHT_STATUS_BARS: Final = "LIGHT_STATUS_BARS"
_LIGHT_NAVIGATION_BARS: Final = "LIGHT_NAVIGATION_BARS"
_APPEARANCE_API: Final = 30

# Android shows this nudge while an immersive request holds; it takes focus
# without taking the app's bar control away.
_IMMERSIVE_MODE_CONFIRMATION: Final = "ImmersiveModeConfirmation"

# The window type of the system splash or task snapshot Android draws while an app launches.
_STARTING_WINDOW_TYPE: Final = "APPLICATION_STARTING"


def _live_windows_section(window_dump: str) -> str:
    """Slices the dump to its ``WINDOW MANAGER WINDOWS`` section.

    Only that section holds live per-window fields. The ``LAST ANR`` section after
    an app ANR repeats the app's ``package=`` frozen at the ANR instant, and must
    never be read. A dump with no such header is returned unchanged.
    """
    m = re.search(r"^WINDOW MANAGER WINDOWS\b.*$", window_dump, re.MULTILINE)
    if m is None:
        return window_dump
    start = m.end()
    m2 = re.search(r"^WINDOW MANAGER \S", window_dump[start:], re.MULTILINE)
    end = start + m2.start() if m2 else len(window_dump)
    return window_dump[start:end]


def _live_window_blocks(window_dump: str) -> list[str]:
    return re.split(r"(?=^ *Window #\d+)", _live_windows_section(window_dump), flags=re.MULTILINE)


def _window_title(block: str) -> str | None:
    """Returns the title in a block's ``Window{<hash> u<user> <title>}`` header."""
    m = re.match(r" *Window #\d+ Window\{\S+ u\d+ (.*)\}:", block)
    return m.group(1) if m else None


def _app_window_block(window_dump: str, package: str) -> str | None:
    """Returns the app's activity ``Window #N`` block, or ``None``.

    The match is on the header title ``<package>/<activity>``: the app's starting
    window also carries ``package=<package>`` but is titled ``Splash Screen <package>``.
    A block that is not ``EXITING`` wins over one that is; else the first match.
    """
    matches = [
        block
        for block in _live_window_blocks(window_dump)
        if (title := _window_title(block)) is not None and title.startswith(package + "/")
    ]
    live = [block for block in matches if not (_window_title(block) or "").endswith(" EXITING")]
    return (live or matches or [None])[0]


def _starting_window_title(window_dump: str) -> str | None:
    """Returns the title of any live starting window, whatever its package, or ``None``.

    Any application window over the status bar, starting windows included, can drive
    the status-bar appearance region, and a task snapshot window owns ``package=android``.
    """
    for block in _live_window_blocks(window_dump):
        if re.search(rf"\bty={_STARTING_WINDOW_TYPE}\b", block):
            return _window_title(block) or _STARTING_WINDOW_TYPE
    return None


def _focused_window_name(window_dump: str) -> str | None:
    m = re.search(r"mCurrentFocus=Window\{\S+ u\d+ (.*)\}\s*$", window_dump, re.MULTILINE)
    if m is None:
        m = re.search(r"mFocusedWindow=Window\{\S+ u\d+ (.*)\}\s*$", window_dump, re.MULTILINE)
    return m.group(1) if m else None


def _focus_violation(window_dump: str, package: str) -> str | None:
    """Returns the foreign focused window's name, or ``None`` when focus is fine.

    Focus is fine on the app's own ``<package>/<activity>`` window, on the immersive
    confirmation, or when the dump has no focus line. The app match is a prefix,
    never a substring: an ANR dialog titled ``Application Not Responding: <package>``
    contains the package too.
    """
    name = _focused_window_name(window_dump)
    if name is None or name.startswith(package + "/") or name == _IMMERSIVE_MODE_CONFIRMATION:
        return None
    return name


def _require_judgeable_window(window_dump: str, package: str) -> None:
    """Raises unless the dump describes the app's own window and no starting window.

    Raises:
        ForeignFocusError: Another window owns focus.
        StartingWindowError: A starting window is up.
    """
    violation = _focus_violation(window_dump, package)
    if violation is not None:
        raise ForeignFocusError(f"focus not app: {violation}")
    starting = _starting_window_title(window_dump)
    if starting is not None:
        raise StartingWindowError(f"starting window up: {starting}")


def parse_bar_visible(window_dump: str, bar: Bar, *, package: str = DEFAULT_PACKAGE) -> bool | None:
    """Returns whether ``bar`` is visible, or ``None`` when the dump cannot say.

    The legacy path reads the app window's ``vsysui`` flags, which a device below
    API 29 may never clear after an immersive page; that reads "hidden" and is a real
    failure, not a parser defect.
    """
    m = re.search(rf"type\s*=\s*{bar}\b[^\n]*?visible\s*=\s*(true|false)", window_dump)
    if m is not None:
        return m.group(1) == "true"
    block = _app_window_block(window_dump, package)
    if block is None:
        return None
    flags = re.search(r"vsysui=([^}\n]*)", block)
    if flags is None:
        return None
    hide_name = _VSYSUI_FULLSCREEN if bar == "statusBars" else _VSYSUI_HIDE_NAVIGATION
    return not re.search(rf"\b{hide_name}\b", flags.group(1))


def parse_appearance(
    window_dump: str, bar: Bar, sdk: int, *, package: str = DEFAULT_PACKAGE
) -> bool:
    """Returns whether the app's activity window asks for DARK content on ``bar``.

    Reads that window's ``apr=`` on API 30+ and ``vsysui=`` below; never the
    display-wide ``mLastAppearance``, which a foreign window can own, nor the
    app's starting window. ``False`` when the window or its flags line is absent.
    """
    block = _app_window_block(window_dump, package)
    if block is None:
        return False
    if sdk >= _APPEARANCE_API:
        flags = re.search(r"apr=([^}\n]*)", block)
        name = _LIGHT_STATUS_BARS if bar == "statusBars" else _LIGHT_NAVIGATION_BARS
    else:
        flags = re.search(r"vsysui=([^}\n]*)", block)
        name = _VSYSUI_LIGHT_STATUS_BAR if bar == "statusBars" else _VSYSUI_LIGHT_NAVIGATION_BAR
    if flags is None:
        return False
    return bool(re.search(rf"\b{name}\b", flags.group(1)))


_APPEARANCE_REGIONS: Final = re.compile(
    r"mLastStatusBarAppearanceRegions=[ \t]*\n((?:[ \t]*AppearanceRegion\{[^\n]*\n)*)"
)
_APPEARANCE_REGION: Final = re.compile(
    r"AppearanceRegion\{([^}]*?)\s*bounds=\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]\}"
)


def _status_region_wants_dark_icons(window_dump: str) -> bool | None:
    """Returns whether SystemUI draws dark status icons, or ``None`` without a verdict.

    SystemUI colors the status bar from ``mLastStatusBarAppearanceRegions``. The region
    under the top-centre point of the regions' span decides; ``None`` when the dump
    lists no region, or none covers that point.
    """
    listing = _APPEARANCE_REGIONS.search(window_dump)
    if listing is None:
        return None
    regions = [
        (flags, int(left), int(top), int(right), int(bottom))
        for flags, left, top, right, bottom in _APPEARANCE_REGION.findall(listing.group(1))
    ]
    if not regions:
        return None
    centre_x = (min(r[1] for r in regions) + max(r[3] for r in regions)) // 2
    top_y = min(r[2] for r in regions)
    for flags, left, top, right, bottom in regions:
        if left <= centre_x < right and top <= top_y < bottom:
            return bool(re.search(rf"\b{_LIGHT_STATUS_BARS}\b", flags))
    return None


def _app_activity_block(activities_dump: str, package: str) -> str | None:
    """Returns the app's own ``Hist #N: ActivityRecord`` block, or ``None``.

    Only ``dumpsys activity activities`` reaches ``ActivityRecord.dump``, the one
    place a task label prints; the ``recents`` dump never does. API 28 heads a block
    ``Hist #N:`` and API 34+ ``Hist  #N:``, so the split accepts any spacing.
    """
    blocks = re.split(
        r"(?=^[ \t]*\*?[ \t]*(?:Hist[ \t]*#\d+:|Task id #\d+|\*[ \t]*Task(?:Record)?\{))",
        activities_dump,
        flags=re.MULTILINE,
    )
    header = re.compile(
        rf"^[ \t]*\*?[ \t]*Hist[ \t]*#\d+:\s*ActivityRecord\{{[^\n]*\b{re.escape(package)}/"
    )
    for block in blocks:
        if header.match(block.split("\n", 1)[0]):
            return block
    return None


def parse_recents_label(activities_dump: str, *, package: str = DEFAULT_PACKAGE) -> str | None:
    """Returns the app-switcher label dumped for the app's activity.

    ``""`` means the block exists but sets no label; ``None`` means the app's block
    is missing, so the capture cannot answer.
    """
    block = _app_activity_block(activities_dump, package)
    if block is None:
        return None
    m = re.search(r'taskDescription:\s*label\s*=\s*"([^"]*)"', block)
    return "" if m is None else m.group(1)


# ---------------------------------------------------------------------------
# Public checks
# ---------------------------------------------------------------------------


def icon_appearance(
    platform: str,
    *,
    png: bytes | None = None,
    window_dump: str | None = None,
    sdk: int | None = None,
    package: str = DEFAULT_PACKAGE,
) -> Brightness:
    """Returns the status-bar icon brightness: ``"light"`` or ``"dark"``.

    Android reads what SystemUI draws from ``window_dump``: on API 30+ the status-bar
    appearance region under the top centre, else the app activity window's appearance
    bit. iOS samples the icon from ``png``.

    Args:
        platform: ``"android"`` or ``"ios"``.
        png: Screenshot bytes; required on iOS.
        window_dump: ``dumpsys window`` text; required on Android.
        sdk: Android API level; required on Android, no dump prints one.
        package: Application id scoping the window block.

    Raises:
        ForeignFocusError: Another window owns focus on Android.
        StartingWindowError: A starting window is up on Android.
        SystemBarsError: No icon pixel differs from the fill on iOS.
        ValueError: A required argument is missing or the platform is unknown.
    """
    if platform == "android":
        if window_dump is None:
            raise ValueError("android needs window_dump")
        if sdk is None:
            raise ValueError("android needs sdk")
        _require_judgeable_window(window_dump, package)
        dark = _status_region_wants_dark_icons(window_dump) if sdk >= _APPEARANCE_API else None
        if dark is None:
            dark = parse_appearance(window_dump, "statusBars", sdk, package=package)
        elif _app_window_block(window_dump, package) is None:
            raise SystemBarsError(f"no window of {package} in the dump")
        return "dark" if dark else "light"
    if platform == "ios":
        if png is None:
            raise ValueError("ios needs png")
        _fill, icon = sample_status_bar(read_png(png), platform)
        if icon is None:
            raise SystemBarsError("no visible status-bar icons")
        return brightness_of(icon)
    raise ValueError(f"unsupported platform {platform!r} (want android or ios)")


def bar_fill_brightness(png: bytes, platform: str) -> Brightness:
    """Returns the brightness of the fill under the status bar."""
    fill, _icon = sample_status_bar(read_png(png), platform)
    return brightness_of(fill)


def _bars_visible(window_dump: str, package: str) -> tuple[bool, bool]:
    _require_judgeable_window(window_dump, package)
    status = parse_bar_visible(window_dump, "statusBars", package=package)
    navigation = parse_bar_visible(window_dump, "navigationBars", package=package)
    if status is None or navigation is None:
        raise SystemBarsError(
            "could not parse statusBars/navigationBars visibility "
            "(tried InsetsSource type=/visible= and legacy vsysui=)"
        )
    return status, navigation


def bars_hidden(window_dump: str, *, package: str = DEFAULT_PACKAGE) -> bool:
    """Returns whether both system bars are hidden.

    Raises:
        ForeignFocusError: Another window owns focus.
        StartingWindowError: A starting window is up.
        SystemBarsError: The dump carries no visibility for a bar.
    """
    status, navigation = _bars_visible(window_dump, package)
    return not status and not navigation


def bars_shown(window_dump: str, *, package: str = DEFAULT_PACKAGE) -> bool:
    """Returns whether both system bars are visible.

    Raises:
        ForeignFocusError: Another window owns focus.
        StartingWindowError: A starting window is up.
        SystemBarsError: The dump carries no visibility for a bar.
    """
    status, navigation = _bars_visible(window_dump, package)
    return status and navigation


def recents_label(activities_dump: str, *, package: str = DEFAULT_PACKAGE) -> str | None:
    """Returns the app-switcher label; ``None`` when the app's activity block is missing."""
    return parse_recents_label(activities_dump, package=package)
