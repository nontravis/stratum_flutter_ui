import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('FocusGroup', () {
    // Built at run time from a parameter, so the checks read `==`.
    FocusGroup group({required bool loop}) =>
        FocusGroup(role: SemanticsRole.list, loop: loop);

    test('D4: compares role and loop by value', () {
      expect(group(loop: true), group(loop: true));
      expect(group(loop: true).hashCode, group(loop: true).hashCode);
      expect(group(loop: true), isNot(group(loop: false)));
    });

    test('D4: copyWith changes one field and keeps the other', () {
      final copy = group(loop: false).copyWith(loop: true);

      expect(copy.loop, isTrue);
      expect(copy.role, SemanticsRole.list);
    });

    test('fo06/us06/fr01: loop defaults to false and role to none', () {
      const value = FocusGroup();

      expect(value.loop, isFalse);
      expect(value.role, isNull);
    });

    test("R4 Q2: takes freezed's toString", () {
      expect(
        const FocusGroup().toString(),
        'FocusGroup(role: null, loop: false)',
      );
    });
  });
}
