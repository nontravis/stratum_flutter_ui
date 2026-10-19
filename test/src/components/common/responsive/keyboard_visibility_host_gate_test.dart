import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/keyboard_visibility_scope.dart';

void main() {
  void setInsets(WidgetTester tester, double height) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewInsets = FakeViewPadding(bottom: height);
  }

  Widget readVisibility(void Function(bool isVisible) onBuild) => Builder(
    builder: (context) {
      onBuild(KeyboardVisibilityScope.of(context));
      return const SizedBox();
    },
  );

  testWidgets('fo07/us04/fr02/e05: on the test host the scope reads false '
      'whatever the inset and opens no platform channel', (tester) async {
    setInsets(tester, 300);
    addTearDown(tester.view.reset);
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(child: readVisibility((v) => isVisible = v)),
    );

    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(tester.takeException(), isNull);
    expect(isVisible, isFalse);
  });

  testWidgets(
    'fo07/us04/fr02/e05: every target platform on the test host opens no '
    'platform channel',
    (tester) async {
      late bool isVisible;

      await tester.pumpWidget(
        KeyboardVisibilityScope(child: readVisibility((v) => isVisible = v)),
      );

      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(tester.takeException(), isNull);
      expect(isVisible, isFalse);
    },
    variant: TargetPlatformVariant.all(),
  );
}
