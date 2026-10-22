import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'common/ink_well';
const _buttonId = 'ink_well.button';
const _logId = 'ink_well.log';

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
  testWidgets('has the button and a nothing-yet log', (tester) async {
    await _openFixture(tester);

    expect(find.bySemanticsIdentifier(_buttonId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_logId), findsOneWidget);
    expect(find.text('Log: nothing yet.'), findsOneWidget);
  });

  testWidgets('the id node is tappable under the button node with the menu '
      'action', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    final node = tester.getSemantics(find.bySemanticsIdentifier(_buttonId));
    final button = node.parent!.getSemanticsData();

    expect(node.identifier, _buttonId);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(button.flagsCollection.isButton, isTrue);
    expect(button.customSemanticsActionIds, hasLength(1));
    handle.dispose();
  });

  testWidgets('a tap logs the tap', (tester) async {
    await _openFixture(tester);

    await tester.tap(find.bySemanticsIdentifier(_buttonId));
    await tester.pump();

    expect(find.text('Log: tapped'), findsOneWidget);
  });

  testWidgets('the context-menu key on the focused button logs the menu', (
    tester,
  ) async {
    await _openFixture(tester);

    Focus.of(tester.element(find.text('Menu target'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();

    expect(find.text('Log: menu'), findsOneWidget);
  });

  testWidgets('the custom semantics action logs the menu', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    final button = tester
        .getSemantics(find.bySemanticsIdentifier(_buttonId))
        .parent!;
    final actionId = button.getSemanticsData().customSemanticsActionIds!.single;
    button.owner!.performAction(
      button.id,
      SemanticsAction.customAction,
      actionId,
    );
    await tester.pump();

    expect(find.text('Log: menu'), findsOneWidget);
    handle.dispose();
  });
}
