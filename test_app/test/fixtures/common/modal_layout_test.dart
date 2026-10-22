import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'common/modal_layout';
const _openId = 'modal_layout.open';
const _pageButtonId = 'modal_layout.page_button';
const _pageTapsId = 'modal_layout.page_taps';
const _resultId = 'modal_layout.result';
const _chooseAId = 'modal_layout.choose_a';
const _chooseBId = 'modal_layout.choose_b';

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

Future<void> _openModal(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier(_openId));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('closed: the page ids are present and no modal control is', (
    tester,
  ) async {
    await _openFixture(tester);

    expect(find.bySemanticsIdentifier(_openId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_pageButtonId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_pageTapsId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_resultId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_chooseAId), findsNothing);
    expect(find.text('page taps: 0'), findsOneWidget);
    expect(find.text('result: none'), findsOneWidget);
  });

  testWidgets('the page control behind is reachable while closed', (
    tester,
  ) async {
    await _openFixture(tester);

    await tester.tap(find.bySemanticsIdentifier(_pageButtonId));
    await tester.pump();

    expect(find.text('page taps: 1'), findsOneWidget);
  });

  testWidgets('open: the modal shows its own two controls', (tester) async {
    await _openFixture(tester);

    await _openModal(tester);

    expect(find.bySemanticsIdentifier(_chooseAId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_chooseBId), findsOneWidget);
  });

  testWidgets('a modal control closes it with its value', (tester) async {
    await _openFixture(tester);
    await _openModal(tester);

    await tester.tap(find.bySemanticsIdentifier(_chooseAId));
    await tester.pumpAndSettle();

    expect(find.text('result: Choose A'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_chooseAId), findsNothing);
  });

  testWidgets('Esc dismisses it and the result reads dismissed', (
    tester,
  ) async {
    await _openFixture(tester);
    await _openModal(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('result: dismissed'), findsOneWidget);
  });
}
