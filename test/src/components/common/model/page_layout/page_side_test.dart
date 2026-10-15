import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('fo06/us19/fr02: PageSide has value equality and copyWith', () {
    // Built at run time from a parameter, so no const canonicalization
    // makes them one instance and the check reads `==`, not identity.
    PageSide make(double minWidth) =>
        PageSide(type: PageDrawerType.front, minWidth: minWidth);
    final a = make(200);
    final b = make(200);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final c = a.copyWith(minWidth: 240);
    expect(c.minWidth, 240);
    expect(c.type, PageDrawerType.front);
  });

  test('fo06/us19/fr02: PageSide copyWith honors the page scale assert', () {
    const side = PageSide(pageScale: 0.5);
    expect(() => side.copyWith(pageScale: 2), throwsA(isA<AssertionError>()));
  });
}
