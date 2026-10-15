import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

void main() {
  test('co01_03/us01/fr01: StratumCaret and its two enums are public through '
      'package:stratum_ui', () {
    const caret = StratumCaret(
      style: StratumCaretStyle.fill,
      direction: StratumCaretDirection.end,
    );

    expect(caret.style, StratumCaretStyle.fill);
    expect(caret.direction, StratumCaretDirection.end);
  });
}
