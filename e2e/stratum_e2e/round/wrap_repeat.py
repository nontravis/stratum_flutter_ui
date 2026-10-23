"""Wraps named testWidgets blocks in a loop of n runs (owned by `e2e/`, the device round).

Reads <source> and writes `<dir>/.dt_<stem>[_<tag>]_x<n>.dart` beside it: every
block whose name starts with one of the comma-separated prefixes is wrapped in
`for (var run = 0; run < n; run++) { // REPEAT ... } // REPEAT`, renamed
`REPEAT run $run <name>`, and prints `REPEAT <prefix> <i>/<n> ok` as its last
statement, so a record can count the iterations that passed (an iteration
that throws never reaches the print). The source file is never edited;
`entry.write_run_file` writes the sibling and `entry.cleanup` deletes it
afterwards. `<tag>` keeps two callers of one source from sharing a sibling.

Run the command line with `python3 -I` so a planted same-named module in the
target directory cannot be imported instead of the standard library.

Exit 0 after writing (prints `wrapped <k> blocks -> <path>`); 1 when a prefix
has no block or a block is malformed (nothing is written); 2 on usage.

`--check <source> <prefix>` only answers whether one block's name starts
with `prefix` in `<source>` (not whether that block is well-formed enough to
wrap): exit 0 when `find_opener` finds the name, 1 when it doesn't, 2 on
usage; nothing is printed or written either way. A malformed block (one
`find_block` itself rejects) still has its name found by `--check` just like
a well-formed one, so a launch still reaches the wrap step for it and fails
loudly there instead of this check silently skipping it. This keeps the
opener matching rule in this one file.
"""

from __future__ import annotations

import re
import sys
from collections.abc import Sequence
from pathlib import Path

_USAGE_ERROR = 2


def find_opener(text: str, prefix: str) -> re.Match[str] | None:
    """Returns the `re.Match` of the `testWidgets(` call whose quoted name
    starts with `prefix`, or `None`. Whitespace, newline included, is
    allowed between `testWidgets(` and the quote, so a name dart format
    wraps onto the next line is found the same as a one-line name. The only
    place this opener pattern is written; `find_block` and `--check` both
    call it so the two never drift.
    """
    pattern = re.compile(r"testWidgets\(\s*'" + re.escape(prefix))
    return pattern.search(text)


def find_block(text: str, prefix: str) -> tuple[int, int, str, int]:
    """Returns (block_start, block_end, marker, close_brace) for the
    testWidgets call whose name starts with `prefix`. `block_start` is the
    start of the line that opens the call; `block_end` is just past the `});`
    (plus a trailing newline, when present) that closes it, found by counting
    brace depth from the callback's opening `{`; `close_brace` is the index
    of the callback's closing `}`. `marker` is the exact `testWidgets(` call
    opener matched, whitespace and all, so a name dart format wrapped onto
    the next line is found the same as a one-line name. The close is read the
    same way: `});` on one line, or dart format's wrapped `},` then a
    trailing comma, newline, and `);` once the call's argument list itself
    wraps.
    """
    match = find_opener(text, prefix)
    if match is None:
        raise ValueError(f"no test block starts with {prefix!r}")
    start = match.start()
    marker = match.group()
    line_start = text.rfind("\n", 0, start) + 1

    open_brace = text.index("{", start)
    depth = 0
    i = open_brace
    while i < len(text):
        char = text[i]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    else:
        raise ValueError(f"unbalanced braces after {prefix!r}")
    close_brace = i

    close_match = re.match(r"[ \t]*,?\s*\);", text[close_brace + 1:])
    if close_match is None:
        raise ValueError(f'expected ");" right after the block for {prefix!r}')
    end = close_brace + 1 + close_match.end()
    if end < len(text) and text[end] == "\n":
        end += 1

    return line_start, end, marker, close_brace


