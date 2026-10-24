"""Errors the device round raises."""

from __future__ import annotations

from pathlib import Path


class CatalogError(ValueError):
    """`e2e/targets.toml` or a round request names something the catalog cannot resolve."""


class RoundEnvError(RuntimeError):
    """The environment, not the code under test, stopped a run; a report line reads `env: <reason>`."""

    def __init__(self, reason: str) -> None:
        super().__init__(f"env: {reason}")
        self.reason = reason


class BuildFailure(Exception):
    """An app build failed, so the round reads `build`, a class that claims no blame: a build's output cannot say
    whether the code under test or the machine broke it.

    `reason` is the output's first error line, `log` the build log, and `argv` and `seconds` the failed command, which
    the summary records as a build.
    """

    def __init__(self, reason: str, log: Path, argv: tuple[str, ...], seconds: float) -> None:
        super().__init__(reason)
        self.reason = reason
        self.log = log
        self.argv = argv
        self.seconds = seconds
