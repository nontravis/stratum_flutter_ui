import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart'
    show StratumThemeApplication, StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/fixtures.dart';

void main() {
  testWidgets('finds the smoke button by semantics identifier', (tester) async {
    await tester.pumpWidget(const FixtureApp(fixtureId: 'smoke/semantics_id'));

    expect(find.bySemanticsIdentifier('smoke.button'), findsOneWidget);
    expect(find.bySemanticsIdentifier('smoke.taps'), findsOneWidget);
  });

  testWidgets('one tap makes smoke.taps read taps: 1', (tester) async {
    await tester.pumpWidget(const FixtureApp(fixtureId: 'smoke/semantics_id'));

    await tester.tap(find.bySemanticsIdentifier('smoke.button'));
    await tester.pump();

    expect(find.bySemanticsIdentifier('smoke.taps'), findsOneWidget);
    expect(find.text('taps: 1'), findsOneWidget);
  });

  testWidgets('an unknown id shows fixture.unknown', (tester) async {
    await tester.pumpWidget(const FixtureApp(fixtureId: 'nope'));

    expect(find.bySemanticsIdentifier('fixture.unknown'), findsOneWidget);
    expect(find.text('unknown fixture: nope'), findsOneWidget);
  });

  testWidgets('a null id shows fixture.unknown', (tester) async {
    await tester.pumpWidget(const FixtureApp(fixtureId: null));

    expect(find.bySemanticsIdentifier('fixture.unknown'), findsOneWidget);
    expect(find.text('unknown fixture: null'), findsOneWidget);
  });

  testWidgets('a non-/ defaultRouteName reports no navigation error', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue =
        '/fixture/smoke/semantics_id';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const FixtureApp(fixtureId: 'smoke/semantics_id'));

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsIdentifier('smoke.button'), findsOneWidget);
    // One route only: the platform route never splits into stacked routes.
    expect(find.byType(Scaffold, skipOffstage: false), findsOneWidget);
  });

  testWidgets('the fixtures map keys the smoke fixture', (tester) async {
    expect(fixtures.containsKey('smoke/semantics_id'), isTrue);
  });

  testWidgets('a themeController publishes the Stratum theme to a fixture', (
    tester,
  ) async {
    final controller = await tester.runAsync(
      () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
    );
    addTearDown(controller!.dispose);

    await tester.pumpWidget(
      FixtureApp(fixtureId: 'smoke/semantics_id', themeController: controller),
    );

    expect(find.byType(StratumThemeApplication), findsOneWidget);
    expect(find.bySemanticsIdentifier('smoke.button'), findsOneWidget);
  });

  group('system bars', () {
    void insetTopBar(WidgetTester tester) {
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 50);
      tester.view.viewPadding = const FakeViewPadding(top: 50);
      addTearDown(tester.view.reset);
    }

    testWidgets('a fixture keeps its content below the status bar', (
      tester,
    ) async {
      insetTopBar(tester);
      final controller = await tester.runAsync(
        () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
      );
      addTearDown(controller!.dispose);

      await tester.pumpWidget(
        FixtureApp(
          fixtureId: 'common/reorderable_list_view_layout',
          themeController: controller,
        ),
      );

      expect(
        tester.getTopLeft(find.text('Item 1')).dy,
        greaterThanOrEqualTo(50),
      );
    });

    testWidgets('an edge-to-edge fixture draws under the status bar', (
      tester,
    ) async {
      insetTopBar(tester);
      expect(edgeToEdgeFixtures, contains('themes/system_style'));

      await tester.pumpWidget(
        const FixtureApp(fixtureId: 'themes/system_style'),
      );

      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(SafeArea),
        ),
        findsNothing,
      );
    });

    test('every edge-to-edge id names a fixture', () {
      expect(fixtures.keys, containsAll(edgeToEdgeFixtures));
    });
  });
}
