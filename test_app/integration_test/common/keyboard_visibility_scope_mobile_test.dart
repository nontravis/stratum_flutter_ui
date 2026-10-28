// Proves FO-07 US-04 FR-02 E02 (Scenario 2) on Android and iOS: the
// platform's own keyboard service really reports the on-screen keyboard
// (`tester.showKeyboard`, never `setVisibleForTesting`), and a dependent that
// reads only `KeyboardVisibilityScope` rebuilds once for each change the OS
// reports through the plugin the scope reads, never once per frame. The test
// self-selects by the real host OS
// (`support/host_platform.dart`'s `hostOSName`, never `defaultTargetPlatform`,
// which every `flutter test` process forces to `TargetPlatform.android`) and
// reports a skip on every other host, where E05 is a widget test
// (`test/src/components/common/responsive/keyboard_visibility_host_gate_test.dart`).
//
// The Android cases that need a host action or a person are e2e legs of the
// same story: E04 (a stylus-handwriting toolbar), the two hardware-keyboard
// states, and the attended rows. This file runs on an Android device with no
// hardware keyboard attached; Gboard shows its full keyboard there.
//
// Before the first measurement the test warms the OS keyboard open and closed
// once, unmeasured (DR15, owner ruling 2026-10-18): the first IME show after a
// cold boot can take well past the measured 10 s bound for reasons of the
// environment, never this package.
//
//   flutter test integration_test/common/keyboard_visibility_scope_mobile_test.dart -d <device>
import 'dart:async';

// The scope reads this plugin; the test counts the plugin's own events to prove
// the scope follows them.
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/app_lifecycle.dart';
import 'support/host_platform.dart';
import 'support/keyboard_settle.dart';
import 'support/pump_until.dart';

/// How long one half of E02 bounds the OS keyboard from its request: the
/// inset wait and the settle loop share it, so a slow IME fails naming the OS
/// keyboard, never the scope (edges review Minor #4).
const _keyboardSettleTimeout = Duration(seconds: 10);

/// How long [_proveE02] waits for the scope's matching build once the OS
/// inset itself has already arrived or cleared (fix-5 item 2.3): short,
/// because this bound measures the scope reacting to an inset Flutter
/// already delivered, never fresh IME latency, which `_keyboardSettleTimeout`
/// covers instead. The settle loop's own per-pass bound is
/// `support/keyboard_settle.dart`'s [scopeAfterOsEventBound].
const _scopeAfterOsEventBound = Duration(seconds: 2);

/// How long [_warmUpKeyboard] waits for the OS keyboard to open or close
/// once (fix-6 item 1, DR15): the first IME show after a cold boot can take
/// well past [_keyboardSettleTimeout] for reasons env, never this package
/// (14.2s on pixel_8; stalled under post-boot GMS autofill work on
/// pixel_2), so this unmeasured round gets its own, longer bound.
const _warmUpTimeout = Duration(seconds: 30);

/// Diagnostic only (fix-5 item 3): the moment an open or close was
/// requested, so [_KeyboardFlagReader] can print the ms since it on every
/// build. `null` outside a wait a caller instrumented; a run with no stall
/// prints nothing extra.
DateTime? _keyboardRequestedAt;

/// Reads [KeyboardVisibilityScope] and reports every value it saw to
/// [onBuild], so a test can prove a dependent rebuilds only on open or close
/// (US-04 FR-02 E02, Scenario 2) without the widget reading anything else
/// that could rebuild it for an unrelated reason.
///
/// Also prints one `KV-DIAG` line per build, with the value and the ms
/// since [_keyboardRequestedAt], whenever a caller has set it (fix-5 item 3,
/// `rca-kv-dr14b.findings.md` lines 165-168): a grep target for the next
/// run's build-timing evidence.
class _KeyboardFlagReader extends StatelessWidget {
  const _KeyboardFlagReader({required this.onBuild});

  final ValueChanged<bool> onBuild;

  @override
  Widget build(BuildContext context) {
    final value = KeyboardVisibilityScope.of(context);
    final requestedAt = _keyboardRequestedAt;
    if (requestedAt != null) {
      debugPrint(
        'KV-DIAG build=$value ms=${DateTime.now().difference(requestedAt).inMilliseconds}',
      );
    }
    onBuild(value);
    return const SizedBox.shrink();
  }
}

final Key _fieldKey = UniqueKey();

