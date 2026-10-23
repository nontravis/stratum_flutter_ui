// Proves FO-07 US-04 FR-02 E02 (Scenario 2) on Android and iOS: the
// platform's own keyboard service really reports the on-screen keyboard
// (`tester.showKeyboard`, never `setVisibleForTesting`), and a dependent that
// reads only `KeyboardVisibilityScope` rebuilds exactly once for each open and
// each close. The test self-selects by the real host OS
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
//   flutter test integration_test/common/keyboard_visibility_scope_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/app_lifecycle.dart';
import 'support/host_platform.dart';
import 'support/pump_until.dart';

/// How long [_proveE02] waits for the OS keyboard to settle open, then
/// closed: one bound for both waits, so a slow IME fails naming the OS
/// keyboard, never the scope (edges review Minor #4).
const _keyboardSettleTimeout = Duration(seconds: 10);

/// How long [_proveE02] waits for the scope's matching build once the OS
/// inset itself has already arrived or cleared (fix-5 item 2.3): short,
/// because this bound measures the scope reacting to an inset Flutter
/// already delivered, never fresh IME latency, which `_keyboardSettleTimeout`
/// covers instead.
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
    timeout: _warmUpTimeout,
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
    timeout: _warmUpTimeout,
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
/// s03 invariant 10): every other host reads the keyboard closed without
/// asking it.
///
/// Reads [hostOSName], the real host OS, never `defaultTargetPlatform`:
/// every `flutter test` process sets `FLUTTER_TEST`, which forces
/// `defaultTargetPlatform` to `TargetPlatform.android` on `mac`, `linux`,
/// and `-d flutter-tester` alike, regardless of the real host (correctness
/// review Critical, edges review Minor #3).
bool get _isAndroidOrIOS => hostOSName == 'android' || hostOSName == 'ios';

/// E02, US-04 Scenario 2: a real on-screen keyboard opens once and closes
/// once, and a dependent that reads only the scope rebuilds exactly once for
/// each.
///
/// Anchors each half on the OS event rather than the scope (fix-5 item 2,
/// `rca-kv-dr14b.findings.md` Part 2 Fix option A): a timeout waiting for
/// `viewInsets.bottom` fails naming the OS keyboard, never the scope, so a
/// slow IME is never blamed on this package; only once that inset has
/// arrived does the scope get a short bound of its own to react.
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

  final showRequestedAt = DateTime.now();
  _keyboardRequestedAt = showRequestedAt;
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
  }, timeout: _keyboardSettleTimeout);
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
    timeout: _scopeAfterOsEventBound,
  );
  expect(
    opened,
    isTrue,
    reason:
        'the scope did not read open within '
        '${_scopeAfterOsEventBound.inSeconds}s of the OS inset arriving',
  );
  expect(
    builds.length - beforeOpen,
    1,
    reason:
        'the scope notifies a dependent once per open, never once per '
        'animation frame (s03 invariant 7, US-04 Scenario 2)',
  );

  final beforeClose = builds.length;
  final closeRequestedAt = DateTime.now();
  _keyboardRequestedAt = closeRequestedAt;
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
  }, timeout: _keyboardSettleTimeout);
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
    timeout: _scopeAfterOsEventBound,
  );
  expect(
    closed,
    isTrue,
    reason:
        'the scope did not read closed within '
        '${_scopeAfterOsEventBound.inSeconds}s of the OS inset clearing',
  );
  expect(
    builds.length - beforeClose,
    1,
    reason: 'closing the keyboard notifies the dependent exactly once more',
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
