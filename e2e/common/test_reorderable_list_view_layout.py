"""Reorder list: the screen reader takes Alt+Up (TalkBack), offers valid moves, moves and speaks.

Drives the `common/reorderable_list_view_layout` fixture (FO-06 US-11; US-04 FR-02 E11: each
row, the disabled one too, is one stop that reads its role, state, moves and tap). TalkBack's actions
for the focused item open through its own keyboard shortcuts on the uhid keyboard, measured
on the e2e AVD (TalkBack 15): Alt+Space opens the TalkBack menu, Alt+Enter on its `Actions`
entry opens the item's actions, Alt+Right steps through them and Alt+Enter runs the one in
focus. The menu lives in a TalkBack window Appium cannot read, so its entries are read from
the speech log.

On iOS, VoiceOver can be walked but not driven: with it on, an Appium touch does not reach
the app, and Appium has no command that runs a VoiceOver action. Level 2 therefore reads the
focus order and the speech. The drop a move announcement needs cannot happen with VoiceOver
on (measured: a drag from Item 3 above Item 2 left the order and the log unchanged, 4 of 4
attempts, while the same drag with VoiceOver off dropped), so no iOS test claims the spoken
move announcement.
"""

from __future__ import annotations

import contextlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy
from playwright.sync_api import Error as PlaywrightError

from stratum_e2e.android import emu_mouse
from stratum_e2e.android.screen_reader import (
    FOCUS_TIMEOUT_S,
    MENU_CANCEL,
    MENU_STEPS,
    entry_name,
    focus_by_touch,
    open_actions,
    press_and_hear,
    run_action,
    settled_speech,
)
from stratum_e2e.android.talkback import TalkBackLog, a11y_focused
from stratum_e2e.android.uhid_keyboard import KEY_ENTER, KEY_RIGHT, KEY_UP, MOD_LALT, UhidKeyboard
from stratum_e2e.fixtures import open_fixture_and_wait
from stratum_e2e.ios import tree as ios_tree
from stratum_e2e.ios.focus_order import focus_order, matches_order
from stratum_e2e.ios.voiceover import VoiceOver
from stratum_e2e.locate import by_id
from stratum_e2e.macos import tree as mac_tree
from stratum_e2e.macos.host_voiceover import HostVoiceOver, HostVoiceOverError, osascript_args
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.waits import wait_until, wait_until_held
from stratum_e2e.web import snapshot as web_snapshot
from stratum_e2e.web.browsers import launch_browser, toolchain_playwright
from stratum_e2e.web.server import StaticServer
from stratum_e2e.web.session import accessibility_snapshot, open_fixture_route

FIXTURE_ID = "common/reorderable_list_view_layout"
LOG_ID = "reorder.log"
ITEM_COUNT = 6
INITIAL_ORDER = [f"Item {n}" for n in range(1, ITEM_COUNT + 1)]

MOVE_UP = "Move up"
MOVE_DOWN = "Move down"
MOVE_TO_START = "Move to the start"
MOVE_TO_END = "Move to the end"
ALL_MOVES = {MOVE_UP, MOVE_DOWN, MOVE_TO_START, MOVE_TO_END}
WAIT_TIMEOUT_S = 10

ACTIONS_HINT = "Actions available"
# What VoiceOver speaks in turn, item 1 to the last element on screen: each root row, the
# disabled Item 6 too, reads its label, `Button`, its state, and `Actions available` at one
# stop; the log follows (VoiceOver cuts an utterance at 64 characters).
IOS_FOCUS_ORDER = [
    *(f"Item {n} Button {ACTIONS_HINT}" for n in range(1, ITEM_COUNT)),
    f"Item {ITEM_COUNT} dimmed Button {ACTIONS_HINT}",
    "Log: nothing yet.",
]

# Host VoiceOver (level2_host, owner command only): the VO cursor starts wherever the host left
# it (on web, possibly in the browser's toolbar), so the walk moves right until it has read all six
# items, this many moves have passed, or two moves in a row spoke nothing new (the end of
# content, or a tree VoiceOver is still building, passes with one).
HOST_MAX_MOVES = 60
HOST_SPEECH_TIMEOUT_S = 5
HOST_SILENT_MOVES = 2
# How long a phrase must hold still (two reads this far apart agree) before a move fires, so a
# hint that lands after a stop's label is not read as the move's answer (edge F1).
HOST_QUIET_S = 0.25
# A stop counts as an item when `Item <n>` starts the phrase or follows a comma: a first stop
# into a new group often carries the group's name first (edge F2).
_HOST_ITEM_IN_PHRASE = re.compile(r"(?:^|,\s*)(Item \d+)")
# The process name of the Chrome the web host leg launches for the `chrome` target (Playwright's `chrome` channel).
_CHROME_PROCESS = "Google Chrome"
_HOST_RUN_TIMEOUT_S = 10.0

