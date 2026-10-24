"""Unit tests for the app build failure classifier (design section 10): code under test reads `fail`, a tool `env`."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.round.build_failure import build_failure
from stratum_e2e.round.errors import CompileFailure, RoundEnvError
from stratum_e2e.round.runner import Completed

BUILDS = Path(__file__).parent / "fixtures" / "round" / "builds"


def failed(log: str, *, status: int = 1, stderr: str = "", timed_out: bool = False) -> Completed:
    return Completed(argv=(), status=status, stdout=(BUILDS / log).read_text(encoding="utf-8"), stderr=stderr,
                     timed_out=timed_out)


@pytest.mark.parametrize(
    ("log", "line"),
    [
        ("macos-dart-error.log", "lib/main.dart:5:3: Error: Method not found: 'runAp'."),
        ("linux-dart-error.log", "../lib/src/layout/column_layout.dart:18:30: Error: Expected ';' after this."),
    ],
)
def test_a_dart_compiler_error_is_a_compile_failure(log: str, line: str) -> None:
    error = build_failure("flutter build macos --debug", failed(log))

    assert isinstance(error, CompileFailure)
    assert error.reason == f"app build: {line}"


def test_a_dart_error_beside_a_gradle_failure_is_still_a_compile_failure() -> None:
    error = build_failure("flutter build apk --debug", failed("android-dart-and-gradle.log"))

    assert isinstance(error, CompileFailure)
    assert error.reason == (
        "app build: ../lib/src/components/common/style/widget_style.dart:41:12: Error: The getter 'colr' isn't defined "
        "for the type 'WidgetStyle'."
    )


@pytest.mark.parametrize(
    ("log", "command", "tail"),
    [
        (
            "linux-cmake.log", "flutter build linux --debug",
            'CMake Error: The source "/work/test_app/linux/CMakeLists.txt" does not match',
        ),
        ("android-gradle-sdk.log", "flutter build apk --debug", "Error: Gradle task assembleDebug failed with exit code 1"),
    ],
)
def test_a_native_or_toolchain_failure_is_env(log: str, command: str, tail: str) -> None:
    error = build_failure(command, failed(log))

    assert isinstance(error, RoundEnvError)
    assert error.reason.startswith(f"{command} failed (exit 1): ")
    assert tail in error.reason


def test_the_env_reason_prefers_stderr() -> None:
    error = build_failure("flutter build web", failed("linux-cmake.log", stderr="Error: no web device\n"))

    assert isinstance(error, RoundEnvError)
    assert error.reason == "flutter build web failed (exit 1): Error: no web device"


def test_a_timeout_is_env_even_with_a_dart_error_in_the_output() -> None:
    error = build_failure("flutter build linux --debug", failed("linux-dart-error.log", status=-9, timed_out=True))

    assert isinstance(error, RoundEnvError)
    assert error.reason.startswith("flutter build linux --debug failed (timed out): ")


def test_a_dart_error_mentioned_in_prose_is_not_a_diagnostic() -> None:
    output = "Note: see lib/main.dart for details. Error: Gradle task assembleDebug failed with exit code 1\n"
    error = build_failure("flutter build apk --debug", Completed((), 1, output, "", False))

    assert isinstance(error, RoundEnvError)
