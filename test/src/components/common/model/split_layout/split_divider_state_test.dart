import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('fo06/us21/fr05: SplitDividerState has value equality and copyWith', () {
    // Built at run time from a parameter, so no const canonicalization
    // makes them one instance and the check reads `==`, not identity.
    SplitDividerState make(bool hovered) =>
        SplitDividerState(hovered: hovered, focused: true);
    final a = make(true);
    final b = make(true);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final c = a.copyWith(focused: false);
    expect(c.focused, isFalse);
    expect(c.hovered, isTrue);
  });
}
