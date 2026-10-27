"""Unit tests for the ARIA snapshot reader, on snapshots taken from real runs (no browser)."""

from __future__ import annotations

from stratum_e2e.web import snapshot

REORDER = """- group:
  - button "Item 1"
  - button "Item 6" [disabled]
- text: "Log: nothing yet."
"""

SPLIT = """- text: List
- slider: "1"
- text: Detail
"""

QUOTED = """- button "Say \\"hi\\"" [disabled] [level=2]
- text: "stored left width: none first frame left width: 260"
"""


def test_nodes_read_role_name_flags_and_text_in_tree_order() -> None:
    nodes = snapshot.nodes(REORDER)

    assert [(n.role, n.name, n.flags, n.text) for n in nodes] == [
        ("group", "", (), ""),
        ("button", "Item 1", (), ""),
        ("button", "Item 6", ("disabled",), ""),
        ("text", "", (), "Log: nothing yet."),
    ]


def test_a_node_without_a_name_keeps_the_value_after_the_colon() -> None:
    slider = next(node for node in snapshot.nodes(SPLIT) if node.role == "slider")

    assert (slider.name, slider.text) == ("", "1")


def test_a_name_unescapes_a_quote_and_flags_split_on_their_brackets() -> None:
    button = snapshot.nodes(QUOTED)[0]

    assert button.name == 'Say "hi"'
    assert button.flags == ("disabled", "level=2")


def test_a_text_with_a_colon_is_read_whole_without_its_quotes() -> None:
    text = snapshot.nodes(QUOTED)[1]

    assert text.text == "stored left width: none first frame left width: 260"


def test_texts_give_every_name_and_text_that_is_not_empty() -> None:
    assert snapshot.texts(REORDER) == ["Item 1", "Item 6", "Log: nothing yet."]


def test_an_empty_snapshot_has_no_nodes() -> None:
    assert snapshot.nodes("") == []
