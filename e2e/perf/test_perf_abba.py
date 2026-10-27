"""The example app's ABBA perf run as a round item: macOS only, outside default runs (design call 7).

`tools/perf_abba.dart` builds its own example app (`example/tools/perf_abba.dart`), so the round builds nothing
for it; the command comes from `apps.example.perf` in `e2e/targets.toml`.
"""

from __future__ import annotations

import shlex

import pytest

from stratum_e2e.paths import REPO_ROOT
from stratum_e2e.round.catalog import TARGETS_TOML, load_catalog
from stratum_e2e.round.state import Backends

PERF_APP = "example"


@pytest.mark.perf
@pytest.mark.macos
def test_perf_abba(round_backends: Backends) -> None:
    """Run the perf command in the example app folder; pass on exit 0. Its output lands in the item's captured log."""
    app = load_catalog(TARGETS_TOML).apps[PERF_APP]
    if app.perf is None:
        pytest.fail(f"e2e/targets.toml gives apps.{PERF_APP} no perf command", pytrace=False)
    done = round_backends.runner.run(shlex.split(app.perf), cwd=REPO_ROOT / app.folder)
    print(done.stdout)
    print(done.stderr)
    if done.status != 0:
        how = "timed out" if done.timed_out else f"exited {done.status}"
        pytest.fail(f"{app.perf} {how}", pytrace=False)
