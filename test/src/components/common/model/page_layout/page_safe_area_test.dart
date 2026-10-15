import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('fo06/us18/fr04: PageSafeArea has value equality and copyWith', () {
    // Built at run time from a parameter, so no const canonicalization
    // makes them one instance and the check reads `==`, not identity.
    PageSafeArea make(bool top) => PageSafeArea(top: top, left: false);
    final a = make(false);
    final b = make(false);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final c = a.copyWith(left: true);
    expect(c.left, isTrue);
    expect(c.top, isFalse);
  });
}
