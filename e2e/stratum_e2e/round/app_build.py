"""Build `test_app` per platform for the Appium legs, and reuse a build whose sources did not change.

A `flutter test integration_test` run on the same platform rebuilds into the same `build/` paths, so a finished build
is copied to `build/e2e/<platform>[-wasm]/` and that copy is what the Appium legs install or serve. A `.digest` stamp
beside the copy says which sources it came from. Every command goes through a `Runner`.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import time
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Final

from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.runner import Runner

_BUILD_TIMEOUT_S: Final = 3600.0
_STAMP: Final = ".digest"
_ERROR_TAIL_LINES: Final = 3

_BUILD_ARGV: Final[dict[tuple[str, bool], tuple[str, ...]]] = {
    ("android", False): ("flutter", "build", "apk", "--debug"),
    ("ios", False): ("flutter", "build", "ios", "--simulator", "--debug"),
    ("macos", False): ("flutter", "build", "macos", "--debug"),
    ("web", False): ("flutter", "build", "web", "-o", "build/web_js"),
    ("web", True): ("flutter", "build", "web", "--wasm", "-o", "build/web_wasm"),
}

# Relative to the app folder; `stratum_ui_test_app.app` is `PRODUCT_NAME` in
# `test_app/macos/Runner/Configs/AppInfo.xcconfig`.
_OUTPUT: Final[dict[tuple[str, bool], str]] = {
    ("android", False): "build/app/outputs/flutter-apk/app-debug.apk",
    ("ios", False): "build/ios/iphonesimulator/Runner.app",
    ("macos", False): "build/macos/Build/Products/Debug/stratum_ui_test_app.app",
    ("web", False): "build/web_js",
    ("web", True): "build/web_wasm",
}

_APP_SOURCES: Final = ("lib", "pubspec.yaml", "pubspec.lock")
_PACKAGE_SOURCES: Final = ("lib", "assets", "android", "darwin", "pubspec.yaml")
_SKIPPED_DIRS: Final = frozenset({"build", ".dart_tool"})


@dataclass(frozen=True)
class AppBuild:
    """One app build the legs can use: the copied artifact, the build argv, the build time, and whether it was reused."""

    path: Path
    argv: tuple[str, ...]
    seconds: float
    reused: bool


def build_argv(platform: str, wasm: bool) -> list[str]:
    """The `flutter build` command for `platform`; `wasm` selects the Wasm web build."""
    return list(_lookup(_BUILD_ARGV, platform, wasm))


def flutter_output(app_dir: Path, platform: str, wasm: bool) -> Path:
    """Where `flutter build` leaves the artifact for `platform`, under `app_dir`."""
    return app_dir / _lookup(_OUTPUT, platform, wasm)


def source_digest(app_dir: Path, package_root: Path, platform: str, argv: Sequence[str]) -> str:
    """A hex digest of the file contents a build for `platform` reads, joined with the build `argv`.

    The app's platform folder joins the app's own sources and the package root's sources. `build/`,
    `.dart_tool/`, and dot entries never count: a build writes them. The `argv` joins the digest so the JS and
    Wasm web builds, which read the same sources, differ.
    """
    digest = hashlib.sha256()
    digest.update("\0".join(argv).encode())
    sources = (
        ("app", app_dir, (*_APP_SOURCES, platform)),
        ("package", package_root, _PACKAGE_SOURCES),
    )
    for label, root, names in sources:
        for name in names:
            for file in _source_files(root / name):
                digest.update(f"\0{label}\0{file.relative_to(root).as_posix()}\0".encode())
                digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()


def ensure_app_build(
    app_dir: Path,
    package_root: Path,
    platform: str,
    wasm: bool,
    runner: Runner,
    log: Path,
) -> AppBuild:
    """Return the app build for `platform`, building it only when its sources changed since the last copy.

    A reused build reports `seconds` 0.0. A failed build, or one that leaves no artifact, raises `RoundEnvError`
    and leaves no copy behind, so a later call never reuses a half build.
    """
    argv = tuple(build_argv(platform, wasm))
    digest = source_digest(app_dir, package_root, platform, argv)
    output = flutter_output(app_dir, platform, wasm)
    folder = app_dir / "build" / "e2e" / (f"{platform}-wasm" if wasm else platform)
    copy = folder / output.name
    stamp = folder / _STAMP

    if copy.exists() and stamp.is_file() and stamp.read_text(encoding="utf-8") == digest:
        return AppBuild(path=copy, argv=argv, seconds=0.0, reused=True)

    shutil.rmtree(folder, ignore_errors=True)
    started = time.monotonic()
    done = runner.run(argv, timeout_s=_BUILD_TIMEOUT_S, cwd=app_dir, log=log)
    if done.status != 0:
        reason = "timed out" if done.timed_out else f"exit {done.status}"
        raise RoundEnvError(f"{' '.join(argv)} failed ({reason}): {_error_tail(done.stderr or done.stdout)}")
    if not output.exists():
        raise RoundEnvError(f"{' '.join(argv)} produced no {output.relative_to(app_dir).as_posix()}")

    folder.mkdir(parents=True)
    if output.is_dir():
        shutil.copytree(output, copy, symlinks=True)
    else:
        shutil.copy2(output, copy)
    stamp.write_text(digest, encoding="utf-8")
    return AppBuild(path=copy, argv=argv, seconds=time.monotonic() - started, reused=False)


def _lookup[T](table: Mapping[tuple[str, bool], T], platform: str, wasm: bool) -> T:
    """Read `table` for `platform` and `wasm`, naming what the e2e app build lacks when the key is absent."""
    if (platform, wasm) in table:
        return table[platform, wasm]
    if wasm and (platform, False) in table:
        raise ValueError(f"wasm builds only the web target, not {platform}")
    raise ValueError(f"the e2e app builds android, ios, macos, and web, not {platform}")


def _source_files(path: Path) -> list[Path]:
    """The files under `path` (or `path` itself) in a stable order, minus build output and dot entries."""
    if path.is_file():
        return [path]
    found: list[Path] = []
    for directory, subdirs, names in os.walk(path):
        subdirs[:] = sorted(d for d in subdirs if d not in _SKIPPED_DIRS and not d.startswith("."))
        found.extend(
            file
            for name in sorted(names)
            if not name.startswith(".") and (file := Path(directory, name)).is_file()
        )
    return found


def _error_tail(text: str) -> str:
    """The last few non-empty lines of `text`, joined on one line."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return " | ".join(lines[-_ERROR_TAIL_LINES:])
