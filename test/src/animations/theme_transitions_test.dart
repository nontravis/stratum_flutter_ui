import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/animations/theme_transitions.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  const transitions = StratumThemeTransitions(
    watch: ScreenTransitionType.fade,
    mobile: ScreenTransitionType.rightToLeft,
    tablet: ScreenTransitionType.scale,
    desktop: ScreenTransitionType.cupertino,
    bigDesktop: ScreenTransitionType.none,
  );

  test('us05/fr04: [] gives the type of each window size', () {
    expect(
      [for (final size in WindowSize.values) transitions[size]],
      [
        ScreenTransitionType.fade,
        ScreenTransitionType.rightToLeft,
        ScreenTransitionType.scale,
        ScreenTransitionType.cupertino,
        ScreenTransitionType.none,
      ],
    );
  });

  test('platform names platform for every window size', () {
    expect([
      for (final size in WindowSize.values)
        StratumThemeTransitions.platform[size],
    ], List.filled(5, ScreenTransitionType.platform));
  });

  test('two values with the same types are equal', () {
    const same = StratumThemeTransitions(
      watch: ScreenTransitionType.fade,
      mobile: ScreenTransitionType.rightToLeft,
      tablet: ScreenTransitionType.scale,
      desktop: ScreenTransitionType.cupertino,
      bigDesktop: ScreenTransitionType.none,
    );

    expect(transitions, same);
    expect(transitions.hashCode, same.hashCode);
    expect(transitions, isNot(StratumThemeTransitions.platform));
  });
}
