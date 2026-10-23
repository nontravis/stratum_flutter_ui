"""Unit tests for the repeat wrap, ported from `wrap_repeat.bats`; they read and write Dart text only."""

from __future__ import annotations

from pathlib import Path

import pytest

from stratum_e2e.round import wrap_repeat
from stratum_e2e.round.wrap_repeat import find_opener, main, sibling_path, wrap_file

SAMPLE = """\
// Trimmed fixture: three independent testWidgets blocks, each a self-contained case, so wrapping one never
// touches the others.
void main() {
  group('demo', () {
    testWidgets('us08/s1: the first case stands on its own',
        (WidgetTester tester) async {
      await tester.pumpWidget(Container());
      expect(true, isTrue);
    });

    testWidgets('us08/s3, us08/fr01: a page on the allowlist and the app '
        'trade messages both ways', (WidgetTester tester) async {
      final recorder = Recorder();
      expect(recorder.errors, isEmpty);
    });

    testWidgets('us08/s9: the third case stands on its own',
        (WidgetTester tester) async {
      expect(1, equals(1));
    });
  });
}
"""

WRAPPED_NAME = """\
void main() {
  group('demo', () {
    testWidgets(
      'f01/us08/s3: a page on the allowlist and the app trade messages '
      'both ways',
      (WidgetTester tester) async {
        final recorder = Recorder();
        expect(recorder.errors, isEmpty);
      },
    );
  });
}
"""


@pytest.fixture
def source(tmp_path: Path) -> Path:
    path = tmp_path / "sample_test.dart"
    path.write_text(SAMPLE, encoding="utf-8")
    return path


def test_wrap_file_writes_the_sibling_and_leaves_the_source_untouched(source: Path) -> None:
    out = wrap_file(source, ["us08/s3"], 3)

    assert out == source.with_name(".dt_sample_test_x3.dart")
    assert source.read_text(encoding="utf-8") == SAMPLE
    text = out.read_text(encoding="utf-8")
    assert "for (var run = 0; run < 3; run++) { // REPEAT" in text
    assert "} // REPEAT" in text
    assert "testWidgets('REPEAT run $run us08/s3," in text


def test_the_wrapped_block_prints_a_repeat_marker_as_its_last_statement(source: Path) -> None:
    lines = wrap_file(source, ["us08/s3"], 3).read_text(encoding="utf-8").splitlines()

    marker = next(i for i, line in enumerate(lines) if "print('REPEAT us08/s3 " in line)
    assert lines[marker] == "      print('REPEAT us08/s3 ${run + 1}/3 ok');"
    assert lines[marker - 1].strip() == "// ignore: avoid_print"
    assert lines[marker + 1] == "    });"


def test_a_tag_joins_the_siblings_name(source: Path) -> None:
    out = wrap_file(source, ["us08/s3"], 3, tag="phone")

    assert out == source.with_name(".dt_sample_test_phone_x3.dart")
    assert out.is_file()


def test_the_other_blocks_stay_untouched(source: Path) -> None:
    text = wrap_file(source, ["us08/s3"], 3).read_text(encoding="utf-8")

    assert "testWidgets('us08/s1: the first case stands on its own'" in text
    assert "testWidgets('us08/s9: the third case stands on its own'" in text
    assert text.count("// REPEAT") == 2


def test_a_prefix_list_wraps_each_named_block(source: Path) -> None:
    text = wrap_file(source, ["us08/s1", "us08/s9"], 3).read_text(encoding="utf-8")

    assert text.count("// REPEAT") == 4
    assert "testWidgets('REPEAT run $run us08/s1" in text
    assert "testWidgets('REPEAT run $run us08/s9" in text
    assert "testWidgets('us08/s3, us08/fr01" in text


def test_wrapping_twice_overwrites_the_sibling_with_the_same_content(source: Path) -> None:
    once = wrap_file(source, ["us08/s3"], 3).read_text(encoding="utf-8")

    assert wrap_file(source, ["us08/s3"], 3).read_text(encoding="utf-8") == once


def test_a_name_wrapped_onto_the_line_after_the_opener_is_found_and_wrapped(tmp_path: Path) -> None:
    source = tmp_path / "wrapped_name_test.dart"
    source.write_text(WRAPPED_NAME, encoding="utf-8")

    out = wrap_file(source, ["f01/us08/s3"], 3)

    assert out == tmp_path / ".dt_wrapped_name_test_x3.dart"
    text = out.read_text(encoding="utf-8")
    assert "testWidgets('REPEAT run $run f01/us08/s3:" in text
    assert "for (var run = 0; run < 3; run++) { // REPEAT" in text


def test_an_unknown_prefix_raises_and_writes_nothing(source: Path) -> None:
    with pytest.raises(ValueError, match="no test block starts with"):
        wrap_file(source, ["no-such-test-prefix"], 3)

    assert not sibling_path(source, 3).exists()


