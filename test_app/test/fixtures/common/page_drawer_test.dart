import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/common/page_drawer.dart';

import '../one_actionable_node.dart';

const _fixtureId = 'common/page_drawer';
const _linkAId = 'page_drawer.link_a';
const _drawer = 'Navigation menu';
const _scrim = 'Dismiss';
const _openNow = 'Open drawer';
const _openLater = 'Open drawer in 5 s';

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
  testWidgets('the body shows its text and both open buttons, and no drawer '
      'yet', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    expect(find.text('Page body'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_linkAId), findsNothing);
    expect(find.bySemanticsLabel(_drawer), findsNothing);
    handle.dispose();
  });

  testWidgets('each open button is one node with its label, role, and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    for (final label in [_openNow, _openLater]) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel(label),
        label: label,
      );
    }
    handle.dispose();
  });

  testWidgets('a tap on Open drawer opens a drawer that scopes and names a '
      'route', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.tap(find.bySemanticsLabel(_openNow));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier(_linkAId), findsOneWidget);
    final flags = tester
        .getSemantics(find.bySemanticsLabel(_drawer))
        .getSemanticsData()
        .flagsCollection;
    expect(flags.scopesRoute, isTrue);
    expect(flags.namesRoute, isTrue);
    expect(find.text('Drawer link A'), findsOneWidget);
    expect(find.text('Drawer link B'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the scrim reads Dismiss and has a tap action', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.tap(find.bySemanticsLabel(_openNow));
    await tester.pumpAndSettle();

    final scrim = tester.getSemantics(find.bySemanticsLabel(_scrim));
    expect(scrim.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('Open drawer in 5 s opens the drawer only after the delay', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.tap(find.bySemanticsLabel(_openLater));
    await tester.pump(pageDrawerFixtureOpenDelay - const Duration(seconds: 1));
    await tester.pump();
    expect(find.bySemanticsIdentifier(_linkAId), findsNothing);

    await tester.pump(pageDrawerFixtureOpenDelay);
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier(_linkAId), findsOneWidget);
    handle.dispose();
  });
}
