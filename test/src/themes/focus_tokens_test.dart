import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  // Built at run time from a parameter, so the checks read `==`.
  StratumFocusTokens make({required double gap}) => StratumFocusTokens(
    outsideColor: const Color(0xFF93C5FD),
    outsideWidth: 3,
    outsideGap: gap,
    insideColor: const Color(0x1A000000),
    insideHoveredWidth: 3,
    insideFocusedWidth: 2,
  );

  test('fo01/us01/fr01: StratumFocusTokens value == and hashCode over the '
      'six fields, and copyWith', () {
    expect(make(gap: 2), make(gap: 2));
    expect(make(gap: 2).hashCode, make(gap: 2).hashCode);
    expect(make(gap: 2), isNot(make(gap: 1)));
    expect(make(gap: 2).copyWith(outsideWidth: 4).outsideWidth, 4);
    expect(make(gap: 2).toString(), startsWith('StratumFocusTokens('));
  });
}
