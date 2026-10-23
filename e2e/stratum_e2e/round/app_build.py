"""Build `test_app` per platform for the Appium legs, and reuse a build whose sources did not change.

A `flutter test integration_test` run on the same platform rebuilds into the same `build/` paths, so a finished build
is copied to `build/e2e/<platform>[-wasm]/` and that copy is what the Appium legs install or serve. A `.digest` stamp
beside the copy says which authored sources and which toolchain it came from. Every command, `git` included, goes
through a `Runner`.

`resolve_app_packages` comes first: the host `flutter build` and `flutter test --no-pub` runs of a round read the app's
`.dart_tool`, so a fresh worktree resolves it once before either.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import time
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Final

from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.runner import Runner

_BUILD_TIMEOUT_S: Final = 3600.0
_QUERY_TIMEOUT_S: Final = 120.0
_STAMP: Final = ".digest"
_RESOLVE_TIMEOUT_S: Final = 600.0
_LOCK_KEY: Final = ".dart_tool/.dt-lock-hash"
_PACKAGE_CONFIG: Final = ".dart_tool/package_config.json"
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

# The app's tests are not compiled into the app, so they stay out of its digest; everything else git lists there
# (authored, not ignored) is a source.
_APP_PATHSPECS: Final = (".", ":(exclude)integration_test", ":(exclude)test")
# The package's shared sources, and the one platform folder of the package each app platform reads.
_PACKAGE_SHARED: Final = ("lib", "assets", "pubspec.yaml")
_PACKAGE_PLATFORM_FOLDER: Final[Mapping[str, str | None]] = {
    "android": "android",
    "ios": "darwin",
    "macos": "darwin",
    "web": None,
}
_XCODE_PLATFORMS: Final = frozenset({"ios", "macos"})


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


def source_digest(
    app_dir: Path, package_root: Path, platform: str, argv: Sequence[str], runner: Runner
) -> str:
    """A hex digest of what a build for `platform` reads: authored source contents, toolchain revisions, build `argv`.

    The file set is what `git ls-files --cached --others --exclude-standard` lists, so a file git ignores (a
    build output, a generated plugin registrant, `local.properties`) never counts and an untracked authored file
    does. That is the app folder minus its `integration_test/` and `test/`, and from the package root `lib/`,
    `assets/`, `pubspec.yaml`, and the one platform folder the app reads (`android/` for android, `darwin/` for ios
    and macos, none for web). The toolchain is the Flutter framework and engine revision, plus the Xcode version
    for ios and macos, so a build from another toolchain is never reused. The `argv` joins the digest so the JS and
    Wasm web builds, which read the same sources, differ.

    Raises `RoundEnvError` when git or a toolchain query fails.
    """
    if platform not in _PACKAGE_PLATFORM_FOLDER:
        raise ValueError(f"the e2e app builds android, ios, macos, and web, not {platform}")
    package_folder = _PACKAGE_PLATFORM_FOLDER[platform]
    package_specs = (*_PACKAGE_SHARED, *((package_folder,) if package_folder else ()))

    digest = hashlib.sha256()
    digest.update("\0".join((*argv, *_toolchain(runner, app_dir, platform))).encode())
    for label, root, specs in (("app", app_dir, _APP_PATHSPECS), ("package", package_root, package_specs)):
        for file in _authored_files(runner, root, specs):
            digest.update(f"\0{label}\0{file.relative_to(root).as_posix()}\0".encode())
            digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()


def resolve_app_packages(app_dir: Path, runner: Runner, log: Path) -> None:
    """Resolve `app_dir`'s packages with `flutter pub get --offline`, then online, unless the last resolve is current.

    `flutter test --no-pub` finds no package config of the app in a fresh worktree and walks up to the enclosing
    checkout's, so a round resolves before its first host run. Current means a package config exists and
    `.dart_tool/.dt-lock-hash` holds this lock's hash and this folder: the Linux container writes the bare hash beside
    a config of its own paths, which therefore reads as stale here. A resolve that fails both ways raises
    `RoundEnvError`.
    """
    key_file = app_dir / _LOCK_KEY
    if (app_dir / _PACKAGE_CONFIG).is_file() and _read_key(key_file) == _lock_key(app_dir):
        return
    key_file.unlink(missing_ok=True)
    offline = ("flutter", "pub", "get", "--offline")
    done = runner.run(offline, timeout_s=_RESOLVE_TIMEOUT_S, cwd=app_dir, log=log)
    if done.status != 0:
        online = ("flutter", "pub", "get")
        done = runner.run(online, timeout_s=_RESOLVE_TIMEOUT_S, cwd=app_dir, log=log)
    if done.status != 0:
        reason = "timed out" if done.timed_out else f"exit {done.status}"
        raise RoundEnvError(f"flutter pub get failed ({reason}): {_error_tail(done.stderr or done.stdout)}")
    key_file.parent.mkdir(parents=True, exist_ok=True)
    key_file.write_text(_lock_key(app_dir), encoding="utf-8")


def _lock_key(app_dir: Path) -> str:
    lock = app_dir / "pubspec.lock"
    content = lock.read_bytes() if lock.is_file() else b""
    return f"{hashlib.sha256(content).hexdigest()} {app_dir.resolve()}"


def _read_key(path: Path) -> str | None:
    return path.read_text(encoding="utf-8") if path.is_file() else None


def ensure_app_build(
    app_dir: Path,
    package_root: Path,
    platform: str,
    wasm: bool,
    runner: Runner,
    log: Path,
) -> AppBuild:
    """Return the app build for `platform`, building it only when its sources changed since the last copy.

    A reused build reports `seconds` 0.0. A failed build, one that leaves no artifact, or a failed git or
    toolchain query raises `RoundEnvError`; a failed build leaves no copy behind, so a later call never reuses a
    half build.
    """
    argv = tuple(build_argv(platform, wasm))
    digest = source_digest(app_dir, package_root, platform, argv, runner)
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


def _authored_files(runner: Runner, root: Path, pathspecs: Sequence[str]) -> list[Path]:
    """The files git lists under `root` for `pathspecs`, tracked or untracked but never ignored, in a stable order."""
    argv = ("git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", *pathspecs)
    done = runner.run(argv, timeout_s=_QUERY_TIMEOUT_S, cwd=root)
    if done.status != 0:
        raise RoundEnvError(f"git ls-files in {root} failed (exit {done.status}): {_error_tail(done.stderr)}")
    names = sorted({name for name in done.stdout.split("\0") if name})
    # A tracked file deleted from disk is still listed; it counts as absent.
    return [root / name for name in names if (root / name).is_file()]


def _toolchain(runner: Runner, app_dir: Path, platform: str) -> list[str]:
    """The toolchain facts a build depends on: Flutter framework and engine revision, and Xcode for ios and macos."""
    version = _query(runner, ("flutter", "--version", "--machine"), app_dir)
    try:
        info = json.loads(version[version.index("{") :])
        revisions = [str(info["frameworkRevision"]), str(info["engineRevision"])]
    except (ValueError, KeyError, TypeError) as error:
        raise RoundEnvError(f"flutter --version --machine gave no framework and engine revision: {error!r}") from error
    if platform in _XCODE_PLATFORMS:
        lines = [line for line in _query(runner, ("xcodebuild", "-version"), app_dir).splitlines() if line.strip()]
        if not lines:
            raise RoundEnvError("xcodebuild -version printed nothing")
        revisions.append(lines[0].strip())
    return revisions


def _query(runner: Runner, argv: Sequence[str], cwd: Path) -> str:
    """Run a read-only query and return its stdout; a failed query is an environment error."""
    done = runner.run(argv, timeout_s=_QUERY_TIMEOUT_S, cwd=cwd)
    if done.status != 0:
        raise RoundEnvError(f"{' '.join(argv)} failed (exit {done.status}): {_error_tail(done.stderr or done.stdout)}")
    return done.stdout


def _error_tail(text: str) -> str:
    """The last few non-empty lines of `text`, joined on one line."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return " | ".join(lines[-_ERROR_TAIL_LINES:])
