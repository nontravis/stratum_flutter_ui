import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/feedback/update_gate.dart';

import '../one_actionable_node.dart';

const _fixtureId = 'feedback/update_gate';
const _dialogTitleId = 'update_gate.dialog_title';
const _screenTitleId = 'update_gate.screen_title';

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

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
  testWidgets('before any tap the page shows and no gate state does', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    expect(find.text('Gate page'), findsOneWidget);
    expect(_id(_screenTitleId), findsNothing);
    expect(_id(_dialogTitleId), findsNothing);
    expect(find.text('Under maintenance'), findsNothing);
    handle.dispose();
  });

  testWidgets('each page control is one node with its label, role, and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    for (final label in ['Offer update', 'Require update in 10 s']) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel(label),
        label: label,
      );
    }
    handle.dispose();
  });

  testWidgets('Offer update shows the dialog and Later removes it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.tap(find.text('Offer update'));
    await tester.pumpAndSettle();
    expect(_id(_dialogTitleId), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);
    // The gate's child stays mounted under the dialog (US-02 FR-01).
    expect(find.text('Gate page'), findsOneWidget);
    expectOneActionableNode(
      tester,
      find.bySemanticsLabel('Later'),
      label: 'Later',
    );

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(_id(_dialogTitleId), findsNothing);
    expect(find.text('Gate page'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'Require update in 10 s replaces the page with the full screen after '
    'the delay',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _openFixture(tester);

      await tester.tap(find.text('Require update in 10 s'));
      // One frame first: the fresh gate mounts and arms its delayed answer;
      // pumping the delay before it mounts advances the clock past a timer
      // that does not exist yet.
      await tester.pump();
      await tester.pump(updateGateFixtureRequireDelay);
      await tester.pumpAndSettle();
      expect(_id(_screenTitleId), findsOneWidget);
      expect(find.text('Install the new version to go on.'), findsOneWidget);
      // The gate replaced its child: the page is not in the tree (US-01
      // FR-02).
      expect(find.text('Gate page'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('a pending 10 s answer leaves no timer after dispose', (
    tester,
  ) async {
    await _openFixture(tester);

    await tester.tap(find.text('Require update in 10 s'));
    // The fresh gate mounts and arms the delayed answer.
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    // No pump of the delay follows: a timer still pending here fails the
    // test.
  });

  testWidgets('a pending 10 s answer leaves no timer after a later tap', (
    tester,
  ) async {
    await _openFixture(tester);

    await tester.tap(find.text('Require update in 10 s'));
    // The fresh gate mounts and arms the delayed answer.
    await tester.pump();
    await tester.tap(find.text('Offer update'));
    await tester.pumpAndSettle();
    expect(_id(_dialogTitleId), findsOneWidget);
    // No pump of the remaining delay follows: a timer still pending here
    // fails the test.
  });
}
