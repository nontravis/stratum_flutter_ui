"""System-bar e2e (FO-03 US-14): the probe checks, driven live; Android, and iOS for the painted fill.

Two checks run on macOS and the web (design section 11): a page with a rotation lock shows in
the window with no error, which the desktop and web targets of `system_style_device_test.dart`
named, and, on the web only, the browser tab title follows the page label, which the file left
to the eye (`system_style_device_test.dart:18-20`).

The iOS legs stop at the painted fill: the iPhone Duo simulator (iOS 27.1) draws no status bar
in its framebuffer, so an icon's brightness cannot be read from a screenshot there, and the
sampler would read the debug banner instead.

Drives the `themes/system_style` fixture. The verdicts live outside the app:
`dumpsys window`'s appearance bit and bar visibility, `dumpsys activity
activities`' taskDescription label, and the screenshot's status-bar fill,
state the OS owns, not Flutter. Each test cites the probe check it replaces
(`system_style_device_test.dart:105`, `:141`, `:167`) and that check's lines
in `system_style_device_test.probes.py`.

Every OS read follows two rules. It starts only after the page it checks is up
(the menu's open button is gone), because the menu already rests in a state
that can match the wanted one. It then has to hold across `DEFAULT_HOLD_S`
(`wait_until_held`), because the Dart probe read after a `pumpAndSettle` and a
style that lands and is then reverted by the platform must fail.
"""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e.android.dumps import activities_dump, sdk_level, window_dump
from stratum_e2e.android.immersive import (
    IMMERSIVE_CONFIRMATION,
    dismiss_immersive_confirmation,
)
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import NODE_NOT_FOUND, by_label, click, is_displayed
from stratum_e2e.macos import tree as mac_tree
from stratum_e2e.system_bars import (
    Brightness,
    SystemBarsError,
    bar_fill_brightness,
    bars_hidden,
    bars_shown,
    icon_appearance,
    recents_label,
)
from stratum_e2e.waits import wait_until, wait_until_held
from stratum_e2e.web import snapshot as web_snapshot
from stratum_e2e.web.session import accessibility_snapshot

FIXTURE_ID = "themes/system_style"

# The fixture's button labels (test_app/lib/fixtures/themes/system_style.dart); the buttons
# carry no id, since an id would split a button's label from its tap onto two nodes.
OPEN_DARK_HEADER = "Open dark header"
OPEN_WHITE_PAGE = "Open white page"
OPEN_DARK_STATUSBAR = "Open dark status bar"
OPEN_VIDEO = "Open video"

# The labels the browser tab shows: the menu's app-wide label, then the video page's own.
APP_LABEL = "Stratum"
VIDEO_LABEL = "Video"

# The route push and the OS's answer to the SystemChrome write land a beat after the click.
SETTLE_TIMEOUT_S = 25


def _serial(driver: Any) -> str:
    return str(driver.capabilities["udid"])


def _menu_displayed(driver: Any, platform: str) -> bool:
    """Whether the menu's first open button is on screen.

    A page pushed over the menu removes it.
    """
    try:
        return is_displayed(by_label(driver, platform, OPEN_DARK_HEADER), platform)
    except NODE_NOT_FOUND:
        return False


def _wait_menu_up(driver: Any, platform: str) -> None:
    wait_until(lambda: _menu_displayed(driver, platform), "the system-style menu on screen")


def _wait_page_up(driver: Any, platform: str) -> None:
    """Wait until a page covers the menu, so a read cannot pass on the menu's own state."""
    wait_until(lambda: not _menu_displayed(driver, platform), "the pushed page to cover the menu")


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until its menu is on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    _wait_menu_up(driver, platform)


def _open_page(driver: Any, platform: str, label: str) -> None:
    """Click the menu button labeled [label] and wait until its page is up."""

    def clicked() -> bool:
        try:
            click(by_label(driver, platform, label), platform)
        except NODE_NOT_FOUND:
            return False
        return True

    wait_until(clicked, f"{label!r} to be clickable")
    _wait_page_up(driver, platform)


def _app_window_dump(driver: Any, serial: str) -> str:
    """A window dump the checks can read.

    The first-entry immersive confirmation is dismissed when it shows; the dump taken
    while it was up describes that window, so this read fails and the poll reads again.
    """
    dump = window_dump(serial)
    if dismiss_immersive_confirmation(driver, dump):
        raise SystemBarsError(f"{IMMERSIVE_CONFIRMATION} was up; dismissed it")
    return dump


def _hold_icons(driver: Any, platform: str, app_id: str, want: Brightness, what: str) -> None:
    serial = _serial(driver)
    wait_until_held(
        lambda: icon_appearance(
            platform,
            window_dump=_app_window_dump(driver, serial),
            sdk=sdk_level(serial),
            package=app_id,
        )
        == want,
        what,
        timeout_s=SETTLE_TIMEOUT_S,
        catch=(SystemBarsError,),
    )


