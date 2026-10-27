"""One snapshot of the Mac's load, so a failure under a slow host reads as one (owner ruling 2026-10-26).

The snapshot records only; the round never waits, skips, retries, or stretches a timeout because of it
(the RCA of the M10 gate reorder failures, `rca-m10-gate-reorder.detail.md`). Every probe is bounded by a
timeout; a probe that fails or times out writes its error text and never raises, so a snapshot can never
fail a test.
"""

from __future__ import annotations

import datetime as _dt
import re
from collections.abc import Sequence
from pathlib import Path
from typing import Final

from stratum_e2e.round.runner import Completed, Runner

BASELINE_NAME: Final = "host_load.baseline.txt"
SNAPSHOT_NAME: Final = "host_load.txt"

# The unified-log window that covers an App Nap edge around a failure; the RCA's command.
_LOG_WINDOW: Final = "15m"
_LOG_PREDICATE: Final = 'process == "runningboardd"'
# App Nap and darwin-role lines, the two runningboardd writes the RCA read back.
_LOG_GREP: Final = "AppNap|Set darwin role"
_PROBE_TIMEOUT_S: Final = 10.0
# `log show` over 15 min is the slow probe, so it gets its own bound.
_LOG_TIMEOUT_S: Final = 30.0

_FREE_PCT: Final = re.compile(r"System-wide memory free percentage:\s*(\d+)")


def probe_runner() -> Runner:
    """The real runner the hooks use; a unit test overrides this name for a fake."""
    from stratum_e2e.round.runner import SubprocessRunner

    return SubprocessRunner()


def snapshot_lines(runner: Runner, *, now: str | None = None) -> list[str]:
    """The lines of one host-load snapshot: time, memory, load, emulators, docker, and App Nap per emulator."""
    moment = now if now is not None else _dt.datetime.now(_dt.UTC).astimezone().isoformat(timespec="seconds")
    lines = [f"host load at {moment}"]
    lines += _memory_lines(runner)
    lines += _emulator_lines(runner)
    return lines


def write_baseline(folder: Path, runner: Runner | None = None) -> Path | None:
    """Write the session-start snapshot into the target's folder; `None` when the write itself fails."""
    return _write(folder / BASELINE_NAME, runner)


def write_failure_snapshot(folder: Path, runner: Runner | None = None) -> Path | None:
    """Write the failure snapshot into the test's folder; `None` when the write itself fails."""
    return _write(folder / SNAPSHOT_NAME, runner)


def _write(path: Path, runner: Runner | None) -> Path | None:
    try:
        lines = snapshot_lines(runner if runner is not None else probe_runner())
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    except OSError:
        return None
    return path


def _memory_lines(runner: Runner) -> list[str]:
    free = _probe(runner, ["memory_pressure"], _free_pct)
    loadavg = _probe(runner, ["sysctl", "-n", "vm.loadavg"])
    ncpu = _probe(runner, ["sysctl", "-n", "hw.ncpu"])
    return [
        f"memory free: {free}",
        f"loadavg: {loadavg}",
        f"cpu count: {ncpu}",
    ]


def _free_pct(out: str) -> str:
    match = _FREE_PCT.search(out)
    return f"{match.group(1)}%" if match else "no free-percentage line"


def _trim(out: str, limit: int = 200) -> str:
    text = out.strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def _emulator_lines(runner: Runner) -> list[str]:
    pgrep = _probe_completed(runner, ["pgrep", "-l", "qemu-system"])
    lines: list[str] = []
    emulators: list[tuple[str, str]] = []
    if pgrep is None:
        lines.append("qemu emulators: probe failed")
    elif pgrep.timed_out or pgrep.status not in (0, 1):
        lines.append(f"qemu emulators: probe failed ({_error_text(pgrep)})")
    elif pgrep.status == 1 or not pgrep.stdout.strip():
        lines.append("qemu emulators: none running")
    else:
        for line in pgrep.stdout.splitlines():
            parts = line.split(maxsplit=1)
            if len(parts) == 2 and parts[0].isdigit():
                emulators.append((parts[0], parts[1].strip()))
        listing = "; ".join(f"{pid} {name}" for pid, name in emulators) or "none running"
        lines.append(f"qemu emulators: {listing}")
    docker = _docker_line(runner)
    lines.append(docker)
    for pid, name in emulators:
        lines.append(f"{pid} App Nap / role:")
        lines += _appnap_lines(runner, name)
    return lines


def _docker_line(runner: Runner) -> str:
    argv = ["docker", "ps", "--format", "{{.Names}} {{.Status}}"]
    done = _probe_completed(runner, argv)
    if done is None:
        return "docker containers: probe failed"
    if done.timed_out:
        return f"docker containers: probe failed ({_error_text(done)})"
    if done.status == 127:
        reason = _trim(done.stderr or done.stdout) or "not installed"
        return f"docker containers: none ({reason})"
    if done.status != 0:
        return f"docker containers: probe failed ({_error_text(done)})"
    listing = _trim(done.stdout, 400) or "none running"
    return f"docker containers: {listing}"


def _appnap_lines(runner: Runner, name: str) -> list[str]:
    argv = [
        "log",
        "show",
        "--last",
        _LOG_WINDOW,
        "--predicate",
        _LOG_PREDICATE,
        "--style",
        "compact",
    ]
    # The grep runs in Python, so one timeout bounds the whole probe.
    done = _probe_completed(runner, argv, timeout_s=_LOG_TIMEOUT_S)
    if done is None:
        return ["  probe failed"]
    if done.timed_out:
        return [f"  probe failed ({_error_text(done)})"]
    if done.status != 0:
        return [f"  probe failed ({_error_text(done)})"]
    kept = [
        line
        for line in done.stdout.splitlines()
        if name in line and re.search(_LOG_GREP, line)
    ]
    if not kept:
        return [f"  none in the last {_LOG_WINDOW}"]
    return [f"  {line.strip()}" for line in kept[:20]]


def _probe(runner: Runner, argv: Sequence[str], parse=None) -> str:  # type: ignore[no-untyped-def]
    done = _probe_completed(runner, argv)
    if done is None:
        return "probe failed"
    if done.timed_out:
        return f"probe failed (timeout after the probe's bound)"
    if done.status != 0:
        return f"probe failed ({_error_text(done)})"
    if parse is not None:
        return parse(done.stdout)
    return _trim(done.stdout) or "empty"


def _probe_completed(runner: Runner, argv: Sequence[str], *, timeout_s: float = _PROBE_TIMEOUT_S) -> Completed | None:
    """Run one probe; an exception (never raised by a real Runner, but a broken one may) reads as `None`."""
    try:
        return runner.run(list(argv), timeout_s=timeout_s)
    except OSError as error:
        return None if not str(error) else Completed(tuple(argv), 1, "", f"{type(error).__name__}: {error}", False)


def _error_text(done: Completed) -> str:
    return _trim(done.stderr or done.stdout) or f"status {done.status}"
