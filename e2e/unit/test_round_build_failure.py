"""Unit tests for the app build failure classifier (design section 10): a compiler error in the repository's own source
reads `fail`, anything else `env`."""

from __future__ import annotations

from pathlib import Path, PurePosixPath

import pytest

from stratum_e2e.round.build_failure import BuildSite, build_failure
from stratum_e2e.round.errors import CompileFailure, RoundEnvError
from stratum_e2e.round.runner import Completed

BUILDS = Path(__file__).parent / "fixtures" / "round" / "builds"

# The repository the fixture logs name: no such folder exists, so nothing on this host is followed.
REPO = Path("/Users/dev/NTD OS/stratum_ui")
HOST = BuildSite(REPO, PurePosixPath(REPO / "test_app"))
CONTAINER = BuildSite(REPO, PurePosixPath("/work/test_app"), mount=PurePosixPath("/work"))


def failed(log: str, *, status: int = 1, stderr: str = "", timed_out: bool = False) -> Completed:
    return Completed(argv=(), status=status, stdout=(BUILDS / log).read_text(encoding="utf-8"), stderr=stderr,
                     timed_out=timed_out)


def output(text: str) -> Completed:
    return Completed((), 1, text, "", False)


@pytest.mark.parametrize(
    ("log", "line"),
    [
        ("macos-dart-error.log", "lib/main.dart:5:3: Error: Method not found: 'runAp'."),
        ("linux-dart-error.log", "../lib/src/layout/column_layout.dart:18:30: Error: Expected ';' after this."),
    ],
)
def test_a_dart_compiler_error_is_a_compile_failure(log: str, line: str) -> None:
    error = build_failure("flutter build macos --debug", failed(log), HOST)

    assert isinstance(error, CompileFailure)
    assert error.reason == f"app build: {line}"


def test_a_dart_error_beside_a_gradle_failure_is_still_a_compile_failure() -> None:
    error = build_failure("flutter build apk --debug", failed("android-dart-and-gradle.log"), HOST)

    assert isinstance(error, CompileFailure)
    assert error.reason == (
        "app build: ../lib/src/components/common/style/widget_style.dart:41:12: Error: The getter 'colr' isn't defined "
        "for the type 'WidgetStyle'."
    )


@pytest.mark.parametrize(
    ("log", "site", "reason"),
    [
        (
            "web-dart2js-error.log", HOST,
            "probe.dart:2:21: Error: A value of type 'String' can't be assigned to a variable of type 'int'.",
        ),
        (
            "linux-dart-error-prefixed.log", CONTAINER,
            "lib/main.dart:13:23: Error: A value of type 'String' can't be assigned to a variable of type 'int'.",
        ),
        (
            "android-kotlin-error.log", HOST,
            "file:///Users/dev/NTD%20OS/stratum_ui/android/src/main/kotlin/dev/stratum/stratum_ui/StratumUiPlugin.kt:31:9 "
            "Unresolved reference 'radius'.",
        ),
        (
            "macos-swift-error.log", HOST,
            "/Users/dev/NTD OS/stratum_ui/darwin/stratum_ui/Sources/stratum_ui/StratumUiPlugin.swift:18:9: error: cannot "
            "find 'radius' in scope",
        ),
        (
            "ios-xcode-swift-error.log", HOST,
            "/Users/dev/NTD%20OS/stratum_ui/darwin/stratum_ui/Sources/stratum_ui/StratumUiPlugin.swift:17:8 Swift "
            "Compiler Error (Xcode): Cannot find 'radius' in scope",
        ),
    ],
)
def test_a_compiler_error_in_the_repository_is_a_compile_failure(log: str, site: BuildSite, reason: str) -> None:
    error = build_failure("flutter build", failed(log), site)

    assert isinstance(error, CompileFailure)
    assert error.reason == f"app build: {reason}"


@pytest.mark.parametrize(
    ("log", "site", "command", "tail"),
    [
        (
            "linux-cmake.log", HOST, "flutter build linux --debug",
            'CMake Error: The source "/work/test_app/linux/CMakeLists.txt" does not match',
        ),
        (
            "android-gradle-sdk.log", HOST, "flutter build apk --debug",
            "Error: Gradle task assembleDebug failed with exit code 1",
        ),
        ("linux-sdk-dart-error.log", CONTAINER, "flutter build linux --debug", "Build process failed"),
        ("linux-plugin-cpp-error.log", CONTAINER, "flutter build linux --debug", "Build process failed"),
    ],
)
def test_a_native_toolchain_or_dependency_failure_is_env(log: str, site: BuildSite, command: str, tail: str) -> None:
    error = build_failure(command, failed(log), site)

    assert isinstance(error, RoundEnvError)
    assert error.reason.startswith(f"{command} failed (exit 1): ")
    assert tail in error.reason


