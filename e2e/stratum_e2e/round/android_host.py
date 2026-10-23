"""Android SDK, AVD, and console port lookups for the device round; none runs a process."""

from __future__ import annotations

import fcntl
import os
import re
import shutil
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.lane import lane_dir

CONSOLE_PORTS = ("console", 5554, 5584, 2)

_LOCAL_PROPERTIES = Path("android") / "local.properties"
_SDK_DIR = re.compile(r"^sdk\.dir=(.*)$", re.MULTILINE)
_AVD_TARGET = re.compile(r"^target=android-([0-9]+)", re.MULTILINE)
_AVD_PATH = re.compile(r"^path=(.+)$", re.MULTILINE)


def sdk_root(app_dir: Path, environ: Mapping[str, str], home: Path) -> Path:
    """The first existing Android SDK directory among `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `local.properties`, and `~/Library/Android/sdk`."""
    properties = app_dir / _LOCAL_PROPERTIES
    candidates = (
        environ.get("ANDROID_HOME", ""),
        environ.get("ANDROID_SDK_ROOT", ""),
        _properties_sdk_dir(properties),
        str(home / "Library" / "Android" / "sdk"),
    )
    for candidate in candidates:
        if candidate and Path(candidate).is_dir():
            return Path(candidate)
    raise RoundEnvError(
        "no Android SDK: set ANDROID_HOME or ANDROID_SDK_ROOT, "
        f"write sdk.dir in {properties}, or install to {home / 'Library' / 'Android' / 'sdk'}"
    )


def _properties_sdk_dir(properties: Path) -> str:
    if not properties.is_file():
        return ""
    match = _SDK_DIR.search(properties.read_text())
    return match.group(1).strip().replace("\\:", ":") if match else ""


def adb_path(sdk: Path, which: Callable[[str], str | None] = shutil.which) -> str:
    """`adb` when it is on PATH, else the SDK's own `platform-tools/adb`."""
    if which("adb"):
        return "adb"
    return str(sdk / "platform-tools" / "adb")


def emulator_path(sdk: Path) -> str:
    """The SDK's `emulator/emulator` binary; the `emulator` on PATH, if any, is often a stale shim."""
    return str(sdk / "emulator" / "emulator")


@dataclass(frozen=True)
class AvdInfo:
    """An AVD's name, Android API level, and data folder."""

    name: str
    api: int
    folder: Path


def avd_info(avd: str, avd_home: Path) -> AvdInfo:
    """Read `<avd_home>/<avd>.ini`; the folder name can differ from the AVD name, so the `.ini` is the index."""
    ini = avd_home / f"{avd}.ini"
    if not ini.is_file():
        raise RoundEnvError(f"no AVD {avd!r} under {avd_home}; {missing_avd_message(avd)}")
    text = ini.read_text()
    target = _AVD_TARGET.search(text)
    folder = _AVD_PATH.search(text)
    if target is None or folder is None:
        raise RoundEnvError(f"{ini} lacks a target=android-<n> or path= line")
    return AvdInfo(name=avd, api=int(target.group(1)), folder=Path(folder.group(1).strip()))


def missing_avd_message(avd: str) -> str:
    """The `avdmanager create avd` line to create the AVD by hand; the round never runs it or downloads an image."""
    return (
        f"create it yourself (the round never downloads an image): "
        f'avdmanager create avd -n {avd} -k "system-images;android-<api>;google_apis_playstore;<abi>"'
    )


@dataclass(eq=False)
class PortReservation:
    """A port held by a `flock` on its lock file; the kernel drops the lock when the holder dies, SIGKILL included."""

    port: int
    path: Path
    _fd: int = field(repr=False, default=-1)

    def release(self) -> None:
        """Unlock and close the lock file; the file stays, since removing it would race another reserver."""
        if self._fd < 0:
            return
        fcntl.flock(self._fd, fcntl.LOCK_UN)
        os.close(self._fd)
        self._fd = -1


def port_directory() -> Path:
    """The one directory every reservation lock lives in, beside the lane locks."""
    return lane_dir() / "ports"


def reserve_port(name: str, low: int, high: int, step: int, taken: set[int], directory: Path) -> PortReservation:
    """Reserve the lowest port in `low..high` (every `step`) that is not in `taken` and not locked by another round."""
    directory.mkdir(parents=True, exist_ok=True)
    for port in range(low, high + 1, step):
        if port in taken:
            continue
        path = directory / f"{name}-{port}.lock"
        fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(fd)
            continue
        return PortReservation(port=port, path=path, _fd=fd)
    raise RoundEnvError(f"no free {name} port in {low}..{high} step {step}")
