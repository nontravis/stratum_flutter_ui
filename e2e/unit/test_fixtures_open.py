"""Unit tests for the shared cold-start-and-wait helper, on a fake clock (no device)."""

from __future__ import annotations

import pytest
from selenium.common.exceptions import WebDriverException

from stratum_e2e import fixtures


class FakeClock:
    """A monotonic clock that only `sleep` advances."""

    def __init__(self) -> None:
        self.now = 0.0

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


@pytest.fixture
def clock(monkeypatch: pytest.MonkeyPatch) -> FakeClock:
    fake = FakeClock()
    monkeypatch.setattr("stratum_e2e.waits.time.monotonic", fake.monotonic)
    monkeypatch.setattr("stratum_e2e.waits.time.sleep", fake.sleep)
    return fake


@pytest.fixture
def opened(monkeypatch: pytest.MonkeyPatch) -> list[tuple[str, str, str]]:
    calls: list[tuple[str, str, str]] = []
    monkeypatch.setattr(
        f"{fixtures.__name__}.open_fixture",
        lambda driver, platform, app_id, fixture_id: calls.append((platform, app_id, fixture_id)),
    )
    return calls


def test_open_wait_cold_starts_then_waits_for_the_condition(
    opened: list[tuple[str, str, str]], clock: FakeClock
) -> None:
    reads: list[int] = []

    def until() -> bool:
        reads.append(len(reads))
        return True

    fixtures.open_fixture_and_wait(None, "android", "test_app", "common/page_drawer", until, "the opener on screen")

    assert opened == [("android", "test_app", "common/page_drawer")]
    assert len(reads) == 1


def test_open_wait_treats_a_missing_node_as_not_yet_not_an_error(
    opened: list[tuple[str, str, str]], clock: FakeClock
) -> None:
    """The wait catches the find error a half-open window raises, so it never escapes."""
    reads: list[int] = []

    def until() -> bool:
        reads.append(len(reads))
        if len(reads) < 3:
            raise WebDriverException("Could not find an element")
        return True

    fixtures.open_fixture_and_wait(None, "android", "test_app", "common/reorder", until, "the first item on screen")

    assert len(reads) == 3


def test_open_wait_times_out_when_the_condition_never_holds(
    opened: list[tuple[str, str, str]], clock: FakeClock
) -> None:
    def until() -> bool:
        raise WebDriverException("Could not find an element")

    with pytest.raises(AssertionError, match="the opener on screen"):
        fixtures.open_fixture_and_wait(None, "android", "test_app", "common/page_drawer", until, "the opener on screen")

    assert clock.now >= fixtures.OPEN_WAIT_TIMEOUT_S