_ITEM_LABEL = re.compile(r"Item \d+")
_BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


def _item_nodes(driver: Any) -> list[tuple[str, int, ET.Element]]:
    """Return (label, top edge, node) of each distinct `Item <n>` node, top to bottom."""
    root = ET.fromstring(driver.page_source.encode("utf-8"))
    found: dict[str, tuple[str, int, ET.Element]] = {}
    for node in root.iter():
        label = node.get("text") or node.get("content-desc") or ""
        bounds = _BOUNDS.fullmatch(node.get("bounds") or "")
        if bounds is None or not _ITEM_LABEL.fullmatch(label):
            continue
        found.setdefault(label, (label, int(bounds.group(2)), node))
    return sorted(found.values(), key=lambda entry: entry[1])


def _ios_items(driver: Any) -> dict[str, ios_tree.Node]:
    """Return the distinct `Item <n>` buttons by label, top to bottom."""
    found: dict[str, ios_tree.Node] = {}
    for node in ios_tree.nodes(driver.page_source):
        if node.kind == "Button" and _ITEM_LABEL.fullmatch(node.label):
            found.setdefault(node.label, node)
    return dict(sorted(found.items(), key=lambda entry: entry[1].y))


def _mac_items(driver: Any) -> dict[str, mac_tree.Node]:
    """Return the distinct `Item <n>` buttons by label, top to bottom."""
    found: dict[str, mac_tree.Node] = {}
    for node in mac_tree.nodes(driver.page_source):
        if node.kind == "Button" and _ITEM_LABEL.fullmatch(node.label):
            found.setdefault(node.label, node)
    return dict(sorted(found.items(), key=lambda entry: entry[1].y))


def _web_items(driver: Any) -> dict[str, web_snapshot.SnapshotNode]:
    """Return the distinct `Item <n>` buttons by name, in the snapshot's order."""
    found: dict[str, web_snapshot.SnapshotNode] = {}
    for node in web_snapshot.nodes(accessibility_snapshot(driver)):
        if node.role == "button" and _ITEM_LABEL.fullmatch(node.name):
            found.setdefault(node.name, node)
    return found


def _order(driver: Any, platform: str) -> list[str]:
    if platform == "ios":
        return list(_ios_items(driver))
    if platform == "macos":
        return list(_mac_items(driver))
    if platform == "web":
        return list(_web_items(driver))
    return [label for label, _, _ in _item_nodes(driver)]


