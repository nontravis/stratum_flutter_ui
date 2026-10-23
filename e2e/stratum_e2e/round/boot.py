"""What the device round records about a booted device, and the interface every platform's booter meets."""

from __future__ import annotations

from dataclasses import dataclass
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
    """

    target: str
    platform: str
    device_id: str
    reused: bool
    pid: int | None = None
    port: PortReservation | None = None
    settings_applied: bool = False


class Booter(Protocol):
    """Boots, readies, and ends the device of a target; a device found running is reused and never ended."""

    def is_running(self, target: Target) -> bool:
        """Whether `boot` would reuse a running device for `target` instead of booting one."""
        ...

    def boot(self, target: Target, log: Path) -> BootRecord:
        """Reuse the running device of `target`, else boot one with its output in `log`.

        Raises `RoundEnvError` when the device never gets ready; a device this call booted is ended first.
        """
        ...

    def before_file(self, record: BootRecord) -> None:
        """Make the device ready for the next test file; raises `RoundEnvError` when it cannot."""
        ...

    def shutdown(self, record: BootRecord) -> None:
        """End the device `boot` booted and release what it held; a reused device is left as found."""
        ...
