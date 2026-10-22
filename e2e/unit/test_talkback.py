"""Unit tests for the TalkBack helpers (no adb, no device)."""

from __future__ import annotations

import subprocess

import pytest

from stratum_e2e.android.talkback import (
    AVD_NAME,
    TALKBACK_SERVICE,
    TalkBackLog,
    TalkBackSession,
    TalkBackSilent,
    TalkBackStuck,
    a11y_focused,
    avd_name,
    utterances,
)

MODULE = "stratum_e2e.android.talkback"
SERIAL = "emulator-5554"
SERVICES = "enabled_accessibility_services"
ENABLED = "accessibility_enabled"

# The Diagnosis-mode lines of spike-android Q3b / Q4.
ITEM_1_LINE = (
    '10-22 16:39:31.076  9112  9112 V talkback: SpeechControllerImpl: Speaking fragment '
    'text="Item 1", utteranceId=talkback_31, spans=null, event=type:EVENT_TYPE_ACCESSIBILITY '
    'subtype:TYPE_VIEW_ACCESSIBILITY_FOCUSED displayId:0 time:1413636\n'
)
ROLE_LINE = (
    '10-22 16:39:32.106  9112  9112 V talkback: SpeechControllerImpl: Speaking fragment '
    'text="Button. 1 of 6. In list. 6 items", utteranceId=talkback_31, spans=null\n'
)
NEXT_LINE = ITEM_1_LINE.replace("Item 1", "Item 2")


class FakeClock:
    """Monotonic clock that only moves when the code sleeps."""

    def __init__(self) -> None:
        self.now = 0.0

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


