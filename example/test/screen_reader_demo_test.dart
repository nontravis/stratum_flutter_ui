import 'dart:io';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// The splash loads widget settings over `shared_preferences`, which needs a
// fake platform here (precedent: stratum_ui's own test/flutter_test_config.dart).
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stratum_ui_example/screen_reader_demo.dart';

/// Pumps up to 500 rounds of a short real delay then a frame, returning as
/// soon as [finder] finds something: the splash preload reads assets, and
/// real time between frames lets it finish whether or not it needs the real
/// event loop.
Future<void> _pumpUntil(WidgetTester tester, FinderBase<Object?> finder) async {
  for (var i = 0; i < 500; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('never showed: $finder');
}

/// Pumps [ScreenReaderDemoApp] until the page's app bar shows, then settles.
Future<void> _pumpDemo(WidgetTester tester) async {
  // Forces the live-region path: every target reports supportsAnnounce
  // true by default, which a widget test cannot read.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(const ScreenReaderDemoApp());
  await _pumpUntil(tester, find.text('Screen reader checks'));
  await tester.pumpAndSettle();
}

/// The seven checks' opening words and sourced "Expected speech:" text, in
/// page order.
const _checks = [
  (
    '1. Reorder.',
    'Stratum UI FO-06 US-11 FR-03 E03; FR-06, Scenarios 16 and 17',
  ),
  ('2. Modal.', 'Stratum UI FO-06 US-20 FR-02; FR-06 E04'),
  ('3. Drawer.', 'Stratum UI FO-06 US-19 FR-05'),
  ('4. Divider.', 'Stratum UI FO-06 US-21 FR-04 E01; Scenario 4'),
  ('5. Page busy.', 'Stratum UI FO-06 US-18 Scenario 7'),
  ('6. Update gate.', 'Stratum UI CO-05-09 US-01 FR-02 E06; US-02 FR-01 E07'),
  ('7. Splash.', 'Stratum UI FO-03 US-12 FR-08'),
];

/// Returns the labels of the custom semantics actions on the semantics
/// node of the item keyed [item] (check 1's move-up, move-down, and jump
/// actions). Asserts that node also carries [item]'s own label, so a row
/// that splits its label and its moves onto two nodes (an `Interaction`
/// wrapper's own `Semantics` boundary) fails here instead of passing
/// silently with an empty move set read from the wrong node.
Set<String> _moves(WidgetTester tester, String item) {
  final data = tester
      .getSemantics(find.byKey(ValueKey(item)))
      .getSemanticsData();
  expect(
    data.label,
    item,
    reason:
        'the row\'s label and its move actions must share one '
        'semantics node',
  );
  return {
    for (final id in data.customSemanticsActionIds ?? const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  };
}

/// Performs the custom semantics action labeled [label] on the item keyed
/// [item], as a screen reader's own move gesture does.
void _moveAction(WidgetTester tester, String item, String label) {
  final node = tester.getSemantics(find.byKey(ValueKey(item)));
  node.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
  );
}

/// Scrolls [target] into view, then settles, as a screen reader's own
/// swipe-to-focus would, before a tap or key reaches it.
Future<void> _show(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  // The splash loads widget settings over `shared_preferences`, which needs
  // a fake platform in a widget test; the package's own test config does
  // this for every package test (test/flutter_test_config.dart), and this
  // page is the example app's first consumer of the splash default.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'f01/us13/fr01, f01/us13/fr01/e01: shows the app bar, the seven checks in '
    'page order, each with its steps and a sourced Expected speech line, and '
    'an empty log',
    (tester) async {
      await _pumpDemo(tester);
      expect(find.text('Screen reader checks'), findsOneWidget);
      var above = double.negativeInfinity;
      for (final (opening, source) in _checks) {
        final steps = find.textContaining(opening);
        expect(steps, findsOneWidget, reason: opening);
        expect(find.textContaining(source), findsOneWidget, reason: source);
        expect(
          tester.getTopLeft(steps).dy,
          greaterThan(above),
          reason: opening,
        );
        above = tester.getTopLeft(steps).dy;
      }
      expect(find.textContaining('Expected speech: '), findsNWidgets(7));
      expect(find.text('Log: nothing yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'f01/us13/fr01/e02: on a Thai device the app resolves Thai for the '
    'built-in labels while the page text stays English',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('th');
      tester.platformDispatcher.localesTestValue = const [Locale('th')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await _pumpDemo(tester);
      expect(
        Localizations.localeOf(
          tester.element(find.text('Screen reader checks')),
        ).languageCode,
        'th',
      );
      expect(find.textContaining('1. Reorder.'), findsOneWidget);
    },
  );

  test(
    'f01/us13/fr01/e03: the page imports Stratum only through its barrel',
    () {
      final imports = File('lib/screen_reader_demo.dart')
          .readAsLinesSync()
          .where((line) => line.startsWith('import '));
      expect(imports, contains("import 'package:stratum_ui/stratum_ui.dart';"));
      expect(
        imports.where((line) => line.contains('package:stratum_ui/src/')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'f01/us13/s1, f01/us13/fr01: each row offers only its valid moves, and '
    'moving Item 3 down speaks Moved to position 4 of 5',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      expect(_moves(tester, 'Item 1'), {'Move down', 'Move to the end'});
      expect(_moves(tester, 'Item 3'), {
        'Move to the start',
        'Move up',
        'Move down',
        'Move to the end',
      });
      expect(_moves(tester, 'Item 5'), {'Move to the start', 'Move up'});

      _moveAction(tester, 'Item 3', 'Move down');
      await tester.pumpAndSettle();

      expect(
        find.semantics.byLabel('Moved to position 4 of 5').evaluate().single,
        isSemantics(isLiveRegion: true),
      );
      expect(
        tester.getTopLeft(find.text('Item 4')).dy,
        lessThan(tester.getTopLeft(find.text('Item 3')).dy),
      );
      expect(find.text('Log: Item 3 moved to position 4'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s1, f01/us13/fr01/e07: Alt+Up on the first row speaks Already '
    'at the start of the list and moves nothing',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      // The test host is Android, where a scrolling box is no Tab stop, so
      // the first Tab stop on the page is Item 1's row Focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('Item 1'))).hasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(
        find.semantics
            .byLabel('Already at the start of the list')
            .evaluate()
            .single,
        isSemantics(isLiveRegion: true),
      );
      expect(find.text('Log: nothing yet.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s2, f01/us13/fr01: Open modal shows a route named Dialog over a '
    'Dismiss scrim with the page hidden, and Esc returns focus to Open modal',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      await _show(tester, find.text('Open modal'));
      final opener = Focus.of(tester.element(find.text('Open modal')))
        ..requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Dialog')),
        isSemantics(label: 'Dialog', scopesRoute: true, namesRoute: true),
      );
      expect(find.semantics.byLabel('Dismiss'), findsOne);
      expect(find.semantics.byLabel('Screen reader checks'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, opener);
      expect(find.text('Log: Modal opened; Modal closed'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('f01/us13/fr01: on Linux the modal scrim reads nothing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpDemo(tester);
    await _show(tester, find.text('Open modal'));
    await tester.tap(find.text('Open modal'));
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('Dialog'), findsOne);
    expect(find.semantics.byLabel('Dismiss'), findsNothing);
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'f01/us13/fr01/e02: on a Thai device the modal reads the Thai built-in '
    'dialog label',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('th');
      tester.platformDispatcher.localesTestValue = const [Locale('th')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      await _show(tester, find.text('Open modal'));
      await tester.tap(find.text('Open modal'));
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('กล่องโต้ตอบ'), findsOne);
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s3, f01/us13/fr01: the menu button opens a route named '
    'Navigation menu over a Dismiss scrim with the page hidden; Esc closes it',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      await _show(tester, find.byTooltip('Open the drawer'));
      await tester.tap(find.byTooltip('Open the drawer'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Navigation menu')),
        isSemantics(
          label: 'Navigation menu',
          scopesRoute: true,
          namesRoute: true,
        ),
      );
      expect(find.semantics.byLabel('Dismiss'), findsOne);
      expect(find.semantics.byLabel('Screen reader checks'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Screen reader checks'), findsOne);
      expect(find.text('Log: Drawer opened; Drawer closed'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s8, f01/us13/fr01/e04: at 1600 logical px wide the start pane '
    'sits inline and the menu button opens nothing',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      expect(
        find.text('Check 3: the start pane.').hitTestable(),
        findsOneWidget,
      );
      await _show(tester, find.byTooltip('Open the drawer'));
      await tester.tap(find.byTooltip('Open the drawer'));
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Dismiss'), findsNothing);
      expect(find.text('Log: nothing yet.'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/fr01/e04: at 1599 logical px wide the menu button opens the '
    'drawer',
    (tester) async {
      tester.view.physicalSize = const Size(1599, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpDemo(tester);
      await _show(tester, find.byTooltip('Open the drawer'));
      await tester.tap(find.byTooltip('Open the drawer'));
      await tester.pumpAndSettle();
      expect(find.text('Log: Drawer opened'), findsOneWidget);
    },
  );

  test('f01/us13/fr01: the log keeps the last six demo actions', () {
    var log = const <String>[];
    for (var i = 1; i <= 7; i++) {
      log = appendToLog(log, 'a$i');
    }
    expect(log, ['a2', 'a3', 'a4', 'a5', 'a6', 'a7']);
  });

  testWidgets(
    'f01/us13/s4, f01/us13/fr01: the divider is a slider labeled Resize '
    'panes at 30%, and increase then decrease read the new percent',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      await _show(tester, find.text('Start pane'));
      final divider = find.semantics.byLabel('Resize panes');
      final start = divider.evaluate().single;
      expect(
        start,
        isSemantics(
          label: 'Resize panes',
          value: '30%',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      final up = start.getSemanticsData().increasedValue;
      expect(up, isNot('30%'));

      tester.semantics.performAction(divider, SemanticsAction.increase);
      await tester.pump();
      expect(divider.evaluate().single.value, up);

      tester.semantics.performAction(divider, SemanticsAction.decrease);
      await tester.pump();
      expect(divider.evaluate().single.value, '30%');
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s5, f01/us13/fr01: Set the page loading for 5 s reads Loading '
    'as a live region, takes no tap, and ends after 5 s',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      final button = find.text('Set the page loading for 5 s');
      await _show(tester, button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Loading')),
        isSemantics(label: 'Loading', isLiveRegion: true),
      );
      await tester.tap(button, warnIfMissed: false);

      await tester.pump(pageLoadingHold);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Loading'), findsNothing);
      expect(
        find.text('Log: Page loading for 5 s; Page loaded'),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s6, f01/us13/fr01: the required screen replaces the page as its '
    'own route scope, and Back to the checks returns',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      await _show(tester, find.text('Show the required update screen'));
      await tester.tap(find.text('Show the required update screen'));
      await tester.pumpAndSettle();

      final scope = find.ancestor(
        of: find.text('Update required'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.scopesRoute ?? false),
        ),
      );
      expect(scope, findsOneWidget);
      expect(tester.getSemantics(scope), isSemantics(scopesRoute: true));
      expect(find.semantics.byLabel('Screen reader checks'), findsNothing);

      await tester.tap(find.text('Back to the checks'));
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsNothing);
      expect(
        find.text('Log: Required update screen shown; Back to the checks'),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s7, f01/us13/fr01/e06: the replayed splash reads Loading as a '
    'live region with frames flowing, and the checks come back as they were',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      _moveAction(tester, 'Item 3', 'Move down');
      await tester.pumpAndSettle();

      await _show(tester, find.text('Show the splash for 5 s'));
      await tester.tap(find.text('Show the splash for 5 s'));
      await _pumpUntil(tester, find.semantics.byLabel('Loading'));
      expect(
        find.semantics.byLabel('Loading').evaluate().single,
        isSemantics(label: 'Loading', isLiveRegion: true),
      );
      expect(tester.binding.sendFramesToEngine, isTrue);

      await tester.pump(splashReplayHold);
      await _pumpUntil(tester, find.text('Screen reader checks'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Item 4')).dy,
        lessThan(tester.getTopLeft(find.text('Item 3')).dy),
      );
      expect(
        find.text(
          'Log: Item 3 moved to position 4; Splash shown for 5 s; Splash done',
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s6, f01/us13/fr01/e05: the optional dialog is read alone, Later '
    'closes it, and a second press opens it again',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      final optional = find.text('Show the optional update dialog');
      for (var round = 0; round < 2; round++) {
        await _show(tester, optional);
        await tester.tap(optional);
        await tester.pumpAndSettle();
        expect(find.text('Update available'), findsOneWidget);
        expect(find.semantics.byLabel('Later'), findsOne);
        expect(find.semantics.byLabel('Screen reader checks'), findsNothing);

        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
        expect(find.text('Update available'), findsNothing);
        expect(find.semantics.byLabel('Screen reader checks'), findsOne);
      }
      expect(
        find.text(
          'Log: Optional update dialog shown; Later; '
          'Optional update dialog shown; Later',
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s6, f01/us13/fr01/e05, f01/us13/fr01/e06: the system back '
    'route ends the gate like Later, so a splash replay does not reopen '
    'the optional dialog',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      final optional = find.text('Show the optional update dialog');
      await _show(tester, optional);
      await tester.tap(optional);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      await _show(tester, find.text('Show the splash for 5 s'));
      await tester.tap(find.text('Show the splash for 5 s'));
      await _pumpUntil(tester, find.semantics.byLabel('Loading'));
      await tester.pump(splashReplayHold);
      await _pumpUntil(tester, find.text('Screen reader checks'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'f01/us13/s6, f01/us13/fr01/e05, f01/us13/fr01/e06: Esc ends the gate '
    'like Later, so a splash replay does not reopen the optional dialog',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDemo(tester);
      final optional = find.text('Show the optional update dialog');
      await _show(tester, optional);
      await tester.tap(optional);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      await _show(tester, find.text('Show the splash for 5 s'));
      await tester.tap(find.text('Show the splash for 5 s'));
      await _pumpUntil(tester, find.semantics.byLabel('Loading'));
      await tester.pump(splashReplayHold);
      await _pumpUntil(tester, find.text('Screen reader checks'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      handle.dispose();
    },
  );
}
