"""Unit tests for the e2e app build backend: a real git lists the files, a scripted flutter builds."""

from __future__ import annotations

import hashlib
import json
import subprocess
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any

import pytest

from stratum_e2e.round.app_build import (
    AppBuild,
    build_argv,
    ensure_app_build,
    flutter_output,
    resolve_app_packages,
    source_digest,
)
from stratum_e2e.round.errors import BuildFailure, RoundEnvError
from stratum_e2e.round.runner import Completed, Runner, SubprocessRunner
from unit.round_fakes import FakeRunner

OK = Completed(("flutter",), 0, "", "", False)
GITIGNORE = "build/\n.dart_tool/\nios/Flutter/Generated.xcconfig\nandroid/local.properties\n"


class BuildingRunner(FakeRunner):
    """A Runner for the app build: `git` runs for real, the toolchain answers from fields, `flutter build` is scripted.

    A successful scripted build leaves the artifact a real build leaves in `cwd/build/`, plus the `generated`
    files (relative to `cwd`) a real build leaves in the platform folders.
    """

    def __init__(self, script: Sequence[tuple[tuple[str, ...], Completed]], platform: str, wasm: bool) -> None:
        super().__init__(script)
        self._platform = platform
        self._wasm = wasm
        self._git = SubprocessRunner()
        self.engine = "engine-1"
        self.version_output: str | None = None
        self.xcode = "Xcode 26.0\nBuild version 17A1"
        self.generated: dict[str, str] = {}
        self.skip_artifact = False

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        if argv[0] == "git":
            self.calls.append(tuple(argv))
            return self._git.run(argv, timeout_s=timeout_s, cwd=cwd)
        if tuple(argv[:2]) == ("flutter", "--version"):
            self.calls.append(tuple(argv))
            info = json.dumps({"frameworkRevision": "framework-1", "engineRevision": self.engine})
            return Completed(tuple(argv), 0, self.version_output or f"Warning: noise\n{info}\n", "", False)
        if argv[0] == "xcodebuild":
            self.calls.append(tuple(argv))
            return Completed(tuple(argv), 0, self.xcode + "\n", "", False)
        done = super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)
        if done.status == 0 and cwd is not None and not self.skip_artifact:
            artifact = flutter_output(cwd, self._platform, self._wasm)
            if artifact.suffix == ".apk":
                artifact.parent.mkdir(parents=True, exist_ok=True)
                artifact.write_bytes(b"apk")
            else:
                (artifact / "contents").mkdir(parents=True, exist_ok=True)
                (artifact / "contents" / "index").write_text("built", encoding="utf-8")
            for name, text in self.generated.items():
                (cwd / name).parent.mkdir(parents=True, exist_ok=True)
                (cwd / name).write_text(text, encoding="utf-8")
        return done


def make_tree(root: Path, platform: str = "android") -> tuple[Path, Path]:
    """Lay out an app folder and a package root as a git repository, each with the sources the digest reads."""
    package = root / "package"
    app = package / "test_app"
    folders = (app / "lib", app / platform, app / "test", app / "integration_test")
    for folder in (*folders, package / "lib", package / "assets", package / "android", package / "darwin"):
        folder.mkdir(parents=True)
    (app / ".gitignore").write_text(GITIGNORE, encoding="utf-8")
    (app / "lib" / "main.dart").write_text("void main() {}", encoding="utf-8")
    (app / "pubspec.yaml").write_text("name: app", encoding="utf-8")
    (app / "pubspec.lock").write_text("packages: {}", encoding="utf-8")
    (app / platform / "Manifest").write_text("manifest", encoding="utf-8")
    (app / "test" / "a_test.dart").write_text("test", encoding="utf-8")
    (app / "integration_test" / "b_test.dart").write_text("test", encoding="utf-8")
    (package / "lib" / "x.dart").write_text("class X {}", encoding="utf-8")
    (package / "assets" / "theme.yaml").write_text("a: 1", encoding="utf-8")
    (package / "android" / "plugin.kt").write_text("plugin", encoding="utf-8")
    (package / "darwin" / "plugin.swift").write_text("plugin", encoding="utf-8")
    (package / "pubspec.yaml").write_text("name: pkg", encoding="utf-8")
    subprocess.run(["git", "init", "-q"], cwd=package, check=True)  # noqa: S607 - test setup in a temp dir
    return app, package