/// Every real-keyboard request in this file goes through here instead of a
/// bare `tester.showKeyboard` (fix-7, DR16): `focusedEditable`'s setter
/// calls `requestKeyboard()` only when the value changes
/// (`flutter_test/lib/src/binding.dart:1608-1613`), so a second
/// `showKeyboard` on the same field after an `unfocus()` — which never
/// clears `focusedEditable` — sends no show request at all. Clearing it
/// first makes every call here a fresh request, whatever ran before.
Future<void> _requestShowKeyboard(WidgetTester tester) async {
  tester.binding.focusedEditable = null;
  await tester.showKeyboard(find.byKey(_fieldKey));
}

/// A focusable field plus a [_KeyboardFlagReader] over [controller]'s theme,
/// which inserts the `KeyboardVisibilityScope` this file reads.
Widget _app(StratumThemeController controller, ValueChanged<bool> onBuild) =>
    MaterialApp(
      builder: (context, child) => StratumThemeApplication.controlled(
        controller: controller,
        themeMode: ThemeMode.light,
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              TextField(key: _fieldKey),
              _KeyboardFlagReader(onBuild: onBuild),
            ],
          ),
        ),
      ),
    );

Future<StratumThemeController> _controller() async {
  final controller = await StratumThemeController.preload();
  return controller;
}

/// Pumps [_app] over a fresh [StratumThemeController], settles, and returns
/// the `builds` list its [_KeyboardFlagReader] appends to; shared by every
/// `testWidgets` body in this file.
///
/// On Android and iOS, waits for the window to gain input focus
/// ([waitForResumed]) before returning, so every case's first keyboard
/// action runs after that precondition, never before it (RCA
/// `rca-kv-pixel8.findings.md` revision 2).
Future<List<bool>> _pumpApp(WidgetTester tester) async {
  final controller = await _controller();
  addTearDown(controller.dispose);
  final builds = <bool>[];
  await tester.pumpWidget(_app(controller, builds.add));
  await tester.pumpAndSettle();
  if (_isAndroidOrIOS) {
    await waitForResumed(tester);
  }
  return builds;
}

/// Opens and closes the real OS keyboard once, unmeasured, before the first
/// real-keyboard case in a test (fix-6 item 1, DR15): absorbs the
/// cold-boot first-show latency env owns, so the measured E02 open/close
/// never pays for it.
///
/// Asserts nothing else about [KeyboardVisibilityScope] and leaves no
/// rebuild behind: truncates [builds] back to its length from before this
/// ran, so a caller's own `beforeOpen`/`builds.last` bookkeeping sees the
/// state as if this never happened.
Future<void> _warmUpKeyboard(WidgetTester tester, List<bool> builds) async {
  final beforeWarmUp = builds.length;

  final openRequestedAt = DateTime.now();
  await _requestShowKeyboard(tester);
  final opened = await pumpUntil(
    tester,
    () => tester.view.viewInsets.bottom > 0,
    budget: _warmUpTimeout,
  );
  debugPrint(
    'KV-DIAG warm-up open ms='
    '${DateTime.now().difference(openRequestedAt).inMilliseconds}',
  );

  expect(
    opened,
    isTrue,
    reason:
        'warm-up: the OS keyboard never opened within '
        '${_warmUpTimeout.inSeconds}s (env)',
  );

  final closeRequestedAt = DateTime.now();
  FocusManager.instance.primaryFocus?.unfocus();
  final closed = await pumpUntil(
    tester,
    () => tester.view.viewInsets.bottom == 0,
    budget: _warmUpTimeout,
  );
  debugPrint(
    'KV-DIAG warm-up close ms='
    '${DateTime.now().difference(closeRequestedAt).inMilliseconds}',
  );
  expect(
    closed,
    isTrue,
    reason:
        'warm-up: the OS keyboard never closed within '
        '${_warmUpTimeout.inSeconds}s (env)',
  );

  builds.removeRange(beforeWarmUp, builds.length);
}

/// Whether this host is the one the OS flag covers at all (US-04 FR-02 E05,
/// s03 INV-10): every other host reads the keyboard closed without
/// asking it.
///
/// Reads [hostOSName], the real host OS, never `defaultTargetPlatform`:
/// every `flutter test` process sets `FLUTTER_TEST`, which forces
/// `defaultTargetPlatform` to `TargetPlatform.android` on `mac`, `linux`,
/// and `-d flutter-tester` alike, regardless of the real host (correctness
/// review Critical, edges review Minor #3).
bool get _isAndroidOrIOS => hostOSName == 'android' || hostOSName == 'ios';

