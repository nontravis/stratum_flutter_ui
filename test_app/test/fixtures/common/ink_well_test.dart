import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

import '../one_actionable_node.dart';

const _fixtureId = 'common/ink_well';
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
  testWidgets('the button is one node with its label, role, tap, and menu '
      'action', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    expectOneActionableNode(
      tester,
      find.bySemanticsLabel('Menu target'),
      label: 'Menu target',
      customActions: 1,
    );
    handle.dispose();
  });

  testWidgets('has the button and a nothing-yet log', (tester) async {
    await _openFixture(tester);

    expect(find.text('Menu target'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_logId), findsOneWidget);
    expect(find.text('Log: nothing yet.'), findsOneWidget);
  });

  testWidgets('a tap logs the tap', (tester) async {
    await _openFixture(tester);

    await tester.tap(find.text('Menu target'));
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

    final button = tester.getSemantics(find.bySemanticsLabel('Menu target'));
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
