import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

void main() {
  test('fo05/us05/fr05: the package exports StratumTransitionPage and '
      'StratumThemeTransitions', () {
    const page = StratumTransitionPage<void>(
      type: ScreenTransitionType.none,
      child: SizedBox(),
    );

    expect(page.type, ScreenTransitionType.none);
    expect(
      StratumThemeTransitions.platform[WindowSize.mobile],
      ScreenTransitionType.platform,
    );
  });
}
