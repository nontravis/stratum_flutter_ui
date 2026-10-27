"""Unit tests for naming a failed app build (design section 10): every failed build reads `build`, which claims no
blame, so the only choice left is the line a reader sees first."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.round.build_failure import build_failure, first_error_line
from stratum_e2e.round.errors import BuildFailure
from stratum_e2e.round.runner import Completed

BUILDS = Path(__file__).parent / "fixtures" / "round" / "builds"
ARGV = ("flutter", "build", "macos", "--debug")
LOG = Path("/round/mac/app build/build.log")


def failed(log: str, *, status: int = 1, stderr: str = "", timed_out: bool = False) -> Completed:
    return Completed(argv=ARGV, status=status, stdout=(BUILDS / log).read_text(encoding="utf-8"), stderr=stderr,
                     timed_out=timed_out)


@pytest.mark.parametrize(
    ("log", "line"),
    [
        ("macos-dart-error.log", "lib/main.dart:5:3: Error: Method not found: 'runAp'."),
        ("linux-dart-error.log", "../lib/src/layout/column_layout.dart:18:30: Error: Expected ';' after this."),
        (
            "android-dart-and-gradle.log",
            "../lib/src/components/common/style/widget_style.dart:41:12: Error: The getter 'colr' isn't defined for "
            "the type 'WidgetStyle'.",
        ),
        ("web-dart2js-error.log", "Error: A value of type 'String' can't be assigned to a variable of type 'int'."),
        ("linux-cmake.log", "CMake Error: The current CMakeCache.txt directory "),
        ("android-gradle-sdk.log", "Error: Gradle task assembleDebug failed with exit code 1"),
    ],
)
def test_every_failed_build_is_a_build_failure_named_by_its_first_error_line(log: str, line: str) -> None:
    error = build_failure(" ".join(ARGV), ARGV, failed(log), 12.5, LOG)

    assert isinstance(error, BuildFailure)
    assert error.reason.startswith(line)
    assert (error.log, error.argv, error.seconds) == (LOG, ARGV, 12.5)


def test_a_build_with_no_error_line_is_named_by_its_exit() -> None:
    done = Completed(ARGV, 65, "Building macOS application...\n** BUILD FAILED **\n", "", False)

    assert build_failure("flutter build macos --debug", ARGV, done, 3.0, LOG).reason == (
        "flutter build macos --debug failed (exit 65)"
    )


def test_a_timeout_is_named_as_one_even_with_an_error_line_in_the_output() -> None:
    error = build_failure("flutter build linux --debug", ARGV, failed("linux-dart-error.log", status=-9,
                                                                       timed_out=True), 3600.0, LOG)

    assert error.reason == "flutter build linux --debug timed out"


def test_the_first_error_line_reads_stdout_before_stderr() -> None:
    done = Completed(ARGV, 1, "lib/a.dart:1:2: Error: first\n", "Error: later\n", False)

    assert build_failure("flutter build web", ARGV, done, 1.0, LOG).reason == "lib/a.dart:1:2: Error: first"


@pytest.mark.parametrize(
    ("text", "line"),
    [
        ("Running Gradle task 'assembleDebug'...\n  ERROR: lib/main.dart:1:2: Error: x  \n", "ERROR: lib/main.dart:1:2: Error: x"),
        ("/x/Plugin.swift:3:5: error: cannot find 'y' in scope\n", "/x/Plugin.swift:3:5: error: cannot find 'y' in scope"),
        ("Compiling 3 files, 0 errors so far\nBuild process failed\n", None),
        ("", None),
    ],
)
def test_first_error_line_takes_the_first_line_that_says_error(text: str, line: str | None) -> None:
    assert first_error_line(text) == line
