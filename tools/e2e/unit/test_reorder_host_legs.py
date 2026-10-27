"""Unit tests for the reorder list's host VoiceOver legs: the walk, the Mac2 bound, Chrome's guard.

Imports the e2e test module for its helpers only. A scripted VoiceOver, a fake clock, and fake
runners stand in for the host, so no VoiceOver, osascript, pgrep, or browser runs.
"""

from __future__ import annotations

import contextlib
import importlib.util
import subprocess
import time
from collections.abc import Iterator
from typing import Any

import pytest

from stratum_e2e import waits
from stratum_e2e.macos import host_voiceover as hv
from stratum_e2e.macos.host_voiceover import HostVoiceOverError, osascript_args
from stratum_e2e.macos.session import NEW_COMMAND_TIMEOUT_S
from stratum_e2e.paths import TESTS_DIR
from stratum_e2e.round.errors import RoundEnvError


def _load_e2e_module(relative: str) -> Any:
    """Import the e2e test file `e2e/<relative>` by path: `e2e/` is no package and sits off the import path."""
    path = TESTS_DIR / relative
    spec = importlib.util.spec_from_file_location(path.stem, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


reorder = _load_e2e_module("common/test_reorderable_list_view_layout.py")
ITEMS = reorder.INITIAL_ORDER
CHROME_PGREP = ["pgrep", "-x", "Google Chrome"]
CHROME_ACTIVATE = osascript_args('tell application "Google Chrome" to activate')
FIREFOX_EXECUTABLE = "/t/ms-playwright/firefox-1/firefox/Nightly.app/Contents/MacOS/firefox"
FIREFOX_BUNDLE = "/t/ms-playwright/firefox-1/firefox/Nightly.app"


class FakeClock:
    """Clock stub: `sleep` advances `now`, so the walk's bounded waits end without real time."""

    def __init__(self) -> None:
        self.now = 0.0

    def sleep(self, seconds: float) -> None:
        self.now += seconds

    def monotonic(self) -> float:
        return self.now


@pytest.fixture(autouse=True)
def clock(monkeypatch: pytest.MonkeyPatch) -> FakeClock:
    """Pace the walk's quiet reads and speech waits (`time` in the test module and in waits)."""
    fake = FakeClock()
    monkeypatch.setattr(time, "sleep", fake.sleep)
    monkeypatch.setattr(time, "monotonic", fake.monotonic)
    return fake


def _moves(label: str) -> list[str]:
    """The move entries the fixture offers [label] (fr03:32)."""
    if label == ITEMS[0]:
        return [reorder.MOVE_DOWN, reorder.MOVE_TO_END]
    if label == ITEMS[-1]:
        return [reorder.MOVE_UP, reorder.MOVE_TO_START]
    return [reorder.MOVE_UP, reorder.MOVE_DOWN, reorder.MOVE_TO_START, reorder.MOVE_TO_END]


class ScriptedVoiceOver:
    """VoiceOver stand-in: each stop speaks its utterances one per read, the last one holding.

    `move_next` goes to the next stop. Past the last stop it raises the helper's error when
    `refuses_end` is set (F8) and otherwise speaks nothing new. `actions_menu` returns the
    moves of the item its stop names, and records the stop it opened on.
    """

    def __init__(self, stops: list[list[str]], *, refuses_end: bool = False) -> None:
        self.stops = stops
        self.refuses_end = refuses_end
        self.stop = 0
        self.reads = 0
        self.menus_at: list[int] = []

    def last_phrase(self) -> str:
        utterances = self.stops[self.stop]
        phrase = utterances[min(self.reads, len(utterances) - 1)]
        self.reads += 1
        return phrase

    def move_next(self) -> None:
        if self.stop + 1 < len(self.stops):
            self.stop += 1
            self.reads = 0
        elif self.refuses_end:
            raise HostVoiceOverError("osascript exited 1 for 'move right'; stderr: end of content")

    def actions_menu(self) -> list[str]:
        self.menus_at.append(self.stop)
        label = next(
            match.group(1)
            for utterance in self.stops[self.stop]
            if (match := reorder._HOST_ITEM_IN_PHRASE.search(utterance)) is not None
        )
        return ["Actions", *_moves(label)]


def _plain_stops(count: int = len(ITEMS)) -> list[list[str]]:
    return [[f"{label}, button"] for label in ITEMS[:count]]


def _walk(voiceover: ScriptedVoiceOver) -> tuple[dict[str, str], dict[str, set[str]], list[str]]:
    return reorder._host_walk(voiceover)  # type: ignore[arg-type]  # duck-typed HostVoiceOver


def test_walk_reads_every_item_and_its_moves() -> None:
    stops, menus, phrases = _walk(ScriptedVoiceOver(_plain_stops()))

    reorder._assert_host_stops(stops, phrases)
    reorder._assert_host_actions(menus, stops, phrases)


def test_walk_reads_a_label_that_arrives_only_once_speech_settles() -> None:
    # Finding 5: the move's first change is the group's name; the label lands after the reads
    # the old walk searched, so only the quiet read before the next move hears it.
    scripted = _plain_stops()
    scripted[2] = ["Items, group", "Items, group", "Item 3, button"]
    voiceover = ScriptedVoiceOver(scripted)

    stops, _, phrases = _walk(voiceover)

    reorder._assert_host_stops(stops, phrases)
    assert voiceover.menus_at == list(range(len(ITEMS)))


def test_walk_reads_a_label_a_hint_overwrites_before_the_next_read() -> None:
    # Finding 5: the wait's own read heard the label; the hint replaced it before the next read.
    scripted = _plain_stops()
    scripted[2] = ["Item 3, button", "Actions available"]
    voiceover = ScriptedVoiceOver(scripted)

    stops, _, phrases = _walk(voiceover)

    reorder._assert_host_stops(stops, phrases)
    assert stops["Item 3"] == "Item 3, button"


def test_walk_counts_a_refused_move_as_silent_and_keeps_the_phrases() -> None:
    # F8: VoiceOver refuses `move right` past the end of content; the walk ends with what it read.
    voiceover = ScriptedVoiceOver(_plain_stops(3), refuses_end=True)

    stops, _, phrases = _walk(voiceover)

    assert list(stops) == ITEMS[:3]
    refusals = [phrase for phrase in phrases if phrase.startswith("[move refused]")]
    assert len(refusals) == reorder.HOST_SILENT_MOVES
    assert "end of content" in refusals[0]


def test_walk_ends_after_the_silent_moves_at_the_end_of_content() -> None:
    voiceover = ScriptedVoiceOver(_plain_stops(4))

    stops, _, _ = _walk(voiceover)

    assert list(stops) == ITEMS[:4]


def test_the_mac2_session_outlasts_the_host_walk_worst_case() -> None:
    """NEW_COMMAND_TIMEOUT_S stays above the walk's bounds, summed as macos/session.py sums them."""
    settled_entry = 2 * hv.MENU_PHRASE_TIMEOUT_SECONDS + hv.POLL_INTERVAL_SECONDS
    menu = hv.MENU_PHRASE_TIMEOUT_SECONDS + hv.ACTIONS_MENU_MAX_ENTRIES * settled_entry
    move = 2 * reorder.HOST_SPEECH_TIMEOUT_S + waits.POLL_INTERVAL_S
    menus = reorder.ITEM_COUNT * (menu + reorder.HOST_SPEECH_TIMEOUT_S)
    walk = reorder.HOST_MAX_MOVES * move + menus
    start_and_stop = hv.READY_TIMEOUT_SECONDS + 2 * hv.STOP_TIMEOUT_SECONDS

    assert NEW_COMMAND_TIMEOUT_S > walk + start_and_stop


class FakeRun:
    """`subprocess.run` stub: records each call, then returns [result] or raises [raises]."""

    def __init__(
        self,
        returncode: int = 0,
        stdout: str = "",
        stderr: str = "",
        raises: BaseException | None = None,
    ) -> None:
        self.result = (returncode, stdout, stderr)
        self.raises = raises
        self.calls: list[list[str]] = []
        self.kwargs: list[dict[str, Any]] = []

    def __call__(self, args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        self.calls.append(args)
        self.kwargs.append(kwargs)
        if self.raises is not None:
            raise self.raises
        returncode, stdout, stderr = self.result
        return subprocess.CompletedProcess(args, returncode, stdout=stdout, stderr=stderr)


def test_a_chrome_that_already_runs_is_refused() -> None:
    # Finding 4: activation by app name could reach the tester's Chrome instead of the launched one.
    runner = FakeRun(returncode=0, stdout="812\n")

    with pytest.raises(RoundEnvError, match="already runs"):
        reorder._refuse_a_running_browser(runner, CHROME_PGREP)

    assert runner.calls == [CHROME_PGREP]


def test_no_running_chrome_passes_the_guard() -> None:
    runner = FakeRun(returncode=1)

    reorder._refuse_a_running_browser(runner, CHROME_PGREP)

    assert runner.calls == [CHROME_PGREP]
    assert runner.kwargs[0]["timeout"] > 0


def test_a_failing_chrome_pgrep_is_a_round_env_error() -> None:
    with pytest.raises(RoundEnvError, match="pgrep exited 2.*bad option"):
        reorder._refuse_a_running_browser(FakeRun(returncode=2, stderr="bad option"), CHROME_PGREP)


def test_a_missing_pgrep_is_a_round_env_error() -> None:
    with pytest.raises(RoundEnvError, match="pgrep not found"):
        reorder._refuse_a_running_browser(FakeRun(raises=FileNotFoundError("pgrep")), CHROME_PGREP)


def test_activation_brings_the_one_chrome_to_the_front() -> None:
    runner = FakeRun(returncode=0)

    reorder._activate_browser(runner, "Google Chrome")

    assert runner.calls == [CHROME_ACTIVATE]
    assert runner.kwargs[0]["timeout"] > 0


def test_a_refused_activation_is_a_round_env_error_with_its_stderr() -> None:
    stderr = "execution error: Not authorized to send Apple events to Google Chrome. (-1743)"

    with pytest.raises(RoundEnvError, match=r"osascript exited 1.*\(-1743\)"):
        reorder._activate_browser(FakeRun(returncode=1, stderr=stderr), "Google Chrome")


def test_a_timed_out_activation_is_a_round_env_error_with_its_stderr() -> None:
    expired = subprocess.TimeoutExpired(cmd="osascript", timeout=10, stderr=b"waiting for consent")

    with pytest.raises(RoundEnvError, match="timed out.*waiting for consent"):
        reorder._activate_browser(FakeRun(raises=expired), "Google Chrome")


def test_host_app_names_chrome_by_its_app_name() -> None:
    assert reorder._host_app("chrome", FIREFOX_EXECUTABLE) == (CHROME_PGREP, "Google Chrome")


def test_host_app_targets_playwrights_firefox_by_its_paths() -> None:
    pgrep, app = reorder._host_app("firefox", FIREFOX_EXECUTABLE)

    assert pgrep == ["pgrep", "-f", FIREFOX_EXECUTABLE]
    assert app == FIREFOX_BUNDLE


def test_host_app_refuses_a_firefox_outside_an_app_bundle() -> None:
    with pytest.raises(RoundEnvError, match="not inside an .app bundle"):
        reorder._host_app("firefox", "/t/firefox/firefox")


def test_firefox_activation_goes_by_the_bundle_path() -> None:
    runner = FakeRun(returncode=0)

    reorder._activate_browser(runner, FIREFOX_BUNDLE)

    assert runner.calls == [osascript_args(f'tell application "{FIREFOX_BUNDLE}" to activate')]


class _HostBrowser:
    def __init__(self, launches: list[tuple[str, dict[str, Any]]]) -> None:
        self._launches = launches

    def new_page(self, base_url: str | None = None) -> str:
        return "page"

    def close(self) -> None:
        pass


class _HostType:
    def __init__(self, name: str, launches: list[tuple[str, dict[str, Any]]]) -> None:
        self._name = name
        self._launches = launches
        self.executable_path = FIREFOX_EXECUTABLE

    def launch(self, **kwargs: Any) -> _HostBrowser:
        self._launches.append((self._name, kwargs))
        return _HostBrowser(self._launches)


class _HostPlaywright:
    def __init__(self) -> None:
        self.launches: list[tuple[str, dict[str, Any]]] = []
        self.chromium = _HostType("chromium", self.launches)
        self.firefox = _HostType("firefox", self.launches)


def _fake_toolchain(monkeypatch: pytest.MonkeyPatch, playwright: _HostPlaywright) -> None:
    @contextlib.contextmanager
    def toolchain() -> Iterator[_HostPlaywright]:
        yield playwright

    monkeypatch.setattr(reorder, "toolchain_playwright", toolchain)
    monkeypatch.setattr(reorder, "open_fixture_route", lambda page, fixture: None)
    monkeypatch.setattr(reorder, "wait_until_held", lambda *args, **kwargs: None)
    monkeypatch.setattr(reorder, "_order", lambda page, platform: reorder.INITIAL_ORDER)


def test_the_host_leg_launches_the_target_browser_visible(monkeypatch: pytest.MonkeyPatch) -> None:
    playwright = _HostPlaywright()
    _fake_toolchain(monkeypatch, playwright)
    runner = _HostRunner(pgrep=1)

    with reorder._host_browser("http://127.0.0.1:1", "firefox", runner=runner):
        pass

    assert playwright.launches == [("firefox", {"headless": False})]
    assert runner.calls == [
        ["pgrep", "-f", FIREFOX_EXECUTABLE],
        osascript_args(f'tell application "{FIREFOX_BUNDLE}" to activate'),
    ]


def test_the_host_leg_refuses_a_running_browser_before_it_launches(monkeypatch: pytest.MonkeyPatch) -> None:
    playwright = _HostPlaywright()
    _fake_toolchain(monkeypatch, playwright)

    with pytest.raises(RoundEnvError, match="already runs"):
        with reorder._host_browser("http://127.0.0.1:1", "chrome", runner=FakeRun(returncode=0, stdout="812\n")):
            pytest.fail("the leg must not run beside another browser")

    assert playwright.launches == []


class _HostRunner:
    """Answers `pgrep` with [pgrep] as its exit code and every other command with 0."""

    def __init__(self, pgrep: int) -> None:
        self._pgrep = pgrep
        self.calls: list[list[str]] = []

    def __call__(self, args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        self.calls.append(args)
        return subprocess.CompletedProcess(args, self._pgrep if args[0] == "pgrep" else 0, stdout="", stderr="")
