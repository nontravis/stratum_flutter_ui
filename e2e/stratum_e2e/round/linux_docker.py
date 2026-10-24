"""The Linux target's docker image and run wrapper: build the image, scan plugin packages, run `flutter test`.

Ported from the retired bash skill's `platforms/linux.sh`. Nothing here starts docker on import; every command goes
through a `Runner`, so a unit test swaps in `unit/round_fakes.py::FakeRunner`.
"""

from __future__ import annotations

import hashlib
import json
import os
import shlex
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

from stratum_e2e.paths import E2E_ROOT
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.runner import Runner

DOCKERFILE = E2E_ROOT / "docker" / "linux.Dockerfile"
IMAGE_NAME = "stratum-e2e-linux"

# The dev packages e2e/docker/linux.Dockerfile installs that a plugin may ask for (`linux.sh::LINUX_IMAGE_APT`);
# a unit test keeps this tuple and the Dockerfile in step.
DEFAULT_PACKAGES = ("libgtk-3-dev", "libsecret-1-dev")

ROUND_LABEL = "stratum-e2e-round=1"

# Host-only trees the source sync leaves out of a target's work volume (`sync_command`). Anchored patterns name a path
# under the repo root; the rest match at any depth. rsync never deletes an excluded path on the receiving side, so the
# container keeps its own `build/`, `.dart_tool/`, and plugin lists beside each app folder between rounds.
SYNC_EXCLUDES = (
    "/.git",  # version control; in a worktree a file, so no trailing slash
    "/.worktrees",  # other checkouts
    "/.superpowers",  # the session journal
    "/tmp",  # round dirs: a run's results leave through the `/round` mount only
    "/e2e/.venv",  # host test tooling
    "/e2e/.tools",
    "/e2e/.wda-derived",
    "build/",  # host build output; the container builds each app at its own path in the work volume
    ".dart_tool/",  # host package configs, which hold host paths
    ".flutter-plugins",  # host plugin lists, which hold host paths
    ".flutter-plugins-dependencies",
    "ephemeral/",  # host platform tooling Flutter regenerates
    "Pods/",  # host CocoaPods state
    ".symlinks/",
    ".gradle/",  # host Gradle state
)
# A log line holding it never ran a test: the work volume could not take the host tree.
SYNC_FAILED_SIGN = "dt: source sync failed"

_BUILD_TIMEOUT_S = 3600.0
_REPORT_PATH = "/round/report.json"

# pkg-config module -> Debian dev package. A module outside it is reported `unknown module` and never checked.
LINUX_MODULE_PACKAGES: Mapping[str, str] = {
    "libsecret-1": "libsecret-1-dev",
    "webkit2gtk-4.1": "libwebkit2gtk-4.1-dev",
    "gtk+-3.0": "libgtk-3-dev",
    "ayatana-appindicator3-0.1": "libayatana-appindicator3-dev",
    "glib-2.0": "libglib2.0-dev",
    "libnotify": "libnotify-dev",
    "sqlite3": "libsqlite3-dev",
    "x11": "libx11-dev",
}

# The scan: argv is <generated_plugins.cmake> <pub cache> <package_config.json>...
# Prints `module <plugin> <pkg-config module>` for every module a plugin's
# linux/CMakeLists.txt asks pkg_check_modules for (version operators
# stripped), and `unresolved <plugin>` when no CMakeLists is found through
# the package_config files (rootUri, absolute or relative) or
# <pub cache>/hosted/pub.dev/<plugin>-*/linux/CMakeLists.txt (newest version).
LINUX_DEPS_PROGRAM = r"""
import glob
import json
import os
import re
import sys
from urllib.parse import unquote, urlparse

cmake, pub_cache, configs = sys.argv[1], sys.argv[2], sys.argv[3:]
with open(cmake, encoding="utf-8") as handle:
    text = handle.read()
plugins = []
for match in re.finditer(r"list\(APPEND\s+FLUTTER_(?:FFI_)?PLUGIN_LIST\s*([^)]*)\)", text):
    plugins.extend(match.group(1).split())

roots = {}
for config in configs:
    try:
        with open(config, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        continue
    base = os.path.dirname(os.path.abspath(config))
    for package in data.get("packages", []):
        uri = urlparse(package.get("rootUri", ""))
        path = unquote(uri.path)
        if uri.scheme != "file":
            path = os.path.normpath(os.path.join(base, path))
        roots.setdefault(package.get("name"), path)


def version_key(path):
    tail = os.path.basename(os.path.dirname(os.path.dirname(path)))
    return tuple(int(n) for n in re.findall(r"\d+", tail))


KEYWORDS = {"REQUIRED", "QUIET", "IMPORTED_TARGET", "GLOBAL", "NO_CMAKE_PATH", "NO_CMAKE_ENVIRONMENT_PATH"}
for plugin in plugins:
    lists = ""
    root = roots.get(plugin)
    if root and os.path.isfile(os.path.join(root, "linux", "CMakeLists.txt")):
        lists = os.path.join(root, "linux", "CMakeLists.txt")
    else:
        hits = glob.glob(os.path.join(pub_cache, "hosted", "pub.dev", plugin + "-*", "linux", "CMakeLists.txt"))
        if hits:
            lists = max(hits, key=version_key)
    if not lists:
        print(f"unresolved {plugin}")
        continue
    with open(lists, encoding="utf-8", errors="replace") as handle:
        source = re.sub(r"#[^\n]*", "", handle.read())
    for call in re.finditer(r"pkg_check_modules\s*\(([^)]*)\)", source):
        for word in call.group(1).split()[1:]:
            module = re.split(r"[<>=]", word)[0]
            if word not in KEYWORDS and module:
                print(f"module {plugin} {module}")
"""