class FakeAdb:
    """In-memory device: settings, the AVD name, a logcat buffer, and TalkBack's bind state.

    TalkBack speaks only after a fresh start (settings turn it on while it is unbound),
    `speak_after_polls` logcat reads later; `None` means it never speaks.
    """

    def __init__(self) -> None:
        self.avd = AVD_NAME
        self.settings: dict[str, str] = {}
        self.logcat = ""
        self.calls: list[list[str]] = []
        self.speak_after_polls: int | None = None
        self.unbind_after_polls = 0
        self.never_unbinds = False
        self.speech = ITEM_1_LINE
        self.bound = False
        self.bound_polls = 0
        self._log_polls = 0
        self._unbind_countdown = 0
        self._speech_pending = False

    def __call__(self, argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        assert argv[:3] == ["adb", "-s", SERIAL]
        self.calls.append(argv[3:])
        return subprocess.CompletedProcess(argv, 0, self._answer(argv[3:]), "")

    def start_bound(self) -> None:
        """Put the device in the resting state: TalkBack on and bound."""
        self.settings.update({SERVICES: TALKBACK_SERVICE, ENABLED: "1"})
        self.bound = True

    def writes(self) -> list[list[str]]:
        """Return every settings put or delete the code issued."""
        verbs = (["shell", "settings", "put"], ["shell", "settings", "delete"])
        return [c for c in self.calls if c[:3] in verbs]

    def _answer(self, args: list[str]) -> str:
        if args == ["emu", "avd", "name"]:
            return f"{self.avd}\nOK\n"
        if args[:4] == ["shell", "settings", "get", "secure"]:
            return self.settings.get(args[4], "null") + "\n"
        if args[:4] == ["shell", "settings", "put", "secure"]:
            self.settings[args[4]] = args[5]
            self._apply_settings()
        elif args[:4] == ["shell", "settings", "delete", "secure"]:
            self.settings.pop(args[4], None)
            self._apply_settings()
        elif args == ["logcat", "-c"]:
            self.logcat = ""
        elif args == ["logcat", "-d"]:
            return self._read_logcat()
        elif args == ["shell", "dumpsys", "accessibility"]:
            return self._dump_accessibility()
        return ""

    def _apply_settings(self) -> None:
        running = self.settings.get(SERVICES) == TALKBACK_SERVICE and self.settings.get(ENABLED) == "1"
        if running and not self.bound:
            self.bound = True
            self._log_polls = 0
            self._speech_pending = True
        elif not running and self.bound:
            self.bound = False
            self._unbind_countdown = self.unbind_after_polls

    def _read_logcat(self) -> str:
        self._log_polls += 1
        due = self.speak_after_polls is not None and self._log_polls >= self.speak_after_polls
        if self._speech_pending and due:
            self.logcat += self.speech
            self._speech_pending = False
        return self.logcat

    def _dump_accessibility(self) -> str:
        self.bound_polls += 1
        still_bound = self.bound or self.never_unbinds or self._unbind_countdown > 0
        self._unbind_countdown = max(0, self._unbind_countdown - 1)
        return "label=TalkBack" if still_bound else "no services"


@pytest.fixture
def clock(monkeypatch: pytest.MonkeyPatch) -> FakeClock:
    fake = FakeClock()
    monkeypatch.setattr(f"{MODULE}.time.monotonic", fake.monotonic)
    monkeypatch.setattr(f"{MODULE}.time.sleep", fake.sleep)
    return fake


@pytest.fixture
def fake_adb(monkeypatch: pytest.MonkeyPatch, clock: FakeClock) -> FakeAdb:
    del clock  # requested for its time patches only
    adb = FakeAdb()
    monkeypatch.setattr(f"{MODULE}.subprocess.run", adb)
    return adb


def test_the_avd_name_has_one_home() -> None:
    assert AVD_NAME == "E2E_TalkBack_API_35"


def test_avd_name_reads_the_first_console_line(fake_adb: FakeAdb) -> None:
    assert avd_name(SERIAL) == AVD_NAME
    assert fake_adb.calls == [["emu", "avd", "name"]]


def test_utterances_from_diagnosis_line() -> None:
    assert utterances(ITEM_1_LINE) == ["Item 1"]


def test_utterances_keep_order_and_every_fragment() -> None:
    assert utterances(ITEM_1_LINE + ROLE_LINE) == ["Item 1", "Button. 1 of 6. In list. 6 items"]


def test_utterances_keep_non_ascii_text() -> None:
    line = ITEM_1_LINE.replace("Item 1", "รายการ 1")

    assert utterances(line) == ["รายการ 1"]


def test_utterances_ignore_lines_without_speech() -> None:
    assert utterances("V talkback: other line\nI x: text=\"nope\"\n") == []


def test_session_waits_first_utterance_before_returning(fake_adb: FakeAdb, clock: FakeClock) -> None:
    fake_adb.speak_after_polls = 3

    with TalkBackSession(SERIAL) as log:
        assert isinstance(log, TalkBackLog)
        assert fake_adb.settings[SERVICES] == TALKBACK_SERVICE
        assert fake_adb.settings[ENABLED] == "1"
        assert clock.now > 0
        assert log.since_mark() == []

        fake_adb.logcat += NEXT_LINE

        assert log.since_mark() == ["Item 2"]


def test_session_refuses_a_shared_avd(fake_adb: FakeAdb) -> None:
    fake_adb.avd = "Pixel_8_API_37"

    with pytest.raises(ValueError, match="Pixel_8_API_37"), TalkBackSession(SERIAL):
        pytest.fail("the body must not run")

    assert fake_adb.writes() == []


def test_session_raises_silent_after_20_seconds_and_restores(fake_adb: FakeAdb, clock: FakeClock) -> None:
    fake_adb.settings[SERVICES] = "com.example/.Other"

    with pytest.raises(TalkBackSilent) as raised, TalkBackSession(SERIAL):
        pytest.fail("the body must not run")

    assert str(raised.value) == "no TalkBack utterance in 20 s: Diagnosis mode off or TalkBack not running"
    assert isinstance(raised.value, RuntimeError)
    assert 20 <= clock.now < 21
    assert fake_adb.settings[SERVICES] == "com.example/.Other"


def test_talkback_session_restores_settings_on_exception(fake_adb: FakeAdb) -> None:
    fake_adb.settings.update({SERVICES: "com.example/.Other", ENABLED: "1"})
    fake_adb.speak_after_polls = 1

    with pytest.raises(RuntimeError, match="boom"), TalkBackSession(SERIAL):
        raise RuntimeError("boom")

    assert fake_adb.settings == {SERVICES: "com.example/.Other", ENABLED: "1"}


def test_session_deletes_settings_that_were_unset(fake_adb: FakeAdb) -> None:
    fake_adb.speak_after_polls = 1

    with TalkBackSession(SERIAL):
        pass

    assert fake_adb.settings == {}


def test_a11y_focused_reads_page_source() -> None:
    source = (
        '<hierarchy><node text="Item 3" a11y-focused="true"/>'
        '<node text="Item 4" a11y-focused="false"/></hierarchy>'
    )

    assert a11y_focused(source) == ["Item 3"]


def test_a11y_focused_falls_back_to_content_desc() -> None:
    source = '<hierarchy><node text="" content-desc="Item 3" a11y-focused="true"/></hierarchy>'

    assert a11y_focused(source) == ["Item 3"]


def test_a11y_focused_skips_a_focused_node_with_no_label() -> None:
    source = '<hierarchy><node text="" content-desc="" a11y-focused="true"/></hierarchy>'

    assert a11y_focused(source) == []


def test_a11y_focused_accepts_the_uiautomator_xml_declaration() -> None:
    source = (
        "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>"
        '<hierarchy><node text="รายการ" a11y-focused="true"/></hierarchy>'
    )

    assert a11y_focused(source) == ["รายการ"]


def test_session_restarts_talkback_that_is_already_on(fake_adb: FakeAdb) -> None:
    fake_adb.start_bound()
    fake_adb.unbind_after_polls = 2
    fake_adb.speak_after_polls = 2

    with TalkBackSession(SERIAL) as log:
        assert fake_adb.bound
        assert fake_adb.bound_polls == 3
        assert log.since_mark() == []

    assert fake_adb.writes().count(["shell", "settings", "put", "secure", ENABLED, "0"]) == 1


def test_session_turns_talkback_off_and_waits_for_unbind_before_turning_it_on(fake_adb: FakeAdb) -> None:
    fake_adb.start_bound()
    fake_adb.unbind_after_polls = 1
    fake_adb.speak_after_polls = 1

    with TalkBackSession(SERIAL):
        pass

    calls = fake_adb.calls
    off = calls.index(["shell", "settings", "put", "secure", ENABLED, "0"])
    delete = calls.index(["shell", "settings", "delete", "secure", SERVICES])
    unbound = [i for i, c in enumerate(calls) if c == ["shell", "dumpsys", "accessibility"]]
    on = calls.index(["shell", "settings", "put", "secure", SERVICES, TALKBACK_SERVICE])
    assert off < delete < unbound[0] < unbound[-1] < on


def test_session_restores_talkback_that_was_on(fake_adb: FakeAdb) -> None:
    fake_adb.start_bound()
    fake_adb.speak_after_polls = 1

    with TalkBackSession(SERIAL):
        pass

    assert fake_adb.settings == {SERVICES: TALKBACK_SERVICE, ENABLED: "1"}


def test_session_raises_stuck_when_talkback_never_unbinds_and_restores(
    fake_adb: FakeAdb, clock: FakeClock
) -> None:
    fake_adb.start_bound()
    fake_adb.never_unbinds = True

    with pytest.raises(TalkBackStuck, match="still bound") as raised, TalkBackSession(SERIAL):
        pytest.fail("the body must not run")

    assert isinstance(raised.value, RuntimeError)
    assert 10 <= clock.now < 11
    assert fake_adb.settings == {SERVICES: TALKBACK_SERVICE, ENABLED: "1"}
