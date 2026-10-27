"""Unit tests for the adb dump captures (M3-T19): the argv shape, and no `grep -q`."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from stratum_e2e.android.dumps import activities_dump, sdk_level, touch_mode, window_dump

SERIAL = "emulator-5554"
API28_WINDOW_DUMP = Path(__file__).resolve().parent / "fixtures" / "dumps" / "api28_dumpsys_window.txt"


class FakeAdb:
    """Stand-in for subprocess.run recording every argv and answering by table."""

    def __init__(self, answers: dict[tuple[str, ...], str]) -> None:
        self.answers = answers
        self.calls: list[list[str]] = []

    def __call__(self, argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        assert argv[:3] == ["adb", "-s", SERIAL]
        self.calls.append(argv[:])
        key = tuple(argv[3:])
        if key not in self.answers:
            raise AssertionError(f"unexpected adb argv tail: {key}")
        return subprocess.CompletedProcess(argv, 0, self.answers[key], "")


@pytest.fixture
def fake_adb(monkeypatch: pytest.MonkeyPatch) -> FakeAdb:
    adb = FakeAdb(
        {
            ("shell", "-n", "dumpsys", "window"): "WINDOW MANAGER WINDOWS",
            ("shell", "-n", "dumpsys", "activity", "activities"): "Activities",
            ("shell", "-n", "getprop", "ro.build.version.sdk"): "35\n",
        }
    )
    monkeypatch.setattr("stratum_e2e.android.dumps.subprocess.run", adb)
    return adb


def test_window_dump_runs_one_shell_dumpsys_window(fake_adb: FakeAdb) -> None:
    assert window_dump(SERIAL) == "WINDOW MANAGER WINDOWS"
    assert fake_adb.calls == [["adb", "-s", SERIAL, "shell", "-n", "dumpsys", "window"]]


def test_activities_dump_reads_activities_never_recents(fake_adb: FakeAdb) -> None:
    assert activities_dump(SERIAL) == "Activities"
    assert fake_adb.calls == [
        ["adb", "-s", SERIAL, "shell", "-n", "dumpsys", "activity", "activities"],
    ]


def test_sdk_level_parses_the_prop(fake_adb: FakeAdb) -> None:
    assert sdk_level(SERIAL) == 35
    assert fake_adb.calls == [
        ["adb", "-s", SERIAL, "shell", "-n", "getprop", "ro.build.version.sdk"],
    ]


def test_no_call_pipes_into_grep(fake_adb: FakeAdb) -> None:
    window_dump(SERIAL)
    activities_dump(SERIAL)
    sdk_level(SERIAL)
    for argv in fake_adb.calls:
        assert "grep" not in argv
        assert "-q" not in argv


def test_sdk_level_rejects_a_non_numeric_prop(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "stratum_e2e.android.dumps.subprocess.run",
        FakeAdb({("shell", "-n", "getprop", "ro.build.version.sdk"): "O\n"}),
    )
    with pytest.raises(ValueError, match="not a level"):
        sdk_level(SERIAL)


INPUT_DUMP = "  Configuration:\n    KeyRepeatDelay: 50ms\n  TouchModePerDisplay:\n{displays}\n  Other: 1\n"


def _input_dump(*displays: str) -> str:
    return INPUT_DUMP.format(displays="\n".join(f"    {line}" for line in displays))


@pytest.mark.parametrize(
    ("dump", "expected"),
    [
        (_input_dump("Display: 0 TouchMode: 1"), True),
        (_input_dump("Display: 0 TouchMode: 0"), False),
        (_input_dump("Display: 2 TouchMode: 1", "Display: 0 TouchMode: 0"), False),
    ],
)
def test_touch_mode_reads_display_zero_of_dumpsys_input(
    dump: str, expected: bool, monkeypatch: pytest.MonkeyPatch
) -> None:
    adb = FakeAdb({("shell", "-n", "dumpsys", "input"): dump})
    monkeypatch.setattr("stratum_e2e.android.dumps.subprocess.run", adb)

    assert touch_mode(SERIAL) is expected
    assert adb.calls == [["adb", "-s", SERIAL, "shell", "-n", "dumpsys", "input"]]


TOP_DUMP = (
    "  ACTIVITY launcher\n    mHasWindowFocus=false\n    mInTouchMode=true\n"
    "  ACTIVITY app\n    mHasWindowFocus=true\n    mTraversalScheduled=false\n"
    "    mInTouchMode={state}\n"
)
NO_ENTRY = "  Configuration:\n    KeyRepeatDelay: 50ms\n"


@pytest.mark.parametrize(("state", "expected"), [("true", True), ("false", False)])
def test_touch_mode_falls_back_to_the_top_activity_without_the_input_entry(
    state: str, expected: bool, monkeypatch: pytest.MonkeyPatch
) -> None:
    adb = FakeAdb(
        {
            ("shell", "-n", "dumpsys", "input"): NO_ENTRY,
            ("shell", "-n", "dumpsys", "activity", "top"): TOP_DUMP.format(state=state),
        }
    )
    monkeypatch.setattr("stratum_e2e.android.dumps.subprocess.run", adb)

    assert touch_mode(SERIAL) is expected
    assert [call[-1] for call in adb.calls] == ["input", "top"]


# API 28 `dumpsys activity top`: the app's ViewRoot block prints neither mHasWindowFocus nor mInTouchMode.
API28_TOP_DUMP = "  ACTIVITY app\n    ViewRoot:\n      mAdded=true\n      mIsAmbientMode=false\n"


@pytest.mark.parametrize(("state", "expected"), [("true", True), ("false", False)])
def test_touch_mode_falls_back_to_the_window_manager_line_on_api_28(
    state: str, expected: bool, monkeypatch: pytest.MonkeyPatch
) -> None:
    window = API28_WINDOW_DUMP.read_text().replace("mInTouchMode=true", f"mInTouchMode={state}")
    adb = FakeAdb(
        {
            ("shell", "-n", "dumpsys", "input"): NO_ENTRY,
            ("shell", "-n", "dumpsys", "activity", "top"): API28_TOP_DUMP,
            ("shell", "-n", "dumpsys", "window"): window,
        }
    )
    monkeypatch.setattr("stratum_e2e.android.dumps.subprocess.run", adb)

    assert touch_mode(SERIAL) is expected
    assert [call[-1] for call in adb.calls] == ["input", "top", "window"]


@pytest.mark.parametrize("dump", ["", NO_ENTRY, _input_dump("Display: 2 TouchMode: 1")])
def test_touch_mode_rejects_dumps_without_a_display_zero_entry(
    dump: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    adb = FakeAdb(
        {
            ("shell", "-n", "dumpsys", "input"): dump,
            ("shell", "-n", "dumpsys", "activity", "top"): "  no view root here\n",
            # Not at a line start: only the anchored window-manager line counts.
            ("shell", "-n", "dumpsys", "window"): "  other mInTouchMode=true\n  mInTouchMode=maybe\n",
        }
    )
    monkeypatch.setattr("stratum_e2e.android.dumps.subprocess.run", adb)

    with pytest.raises(ValueError, match="no touch mode"):
        touch_mode(SERIAL)
