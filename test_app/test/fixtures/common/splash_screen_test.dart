import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// stratum_ui owns shared_preferences as its settings store seam; the splash
// makes its own settings controller over the default store, which needs a
// platform instance, as the package's own flutter_test_config provides.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/common/splash_screen.dart';

const _fixtureId = 'common/splash_screen';
const _loading = 'Loading';
const _doneId = 'splash_screen.done';

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

/// Pumps the fixture until the splash's own theme preload ends and its first
/// frame appears: the spinner of a loading state, or `Started` at done.
///
/// The splash reads the package's theme assets through the real asset
/// bundle, so each read finishes on the real event loop; one `runAsync`
/// round-trip lets it finish and the pump after it drains the splash's
/// continuation, until the first state shows.
Future<StratumThemeController> _preloadTheme(WidgetTester tester) async {
  // The theme preload reads assets, which needs real time, not fake async.
  final controller = await tester.runAsync(
    () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
  );
  addTearDown(controller!.dispose);
  return controller;
}

Future<void> _openFixture(WidgetTester tester) async {
  final controller = await _preloadTheme(tester);
  // The test binding latches its first-frame flag on the first frame drawn
  // while no splash holds it; clear it so a frame assertion sees this mount.
  tester.binding.resetFirstFrameSent();
  await tester.pumpWidget(
    FixtureApp(fixtureId: _fixtureId, themeController: controller),
  );
  await _waitForFirstState(tester);
}

/// Real-time bound for the first state: the asset reads outlast any round
/// count on a loaded machine, such as one with a device lane building.
const _firstStateDeadline = Duration(seconds: 5);

Future<void> _waitForFirstState(WidgetTester tester) async {
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsed < _firstStateDeadline) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.text('Started').evaluate().isNotEmpty) {
      return;
    }
  }
  fail(
    'No splash state showed within $_firstStateDeadline: neither a spinner '
    'nor Started is on screen.',
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'a live-region node labeled Loading sits over the loading frame on open',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _openFixture(tester);

      expect(find.bySemanticsLabel(_loading), findsOneWidget);
      final flags = tester
          .getSemantics(find.bySemanticsLabel(_loading))
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isLiveRegion, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      // Fire the postload hold the unmounted splash still awaits, so no
      // timer stays pending.
      await tester.pump(splashScreenFixtureHold);
      handle.dispose();
    },
  );

  testWidgets('the done frame shows splash_screen.done after the hold', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.pump(splashScreenFixtureHold);
    // The done frame lands through the exit transition's settle.
    await tester.pumpAndSettle();
    expect(find.text('Started'), findsOneWidget);
    expect(_id(_doneId), findsOneWidget);
    expect(find.bySemanticsLabel(_loading), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  testWidgets('one cycle bumps the generation and Loading returns', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openFixture(tester);

    await tester.pump(splashScreenFixtureHold);
    // Clear the latch so the assertion below sees the remount, not the first
    // splash's frame.
    tester.binding.resetFirstFrameSent();
    await tester.pump(splashScreenFixtureCycle - splashScreenFixtureHold);
    // The cycle bumped the generation: a fresh splash mounted and its own
    // preload ran, so wait for its first frame the same way.
    await _waitForFirstState(tester);
    expect(find.bySemanticsLabel(_loading), findsOneWidget);
    // The remounted splash still draws: its loading frame reached the engine.
    expect(tester.binding.sendFramesToEngine, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(splashScreenFixtureHold);
    handle.dispose();
  });

  // The splash may leave the tree while postload holds it: nothing stays
  // deferred and no exception escapes.
  testWidgets('a splash disposed after its first frame leaves the frames free '
      'and throws nothing', (tester) async {
    await _openFixture(tester);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    // Fire the postload hold the disposed splash still awaits, so no timer
    // stays pending; its result lands on an unmounted splash and drops.
    await tester.pump(splashScreenFixtureHold);

    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a splash disposed before its first state frees the frames', (
    tester,
  ) async {
    final controller = await _preloadTheme(tester);
    tester.binding.resetFirstFrameSent();
    // One pump with no runAsync yield: the splash's theme preload has not
    // finished, so it still holds the first frame when it leaves the tree.
    await tester.pumpWidget(
      FixtureApp(fixtureId: _fixtureId, themeController: controller),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Started'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(tester.takeException(), isNull);
    // Clear the timers the fixture and its postload left behind.
    await tester.pump(splashScreenFixtureHold);
  });
}
