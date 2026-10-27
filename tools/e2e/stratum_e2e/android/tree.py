"""Read the OS accessibility tree from an Appium page source (design section 6, level 1)."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET

_BOUNDS = re.compile(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]")


def resource_ids(page_source: str) -> set[str]:
    """Return the resource-ids (Flutter semantics identifiers) of every node in [page_source]."""
    root = ET.fromstring(page_source.encode("utf-8"))
    return {node.get("resource-id") or "" for node in root.iter()} - {""}


def node_label(node: ET.Element) -> str:
    """Return a node's label: its `text`, else `content-desc`, else `hint`; "" when it has none.

    A Flutter text field is an `android.widget.EditText` with empty `text` and no
    `content-desc`: its semantics label (and the group label merged into it) sits in `hint`.
    """
    return node.get("text") or node.get("content-desc") or node.get("hint") or ""


def labels(page_source: str) -> list[str]:
    """Return the labels (see `node_label`) of every labeled node, in tree order."""
    root = ET.fromstring(page_source.encode("utf-8"))
    found = (node_label(node) for node in root.iter())
    return [label for label in found if label]


def labels_with(page_source: str, attribute: str) -> list[str]:
    """Return the labels of nodes whose [attribute] is "true" in [page_source], in tree order.

    A label is the node's `node_label`; unlabeled nodes are skipped.
    """
    root = ET.fromstring(page_source.encode("utf-8"))
    labels = (
        node_label(node)
        for node in root.iter()
        if node.get(attribute) == "true"
    )
    return [label for label in labels if label]


def key_focused(page_source: str) -> list[str]:
    """Return the labels of nodes holding keyboard (input) focus in [page_source].

    Unlabeled nodes, such as the Flutter view that holds focus before any widget does,
    are skipped.
    """
    return labels_with(page_source, "focused")


def parent_attributes(page_source: str, identifier: str) -> dict[str, str] | None:
    """Return the attributes of the parent of the node whose resource-id is [identifier].

    None when no node has that id, or when it is the root. UiAutomator2 rejects a relative
    `..` lookup from an element, so the parent is read from the page source.
    """
    root = ET.fromstring(page_source.encode("utf-8"))
    for parent in root.iter():
        for child in parent:
            if child.get("resource-id") == identifier:
                return dict(parent.attrib)
    return None


def bounds(attributes: dict[str, str]) -> tuple[int, int, int, int]:
    """Return `(left, top, right, bottom)` from a node's `bounds` attribute.

    Raises ValueError when [attributes] holds no well-formed `bounds`.
    """
    match = _BOUNDS.fullmatch(attributes.get("bounds", ""))
    if match is None:
        raise ValueError(f"no bounds in {attributes!r}")
    left, top, right, bottom = (int(group) for group in match.groups())
    return left, top, right, bottom
