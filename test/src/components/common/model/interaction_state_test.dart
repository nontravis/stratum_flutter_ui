import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('InteractionState', () {
    InteractionState state({required bool hovered}) =>
        InteractionState(hovered: hovered, focused: true);

    test('fo06/us17/fr04: a default state has every value false', () {
      const value = InteractionState();

      expect(value.hovered, isFalse);
      expect(value.pressed, isFalse);
      expect(value.focused, isFalse);
      expect(value.disabled, isFalse);
    });

    test('fo06/us17/fr01, PD11: states with the same values are equal and hash '
        'alike; one different value is not equal', () {
      expect(state(hovered: true), state(hovered: true));
      expect(state(hovered: true), isNot(same(state(hovered: true))));
      expect(state(hovered: true).hashCode, state(hovered: true).hashCode);
      expect(state(hovered: true), isNot(state(hovered: false)));
    });

    test('5.5: copyWith changes one value and keeps the rest', () {
      final copy = const InteractionState(focused: true)
          .copyWith(hovered: true);

      expect(copy.hovered, isTrue);
      expect(copy.focused, isTrue);
      expect(copy.pressed, isFalse);
      expect(copy.disabled, isFalse);
    });

    test("R4 Q2: takes freezed's toString", () {
      expect(
        const InteractionState().toString(),
        'InteractionState(hovered: false, pressed: false, focused: false, '
        'disabled: false)',
      );
    });
  });
}