def runner_for(platform: str, wasm: bool, builds: int = 1) -> BuildingRunner:
    return BuildingRunner([(("flutter", "build"), OK)] * builds, platform, wasm)


def build_calls(runner: FakeRunner) -> list[tuple[str, ...]]:
    return [call for call in runner.calls if call[:2] == ("flutter", "build")]


def digest_for(app: Path, package: Path, platform: str, runner: Runner | None = None) -> str:
    """The digest of the tree as it stands, for the build a default call would run."""
    return source_digest(app, package, platform, build_argv(platform, False), runner or runner_for(platform, False))


@pytest.mark.parametrize(
    ("platform", "wasm", "expected"),
    [
        ("android", False, ["flutter", "build", "apk", "--debug"]),
        ("ios", False, ["flutter", "build", "ios", "--simulator", "--debug"]),
        ("macos", False, ["flutter", "build", "macos", "--debug"]),
        ("web", False, ["flutter", "build", "web", "-o", "build/web_js"]),
        ("web", True, ["flutter", "build", "web", "--wasm", "-o", "build/web_wasm"]),
    ],
)
def test_build_argv_per_platform(platform: str, wasm: bool, expected: list[str]) -> None:
    assert build_argv(platform, wasm) == expected


def test_build_argv_rejects_a_platform_it_does_not_build() -> None:
    with pytest.raises(ValueError, match="linux"):
        build_argv("linux", False)


def test_build_argv_rejects_wasm_off_the_web() -> None:
    with pytest.raises(ValueError, match="wasm"):
        build_argv("android", True)


@pytest.mark.parametrize(
    ("platform", "wasm", "expected"),
    [
        ("android", False, "build/app/outputs/flutter-apk/app-debug.apk"),
        ("ios", False, "build/ios/iphonesimulator/Runner.app"),
        ("macos", False, "build/macos/Build/Products/Debug/stratum_ui_test_app.app"),
        ("web", False, "build/web_js"),
        ("web", True, "build/web_wasm"),
    ],
)
def test_flutter_output_per_platform(tmp_path: Path, platform: str, wasm: bool, expected: str) -> None:
    assert flutter_output(tmp_path, platform, wasm) == tmp_path / expected


def test_first_call_builds_and_returns_the_copy(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)

    result = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert result.reused is False
    assert result.argv == ("flutter", "build", "apk", "--debug")
    assert result.seconds >= 0.0
    assert result.path.read_bytes() == b"apk"
    assert build_calls(runner) == [("flutter", "build", "apk", "--debug")]


def test_unchanged_sources_reuse_the_copy(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    first = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    second = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert second == AppBuild(path=first.path, argv=first.argv, seconds=0.0, reused=True)
    assert len(build_calls(runner)) == 1


def test_changed_package_lib_rebuilds(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False, builds=2)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (package / "lib" / "x.dart").write_text("class X { int y = 1; }", encoding="utf-8")
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is False
    assert len(build_calls(runner)) == 2


def test_changed_app_platform_folder_rebuilds(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False, builds=2)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / "android" / "Manifest").write_text("changed", encoding="utf-8")
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is False


def test_build_folder_changes_do_not_rebuild(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / "build").mkdir(exist_ok=True)
    (app / "build" / "noise").write_text("x", encoding="utf-8")
    (app / "android" / "build").mkdir()
    (app / "android" / "build" / "noise").write_text("x", encoding="utf-8")
    (app / ".dart_tool").mkdir()
    (app / ".dart_tool" / "package_config.json").write_text("x", encoding="utf-8")
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is True
    assert len(build_calls(runner)) == 1


def test_missing_stamp_rebuilds(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False, builds=2)
    first = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (first.path.parent / ".digest").unlink()
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is False


def test_missing_copy_rebuilds(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False, builds=2)
    first = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    first.path.unlink()
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is False
    assert again.path.read_bytes() == b"apk"


def test_js_and_wasm_digests_differ(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path, platform="web")
    runner = runner_for("web", False)

    js = source_digest(app, package, "web", build_argv("web", False), runner)
    wasm = source_digest(app, package, "web", build_argv("web", True), runner)

    assert js != wasm
    assert js == source_digest(app, package, "web", build_argv("web", False), runner)


