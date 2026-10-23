"""Unit tests for the web page helpers, locator, and fixture launch, on recording stubs."""

from __future__ import annotations

from typing import Any

import pytest

from stratum_e2e import fixtures, locate
from stratum_e2e.web import session
from stratum_e2e.web.session import (
    accessibility_snapshot,
    requested_resources,
    slider_value_text,
    web_page,
)

BASE_URL = "http://127.0.0.1:8123"


class FakeLocator:
    def __init__(self, selector: str, page: "FakePage") -> None:
        self.selector = selector
        self.page = page

    def aria_snapshot(self) -> str:
        return f"snapshot of {self.selector}"

    def get_attribute(self, name: str, **options: Any) -> str | None:
        self.page.calls.append(("get_attribute", (self.selector, name, options)))
        return "30%"

    def text_content(self, **options: Any) -> str:
        self.page.calls.append(("text_content", options))
        return f"text of {self.selector}"


class FakePage:
    """Page stub that records navigation, waits, and locator calls."""

    def __init__(self) -> None:
        self.calls: list[tuple[str, Any]] = []
        self.resources: list[str] = []

    def goto(self, url: str) -> None:
        self.calls.append(("goto", url))

    def wait_for_selector(self, selector: str, **options: Any) -> None:
        self.calls.append(("wait_for_selector", (selector, options)))

    def locator(self, selector: str) -> FakeLocator:
        self.calls.append(("locator", selector))
        return FakeLocator(selector, self)

    def evaluate(self, expression: str) -> list[str]:
        self.calls.append(("evaluate", expression))
        return self.resources


class FakeBrowser:
    def __init__(self) -> None:
        self.page = FakePage()
        self.new_page_options: dict[str, Any] | None = None

    def new_page(self, **options: Any) -> FakePage:
        self.new_page_options = options
        return self.page


def test_web_page_opens_the_fixture_route_in_a_new_page() -> None:
    browser = FakeBrowser()

    page = web_page(browser, BASE_URL, "smoke/semantics_id")  # type: ignore[arg-type]  # stub, not a Browser

    assert page is browser.page
    assert browser.new_page_options == {"base_url": BASE_URL}
    assert ("goto", "/#/fixture/smoke/semantics_id") in page.calls


def test_web_page_waits_for_a_semantics_node_before_it_returns() -> None:
    browser = FakeBrowser()

    page = web_page(browser, BASE_URL, "smoke/semantics_id")  # type: ignore[arg-type]  # stub, not a Browser

    wait = [args for name, args in page.calls if name == "wait_for_selector"]
    assert wait == [(session.SEMANTICS_NODE, {"state": "attached", "timeout": session.READY_TIMEOUT_MS})]


def test_open_fixture_route_leaves_the_old_document_before_it_loads_the_route() -> None:
    page = FakePage()

    session.open_fixture_route(page, "common/page_layout")  # type: ignore[arg-type]  # stub, not a Page

    assert [args for name, args in page.calls if name == "goto"] == [
        "about:blank",
        "/#/fixture/common/page_layout",
    ]


def test_open_fixture_on_web_uses_the_page_route_helper() -> None:
    page = FakePage()

    fixtures.open_fixture(page, "web", "ignored", "common/page_layout")

    assert ("goto", "/#/fixture/common/page_layout") in page.calls


def test_accessibility_snapshot_reads_the_aria_snapshot_of_the_body() -> None:
    page = FakePage()

    assert accessibility_snapshot(page) == "snapshot of body"  # type: ignore[arg-type]  # stub, not a Page


def test_requested_resources_lists_the_urls_the_page_fetched() -> None:
    page = FakePage()
    page.resources = [f"{BASE_URL}/main.dart.js"]

    assert requested_resources(page) == [f"{BASE_URL}/main.dart.js"]  # type: ignore[arg-type]  # stub, not a Page


def test_by_id_on_web_matches_the_semantics_identifier_attribute() -> None:
    page = FakePage()

    locator = locate.by_id(page, "web", "smoke.button")

    assert isinstance(locator, FakeLocator)
    assert locator.selector == '[flt-semantics-identifier="smoke.button"]'


@pytest.mark.parametrize("text", ['a"b', "a\\b"])
def test_by_id_on_web_refuses_a_quote_or_backslash(text: str) -> None:
    page = FakePage()

    with pytest.raises(ValueError, match="quote or backslash"):
        locate.by_id(page, "web", text)

    assert page.calls == []


def test_label_of_on_web_reads_the_text_of_the_semantics_node() -> None:
    locator = FakeLocator("x", FakePage())

    assert locate.label_of(locator, "web") == "text of x"


def test_label_of_on_web_gives_up_on_a_missing_node_within_a_poll_not_the_page_timeout() -> None:
    page = FakePage()

    locate.label_of(page.locator("x"), "web")

    assert ("text_content", {"timeout": locate.WEB_READ_TIMEOUT_MS}) in page.calls


def test_slider_value_text_reads_aria_valuetext_of_the_slider_input() -> None:
    page = FakePage()

    assert slider_value_text(page) == "30%"  # type: ignore[arg-type]  # stub, not a Page
    assert ("locator", 'flt-semantics input[role="slider"]') in page.calls
    assert (
        "get_attribute",
        ('flt-semantics input[role="slider"]', "aria-valuetext", {"timeout": session.READ_TIMEOUT_MS}),
    ) in page.calls