@pytest.mark.parametrize(
    ("line", "site"),
    [
        ("/Users/dev/flutter/packages/flutter/lib/src/widgets/framework.dart:12:3: Error: Expected ';' after this.", HOST),
        ("../../../flutter/packages/flutter/lib/src/widgets/framework.dart:12:3: Error: Expected ';' after this.", HOST),
        ("ERROR: /root/.pub-cache/hosted/pub.dev/xml-7.0.1/lib/xml.dart:4:1: Error: Expected ';' after this.", CONTAINER),
        ("ERROR: /work/../opt/flutter/packages/flutter/lib/material.dart:4:1: Error: Expected ';' after this.", CONTAINER),
    ],
)
def test_a_dart_error_under_the_sdk_or_the_pub_cache_is_env(line: str, site: BuildSite) -> None:
    assert isinstance(build_failure("flutter build", output(f"{line}\n"), site), RoundEnvError)


@pytest.mark.parametrize(
    "path",
    [
        ".dart_tool/flutter_build/3ef42062/main.dart",
        "build/macos/SourcePackages/checkouts/swift-collections/Sources/A.dart",
        "macos/Flutter/ephemeral/Packages/.packages/url_launcher_macos/Sources/A.dart",
        "ios/Pods/FirebaseCore/Sources/A.dart",
    ],
)
def test_an_error_in_a_folder_a_tool_writes_is_env(path: str) -> None:
    error = build_failure("flutter build", output(f"{path}:1:2: Error: Expected ';' after this.\n"), HOST)

    assert isinstance(error, RoundEnvError)


@pytest.mark.parametrize(("plugin", "kind"), [("stratum_ui", CompileFailure), ("url_launcher_macos", RoundEnvError)])
def test_a_plugin_reached_through_a_symlink_belongs_where_the_link_points(
    tmp_path: Path, plugin: str, kind: type[Exception]
) -> None:
    repo = tmp_path / "repo"
    packages = repo / "test_app" / "macos" / "Flutter" / "ephemeral" / "Packages" / ".packages"
    targets = {"stratum_ui": repo / "darwin" / "stratum_ui", "url_launcher_macos": tmp_path / "pub-cache" / "url"}
    for name, target in targets.items():
        target.mkdir(parents=True)
        packages.mkdir(parents=True, exist_ok=True)
        (packages / name).symlink_to(target)
    swift = f"{packages / plugin}/Sources/Plugin.swift:3:5: error: cannot find 'y' in scope\n"

    error = build_failure("flutter build macos --debug", output(swift), BuildSite(repo, PurePosixPath(repo / "test_app")))

    assert isinstance(error, kind)


def test_an_error_in_the_repository_wins_over_one_outside_it() -> None:
    text = "".join((BUILDS / log).read_text(encoding="utf-8")
                   for log in ("linux-sdk-dart-error.log", "linux-dart-error-prefixed.log"))

    error = build_failure("flutter build linux --debug", output(text), CONTAINER)

    assert isinstance(error, CompileFailure)
    assert error.reason.startswith("app build: lib/main.dart:13:23: Error: ")


def test_the_env_reason_prefers_stderr() -> None:
    error = build_failure("flutter build web", failed("linux-cmake.log", stderr="Error: no web device\n"), HOST)

    assert isinstance(error, RoundEnvError)
    assert error.reason == "flutter build web failed (exit 1): Error: no web device"


def test_a_timeout_is_env_even_with_a_dart_error_in_the_output() -> None:
    error = build_failure(
        "flutter build linux --debug", failed("linux-dart-error.log", status=-9, timed_out=True), HOST
    )

    assert isinstance(error, RoundEnvError)
    assert error.reason.startswith("flutter build linux --debug failed (timed out): ")


def test_a_dart_error_mentioned_in_prose_is_not_a_diagnostic() -> None:
    text = "Note: see lib/main.dart for details. Error: Gradle task assembleDebug failed with exit code 1\n"

    assert isinstance(build_failure("flutter build apk --debug", output(text), HOST), RoundEnvError)
