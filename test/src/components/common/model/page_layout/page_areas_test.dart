import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/page_layout/page_areas.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('PageAreas', () {
    test('fo06/us18/fr01: has value equality and copyWith', () {
      // Built at run time from a parameter, so no const canonicalization
      // makes them one instance and the check reads `==`, not identity.
      PageAreas make(double footerTop) => PageAreas(
        body: const Rect.fromLTWH(0, 0, 10, 10),
        footerTop: footerTop,
      );
      final a = make(5);
      final b = make(5);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(footerTop: 9);
      expect(c.footerTop, 9);
      expect(c.body, a.body);
    });
  });
}
