import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/disabled.dart';
import 'package:stratum_ui/src/src.dart';

// NFR-U01 n/a: the gate paints nothing.
// NFR-U03 n/a: the gate runs no animation; screens swap at once.
// NFR-U04 n/a: the gate draws no text; the app's screens own it.
// NFR-U05 n/a: the gate has no target of its own.
// NFR-U07 n/a: the gate paints nothing.
// NFR-U08 n/a: the gate paints nothing.
// NFR-E01 n/a: not a component (d01 glossary), and the gate paints
// nothing; set B design R6.
// NFR-E02 n/a: not a component (d01 glossary); set B design R6.

/// An update check whose every ask waits until the test answers it.
class _Checker implements UpdateChecker {
  final List<Completer<UpdateStatus>> asks = [];

  @override
  Future<UpdateStatus> check() {
    final ask = Completer<UpdateStatus>();
    asks.add(ask);
    return ask.future;
  }

  /// Answers the latest ask with [status].
  void answer(UpdateStatus status) => asks.last.complete(status);

  /// Fails the latest ask.
  void fail() => asks.last.completeError(StateError('offline'));
}

typedef _Builder = Widget Function(BuildContext context, UpdateGateState gate);

/// The app's screens and dialog: a label naming the state, with
/// " checking" while a later ask runs. The dialog sits at the top, so the
/// app's "Behind" button in the middle stays uncovered.
Widget _screens(BuildContext context, UpdateGateState gate) {
  final busy = gate.checking ? ' checking' : '';
  return switch (gate) {
    UpdateGateRequired() => Material(
      child: Center(child: Text('Required$busy')),
    ),
    UpdateGateMaintenance(:final retry) => Material(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Maintenance$busy'),
            TextButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
    UpdateGateAvailable(:final dismiss) => Align(
      alignment: Alignment.topCenter,
      child: Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available$busy'),
            TextButton(onPressed: dismiss, child: const Text('Later')),
            TextButton(onPressed: () {}, child: const Text('Update')),
          ],
        ),
      ),
    ),
  };
}

/// A [MaterialApp] whose builder places the gate around its navigator;
/// its first page shows "Home" and a "Behind" button.
Widget _app(
  _Checker checker, {
  _Builder builder = _screens,
  VoidCallback? onBehind,
}) => MaterialApp(
  builder: (context, child) =>
      StratumUpdateGate(checker: checker, builder: builder, child: child!),
  home: Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Home'),
          TextButton(onPressed: onBehind ?? () {}, child: const Text('Behind')),
        ],
      ),
    ),
  ),
);

/// A builder that records every state it receives, then builds
/// [_screens].
_Builder _recording(List<UpdateGateState> states) => (context, gate) {
  states.add(gate);
  return _screens(context, gate);
};

/// Delivers [state] the way the platform does, over `flutter/lifecycle`.
Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );

/// The app goes to the background and comes back.
Future<void> _returnToForeground(WidgetTester tester) async {
  await _lifecycle(tester, AppLifecycleState.paused);
  await _lifecycle(tester, AppLifecycleState.resumed);
  await tester.pump();
}

/// Pushes a page that shows [label] over "Home".
Future<void> _push(WidgetTester tester, String label) async {
  Navigator.of(tester.element(find.text('Home'))).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Center(child: Text(label))),
    ),
  );
  await tester.pumpAndSettle();
}

/// The route scope the gate puts around a built screen.
Finder _scopeOf(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && (widget.properties.scopesRoute ?? false),
  ),
);

/// Shows the maintenance screen: the first ask answers maintenance.
Future<_Checker> _maintenance(WidgetTester tester) async {
  final checker = _Checker();
  await tester.pumpWidget(_app(checker));
  checker.answer(UpdateStatus.maintenance);
  await tester.pump(Duration.zero);
  return checker;
}