/// Records every value the plugin reports through
/// `KeyboardVisibilityController().onChange` into [events], and prints one
/// `KV-OS` line per event with the value and the ms since
/// [_keyboardRequestedAt], so a device log maps each build to the OS event
/// behind it.
///
/// This is the stream [KeyboardVisibilityScope] reads, so [events] is the
/// OS's own count of changes, whatever frames land between them.
StreamSubscription<bool> _listenToOsEvents(List<bool> events) {
  return KeyboardVisibilityController().onChange.listen((value) {
    events.add(value);
    final requestedAt = _keyboardRequestedAt;
    final ms = requestedAt == null
        ? 'n/a'
        : '${DateTime.now().difference(requestedAt).inMilliseconds}';
    debugPrint('KV-OS event=$value ms=$ms');
  });
}

/// Whether every value in [window] differs from the one before it, the first
/// compared with [before].
bool _everyBuildFlips(bool before, List<bool> window) {
  var previous = before;
  for (final value in window) {
    if (value == previous) return false;
    previous = value;
  }
  return true;
}

// Each half settles through `support/keyboard_settle.dart`'s
// `settleKeyboardScope` (host proof: `test/integration_support/
// keyboard_settle_test.dart`), so an interim OS report never ends it.

/// Asserts the scope followed the OS's own reports across one half (open or
/// close) of E02: [window] holds the builds of that half, [osEvents] the
/// plugin events of the same half, [before] the value the scope read when the
/// half began, and [expectedLast] the value the half ends on.
///
/// The OS can report a flip (shown, hidden, shown) inside one request, and
/// the scope publishes each one (s03 INV-10), so the count to hold is the
/// plugin's, never a fixed one.
void _expectScopeFollowedOs({
  required String half,
  required bool before,
  required bool expectedLast,
  required List<bool> window,
  required List<bool> osEvents,
}) {
  expect(
    window,
    isNotEmpty,
    reason:
        '$half: the scope never rebuilt the dependent after the OS reported '
        'the change (s03 INV-10, US-04 Scenario 2)',
  );
  expect(
    window.length,
    lessThanOrEqualTo(osEvents.length),
    reason:
        '$half: ${window.length} builds for ${osEvents.length} OS reports; '
        'the scope follows each change the OS reports, never each frame '
        '(s03 INV-7 and INV-10, US-04 Scenario 2)',
  );
  expect(
    osEvents.last,
    expectedLast,
    reason:
        '$half: the OS ended on ${osEvents.last ? 'open' : 'closed'}, not '
        '${expectedLast ? 'open' : 'closed'} (s03 INV-10, US-04 Scenario 2)',
  );
  expect(
    _everyBuildFlips(before, window),
    isTrue,
    reason:
        '$half: builds $window after $before; each build must flip the '
        'value from the one before it, or the scope published a repeat '
        '(s03 INV-7, US-04 Scenario 2)',
  );
  expect(
    window.last,
    osEvents.last,
    reason:
        '$half: the last build must read what the OS last reported, '
        '${osEvents.last ? 'open' : 'closed'} (s03 INV-10, US-04 Scenario 2)',
  );
  expect(
    window.last,
    expectedLast,
    reason:
        '$half: the last build must read ${expectedLast ? 'open' : 'closed'} '
        '(s03 INV-10, US-04 Scenario 2)',
  );
}

