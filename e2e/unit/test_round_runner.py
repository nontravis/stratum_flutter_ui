"""Unit tests for the command Runner and the FakeRunner every later round test uses."""

from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path

import pytest

from stratum_e2e.round.runner import Completed, SubprocessRunner
from unit.round_fakes import FakeRunner


def _done(stdout: str = "", status: int = 0) -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr="", timed_out=False)


def test_subprocess_runner_returns_status_and_stdout() -> None:
    done = SubprocessRunner().run(["sh", "-c", "echo hi; exit 3"])
    assert done.status == 3
    assert done.stdout == "hi\n"
    assert done.argv == ("sh", "-c", "echo hi; exit 3")
    assert done.timed_out is False


def test_subprocess_runner_separates_stderr() -> None:
    done = SubprocessRunner().run(["sh", "-c", "echo out; echo err >&2"])
    assert (done.stdout, done.stderr) == ("out\n", "err\n")


def test_subprocess_runner_timeout_sets_timed_out() -> None:
    done = SubprocessRunner().run(["sleep", "5"], timeout_s=0.2)
    assert done.timed_out is True
    assert done.status != 0


def test_subprocess_runner_timeout_kills_the_child_group() -> None:
    done = SubprocessRunner().run(["sh", "-c", "sleep 5 & wait"], timeout_s=0.2)
    assert done.timed_out is True


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def test_subprocess_runner_interrupted_run_kills_and_reaps_the_child_group(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A KeyboardInterrupt (SIGTERM in a round) inside `communicate` ends the child and its children, then re-raises."""
    pid_file = tmp_path / "grandchild.pid"
    started: list[int] = []
    real_communicate = subprocess.Popen.communicate

    def interrupted(self: subprocess.Popen[str], *args: object, **kwargs: object) -> tuple[str, str]:
        if not started:
            started.append(self.pid)
            deadline = time.monotonic() + 5
            while not pid_file.exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            raise KeyboardInterrupt
        return real_communicate(self, *args, **kwargs)  # type: ignore[arg-type]

    monkeypatch.setattr(subprocess.Popen, "communicate", interrupted)
    with pytest.raises(KeyboardInterrupt):
        SubprocessRunner().run(["sh", "-c", f"sleep 30 & echo $! > '{pid_file}'; wait"])
    grandchild = int(pid_file.read_text().strip())
    assert not _alive(started[0])
    deadline = time.monotonic() + 5
    while _alive(grandchild) and time.monotonic() < deadline:
        time.sleep(0.05)
    assert not _alive(grandchild)


def test_subprocess_runner_writes_output_to_the_log(tmp_path: Path) -> None:
    log = tmp_path / "run.log"
    SubprocessRunner().run(["sh", "-c", "echo hi; echo err >&2"], log=log)
    text = log.read_text(encoding="utf-8")
    assert "hi" in text
    assert "err" in text


def test_subprocess_runner_uses_cwd_and_overlays_env(tmp_path: Path) -> None:
    done = SubprocessRunner().run(["sh", "-c", 'echo "$PWD:$ROUND_PROBE"'], cwd=tmp_path, env={"ROUND_PROBE": "x"})
    assert done.stdout.strip() == f"{tmp_path.resolve()}:x"


def test_subprocess_runner_missing_binary_is_a_127_result() -> None:
    done = SubprocessRunner().run(["definitely-not-a-binary-xyz"])
    assert done.status == 127
    assert "definitely-not-a-binary-xyz" in done.stderr


def test_subprocess_runner_spawn_logs_and_returns_a_process(tmp_path: Path) -> None:
    log = tmp_path / "spawn.log"
    process = SubprocessRunner().spawn(["sh", "-c", "echo spawned"], log=log)
    assert process.wait(timeout=10) == 0
    assert "spawned" in log.read_text(encoding="utf-8")


def test_fake_runner_answers_by_argv_prefix() -> None:
    fake = FakeRunner([(("adb", "devices"), _done("List of devices\n"))])
    done = fake.run(["adb", "devices", "-l"])
    assert done.stdout == "List of devices\n"
    assert fake.calls == [("adb", "devices", "-l")]


def test_fake_runner_raises_naming_an_unscripted_argv() -> None:
    fake = FakeRunner([(("adb", "devices"), _done())])
    with pytest.raises(AssertionError, match="emulator -list-avds"):
        fake.run(["emulator", "-list-avds"])


def test_fake_runner_consumes_entries_in_order() -> None:
    fake = FakeRunner([
        (("adb", "get-state"), _done("offline")),
        (("adb", "get-state"), _done("device")),
    ])
    assert fake.run(["adb", "get-state"]).stdout == "offline"
    assert fake.run(["adb", "get-state"]).stdout == "device"
    with pytest.raises(AssertionError, match="adb get-state"):
        fake.run(["adb", "get-state"])


def test_fake_runner_answers_the_first_unconsumed_matching_prefix() -> None:
    fake = FakeRunner([
        (("adb",), _done("generic")),
        (("adb", "devices"), _done("specific")),
    ])
    assert fake.run(["adb", "devices"]).stdout == "generic"
    assert fake.run(["adb", "devices"]).stdout == "specific"


def test_fake_runner_records_a_call_that_raises() -> None:
    fake = FakeRunner([])
    with pytest.raises(AssertionError):
        fake.run(["nope"])
    assert fake.calls == [("nope",)]


def test_fake_runner_spawn_returns_pid_poll_kill(tmp_path: Path) -> None:
    fake = FakeRunner([])
    first = fake.spawn(["emulator", "-avd", "x"], log=tmp_path / "e.log")
    second = fake.spawn(["emulator", "-avd", "y"], log=tmp_path / "e2.log")
    assert isinstance(first.pid, int)
    assert second.pid == first.pid + 1
    assert first.poll() is None
    first.kill()
    assert first.poll() is not None
    assert second.poll() is None
    assert ("emulator", "-avd", "x") in fake.calls
