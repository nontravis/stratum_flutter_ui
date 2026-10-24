"""Errors the device round raises."""

from __future__ import annotations


class CatalogError(ValueError):
    """`e2e/targets.toml` or a round request names something the catalog cannot resolve."""


class RoundEnvError(RuntimeError):
    """The environment, not the code under test, stopped a run; a report line reads `env: <reason>`."""

    def __init__(self, reason: str) -> None:
        super().__init__(f"env: {reason}")
        self.reason = reason


class CompileFailure(Exception):
    """The code under test does not compile in an app build: a widget failure, so the round reads `fail` with
    `reason` (`app build: <the first Dart compiler error>`), never `env`."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason
