"""Launches the browser a web target names: Chrome through its channel, or Playwright's bundled Firefox."""

from __future__ import annotations

import os

from playwright.sync_api import Browser, Page, Playwright, sync_playwright
from playwright.sync_api._context_manager import PlaywrightContextManager

from stratum_e2e.paths import PLAYWRIGHT_BROWSERS_DIR


def toolchain_playwright() -> PlaywrightContextManager:
    """Returns `sync_playwright()` looking for its browsers in the toolchain folder unless the env already names one."""
    os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", str(PLAYWRIGHT_BROWSERS_DIR))
    return sync_playwright()


def launch_browser(playwright: Playwright, name: str, *, headless: bool) -> Browser:
    """Launches the catalog browser [name] (`chrome` or `firefox`); raises `ValueError` for any other name."""
    if name == "chrome":
        return playwright.chromium.launch(channel="chrome", headless=headless)
    if name == "firefox":
        return playwright.firefox.launch(headless=headless)
    raise ValueError(f"unknown browser '{name}'; the catalog names chrome or firefox")


def launch_error(name: str, error: Exception) -> str:
    """Returns the `RoundEnvError` message of a failed launch of [name]: the error's first line, plus the fix when the browser is not installed."""
    first_line = next((line.strip() for line in str(error).splitlines() if line.strip()), "")
    message = f"{name} launch failed: {first_line}"
    if "Executable doesn't exist" in first_line:
        message += "; run tools/e2e/setup.sh"
    return message


def browser_engine(page: Page) -> str:
    """Returns the engine that renders [page]: `chromium` or `firefox`."""
    browser = page.context.browser
    assert browser is not None, "a page of a persistent context has no browser"
    return browser.browser_type.name
