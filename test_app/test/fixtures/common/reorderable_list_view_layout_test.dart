import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

import '../one_actionable_node.dart';

const _fixtureId = 'common/reorderable_list_view_layout';

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
  testWidgets('each enabled row is one node with its label, role, tap, and '
      'move actions', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    for (var n = 1; n <= 5; n++) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel('Item $n'),
        label: 'Item $n',
        // The first row cannot move up, so it holds one pair less.
        customActions: n == 1 ? 2 : 4,
      );
    }
    handle.dispose();
  });

  testWidgets('has the six items and a nothing-yet log', (tester) async {
    await _openFixture(tester);

    for (var n = 1; n <= 6; n++) {
      expect(find.text('Item $n'), findsOneWidget);
    }
    expect(find.bySemanticsIdentifier('reorder.log'), findsOneWidget);
    expect(find.text('Log: nothing yet.'), findsOneWidget);
  });

  testWidgets('tapping Item 4 logs Item 4 tapped', (tester) async {
    await _openFixture(tester);

    await tester.tap(find.text('Item 4'));
    await tester.pump();

    expect(find.text('Log: Item 4 tapped'), findsOneWidget);
  });

  testWidgets('Alt+Arrow Up on a focused Item 3 logs the move to position 2', (
    tester,
  ) async {
    await _openFixture(tester);

    Focus.of(tester.element(find.text('Item 3'))).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(find.text('Log: Item 3 moved to position 2'), findsOneWidget);
    // The row keeps its original number, not its position.
    expect(find.text('Item 3'), findsOneWidget);
  });
}
