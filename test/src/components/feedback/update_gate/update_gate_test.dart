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

/// An update check that throws before it returns a future at all.
class _SyncThrowChecker implements UpdateChecker {
  @override
  Future<UpdateStatus> check() => throw StateError('offline');
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

/// The dialog alone, with its own "Update" carrying the app's own
/// `autofocus`: NFR-U02 asks that the app's choice of first focus wins
/// over the gate's.
Widget _autofocusDialog(BuildContext context, UpdateGateState gate) =>
    switch (gate) {
      UpdateGateAvailable(:final dismiss) => Align(
        alignment: Alignment.topCenter,
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: dismiss, child: const Text('Later')),
              TextButton(
                autofocus: true,
                onPressed: () {},
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      ),
      _ => const SizedBox(),
    };

/// A [MaterialApp] whose builder places the gate around its navigator;
/// its first page shows "Home" and a "Behind" button.
Widget _app(
  UpdateChecker checker, {
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
  group("co05_09/us01/fr01: ask the app's update check", () {
    testWidgets(
      'co05_09/us01/fr01/e02: while the first answer is pending the app '
      'shows',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        expect(find.text('Home'), findsOneWidget);
        expect(checker.asks, hasLength(1));
      },
    );

    testWidgets('co05_09/us01/s1: an up-to-date answer keeps the app', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('co05_09/us01/fr01/e01: a failed check shows the app', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.fail();
      await tester.pump(Duration.zero);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'co05_09/us01/fr01/e01: a checker that throws before returning a '
      'future shows the app',
      (tester) async {
        await tester.pumpWidget(_app(_SyncThrowChecker()));
        await tester.pump();
        expect(find.text('Home'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'co05_09/us01/fr01/e03: a return to the foreground asks again',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        checker.answer(UpdateStatus.upToDate);
        await tester.pump(Duration.zero);
        await _returnToForeground(tester);
        expect(checker.asks, hasLength(2));
        checker.answer(UpdateStatus.required);
        await tester.pump(Duration.zero);
        expect(find.text('Required'), findsOneWidget);
      },
    );

    // R8: the gate re-asks only on a return from the background. A
    // foreground interruption (`inactive` alone, Face ID or Control
    // Center) and a cold start's own first `resumed` never count as one;
    // `hidden` or `paused` before `resumed` always does. Every row starts
    // the binding's lifecycle at null (the test framework resets it after
    // each test), so a row naming a prior `resumed` sends it itself.
    for (final (name, states, asks) in <(String, List<AppLifecycleState>, int)>[
      (
        "a cold start's first resumed asks none",
        [AppLifecycleState.resumed],
        1,
      ),
      (
        'null then inactive then resumed asks none',
        [AppLifecycleState.inactive, AppLifecycleState.resumed],
        1,
      ),
      (
        'resumed then inactive then resumed asks none',
        [
          AppLifecycleState.resumed,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ],
        1,
      ),
      (
        'paused then resumed asks once',
        [AppLifecycleState.paused, AppLifecycleState.resumed],
        2,
      ),
      (
        'hidden then inactive then resumed asks once',
        [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ],
        2,
      ),
    ]) {
      testWidgets('co05_09/us01/fr01/e03: $name', (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        checker.answer(UpdateStatus.upToDate);
        await tester.pump(Duration.zero);
        for (final state in states) {
          await _lifecycle(tester, state);
        }
        await tester.pump();
        expect(checker.asks, hasLength(asks));
      });
    }

    testWidgets('co05_09/us01/fr01/e03: mounted while hidden, then inactive, '
        'resumed asks once more', (tester) async {
      tester.binding.resetInternalState();
      await _lifecycle(tester, AppLifecycleState.hidden);
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      // Frames are off while hidden; a real app still builds its tree
      // through runApp's warm-up frame, so force one.
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      await _lifecycle(tester, AppLifecycleState.inactive);
      await _lifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(checker.asks, hasLength(2));
    });

    testWidgets(
      'co05_09/us01/fr01/e04: retry asks again, with checking, and an '
      'up-to-date answer shows the app',
      (tester) async {
        final checker = await _maintenance(tester);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(checker.asks, hasLength(2));
        expect(find.text('Maintenance checking'), findsOneWidget);
        checker.answer(UpdateStatus.upToDate);
        await tester.pump(Duration.zero);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('co05_09/us01/fr01/e06: a re-ask keeps the full screen, with '
        'checking, until it answers', (tester) async {
      final checker = await _maintenance(tester);
      await _returnToForeground(tester);
      expect(find.text('Maintenance checking'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('co05_09/us01/fr01/e07: retry while an ask runs starts none', (
      tester,
    ) async {
      final checker = await _maintenance(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(checker.asks, hasLength(2));
    });

    testWidgets(
      'co05_09/us01/fr01/e08: a return to the foreground while an ask runs '
      'starts none, and checking stays',
      (tester) async {
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
      },
    );

    testWidgets(
      'co05_09/us01/s10: a check on return that fails shows the first '
      'page',
      (tester) async {
        final checker = await _maintenance(tester);
        await _returnToForeground(tester);
        checker.fail();
        await tester.pump(Duration.zero);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('co05_09/us01/fr01/e05: every platform asks the same way', (
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

  group('co05_09/us01/fr02: replace the app with a full screen', () {
    testWidgets(
      "co05_09/us01/fr02: required replaces the navigator with the app's "
      'force update screen',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        checker.answer(UpdateStatus.required);
        await tester.pump(Duration.zero);
        expect(find.text('Required'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
        expect(find.byType(Navigator), findsNothing);
      },
    );

    testWidgets(
      'co05_09/us01/fr02/e01: required carries neither retry nor dismiss',
      (tester) async {
        final states = <UpdateGateState>[];
        final checker = _Checker();
        await tester.pumpWidget(_app(checker, builder: _recording(states)));
        checker.answer(UpdateStatus.required);
        await tester.pump(Duration.zero);
        expect(states, isNotEmpty);
        expect(states, everyElement(isA<UpdateGateRequired>()));
      },
    );

    testWidgets(
      "co05_09/us01/fr02: maintenance shows the app's maintenance screen "
      'with its retry',
      (tester) async {
        await _maintenance(tester);
        expect(find.text('Maintenance'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
      },
    );

    testWidgets(
      "co05_09/us01/fr02/e03: after a full screen the app's pages start "
      'over',
      (tester) async {
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
      },
    );

    testWidgets('co05_09/us01/fr02/e04: maintenance turns to required', (
      tester,
    ) async {
      final checker = await _maintenance(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Maintenance'), findsNothing);
    });

    testWidgets('co05_09/us01/fr02/e04: required turns to maintenance', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      await _returnToForeground(tester);
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Required'), findsNothing);
    });

    testWidgets(
      'co05_09/us01/fr02/e06: a full screen opens a route scope and takes '
      'focus',
      (tester) async {
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
      },
    );

    testWidgets('co05_09/us01/fr02/e07: a screen swaps in one frame with no '
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

    // s01 "Full screens (the app's)" row / PD3: a full screen replaces the
    // navigator and its overlay, so a text field works on it too.
    testWidgets('a full screen hosts a focusable, typeable text field', (
      tester,
    ) async {
      final checker = _Checker();
      await tester.pumpWidget(
        _app(
          checker,
          builder: (context, gate) =>
              const Material(child: Center(child: TextField())),
        ),
      );
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Store');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Store'), findsOneWidget);
    });

    testWidgets(
      "co05_09/us01/fr02/e02: the force update screen's own button runs "
      "the app's code and the screen stays",
      (tester) async {
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
      },
    );

    testWidgets(
      "co05_09/us01/fr02/e05: the maintenance screen's retry asks the "
      'checker again',
      (tester) async {
        final checker = await _maintenance(tester);
        expect(checker.asks, hasLength(1));
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(checker.asks, hasLength(2));
      },
    );

    testWidgets('s03/inv10: no StratumDisabled wraps the gate', (tester) async {
      await _maintenance(tester);
      expect(find.byType(StratumDisabled), findsNothing);
    });
  });

  group('us01: stop the app for a required update or maintenance', () {
    testWidgets(
      'co05_09/us01/s2: a required update replaces every page and offers '
      'no way on',
      (tester) async {
        final states = <UpdateGateState>[];
        final checker = _Checker();
        await tester.pumpWidget(_app(checker, builder: _recording(states)));
        checker.answer(UpdateStatus.required);
        await tester.pump(Duration.zero);
        expect(find.text('Required'), findsOneWidget);
        expect(find.byType(Navigator), findsNothing);
        expect(states.last, isA<UpdateGateRequired>());
      },
    );

    testWidgets(
      'co05_09/us01/s3: a check on return keeps the maintenance screen and '
      'tells it a check runs',
      (tester) async {
        await _maintenance(tester);
        await _returnToForeground(tester);
        expect(find.text('Maintenance checking'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
      },
    );

    testWidgets('co05_09/us01/s4: maintenance replaces every page and offers a '
        'retry', (tester) async {
      await _maintenance(tester);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(Navigator), findsNothing);
    });

    testWidgets(
      'co05_09/us01/s5: a retry that finds the app up to date shows the '
      'first page',
      (tester) async {
        final checker = await _maintenance(tester);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        checker.answer(UpdateStatus.upToDate);
        await tester.pump(Duration.zero);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets(
      'co05_09/us01/s6: back from the background, a required answer shows '
      'the force update screen',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        checker.answer(UpdateStatus.upToDate);
        await tester.pump(Duration.zero);
        expect(find.text('Home'), findsOneWidget);
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.required);
        await tester.pump(Duration.zero);
        expect(find.text('Required'), findsOneWidget);
      },
    );

    testWidgets(
      'co05_09/us01/s7: while the check has not answered, the first page '
      'shows',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        await tester.pump();
        expect(find.text('Home'), findsOneWidget);
        expect(checker.asks.single.isCompleted, isFalse);
      },
    );

    testWidgets(
      'co05_09/us01/s8: three pages deep, a retry that finds the app up to '
      'date starts at the first page',
      (tester) async {
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
      },
    );

    testWidgets(
      'co05_09/us01/s9: a second retry while a check runs starts no second '
      'check',
      (tester) async {
        final checker = await _maintenance(tester);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(checker.asks, hasLength(2));
      },
    );

    testWidgets(
      'co05_09/us01/s11: a broken check shows the first page and never '
      'locks the app',
      (tester) async {
        var taps = 0;
        final checker = _Checker();
        await tester.pumpWidget(_app(checker, onBehind: () => taps++));
        checker.fail();
        await tester.pump(Duration.zero);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Behind'));
        await tester.pump();
        expect(taps, 1);
      },
    );
  });

  /// The Android back button, over `flutter/navigation`.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMessageCodec().encodeMessage(<String, Object?>{
        'method': 'popRoute',
      }),
      (_) {},
    );
    await tester.pump();
  }

  /// Delivers one predictive back [method] over `flutter/backgesture`,
  /// the channel Android's predictive back drives.
  Future<void> backGesture(
    WidgetTester tester,
    String method, {
    double progress = 0,
  }) {
    final hasTouch =
        method == 'startBackGesture' || method == 'updateBackGestureProgress';
    final call = MethodCall(
      method,
      hasTouch
          ? <String, Object?>{
              'touchOffset': const <double>[5, 200],
              'progress': progress,
              'swipeEdge': SwipeEdge.left.index,
            }
          : null,
    );
    return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.backGesture.name,
      SystemChannels.backGesture.codec.encodeMethodCall(call),
      (_) {},
    );
  }

  /// Lets an answer open the dialog: the answer's frame shows the app, and
  /// the route the gate pushes after that frame builds in the next one.
  Future<void> dialogFrames(WidgetTester tester) async {
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  /// Shows the dialog over the app: the first ask answers available.
  Future<_Checker> available(
    WidgetTester tester, {
    _Builder builder = _screens,
    VoidCallback? onBehind,
  }) async {
    final checker = _Checker();
    await tester.pumpWidget(
      _app(checker, builder: builder, onBehind: onBehind),
    );
    checker.answer(UpdateStatus.available);
    await dialogFrames(tester);
    return checker;
  }

  group('co05_09/us02/fr01: offer the update once in a dialog', () {
    testWidgets(
      "co05_09/us02/s1: available shows the app's dialog over the app",
      (tester) async {
        await available(tester);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('co05_09/us02/fr01: the dialog is a route on the app navigator '
        'that runs no transition', (tester) async {
      await available(tester);
      final route = ModalRoute.of(tester.element(find.text('Available')));
      expect(route, isA<RawDialogRoute<void>>());
      expect(route!.opaque, isFalse);
      expect(route.barrierDismissible, isFalse);
      expect(route.barrierColor, isNull);
      expect(route.transitionDuration, Duration.zero);
      expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);
      expect(
        route.navigator,
        same(Navigator.of(tester.element(find.text('Home')))),
      );
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
      "co05_09/us02/fr01/e01: available again in the same gate's lifetime "
      'shows no dialog',
      (tester) async {
        final checker = await available(tester);
        await tester.tap(find.text('Later'));
        await tester.pump();
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.available);
        await dialogFrames(tester);
        expect(find.text('Available'), findsNothing);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('co05_09/us02/fr01/e02: a new gate offers the update again', (
      tester,
    ) async {
      await available(tester);
      await tester.tap(find.text('Later'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await available(tester);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets(
      'co05_09/us02/fr01/e03: three pages deep, Android back closes the '
      'dialog alone and the page stays',
      (tester) async {
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
        checker.answer(UpdateStatus.available);
        await dialogFrames(tester);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('Third'), findsOneWidget);
        await systemBack(tester);
        expect(find.text('Available'), findsNothing);
        expect(find.text('Third'), findsOneWidget);
        await systemBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('Second'), findsOneWidget);
      },
    );

    testWidgets('co05_09/us02/fr01/e03: under MaterialApp.router, Android back '
        'closes the dialog alone and the page stays', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: RouterConfig<Object>(
            routerDelegate: _TwoPages(),
            backButtonDispatcher: RootBackButtonDispatcher(),
          ),
          builder: (context, child) => StratumUpdateGate(
            checker: checker,
            builder: _screens,
            child: child!,
          ),
        ),
      );
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      await systemBack(tester);
      expect(find.text('Available'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets(
      'co05_09/us02/fr01/e03: later leaves the shown page as it was',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        checker.answer(UpdateStatus.upToDate);
        await tester.pumpAndSettle();
        await _push(tester, 'Second');
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.available);
        await dialogFrames(tester);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
      },
    );

    testWidgets('co05_09/us02/fr01/e04: Esc dismisses the dialog', (
      tester,
    ) async {
      await available(tester);
      expect(find.text('Available'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Available'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('co05_09/us02/fr01/e04: the Android back button dismisses the '
        'dialog', (tester) async {
      await available(tester);
      expect(find.text('Available'), findsOneWidget);
      await systemBack(tester);
      expect(find.text('Available'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets(
      'co05_09/us02/fr01/e04: Android lets the app handle back while the '
      'dialog shows',
      (tester) async {
        final handlesBack = <Object?>[];
        final messenger = tester.binding.defaultBinaryMessenger
          ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
              handlesBack.add(call.arguments);
            }
            return null;
          });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await _lifecycle(tester, AppLifecycleState.resumed);
        await available(tester);
        expect(handlesBack.last, isTrue);
        await tester.tap(find.text('Later'));
        await tester.pump();
        await tester.pump();
        expect(handlesBack.last, isFalse);
      },
    );

    testWidgets(
      'co05_09/us02/fr01/e05: focus moves into the dialog, and Tab from '
      'its last control moves to its first',
      (tester) async {
        await available(tester);
        bool focused(String label) =>
            Focus.of(tester.element(find.text(label))).hasFocus;
        expect(
          FocusScope.of(tester.element(find.text('Later'))).hasFocus,
          isTrue,
        );
        for (final label in ['Later', 'Update', 'Later', 'Update']) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(focused(label), isTrue);
          expect(focused('Behind'), isFalse);
        }
      },
    );

    testWidgets(
      'co05_09/us02/fr01/e06: a tap outside the dialog reaches nothing '
      'behind it',
      (tester) async {
        var behindTaps = 0;
        await available(tester, onBehind: () => behindTaps++);
        await tester.tap(find.text('Behind'), warnIfMissed: false);
        await tester.pump();
        expect(behindTaps, 0);
        expect(find.text('Available'), findsOneWidget);
      },
    );

    testWidgets(
      'co05_09/us02/fr01/e07: a screen reader reads the dialog alone',
      (tester) async {
        final handle = tester.ensureSemantics();
        await available(tester);
        expect(find.semantics.byLabel('Behind'), findsNothing);
        expect(find.semantics.byLabel('Home'), findsNothing);
        expect(find.semantics.byLabel('Later'), findsOne);
        await tester.tap(find.text('Later'));
        await tester.pump();
        expect(find.semantics.byLabel('Behind'), findsOne);
        handle.dispose();
      },
    );

    testWidgets("co05_09/us02/fr01/e08: the app's update button runs the app's "
        'code, and the gate leaves the dialog open', (tester) async {
      var updates = 0;
      await available(
        tester,
        builder: (context, gate) => switch (gate) {
          UpdateGateAvailable() => Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: TextButton(
                onPressed: () => updates++,
                child: const Text('Update'),
              ),
            ),
          ),
          _ => _screens(context, gate),
        },
      );
      await tester.tap(find.text('Update'));
      await tester.pump();
      expect(updates, 1);
      expect(find.text('Update'), findsOneWidget);
    });

    for (final (label, settle) in <(String, void Function(_Checker))>[
      ('up to date', (checker) => checker.answer(UpdateStatus.upToDate)),
      ('a failure', (checker) => checker.fail()),
    ]) {
      testWidgets(
        'co05_09/us02/fr01/e09: a later ask that answers $label closes the '
        'dialog',
        (tester) async {
          final checker = await available(tester);
          expect(find.text('Available'), findsOneWidget);
          await _returnToForeground(tester);
          settle(checker);
          await tester.pump(Duration.zero);
          expect(find.text('Available'), findsNothing);
          expect(find.text('Home'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'co05_09/us01/fr01/e06: a re-ask keeps the dialog, with checking',
      (tester) async {
        final checker = await available(tester);
        await _returnToForeground(tester);
        expect(find.text('Available checking'), findsOneWidget);
        checker.answer(UpdateStatus.available);
        await tester.pump(Duration.zero);
        expect(find.text('Available'), findsOneWidget);
      },
    );

    testWidgets(
      'co05_09/us02/fr01: a full screen turns into the dialog on a first '
      'available answer',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(_app(checker));
        checker.answer(UpdateStatus.required);
        await tester.pump(Duration.zero);
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.available);
        await dialogFrames(tester);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('co05_09/us01/fr02: a required answer while the dialog shows '
        'replaces the navigator, dialog and all', (tester) async {
      final checker = await available(tester);
      expect(find.text('Available'), findsOneWidget);
      await _returnToForeground(tester);
      checker.answer(UpdateStatus.required);
      await tester.pump(Duration.zero);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
      await _returnToForeground(tester);
      checker.answer(UpdateStatus.upToDate);
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'co05_09/us01/fr02: a maintenance answer while the dialog shows '
      'replaces the navigator, dialog and all',
      (tester) async {
        final checker = await available(tester);
        expect(find.text('Available'), findsOneWidget);
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.maintenance);
        await tester.pump(Duration.zero);
        expect(find.text('Maintenance'), findsOneWidget);
        expect(find.text('Available'), findsNothing);
        expect(find.byType(Navigator), findsNothing);
      },
    );

    testWidgets(
      'co05_09/us02/fr01/e01: after the dialog showed, available from a '
      'full screen shows the app alone',
      (tester) async {
        final checker = await available(tester);
        await tester.tap(find.text('Later'));
        await tester.pump();
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.required);
        await tester.pump(Duration.zero);
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.available);
        await dialogFrames(tester);
        expect(find.text('Available'), findsNothing);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('the dialog hosts overlay widgets such as a tooltip', (
      tester,
    ) async {
      await available(
        tester,
        builder: (context, gate) => const Align(
          alignment: Alignment.topCenter,
          child: Material(
            child: Tooltip(message: 'Store', child: Text('Available')),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets(
      'co05_09/us02/fr01: with no navigator below the gate no dialog shows, '
      'and a debug assert names the placement',
      (tester) async {
        final checker = _Checker();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StratumUpdateGate(
              checker: checker,
              builder: _screens,
              child: const SizedBox(),
            ),
          ),
        );
        checker.answer(UpdateStatus.available);
        await tester.pump(Duration.zero);
        expect(tester.takeException(), isAssertionError);
        expect(find.text('Available'), findsNothing);
      },
    );

    testWidgets('the gate unmounts with the dialog up', (tester) async {
      await available(tester);
      expect(find.text('Available'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismiss called twice closes the dialog once', (tester) async {
      VoidCallback? dismiss;
      await available(
        tester,
        builder: (context, gate) => switch (gate) {
          UpdateGateAvailable(dismiss: final d) => Builder(
            builder: (context) {
              dismiss = d;
              return _screens(context, gate);
            },
          ),
          _ => _screens(context, gate),
        },
      );
      dismiss!();
      dismiss!();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Available'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('the app pops the dialog route itself, with Navigator.pop', (
      tester,
    ) async {
      await available(tester);
      expect(find.text('Available'), findsOneWidget);
      Navigator.of(tester.element(find.text('Available'))).pop();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Available'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('StratumUpdateGate accessibility gate', () {
    testWidgets('NFR-U02: focus moves into a full screen and into the '
        'dialog; Tab stays in the dialog; Esc dismisses it', (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(
        FocusScope.of(tester.element(find.text('Retry'))).hasFocus,
        isTrue,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      expect(
        FocusScope.of(tester.element(find.text('Later'))).hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusScope.of(tester.element(find.text('Later'))).hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Available'), findsNothing);
    });

    testWidgets("NFR-U02: the app's own autofocus control takes focus over "
        "the gate's", (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, builder: _autofocusDialog));
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      expect(Focus.of(tester.element(find.text('Update'))).hasFocus, isTrue);
    });

    testWidgets('NFR-U02: Esc before any Tab dismisses the dialog, with '
        "the app's own autofocus set", (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, builder: _autofocusDialog));
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Update'), findsNothing);
    });

    testWidgets('NFR-U02: Tab cycles inside the dialog, with the '
        "app's own autofocus set", (tester) async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, builder: _autofocusDialog));
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      bool focused(String label) =>
          Focus.of(tester.element(find.text(label))).hasFocus;
      for (final label in ['Later', 'Update', 'Later', 'Update']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(label), isTrue);
        expect(focused('Behind'), isFalse);
      }
    });

    testWidgets('NFR-U06: a full screen and the dialog each open a route '
        'scope, and the app behind the dialog leaves the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      checker.answer(UpdateStatus.maintenance);
      await tester.pump(Duration.zero);
      expect(
        tester.getSemantics(_scopeOf('Maintenance')),
        isSemantics(scopesRoute: true),
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      expect(
        tester.getSemantics(_scopeOf('Available')),
        isSemantics(scopesRoute: true),
      );
      expect(find.semantics.byLabel('Home'), findsNothing);
      handle.dispose();
    });

    testWidgets('NFR-U09: a barrier blocks pointers to the app behind the '
        'dialog', (tester) async {
      var behindTaps = 0;
      final checker = _Checker();
      await tester.pumpWidget(_app(checker, onBehind: () => behindTaps++));
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      await tester.tap(find.text('Behind'), warnIfMissed: false);
      await tester.pump();
      expect(behindTaps, 0);
    });
  });

  group('us02: offer an optional update', () {
    for (final (way, close) in <(String, Future<void> Function(WidgetTester))>[
      (
        "the app's later button",
        (tester) async {
          await tester.tap(find.text('Later'));
          await tester.pump();
        },
      ),
      (
        'Esc',
        (tester) async {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
        },
      ),
      ('the Android back button', systemBack),
    ]) {
      testWidgets(
        'co05_09/us02/s2: $way closes the dialog and the app stays on its '
        'page',
        (tester) async {
          final checker = _Checker();
          await tester.pumpWidget(_app(checker));
          checker.answer(UpdateStatus.upToDate);
          await tester.pumpAndSettle();
          await _push(tester, 'Second');
          await _returnToForeground(tester);
          checker.answer(UpdateStatus.available);
          await dialogFrames(tester);
          expect(find.text('Available'), findsOneWidget);
          await close(tester);
          expect(find.text('Available'), findsNothing);
          expect(find.text('Second'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'co05_09/us02/s3: focus starts in the dialog and Tab moves only among '
      'its controls',
      (tester) async {
        await available(tester);
        bool focused(String label) =>
            Focus.of(tester.element(find.text(label))).hasFocus;
        expect(
          FocusScope.of(tester.element(find.text('Later'))).hasFocus,
          isTrue,
        );
        for (var press = 0; press < 5; press++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(focused('Later') || focused('Update'), isTrue);
          expect(focused('Behind'), isFalse);
        }
      },
    );

    testWidgets(
      'co05_09/us02/s4: after the dialog closed, a return to the app shows '
      'no dialog',
      (tester) async {
        final checker = await available(tester);
        await tester.tap(find.text('Later'));
        await tester.pump();
        await _returnToForeground(tester);
        checker.answer(UpdateStatus.available);
        await dialogFrames(tester);
        expect(find.text('Available'), findsNothing);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('co05_09/us02/s5: a new launch offers the update again', (
      tester,
    ) async {
      await available(tester);
      await tester.tap(find.text('Later'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await available(tester);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('co05_09/us02/s6: a screen reader reads the dialog alone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await available(tester);
      expect(find.semantics.byLabel('Available'), findsOne);
      expect(find.semantics.byLabel('Later'), findsOne);
      expect(find.semantics.byLabel('Home'), findsNothing);
      expect(find.semantics.byLabel('Behind'), findsNothing);
      handle.dispose();
    });

    testWidgets(
      'co05_09/us02/s7: a tap behind the dialog reaches no page, and only '
      "the app's scrim closes the dialog",
      (tester) async {
        var behindTaps = 0;
        await available(
          tester,
          onBehind: () => behindTaps++,
          builder: (context, gate) => switch (gate) {
            UpdateGateAvailable(:final dismiss) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: dismiss,
                  ),
                ),
                const Align(
                  alignment: Alignment.topCenter,
                  child: Material(child: Text('Available')),
                ),
              ],
            ),
            _ => _screens(context, gate),
          },
        );
        expect(find.text('Available'), findsOneWidget);
        await tester.tap(find.text('Behind'), warnIfMissed: false);
        await tester.pump();
        expect(behindTaps, 0);
        expect(find.text('Available'), findsNothing);
      },
    );
  });

  testWidgets('co05_09/us02/fr01/e03: a committed predictive back gesture '
      'closes the dialog alone and a cancelled one leaves it open, three pages '
      'deep', (tester) async {
    Future<void> openThreePagesDeep() async {
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      for (final label in const ['Second', 'Third']) {
        navigator
            .push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: Center(child: Text(label))),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
      }
      checker.answer(UpdateStatus.available);
      await dialogFrames(tester);
      expect(find.text('Available'), findsOneWidget);
    }

    await openThreePagesDeep();
    await backGesture(tester, 'startBackGesture');
    await backGesture(tester, 'updateBackGestureProgress', progress: 0.6);
    await tester.pump();
    expect(find.text('Available'), findsOneWidget);
    await backGesture(tester, 'commitBackGesture');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsNothing);
    expect(find.text('Third'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await openThreePagesDeep();
    await backGesture(tester, 'startBackGesture');
    await backGesture(tester, 'updateBackGestureProgress', progress: 0.6);
    await backGesture(tester, 'cancelBackGesture');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
  });
}

/// A router delegate with two fixed pages, "Home" under "Second", whose
/// navigator takes the Android back button through the router.
class _TwoPages extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: const [
      MaterialPage<void>(
        child: Scaffold(body: Center(child: Text('Home'))),
      ),
      MaterialPage<void>(
        child: Scaffold(body: Center(child: Text('Second'))),
      ),
    ],
    onDidRemovePage: (_) {},
  );

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
