import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/constant/input_method.dart';

void main() {
  test('fo03/us10/fr04: the input method is none, keyboard, or pointer, and '
      'each check is true for that method only', () {
    expect(InputMethod.values, [
      InputMethod.none,
      InputMethod.keyboard,
      InputMethod.pointer,
    ]);
    for (final method in InputMethod.values) {
      final reason = method.name;
      expect(method.isNone, method == InputMethod.none, reason: reason);
      expect(method.isKeyboard, method == InputMethod.keyboard, reason: reason);
      expect(method.isPointer, method == InputMethod.pointer, reason: reason);
      expect(method.isNotNone, method != InputMethod.none, reason: reason);
      expect(
        method.isNotKeyboard,
        method != InputMethod.keyboard,
        reason: reason,
      );
      expect(
        method.isNotPointer,
        method != InputMethod.pointer,
        reason: reason,
      );
    }
  });

  test('fo03/us10/fr04/e01: keyboard is keyboard and not pointer', () {
    expect(InputMethod.keyboard.isKeyboard, isTrue);
    expect(InputMethod.keyboard.isNotPointer, isTrue);
  });
}
