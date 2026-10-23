"""Unit tests for the page-source readers of the OS accessibility tree (no device)."""

from __future__ import annotations

from stratum_e2e.android.tree import key_focused, labels_with, parent_attributes, resource_ids

PAGE = """<hierarchy>
  <node resource-id="" content-desc="" text="" focused="true"/>
  <node resource-id="a.button" content-desc="Choose A" text="" focused="true"/>
  <node resource-id="" content-desc="Close" text="" focused="false"/>
  <node resource-id="a.log" content-desc="" text="Log: menu" focused="true"/>
  <node resource-id="a.button" content-desc="Choose A" text="" focused="false"/>
</hierarchy>"""


def test_resource_ids_are_the_distinct_non_empty_identifiers() -> None:
    assert resource_ids(PAGE) == {"a.button", "a.log"}


def test_resource_ids_of_an_empty_tree() -> None:
    assert resource_ids("<hierarchy/>") == set()


def test_key_focused_lists_labels_of_focused_nodes_only() -> None:
    assert key_focused(PAGE) == ["Choose A", "Log: menu"]


def test_key_focused_skips_unlabeled_nodes() -> None:
    assert key_focused('<hierarchy><node content-desc="" text="" focused="true"/></hierarchy>') == []


TREE = """<hierarchy>
  <node class="android.view.View" resource-id="">
    <node class="android.widget.Button" resource-id="">
      <node class="android.view.View" resource-id="a.button" content-desc="Menu target"/>
    </node>
  </node>
</hierarchy>"""


def test_parent_attributes_reads_the_parent_of_the_id_node() -> None:
    parent = parent_attributes(TREE, "a.button")

    assert parent is not None
    assert parent["class"] == "android.widget.Button"


def test_parent_attributes_is_none_for_an_unknown_id() -> None:
    assert parent_attributes(TREE, "missing") is None


def test_parent_attributes_is_none_for_the_root() -> None:
    assert parent_attributes('<node resource-id="root"/>', "root") is None


def test_labels_with_reads_the_attribute_it_is_given() -> None:
    page = (
        '<hierarchy><node text="Item 2" a11y-focused="true" focused="false"/>'
        '<node content-desc="Item 3" a11y-focused="false" focused="true"/></hierarchy>'
    )

    assert labels_with(page, "a11y-focused") == ["Item 2"]
    assert labels_with(page, "focused") == ["Item 3"]
    assert labels_with(page, "absent") == []
