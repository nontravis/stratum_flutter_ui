"""Unit tests for the immersive-confirmation dismissal: the tap call shape (M3-T19)."""

from __future__ import annotations

from stratum_e2e.android.immersive import dismiss_immersive_confirmation


class FakeDriver:
    """Records tap calls and, like the real client, takes a list of (x, y) tuples."""

    def __init__(self, width: int = 1080, height: int = 2400) -> None:
        self._size = {"width": width, "height": height}
        self.taps: list[list[tuple[int, int]]] = []

    def get_window_size(self) -> dict[str, int]:
        return self._size

    def tap(self, positions: list[tuple[int, int]]) -> None:
        for x, y in positions:  # a flat [x, y] list fails here, as it does in the client
            assert isinstance((x, y), tuple)
        self.taps.append(positions)


def test_taps_the_window_centre_as_one_xy_tuple() -> None:
    driver = FakeDriver(width=720, height=1280)

    tapped = dismiss_immersive_confirmation(driver, "Window{x u0 ImmersiveModeConfirmation}")

    assert tapped is True
    assert driver.taps == [[(360, 640)]]


def test_does_not_tap_without_the_confirmation() -> None:
    driver = FakeDriver()

    assert dismiss_immersive_confirmation(driver, "Window{x u0 com.app/.MainActivity}") is False
    assert driver.taps == []
