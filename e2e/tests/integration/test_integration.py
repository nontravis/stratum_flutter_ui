"""One item per integration file a round target runs (design section 9).

The plugin runs each of the target's plans once, before the target's first integration item, and splits each run's
report per file; this item only reports its file's result. Outside a round nothing parametrizes it, so it skips.
"""

from __future__ import annotations

import pytest

from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.integration_run import FileResult
from stratum_e2e.round.state import RoundTarget


def test_integration_file(
    round_target: RoundTarget | None, integration_file: str, integration_outcomes: dict[str, FileResult]
) -> None:
    """Pass, fail, or class `env` as the file's result says; the plugin records its `n/N` cell."""
    result = integration_outcomes.get(integration_file)
    if result is None:
        target = round_target.target.name if round_target is not None else "this target"
        pytest.fail(f"no integration run on {target} covered {integration_file}", pytrace=False)
    if result.cls == "env":
        raise RoundEnvError(result.reason)
    if result.cls == "fail":
        pytest.fail(result.reason or f"{integration_file} failed", pytrace=False)
