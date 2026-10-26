import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart'
    show KeyboardVisibilityScope, StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

import '../one_actionable_node.dart';

const _fixtureId = 'common/keyboard_visibility_scope';
const _stateId = 'keyboard_visibility_scope.state';
const _insetId = 'keyboard_visibility_scope.inset';

Future<void> _openFixture(WidgetTester tester) async {
  // The theme preload reads assets, which needs real time, not fake async.
  final controller = await tester.runAsync(
    () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
  );
  addTearDown(controller!.dispose);
  await tester.pumpWidget(
    FixtureApp(fixtureId: _fixtureId, themeController: controller),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('has the button, the field, and both texts', (tester) async {
    await _openFixture(tester);

    expect(find.text('Close keyboard'), findsOneWidget);
    expect(find.text('Type here'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_stateId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_insetId), findsOneWidget);
  });

  testWidgets('reads closed and inset 0 at mount, and the forced value wins', (
    tester,
  ) async {
    await _openFixture(tester);

    expect(find.text('keyboard: closed'), findsOneWidget);
    expect(find.text('inset: 0'), findsOneWidget);

    KeyboardVisibilityScope.setVisibleForTesting(true);
    addTearDown(() => KeyboardVisibilityScope.setVisibleForTesting(false));
    await tester.pumpAndSettle();

    expect(find.text('keyboard: open'), findsOneWidget);
  });

  testWidgets('the close button drops the field focus', (tester) async {
    await _openFixture(tester);

    await tester.enterText(find.byType(EditableText), 'a');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(find.text('Close keyboard'));
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });

  testWidgets('the inset text follows a changed bottom view inset', (
    tester,
  ) async {
    await _openFixture(tester);

    tester.view.viewInsets = FakeViewPadding(bottom: 792.5);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.text('inset: 793'), findsOneWidget);

    tester.view.viewInsets = FakeViewPadding(bottom: 0);
    await tester.pumpAndSettle();

    expect(find.text('inset: 0'), findsOneWidget);
  });

  testWidgets('the close button is one node with its label, role, and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    expectOneActionableNode(
      tester,
      find.text('Close keyboard'),
      label: 'Close keyboard',
    );
    handle.dispose();
  });

  testWidgets('the button and both texts sit above the field', (tester) async {
    await _openFixture(tester);

    final fieldTop = tester.getTopLeft(find.text('Type here')).dy;
    expect(
      tester.getTopLeft(find.text('Close keyboard')).dy,
      lessThan(fieldTop),
    );
    expect(
      tester.getTopLeft(find.text('keyboard: closed')).dy,
      lessThan(fieldTop),
    );
    expect(tester.getTopLeft(find.text('inset: 0')).dy, lessThan(fieldTop));
  });
}
