import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';

import '../one_actionable_node.dart';

const _fixtureId = 'common/modal_layout';
const _pageTapsId = 'modal_layout.page_taps';
const _resultId = 'modal_layout.result';

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
  await tester.tap(find.text('Open modal'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('each page control is one node with its label, role, and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    for (final label in ['Page control', 'Open modal']) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel(label),
        label: label,
      );
    }
    handle.dispose();
  });

  testWidgets('each modal control is one node with its label, role, and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);
    await _openModal(tester);

    for (final label in ['Choose A', 'Choose B']) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel(label),
        label: label,
      );
    }
    handle.dispose();
  });

  testWidgets('closed: the page controls are present and no modal control is', (
    tester,
  ) async {
    await _openFixture(tester);

    expect(find.text('Open modal'), findsOneWidget);
    expect(find.text('Page control'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_pageTapsId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_resultId), findsOneWidget);
    expect(find.text('Choose A'), findsNothing);
    expect(find.text('page taps: 0'), findsOneWidget);
    expect(find.text('result: none'), findsOneWidget);
  });

  testWidgets('the page control behind is reachable while closed', (
    tester,
  ) async {
    await _openFixture(tester);

    await tester.tap(find.text('Page control'));
    await tester.pump();

    expect(find.text('page taps: 1'), findsOneWidget);
  });

  testWidgets('open: the modal shows its own two controls', (tester) async {
    await _openFixture(tester);

    await _openModal(tester);

    expect(find.text('Choose A'), findsOneWidget);
    expect(find.text('Choose B'), findsOneWidget);
  });

  testWidgets('a modal control closes it with its value', (tester) async {
    await _openFixture(tester);
    await _openModal(tester);

    await tester.tap(find.text('Choose A'));
    await tester.pumpAndSettle();

    expect(find.text('result: Choose A'), findsOneWidget);
    expect(find.text('Choose A'), findsNothing);
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
