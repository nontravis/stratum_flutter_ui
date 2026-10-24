"""Class a failed app build or test run (design section 10) by where its compiler errors point: an error in this
repository's own source reads `fail`; anything else (CMake, Gradle, Xcode, the toolchain, a dependency, the round's own
entry file, a timeout) is a tool failure and reads `env`."""

from __future__ import annotations

import os
import posixpath
import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Final
from urllib.parse import unquote

from stratum_e2e.round.entry import ENTRY_PREFIX
from stratum_e2e.round.errors import CompileFailure, RoundEnvError
from stratum_e2e.round.runner import Completed

_TAIL_LINES: Final = 3

# Folders a tool writes inside the repository: Flutter's build output, generated Dart, and platform tooling (engine
# copies, and plugin links this host cannot follow for a container build), and CocoaPods' pod sources. A file in one is
# not source, and neither is an entry file the round writes (`ENTRY_PREFIX`).
_TOOL_TREES: Final = frozenset({"build", ".dart_tool", "ephemeral", "Pods"})
# A web debug run names a file under `BuildSite.app_uri_root` by this scheme.
_APP_SCHEME: Final = "org-dartlang-app:///"

# A log prefix ahead of a diagnostic ends in `: ` (`ERROR: ` from the Linux tool backend, `error: ` from the Xcode
# one); the lazy `??` tries none first. A printed path holds no colon past its `org-dartlang-app://` scheme, so the
# `:<line>:<column>` after it is plain.
_PREFIX: Final = r"^(?:.*?: )??[ \t]*"
_PATH: Final = r"(?:org-dartlang-app://)?[^\s:][^:\n]*?"


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
    """Where an app build or test run ran, so a path its compiler printed traces back to a file on this host.

    `repo_root` is the repository on this host. `cwd` is the folder the build ran in as the build saw it: a relative
    path resolves against it. A container build sees `repo_root` mounted at `mount`; a build on this host has none.
    `app_uri_root` is the folder a web debug run's `org-dartlang-app:///` names, the entry's own folder; `None` where no
    such name can appear.
    """

    repo_root: Path
    cwd: PurePosixPath
    mount: PurePosixPath | None = None
    app_uri_root: PurePosixPath | None = None

    def owns(self, printed: str) -> bool:
        """Whether `printed`, a path as the build printed it, is this repository's own source: once mapped to this
        host and its symlinks followed, a file inside `repo_root`, outside every `_TOOL_TREES` folder, and not a
        round entry. A container path outside `mount` (the image's SDK, the mounted pub cache) never is, and neither is an
        `org-dartlang-app:///` name with no `app_uri_root` to trace it to."""
        if printed.startswith(_APP_SCHEME):
            if self.app_uri_root is None:
                return False
            printed = str(self.app_uri_root / printed.removeprefix(_APP_SCHEME))
        seen = PurePosixPath(posixpath.normpath(posixpath.join(self.cwd, printed)))
        if self.mount is None:
            host = Path(seen)
        elif seen.is_relative_to(self.mount):
            host = self.repo_root / seen.relative_to(self.mount)
        else:
            return False
        root = Path(os.path.realpath(self.repo_root))
        real = Path(os.path.realpath(host))
        return (
            real.is_relative_to(root)
            and _TOOL_TREES.isdisjoint(real.relative_to(root).parts)
            and not real.name.startswith(ENTRY_PREFIX)
        )


def build_failure(command: str, completed: Completed, site: BuildSite) -> CompileFailure | RoundEnvError:
    """The error to raise for a build of `command` that ended `completed` with a non-zero exit.

    The first compiler error in the output that points into the repository's own source (`BuildSite.owns`) makes it
    `CompileFailure("app build: <location> <message>")`, whatever else failed beside it. Otherwise, and always after a
    timeout, it is `RoundEnvError` naming the exit and the last lines of the output (stderr when there is any).
    """
    if not completed.timed_out:
        owned = [error for error, own in _located_errors(f"{completed.stdout}\n{completed.stderr}", site) if own]
        if owned:
            return CompileFailure(f"app build: {owned[0]}")
    how = "timed out" if completed.timed_out else f"exit {completed.status}"
    return RoundEnvError(f"{command} failed ({how}): {error_tail(completed.stderr or completed.stdout)}")


def tool_compile_error(output: str, site: BuildSite) -> str | None:
    """`<location> <message>` of the first located compiler error in a run's `output` when every one points outside
    `site`'s own source, such as into the round's entry: a tool cause, so the run reads `env`. `None` when there is no
    such error, or when one is the code's own and the run keeps reading `fail`."""
    errors = _located_errors(output, site)
    if not errors or any(own for _, own in errors):
        return None
    return errors[0][0]


def _located_errors(output: str, site: BuildSite) -> list[tuple[str, bool]]:
    """Each located compiler error in `output`, earliest first: `<location> <message>`, and whether `site` owns it."""
    found = sorted(
        (
            match.start(),
            f"{match['location'].strip()} {match['message'].strip()}",
            site.owns(unquote(match["path"]) if shape.percent_encoded else match["path"]),
        )
        for shape in _SHAPES
        for match in shape.pattern.finditer(output)
    )
    return [(error, own) for _, error, own in found]


def error_tail(text: str) -> str:
    """The last few non-empty lines of `text`, joined on one line."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return " | ".join(lines[-_TAIL_LINES:])