def dart_string(text: str) -> str:
    """Escapes `text` for a single-quoted Dart string."""
    return text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def wrap(text: str, prefix: str, n: int) -> str:
    """Returns `text` with the block named `prefix` wrapped in an `n`-run loop that prints one `REPEAT` line per pass."""
    start, end, marker, close_brace = find_block(text, prefix)
    block = text[start:end]
    close_offset = close_brace - start

    stripped = block.lstrip(" ")
    indent = block[:len(block) - len(stripped)]
    ok_line = (
        f"  // ignore: avoid_print\n"
        f"{indent}  print('REPEAT {dart_string(prefix)} ${{run + 1}}/{n} ok');\n{indent}"
    )
    block = block[:close_offset] + ok_line + block[close_offset:]
    block = block.replace(marker, "testWidgets('REPEAT run $run " + prefix, 1)
    return (
        text[:start]
        + f"{indent}for (var run = 0; run < {n}; run++) {{ // REPEAT\n"
        + block
        + f"{indent}}} // REPEAT\n"
        + text[end:]
    )


def sibling_path(source: Path, n: int, tag: str | None = None) -> Path:
    """Returns where the wrapped copy of `source` lands: `.dt_<stem>[_<tag>]_x<n>.dart` beside it."""
    stem = source.name.removesuffix(".dart")
    middle = f"_{tag}" if tag else ""
    return source.with_name(f".dt_{stem}{middle}_x{n}.dart")


def wrap_file(source: Path, prefixes: Sequence[str], n: int, tag: str | None = None) -> Path:
    """Writes the wrapped sibling of `source` and returns its path.

    Raises `ValueError` before writing anything when `n` is below 1, `prefixes` is empty, or a prefix names no
    well-formed block.
    """
    if n < 1:
        raise ValueError(f"n must be at least 1, got {n}")
    if not prefixes:
        raise ValueError("the prefix list is empty")
    text = source.read_text(encoding="utf-8")
    for prefix in prefixes:
        text = wrap(text, prefix, n)
    out = sibling_path(source, n, tag)
    out.write_text(text, encoding="utf-8")
    return out


def check(argv: Sequence[str]) -> int:
    """`--check <source> <prefix>`: exit 0 when a block's name starts with
    `prefix`, 1 when none does, 2 on usage. Never writes or prints. Asks only
    `find_opener`, not `find_block`: a malformed block's name still counts
    as found here, so it is the wrap step (`find_block`) that rejects it
    later, with the loud "malformed" failure the caller already expects.
    """
    if len(argv) != 4:
        print("usage: wrap_repeat.py --check <source> <test-name-prefix>", file=sys.stderr)
        return _USAGE_ERROR
    path, prefix = argv[2], argv[3]
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        print(f"{exc}", file=sys.stderr)
        return _USAGE_ERROR
    return 0 if find_opener(text, prefix) is not None else 1


def main(argv: Sequence[str]) -> int:
    """Runs the command line described in the module docstring and returns its exit status."""
    if len(argv) > 1 and argv[1] == "--check":
        return check(argv)

    if len(argv) not in (4, 5):
        print("usage: wrap_repeat.py <source> <test-name-prefix>[, <prefix>] <n> [<tag>]", file=sys.stderr)
        return _USAGE_ERROR

    path, prefix_text, n_text = argv[1], argv[2], argv[3]
    tag = argv[4] if len(argv) == 5 else None
    try:
        n = int(n_text)
    except ValueError:
        print(f"n must be an integer, got {n_text!r}", file=sys.stderr)
        return _USAGE_ERROR
    if n < 1:
        print(f"n must be at least 1, got {n}", file=sys.stderr)
        return _USAGE_ERROR
    prefixes = [p.strip() for p in prefix_text.split(",") if p.strip()]
    if not prefixes:
        print("the prefix list is empty", file=sys.stderr)
        return _USAGE_ERROR

    try:
        out = wrap_file(Path(path), prefixes, n, tag)
    except ValueError as exc:
        print(f"{exc}", file=sys.stderr)
        return 1
    print(f"wrapped {len(prefixes)} blocks -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
