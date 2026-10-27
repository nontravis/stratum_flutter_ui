"""The machine-wide lane of the device round: file locks between sessions and the memory-pressure gate.

Every session on the machine shares one lock directory, so two rounds never drive the same target, and an `alone`
target (an Android emulator) never shares the machine with any other target. The kernel drops an `flock` when its
holder exits, so a crashed round strands no target.
"""

from __future__ import annotations

import fcntl
import json
import os
import re
import time
from collections.abc import Callable, Sequence
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from types import TracebackType

from stratum_e2e.round.catalog import LaneConfig
from stratum_e2e.round.runner import Runner

LANE_DIR_ENV = "STRATUM_E2E_LANE_DIR"
_MACHINE_LOCK = "machine.lock"
_SESSION_ENV = "CLAUDE_CODE_SESSION_ID"
_SESSION_CHARS = 8
_TARGET_NAME = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]*")
_HOLDER_SUFFIX = ".holder.json"

# The engine's own heavy-process terms; a project's `[lane] heavy_processes` follow them in `heavy_pattern`.
_HEAVY_PROC_PATTERN = "qemu-system|flutter_tools.snapshot (drive|test integration_test)|chromedriver"
_FREE_PCT = re.compile(r"([0-9]+)%")
_HEAVY_LINE_CHARS = 160
_PROBE_TIMEOUT_S = 30.0
_LEVEL2_MIN_FREE_PCT = 30
_LEVEL1_MIN_FREE_PCT = 20


@dataclass(frozen=True)
class Holder:
    """Who holds a lane: process id, Claude session prefix, and ISO UTC start time."""

    pid: int
    session: str
    started: str


class LaneBusy(Exception):
    """A target (or the machine) stayed held by another round for the whole wait."""


def lane_dir() -> Path:
    """The lock directory: `$STRATUM_E2E_LANE_DIR`, else one directory under the home cache, outside every checkout."""
    override = os.environ.get(LANE_DIR_ENV)
    if override:
        return Path(override)
    return Path.home() / ".cache" / "stratum_e2e" / "lanes"


def current_holder() -> Holder:
    """This process as a lane holder; the session is the first 8 characters of `CLAUDE_CODE_SESSION_ID`, else `none`."""
    session = os.environ.get(_SESSION_ENV, "")[:_SESSION_CHARS] or "none"
    return Holder(pid=os.getpid(), session=session, started=datetime.now(timezone.utc).isoformat())


def _open_lock(path: Path) -> int:
    return os.open(path, os.O_RDWR | os.O_CREAT, 0o600)


def _try_lock(fd: int, mode: int) -> bool:
    try:
        fcntl.flock(fd, mode | fcntl.LOCK_NB)
    except BlockingIOError:
        return False
    return True


def _describe_holder(path: Path) -> str:
    try:
        data = json.loads(path.read_text())
        return f"pid {int(data['pid'])}, session {data['session']}, since {data['started']}"
    except (OSError, ValueError, KeyError, TypeError):
        return "holder unknown"


class Lease:
    """A held lane; leaving the `with` block, or `release()`, frees it. Releasing twice is harmless."""

    def __init__(self, holder_file: Path, target_fd: int, machine_fd: int) -> None:
        self._holder_file = holder_file
        self._fds: list[int] = [target_fd, machine_fd]

    def release(self) -> None:
        """Remove the holder file, then free the machine lock and the target lock, in reverse of how they were taken.

        The locks are freed even when removing the holder file raises; readers skip a holder file left behind.
        """
        if not self._fds:
            return
        try:
            self._holder_file.unlink(missing_ok=True)
        finally:
            while self._fds:
                os.close(self._fds.pop())

    def __enter__(self) -> Lease:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        tb: TracebackType | None,
    ) -> None:
        self.release()


def _machine_holders(directory: Path, own_target: str) -> str:
    """Name the other targets whose lock is held right now; a holder file left by a killed round is skipped."""
    named: list[str] = []
    for holder_file in sorted(directory.glob(f"*{_HOLDER_SUFFIX}")):
        target = holder_file.name[: -len(_HOLDER_SUFFIX)]
        if target == own_target:
            continue
        fd = _open_lock(directory / f"{target}.lock")
        try:
            held = not _try_lock(fd, fcntl.LOCK_EX)
        finally:
            os.close(fd)
        if held:
            named.append(f"{target} ({_describe_holder(holder_file)})")
    return ", ".join(named) or "holder unknown"