# The build-volume gate: one `dt: removing <dir> (<rule>)` line per wiped cmake build dir, then the pending marker.
_BUILD_GATE = (
    r"""mkdir -p build; prev=$(cat build/.dt-last-exit 2>/dev/null); for d in build/linux/*/debug; do """
    r"""[ -d "$d" ] || continue; why=""; if [ -n "$prev" ] && [ "$prev" != 0 ]; then why="previous exit $prev"; """
    r"""else p=$(sed -n "s/^CMAKE_INSTALL_PREFIX:PATH=//p" "$d/CMakeCache.txt" 2>/dev/null | head -1); """
    r"""if [ -n "$p" ] && [ "${p%/bundle}" = "$p" ]; then why="install prefix $p"; fi; fi; """
    r"""[ -z "$why" ] || { echo "dt: removing $d ($why)"; rm -rf "$d"; }; done; echo pending > build/.dt-last-exit"""
)


@dataclass(frozen=True)
class DepsResolution:
    """What the plugin scan found: one report line per module or unresolved plugin, the mapped Debian packages
    (sorted, unique), and the modules outside `LINUX_MODULE_PACKAGES`."""

    lines: tuple[str, ...]
    packages: tuple[str, ...]
    unknown: tuple[str, ...]


def _apt_text(apt: Sequence[str]) -> str:
    return " ".join(sorted(set(apt)))


def image_tag(flutter_version: str, dockerfile_text: str, apt: Sequence[str]) -> str:
    """The image tag for one Flutter version, Dockerfile, and apt list, so an edit to either rebuilds."""
    digest = hashlib.sha256(f"{dockerfile_text}apt={_apt_text(apt)}\n".encode()).hexdigest()[:8]
    return f"{IMAGE_NAME}:{flutter_version}-{digest}"


def ensure_image(runner: Runner, target: Target, flutter_version: str) -> str:
    """The tag of the target's image, building it first when `docker image inspect` does not find it.

    Raises `RoundEnvError` when the build fails: docker, the network, or the disk stopped it, not the code under test.
    """
    tag = image_tag(flutter_version, DOCKERFILE.read_text(encoding="utf-8"), target.apt)
    if runner.run(["docker", "image", "inspect", tag]).status == 0:
        return tag
    built = runner.run(
        [
            "docker",
            "build",
            "-f",
            str(DOCKERFILE),
            "--build-arg",
            f"FLUTTER_VERSION={flutter_version}",
            "--build-arg",
            f"EXTRA_APT={_apt_text(target.apt)}",
            "-t",
            tag,
            str(DOCKERFILE.parent),
        ],
        timeout_s=_BUILD_TIMEOUT_S,
    )
    if built.status != 0:
        detail = (built.stderr.strip().splitlines() or ["no output"])[-1]
        raise RoundEnvError(f"docker build of {tag} failed (status {built.status}): {detail}")
    return tag


def inner_command(files: Sequence[str], plain_name: str | None, sequence: bool) -> str:
    """The `flutter test` line the container runs under xvfb; the per-test report lands in the mounted `/round`.

    Raises `ValueError` for no files: `flutter test` with none would run the whole `test/` folder.
    """
    if not files:
        raise ValueError("inner_command needs at least one test file")
    parts = [
        "xvfb-run flutter test",
        *(shlex.quote(name) for name in files),
        "-d linux --no-pub --reporter expanded",
        f"--file-reporter json:{_REPORT_PATH}",
    ]
    if plain_name is not None:
        parts.append(f"--plain-name {shlex.quote(plain_name)}")
    if sequence:
        parts.append("--no-uninstall")
    return " ".join(parts)


