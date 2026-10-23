"""Unit tests for the Mac2 page-source reader, on a source trimmed from a real run (no device)."""

from __future__ import annotations

from stratum_e2e.macos import tree

# The shape Mac2 returns for the modal fixture: the app, one window with the Flutter group
# under it, and the menu bar, whose items carry a title and an empty label.
SOURCE = """<?xml version="1.0" encoding="UTF-8"?>
<XCUIElementTypeApplication elementType="1" label="stratum_ui_test_app" title="stratum_ui_test_app" enabled="true" x="0" y="0" width="2560" height="1440">
  <XCUIElementTypeWindow elementType="4" identifier="_NS:6" label="" title="stratum_ui_test_app" enabled="false" x="100" y="200" width="480" height="640">
    <XCUIElementTypeGroup elementType="3" identifier="" label="stratum_ui_test_app" title="" enabled="false" x="100" y="228" width="480" height="612">
      <XCUIElementTypeButton elementType="9" identifier="" value="" label="Choose A" title="Choose A" enabled="true" x="120" y="300" width="100" height="40"/>
      <XCUIElementTypeButton elementType="9" identifier="" value="" label="Item 6" title="Item 6" enabled="false" x="120" y="400" width="100" height="40"/>
      <XCUIElementTypeSlider elementType="33" identifier="" value="30%" label="Resize panes" title="Resize panes" enabled="true" x="300" y="300" width="20" height="100"/>
      <XCUIElementTypeStaticText elementType="48" identifier="" value="Dismiss" label="" title="" enabled="true" x="120" y="500" width="60" height="20"/>
    </XCUIElementTypeGroup>
    <XCUIElementTypeButton elementType="9" identifier="_XCUI:CloseWindow" label="" title="" enabled="true" x="108" y="206" width="14" height="16"/>
  </XCUIElementTypeWindow>
  <XCUIElementTypeMenuBar elementType="55" identifier="_NS:324" label="" title="" enabled="true" x="0" y="0" width="2560" height="30">
    <XCUIElementTypeMenuBarItem elementType="56" identifier="" label="Close" title="File" enabled="true" x="10" y="0" width="34" height="30"/>
  </XCUIElementTypeMenuBar>
</XCUIElementTypeApplication>
"""


def test_nodes_hold_only_the_window_subtree_in_tree_order() -> None:
    kinds = [(node.kind, node.label or node.value) for node in tree.nodes(SOURCE)]

    assert kinds == [
        ("Window", ""),
        ("Group", "stratum_ui_test_app"),
        ("Button", "Choose A"),
        ("Button", "Item 6"),
        ("Slider", "Resize panes"),
        ("StaticText", "Dismiss"),
        ("Button", ""),
    ]


def test_a_node_reads_its_label_value_enabled_flag_and_frame() -> None:
    slider = next(node for node in tree.nodes(SOURCE) if node.kind == "Slider")

    assert (slider.label, slider.value, slider.enabled) == ("Resize panes", "30%", True)
    assert (slider.x, slider.y, slider.width, slider.height) == (300, 300, 20, 100)


def test_a_disabled_node_reads_not_enabled() -> None:
    item = next(node for node in tree.nodes(SOURCE) if node.label == "Item 6")

    assert item.enabled is False


def test_texts_give_each_label_or_value_that_is_not_empty() -> None:
    assert tree.texts(SOURCE) == [
        "stratum_ui_test_app",
        "Choose A",
        "Item 6",
        "Resize panes",
        "Dismiss",
    ]


def test_window_size_reads_the_first_windows_width_and_height() -> None:
    assert tree.window_size(SOURCE) == (480, 640)


def test_a_source_with_no_window_has_no_nodes_and_no_size() -> None:
    source = '<XCUIElementTypeApplication label="x"/>'

    assert tree.nodes(source) == []
    assert tree.window_size(source) is None
