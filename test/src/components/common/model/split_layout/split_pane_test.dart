import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('fo06/us21/fr01: SplitPane has value equality and copyWith', () {
    // Built at run time from a parameter, so no const canonicalization
    // makes them one instance and the check reads `==`, not identity.
    SplitPane make(double min) =>
        SplitPane(child: const SizedBox(), size: 100, min: min);
    final a = make(50);
    final b = make(50);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final c = a.copyWith(min: 60);
    expect(c.min, 60);
    expect(c.size, 100);
  });

  test('fo06/us21/fr01: SplitPane copyWith honors the min-max assert', () {
    const pane = SplitPane(child: SizedBox(), min: 50);
    expect(() => pane.copyWith(max: 10), throwsA(isA<AssertionError>()));
  });
}
