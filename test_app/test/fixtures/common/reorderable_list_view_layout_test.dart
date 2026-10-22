import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'common/reorderable_list_view_layout';

String _itemId(int n) => 'reorder.item.$n';

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
  testWidgets('has the six item ids and a nothing-yet log', (tester) async {
    await _openFixture(tester);

    for (var n = 1; n <= 6; n++) {
      expect(find.bySemanticsIdentifier(_itemId(n)), findsOneWidget);
      expect(find.text('Item $n'), findsOneWidget);
    }
    expect(find.bySemanticsIdentifier('reorder.log'), findsOneWidget);
    expect(find.text('Log: nothing yet.'), findsOneWidget);
  });

  testWidgets('tapping Item 4 logs Item 4 tapped', (tester) async {
    await _openFixture(tester);

    await tester.tap(find.bySemanticsIdentifier(_itemId(4)));
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
    // The id follows the original number, not the position.
    expect(find.bySemanticsIdentifier(_itemId(3)), findsOneWidget);
  });
}