def _hold_bars(driver: Any, app_id: str, *, hidden: bool, what: str) -> None:
    serial = _serial(driver)
    check = bars_hidden if hidden else bars_shown
    wait_until_held(
        lambda: check(_app_window_dump(driver, serial), package=app_id),
        what,
        timeout_s=SETTLE_TIMEOUT_S,
        catch=(SystemBarsError,),
    )


@pytest.mark.android
@pytest.mark.req("fo03/us14/s3")
@pytest.mark.req("fo03/us14/fr02/e01")
def test_status_bar_icons_turn_light_under_a_dark_header(
    driver: Any, platform: str, app_id: str
) -> None:
    """dark_header (probes.py:675-685; dart:105): light icons over the dark fill.

    The menu rests on dark icons, so a pass needs the dark-header page to turn them light
    and keep them light. The known pixel_8 (API 37) failure, dark icons, is the open
    finding of phase stratum-system-style-api37; expected there, never xfailed.
    """
    _open(driver, platform, app_id)
    _open_page(driver, platform, OPEN_DARK_HEADER)

    _hold_icons(
        driver, platform, app_id, "light", "light status-bar icons under the dark header"
    )


@pytest.mark.android
@pytest.mark.req("fo03/us14/s5")
@pytest.mark.req("fo03/us14/fr02/e03")
def test_status_bar_icons_turn_dark_over_the_page_background(
    driver: Any, platform: str, app_id: str
) -> None:
    """white_page (probes.py:686-696; dart:105): dark icons, no fill declared.

    The menu also rests on dark icons, so the read starts only once the white page covers it.
    """
    _open(driver, platform, app_id)
    _open_page(driver, platform, OPEN_WHITE_PAGE)

    _hold_icons(
        driver, platform, app_id, "dark", "dark status-bar icons over the page background"
    )


@pytest.mark.android
@pytest.mark.req("fo03/us14/s16")
@pytest.mark.req("fo03/us14/fr02/e07")
def test_a_dark_bar_color_turns_the_status_bar_icons_light(
    driver: Any, platform: str, app_id: str
) -> None:
    """dark_statusbar (probes.py:697-707; dart:141): light icons against the dark bar color."""
    _open(driver, platform, app_id)
    _open_page(driver, platform, OPEN_DARK_STATUSBAR)

    _hold_icons(
        driver, platform, app_id, "light", "light status-bar icons against the dark bar color"
    )


@pytest.mark.android
@pytest.mark.ios
@pytest.mark.req("fo03/us14/s16")
@pytest.mark.req("fo03/us14/fr01/e06")
def test_the_painted_bar_color_is_the_topmost_fill(
    driver: Any, platform: str, app_id: str
) -> None:
    """dark_statusbar_fill (probes.py:708-718; dart:141): the strip under the bar reads dark.

    On iOS the strip is the app's own top pixels, which is all the screenshot holds there.
    """
    _open(driver, platform, app_id)
    _open_page(driver, platform, OPEN_DARK_STATUSBAR)

    wait_until_held(
        lambda: bar_fill_brightness(driver.get_screenshot_as_png(), platform) == "dark",
        "the painted dark bar color as the topmost fill",
        timeout_s=SETTLE_TIMEOUT_S,
        catch=(SystemBarsError,),
    )


@pytest.mark.android
@pytest.mark.req("fo03/us14/s7")
@pytest.mark.req("fo03/us14/fr03/e05")
def test_the_video_page_hides_both_bars(
    driver: Any, platform: str, app_id: str
) -> None:
    """video_bars_hidden (probes.py:719-728; dart:167): immersiveSticky hides both."""
    _open(driver, platform, app_id)
    _open_page(driver, platform, OPEN_VIDEO)

    _hold_bars(driver, app_id, hidden=True, what="both bars hidden on the video page")


@pytest.mark.android
@pytest.mark.req("fo03/us14/s8")
@pytest.mark.req("fo03/us14/fr03/e02")
def test_a_page_with_no_style_over_it_shows_the_bars_again(
    driver: Any, platform: str, app_id: str
) -> None:
    """video_bars_shown (probes.py:729-738; dart:167): back to a no-style page, both show.

    Back is Android's own, driven from outside, so the route pop and the app-wide restore
    read as the EndUser sees them.
    """
    _open(driver, platform, app_id)
    _open_page(driver, platform, OPEN_VIDEO)
    _hold_bars(driver, app_id, hidden=True, what="both bars hidden on the video page")
    driver.press_keycode(4)  # KEYCODE_BACK
    _wait_menu_up(driver, platform)

    _hold_bars(driver, app_id, hidden=False, what="both bars visible back on the menu")