def linux_pub_gate() -> str:
    """The in-container script that runs `flutter pub get` unless the target's `.dart_tool` volume is current.

    Current means: a package_config exists, every rootUri lies inside the container, and the lock hash equals the one
    stored beside it. Offline against the mounted host pub cache first, then online.
    """
    return (
        r"""h=$(sha256sum pubspec.lock | cut -d" " -f1); pc=.dart_tool/package_config.json; """
        r"""f=.dart_tool/.dt-lock-hash; """
        r"""current=0; if [ -f "$pc" ] && [ "$(cat "$f" 2>/dev/null)" = "$h" ] && """
        r"""! grep -Eo "\"rootUri\": *\"file:///[^/\"]+" "$pc" | grep -vqE "file:///(work|root)$"; """
        r"""then current=1; fi; """
        r"""[ "$current" = 1 ] || { { flutter pub get --offline || flutter pub get; } && mkdir -p .dart_tool && """
        r"""echo "$h" > "$f"; }"""
    )


def sync_command() -> str:
    """The in-container command that brings the target's work volume (`/work`) level with the read-only host tree
    (`/host`): incremental, deleting what the host deleted, and leaving out `SYNC_EXCLUDES`."""
    excludes = " ".join(f"--exclude={shlex.quote(pattern)}" for pattern in SYNC_EXCLUDES)
    return f"rsync -a --delete {excludes} /host/ /work/"


def container_script(inner: str) -> str:
    """The whole in-container script: the source sync, the build-dir gate, the pub gate, `inner`, then its exit status.

    A failed sync prints `SYNC_FAILED_SIGN` and stops. The status goes to `build/.dt-last-exit`; the next run wipes
    the cmake build dir when it was not 0.
    """
    return (
        f'{sync_command()} || {{ echo "{SYNC_FAILED_SIGN}"; exit 1; }}; '
        f'{_BUILD_GATE}; {linux_pub_gate()} && {inner}; rc=$?; echo "$rc" > build/.dt-last-exit; exit "$rc"'
    )


# Every docker object the round owns is named under `IMAGE_NAME`, so none collides with the bash tool's `dt-*` names.


def source_volume(target: str) -> str:
    """The named volume holding the target's work copy of the repo at `/work`: the synced source plus each app
    folder's own `build/`, `.dart_tool/`, and plugin lists, kept between rounds."""
    return f"{IMAGE_NAME}-src-{target}"


def home_volume(target: str) -> str:
    """The named volume a sequence's launches share at `/root/.local/share`, the one place app data survives."""
    return f"{IMAGE_NAME}-home-{target}"


def container_name(target: str) -> str:
    """The name of the target's run container; pass it as `container` to `docker_run_argv`."""
    return f"{IMAGE_NAME}-run-{target}"


def host_pub_cache(environ: Mapping[str, str], home: Path) -> Path:
    """The host pub cache, mounted so private git dependencies fetched on the host resolve offline in the container."""
    return Path(environ.get("PUB_CACHE") or home / ".pub-cache")


def docker_run_argv(
    tag: str,
    repo_root: Path,
    app_rel: str,
    item_dir: Path,
    inner: str,
    container: str,
    sequence: bool,
    target: str,
) -> list[str]:
    """The `docker run` argv for one Linux run of the app at `repo_root/app_rel`.

    The repo mounts read-only at `/host`, and the script syncs it into the target's source volume at `/work`, where
    `flutter pub get`, the build, and `flutter test` run, so the container never writes the host tree. Each app
    folder keeps its own `build/` and `.dart_tool/` at its own path in that volume. The host pub cache mounts at
    `/root/.pub-cache`, and `item_dir` at `/round`, the one mount a run's results leave through (the report). A
    `sequence` also mounts the home volume so its launches share app data. `target` names every volume.
    The run carries `ROUND_LABEL` so a stray container is findable.

    The caller holds the per-target lane lock, so at most one container named `container` runs; it runs
    `remove_stale_container_argv(target)` first when a killed round may have left one, and passes
    `container_name(target)` as `container`. Raises `ValueError` for a relative `repo_root` or `item_dir`, or an
    `app_rel` that leaves the repo.
    """
    for name, path in (("repo_root", repo_root), ("item_dir", item_dir)):
        if not path.is_absolute():
            raise ValueError(f"{name} must be absolute, got {str(path)!r}")
    app = PurePosixPath(app_rel)
    if app.is_absolute() or ".." in app.parts:
        raise ValueError(f"app_rel must stay inside the repo, got {app_rel!r}")
    workdir = PurePosixPath("/work") / app
    home_mount = ["-v", f"{home_volume(target)}:/root/.local/share"] if sequence else []
    return [
        "docker",
        "run",
        "--rm",
        "--init",
        "--name",
        container,
        "--label",
        ROUND_LABEL,
        "-v",
        f"{repo_root}:/host:ro",
        "-v",
        f"{source_volume(target)}:/work",
        "-v",
        f"{host_pub_cache(os.environ, Path.home())}:/root/.pub-cache",
        *home_mount,
        "-v",
        f"{item_dir}:/round",
        "-w",
        str(workdir),
        tag,
        "bash",
        "-c",
        container_script(inner),
    ]


