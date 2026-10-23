"""Read the OS accessibility tree from an Appium page source (design section 6, level 1)."""

from __future__ import annotations

import xml.etree.ElementTree as ET


def resource_ids(page_source: str) -> set[str]:
    """Return the resource-ids (Flutter semantics identifiers) of every node in [page_source]."""
    root = ET.fromstring(page_source.encode("utf-8"))
    return {node.get("resource-id") or "" for node in root.iter()} - {""}


def labels(page_source: str) -> list[str]:
    """Return the labels (`text`, else `content-desc`) of every labeled node, in tree order."""
    root = ET.fromstring(page_source.encode("utf-8"))
    found = (node.get("text") or node.get("content-desc") or "" for node in root.iter())
    return [label for label in found if label]


def labels_with(page_source: str, attribute: str) -> list[str]:
    """Return the labels of nodes whose [attribute] is "true" in [page_source], in tree order.

    A label is the node's `text`, else its `content-desc`; unlabeled nodes are skipped.
    """
    root = ET.fromstring(page_source.encode("utf-8"))
    labels = (
        node.get("text") or node.get("content-desc") or ""
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
