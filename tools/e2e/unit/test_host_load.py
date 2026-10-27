"""Unit tests for the host-load snapshot: what it records, how a failed probe degrades, and when the hooks write."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from stratum_e2e.host_load import (
    BASELINE_NAME,
    SNAPSHOT_NAME,
    snapshot_lines,
    write_baseline,
    write_failure_snapshot,
)
from stratum_e2e.paths import E2E_ROOT
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner
from unit.sandbox import build_sandbox, run_sandbox, suite_dir

MEMORY_OUT = """\
The system has 34359738368 (2097152 pages with a page size of 16384).

System-wide memory free percentage: 45%
"""

LOADAVG_OUT = "{ 7.30 8.97 12.10 }\n"
NCPU_OUT = "12\n"
QEMU_PGREP = "14636 qemu-system-aarch64\n"
DOCKER_PS = "linux_flutter Running (up 2 hours)\n"
APPNAP_LOG = (
    "2026-10-26 16:36:33.437 Df [anon<qemu-system-aarch64>(501):14636] Set darwin role to: UserInteractiveFocal\n"
    "2026-10-26 16:37:28.136 Df [anon<qemu-system-aarch64>(501):14636] AppNap enabled:Y active:Y socket:Y disk:Y "
    "priority:Y cpu:Y timer:Tier5>\n"
)


def _ok(argv: tuple[str, ...], stdout: str = "") -> tuple[tuple[str, ...], Completed]:
    return argv, Completed(argv=argv, status=0, stdout=stdout, stderr="", timed_out=False)


def _timeout(argv: tuple[str, ...]) -> tuple[tuple[str, ...], Completed]:
    return argv, Completed(
        argv=argv, status=-9, stdout="", stderr="killed by timeout", timed_out=True
    )


class _Clock:
    """One frozen moment, so a snapshot's time header is stable in a test."""

    def now(self) -> str:
        return "2026-10-26T16:39:52+07:00"


def _full_script() -> list[tuple[tuple[str, ...], Completed]]:
    return [
        _ok(("memory_pressure",), MEMORY_OUT),
        _ok(("sysctl", "-n", "vm.loadavg"), LOADAVG_OUT),
        _ok(("sysctl", "-n", "hw.ncpu"), NCPU_OUT),
        _ok(("pgrep", "-l", "qemu-system"), QEMU_PGREP),
        _ok(("docker", "ps", "--format", "{{.Names}} {{.Status}}"), DOCKER_PS),
        _ok(("log", "show"), APPNAP_LOG),
    ]


def test_snapshot_holds_every_field() -> None:
    """A full snapshot records time, free memory, load average and CPU count, emulators, docker, and App Nap lines."""
    runner = FakeRunner(_full_script())
    lines = snapshot_lines(runner, now=_Clock().now())
    text = "\n".join(lines)
    assert "host load at 2026-10-26T16:39:52+07:00" in text
    assert "memory free: 45%" in text
    assert "loadavg: { 7.30 8.97 12.10 }" in text
    assert "cpu count: 12" in text
    assert "qemu emulators:" in text
    assert "14636 qemu-system-aarch64" in text
    assert "docker containers:" in text
    assert "linux_flutter Running (up 2 hours)" in text
    assert "14636 App Nap / role:" in text
    assert "AppNap enabled:Y active:Y" in text
    assert "Set darwin role to: UserInteractiveFocal" in text


def test_a_probe_that_times_out_writes_its_error_and_never_raises() -> None:
    """A probe the timeout kills records the failure in place of its field; the snapshot still returns."""
    runner = FakeRunner(
        [
            _timeout(("memory_pressure",)),
            _ok(("sysctl", "-n", "vm.loadavg"), LOADAVG_OUT),
            _ok(("sysctl", "-n", "hw.ncpu"), NCPU_OUT),
            _timeout(("pgrep", "-l", "qemu-system")),
            _ok(("docker", "ps", "--format", "{{.Names}} {{.Status}}"), ""),
            _timeout(("log", "show")),
        ]
    )
    text = "\n".join(snapshot_lines(runner, now=_Clock().now()))
    assert "memory free: probe failed" in text
    assert "timeout" in text
    assert "memory free percentage" not in text
    assert "loadavg: { 7.30 8.97 12.10 }" in text
    assert "qemu emulators: probe failed" in text
    assert "docker containers: none running" in text


