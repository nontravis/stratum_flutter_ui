"""Read the OS accessibility tree from a Mac2 page source (design section 6, level 1)."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass

_TYPE_PREFIX = "XCUIElementType"
_WINDOW = f"{_TYPE_PREFIX}Window"


@dataclass(frozen=True)
class Node:
    """One element of the Mac2 tree; an attribute the source leaves out reads as ""."""

    kind: str
    label: str
    value: str
    enabled: bool
    x: int
    y: int
    width: int
    height: int


def _node(element: ET.Element) -> Node:
    def number(attribute: str) -> int:
        return int(float(element.get(attribute) or 0))

    return Node(
        kind=element.tag.removeprefix(_TYPE_PREFIX),
        label=element.get("label") or "",
        value=element.get("value") or "",
        enabled=element.get("enabled") == "true",
        x=number("x"),
        y=number("y"),
        width=number("width"),
        height=number("height"),
    )


def nodes(page_source: str) -> list[Node]:
    """Return every element under the app's windows in tree order.

    The menu bar is left out: its items carry a title and no label, and its entries
    (`Close`) would read as the page's own.
    """
    root = ET.fromstring(page_source.encode("utf-8"))
    return [_node(element) for window in root.iter(_WINDOW) for element in window.iter()]


def texts(page_source: str) -> list[str]:
    """Return the label of each window element, or its value when the label is empty.

    Flutter's macOS embedder publishes a static text's string as the value and leaves its
    label empty. Elements with neither are left out.
    """
    return [text for node in nodes(page_source) if (text := node.label or node.value)]


def window_size(page_source: str) -> tuple[int, int] | None:
    """Return the first window's (width, height), or None when the source holds no window."""
    first = next(iter(nodes(page_source)), None)
    return None if first is None else (first.width, first.height)
