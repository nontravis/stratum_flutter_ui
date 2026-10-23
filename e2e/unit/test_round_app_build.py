"""Unit tests for the e2e app build backend, with a scripted flutter that writes a fake artifact."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest

from stratum_e2e.round.app_build import (
    AppBuild,
    build_argv,
    ensure_app_build,
    flutter_output,
    source_digest,
)
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner

OK = Completed(("flutter",), 0, "", "", False)


class BuildingRunner(FakeRunner):
    """A FakeRunner whose `flutter build` leaves the artifact a real build would leave in `cwd/build/`."""

    def __init__(self, script: Sequence[tuple[tuple[str, ...], Completed]], platform: str, wasm: bool) -> None:
        super().__init__(script)
        self._platform = platform
        self._wasm = wasm

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        done = super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)
        if done.status == 0 and cwd is not None:
            artifact = flutter_output(cwd, self._platform, self._wasm)
            if artifact.suffix == ".apk":
                artifact.parent.mkdir(parents=True, exist_ok=True)
                artifact.write_bytes(b"apk")
            else:
                (artifact / "contents").mkdir(parents=True, exist_ok=True)
                (artifact / "contents" / "index").write_text("built", encoding="utf-8")
        return done


def make_tree(root: Path, platform: str = "android") -> tuple[Path, Path]:
    """Lay out an app folder and a package root, each with the sources the digest reads."""
    package = root / "package"
    app = package / "test_app"
    for folder in (app / "lib", app / platform, package / "lib", package / "assets", package / "android"):
        folder.mkdir(parents=True)
    (app / "lib" / "main.dart").write_text("void main() {}", encoding="utf-8")
    (app / "pubspec.yaml").write_text("name: app", encoding="utf-8")
    (app / "pubspec.lock").write_text("packages: {}", encoding="utf-8")
    (app / platform / "Manifest").write_text("manifest", encoding="utf-8")
    (package / "lib" / "x.dart").write_text("class X {}", encoding="utf-8")
    (package / "assets" / "theme.yaml").write_text("a: 1", encoding="utf-8")
    (package / "android" / "plugin.kt").write_text("plugin", encoding="utf-8")
    (package / "pubspec.yaml").write_text("name: pkg", encoding="utf-8")
    return app, package


def runner_for(platform: str, wasm: bool, builds: int = 1) -> BuildingRunner:
    return BuildingRunner([(("flutter", "build"), OK)] * builds, platform, wasm)


def build_calls(runner: FakeRunner) -> list[tuple[str, ...]]:
    return [call for call in runner.calls if call[:2] == ("flutter", "build")]


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


def test_another_platforms_folder_does_not_rebuild(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    (app / "ios").mkdir()
    runner = runner_for("android", False)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / "ios" / "Info.plist").write_text("changed", encoding="utf-8")
    again = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert again.reused is True


def test_build_folder_changes_do_not_rebuild(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = runner_for("android", False)
    ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (app / "build" / "noise").write_text("x", encoding="utf-8")
    (app / "android" / "build").mkdir()
    (app / "android" / "build" / "noise").write_text("x", encoding="utf-8")
    (package / "lib" / ".hidden").write_text("x", encoding="utf-8")
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

    js = source_digest(app, package, "web", build_argv("web", False))
    wasm = source_digest(app, package, "web", build_argv("web", True))

    assert js != wasm
    assert js == source_digest(app, package, "web", build_argv("web", False))


def test_digest_is_content_not_mtime(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    argv = build_argv("android", False)
    before = source_digest(app, package, "android", argv)

    source = package / "lib" / "x.dart"
    source.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")

    assert source_digest(app, package, "android", argv) == before


def test_digest_tells_app_files_from_package_files(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    argv = build_argv("android", False)
    before = source_digest(app, package, "android", argv)

    (package / "lib" / "x.dart").rename(package / "lib" / "y.dart")

    assert source_digest(app, package, "android", argv) != before


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


def test_failed_build_is_env(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    failed = Completed(("flutter",), 1, "", "Gradle task assembleDebug failed\n", False)
    runner = FakeRunner([(("flutter", "build"), failed)])

    with pytest.raises(RoundEnvError, match=r"flutter build apk --debug") as raised:
        ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert "Gradle task assembleDebug failed" in raised.value.reason
    assert not (app / "build" / "e2e").exists()


def test_failed_rebuild_drops_the_stale_copy(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    failed = Completed(("flutter",), 1, "", "boom\n", False)
    runner = BuildingRunner([(("flutter", "build"), OK), (("flutter", "build"), failed)], "android", False)
    first = ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    (package / "lib" / "x.dart").write_text("class X { int y = 1; }", encoding="utf-8")
    with pytest.raises(RoundEnvError):
        ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")

    assert not first.path.exists()


def test_build_without_an_artifact_is_env(tmp_path: Path) -> None:
    app, package = make_tree(tmp_path)
    runner = FakeRunner([(("flutter", "build"), OK)])

    with pytest.raises(RoundEnvError, match="produced no"):
        ensure_app_build(app, package, "android", False, runner, tmp_path / "build.log")
