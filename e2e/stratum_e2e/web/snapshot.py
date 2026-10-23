"""Read a Playwright ARIA snapshot as nodes (design section 6, level 1 on web)."""

from __future__ import annotations

import re
from dataclasses import dataclass

# `- button "Item 6" [disabled]`, `- text: List`, `- slider: "1"`, `- group:`
_LINE = re.compile(
    r'^\s*- (?P<role>[\w-]+)'
    r'(?: "(?P<name>(?:[^"\\]|\\.)*)")?'
    r'(?P<flags>(?: \[[^\]]*\])*)'
    r'(?::(?: (?P<text>.*))?)?$'
)
_FLAG = re.compile(r"\[([^\]]*)\]")
_ESCAPED = re.compile(r"\\(.)")


@dataclass(frozen=True)
class SnapshotNode:
    """One line of an ARIA snapshot: the role, the quoted name, the bracket flags, the text after the colon."""

    role: str
    name: str
    flags: tuple[str, ...]
    text: str


def _unquote(text: str) -> str:
    if len(text) >= 2 and text.startswith('"') and text.endswith('"'):
        return _ESCAPED.sub(r"\1", text[1:-1])
    return text


def nodes(snapshot: str) -> list[SnapshotNode]:
    """Return the node of each line of [snapshot] in tree order; a line that is no node is skipped."""
    found: list[SnapshotNode] = []
    for line in snapshot.splitlines():
        match = _LINE.match(line)
        if match is None:
            continue
        found.append(
            SnapshotNode(
                role=match["role"],
                name=_ESCAPED.sub(r"\1", match["name"] or ""),
                flags=tuple(_FLAG.findall(match["flags"] or "")),
                text=_unquote(match["text"] or ""),
            )
        )
    return found


def texts(snapshot: str) -> list[str]:
    """Return the name of each node, or its text when it has no name; empty ones are left out."""
    return [text for node in nodes(snapshot) if (text := node.name or node.text)]
