// Proves StratumUpdateGate's queued device cases in code on every target
// (CO-05-09 US-01, US-02; design `2026-10-10-common-widgets-b-design.md`
// D3 and its accessibility block, `:154-190`): Android back and a
// predictive back gesture close the available dialog alone, leaving the
// app on the page it showed however deep in its routes; each full screen
// and the dialog open a route scope, with the routes behind the dialog
// excluded from semantics while it shows; Esc dismisses the dialog and
// Tab stays inside it. The test builds its own app from the public gate
// API. One check code cannot judge: whether TalkBack and VoiceOver actually
// speak the route-scope change out loud (stratum-device-round A1, A2, B1);
// a person hears it on check 6 of the screen reader checks page,
// `lib/screen_reader_demo.dart` (F-01 US-13). Runs in roadmap phase
// stratum-device-round, never in a feature session:
//
//   flutter test integration_test/update_gate_device_test.dart -d <device>
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/key_simulation.dart';

/// An update check whose one ask the test answers by hand.
class _Checker implements UpdateChecker {
  final List<Completer<UpdateStatus>> _asks = [];

  @override
  Future<UpdateStatus> check() {
    final ask = Completer<UpdateStatus>();
    _asks.add(ask);
    return ask.future;
  }

  /// Answers the latest ask with [status].
  void answer(UpdateStatus status) => _asks.last.complete(status);
}

/// The app's own screens and dialog, named so a test can find and drive
/// them: required and maintenance share the same route-scope wrapper in
/// `StratumUpdateGate`, so proving it once on required covers both.
Widget _screens(BuildContext context, UpdateGateState gate) => switch (gate) {
  UpdateGateRequired() => const Material(
    child: Center(child: Text('Required')),
  ),
  UpdateGateMaintenance(:final retry) => Material(
    child: Center(
      child: TextButton(onPressed: retry, child: const Text('Retry')),
    ),
  ),
  UpdateGateAvailable(:final dismiss) => Align(
    alignment: Alignment.topCenter,
    child: Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: dismiss, child: const Text('Later')),
          TextButton(onPressed: () {}, child: const Text('Update')),
        ],
      ),
    ),
  ),
};

/// A [MaterialApp] whose builder wraps the gate around its navigator; its
/// first page shows "Home" and a "Behind" button a tap behind the dialog
/// must never reach.
Widget _app(_Checker checker) => MaterialApp(
  builder: (context, child) =>
      StratumUpdateGate(checker: checker, builder: _screens, child: child!),
  home: Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Home'),
          TextButton(onPressed: () {}, child: const Text('Behind')),
        ],
      ),
    ),
  ),
);

/// Pushes a page named [label] on top of the page named [from].
Future<void> _push(WidgetTester tester, String from, String label) async {
  Navigator.of(tester.element(find.text(from))).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Center(child: Text(label))),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lets an answer open the dialog: the answer's own frame shows the app,
/// and the route the gate pushes after that frame builds in the next one.
Future<void> _dialogFrames(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  await tester.pump();
}

/// Opens the available dialog three pages deep, as A1 and the design's
/// R5 scenario describe ("however deep in the app's routes").
Future<void> _availableThreePagesDeep(
  WidgetTester tester,
  _Checker checker,
) async {
  await tester.pumpWidget(_app(checker));
  await _push(tester, 'Home', 'Second');
  await _push(tester, 'Second', 'Third');
  checker.answer(UpdateStatus.available);
  await _dialogFrames(tester);
}

/// Delivers one predictive-back [method] over `flutter/backgesture`, the
/// channel Android's predictive back drives (`WidgetsBinding._handleBack
/// GestureInvocation`). `startBackGesture` and `updateBackGestureProgress`
/// carry a touch point and [progress]; `commitBackGesture` and
/// `cancelBackGesture` carry nothing.
Future<void> _backGesture(
  WidgetTester tester,
  String method, {
  double progress = 0.0,
}) {
  final needsArgs =
      method == 'startBackGesture' || method == 'updateBackGestureProgress';
  final call = MethodCall(
    method,
    needsArgs
        ? <String, Object?>{
            'touchOffset': const <double>[5.0, 200.0],
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

/// The route scope `StratumUpdateGate` puts around a built screen or
/// dialog (D3; `_GateScope`, `update_gate.dart:253-258`): the framework
/// gives the dialog's own scope through `RawDialogRoute.buildPage`.
Finder _scopeOf(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && (widget.properties.scopesRoute ?? false),
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'co05_09/us02/fr01/e03, NFR-U02: Android back closes the available '
    "dialog alone and the app stays on the page it showed, however deep "
    'in its routes (A1)',
    (tester) async {
      await _availableThreePagesDeep(tester, _Checker());
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Update'), findsNothing);
      expect(find.text('Third'), findsOneWidget);
    },
  );

  testWidgets(
    'NFR-U02: a committed predictive back gesture closes the available '
    'dialog alone and the app stays on the page it showed, however deep '
    'in its routes (A1)',
    (tester) async {
      await _availableThreePagesDeep(tester, _Checker());
      expect(find.text('Update'), findsOneWidget);

      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', progress: 0.6);
      await tester.pump();
      expect(find.text('Update'), findsOneWidget);

      await _backGesture(tester, 'commitBackGesture');
      await tester.pump();

      expect(find.text('Update'), findsNothing);
      expect(find.text('Third'), findsOneWidget);
    },
  );

  testWidgets(
    'NFR-U02: a cancelled predictive back gesture leaves the available '
    'dialog open and the app on the page it showed (A1)',
    (tester) async {
      await _availableThreePagesDeep(tester, _Checker());
      expect(find.text('Update'), findsOneWidget);

      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', progress: 0.6);
      await _backGesture(tester, 'cancelBackGesture');
      await tester.pump();

      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    },
  );

  testWidgets(
    'NFR-U06: a full screen opens a route scope a screen reader announces '
    '(A2, B1)',
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

      handle.dispose();
    },
  );

  testWidgets(
    'NFR-U06: the available dialog opens a route scope, and the routes '
    'behind it leave semantics while it shows (A2, B1)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final checker = _Checker();
      await tester.pumpWidget(_app(checker));
      expect(find.semantics.byLabel('Home'), findsOne);

      checker.answer(UpdateStatus.available);
      await _dialogFrames(tester);

      expect(find.semantics.byLabel('Home'), findsNothing);
      expect(find.semantics.byLabel('Behind'), findsNothing);
      expect(_scopeOf('Update'), findsOneWidget);
      expect(
        tester.getSemantics(_scopeOf('Update')),
        isSemantics(scopesRoute: true),
      );

      handle.dispose();
    },
  );

  testWidgets('NFR-U02: Esc dismisses the available dialog on desktop', (
    tester,
  ) async {
    final checker = _Checker();
    await tester.pumpWidget(_app(checker));
    checker.answer(UpdateStatus.available);
    await _dialogFrames(tester);
    expect(find.text('Update'), findsOneWidget);

    await sendKey(tester, LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('Update'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('NFR-U02: Tab stays inside the dialog and never reaches the app '
      'behind it', (tester) async {
    final checker = _Checker();
    await tester.pumpWidget(_app(checker));
    checker.answer(UpdateStatus.available);
    await _dialogFrames(tester);

    bool focused(String label) =>
        Focus.of(tester.element(find.text(label))).hasFocus;

    for (final label in ['Later', 'Update', 'Later', 'Update']) {
      await sendKey(tester, LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focused(label), isTrue);
    }
  });
}