def test_no_docker_binary_writes_missing_docker_and_never_raises() -> None:
    """A missing docker binary records itself and its exit-127 text; the snapshot still returns."""
    missing = Completed(
        argv=("docker", "ps", "--format", "{{.Names}} {{.Status}}"),
        status=127,
        stdout="",
        stderr="docker: command not found\n",
        timed_out=False,
    )
    runner = FakeRunner(
        [
            _ok(("memory_pressure",), MEMORY_OUT),
            _ok(("sysctl", "-n", "vm.loadavg"), LOADAVG_OUT),
            _ok(("sysctl", "-n", "hw.ncpu"), NCPU_OUT),
            _ok(("pgrep", "-l", "qemu-system"), ""),
            (("docker", "ps", "--format", "{{.Names}} {{.Status}}"), missing),
            _ok(("log", "show"), ""),
        ]
    )
    text = "\n".join(snapshot_lines(runner, now=_Clock().now()))
    assert "docker containers: none (docker: command not found)" in text
    assert "qemu emulators: none running" in text


def test_a_probe_that_raises_never_escapes() -> None:
    """A runner exception in one probe records the error and the rest still runs."""

    class _Raising(FakeRunner):
        def run(self, argv, **kwargs):  # type: ignore[no-untyped-def]
            if tuple(argv)[:1] == ("memory_pressure",):
                raise OSError("host probe exploded")
            return super().run(argv, **kwargs)

    runner = _Raising(
        [
            _ok(("sysctl", "-n", "vm.loadavg"), LOADAVG_OUT),
            _ok(("sysctl", "-n", "hw.ncpu"), NCPU_OUT),
            _ok(("pgrep", "-l", "qemu-system"), ""),
            _ok(("docker", "ps", "--format", "{{.Names}} {{.Status}}"), ""),
        ]
    )
    text = "\n".join(snapshot_lines(runner, now=_Clock().now()))
    assert "memory free: probe failed (OSError: host probe exploded)" in text
    assert "cpu count: 12" in text


TESTS_DIR_SOURCE = """\
import pytest


@pytest.mark.macos
def test_passing(): pass


@pytest.mark.macos
def test_failing():
    assert False, "boom"


@pytest.fixture
def broken():
    raise RuntimeError("setup exploded")


@pytest.mark.macos
def test_setup_fails(broken): pass
"""


HOST_TARGETS_TOML = """\
[apps.test_app]
folder = "test_app"
android_id = "dev.stratum.stratum_ui_test_app"
apple_id = "dev.stratum.stratumUiTestApp"

[targets.host_fake]
platform = "macos"

[lane]
run_timeout_minutes = 20
boot_settle_timeout_seconds = 300
heavy_processes = []
lane_wait_minutes = 30
boot_timeout_minutes = 5

[modes.fast]
targets = ["host_fake"]
repeat = 1
"""


