"""Unit tests for the shared wait helpers, on a fake clock (M3-T19)."""

from __future__ import annotations

import pytest

from stratum_e2e.waits import wait_until, wait_until_held

MODULE = "stratum_e2e.waits"


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
    monkeypatch.setattr(f"{MODULE}.time.monotonic", fake.monotonic)
    monkeypatch.setattr(f"{MODULE}.time.sleep", fake.sleep)
    return fake


class Boom(Exception):
    pass


def test_wait_until_returns_on_the_first_true_read(clock: FakeClock) -> None:
    wait_until(lambda: True, "x")
    assert clock.now == 0.0


def test_wait_until_times_out_and_names_the_last_caught_error(clock: FakeClock) -> None:
    def failing() -> bool:
        raise Boom("no window")

    with pytest.raises(AssertionError, match=r"waiting for thing .*Boom: no window"):
        wait_until(failing, "thing", timeout_s=2, catch=(Boom,))


def test_wait_until_lets_an_uncaught_error_through(clock: FakeClock) -> None:
    def failing() -> bool:
        raise ValueError("bug")

    with pytest.raises(ValueError):
        wait_until(failing, "thing", catch=(Boom,))


def test_held_returns_after_the_hold_time(clock: FakeClock) -> None:
    wait_until_held(lambda: True, "x", hold_s=1.5, poll_interval_s=0.25)
    assert clock.now == pytest.approx(1.5)


def test_held_fails_a_light_then_dark_revert(clock: FakeClock) -> None:
    """The value reads right for 0.75 s, then reverts for good: it never settles."""
    with pytest.raises(AssertionError, match="to hold 1.5s"):
        wait_until_held(
            lambda: clock.now < 0.75, "light icons", hold_s=1.5, timeout_s=10, poll_interval_s=0.25
        )


def test_held_restarts_the_hold_at_a_false_read(clock: FakeClock) -> None:
    """A dip at t=1.0 pushes settling out to a full hold after the dip."""
    wait_until_held(
        lambda: not 0.9 < clock.now < 1.1, "x", hold_s=1.5, timeout_s=10, poll_interval_s=0.25
    )
    assert clock.now >= 1.1 + 1.5


def test_held_counts_a_caught_error_as_a_false_read(clock: FakeClock) -> None:
    def failing() -> bool:
        raise Boom("flaky")

    with pytest.raises(AssertionError, match="Boom: flaky"):
        wait_until_held(failing, "x", timeout_s=2, catch=(Boom,))


def test_held_names_no_error_that_an_older_poll_saw_once_reads_return(clock: FakeClock) -> None:
    """A caught error on poll 1 must not be blamed when every later read returned false."""
    polls = iter([True])

    def read() -> bool:
        if next(polls, False):
            raise Boom("splash")
        return False

    with pytest.raises(AssertionError) as caught:
        wait_until_held(read, "x", timeout_s=1, poll_interval_s=0.25, catch=(Boom,))
    assert "last error" not in str(caught.value)


def test_wait_until_names_no_error_that_an_older_poll_saw(clock: FakeClock) -> None:
    polls = iter([True])

    def read() -> bool:
        if next(polls, False):
            raise Boom("splash")
        return False

    with pytest.raises(AssertionError) as caught:
        wait_until(read, "x", timeout_s=1, poll_interval_s=0.25, catch=(Boom,))
    assert "last error" not in str(caught.value)
