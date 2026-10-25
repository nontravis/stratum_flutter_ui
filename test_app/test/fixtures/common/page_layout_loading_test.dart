import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/common/page_layout_loading.dart';

const _fixtureId = 'common/page_layout_loading';
const _loading = 'Loading';

/// The loading layer's fade, in or out (PageLayout FR-06).
const _fade = Duration(milliseconds: 125);

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
  testWidgets('the page shows its body and no Loading node at mount', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    expect(find.text('Page body'), findsOneWidget);
    expect(find.bySemanticsLabel(_loading), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  testWidgets('one live-region node labeled Loading appears after the idle '
      'stretch and the fade, and goes after the busy stretch and the fade', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.pump(pageLayoutLoadingFixtureIdle);
    await tester.pump(_fade);
    expect(find.bySemanticsLabel(_loading), findsOneWidget);
    final flags = tester
        .getSemantics(find.bySemanticsLabel(_loading))
        .getSemanticsData()
        .flagsCollection;
    expect(flags.isLiveRegion, isTrue);

    await tester.pump(pageLayoutLoadingFixtureBusy);
    await tester.pump(_fade);
    await tester.pump();
    expect(find.bySemanticsLabel(_loading), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  testWidgets('the cycle repeats: Loading turns on a second time', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.pump(pageLayoutLoadingFixtureIdle);
    await tester.pump(pageLayoutLoadingFixtureBusy);
    await tester.pump(_fade);
    await tester.pump();
    expect(find.bySemanticsLabel(_loading), findsNothing);

    await tester.pump(pageLayoutLoadingFixtureIdle);
    await tester.pump(_fade);
    expect(find.bySemanticsLabel(_loading), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  // flutter_test fails any test that ends with a Timer still pending, so
  // leaving the tree mid-cycle, in either stretch, proves dispose cancels it.
  testWidgets('no timer stays pending once the fixture leaves the tree', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.pump(pageLayoutLoadingFixtureIdle);
    await tester.pump(_fade);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(find.bySemanticsLabel(_loading), findsNothing);
    handle.dispose();
  });
}
