"""Class a failed app build (design section 10) by where its compiler error points: an error in this repository's own
source reads `fail`; anything else (CMake, Gradle, Xcode, the toolchain, a dependency, a timeout) is a tool failure and
reads `env`."""

from __future__ import annotations

import os
import posixpath
import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Final
from urllib.parse import unquote

from stratum_e2e.round.errors import CompileFailure, RoundEnvError
from stratum_e2e.round.runner import Completed

_TAIL_LINES: Final = 3

# Folders a tool writes inside the repository: Flutter's build output, generated Dart, and platform tooling (engine
# copies, and plugin links this host cannot follow for a container build), and CocoaPods' pod sources. A file in one is
# not source.
_TOOL_TREES: Final = frozenset({"build", ".dart_tool", "ephemeral", "Pods"})

# A log prefix ahead of a diagnostic ends in `: ` (`ERROR: ` from the Linux tool backend, `error: ` from the Xcode
# one); the lazy `??` tries none first. A printed path holds no colon, so the `:<line>:<column>` after it is plain.
_PREFIX: Final = r"^(?:.*?: )??[ \t]*"
_PATH: Final = r"[^\s:][^:\n]*?"


@dataclass(frozen=True)
class _Shape:
    """One way a compiler prints a located error; `pattern` names `location` (as printed), `path`, and `message`."""

    pattern: re.Pattern[str]
    percent_encoded: bool


_SHAPES: Final = (
    # The Dart front end: `<path>.dart:<l>:<c>: Error: <message>`.
    _Shape(re.compile(_PREFIX + rf"(?P<location>(?P<path>{_PATH}\.dart):\d+:\d+:) (?P<message>Error: .*)$", re.M),
           percent_encoded=False),
    # dart2js: the location on a line of its own, then `Error: <message>`.
    _Shape(re.compile(_PREFIX + rf"(?P<location>(?P<path>{_PATH}\.dart):\d+:\d+:)[ \t]*\n[ \t]*(?P<message>Error: .*)$",
                      re.M), percent_encoded=False),
    # Kotlin: `e: file://<path>:<l>:<c> <message>`.
    _Shape(re.compile(_PREFIX + r"e: (?P<location>file://(?P<path>\S+?):\d+:\d+):? (?P<message>\S.*)$", re.M),
           percent_encoded=True),
    # Swift and clang: `<path>:<l>:<c>: error: <message>`.
    _Shape(re.compile(_PREFIX + rf"(?P<location>(?P<path>{_PATH}):\d+:\d+:) (?P<message>(?:fatal )?error: .*)$", re.M),
           percent_encoded=False),
    # An Xcode issue the Flutter tool reads from the result bundle (iOS): `<kind> (Xcode): <message>`, then the location.
    _Shape(re.compile(r"^[ \t]*(?P<message>\S.*? \(Xcode\): .*)\n[ \t]*(?P<location>(?P<path>/[^:\n]*?):\d+(?::\d+)?)"
                      r"[ \t]*$", re.M), percent_encoded=True),
)


@dataclass(frozen=True)
class BuildSite:
    """Where an app build ran, so a path its compiler printed traces back to a file on this host.

    `repo_root` is the repository on this host. `cwd` is the folder the build ran in as the build saw it: a relative
    path resolves against it. A container build sees `repo_root` mounted at `mount`; a build on this host has none.
    """

    repo_root: Path
    cwd: PurePosixPath
    mount: PurePosixPath | None = None

    def owns(self, printed: str) -> bool:
        """Whether `printed`, a path as the build printed it, is this repository's own source: once mapped to this
        host and its symlinks followed, a file inside `repo_root` and outside every `_TOOL_TREES` folder. A container
        path outside `mount` (the image's SDK, the mounted pub cache) never is."""
        seen = PurePosixPath(posixpath.normpath(posixpath.join(self.cwd, printed)))
        if self.mount is None:
            host = Path(seen)
        elif seen.is_relative_to(self.mount):
            host = self.repo_root / seen.relative_to(self.mount)
        else:
            return False
        root = Path(os.path.realpath(self.repo_root))
        real = Path(os.path.realpath(host))
        return real.is_relative_to(root) and _TOOL_TREES.isdisjoint(real.relative_to(root).parts)


def build_failure(command: str, completed: Completed, site: BuildSite) -> CompileFailure | RoundEnvError:
    """The error to raise for a build of `command` that ended `completed` with a non-zero exit.

    The first compiler error in the output that points into the repository's own source (`BuildSite.owns`) makes it
    `CompileFailure("app build: <location> <message>")`, whatever else failed beside it. Otherwise, and always after a
    timeout, it is `RoundEnvError` naming the exit and the last lines of the output (stderr when there is any).
    """
    if not completed.timed_out:
        error = _first_owned_error(f"{completed.stdout}\n{completed.stderr}", site)
        if error is not None:
            return CompileFailure(f"app build: {error}")
    how = "timed out" if completed.timed_out else f"exit {completed.status}"
    return RoundEnvError(f"{command} failed ({how}): {error_tail(completed.stderr or completed.stdout)}")


def _first_owned_error(output: str, site: BuildSite) -> str | None:
    """`<location> <message>` of the earliest located compiler error in `output` that `site` owns, or None."""
    owned = [
        (match.start(), f"{match['location'].strip()} {match['message'].strip()}")
        for shape in _SHAPES
        for match in shape.pattern.finditer(output)
        if site.owns(unquote(match["path"]) if shape.percent_encoded else match["path"])
    ]
    return min(owned)[1] if owned else None


def error_tail(text: str) -> str:
    """The last few non-empty lines of `text`, joined on one line."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return " | ".join(lines[-_TAIL_LINES:])
