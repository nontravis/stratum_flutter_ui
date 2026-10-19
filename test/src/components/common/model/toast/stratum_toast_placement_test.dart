import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('co05_07/us01/fr02: StratumToastPlacement.float has value equality and '
      'copyWith', () {
    // Built at run time from a parameter, so no const canonicalization
    // makes them one instance and the check reads `==`, not identity.
    StratumToastPlacement make(StratumToastCorner corner) =>
        StratumToastPlacement.float(corner);
    final a = make(StratumToastCorner.bottomStart);
    final b = make(StratumToastCorner.bottomStart);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final c = (a as StratumToastFloat).copyWith(
      corner: StratumToastCorner.topEnd,
    );
    expect(c.corner, StratumToastCorner.topEnd);
  });

  test('co05_07/us01/fr02: StratumToastPlacement.solid has value equality and '
      'copyWith', () {
    // Built at run time from a parameter, so no const canonicalization
    // makes them one instance and the check reads `==`, not identity.
    StratumToastPlacement make(StratumToastEdge edge) =>
        StratumToastPlacement.solid(edge);
    final a = make(StratumToastEdge.bottom);
    final b = make(StratumToastEdge.bottom);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final c = (a as StratumToastSolid).copyWith(edge: StratumToastEdge.top);
    expect(c.edge, StratumToastEdge.top);
  });
}