def _make_tree(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> Path:
    """The repo-shaped sandbox with a fake host-load backend plugin; no test touches the OS."""
    root = build_sandbox(pytester, monkeypatch, plugin="round_fake_host")
    (suite_dir(pytester) / "targets.toml").write_text(HOST_TARGETS_TOML)
    fake = ROUND_FAKE_SOURCE.replace("from unit.round_fakes import FakeRunner", "from round_fakes import FakeRunner")
    (root / "round_fake_host.py").write_text(fake)
    shutil.copy(E2E_ROOT / "unit" / "round_fakes.py", root / "round_fakes.py")
    (suite_dir(pytester) / "test_host.py").write_text(TESTS_DIR_SOURCE)
    return root


ROUND_FAKE_SOURCE = '''\
"""Fake round backends for the host-load hooks: a host target, a FakeRunner for the probes, no boot."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

import pytest

import stratum_e2e.round.bring_up as bring_up
from stratum_e2e.host_load import probe_runner
from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.state import Backends
from unit.round_fakes import FakeRunner

NOW = datetime(2026, 10, 24, 1, 2, 3, tzinfo=UTC)


class _ProbeRunner(FakeRunner):
    """Answers every host-load probe with one fixed line; anything else passes."""

    def run(self, argv, *, timeout_s=None, cwd=None, env=None, log=None):
        call = tuple(str(arg) for arg in argv)
        answers = {
            ("memory_pressure",): "System-wide memory free percentage: 61%\\n",
            ("sysctl", "-n", "vm.loadavg"): "{ 1.00 2.00 3.00 }\\n",
            ("sysctl", "-n", "hw.ncpu"): "10\\n",
            ("pgrep", "-l", "qemu-system"): "",
            ("docker", "ps", "--format", "{{.Names}} {{.Status}}"): "",
            ("log", "show"): "",
        }
        for prefix, stdout in answers.items():
            if call[: len(prefix)] == prefix:
                from stratum_e2e.round.runner import Completed

                status = 1 if call[0] == "pgrep" else 0
                return Completed(call, status, stdout, "", False)
        if call[0] == "screencapture":
            from pathlib import Path as _P

            if call[-1].endswith(".partial"):
                _P(call[-1]).write_bytes(b"png")
            return type(
                "C",
                (),
                {"argv": call, "status": 0, "stdout": "", "stderr": "", "timed_out": False},
            )()
        return super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)


class _HostBooter:
    def is_running(self, target):
        return False

    def boot(self, target, log=None, device_log=None):
        return BootRecord(target=target.name, platform=target.platform, device_id="mac", reused=False)

    def shutdown(self, record):
        pass


@pytest.fixture(scope="session")
def round_backends():
    runner = _ProbeRunner(
        [
            (("ioreg", "-n", "Root"), type("C", (), {"argv": (), "status": 0, "stdout": "", "stderr": "", "timed_out": False})()),
        ]
    )
    probe_runner_orig = probe_runner
    import stratum_e2e.host_load as host_load

    host_load.probe_runner = lambda: runner
    yield Backends(
        runner=runner,
        booter_for=lambda target: _HostBooter(),
        resolve=lambda *a, **k: None,
        build=lambda *a, **k: None,
        run_plan=lambda *a, **k: None,
        memory_reasons=lambda: [],
        now=lambda: NOW,
        port_dir=Path("."),
        sleep=lambda seconds: None,
    )
    host_load.probe_runner = probe_runner_orig
'''


def test_hooks_write_only_on_failure(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    """The baseline lands in the round's target folder; a failed call or setup writes host_load.txt; a pass writes
    nothing."""
    _make_tree(pytester, monkeypatch)
    rounds = pytester.path / "rounds"
    monkeypatch.setenv("STRATUM_E2E_ROUNDS_DIR", str(rounds))
    monkeypatch.setenv("STRATUM_E2E_LANE_DIR", str(pytester.path / "lanes"))
    result = run_sandbox(pytester, "e2e", "-p", "no:cacheprovider", "--target", "host_fake", "-p", "no:randomly")
    result.assert_outcomes(passed=1, failed=1, errors=1)
    stamp_dirs = sorted(rounds.iterdir())
    assert len(stamp_dirs) == 1
    baseline = list(stamp_dirs[0].rglob(BASELINE_NAME))
    assert len(baseline) == 1
    assert "host load at" in baseline[0].read_text()
    failures = sorted(stamp_dirs[0].rglob(SNAPSHOT_NAME))
    assert len(failures) == 2
    assert all("host load at" in path.read_text() for path in failures)


def test_first_item_of_a_target_writes_the_baseline(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    """A round whose target runs exactly one item still writes the baseline.

    The write must not depend on a later item reaching the hook: `round_target`'s bring-up
    creates the round dir during the setup phase, after every `pytest_runtest_setup` hook ran,
    so a hook that reads the dir before the fixtures is up sees none and never writes (the
    `-k` smoke round of fix 1)."""
    _make_tree(pytester, monkeypatch)
    rounds = pytester.path / "rounds"
    monkeypatch.setenv("STRATUM_E2E_ROUNDS_DIR", str(rounds))
    monkeypatch.setenv("STRATUM_E2E_LANE_DIR", str(pytester.path / "lanes"))
    result = run_sandbox(
        pytester, "e2e", "-p", "no:cacheprovider", "--target", "host_fake", "-p", "no:randomly", "-k", "test_passing"
    )
    result.assert_outcomes(passed=1, deselected=2)
    baseline = list(rounds.rglob(BASELINE_NAME))
    assert len(baseline) == 1
    assert "host load at" in baseline[0].read_text()