def test_digest_is_content_not_mtime(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    before = digest_for(app, package, "android")

    source = package / "lib" / "x.dart"
    source.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")

    assert digest_for(app, package, "android") == before


def test_digest_tells_app_files_from_package_files(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    before = digest_for(app, package, "android")

    (package / "lib" / "x.dart").rename(package / "lib" / "y.dart")

    assert digest_for(app, package, "android") != before


def test_generated_files_a_build_writes_do_not_change_the_digest(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    runner.generated = {
        "ios/Flutter/Generated.xcconfig": "FLUTTER_ROOT=/sdk",
        "android/local.properties": "flutter.buildMode=debug",
    }
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is True
    assert len(build_calls(runner)) == 1


def test_build_mode_flip_in_local_properties_does_not_rebuild(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    runner.generated = {"android/local.properties": "flutter.buildMode=debug"}
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / "android" / "local.properties").write_text("flutter.buildMode=profile", encoding="utf-8")
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is True


def test_untracked_authored_file_rebuilds(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False, builds=2)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / "lib" / "added.dart").write_text("class Added {}", encoding="utf-8")
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is False


def test_tracked_file_edit_and_delete_rebuild(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    subprocess.run(["git", "add", "-A"], cwd=package, check=True)  # noqa: S607 - test setup in a temp dir
    runner = runner_for("android", False, builds=3)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / "lib" / "main.dart").write_text("void main() { run(); }", encoding="utf-8")
    edited = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")
    (app / "lib" / "main.dart").unlink()
    deleted = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert (edited.reused, deleted.reused) == (False, False)


@pytest.mark.parametrize("folder", ["test", "integration_test"])
def test_app_test_folders_do_not_rebuild(tmp_path: Path, folder: str) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / folder / "c_test.dart").write_text("more tests", encoding="utf-8")
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is True


def test_changed_engine_revision_changes_the_digest(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False, builds=2)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    runner.engine = "engine-2"
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is False
    assert len(build_calls(runner)) == 2


@pytest.mark.parametrize("platform", ["ios", "macos"])
def test_changed_xcode_version_changes_the_apple_digest(tmp_path: Path, platform: str) -> None:
    app, package = make_tree(tmp_path, platform=platform)
    runner = runner_for(platform, False)
    before = digest_for(app, package, platform, runner)

    runner.xcode = "Xcode 26.1\nBuild version 17B1"

    assert digest_for(app, package, platform, runner) != before


def test_xcode_is_only_asked_for_apple_platforms(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)

    digest_for(app, package, "android", runner)

    assert not [call for call in runner.calls if call[0] == "xcodebuild"]


def test_darwin_edit_leaves_the_android_digest_alone(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    before = digest_for(app, package, "android")

    (package / "darwin" / "plugin.swift").write_text("changed", encoding="utf-8")

    assert digest_for(app, package, "android") == before


@pytest.mark.parametrize(("platform", "own", "other"), [("ios", "darwin", "android"), ("macos", "darwin", "android")])
def test_apple_digests_read_darwin_not_android(tmp_path: Path, platform: str, own: str, other: str) -> None:
    app, package = make_tree(tmp_path, platform=platform)
    before = digest_for(app, package, platform)

    (package / other / "plugin.kt").write_text("changed", encoding="utf-8")
    assert digest_for(app, package, platform) == before

    (package / own / "plugin.swift").write_text("changed", encoding="utf-8")
    assert digest_for(app, package, platform) != before


def test_android_digest_reads_the_package_android_folder(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    before = digest_for(app, package, "android")

    (package / "android" / "plugin.kt").write_text("changed", encoding="utf-8")

    assert digest_for(app, package, "android") != before


def test_web_digest_reads_neither_package_platform_folder(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path, platform="web")
    before = digest_for(app, package, "web")

    (package / "android" / "plugin.kt").write_text("changed", encoding="utf-8")
    (package / "darwin" / "plugin.swift").write_text("changed", encoding="utf-8")

    assert digest_for(app, package, "web") == before


@pytest.mark.parametrize("shared", ["lib/x.dart", "assets/theme.yaml", "pubspec.yaml"])
def test_every_platform_reads_the_shared_package_sources(tmp_path: Path, shared: str) -> None:
    app, package = make_tree(tmp_path, platform="web")
    before = digest_for(app, package, "web")

    (package / shared).write_text("changed", encoding="utf-8")

    assert digest_for(app, package, "web") != before


def test_digest_rejects_a_platform_it_does_not_build(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)

    with pytest.raises(ValueError, match="linux"):
        source_digest(app, package, "linux", ["flutter"], runner_for("android", False))


def test_outside_a_git_repository_is_env(tmp_path: Path) -> None:
    app = tmp_path / "plain" / "app"
    (app / "lib").mkdir(parents=True)
    runner = runner_for("android", False)

    with pytest.raises(RoundEnvError, match="git ls-files"):
        source_digest(app, app.parent, "android", build_argv("android", False), runner)


def test_unreadable_flutter_version_is_env(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    runner.version_output = "not json at all\n"

    with pytest.raises(RoundEnvError, match="engine revision"):
        source_digest(app, package, "android", build_argv("android", False), runner)


def test_artifact_is_copied_out_of_the_flutter_build_folder(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path, platform="web")
    runner = runner_for("web", True)

    result = ensure_app_build(app, package, "web", True, runner, tmp_path / "build.log")

    assert result.path == app / "build" / "e2e" / "web-wasm" / "web_wasm"
    assert (result.path / "contents" / "index").read_text(encoding="utf-8") == "built"
    assert (result.path.parent / ".digest").is_file()


def test_js_and_wasm_copies_live_side_by_side(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path, platform="web")
    js = ensure_app_build(app, package, "web", False, runner_for("web", False), tmp_path / "build.log")
    wasm = ensure_app_build(app, package, "web", True, runner_for("web", True), tmp_path / "build.log")

    assert js.path == app / "build" / "e2e" / "web" / "web_js"
    assert js.path.is_dir() and wasm.path.is_dir()


def test_later_flutter_build_does_not_touch_the_copy(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    result = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    flutter_output(app, "android", False).write_bytes(b"overwritten by an integration run")

    assert result.path.read_bytes() == b"apk"


@pytest.mark.parametrize(
    ("stdout", "stderr", "reason"),
    [
        ("", "Gradle task assembleDebug failed\n", "flutter build apk --debug failed (exit 1)"),
        (
            "lib/main.dart:1:13: Error: Expected a declaration, but got '}'.\n", "Error: Gradle task failed\n",
            "lib/main.dart:1:13: Error: Expected a declaration, but got '}'.",
        ),
    ],
)
def test_failed_build_is_a_build_failure_with_its_log(tmp_path: Path, stdout: str, stderr: str, reason: str) -> None:
    app, package = make_tree(tmp_path)
    failed = Completed(("flutter",), 1, stdout, stderr, False)
    runner = BuildingRunner([(("flutter", "build"), failed)], "android", False)

    with pytest.raises(BuildFailure) as raised:
        ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert raised.value.reason == reason
    assert (raised.value.log, raised.value.argv) == (tmp_path / "build.log", ("flutter", "build", "apk", "--debug"))
    assert raised.value.seconds >= 0
    assert not (app / "build" / "e2e").exists()


def test_failed_rebuild_drops_the_stale_copy(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    failed = Completed(("flutter",), 1, "", "boom\n", False)
    runner = BuildingRunner([(("flutter", "build"), OK), (("flutter", "build"), failed)], "android", False)
    first = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (package / "lib" / "x.dart").write_text("class X { int y = 1; }", encoding="utf-8")
    with pytest.raises(BuildFailure):
        ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert not first.path.exists()


def test_build_without_an_artifact_is_a_build_failure(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = BuildingRunner([(("flutter", "build"), OK)], "android", False)
    runner.skip_artifact = True

    with pytest.raises(BuildFailure, match="produced no"):
        ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")


VERSION = "3.99.0"


def _resolve(app: Path, runner: Runner, tmp_path: Path, version: str = VERSION) -> None:
    resolve_app_packages(app, app.parent, version, runner, tmp_path / "pub_get.log")


def _mark_resolved(app: Path, tmp_path: Path) -> None:
    """Leave the `.dart_tool` of a finished host resolve: a package config and the current key."""
    _resolve(app, FakeRunner([(("flutter", "pub", "get", "--offline"), OK)]), tmp_path)
    (app / ".dart_tool" / "package_config.json").write_text("{}", encoding="utf-8")


def test_resolve_runs_pub_get_offline_in_the_app_folder_and_stamps_the_key(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    runner = FakeRunner([(("flutter", "pub", "get", "--offline"), OK)])

    _resolve(app, runner, tmp_path)

    assert runner.calls == [("flutter", "pub", "get", "--offline")]
    assert (app / ".dart_tool" / ".dt-lock-hash").read_text(encoding="utf-8").endswith(f" {app.resolve()}")


def test_resolve_falls_back_to_online_when_offline_fails(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    offline = Completed(("flutter",), 1, "", "Because x was not found in the cache\n", False)
    runner = FakeRunner([(("flutter", "pub", "get", "--offline"), offline), (("flutter", "pub", "get"), OK)])

    _resolve(app, runner, tmp_path)

    assert runner.calls == [("flutter", "pub", "get", "--offline"), ("flutter", "pub", "get")]
    assert (app / ".dart_tool" / ".dt-lock-hash").is_file()


def test_each_resolve_attempt_writes_its_own_log(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    logs: list[Path | None] = []

    class LoggingRunner(FakeRunner):
        def run(self, argv: Sequence[str], **kwargs: Any) -> Completed:
            logs.append(kwargs.get("log"))
            return super().run(argv, **kwargs)

    offline = Completed(("flutter",), 1, "", "cache miss\n", False)
    runner = LoggingRunner([(("flutter", "pub", "get", "--offline"), offline), (("flutter", "pub", "get"), OK)])

    _resolve(app, runner, tmp_path)

    assert logs == [tmp_path / "pub_get_offline.log", tmp_path / "pub_get.log"]


def test_resolve_that_fails_online_too_is_env_names_both_exits_and_leaves_no_stamp(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    offline = Completed(("flutter",), 66, "", "cache miss\n", False)
    online = Completed(("flutter",), 69, "", "Could not resolve host pub.dev\n", False)
    runner = FakeRunner([(("flutter", "pub", "get", "--offline"), offline), (("flutter", "pub", "get"), online)])

    with pytest.raises(RoundEnvError, match=r"offline exit 66, online exit 69") as raised:
        _resolve(app, runner, tmp_path)

    assert "Could not resolve host pub.dev" in raised.value.reason
    assert not (app / ".dart_tool" / ".dt-lock-hash").exists()


def test_resolve_is_skipped_while_the_key_and_the_package_config_are_current(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    _mark_resolved(app, tmp_path)
    runner = FakeRunner([])

    _resolve(app, runner, tmp_path)

    assert runner.calls == []


def _assert_resolves_again(app: Path, tmp_path: Path, version: str = VERSION) -> None:
    runner = FakeRunner([(("flutter", "pub", "get", "--offline"), OK)])
    _resolve(app, runner, tmp_path, version)
    assert runner.calls == [("flutter", "pub", "get", "--offline")]


def test_resolve_runs_again_when_the_lock_changed(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    _mark_resolved(app, tmp_path)
    (app / "pubspec.lock").write_text("packages: {a: 1}", encoding="utf-8")

    _assert_resolves_again(app, tmp_path)


def test_resolve_runs_again_when_the_app_pubspec_changed(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    _mark_resolved(app, tmp_path)
    (app / "pubspec.yaml").write_text("name: app\ndependencies: {webview: any}", encoding="utf-8")

    _assert_resolves_again(app, tmp_path)


def test_resolve_runs_again_when_the_package_roots_pubspec_changed(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    (package / "pubspec.yaml").write_text("name: root", encoding="utf-8")
    _mark_resolved(app, tmp_path)
    (package / "pubspec.yaml").write_text("name: root\ndependencies: {plugin: any}", encoding="utf-8")

    _assert_resolves_again(app, tmp_path)


def test_resolve_runs_again_when_overrides_were_added(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    _mark_resolved(app, tmp_path)
    (app / "pubspec_overrides.yaml").write_text("dependency_overrides: {}", encoding="utf-8")

    _assert_resolves_again(app, tmp_path)


def test_resolve_runs_again_when_the_flutter_version_changed(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    _mark_resolved(app, tmp_path)

    _assert_resolves_again(app, tmp_path, version="3.100.0")


def test_resolve_runs_again_when_the_package_config_is_gone(tmp_path: Path) -> None:
    app, _ = make_tree(tmp_path)
    _mark_resolved(app, tmp_path)
    (app / ".dart_tool" / "package_config.json").unlink()

    _assert_resolves_again(app, tmp_path)


def test_resolve_runs_again_when_the_stamp_is_the_containers_bare_hash(tmp_path: Path) -> None:
    """The Linux container writes the bare lock hash beside a package config of its own paths."""
    app, _ = make_tree(tmp_path)
    _mark_resolved(app, tmp_path)
    bare = hashlib.sha256((app / "pubspec.lock").read_bytes()).hexdigest()
    (app / ".dart_tool" / ".dt-lock-hash").write_text(bare, encoding="utf-8")

    _assert_resolves_again(app, tmp_path)