def _try_acquire(target: str, alone: bool, directory: Path, holder: Holder) -> Lease | str:
    """One non-blocking attempt at the target lock, then the machine lock; a string is the reason it failed."""
    target_fd = _open_lock(directory / f"{target}.lock")
    if not _try_lock(target_fd, fcntl.LOCK_EX):
        os.close(target_fd)
        return f"{target} is held by {_describe_holder(directory / f'{target}{_HOLDER_SUFFIX}')}"
    machine_fd = _open_lock(directory / _MACHINE_LOCK)
    if not _try_lock(machine_fd, fcntl.LOCK_EX if alone else fcntl.LOCK_SH):
        os.close(machine_fd)
        os.close(target_fd)
        return f"{target} needs the machine, held by {_machine_holders(directory, target)}"
    holder_file = directory / f"{target}{_HOLDER_SUFFIX}"
    try:
        holder_file.write_text(json.dumps(asdict(holder)))
    except BaseException:
        os.close(machine_fd)
        os.close(target_fd)
        raise
    return Lease(holder_file, target_fd, machine_fd)


def acquire_lane(
    target: str,
    alone: bool,
    wait_s: float,
    directory: Path,
    holder: Holder,
    *,
    poll_s: float = 5.0,
    sleep: Callable[[float], None] = time.sleep,
    monotonic: Callable[[], float] = time.monotonic,
) -> Lease:
    """Take the lane for `target`, polling for up to `wait_s` seconds; raise `LaneBusy` naming the holder on timeout.

    The target lock comes first, then the machine lock (exclusive for an `alone` target, shared otherwise), so two
    rounds never wait on each other in a cycle. A failed attempt frees whatever it took before it polls again.
    """
    if not _TARGET_NAME.fullmatch(target):
        raise ValueError(f"target name {target!r} must be a plain name")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    deadline = monotonic() + wait_s
    while True:
        attempt = _try_acquire(target, alone, directory, holder)
        if isinstance(attempt, Lease):
            return attempt
        remaining = deadline - monotonic()
        if remaining <= 0:
            raise LaneBusy(f"lane busy: {attempt}")
        sleep(min(poll_s, remaining))


def heavy_pattern(extra: Sequence[str]) -> str:
    """The heavy-process pattern: the engine terms, then `|<name>` for each project term in `extra`, in order."""
    return _HEAVY_PROC_PATTERN + "".join(f"|{name}" for name in extra)


def parse_free_pct(out: str) -> int:
    """The free-memory percentage on the last non-blank line of `memory_pressure`; 0 when there is none."""
    lines = [line for line in out.splitlines() if line.strip()]
    if not lines:
        return 0
    match = _FREE_PCT.search(lines[-1])
    return int(match.group(1)) if match else 0


def memory_gate_reasons(level: str, free_pct: int, allow_level2: bool, heavy_line: str | None) -> list[str]:
    """Why the host cannot take a boot now; an empty list means the gate passes."""
    reasons: list[str] = []
    if allow_level2 and level == "2":
        if free_pct < _LEVEL2_MIN_FREE_PCT:
            reasons.append(f"pressure level 2 needs at least {_LEVEL2_MIN_FREE_PCT}% free, has {free_pct}%")
    elif level == "1":
        if free_pct < _LEVEL1_MIN_FREE_PCT:
            reasons.append(f"pressure level 1 needs at least {_LEVEL1_MIN_FREE_PCT}% free, has {free_pct}%")
    elif allow_level2:
        reasons.append(f"pressure level {level} is not 1 or 2")
    else:
        reasons.append(f"pressure level {level} is not 1")
    if heavy_line:
        reasons.append(f"a heavy process is running: {heavy_line}")
    return reasons


def host_memory_reasons(runner: Runner, lane: LaneConfig) -> list[str]:
    """Probe the host (`memory_pressure`, the kernel pressure level, `pgrep` for heavy processes) and apply the gate."""
    free_pct = parse_free_pct(runner.run(["memory_pressure"], timeout_s=_PROBE_TIMEOUT_S).stdout)
    level_probe = runner.run(["sysctl", "-n", "kern.memorystatus_vm_pressure_level"], timeout_s=_PROBE_TIMEOUT_S)
    level = level_probe.stdout.strip() if level_probe.status == 0 else "unknown"
    heavy = runner.run(["pgrep", "-fl", heavy_pattern(lane.heavy_processes)], timeout_s=_PROBE_TIMEOUT_S)
    heavy_line = None
    if heavy.status == 0 and heavy.stdout.strip():
        heavy_line = heavy.stdout.splitlines()[0][:_HEAVY_LINE_CHARS]
    return memory_gate_reasons(level, free_pct, lane.allow_level2, heavy_line)


def wait_for_memory(
    probe: Callable[[], list[str]],
    wait_s: float,
    *,
    poll_s: float = 5.0,
    sleep: Callable[[float], None] = time.sleep,
    monotonic: Callable[[], float] = time.monotonic,
) -> list[str]:
    """Poll `probe` for up to `wait_s` seconds; return `[]` once it passes, else its last reasons at timeout."""
    deadline = monotonic() + wait_s
    while True:
        reasons = probe()
        if not reasons:
            return []
        remaining = deadline - monotonic()
        if remaining <= 0:
            return reasons
        sleep(min(poll_s, remaining))
