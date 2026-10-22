"""Unit tests for the adb dump captures (M3-T19): the argv shape, and no `grep -q`."""

from __future__ import annotations

import subprocess

import pytest

from stratum_e2e.android.dumps import activities_dump, sdk_level, window_dump

SERIAL = "emulator-5554"


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
