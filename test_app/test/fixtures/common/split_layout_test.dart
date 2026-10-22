import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'common/split_layout';
const _listId = 'split.list_pane';
const _detailId = 'split.detail_pane';

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
  testWidgets('has the list and detail pane ids', (tester) async {
    await _openFixture(tester);

    expect(find.bySemanticsIdentifier(_listId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_detailId), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets('the divider reads as a slider at 30%', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    final divider = tester.getSemantics(find.bySemanticsLabel('Resize panes'));

    expect(divider.flagsCollection.isSlider, isTrue);
    expect(divider.value, '30%');
    handle.dispose();
  });

  testWidgets('increase moves the divider and it reads the new value', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    final divider = tester.getSemantics(find.bySemanticsLabel('Resize panes'));
    divider.owner!.performAction(divider.id, SemanticsAction.increase);
    await tester.pumpAndSettle();

    final moved = tester.getSemantics(find.bySemanticsLabel('Resize panes'));
    // One 16 px step of the 800 px test window moves 240 px to 256 px.
    expect(moved.value, '32%');
    handle.dispose();
  });
}
