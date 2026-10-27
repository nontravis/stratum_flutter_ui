"""Parse the ``WINDOW MANAGER WINDOWS`` section of ``dumpsys window`` output.

Pure text helpers shared by the settle gates and the system-bar checks. Only that
section holds live per-window state; the sections around it repeat stale snapshots
frozen at earlier instants.
"""

from __future__ import annotations

import re


def live_windows_section(window_dump: str) -> str:
    """Slices the dump to its ``WINDOW MANAGER WINDOWS`` section.

    Only that section holds live per-window fields. The ``LAST ANR`` section after
    an app ANR repeats the app's ``package=`` frozen at the ANR instant, and must
    never be read. A dump with no such header is returned unchanged.
    """
    m = re.search(r"^WINDOW MANAGER WINDOWS\b.*$", window_dump, re.MULTILINE)
    if m is None:
        return window_dump
    start = m.end()
    m2 = re.search(r"^WINDOW MANAGER \S", window_dump[start:], re.MULTILINE)
    end = start + m2.start() if m2 else len(window_dump)
    return window_dump[start:end]


def live_window_blocks(window_dump: str) -> list[str]:
    """Splits the live windows section into per-window blocks, header line first."""
    return re.split(r"(?=^ *Window #\d+)", live_windows_section(window_dump), flags=re.MULTILINE)


def window_title(block: str) -> str | None:
    """Returns the title in a block's ``Window{<hash> u<user> <title>}`` header."""
    m = re.match(r" *Window #\d+ Window\{\S+ u\d+ (.*)\}:", block)
    return m.group(1) if m else None