def _app_log(driver: Any) -> str:
    return str(by_id(driver, "android", LOG_ID).get_attribute("content-desc"))


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until all six items are on screen."""
    open_fixture_and_wait(
        driver,
        platform,
        app_id,
        FIXTURE_ID,
        lambda: _order(driver, platform) == INITIAL_ORDER,
        "the six items on screen",
    )


def _host_walk(voiceover: HostVoiceOver) -> tuple[dict[str, str], dict[str, set[str]], list[str]]:
    """Walk the cursor right; return each item stop's phrase by label, its menu's moves by label,
    and every phrase seen.

    A stop counts as an item when `Item <n>` starts the phrase or follows a comma (a first stop
    into a new group often carries the group's name first, edge F2). Each move fires only after
    two phrase reads HOST_QUIET_S apart agree, so a hint that lands after a stop's label is not
    mistaken for the move's answer (edge F1). Each item's actions menu is read at its own stop,
    so the label and the move list come from the same stop (N1); `stops` and `menus` share keys,
    so a menu read where no item label was spoken fails the walk's own contract. The walk ends
    at the sixth item, after HOST_SILENT_MOVES moves in a row spoke nothing new, or at the move
    bound; a move VoiceOver refuses (past the end of content) counts as silent. Every phrase
    seen and every refusal, in order, comes back so a failure names the cause (edge F4, F8).
    """
    stops: dict[str, str] = {}
    menus: dict[str, set[str]] = {}
    phrases: list[str] = []
    silent = 0
    heard: list[str] = []
    for _ in range(HOST_MAX_MOVES):
        previous = _host_read_stop(voiceover, heard, stops, menus, phrases)
        if len(stops) == ITEM_COUNT:
            break
        heard = _host_move(voiceover, previous, phrases)
        if heard:
            silent = 0
            continue
        silent += 1
        if silent >= HOST_SILENT_MOVES:
            break
    return stops, menus, phrases


def _host_read_stop(
    voiceover: HostVoiceOver,
    heard: list[str],
    stops: dict[str, str],
    menus: dict[str, set[str]],
    phrases: list[str],
) -> str:
    """Find a new item at the cursor's stop and read its actions; return the phrase to move from.

    A stop's label can be the move's first change, the read after it, or arrive only once speech
    settles, after a group name or under a hint (finding 5), so [heard] is searched first and
    then a quiet read, all before the next move.
    """
    label = _host_new_item(heard, stops, phrases)
    if label is None:
        settled = _host_quiet_phrase(voiceover)
        label = _host_new_item([settled], stops, phrases)
        if label is None:
            return settled
    entries = voiceover.actions_menu()
    phrases.append(f"[{label} actions] {', '.join(entries)}")
    menus[label] = {move for move in ALL_MOVES if any(move in entry for entry in entries)}
    return _host_quiet_phrase(voiceover)


def _host_new_item(candidates: list[str], stops: dict[str, str], phrases: list[str]) -> str | None:
    """Log each of [candidates] into [phrases]; return the first label new to [stops], now added."""
    for phrase in candidates:
        if not phrases or phrases[-1] != phrase:
            phrases.append(phrase)
        item = _HOST_ITEM_IN_PHRASE.search(phrase)
        if item is not None and item.group(1) not in stops:
            stops[item.group(1)] = phrase
            return item.group(1)
    return None


def _host_move(voiceover: HostVoiceOver, previous: str, phrases: list[str]) -> list[str]:
    """Move the VO cursor right; return the phrases it spoke, or [] when it spoke nothing new.

    The first phrase that differs from [previous] is kept, then one more read, since a hint can
    replace the label between the two (finding 5). A refused move is logged into [phrases] and
    returns [] (F8).
    """
    try:
        voiceover.move_next()
    except HostVoiceOverError as error:
        phrases.append(f"[move refused] {error}")
        return []
    changed: list[str] = []

    def spoke_something_new() -> bool:
        phrase = voiceover.last_phrase()
        if phrase == previous:
            return False
        changed.append(phrase)
        return True

    try:
        wait_until(
            spoke_something_new, "VoiceOver to speak the next stop", timeout_s=HOST_SPEECH_TIMEOUT_S
        )
    except AssertionError:
        return []
    return [*changed, voiceover.last_phrase()]


def _host_quiet_phrase(voiceover: HostVoiceOver) -> str:
    """Return the phrase once two reads HOST_QUIET_S apart agree, or the newest read at the bound.

    VoiceOver speaks a stop's label, then its hint, as separate utterances; a read between the
    two would hand the walk a phrase that is about to change (edge F1), so only a phrase that
    holds still across two reads is trusted.
    """
    deadline = time.monotonic() + HOST_SPEECH_TIMEOUT_S
    phrase = voiceover.last_phrase()
    while time.monotonic() + HOST_QUIET_S < deadline:
        time.sleep(HOST_QUIET_S)
        current = voiceover.last_phrase()
        if current == phrase:
            break
        phrase = current
    return phrase


def _assert_host_stops(stops: dict[str, str], phrases: list[str]) -> None:
    """Assert the host walk read Item 1 to Item 6 in order; the phrases name the cause when not."""
    assert list(stops) == INITIAL_ORDER, (
        f"phrases spoken, in order: {phrases!r}; stops: {list(stops)}"
    )


def _assert_host_actions(
    menus: dict[str, set[str]], stops: dict[str, str], phrases: list[str]
) -> None:
    """Prove the FR-03 E03 action lists for Item 1, Item 3, and Item 6 from the walk's own menus.

    `_host_walk` read each menu at the stop whose phrase named the item, so the label and the
    list come from the same stop (N1). fr03:32 states the lists: Item 1 offers only
    `Move down` and `Move to the end`, a middle item all four moves, Item 6 (disabled) only
    `Move up` and `Move to the start`. The failure prints every phrase and both maps, so a
    menu read at a wrong stop or an unread item names its cause.
    """
    expected = {
        INITIAL_ORDER[0]: {MOVE_DOWN, MOVE_TO_END},
        INITIAL_ORDER[2]: ALL_MOVES,
        INITIAL_ORDER[-1]: {MOVE_UP, MOVE_TO_START},
    }
    offered = {label: menus.get(label, set()) for label in expected}
    assert offered == expected, (
        f"phrases spoken, in order: {phrases!r}; stops: {stops!r}; menus: {menus!r}"
    )


@contextlib.contextmanager
def _host_browser(base_url: str, browser: str, runner: Callable[..., Any] = subprocess.run) -> Iterator[Any]:
    """Yield a page of a visible [browser] on the fixture route, in front, closed afterwards.

    A headless browser has no window host VoiceOver can read, so this leg launches its own visible
    one instead of the suite's `driver` fixture, wraps a launch failure in `RoundEnvError` as the
    suite's own launch does (finding 5), and activates the browser through the OS (`osascript
    activate`), since `bring_to_front` only raises a tab inside the browser while the terminal can
    still be the frontmost app (edge F5). Playwright exposes no handle on the process it
    launches, so activation goes by app name or bundle path; the leg refuses to start beside
    another instance of that app, so the name can only mean the launched one. [runner] runs pgrep
    and osascript.
    """
    with toolchain_playwright() as playwright:
        pgrep_args, app = _host_app(browser, playwright.firefox.executable_path)
        _refuse_a_running_browser(runner, pgrep_args)
        try:
            opened = launch_browser(playwright, browser, headless=False)
        except PlaywrightError as error:
            raise RoundEnvError(f"{browser} launch failed: {error}") from error
        try:
            page = opened.new_page(base_url=base_url)
            open_fixture_route(page, FIXTURE_ID)
            wait_until_held(
                lambda: _order(page, "web") == INITIAL_ORDER,
                "the six items on screen",
                timeout_s=WAIT_TIMEOUT_S,
            )
            _activate_browser(runner, app)
            yield page
        finally:
            with contextlib.suppress(PlaywrightError):
                opened.close()


def _host_app(browser: str, firefox_executable: str) -> tuple[list[str], str]:
    """Return the `pgrep` argv that finds [browser]'s process and the `osascript` target that names its app.

    Chrome goes by its app name. Firefox is Playwright's bundled build, found by the path of its
    executable and activated by the `.app` bundle holding it, so a tester's own Firefox is never
    the target and no bundle name is hardcoded.
    """
    if browser == "chrome":
        return ["pgrep", "-x", _CHROME_PROCESS], _CHROME_PROCESS
    bundle = next((parent for parent in Path(firefox_executable).parents if parent.suffix == ".app"), None)
    if bundle is None:
        raise RoundEnvError(f"the Playwright Firefox at {firefox_executable} is not inside an .app bundle")
    return ["pgrep", "-f", firefox_executable], str(bundle)


def _refuse_a_running_browser(runner: Callable[..., Any], pgrep_args: list[str]) -> None:
    """Raise `RoundEnvError` when [pgrep_args] finds the browser's app already running on this Mac (finding 4).

    Activation by app name could reach that instance instead of the launched one, and VoiceOver
    would then walk the tester's own tabs.
    """
    result = _run_on_host(runner, pgrep_args)
    if result.returncode == 0:
        raise RoundEnvError(
            f"{pgrep_args[-1]} already runs (pid {_stream_text(result.stdout)}); quit it first: "
            "the web host leg activates the browser by name and could reach that instance"
        )
    if result.returncode != 1:
        raise RoundEnvError(
            f"pgrep exited {result.returncode}. stderr: {_stream_text(result.stderr)}"
        )


def _activate_browser(runner: Callable[..., Any], app: str) -> None:
    """Bring the one running [app], the launched browser, to the front, or raise `RoundEnvError`."""
    activate = f'tell application "{app}" to activate'
    result = _run_on_host(runner, osascript_args(activate))
    if result.returncode != 0:
        raise RoundEnvError(
            f"{app} activation failed: osascript exited {result.returncode}. "
            f"stderr: {_stream_text(result.stderr)}"
        )


def _run_on_host(runner: Callable[..., Any], args: list[str]) -> Any:
    """Run [args] through [runner]; a timeout or a missing program raises `RoundEnvError`."""
    try:
        return runner(
            args, capture_output=True, encoding="utf-8", check=False, timeout=_HOST_RUN_TIMEOUT_S
        )
    except subprocess.TimeoutExpired as error:
        raise RoundEnvError(
            f"{args[0]} timed out after {_HOST_RUN_TIMEOUT_S:g}s (a pending macOS Automation "
            f"prompt can block osascript). stderr: {_stream_text(error.stderr)}"
        ) from error
    except FileNotFoundError as error:
        raise RoundEnvError(f"{args[0]} not found") from error


def _stream_text(stream: str | bytes | None) -> str:
    """Return [stream] stripped; a timeout hands back bytes, and a missing stream reads empty."""
    if isinstance(stream, bytes):
        return stream.decode("utf-8", errors="replace").strip()
    return (stream or "").strip()


def _focus_item(driver: Any, label: str, talkback: TalkBackLog) -> None:
    """Explore-by-touch: touch [label]'s item so TalkBack focuses and speaks it."""
    focus_by_touch(driver, driver.find_element(AppiumBy.ACCESSIBILITY_ID, label), label, talkback)


def _offered_moves(keyboard: UhidKeyboard, talkback: TalkBackLog) -> set[str]:
    """Open the actions and return the moves spoken over one pass of the entries.

    A pass is complete only once Cancel was heard, the last entry of the menu.
    """
    open_actions(keyboard, talkback)
    heard: list[str] = []
    for _ in range(MENU_STEPS):
        heard += press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
    names = {entry_name(text) for text in heard}
    assert MENU_CANCEL in names, f"the pass did not reach Cancel, heard {heard}"
    return names & ALL_MOVES


def _close_actions(
    driver: Any, keyboard: UhidKeyboard, talkback: TalkBackLog, returns_to: str
) -> None:
    """Close the open actions menu through the keyboard: step to Cancel, then activate it.

    Proof of closing: TalkBack's focus is back on [returns_to], an app node, which the
    menu's own window cannot hold.
    """
    for _ in range(MENU_STEPS):
        heard = press_and_hear(keyboard, talkback, KEY_RIGHT, MOD_LALT)
        if any(entry_name(text) == MENU_CANCEL for text in heard):
            keyboard.press(KEY_ENTER, MOD_LALT)
            wait_until(
                lambda: a11y_focused(driver.page_source) == [returns_to],
                f"the menu to close with TalkBack focus back on {returns_to}",
                timeout_s=WAIT_TIMEOUT_S,
            )
            return
    raise AssertionError(f"{MENU_CANCEL!r} was not offered in {MENU_STEPS} steps")


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr02/e10")
def test_talkback_takes_alt_up_before_the_app(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)
    _focus_item(driver, "Item 3", talkback)

    talkback.mark()
    keyboard.press(KEY_UP, MOD_LALT)
    wait_until(
        lambda: a11y_focused(driver.page_source) == ["Item 2"],
        "TalkBack focus on Item 2",
        timeout_s=WAIT_TIMEOUT_S,
    )

    spoken = talkback.since_mark()
    assert spoken[0].startswith("Item 2"), spoken
    assert _order(driver, platform) == INITIAL_ORDER
    assert "moved" not in _app_log(driver)


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr03/e03")
def test_talkback_offers_only_valid_moves(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)

    _focus_item(driver, "Item 1", talkback)
    first = _offered_moves(keyboard, talkback)
    assert MOVE_UP not in first
    assert MOVE_TO_START not in first
    assert {MOVE_DOWN, MOVE_TO_END} <= first

    _close_actions(driver, keyboard, talkback, returns_to="Item 1")
    _focus_item(driver, "Item 3", talkback)
    middle = _offered_moves(keyboard, talkback)
    assert middle == ALL_MOVES


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us11/fr03/e03")
@pytest.mark.req("fo06/us11/fr06/e01")
def test_talkback_move_up_moves_item_and_speaks_position(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)
    _focus_item(driver, "Item 3", talkback)

    run_action(keyboard, talkback, MOVE_UP)
    wait_until(
        lambda: _order(driver, platform)[1] == "Item 3",
        "Item 3 in the second slot",
        timeout_s=WAIT_TIMEOUT_S,
    )
    wait_until(
        lambda: any("Moved to position 2 of 6" in text for text in talkback.since_mark()),
        "TalkBack to speak the new position",
        timeout_s=WAIT_TIMEOUT_S,
    )

    assert _order(driver, platform) == ["Item 1", "Item 3", "Item 2", "Item 4", "Item 5", "Item 6"]
    assert _app_log(driver).count("moved") == 1


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us04/fr02/e11")
def test_talkback_reads_a_root_row_with_its_role_moves_and_tap_at_one_stop(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)

    talkback.mark()
    _focus_item(driver, "Item 3", talkback)
    spoken = settled_speech(talkback, FOCUS_TIMEOUT_S)
    assert spoken, "TalkBack spoke nothing after the focus"
    node = driver.find_element(AppiumBy.ACCESSIBILITY_ID, "Item 3")

    assert spoken[0].startswith("Item 3"), spoken
    assert node.get_attribute("class") == "android.widget.Button"
    assert node.get_attribute("enabled") == "true"
    assert _offered_moves(keyboard, talkback) == ALL_MOVES

    _close_actions(driver, keyboard, talkback, returns_to="Item 3")
    assert "Item 3 tapped" not in _app_log(driver)
    x, y = emu_mouse.center(driver.find_element(AppiumBy.ACCESSIBILITY_ID, "Item 3").rect)
    emu_mouse.double_tap(str(driver.capabilities["udid"]), x, y)
    wait_until(
        lambda: "Item 3 tapped" in _app_log(driver),
        "the log to gain `Item 3 tapped`",
        timeout_s=WAIT_TIMEOUT_S,
    )


@pytest.mark.android
@pytest.mark.level2
@pytest.mark.talkback_avd
@pytest.mark.req("fo06/us04/fr02/e11")
def test_talkback_reads_the_disabled_root_row_with_its_moves_and_no_tap(
    driver: Any, platform: str, app_id: str, talkback: TalkBackLog, keyboard: UhidKeyboard
) -> None:
    _open(driver, platform, app_id)

    talkback.mark()
    _focus_item(driver, "Item 6", talkback)
    spoken = settled_speech(talkback, FOCUS_TIMEOUT_S)
    assert spoken, "TalkBack spoke nothing after the focus"
    node = driver.find_element(AppiumBy.ACCESSIBILITY_ID, "Item 6")

    assert node.get_attribute("enabled") == "false"
    assert spoken[0].startswith("Item 6"), spoken
    assert "disabled" in " ".join(spoken).lower(), spoken
    assert _offered_moves(keyboard, talkback) == {MOVE_UP, MOVE_TO_START}

    _close_actions(driver, keyboard, talkback, returns_to="Item 6")
    x, y = emu_mouse.center(driver.find_element(AppiumBy.ACCESSIBILITY_ID, "Item 6").rect)
    emu_mouse.double_tap(str(driver.capabilities["udid"]), x, y)
    wait_until_held(
        lambda: "Item 6 tapped" not in _app_log(driver),
        "the log to stay free of `Item 6 tapped`",
        hold_s=3,
        timeout_s=WAIT_TIMEOUT_S,
    )


@pytest.mark.android
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
def test_os_tree_exposes_items_and_disabled_item_6(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    assert _order(driver, platform) == INITIAL_ORDER
    enabled = {
        label: node.get("enabled") for label, _, node in _item_nodes(driver)
    }
    assert enabled["Item 6"] == "false"
    assert {label for label, value in enabled.items() if value == "true"} == set(
        INITIAL_ORDER[:-1]
    )


@pytest.mark.ios
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
def test_ios_tree_exposes_items_and_disabled_item_6(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    items = _ios_items(driver)

    assert list(items) == INITIAL_ORDER
    assert not items["Item 6"].enabled
    assert "NotEnabled" in items["Item 6"].traits
    assert {label for label, node in items.items() if node.enabled} == set(INITIAL_ORDER[:-1])


@pytest.mark.ios
@pytest.mark.level2
@pytest.mark.req("fo06/us11/fr03/e03")
@pytest.mark.req("fo06/us04/fr02/e11")
def test_voiceover_reads_each_item_at_one_stop(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    with VoiceOver(driver) as voiceover:
        spoken = focus_order(driver, voiceover)

    assert matches_order(spoken, IOS_FOCUS_ORDER), spoken


@pytest.mark.macos
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
def test_macos_tree_exposes_the_six_items_as_buttons(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    items = _mac_items(driver)

    assert list(items) == INITIAL_ORDER
    assert {label for label, node in items.items() if node.enabled} >= set(INITIAL_ORDER[:-1])


# WORKAROUND: Flutter 3.47.7's desktop accessibility bridge (engine
# shell/platform/common/accessibility_bridge.cc) maps no enabled state, so Mac2 reads the
# disabled Item 6 as enabled="true". Remove when the Flutter SDK floor includes 30c289b8cde
# (flutter#190353, in 3.48.0-0.1.pre); strict=True fails the run once the fix lands.
@pytest.mark.macos
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
@pytest.mark.xfail(
    strict=True,
    reason="Flutter desktop < 3.48 maps no disabled state to the AX node (flutter#190353)",
)
def test_macos_tree_exposes_item_6_as_disabled(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    items = _mac_items(driver)

    assert {label for label, node in items.items() if not node.enabled} == {INITIAL_ORDER[-1]}


@pytest.mark.web
@pytest.mark.level1
@pytest.mark.req("fo06/us11/fr03/e03")
def test_web_snapshot_exposes_items_and_disabled_item_6(
    driver: Any, platform: str, app_id: str
) -> None:
    _open(driver, platform, app_id)

    items = _web_items(driver)

    assert list(items) == INITIAL_ORDER
    assert {label for label, node in items.items() if "disabled" in node.flags} == {INITIAL_ORDER[-1]}


@pytest.mark.macos
@pytest.mark.level2
@pytest.mark.level2_host
@pytest.mark.req("fo06/us11/fr03/e03")
def test_host_voiceover_reads_the_items_and_their_moves_on_macos(
    driver: Any, platform: str, app_id: str
) -> None:
    """The Mac's own VoiceOver reads Item 1 to Item 6 in order, and their actions prove FR-03 E03.

    Owner command only (`-m level2_host --host-voiceover --platform macos`; ruling O1); without
    `--host-voiceover` it skips whatever `-m` selects. Focus: the Mac2 session already launched
    the build through `appPath`; `macos: activateApp` then puts its window in front before
    VoiceOver starts, so the VO cursor begins in the Flutter window. Mac2 sends no touch or read
    while VoiceOver walks; its `newCommandTimeout` (macos/session.py NEW_COMMAND_TIMEOUT_S)
    outlasts the walk's bounds, so the session survives it. VoiceOver must have "Allow
    VoiceOver to be controlled with AppleScript" on, or `HostVoiceOver` raises naming it.
    Words: a stop counts as an item when `Item <n>` starts the phrase or follows a comma; what
    follows the label is VoiceOver's own role and state wording and is not pinned. E03's action
    lists come from `actions_menu`: Item 1 offers only `Move down` and `Move to the end`,
    Item 3 all four moves, Item 6 (disabled) only `Move up` and `Move to the start` (fr03:32,
    as the TalkBack test `test_talkback_offers_only_valid_moves` states them).
    """
    _open(driver, platform, app_id)
    driver.execute_script("macos: activateApp", {"bundleId": app_id})

    with HostVoiceOver() as voiceover:
        stops, menus, phrases = _host_walk(voiceover)
        _assert_host_stops(stops, phrases)
        _assert_host_actions(menus, stops, phrases)


@pytest.mark.web
@pytest.mark.level2
@pytest.mark.level2_host
@pytest.mark.req("fo06/us11/fr03/e03")
def test_host_voiceover_reads_the_items_and_their_moves_on_web(
    static_server: StaticServer, browser_name: str
) -> None:
    """The Mac's VoiceOver reads Item 1 to Item 6 in order in a visible browser, and their moves prove E03.

    Owner command only (`-m level2_host --host-voiceover --platform web`; ruling O1); without
    `--host-voiceover` it skips whatever `-m` selects. Browser: the one the target names
    (`--device`), as the level 1 web leg, but visible (`headless=False`), since a headless
    browser has no window for VoiceOver; `_host_browser` refuses to start while another instance
    of that app runs, then activates the launched one itself (`osascript`), since
    `bring_to_front` only raises a tab while the terminal can stay the frontmost app. Semantics:
    the test_app calls `SemanticsBinding.ensureSemantics` at start, so Flutter's semantics tree
    exists with no placeholder click, and `_host_browser` waits for the six items (held) before
    VoiceOver starts; the browser builds its accessibility tree for VoiceOver once VoiceOver
    runs, which the walk's silence tolerance rides out.
    Words and E03 action lists: as the macOS leg above.
    """
    with _host_browser(static_server.url, browser_name), HostVoiceOver() as voiceover:
        stops, menus, phrases = _host_walk(voiceover)
        _assert_host_stops(stops, phrases)
        _assert_host_actions(menus, stops, phrases)