def remove_stale_container_argv(target: str) -> list[str]:
    """The argv that removes a container a killed round left under the target's run name; `-f` succeeds when none."""
    return ["docker", "rm", "-f", container_name(target)]


def reset_home_volume(runner: Runner, target: str) -> None:
    """Remove the target's home volume so a sequence's first launch starts with no app data.

    Task 9 or 13 calls it before launch 1 of a sequence, not after the last launch: a round that dies mid-sequence
    then never seeds the next one. A volume that does not exist counts as removed.
    Raises `RoundEnvError` when docker fails for another reason, such as a container still using the volume.
    """
    removed = runner.run(["docker", "volume", "rm", "-f", home_volume(target)])
    if removed.status != 0 and "no such volume" not in removed.stderr.lower():
        detail = (removed.stderr.strip().splitlines() or ["no output"])[-1]
        raise RoundEnvError(f"docker volume rm {home_volume(target)} failed (status {removed.status}): {detail}")


def linux_deps_resolve(
    runner: Runner, plugins_cmake: Path, pub_cache: Path, package_configs: Sequence[Path]
) -> DepsResolution:
    """Scan the plugins in `plugins_cmake` for the pkg-config modules they need and map them to Debian packages.

    Raises `RoundEnvError` when `plugins_cmake` is missing (run `flutter pub get`, or the app has no `linux/` folder)
    or the scan itself fails.
    """
    if not plugins_cmake.is_file():
        raise RoundEnvError(f"no {plugins_cmake}: nothing to scan (no linux/ folder, or run flutter pub get)")
    scan = runner.run(
        [
            "python3",
            "-I",
            "-c",
            LINUX_DEPS_PROGRAM,
            str(plugins_cmake),
            str(pub_cache),
            *(str(config) for config in package_configs),
        ]
    )
    if scan.status != 0:
        raise RoundEnvError(f"the plugin scan failed on {plugins_cmake}")
    lines: list[str] = []
    packages: set[str] = set()
    unknown: list[str] = []
    seen: set[str] = set()
    for row in scan.stdout.splitlines():
        words = row.split()
        if len(words) == 2 and words[0] == "unresolved":
            lines.append(
                f"unresolved plugin {words[1]}: no linux/CMakeLists.txt through package_config.json or {pub_cache}"
            )
        elif len(words) == 3 and words[0] == "module" and words[2] not in seen:
            module = words[2]
            seen.add(module)
            package = LINUX_MODULE_PACKAGES.get(module)
            if package is None:
                lines.append(f"unknown module {module}: add its -dev package to the target's apt list")
                unknown.append(module)
            else:
                lines.append(f"{module} -> {package}")
                packages.add(package)
    return DepsResolution(tuple(lines), tuple(sorted(packages)), tuple(unknown))


def flutter_version(runner: Runner) -> str:
    """The host's Flutter `frameworkVersion`, the tag the image clones; read once per round.

    Raises `RoundEnvError` when `flutter --version --machine` fails or prints no `frameworkVersion`.
    """
    probe = runner.run(["flutter", "--version", "--machine"])
    if probe.status != 0:
        raise RoundEnvError(f"flutter --version failed (status {probe.status}): {probe.stderr.strip()}")
    try:
        version = json.loads(probe.stdout)["frameworkVersion"]
    except (ValueError, KeyError, TypeError) as error:
        raise RoundEnvError("flutter --version --machine printed no frameworkVersion") from error
    if not isinstance(version, str) or not version:
        raise RoundEnvError("flutter --version --machine printed no frameworkVersion")
    return version


def check_packages(resolved: DepsResolution, target_apt: Sequence[str]) -> None:
    """Fail before any image build when a plugin needs a package the image and the target's apt list both lack.

    Ports `linux.sh::p_prepare` (`linux.sh:344-351`): a round that would fail at a CMake error minutes into a build
    fails in seconds instead. Raises `RoundEnvError` naming each missing package.
    """
    have = {*DEFAULT_PACKAGES, *target_apt}
    missing = [package for package in resolved.packages if package not in have]
    if missing:
        raise RoundEnvError(
            f"missing native packages: {' '.join(missing)}; add them to the target's apt list in e2e/targets.toml"
        )
