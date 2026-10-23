"""Unit tests for the iOS focus-order reader and tree reader, on stubs (no simulator)."""

from __future__ import annotations

from typing import Any

import pytest
from stratum_e2e.ios import focus_order as focus_order_module
from stratum_e2e.ios.focus_order import focus_order, matches_order, strip_app_name
from stratum_e2e.ios.tree import find, labels, names, nodes
from stratum_e2e.ios.voiceover import VoiceOver, VoiceOverSilent

APP_NAME = "Stratum Ui Test App"


class FakeDriver:
    """Driver stub: the page source, the first stop speech, then `moves` for voiceOverMove."""

    page_source = (
        f'<AppiumAUT><XCUIElementTypeApplication name="{APP_NAME}" label="{APP_NAME}"/></AppiumAUT>'
    )

    def __init__(self, first: str | None | list[str | None], moves: list[str | None]) -> None:
        self.firsts = list(first) if isinstance(first, list) else [first]
        self.moves = list(moves)

    def execute_script(self, script: str, args: dict[str, Any] | None = None) -> Any:
        if script == "mobile: voiceOverCurrentSpeech":
            return {"utterance": self.firsts.pop(0) if len(self.firsts) > 1 else self.firsts[0]}
        if script == "mobile: voiceOverMove":
            return {"utterance": self.moves.pop(0)}
        return None


@pytest.mark.parametrize(
    ("utterance", "expected"),
    [
        (f"{APP_NAME} Button Actions available", "Button Actions available"),
        (f"{APP_NAME} List", "List"),
        (APP_NAME, ""),
        (None, ""),
        ("Item 1 Button", "Item 1 Button"),
    ],
)
def test_strip_app_name(utterance: str | None, expected: str) -> None:
    assert strip_app_name(utterance, APP_NAME) == expected


def test_focus_order_puts_the_first_stop_ahead_of_the_walk() -> None:
    driver = FakeDriver(f"{APP_NAME} Dismiss Button", ["Close Button", "Choose A Button", "Dismiss", "Dismiss"])

    order = focus_order(driver, VoiceOver(driver))

    assert order == ["Dismiss Button", "Close Button", "Choose A Button", "Dismiss"]


def test_focus_order_waits_for_the_first_stop_to_speak() -> None:
    driver = FakeDriver([None, APP_NAME, f"{APP_NAME} Menu target Button"], ["Log", "Log"])

    assert focus_order(driver, VoiceOver(driver)) == ["Menu target Button", "Log"]


def test_focus_order_drops_a_first_stop_that_never_speaks_past_the_app_name(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(focus_order_module, "FIRST_STOP_TIMEOUT_S", 0.1)
    driver = FakeDriver(APP_NAME, ["Item 1 Button", "Item 1 Button"])

    assert focus_order(driver, VoiceOver(driver)) == ["Item 1 Button"]


def test_focus_order_raises_when_the_walk_is_silent() -> None:
    driver = FakeDriver(f"{APP_NAME} List", [None] * 30)

    with pytest.raises(VoiceOverSilent):
        focus_order(driver, VoiceOver(driver))


def test_matches_order_compares_by_the_64_character_prefix() -> None:
    long_expected = "Resize panes 30% adjustable Swipe up or down with one finger to adjust the value"
    spoken = ["List", long_expected[:64]]

    assert matches_order(spoken, ["List", long_expected])


@pytest.mark.parametrize(
    ("spoken", "expected"),
    [(["a"], ["a", "b"]), (["a", "c"], ["a", "b"]), ([], ["a"])],
)
def test_matches_order_rejects_a_different_length_or_a_different_stop(
    spoken: list[str], expected: list[str]
) -> None:
    assert not matches_order(spoken, expected)


PAGE = """<XCUIElementTypeApplication type="XCUIElementTypeApplication" name="App" label="App" enabled="true" x="0" y="0" width="400" height="800">
  <XCUIElementTypeOther type="XCUIElementTypeOther" enabled="true" accessible="false" traits="" x="0" y="300" width="400" height="48">
    <XCUIElementTypeButton type="XCUIElementTypeButton" enabled="true" accessible="true" traits="Button" x="0" y="300" width="400" height="48"/>
    <XCUIElementTypeStaticText type="XCUIElementTypeStaticText" name="a.button" label="Menu target" value="Menu target" enabled="true" accessible="true" traits="StaticText" x="0" y="300" width="400" height="48"/>
  </XCUIElementTypeOther>
  <XCUIElementTypeButton type="XCUIElementTypeButton" name="Item 6" label="Item 6" enabled="false" accessible="true" traits="NotEnabled, Button" x="0" y="400" width="400" height="48"/>
</XCUIElementTypeApplication>"""


def test_nodes_read_kind_attributes_and_traits() -> None:
    item = [node for node in nodes(PAGE) if node.name == "Item 6"][0]

    assert (item.kind, item.label, item.enabled, item.accessible) == ("Button", "Item 6", False, True)
    assert item.traits == ("NotEnabled", "Button")
    assert (item.x, item.y, item.width, item.height) == (0, 400, 400, 48)


def test_names_and_labels_skip_unnamed_and_unlabeled_nodes() -> None:
    assert names(PAGE) == {"App", "a.button", "Item 6"}
    assert labels(PAGE) == ["App", "Menu target", "Item 6"]


def test_find_returns_the_first_element_with_the_name_or_none() -> None:
    found = find(PAGE, "Item 6")

    assert found is not None and found.label == "Item 6"
    assert find(PAGE, "nope") is None
