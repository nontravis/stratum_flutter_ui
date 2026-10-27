"""Unit tests for `stratum_e2e.web.browsers`: which browser a web target launches, and where Playwright finds it.

A recording fake Playwright stands in for the real one, so no browser launches and nothing installs.
"""

from __future__ import annotations

import os
from types import SimpleNamespace
from typing import Any

import pytest

import stratum_e2e.web.browsers as browsers
from stratum_e2e.paths import PLAYWRIGHT_BROWSERS_DIR
from stratum_e2e.round.catalog import BROWSERS

BROWSERS_PATH_ENV = "PLAYWRIGHT_BROWSERS_PATH"


class _RecordingType:
    """One Playwright browser type: records each `launch` as `(name, kwargs)` and returns a marker browser."""

    def __init__(self, name: str, launches: list[tuple[str, dict[str, Any]]]) -> None:
        self._name = name
        self._launches = launches

    def launch(self, **kwargs: Any) -> str:
        self._launches.append((self._name, kwargs))
        return f"{self._name} browser"


class _FakePlaywright:
    def __init__(self) -> None:
        self.launches: list[tuple[str, dict[str, Any]]] = []
        self.chromium = _RecordingType("chromium", self.launches)
        self.firefox = _RecordingType("firefox", self.launches)


def test_launch_browser_opens_chrome_through_its_channel() -> None:
    playwright = _FakePlaywright()

    opened = browsers.launch_browser(playwright, "chrome", headless=True)  # type: ignore[arg-type]  # fake

    assert opened == "chromium browser"
    assert playwright.launches == [("chromium", {"channel": "chrome", "headless": True})]


def test_launch_browser_opens_playwrights_firefox() -> None:
    playwright = _FakePlaywright()

    opened = browsers.launch_browser(playwright, "firefox", headless=True)  # type: ignore[arg-type]  # fake

    assert opened == "firefox browser"
    assert playwright.launches == [("firefox", {"headless": True})]


def test_launch_browser_passes_a_visible_request_through() -> None:
    playwright = _FakePlaywright()

    browsers.launch_browser(playwright, "firefox", headless=False)  # type: ignore[arg-type]  # fake

    assert playwright.launches == [("firefox", {"headless": False})]


@pytest.mark.parametrize("name", BROWSERS)
def test_every_catalog_browser_launches(name: str) -> None:
    playwright = _FakePlaywright()

    browsers.launch_browser(playwright, name, headless=True)  # type: ignore[arg-type]  # fake

    assert len(playwright.launches) == 1


def test_an_unknown_browser_is_a_value_error() -> None:
    playwright = _FakePlaywright()

    with pytest.raises(ValueError, match="'safari'"):
        browsers.launch_browser(playwright, "safari", headless=True)  # type: ignore[arg-type]  # fake

    assert playwright.launches == []


def test_toolchain_playwright_points_at_the_toolchain_browsers(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv(BROWSERS_PATH_ENV, "")  # so the undo removes what the call sets
    monkeypatch.delenv(BROWSERS_PATH_ENV)
    sentinel = object()
    monkeypatch.setattr(browsers, "sync_playwright", lambda: sentinel)

    started = browsers.toolchain_playwright()

    assert started is sentinel
    assert os.environ[BROWSERS_PATH_ENV] == str(PLAYWRIGHT_BROWSERS_DIR)


def test_toolchain_playwright_keeps_a_browsers_path_already_set(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv(BROWSERS_PATH_ENV, "/x")
    monkeypatch.setattr(browsers, "sync_playwright", lambda: object())

    browsers.toolchain_playwright()

    assert os.environ[BROWSERS_PATH_ENV] == "/x"


@pytest.mark.parametrize("engine", ["chromium", "firefox"])
def test_browser_engine_reads_the_pages_browser_type(engine: str) -> None:
    page = SimpleNamespace(context=SimpleNamespace(browser=SimpleNamespace(browser_type=SimpleNamespace(name=engine))))

    assert browsers.browser_engine(page) == engine  # type: ignore[arg-type]  # fake


def test_launch_error_names_the_browser_and_the_first_line() -> None:
    error = RuntimeError("\n  BrowserType.launch: it broke\nsecond line")

    assert browsers.launch_error("chrome", error) == "chrome launch failed: BrowserType.launch: it broke"


@pytest.mark.parametrize("name", BROWSERS)
def test_launch_error_points_a_missing_executable_at_setup(name: str) -> None:
    error = RuntimeError("BrowserType.launch: Executable doesn't exist at /t/ms-playwright/firefox-1\nlooks like...")

    assert browsers.launch_error(name, error) == (
        f"{name} launch failed: BrowserType.launch: Executable doesn't exist at /t/ms-playwright/firefox-1"
        "; run tools/e2e/setup.sh"
    )
