"""Read the OS accessibility tree from an XCUITest page source (design section 6, level 1)."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass

_TYPE_PREFIX = "XCUIElementType"


@dataclass(frozen=True)
class Node:
    """One element of the XCUITest tree; an attribute the source leaves out reads as ""."""

    kind: str
    name: str
    label: str
    value: str
    enabled: bool
    accessible: bool
    traits: tuple[str, ...]
    x: int
    y: int
    width: int
    height: int


def _node(element: ET.Element) -> Node:
    def number(attribute: str) -> int:
        return int(element.get(attribute) or 0)

    return Node(
        kind=element.tag.removeprefix(_TYPE_PREFIX),
        name=element.get("name") or "",
        label=element.get("label") or "",
        value=element.get("value") or "",
        enabled=element.get("enabled") == "true",
        accessible=element.get("accessible") == "true",
        traits=tuple(
            trait.strip() for trait in (element.get("traits") or "").split(",") if trait.strip()
        ),
        x=number("x"),
        y=number("y"),
        width=number("width"),
        height=number("height"),
    )


def nodes(page_source: str) -> list[Node]:
    """Return every element of [page_source] in tree order."""
    root = ET.fromstring(page_source.encode("utf-8"))
    return [_node(element) for element in root.iter()]


def find(page_source: str, name: str) -> Node | None:
    """Return the first element named [name] in [page_source], or None when there is none."""
    return next((node for node in nodes(page_source) if node.name == name), None)


def names(page_source: str) -> set[str]:
    """Return the names of every element in [page_source]: Flutter semantics identifiers and labels."""
    return {node.name for node in nodes(page_source)} - {""}


def labels(page_source: str) -> list[str]:
    """Return the labels of the elements in [page_source], in tree order; unlabeled ones are skipped."""
    return [node.label for node in nodes(page_source) if node.label]
