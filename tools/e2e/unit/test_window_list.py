"""Unit tests for the pure ``WINDOW MANAGER WINDOWS`` section parsers."""

from __future__ import annotations

from pathlib import Path

from stratum_e2e.android.window_list import live_window_blocks, live_windows_section, window_title

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "round" / "android"


def _fixture(name: str) -> str:
    return (FIXTURES / name).read_text()


def test_live_windows_section_slices_from_header_to_next_section() -> None:
    window = _fixture("focus_normal.txt")
    dump = (
        "WINDOW MANAGER LAST ANR (dumpsys window lastanr)\n  stale\n\n"
        "WINDOW MANAGER WINDOWS (dumpsys window windows)\n" + window + "WINDOW MANAGER TRACE\n"
    )
    assert live_windows_section(dump) == "\n" + window


def test_live_windows_section_returns_dump_unchanged_without_header() -> None:
    assert live_windows_section("no sections here\n") == "no sections here\n"


def test_live_window_blocks_split_on_each_window_header() -> None:
    blocks = live_window_blocks(_fixture("windows_anr_unfocused_api35.txt"))
    assert len(blocks) == 7  # the leading preamble plus six window blocks
    assert window_title(blocks[3]) == "Application Not Responding: com.android.systemui"


def test_window_title_reads_hash_user_and_activity_title() -> None:
    assert window_title(_fixture("anr_title_shape.txt")) == "Application Not Responding: com.android.systemui"
    assert window_title(_fixture("focus_normal.txt")) == "com.example/com.example.MainActivity"


def test_window_title_keeps_an_exiting_suffix() -> None:
    header = _fixture("anr_exiting.txt").splitlines()[1]
    assert window_title(header + "\n") == "Application Not Responding: com.android.systemui EXITING"


def test_window_title_returns_none_for_a_non_window_block() -> None:
    assert window_title("  mOwnerUid=1000 package=android\n") is None
