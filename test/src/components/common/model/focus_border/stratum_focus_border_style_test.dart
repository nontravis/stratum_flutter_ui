import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  const red = Color(0xFFFF0000);

  test('R6(1): the placement enum is outside, then inside', () {
    expect(StratumFocusBorderPlacement.values, [
      StratumFocusBorderPlacement.outside,
      StratumFocusBorderPlacement.inside,
    ]);
  });

  test('fo06/us04/fr03: R3, layout s03, every field is optional, and every '
      'field but placement resolves per shown state', () {
    const style = StratumFocusBorderStyle(
      color: WidgetStatePropertyAll(red),
      width: WidgetStateProperty.fromMap({
        WidgetState.hovered: 3,
        WidgetState.focused: 2,
      }),
      gap: WidgetStatePropertyAll(2),
      radius: WidgetStatePropertyAll(BorderRadius.zero),
      placement: StratumFocusBorderPlacement.inside,
      motion: WidgetStatePropertyAll(AnimationStyle.noAnimation),
      secondRing: WidgetStatePropertyAll((color: red, width: null)),
      glow: WidgetStatePropertyAll([BoxShadow(blurRadius: 4)]),
    );

    expect(const StratumFocusBorderStyle().color, isNull);
    expect(style.width!.resolve({WidgetState.hovered}), 3);
    expect(style.width!.resolve({WidgetState.focused}), 2);
    expect(style.secondRing!.resolve({WidgetState.focused})!.width, isNull);
  });

  test('fo06/us04/fr03: freezed-models convention, value ==, copyWith, and '
      'toString', () {
    // Built at run time from a parameter, so the checks read `==`.
    StratumFocusBorderStyle make(Color color) =>
        StratumFocusBorderStyle(color: WidgetStatePropertyAll(color));

    expect(make(red), make(red));
    expect(make(red).hashCode, make(red).hashCode);
    expect(make(red), isNot(make(const Color(0xFF00FF00))));
    expect(
      make(red)
          .copyWith(placement: StratumFocusBorderPlacement.inside)
          .placement,
      StratumFocusBorderPlacement.inside,
    );
    expect(make(red).toString(), startsWith('StratumFocusBorderStyle('));
  });
}
