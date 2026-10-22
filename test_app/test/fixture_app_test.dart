import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
