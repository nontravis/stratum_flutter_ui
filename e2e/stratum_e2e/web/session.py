"""Playwright page helpers for a Flutter web build (design section 8)."""

from __future__ import annotations

from playwright.sync_api import Browser, Page

SEMANTICS_NODE = "flt-semantics"
READY_TIMEOUT_MS = 30_000
_BLANK_PAGE = "about:blank"


def open_fixture_route(page: Page, fixture_id: str) -> None:
    """Cold-load the fixture route for [fixture_id] in [page] and wait for its semantics tree.

    Leaves the current document first: a change of the URL hash alone would only
    navigate Flutter's router and keep the running app, not restart it. [page] needs
    a `base_url`, which `web_page` and the `driver` fixture set.
    Raises playwright's TimeoutError when no semantics node appears, as in a blank render.
    """
    page.goto(_BLANK_PAGE)
    page.goto(f"/#/fixture/{fixture_id}")
    page.wait_for_selector(SEMANTICS_NODE, state="attached", timeout=READY_TIMEOUT_MS)


def web_page(browser: Browser, base_url: str, fixture_id: str) -> Page:
    """Open a new page on `<base_url>/#/fixture/<fixture_id>` once its semantics tree exists."""
    page = browser.new_page(base_url=base_url)
    open_fixture_route(page, fixture_id)
    return page


def accessibility_snapshot(page: Page) -> str:
    """Return the ARIA snapshot of [page]'s body: the tree a screen reader would read."""
    return page.locator("body").aria_snapshot()


def requested_resources(page: Page) -> list[str]:
    """Return the URL of every resource [page] fetched, in the order the browser timed them."""
    urls: list[str] = page.evaluate("performance.getEntriesByType('resource').map(e => e.name)")
    return urls