/// E02, US-04 Scenario 2: a real on-screen keyboard opens and closes, and a
/// dependent that reads only the scope rebuilds once per change the OS
/// reports through the plugin, never once per frame (s03 INV-10).
///
/// Anchors each half on the OS event rather than the scope (fix-5 item 2,
/// `rca-kv-dr14b.findings.md` Part 2 Fix option A): a timeout waiting for
/// `viewInsets.bottom` fails naming the OS keyboard, never the scope, so a
/// slow IME is never blamed on this package; only once that inset has
/// arrived does the scope get a short bound of its own to react.
///
/// Counts the scope's builds against the plugin's own events for the same
/// window (task 53): Android can report shown, hidden, shown inside one
/// open, and the scope publishes each report.
Future<void> _proveE02(WidgetTester tester, List<bool> builds) async {
  debugPrint('fo07/us04/fr02/e02, s2: platform=$hostOSName');
  final beforeOpen = builds.length;
  expect(
    builds.last,
    isFalse,
    reason:
        'the scope must already read closed before this case requests the '
        'show, or an earlier open went unnoticed (fix-5 item 2.1, P2)',
  );

  final osEvents = <bool>[];
  final osSubscription = _listenToOsEvents(osEvents);
  addTearDown(osSubscription.cancel);

  final showRequestedAt = DateTime.now();
  _keyboardRequestedAt = showRequestedAt;
  final showRequestStopwatch = Stopwatch()..start();
  await _requestShowKeyboard(tester);

  var insetOpenLogged = false;
  final insetOpened = await pumpUntil(tester, () {
    final hasInset = tester.view.viewInsets.bottom > 0;
    if (hasInset && !insetOpenLogged) {
      insetOpenLogged = true;
      debugPrint(
        'KV-DIAG inset>0 ms='
        '${DateTime.now().difference(showRequestedAt).inMilliseconds}',
      );
    }
    return hasInset;
  }, budget: _keyboardSettleTimeout);
  expect(
    insetOpened,
    isTrue,
    reason:
        'the OS keyboard did not open within '
        '${_keyboardSettleTimeout.inSeconds}s',
  );

  final opened = await pumpUntil(
    tester,
    () => builds.length > beforeOpen && builds.last,
    budget: _scopeAfterOsEventBound,
  );
  expect(
    opened,
    isTrue,
    reason:
        'the scope did not read open within '
        '${_scopeAfterOsEventBound.inSeconds}s of the OS inset arriving',
  );
  await settleKeyboardScope(
    tester,
    builds,
    osEvents,
    expected: true,
    stopwatch: showRequestStopwatch,
    budget: _keyboardSettleTimeout,
  );
  final beforeClose = builds.length;
  final osEventsBeforeClose = osEvents.length;
  _expectScopeFollowedOs(
    half: 'open',
    before: false,
    expectedLast: true,
    window: builds.sublist(beforeOpen),
    osEvents: osEvents.sublist(0, osEventsBeforeClose),
  );

  final closeRequestedAt = DateTime.now();
  _keyboardRequestedAt = closeRequestedAt;
  final closeRequestStopwatch = Stopwatch()..start();
  FocusManager.instance.primaryFocus?.unfocus();

  var insetClosedLogged = false;
  final insetClosed = await pumpUntil(tester, () {
    final noInset = tester.view.viewInsets.bottom == 0;
    if (noInset && !insetClosedLogged) {
      insetClosedLogged = true;
      debugPrint(
        'KV-DIAG inset==0 ms='
        '${DateTime.now().difference(closeRequestedAt).inMilliseconds}',
      );
    }
    return noInset;
  }, budget: _keyboardSettleTimeout);
  expect(
    insetClosed,
    isTrue,
    reason:
        'the OS keyboard did not close within '
        '${_keyboardSettleTimeout.inSeconds}s',
  );

  final closed = await pumpUntil(
    tester,
    () => builds.length > beforeClose && !builds.last,
    budget: _scopeAfterOsEventBound,
  );
  expect(
    closed,
    isTrue,
    reason:
        'the scope did not read closed within '
        '${_scopeAfterOsEventBound.inSeconds}s of the OS inset clearing',
  );
  await settleKeyboardScope(
    tester,
    builds,
    osEvents,
    expected: false,
    stopwatch: closeRequestStopwatch,
    budget: _keyboardSettleTimeout,
  );
  _expectScopeFollowedOs(
    half: 'close',
    before: true,
    expectedLast: false,
    window: builds.sublist(beforeClose),
    osEvents: osEvents.sublist(osEventsBeforeClose),
  );
  expect(
    builds.length - beforeOpen,
    lessThanOrEqualTo(osEvents.length),
    reason:
        'across the open and the close, ${builds.length - beforeOpen} builds '
        'for ${osEvents.length} OS reports (s03 INV-7 and INV-10, US-04 '
        'Scenario 2)',
  );
  _keyboardRequestedAt = null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Eager install (support/app_lifecycle.dart's own doc): seeds the
  // process-wide lifecycle record before this file's first test can hit
  // flutter_test's per-test reset.
  installLifecycleObserver();

  testWidgets(
    'fo07/us04/fr02/e02, fo07/us04/s2: the keyboard-visibility scope reads '
    'the real on-screen keyboard open once and closed once',
    (tester) async {
      final builds = await _pumpApp(tester);
      expect(builds, isNotEmpty, reason: 'the reader never built at all');

      await _warmUpKeyboard(tester, builds);
      await _proveE02(tester, builds);
    },
    skip: !_isAndroidOrIOS,
  );
}
