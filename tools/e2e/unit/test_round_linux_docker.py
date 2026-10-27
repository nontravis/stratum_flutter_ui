"""Unit tests for the Linux docker image and run wrapper, with a scripted docker and no container."""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from stratum_e2e.round import linux_docker
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.linux_docker import (
    DEFAULT_PACKAGES,
    DOCKERFILE,
    IMAGE_NAME,
    LINUX_MODULE_PACKAGES,
    ROUND_LABEL,
    SYNC_EXCLUDES,
    DepsResolution,
    check_packages,
    container_name,
    container_script,
    docker_run_argv,
    ensure_image,
    flutter_version,
    home_volume,
    image_tag,
    inner_command,
    linux_deps_resolve,
    linux_pub_gate,
    remove_stale_container_argv,
    reset_home_volume,
    source_volume,
)
from stratum_e2e.round.runner import Completed, SubprocessRunner
from unit.round_fakes import FakeRunner

Entry = tuple[tuple[str, ...], Completed]
DOCKERFILE_TEXT = "FROM ubuntu:24.04\n"
LINUX = Target(name="linux", platform="linux", apt=("libwebkit2gtk-4.1-dev", "libsecret-1-dev"), e2e=False)


def done(status: int = 0, stdout: str = "", stderr: str = "") -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr=stderr, timed_out=False)


def argv_pair(argv: list[str], flag: str, value: str) -> bool:
    """Whether `flag value` sits side by side in `argv`."""
    return any(argv[i] == flag and argv[i + 1] == value for i in range(len(argv) - 1))


def test_image_tag_changes_with_dockerfile_or_apt() -> None:
    base = image_tag("3.47.7", DOCKERFILE_TEXT, ["a-dev", "b-dev"])

    assert image_tag("3.47.7", DOCKERFILE_TEXT, ["b-dev", "a-dev"]) == base
    assert image_tag("3.47.7", DOCKERFILE_TEXT + "RUN true\n", ["a-dev", "b-dev"]) != base
    assert image_tag("3.47.7", DOCKERFILE_TEXT, ["a-dev"]) != base
    assert image_tag("3.47.8", DOCKERFILE_TEXT, ["a-dev", "b-dev"]) != base


def test_image_tag_shape() -> None:
    tag = image_tag("3.47.7", DOCKERFILE_TEXT, [])

    assert re.fullmatch(r"stratum-e2e-linux:3\.47\.7-[0-9a-f]{8}", tag)
    assert tag.startswith(f"{IMAGE_NAME}:")


def test_existing_image_is_not_rebuilt() -> None:
    tag = image_tag("3.47.7", DOCKERFILE.read_text(encoding="utf-8"), LINUX.apt)
    runner = FakeRunner([(("docker", "image", "inspect", tag), done())])

    assert ensure_image(runner, LINUX, "3.47.7") == tag
    assert runner.calls == [("docker", "image", "inspect", tag)]


def test_missing_image_is_built_from_the_e2e_dockerfile() -> None:
    tag = image_tag("3.47.7", DOCKERFILE.read_text(encoding="utf-8"), LINUX.apt)
    build = (
        "docker",
        "build",
        "-f",
        str(DOCKERFILE),
        "--build-arg",
        "FLUTTER_VERSION=3.47.7",
        "--build-arg",
        "EXTRA_APT=libsecret-1-dev libwebkit2gtk-4.1-dev",
        "-t",
        tag,
        str(DOCKERFILE.parent),
    )
    runner = FakeRunner([(("docker", "image", "inspect", tag), done(1)), (build, done())])

    assert ensure_image(runner, LINUX, "3.47.7") == tag
    assert runner.calls[-1] == build


def test_failed_build_is_an_env_error() -> None:
    runner = FakeRunner(
        [(("docker", "image", "inspect"), done(1)), (("docker", "build"), done(1, stderr="no space left on device\n"))]
    )

    with pytest.raises(RoundEnvError, match="no space left on device"):
        ensure_image(runner, LINUX, "3.47.7")


def test_inner_command_runs_xvfb_flutter_test() -> None:
    command = inner_command(["common/a_linux_test.dart"], None)

    assert command == (
        "xvfb-run flutter test common/a_linux_test.dart -d linux --no-pub --reporter expanded "
        "--file-reporter json:/round/report.json"
    )


def test_inner_command_quotes_plain_name() -> None:
    command = inner_command(["a_test.dart"], "group B, native only")

    assert command.endswith("--plain-name 'group B, native only'")
    assert "--no-uninstall" not in command


def test_inner_command_writes_the_report_it_is_given() -> None:
    command = inner_command(["a_linux_test.dart"], None, "report.2.json")

    assert command.endswith("--file-reporter json:/round/report.2.json")
    assert "--no-uninstall" not in command