def test_one_unknown_prefix_in_a_list_writes_nothing(source: Path) -> None:
    with pytest.raises(ValueError, match="no test block starts with"):
        wrap_file(source, ["us08/s1", "nope"], 3)

    assert not sibling_path(source, 3).exists()


def test_a_non_positive_n_raises(source: Path) -> None:
    with pytest.raises(ValueError, match="at least 1"):
        wrap_file(source, ["us08/s3"], 0)


def test_an_empty_prefix_list_raises(source: Path) -> None:
    with pytest.raises(ValueError, match="empty"):
        wrap_file(source, [], 3)


def test_the_command_line_reports_what_it_wrote(source: Path, capsys: pytest.CaptureFixture[str]) -> None:
    before = source.read_text(encoding="utf-8")

    assert main(["wrap_repeat.py", str(source), "us08/s3,", "3"]) == 0

    out = sibling_path(source, 3)
    assert capsys.readouterr().out == f"wrapped 1 blocks -> {out}\n"
    assert out.is_file()
    assert source.read_text(encoding="utf-8") == before


def test_the_command_line_wraps_a_comma_separated_prefix_list(source: Path,
                                                              capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["wrap_repeat.py", str(source), "us08/s1, us08/s9", "3"]) == 0

    assert capsys.readouterr().out.startswith("wrapped 2 blocks -> ")
    assert sibling_path(source, 3).read_text(encoding="utf-8").count("// REPEAT") == 4


def test_the_command_line_takes_a_tag(source: Path) -> None:
    assert main(["wrap_repeat.py", str(source), "us08/s3,", "3", "phone"]) == 0

    assert sibling_path(source, 3, "phone").is_file()


def test_the_command_line_exits_1_for_an_unknown_prefix_and_writes_nothing(
    source: Path, capsys: pytest.CaptureFixture[str],
) -> None:
    assert main(["wrap_repeat.py", str(source), "no-such-test-prefix", "3"]) == 1

    assert "no test block starts with" in capsys.readouterr().err
    assert not sibling_path(source, 3).exists()


def test_the_command_line_exits_1_when_one_prefix_in_a_list_is_unknown(source: Path) -> None:
    assert main(["wrap_repeat.py", str(source), "us08/s1, nope", "3"]) == 1

    assert not sibling_path(source, 3).exists()


def test_the_command_line_exits_2_on_the_wrong_argument_count(source: Path) -> None:
    assert main(["wrap_repeat.py", str(source)]) == 2


@pytest.mark.parametrize("n", ["not-a-number", "0"])
def test_the_command_line_exits_2_for_a_non_integer_or_non_positive_n(source: Path, n: str) -> None:
    assert main(["wrap_repeat.py", str(source), "us08/s3,", n]) == 2


def test_check_exits_0_for_a_matching_prefix_and_writes_and_prints_nothing(
    source: Path, capsys: pytest.CaptureFixture[str],
) -> None:
    before = source.read_text(encoding="utf-8")

    assert main(["wrap_repeat.py", "--check", str(source), "us08/s3"]) == 0

    assert capsys.readouterr().out == ""
    assert not sibling_path(source, 3).exists()
    assert source.read_text(encoding="utf-8") == before


def test_check_finds_a_name_wrapped_onto_the_line_after_the_opener(tmp_path: Path) -> None:
    source = tmp_path / "wrapped_name_test.dart"
    source.write_text(WRAPPED_NAME, encoding="utf-8")

    assert main(["wrap_repeat.py", "--check", str(source), "f01/us08/s3"]) == 0


def test_check_exits_1_for_an_unmatched_prefix_and_prints_nothing(
    source: Path, capsys: pytest.CaptureFixture[str],
) -> None:
    assert main(["wrap_repeat.py", "--check", str(source), "no-such-test-prefix"]) == 1

    assert capsys.readouterr().out == ""


def test_check_exits_2_on_the_wrong_argument_count(source: Path) -> None:
    assert main(["wrap_repeat.py", "--check", str(source)]) == 2


def test_check_still_finds_the_name_of_a_malformed_block(tmp_path: Path) -> None:
    source = tmp_path / "broken_test.dart"
    source.write_text("void main() { testWidgets('us08/s3: never closed', (t) async {\n", encoding="utf-8")

    assert main(["wrap_repeat.py", "--check", str(source), "us08/s3"]) == 0
    assert find_opener(source.read_text(encoding="utf-8"), "us08/s3") is not None
    assert main(["wrap_repeat.py", str(source), "us08/s3", "3"]) == 1


def test_the_module_docstring_names_the_e2e_owner() -> None:
    assert "`e2e/`" in (wrap_repeat.__doc__ or "").splitlines()[0]