void main() {
  group("us01/fr01: ask the app's update check", () {
    testWidgets('us01/fr01/e02: while the first answer is pending the app '
        'shows', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      expect(find.text('Home'), findsOneWidget);
      expect(checker.asks, hasLength(1));
    });

    testWidgets('us01/s1: an up-to-date answer keeps the app', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('us01/fr01/e01: a failed check shows the app', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.fail();
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('us01/fr01/e03: a return to the foreground asks again', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      await _returnToForeground(tester);
      expect(checker.asks, hasLength(2));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('us01/fr01/e04: retry asks again, with checking, and an '
        'up-to-date answer shows the app', (tester) async {
      final checker = await _maintenance(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(checker.asks, hasLength(2));
      expect(find.text('Maintenance checking'), findsOneWidget);
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('us01/fr01/e06: a re-ask keeps the full screen, with '
        'checking, until it answers', (tester) async {
      final checker = await _maintenance(tester);
      await _returnToForeground(tester);
      expect(find.text('Maintenance checking'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('us01/fr01/e07: retry while an ask runs starts none', (
      tester,
    ) async {
      final checker = await _maintenance(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(checker.asks, hasLength(2));
    });

    testWidgets('us01/fr01/e08: a return to the foreground while an ask runs '
        'starts none, and checking stays', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      await _returnToForeground(tester);
      expect(checker.asks, hasLength(1));
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await _returnToForeground(tester);
      expect(checker.asks, hasLength(2));
      expect(find.text('Maintenance checking'), findsOneWidget);
    });

    testWidgets('us01/s10: a check on return that fails shows the first '
        'page', (tester) async {
      final checker = await _maintenance(tester);
      await _returnToForeground(tester);
      checker.fail();
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('us01/fr01/e05: every platform asks the same way', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
    }, variant: TargetPlatformVariant.all());

    testWidgets('an answer after unmount changes nothing', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      await tester.pumpWidget(const SizedBox.shrink());
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('s03/inv3: the builder never runs for up to date, a pending '
        'first answer, or a failed check', (tester) async {
      final states = <UpdateGateState>[];
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, builder: _recording(states)));
      expect(states, isEmpty);
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      await _returnToForeground(tester);
      checker.fail();
      await tester.pump(Duration.zero);
      expect(states, isEmpty);
    });
  });

  group('us01/fr02: replace the app with a full screen', () {
    testWidgets("us01/fr02: required replaces the navigator with the app's "
        'force update screen', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.byType(Navigator), findsNothing);
    });

    testWidgets('us01/fr02/e01: required carries neither retry nor dismiss', (
      tester,
    ) async {
      final states = <UpdateGateState>[];
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, builder: _recording(states)));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(states, isNotEmpty);
      expect(states, everyElement(isA<UpdateGateRequired>()));
    });

    testWidgets("us01/fr02: maintenance shows the app's maintenance screen "
        'with its retry', (tester) async {
      await _maintenance(tester);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets("us01/fr02/e03: after a full screen the app's pages start "
        'over', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.upToDate);
      await tester.pumpAndSettle();
      await _push(tester, 'Second');
      await _returnToForeground(tester);
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      checker.answer(UpdateStatus.upToDate);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('us01/fr02/e04: maintenance turns to required', (tester) async {
      final checker = await _maintenance(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Maintenance'), findsNothing);
    });

    testWidgets('us01/fr02/e06: a full screen opens a route scope and takes '
        'focus', (tester) async {
      final handle = tester.ensureSemantics();
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(_scopeOf('Required'), findsOneWidget);
      expect(
        tester.getSemantics(_scopeOf('Required')),
        isSemantics(scopesRoute: true),
      );
      expect(
        FocusScope.of(tester.element(find.text('Required'))).hasFocus,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('us01/fr02/e07: a screen swaps in one frame with no '
        'animation', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      await tester.pumpAndSettle();
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('the same answer keeps the screen and its focus', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      await tester.pump();
      final scope = FocusScope.of(tester.element(find.text('Required')));
      await _returnToForeground(tester);
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      await tester.pump();
      final after = FocusScope.of(tester.element(find.text('Required')));
      expect(identical(after, scope), isTrue);
      expect(after.hasFocus, isTrue);
    });

    testWidgets('a full screen hosts overlay widgets such as a tooltip', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(
        _app(
          checker,
          builder: (context, gate) => const Material(
            child: Center(
              child: Tooltip(message: 'Store', child: Text('Required')),
            ),
          ),
        ),
      );
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(tester.takeException(), isNull);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets("us01/fr02/e02: the force update screen's own button runs "
        "the app's code and the screen stays", (tester) async {
      var updates = 0;
      final checker = _Checker();
      await tester.pumpWidget(
        _app(
          checker,
          builder: (context, gate) => Material(
            child: Center(
              child: TextButton(
                onPressed: () => updates++,
                child: const Text('Update'),
              ),
            ),
          ),
        ),
      );
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      await tester.tap(find.text('Update'));
      await tester.pump();
      expect(updates, 1);
      expect(find.text('Update'), findsOneWidget);
      expect(checker.asks, hasLength(1));
    });

    testWidgets("us01/fr02/e05: the maintenance screen's retry asks the "
        'checker again', (tester) async {
      final checker = await _maintenance(tester);
      expect(checker.asks, hasLength(1));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(checker.asks, hasLength(2));
    });

    testWidgets('s03/inv10: no StratumDisabled wraps the gate', (tester) async {
      await _maintenance(tester);
      expect(find.byType(StratumDisabled), findsNothing);
    });
  });

  group('us01: stop the app for a required update or maintenance', () {
    testWidgets('us01/s2: a required update replaces every page and offers '
        'no way on', (tester) async {
      final states = <UpdateGateState>[];
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, builder: _recording(states)));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
      expect(find.byType(Navigator), findsNothing);
      expect(states.last, isA<UpdateGateRequired>());
    });

    testWidgets('us01/s3: a check on return keeps the maintenance screen and '
        'tells it a check runs', (tester) async {
      await _maintenance(tester);
      await _returnToForeground(tester);
      expect(find.text('Maintenance checking'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('us01/s4: maintenance replaces every page and offers a '
        'retry', (tester) async {
      await _maintenance(tester);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(Navigator), findsNothing);
    });

    testWidgets('us01/s5: a retry that finds the app up to date shows the '
        'first page', (tester) async {
      final checker = await _maintenance(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('us01/s6: back from the background, a required answer shows '
        'the force update screen', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
      await _returnToForeground(tester);
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('us01/s7: while the check has not answered, the first page '
        'shows', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(checker.asks.single.isCompleted, isFalse);
    });

    testWidgets('us01/s8: three pages deep, a retry that finds the app up to '
        'date starts at the first page', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.upToDate);
      await tester.pumpAndSettle();
      await _push(tester, 'Second');
      Navigator.of(tester.element(find.text('Second'))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('Third'))),
        ),
      );
      await tester.pumpAndSettle();
      await _returnToForeground(tester);
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      checker.answer(UpdateStatus.upToDate);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Third'), findsNothing);
    });

    testWidgets('us01/s9: a second retry while a check runs starts no second '
        'check', (tester) async {
      final checker = await _maintenance(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(checker.asks, hasLength(2));
    });

    testWidgets('us01/s11: a broken check shows the first page and never '
        'locks the app', (tester) async {
      var taps = 0;
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, onBehind: () => taps++));
      checker.fail();
      await tester.pump(Duration.zero);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Behind'));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
