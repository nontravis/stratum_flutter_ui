"""Unit tests for the host VoiceOver helper, on a scripted runner (no real VoiceOver)."""

from __future__ import annotations

import subprocess
from typing import Any

import pytest

from stratum_e2e.macos.host_voiceover import (
    POLL_INTERVAL_SECONDS,
    READY_TIMEOUT_SECONDS,
    RUN_TIMEOUT_SECONDS,
    HostVoiceOver,
    HostVoiceOverAlreadyRunning,
    HostVoiceOverError,
    HostVoiceOverNotReady,
    HostVoiceOverNotStopped,
    osascript_args,
)

START = 'tell application "VoiceOver" to launch'
STOP = 'tell application "VoiceOver" to quit'
MOVE_NEXT = 'tell application "VoiceOver" to tell vo cursor to move right'
LAST_PHRASE = 'tell application "VoiceOver" to return content of last phrase'
PGREP = ["pgrep", "-x", "VoiceOver"]


class FakeClock:
    """Clock stub: `sleep` advances `now`, so a bounded wait ends without real time."""

    def __init__(self) -> None:
        self.now = 0.0
        self.sleeps: list[float] = []

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.now += seconds

    def read(self) -> float:
        return self.now


class FakeRunner:
    """Runner stub for osascript and pgrep.

    `outputs` answers an osascript script's stdout. `failing` maps a script to the stderr of
    an exit-1 run. `fail_first` makes a script fail that many times before it works. `raises`
    makes a script raise. `pgrep` feeds `pgrep -x VoiceOver` stdout in order, the last answer
    repeating.
    """

    def __init__(
        self,
        outputs: dict[str, str | None] | None = None,
        failing: dict[str, str] | None = None,
        fail_first: dict[str, int] | None = None,
        raises: dict[str, BaseException] | None = None,
        pgrep: list[str] | None = None,
    ) -> None:
        self.outputs = outputs or {}
        self.failing = failing or {}
        self.fail_first = dict(fail_first or {})
        self.raises = raises or {}
        self.pgrep = list(pgrep or [""])
        self.calls: list[list[str]] = []
        self.kwargs: list[dict[str, Any]] = []

    def __call__(self, args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        self.calls.append(args)
        self.kwargs.append(kwargs)
        if args == PGREP:
            answer = self.pgrep.pop(0) if len(self.pgrep) > 1 else self.pgrep[0]
            return subprocess.CompletedProcess(args, 0 if answer else 1, stdout=answer, stderr="")
        script = args[-1]
        if script in self.raises:
            raise self.raises[script]
        if self.fail_first.get(script, 0) > 0:
            self.fail_first[script] -= 1
            return subprocess.CompletedProcess(args, 1, stdout="", stderr="not up yet")
        if script in self.failing:
            return subprocess.CompletedProcess(args, 1, stdout="", stderr=self.failing[script])
        return subprocess.CompletedProcess(
            args,
            0,
            # None models a runner whose stdout is missing.
            stdout=self.outputs.get(script, ""),  # type: ignore[arg-type]
            stderr="",
        )

    def scripts(self) -> list[str]:
        """Return the osascript scripts run, in order."""
        return [args[-1] for args in self.calls if args[0] == "osascript"]


def make(runner: FakeRunner, clock: FakeClock | None = None) -> HostVoiceOver:
    clock = clock or FakeClock()
    return HostVoiceOver(runner, sleep=clock.sleep, clock=clock.read)


def test_osascript_args_pass_the_script_as_one_dash_e_argument() -> None:
    assert osascript_args("return 1") == ["osascript", "-e", "return 1"]


def test_enter_checks_not_running_starts_waits_ready_and_exit_stops() -> None:
    runner = FakeRunner()

    with make(runner):
        pass

    assert runner.calls == [
        PGREP,
        osascript_args(START),
        osascript_args(LAST_PHRASE),
        osascript_args(STOP),
        PGREP,
    ]


def test_stop_runs_on_exception() -> None:
    runner = FakeRunner()

    with pytest.raises(KeyError):
        with make(runner):
            raise KeyError("boom")

    assert runner.scripts()[-1] == STOP


def test_stop_runs_when_a_call_inside_fails() -> None:
    runner = FakeRunner(failing={MOVE_NEXT: "refused"})

    with pytest.raises(HostVoiceOverError):
        with make(runner) as voiceover:
            voiceover.move_next()

    assert runner.scripts()[-1] == STOP


def test_start_failure_surfaces_and_stop_still_runs() -> None:
    runner = FakeRunner(failing={START: "not allowed"})

    with pytest.raises(HostVoiceOverError, match="not allowed"):
        with make(runner):
            pytest.fail("body must not run when start fails")

    assert runner.scripts() == [START, STOP]


def test_start_failure_wins_over_a_failing_stop() -> None:
    runner = FakeRunner(failing={START: "start refused", STOP: "stop refused"})

    with pytest.raises(HostVoiceOverError, match="start refused"):
        with make(runner):
            pytest.fail("body must not run when start fails")


def test_enter_refuses_a_voiceover_that_already_runs_and_quits_nothing() -> None:
    runner = FakeRunner(pgrep=["4242\n"])

    with pytest.raises(HostVoiceOverAlreadyRunning, match="never takes over"):
        with make(runner):
            pytest.fail("body must not run over a running VoiceOver")

    assert runner.calls == [PGREP]


def test_enter_waits_until_voiceover_answers() -> None:
    runner = FakeRunner(fail_first={LAST_PHRASE: 3})
    clock = FakeClock()

    with make(runner, clock):
        pass

    assert runner.scripts().count(LAST_PHRASE) == 4
    assert clock.sleeps == [POLL_INTERVAL_SECONDS] * 3


def test_enter_times_out_with_a_readiness_error_and_stops() -> None:
    runner = FakeRunner(fail_first={LAST_PHRASE: 10_000})
    clock = FakeClock()

    with pytest.raises(HostVoiceOverNotReady, match="not up yet") as raised:
        with make(runner, clock):
            pytest.fail("body must not run when VoiceOver never answers")

    assert type(raised.value) is HostVoiceOverNotReady
    assert runner.scripts()[-1] == STOP
    assert READY_TIMEOUT_SECONDS <= clock.now <= READY_TIMEOUT_SECONDS + POLL_INTERVAL_SECONDS


def test_every_runner_call_carries_a_timeout_and_utf8() -> None:
    runner = FakeRunner()

    with make(runner) as voiceover:
        voiceover.move_next()
        voiceover.last_phrase()

    assert runner.kwargs
    for kwargs in runner.kwargs:
        assert kwargs["timeout"] == RUN_TIMEOUT_SECONDS
        assert kwargs["encoding"] == "utf-8"


def test_a_timed_out_call_becomes_the_typed_error_and_stop_still_runs() -> None:
    expired = subprocess.TimeoutExpired(cmd="osascript", timeout=RUN_TIMEOUT_SECONDS)
    runner = FakeRunner(raises={MOVE_NEXT: expired})

    with pytest.raises(HostVoiceOverError, match="timed out"):
        with make(runner) as voiceover:
            voiceover.move_next()

    assert runner.scripts()[-1] == STOP


def test_a_missing_osascript_becomes_the_typed_error_and_start_failure_surfaces() -> None:
    missing = FileNotFoundError("osascript")
    runner = FakeRunner(raises={START: missing, STOP: missing})

    with pytest.raises(HostVoiceOverError, match="osascript not found"):
        with make(runner):
            pytest.fail("body must not run when start fails")


def test_a_timed_out_stop_after_a_failed_start_does_not_hide_the_start_error() -> None:
    expired = subprocess.TimeoutExpired(cmd="osascript", timeout=RUN_TIMEOUT_SECONDS)
    runner = FakeRunner(failing={START: "start refused"}, raises={STOP: expired})

    with pytest.raises(HostVoiceOverError, match="start refused"):
        with make(runner):
            pytest.fail("body must not run when start fails")


def test_a_stop_failure_after_a_clean_body_raises() -> None:
    runner = FakeRunner(failing={STOP: "stop refused"})

    with pytest.raises(HostVoiceOverError, match="stop refused"):
        with make(runner):
            pass


def test_the_body_exception_wins_over_a_stop_failure() -> None:
    runner = FakeRunner(failing={STOP: "stop refused"})

    with pytest.raises(KeyError):
        with make(runner):
            raise KeyError("boom")


def test_exit_waits_until_voiceover_is_gone() -> None:
    runner = FakeRunner(pgrep=["", "99", "99", ""])
    clock = FakeClock()

    with make(runner, clock):
        pass

    assert runner.calls.count(PGREP) == 4
    assert clock.sleeps == [POLL_INTERVAL_SECONDS] * 2


def test_exit_raises_when_voiceover_still_runs_after_quit() -> None:
    runner = FakeRunner(pgrep=["", "99"])

    with pytest.raises(HostVoiceOverNotStopped):
        with make(runner):
            pass


def test_the_body_exception_wins_over_a_voiceover_that_will_not_stop() -> None:
    runner = FakeRunner(pgrep=["", "99"])

    with pytest.raises(KeyError):
        with make(runner):
            raise KeyError("boom")


def test_move_next_moves_the_vo_cursor_right() -> None:
    runner = FakeRunner()

    with make(runner) as voiceover:
        assert voiceover.move_next() is None

    assert MOVE_NEXT in runner.scripts()


def test_last_phrase_strips_stdout() -> None:
    runner = FakeRunner(outputs={LAST_PHRASE: "  Save button  \n"})

    with make(runner) as voiceover:
        assert voiceover.last_phrase() == "Save button"


@pytest.mark.parametrize("stdout", ["missing value\n", "\n", "", None])
def test_last_phrase_is_empty_when_voiceover_has_spoken_nothing(stdout: str | None) -> None:
    runner = FakeRunner(outputs={LAST_PHRASE: stdout})

    with make(runner) as voiceover:
        assert voiceover.last_phrase() == ""


def test_failure_names_the_voiceover_setting_and_carries_stderr() -> None:
    runner = FakeRunner(failing={MOVE_NEXT: "execution error: not authorized"})

    with pytest.raises(HostVoiceOverError) as raised:
        with make(runner) as voiceover:
            voiceover.move_next()

    message = str(raised.value)
    assert "Allow VoiceOver to be controlled with AppleScript" in message
    assert "execution error: not authorized" in message
    assert "Automation" not in message


def test_error_1743_names_the_automation_privacy_setting() -> None:
    stderr = "execution error: Not authorized to send Apple events to VoiceOver. (-1743)"
    runner = FakeRunner(failing={MOVE_NEXT: stderr})

    with pytest.raises(HostVoiceOverError) as raised:
        with make(runner) as voiceover:
            voiceover.move_next()

    message = str(raised.value)
    assert "System Settings > Privacy & Security > Automation" in message
    assert "-1743" in message