@pytest.mark.android
@pytest.mark.req("fo03/us14/s9")
@pytest.mark.req("fo03/us14/fr03/e03")
@pytest.mark.req("fo03/us14/fr03/e05")
def test_back_to_the_video_page_hides_the_bars_again(
    driver: Any, platform: str, app_id: str
) -> None:
    """video_back (probes.py:739-748; dart:167): re-entering, hidden again, no restore code."""
    _open(driver, platform, app_id)
    _open_page(driver, platform, OPEN_VIDEO)
    _hold_bars(driver, app_id, hidden=True, what="both bars hidden on the video page")
    driver.press_keycode(4)  # KEYCODE_BACK
    _wait_menu_up(driver, platform)
    _hold_bars(driver, app_id, hidden=False, what="both bars visible back on the menu")
    _open_page(driver, platform, OPEN_VIDEO)

    _hold_bars(driver, app_id, hidden=True, what="both bars hidden again on the video page")


@pytest.mark.android
@pytest.mark.req("fo03/us14/s12")
@pytest.mark.req("fo03/us14/s13")
@pytest.mark.req("fo03/us14/s14")
@pytest.mark.req("fo03/us14/fr04")
def test_the_app_switcher_labels_the_page(
    driver: Any, platform: str, app_id: str
) -> None:
    """recents_label (probes.py:749-760; dart:167): the entry reads Stratum, then Video."""
    serial = _serial(driver)
    _open(driver, platform, app_id)
    wait_until_held(
        lambda: recents_label(activities_dump(serial), package=app_id) == "Stratum",
        "the app-wide switcher label Stratum on the menu page",
        timeout_s=SETTLE_TIMEOUT_S,
    )
    _open_page(driver, platform, OPEN_VIDEO)

    wait_until_held(
        lambda: recents_label(activities_dump(serial), package=app_id) == "Video",
        "the per-page switcher label Video on the video page",
        timeout_s=SETTLE_TIMEOUT_S,
    )


def _page_texts(driver: Any, platform: str) -> list[str]:
    """The texts the OS tree exposes right now: the Mac2 source, or the web snapshot."""
    if platform == "macos":
        return mac_tree.texts(driver.page_source)
    return web_snapshot.texts(accessibility_snapshot(driver))


def _window_size(driver: Any, platform: str) -> tuple[int, int] | None:
    """The window's size as the OS exposes it: from the Mac2 source, or the page's viewport.

    The viewport is the fixed size Playwright created the page with, so on web the size hold
    below cannot fail; the `Video` text carries the web check and the size hold carries macOS.
    """
    if platform == "macos":
        return mac_tree.window_size(driver.page_source)
    viewport = driver.viewport_size
    return None if viewport is None else (viewport["width"], viewport["height"])


@pytest.mark.macos
@pytest.mark.web
@pytest.mark.req("fo03/us14/s12")
@pytest.mark.req("fo03/us14/fr03/e05")
def test_a_page_that_locks_the_rotation_shows_in_the_window_with_no_error(
    driver: Any, platform: str, app_id: str
) -> None:
    """The video page asks for portraitUp (dart:31-35); a desktop window or a browser ignores it.

    The page must show, and on macOS the window must keep the shape it had, held across the
    settle window so a late resize would fail it (the web viewport is fixed; see `_window_size`).
    """
    _open(driver, platform, app_id)
    before = _window_size(driver, platform)
    assert before is not None

    _open_page(driver, platform, OPEN_VIDEO)

    wait_until_held(
        lambda: VIDEO_LABEL in _page_texts(driver, platform)
        and _window_size(driver, platform) == before,
        f"the video page showing in the window's current shape {before}",
        timeout_s=SETTLE_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )


@pytest.mark.web
@pytest.mark.req("fo03/us14/s13")
@pytest.mark.req("fo03/us14/s14")
@pytest.mark.req("fo03/us14/fr04")
def test_tab_title_follows_the_page_label(driver: Any, platform: str, app_id: str) -> None:
    """The tab title reads the page label after the push and the app label after back (dart:18-20)."""
    _open(driver, platform, app_id)
    wait_until(lambda: driver.title() == APP_LABEL, f"the tab title {APP_LABEL!r} on the menu")

    _open_page(driver, platform, OPEN_VIDEO)
    wait_until_held(
        lambda: driver.title() == VIDEO_LABEL,
        f"the tab title {VIDEO_LABEL!r} on the video page",
        timeout_s=SETTLE_TIMEOUT_S,
    )

    driver.go_back()  # the browser's own Back, as the EndUser presses it
    _wait_menu_up(driver, platform)
    wait_until_held(
        lambda: driver.title() == APP_LABEL,
        f"the tab title {APP_LABEL!r} back on the menu",
        timeout_s=SETTLE_TIMEOUT_S,
    )
