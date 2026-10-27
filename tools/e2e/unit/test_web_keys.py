"""Unit tests for `stratum_e2e.web.keys`: the Mac Option+T press, on recording stubs."""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import pytest

from stratum_e2e.web import keys


class _FakeCdpSession:
    def __init__(self, calls: list[tuple[str, Any]]) -> None:
        self.calls = calls

    def send(self, method: str, params: dict[str, Any]) -> None:
        self.calls.append((method, params))


class _FakePage:
    """Page stub on one engine: records CDP sends, key presses, and CDP session opens."""

    def __init__(self, engine: str) -> None:
        self.calls: list[tuple[str, Any]] = []
        self.sessions_opened = 0
        browser = SimpleNamespace(browser_type=SimpleNamespace(name=engine))
        self.context = SimpleNamespace(browser=browser, new_cdp_session=self._new_cdp_session)
        self.keyboard = SimpleNamespace(press=lambda key: self.calls.append(("press", key)))

    def _new_cdp_session(self, page: "_FakePage") -> _FakeCdpSession:
        assert page is self
        self.sessions_opened += 1
        return _FakeCdpSession(self.calls)


def test_option_t_cdp_events_are_a_mac_option_t() -> None:
    assert keys.OPTION_T_CDP_EVENTS == (
        {"type": "rawKeyDown", "key": "Alt", "code": "AltLeft", "windowsVirtualKeyCode": 18, "location": 1, "modifiers": 1},
        {"type": "keyDown", "key": "†", "code": "KeyT", "text": "†", "windowsVirtualKeyCode": 84, "modifiers": 1},
        {"type": "keyUp", "key": "†", "code": "KeyT", "windowsVirtualKeyCode": 84, "modifiers": 1},
        {"type": "keyUp", "key": "Alt", "code": "AltLeft", "windowsVirtualKeyCode": 18, "location": 1, "modifiers": 0},
    )


def test_press_option_t_sends_the_cdp_events_on_chromium() -> None:
    page = _FakePage("chromium")

    typed = keys.press_option_t(page)  # type: ignore[arg-type]  # stub, not a Page

    assert typed is True
    assert page.calls == [("Input.dispatchKeyEvent", event) for event in keys.OPTION_T_CDP_EVENTS]
    assert not any(name == "press" for name, _ in page.calls)


def test_press_option_t_presses_alt_t_on_firefox() -> None:
    page = _FakePage("firefox")

    typed = keys.press_option_t(page)  # type: ignore[arg-type]  # stub, not a Page

    assert typed is False
    assert page.calls == [("press", "Alt+KeyT")]
    assert page.sessions_opened == 0


@pytest.mark.parametrize("engine", ["chromium", "firefox"])
def test_press_option_t_reads_the_engine_of_the_page(engine: str) -> None:
    page = _FakePage(engine)

    assert keys.press_option_t(page) is (engine == "chromium")  # type: ignore[arg-type]  # stub, not a Page