def argv_for(*, sequence: bool = False, inner: str = "echo hi") -> list[str]:
    return docker_run_argv(
        "stratum-e2e-linux:3.47.7-abcd1234",
        Path("/repo"),
        "test_app",
        Path("/repo/.round/item"),
        inner,
        "stratum-e2e-linux-run",
        sequence,
        "linux",
    )


def test_docker_run_argv_mounts_repo_and_round_dir(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PUB_CACHE", "/cache/pub")

    argv = argv_for()

    assert argv[:5] == ["docker", "run", "--rm", "--init", "--name"]
    assert argv[5] == "stratum-e2e-linux-run"
    assert argv_pair(argv, "-v", "/repo:/host:ro")
    assert argv_pair(argv, "-v", "stratum-e2e-linux-src-linux:/work")
    assert argv_pair(argv, "-v", "/cache/pub:/root/.pub-cache")
    assert argv_pair(argv, "-v", "/repo/.round/item:/round")
    assert argv_pair(argv, "-w", "/work/test_app")
    assert argv[argv.index("stratum-e2e-linux:3.47.7-abcd1234") + 1 : -1] == ["bash", "-c"]


def mounts_of(argv: list[str]) -> list[str]:
    return [argv[i + 1] for i in range(len(argv) - 1) if argv[i] == "-v"]


@pytest.mark.parametrize("sequence", [False, True])
def test_docker_run_argv_never_mounts_the_host_tree_read_write(
    monkeypatch: pytest.MonkeyPatch, sequence: bool
) -> None:
    monkeypatch.setenv("PUB_CACHE", "/cache/pub")

    for mount in mounts_of(argv_for(sequence=sequence)):
        source, target, *mode = mount.split(":")
        if source.startswith("/repo"):
            # The host tree is read-only; only the item dir comes back, mounted for results alone.
            assert mode == ["ro"] or (source == "/repo/.round/item" and target == "/round"), mount


def test_docker_run_argv_keeps_each_apps_build_state_in_the_work_volume() -> None:
    targets = [mount.split(":")[1] for mount in mounts_of(argv_for())]

    assert not [target for target in targets if target.endswith(("/build", "/.dart_tool"))]
    assert "/work" in targets


def test_round_docker_names_never_reuse_the_bash_tools() -> None:
    names = [source_volume("linux"), home_volume("linux"), container_name("linux")]

    assert all(name.startswith(f"{IMAGE_NAME}-") for name in names)
    assert not [name for name in names if name.startswith("dt-")]
    assert len(set(names)) == 3


def test_container_script_syncs_the_host_tree_before_the_gates() -> None:
    script = container_script("xvfb-run flutter test a_test.dart")
    sync = script[: script.index(" || ")]

    assert sync.startswith("rsync -a --delete ")
    assert sync.endswith(" /host/ /work/")
    for pattern in SYNC_EXCLUDES:
        assert f"--exclude={pattern}" in sync
    assert script.index("rsync") < script.index("build/.dt-last-exit") < script.index("flutter pub get")


def test_sync_excludes_the_host_only_trees() -> None:
    for pattern in ("/.git", "/.worktrees", "/tmp", "build/", ".dart_tool/", ".flutter-plugins-dependencies"):
        assert pattern in SYNC_EXCLUDES


def test_dockerfile_installs_rsync_for_the_source_sync() -> None:
    assert re.search(r"apt-get install[^;]*\brsync\b", DOCKERFILE.read_text(encoding="utf-8"))


def test_docker_run_argv_defaults_the_pub_cache_to_the_home_folder(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("PUB_CACHE", raising=False)

    argv = argv_for()

    assert argv_pair(argv, "-v", f"{Path.home()}/.pub-cache:/root/.pub-cache")


def test_docker_run_argv_mounts_the_home_volume_only_for_a_sequence() -> None:
    assert argv_pair(argv_for(sequence=True), "-v", f"{home_volume('linux')}:/root/.local/share")
    assert not any(part.endswith(":/root/.local/share") for part in argv_for(sequence=False))


def test_docker_run_argv_runs_the_inner_command_after_the_gates() -> None:
    script = argv_for(inner="xvfb-run flutter test a_test.dart")[-1]

    assert script == container_script("xvfb-run flutter test a_test.dart")
    assert script.index("build/.dt-last-exit") < script.index("flutter pub get") < script.index("xvfb-run flutter test")
    assert script.endswith('rc=$?; echo "$rc" > build/.dt-last-exit; exit "$rc"')


@pytest.mark.parametrize("app_rel", ["/abs/app", "../outside", "a/../../b"])
def test_docker_run_argv_refuses_an_app_outside_the_repo(app_rel: str) -> None:
    with pytest.raises(ValueError, match="app_rel"):
        docker_run_argv("t", Path("/repo"), app_rel, Path("/i"), "x", "c", False, "linux")


def test_container_script_wipes_a_stale_cmake_build_dir() -> None:
    script = container_script("true")

    assert 'rm -rf "$d"' in script
    assert "previous exit $prev" in script
    assert "install prefix $p" in script


def test_linux_pub_gate_is_the_ported_script() -> None:
    gate = linux_pub_gate()

    assert "pubspec.lock" in gate
    assert ".dart_tool/.dt-lock-hash" in gate
    assert "flutter pub get --offline" in gate
    assert '"rootUri\\": *\\"file:///[^/\\"]+"' in gate


def write_plugins(tmp_path: Path, plugin_names: list[str]) -> Path:
    cmake = tmp_path / "app" / "linux" / "flutter" / "generated_plugins.cmake"
    cmake.parent.mkdir(parents=True)
    cmake.write_text(f"list(APPEND FLUTTER_PLUGIN_LIST\n  {chr(10).join('  ' + n for n in plugin_names)}\n)\n")
    return cmake


def write_plugin_package(tmp_path: Path, name: str, cmake_body: str) -> dict[str, str]:
    root = tmp_path / "pkgs" / name
    (root / "linux").mkdir(parents=True)
    (root / "linux" / "CMakeLists.txt").write_text(cmake_body)
    return {"name": name, "rootUri": root.as_uri(), "packageUri": "lib/"}


def test_linux_deps_resolve_maps_plugins_and_flags_unknown(tmp_path: Path) -> None:
    cmake = write_plugins(tmp_path, ["flutter_secure_storage_linux", "webview_all_linux", "odd_plugin", "lost_plugin"])
    packages = [
        write_plugin_package(
            tmp_path,
            "flutter_secure_storage_linux",
            "pkg_check_modules(LIBSECRET REQUIRED IMPORTED_TARGET libsecret-1>=0.18.4)\n",
        ),
        write_plugin_package(
            tmp_path,
            "webview_all_linux",
            "pkg_check_modules(WEBKIT REQUIRED IMPORTED_TARGET webkit2gtk-4.1)\n"
            "pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)  # gtk comment\n",
        ),
        write_plugin_package(tmp_path, "odd_plugin", "pkg_check_modules(ODD REQUIRED IMPORTED_TARGET oddlib-9)\n"),
    ]
    config = tmp_path / "package_config.json"
    config.write_text(json.dumps({"configVersion": 2, "packages": packages}))

    result = linux_deps_resolve(SubprocessRunner(), cmake, tmp_path / "pub-cache", [config, tmp_path / "missing.json"])

    assert result.packages == ("libgtk-3-dev", "libsecret-1-dev", "libwebkit2gtk-4.1-dev")
    assert result.unknown == ("oddlib-9",)
    assert "libsecret-1 -> libsecret-1-dev" in result.lines
    assert "webkit2gtk-4.1 -> libwebkit2gtk-4.1-dev" in result.lines
    assert any(line.startswith("unknown module oddlib-9:") for line in result.lines)
    assert any(line.startswith("unresolved plugin lost_plugin:") for line in result.lines)


def test_linux_deps_resolve_lists_a_shared_module_once(tmp_path: Path) -> None:
    cmake = write_plugins(tmp_path, ["one", "two"])
    packages = [
        write_plugin_package(tmp_path, "one", "pkg_check_modules(A REQUIRED gtk+-3.0)\n"),
        write_plugin_package(tmp_path, "two", "pkg_check_modules(B REQUIRED gtk+-3.0)\n"),
    ]
    config = tmp_path / "package_config.json"
    config.write_text(json.dumps({"packages": packages}))

    result = linux_deps_resolve(SubprocessRunner(), cmake, tmp_path / "pub-cache", [config])

    assert result.lines == ("gtk+-3.0 -> libgtk-3-dev",)
    assert result.packages == ("libgtk-3-dev",)


def test_linux_deps_resolve_missing_plugin_list_is_env(tmp_path: Path) -> None:
    runner = FakeRunner([])

    with pytest.raises(RoundEnvError, match="generated_plugins.cmake"):
        linux_deps_resolve(runner, tmp_path / "nope" / "generated_plugins.cmake", tmp_path, [])

    assert runner.calls == []


def test_linux_deps_resolve_scan_failure_is_env(tmp_path: Path) -> None:
    cmake = write_plugins(tmp_path, ["one"])
    runner = FakeRunner([(("python3", "-I", "-c"), done(1, stderr="Traceback"))])

    with pytest.raises(RoundEnvError, match="plugin scan failed"):
        linux_deps_resolve(runner, cmake, tmp_path, [])


def test_module_table_covers_the_dockerfile_default_packages() -> None:
    assert LINUX_MODULE_PACKAGES["libsecret-1"] == "libsecret-1-dev"
    assert LINUX_MODULE_PACKAGES["gtk+-3.0"] == "libgtk-3-dev"


def test_flutter_version_reads_the_machine_json() -> None:
    runner = FakeRunner(
        [(("flutter", "--version", "--machine"), done(stdout=json.dumps({"frameworkVersion": "3.47.7"})))]
    )

    assert flutter_version(runner) == "3.47.7"


def test_flutter_version_without_flutter_is_env() -> None:
    runner = FakeRunner([(("flutter", "--version", "--machine"), done(127, stderr="flutter: not found"))])

    with pytest.raises(RoundEnvError, match="flutter --version"):
        flutter_version(runner)


@pytest.mark.parametrize("stdout", ["not json", json.dumps({"channel": "stable"})])
def test_flutter_version_unreadable_output_is_env(stdout: str) -> None:
    runner = FakeRunner([(("flutter", "--version", "--machine"), done(stdout=stdout))])

    with pytest.raises(RoundEnvError, match="frameworkVersion"):
        flutter_version(runner)


def test_dockerfile_moved_under_e2e() -> None:
    assert DOCKERFILE == linux_docker.E2E_ROOT / "docker" / "linux.Dockerfile"
    assert DOCKERFILE.is_file()
    assert "FROM ubuntu:24.04" in DOCKERFILE.read_text(encoding="utf-8")


def test_inner_command_without_files_is_refused() -> None:
    with pytest.raises(ValueError, match="at least one test file"):
        inner_command([], None)


@pytest.mark.parametrize("field", ["repo_root", "item_dir"])
def test_docker_run_argv_refuses_a_relative_mount_source(field: str) -> None:
    mounts = {"repo_root": Path("/repo"), "item_dir": Path("/repo/.round/item")}
    mounts[field] = Path("relative/dir")

    with pytest.raises(ValueError, match=field):
        docker_run_argv("t", mounts["repo_root"], "test_app", mounts["item_dir"], "x", "c", False, "linux")


def test_docker_run_argv_labels_the_run() -> None:
    assert argv_pair(argv_for(), "--label", ROUND_LABEL)
    assert ROUND_LABEL == "stratum-e2e-round=1"


def test_remove_stale_container_argv_names_the_runs_container() -> None:
    argv = remove_stale_container_argv("linux")

    assert argv == ["docker", "rm", "-f", container_name("linux")]
    run = docker_run_argv("t", Path("/repo"), "test_app", Path("/i"), "x", container_name("linux"), False, "linux")
    assert run[run.index("--name") + 1] == argv[-1]


def test_reset_home_volume_removes_the_targets_home_volume() -> None:
    runner = FakeRunner([(("docker", "volume", "rm", "-f", home_volume("linux")), done())])

    reset_home_volume(runner, "linux")

    assert runner.calls == [("docker", "volume", "rm", "-f", home_volume("linux"))]


def test_reset_home_volume_treats_no_such_volume_as_success() -> None:
    runner = FakeRunner([(("docker", "volume", "rm"), done(1, stderr=f"Error: No such volume: {home_volume('linux')}\n"))])

    reset_home_volume(runner, "linux")


def test_reset_home_volume_surfaces_a_volume_in_use_as_env() -> None:
    runner = FakeRunner([(("docker", "volume", "rm"), done(1, stderr="volume is in use - [abc123]\n"))])

    with pytest.raises(RoundEnvError, match="volume is in use"):
        reset_home_volume(runner, "linux")


def resolution(*packages: str) -> DepsResolution:
    return DepsResolution(lines=(), packages=tuple(sorted(packages)), unknown=())


def test_check_packages_names_each_package_the_image_and_apt_lack() -> None:
    resolved = resolution("libwebkit2gtk-4.1-dev", "libnotify-dev", "libgtk-3-dev")

    with pytest.raises(RoundEnvError, match="libnotify-dev libwebkit2gtk-4.1-dev"):
        check_packages(resolved, [])


def test_check_packages_accepts_image_defaults_and_the_targets_apt() -> None:
    resolved = resolution("libgtk-3-dev", "libsecret-1-dev", "libwebkit2gtk-4.1-dev")

    check_packages(resolved, ["libwebkit2gtk-4.1-dev"])


def test_default_packages_match_the_dockerfile() -> None:
    text = DOCKERFILE.read_text(encoding="utf-8")

    assert all(package in text for package in DEFAULT_PACKAGES)
