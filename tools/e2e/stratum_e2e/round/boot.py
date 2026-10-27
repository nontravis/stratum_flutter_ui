"""What the device round records about a booted device, and the interface every platform's booter meets."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Protocol

from stratum_e2e.round.android_host import PortReservation
from stratum_e2e.round.catalog import Target


@dataclass
class BootRecord:
    """The device one target runs on, and what the round must undo when it ends.

    `reused` marks a device found running at round start: the round never changes or ends it. A booted device gets
    `pid` and `port` at spawn, before any wait, so a boot that fails later still finds what it started.
    `settings_applied` turns true before the first boot setting is written, so a partial write is still restored.
    `setting_failures` names each boot setting write or restore that failed; neither fails the boot or the shutdown,
    so the round reports them instead.
    """

    target: str
    platform: str
    device_id: str
    reused: bool
    pid: int | None = None
    port: PortReservation | None = None
    settings_applied: bool = False
    setting_failures: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class BootLog:
    """Where a booter keeps the device log of a boot it ran, and the instant that log starts."""

    path: Path
    since: datetime


class Booter(Protocol):
    """Boots, readies, and ends the device of a target; a device found running is reused and never ended."""

    def is_running(self, target: Target) -> bool:
        """Whether `boot` would reuse a running device for `target` instead of booting one."""
        ...

    def boot(self, target: Target, log: Path, device_log: BootLog | None = None) -> BootRecord:
        """Reuse the running device of `target`, else boot one with its output in `log`.

        With `device_log`, a device this call booted gets its device log from `device_log.since` to the end of the
        boot saved at `device_log.path`, also when the boot fails, before the device is ended. A reused device and a
        host platform save none.

        Raises `RoundEnvError` when the device never gets ready; a device this call booted is ended first.
        """
        ...

    def before_file(self, record: BootRecord) -> None:
        """Make the device ready before each integration file and each e2e item; raises `RoundEnvError` when it cannot."""
        ...

    def shutdown(self, record: BootRecord) -> None:
        """End the device `boot` booted and release what it held; a reused device is left as found."""
        ...
