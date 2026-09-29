import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/keyboard_visibility_scope.dart';

void main() {
  void setKeyboardHeight(WidgetTester tester, double height) {
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

  testWidgets('of returns true while the keyboard is open', (tester) async {
    setKeyboardHeight(tester, 300);
    addTearDown(tester.view.reset);
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(child: readVisibility((v) => isVisible = v)),
    );

    expect(isVisible, isTrue);
  });

  testWidgets('of returns false while the keyboard is closed', (tester) async {
    setKeyboardHeight(tester, 0);
    addTearDown(tester.view.reset);
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(child: readVisibility((v) => isVisible = v)),
    );

    expect(isVisible, isFalse);
  });

  testWidgets('of ignores insets removed below the scope', (tester) async {
    setKeyboardHeight(tester, 300);
    addTearDown(tester.view.reset);
    late bool isVisible;

    await tester.pumpWidget(
      KeyboardVisibilityScope(
        child: Builder(
          builder: (context) => MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: readVisibility((v) => isVisible = v),
          ),
        ),
      ),
    );

    expect(isVisible, isTrue);
  });

  testWidgets(
    'of throws a FlutterError without a KeyboardVisibilityScope ancestor',
    (tester) async {
      await tester.pumpWidget(readVisibility((_) {}));

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('No KeyboardVisibilityScope found'),
        ),
      );
    },
  );

  testWidgets('rebuilds dependents only when the keyboard opens or closes', (
    tester,
  ) async {
    setKeyboardHeight(tester, 0);
    addTearDown(tester.view.reset);
    var dependentBuilds = 0;

    await tester.pumpWidget(
      KeyboardVisibilityScope(child: readVisibility((_) => dependentBuilds++)),
    );
    dependentBuilds = 0;

    for (var height = 10.0; height <= 300; height += 10) {
      setKeyboardHeight(tester, height);
      await tester.pump();
    }
    for (var height = 290.0; height >= 0; height -= 10) {
      setKeyboardHeight(tester, height);
      await tester.pump();
    }

    // Opens once and closes once across 60 animation frames.
    expect(dependentBuilds, 2);
  });
}
