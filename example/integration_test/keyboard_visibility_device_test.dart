// Proves the keyboard-visibility device cases (US-04 FR-02) code can reach,
// self-selecting the one or two cases each target can show by the real host
// OS (`support/host_platform.dart`'s `hostOSName`, never
// `defaultTargetPlatform`, which every `flutter test` process forces to
// `TargetPlatform.android` regardless of the real host) rather than keying
// off a device name:
// `docs/prds/features/foundation/fo07_responsive/us04_window_metrics/functional_requirements/fr02_publish_keyboard_visibility.md`.
//
// - web, macOS, Linux, and Windows: E05 — a host that is neither Android nor
//   iOS never asks the OS, so the scope reads the keyboard closed with no
//   `MissingPluginException` from the host-gated platform channel (s03
//   invariant 10).
// - Android with a hardware keyboard attached: this file proves two states
//   — the device's own `show_ime_with_hard_keyboard` setting, then the
//   flipped one (`hostAction`), flipped back after — judging each by the
//   real `viewInsets.bottom`, never the setting (owner ruling 2026-10-18,
//   DR18 `pixel_2` API 28: Gboard showed its full keyboard, inset 746px,
//   even with the setting off, and the scope's `true` was correct; the
//   setting is logged only). A state whose inset rises proves E02
//   semantics; a state whose inset stays 0 for the whole bound proves E07.
//   When neither state ever does, this file says E07 is not reachable on
//   this device, which is not a failure (DR18); a human can still confirm
//   E07 through the attended case below.
// - Android with no hardware keyboard attached: E02, US-04 Scenario 2 — a
//   real on-screen keyboard (`tester.showKeyboard`, never
//   `setVisibleForTesting`) opens once and closes once, and a dependent
//   that reads only the scope rebuilds exactly once for each; then E04, D4
//   — a host action (`support/host_action.dart`) turns on the Gboard
//   stylus-handwriting toolbar and taps the field, and the scope reads open
//   while `DeviceWindow.keyboardHeight` reads 0.
// - iOS: E02 as above (iOS carries no stylus toolbar to gate it on). Owner
//   ruling 2026-10-18: iOS E07 is attended rather than automated (below),
//   since nothing in this file can trust `GCKeyboard.coalesced` enough to
//   assert pass or fail from it alone.
//
// E06 (Android) and E07 (iOS) are attended, not automated: each is its own
// `testWidgets`, `skip:` unless `--attended` set `DT_ATTENDED`, registered
// before any body runs. A skip from inside a running test (`attend`'s own
// fallback, or the `markTestSkipped` pattern elsewhere in this directory)
// overrides that same test's earlier assertions in the report, which is why
// the attended cases never share a test with the automated ones above.
//
// On Android and iOS, every case waits for the app window to gain input
// focus (`support/app_lifecycle.dart`'s `waitForResumed`) before its first
// keyboard action: a show sent before that is silently dropped and never
// resent (RCA `rca-kv-pixel8.findings.md` revision 2), which also made
// E07's and E06's "stays closed" checks meaningless for a run that hit it.
//
// When E02's open wait times out, this file calls `probe('e02_open_timeout')`
// before failing, so the device-round skill captures a screenshot and
// `dumpsys window` for the failure (whether the IME window is up at all).
//
// Before the first real-keyboard measurement in a test that has one (the
// E02 branch, which always precedes E04 in the same test where both run),
// this file warms the OS keyboard open and closed once, unmeasured (DR15,
// owner ruling 2026-10-18): the first IME show after a cold boot can take
// well past the measured 10s bound for reasons env, never this package, so
// that cost is paid once, outside any assertion. Skipped wherever no real
// soft keyboard opens at all (the E07 stays-closed checks, web and desktop
// hosts).
//
// Code cannot judge without a human's attended confirmation:
// - Android's floating or split keyboard mode (E06) and a hardware keyboard
//   connected to the iOS simulator (E07): no in-process seam triggers
//   either from a script.
//
//   flutter test integration_test/keyboard_visibility_device_test.dart -d <device>
//   flutter test integration_test/keyboard_visibility_device_test.dart \
//     -d <device> --dart-define=DT_ATTENDED=true
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/app_lifecycle.dart';
import 'support/hardware_keyboard.dart';
import 'support/host_action.dart';
import 'support/host_platform.dart';
import 'support/probe.dart';
import 'support/pump_until.dart';

/// How long a case waits for the keyboard to settle open, closed, or
/// still closed: the same bound every case shares, so E07's stays-closed
/// wait cannot pass by giving up before a slow IME would have opened it,
/// the way E02's own open wait trusts (edges review Minor #4).
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
/// and the E04 tap never pay for it. A caller whose test never opens a
/// real soft keyboard (the E07 stays-closed checks, web, and desktop
/// hosts) never calls this: there [_warmUpTimeout] would have nothing to
/// wait for.
///
/// [hasHardwareKeyboard] (fix-10, owner ruling 2026-10-18): this only warms
/// a soft keyboard that was going to show anyway, so on a device with a
/// hardware keyboard attached the OS hiding the soft keyboard entirely —
/// the inset staying 0 for the whole bound — is a valid outcome, logged as
/// `KV-DIAG warm-up: soft keyboard hidden (hardware keyboard)`, never a
/// failure. It still fails as env when no hardware keyboard is attached
/// and no inset ever arrives.
///
/// Asserts nothing else about [KeyboardVisibilityScope] and leaves no
/// rebuild behind: truncates [builds] back to its length from before this
/// ran, so a caller's own `beforeOpen`/`builds.last` bookkeeping sees the
/// state as if this never happened.
Future<void> _warmUpKeyboard(
  WidgetTester tester,
  List<bool> builds, {
  required bool hasHardwareKeyboard,
}) async {
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

  if (!opened && hasHardwareKeyboard) {
    debugPrint('KV-DIAG warm-up: soft keyboard hidden (hardware keyboard)');
    FocusManager.instance.primaryFocus?.unfocus();
    builds.removeRange(beforeWarmUp, builds.length);
    return;
  }
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

/// E05: a host that is neither Android nor iOS reads the keyboard closed
/// with no fallback to the OS or the inset, and no `MissingPluginException`
/// escapes the host-gated platform channel.
Future<void> _proveE05(WidgetTester tester, List<bool> builds) async {
  debugPrint('fo07/us04/fr02/e05: platform=$hostOSName');
  await _requestShowKeyboard(tester);
  await tester.pumpAndSettle();

  expect(
    builds.last,
    isFalse,
    reason:
        'a host that is neither Android nor iOS reads the keyboard closed '
        'with no fallback to the OS or the inset (s03 invariant 10)',
  );
  expect(
    tester.takeException(),
    isNull,
    reason:
        'no MissingPluginException from the host-gated platform channel '
        '(s03 invariant 10 WORKAROUND)',
  );
}

/// Focuses the field, settles for [_keyboardSettleTimeout], then asserts
/// the scope never read open: shared by every attended check (E06, Android
/// E07, iOS E07) a human confirms first.
///
/// Unfocuses the field before returning, so a caller that runs another
/// keyboard case right after always starts that case's `showKeyboard` from
/// a fresh focus transition, never a no-op on a field that was already
/// focused.
Future<void> _assertStaysClosed(WidgetTester tester, List<bool> builds) async {
  await _requestShowKeyboard(tester);
  await pumpUntil(tester, () => false, timeout: _keyboardSettleTimeout);

  expect(
    builds.contains(true),
    isFalse,
    reason:
        'this case reads the scope closed even while the field holds '
        'focus (s03 invariant 10)',
  );
  FocusManager.instance.primaryFocus?.unfocus();
}

/// Requests the keyboard once for this state, then judges the result by
/// `viewInsets.bottom`, never the `show_ime_with_hard_keyboard` setting
/// (fix-9, owner ruling 2026-10-18, DR18: Gboard showed its full keyboard,
/// inset 746px, even with the setting off on `pixel_2` API 28, and the
/// scope's `true` was correct — the setting was never the oracle).
/// [loggedSetting] is printed through one `KV-DIAG` line only.
///
/// A state whose inset rises above 0 within [_keyboardSettleTimeout] proves
/// E02 semantics: the scope reads open with exactly one build, then closes
/// the same way. A state whose inset stays 0 for the whole bound proves
/// E07: the scope stays false, with a `KV-DIAG` line (throttled to one per
/// 500ms) of `viewInsets.bottom` and `physicalSize` while the wait runs,
/// and `probe('e07_open')` before a failing check reports — the evidence
/// fix-8 added for this path, now unconditional here since this function
/// only ever runs the real inset-judged check (fix-8's per-call
/// `logDiagnostics` plumbing is gone with the setting-based dispatch it
/// served).
///
/// Returns `true` when this state proved E07, so [_proveHardwareKeyboardBoth]
/// can tell whether any state on the device ever did (fix-9 item 2).
Future<bool> _proveHardwareKeyboardState(
  WidgetTester tester,
  List<bool> builds,
  bool loggedSetting,
) async {
  debugPrint(
    'KV-DIAG hwkbd show_ime_with_hard_keyboard=$loggedSetting '
    '(logged only, never the oracle)',
  );

  final beforeOpen = builds.length;
  await _requestShowKeyboard(tester);

  DateTime? lastLoggedAt;
  final insetShown = await pumpUntil(tester, () {
    final hasInset = tester.view.viewInsets.bottom > 0;
    final now = DateTime.now();
    if (!hasInset &&
        (lastLoggedAt == null ||
            now.difference(lastLoggedAt!) >=
                const Duration(milliseconds: 500))) {
      lastLoggedAt = now;
      debugPrint(
        'KV-DIAG hwkbd viewInsets.bottom=${tester.view.viewInsets.bottom} '
        'physicalSize=${tester.view.physicalSize}',
      );
    }
    return hasInset;
  }, timeout: _keyboardSettleTimeout);

  if (!insetShown) {
    debugPrint('fo07/us04/fr02/e07: platform=$hostOSName');
    final stayedClosed = !builds.sublist(beforeOpen).contains(true);
    if (!stayedClosed) {
      await probe('e07_open');
    }
    expect(
      stayedClosed,
      isTrue,
      reason:
          'this state reads the scope open even though the inset stayed 0 '
          'for the whole ${_keyboardSettleTimeout.inSeconds}s (s03 '
          'invariant 10)',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  debugPrint(
    'fo07/us04/fr02/e02 (hardware keyboard, soft keyboard shown): '
    'platform=$hostOSName',
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
  FocusManager.instance.primaryFocus?.unfocus();
  final insetClosed = await pumpUntil(
    tester,
    () => tester.view.viewInsets.bottom == 0,
    timeout: _keyboardSettleTimeout,
  );
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
  return false;
}

/// Android with a hardware keyboard attached: proves two states — the
/// device's own `show_ime_with_hard_keyboard` setting, then the flipped
/// one, restored with [hostAction] in a `finally` so a later test on the
/// same device never inherits the flip — each judged by
/// [_proveHardwareKeyboardState], never by the setting (fix-9, DR18).
///
/// Prints one line, not a failure, when neither state ever leaves the
/// inset at 0 (fix-9 item 2): on such a device, E07 is not automated at
/// all here, only through the attended case below.
Future<void> _proveHardwareKeyboardBoth(
  WidgetTester tester,
  List<bool> builds,
) async {
  final settingFirst = await showImeWithHardKeyboard();
  final hitE07First = await _proveHardwareKeyboardState(
    tester,
    builds,
    settingFirst,
  );

  await hostAction('hwkbd_flip', 'show_ime_with_hard_keyboard', [
    settingFirst ? 'off' : 'on',
  ]);
  var hitE07Second = false;
  try {
    final settingSecond = await showImeWithHardKeyboard();
    hitE07Second = await _proveHardwareKeyboardState(
      tester,
      builds,
      settingSecond,
    );
  } finally {
    await hostAction('hwkbd_restore', 'show_ime_with_hard_keyboard', [
      settingFirst ? 'on' : 'off',
    ]);
  }

  if (!hitE07First && !hitE07Second) {
    debugPrint(
      'fo07/us04/fr02/e07 not reachable on this device (soft keyboard '
      'shown with a hardware keyboard)',
    );
  }
}

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
  if (!insetOpened) {
    // Carries evidence into the next failure: a screenshot and
    // `dumpsys window` show whether the IME window ever came up (RCA
    // rca-kv-pixel8.findings.md, probable host-pressure starvation).
    await probe('e02_open_timeout');
  }
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

/// The field's centre in global, physical-pixel coordinates (logical centre
/// times `devicePixelRatio`), the form `hostAction`'s `tap` verb takes
/// (host-action contract, host side, item 4).
Offset _fieldCenterPhysical(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byKey(_fieldKey));
  final globalCenter = box.localToGlobal(box.size.center(Offset.zero));
  return globalCenter * tester.view.devicePixelRatio;
}

/// The field's rect in global, physical-pixel coordinates: [_fieldCenterPhysical]'s
/// rect-shaped twin, used to prove the field sits inside the touchable band
/// before a tap reaches it (fix-5 item 1.2).
Rect _fieldRectPhysical(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byKey(_fieldKey));
  final globalTopLeft = box.localToGlobal(Offset.zero);
  final ratio = tester.view.devicePixelRatio;
  return Rect.fromLTWH(
    globalTopLeft.dx * ratio,
    globalTopLeft.dy * ratio,
    box.size.width * ratio,
    box.size.height * ratio,
  );
}

/// Fails naming the field's rect and the view's padding when the field does
/// not sit inside the app's touchable band — below the status bar
/// (`tester.view.padding.top`) and above any bottom inset
/// (`tester.view.padding.bottom`) — so a future layout change fails by name
/// instead of the E04 tap landing on system UI (fix-5 item 1.2,
/// `rca-kv-dr14b.findings.md` Part 1 Fix item 2).
void _assertFieldInTouchableBand(WidgetTester tester) {
  final rect = _fieldRectPhysical(tester);
  final padding = tester.view.padding;
  final bandTop = padding.top;
  final bandBottom = tester.view.physicalSize.height - padding.bottom;
  expect(
    rect.top >= bandTop && rect.bottom <= bandBottom,
    isTrue,
    reason:
        'the field rect $rect must sit inside the touchable band '
        '[$bandTop, $bandBottom] (view padding top=${padding.top}, '
        'bottom=${padding.bottom}), or the E04 tap would land on system UI',
  );
}

/// E04, D4: Android's Gboard stylus-handwriting toolbar reads the scope
/// open while `DeviceWindow.keyboardHeight` reads 0, since the toolbar
/// claims no view inset the way the ordinary soft keyboard does.
///
/// Sets `tester.binding.shouldPropagateDevicePointerEvents` around the tap
/// only, so the kernel touch (`host-action-contract.md` device side item 2)
/// actually reaches the app instead of being dropped as a non-`WidgetController`
/// device pointer event (fix-5 item 1.3); restored, with the toolbar turned
/// off again, in the existing `finally`, even on a failed assertion, so a
/// later test on the same device never inherits either still set.
Future<void> _proveE04(WidgetTester tester, List<bool> builds) async {
  debugPrint('fo07/us04/fr02/e04, d4: platform=$hostOSName');
  _assertFieldInTouchableBand(tester);
  await hostAction('e04_stylus_on', 'stylus_handwriting', const ['on']);
  final propagateBefore = tester.binding.shouldPropagateDevicePointerEvents;
  try {
    final center = _fieldCenterPhysical(tester);
    tester.binding.shouldPropagateDevicePointerEvents = true;
    await hostAction('e04_tap', 'tap', [
      center.dx.round().toString(),
      center.dy.round().toString(),
    ]);
    final shown = await pumpUntil(
      tester,
      () => builds.last,
      timeout: _keyboardSettleTimeout,
    );
    expect(
      shown,
      isTrue,
      reason:
          'the stylus-handwriting toolbar did not report the keyboard '
          'open within 10s',
    );
    expect(
      tester.element(find.byKey(_fieldKey)).deviceWindow.keyboardHeight,
      0,
      reason:
          'the Gboard stylus toolbar claims no view inset, unlike the '
          'ordinary soft keyboard (E04, D4)',
    );
    FocusManager.instance.primaryFocus?.unfocus();
  } finally {
    tester.binding.shouldPropagateDevicePointerEvents = propagateBefore;
    await hostAction('e04_stylus_off', 'stylus_handwriting', const ['off']);
  }
}

/// E06, attended: a human switches Gboard to floating or split mode, which
/// `attend` skips unless `--attended` launched this run; once confirmed the
/// scope stays closed while the field holds focus.
Future<void> _attendE06Android(WidgetTester tester, List<bool> builds) async {
  final confirmed = await attend(
    'e06',
    'switch Gboard to floating mode, then confirm',
  );
  if (!confirmed) return;
  debugPrint('fo07/us04/fr02/e06: platform=$hostOSName');
  await _assertStaysClosed(tester, builds);
}

/// E07, attended on Android: a human connects a physical keyboard so
/// Android hides the on-screen keyboard, which `attend` skips unless
/// `--attended` launched this run; once confirmed the scope stays closed
/// while the field holds focus (fix-9 item 3: `_proveHardwareKeyboardState`
/// only proves E07 automatically on a device whose inset leaves 0 on its
/// own; DR18 found some never do).
Future<void> _attendE07Android(WidgetTester tester, List<bool> builds) async {
  final confirmed = await attend(
    'e07_android',
    'connect a physical keyboard so Android hides the on-screen keyboard, '
        'then confirm',
  );
  if (!confirmed) return;
  debugPrint('fo07/us04/fr02/e07: platform=$hostOSName');
  await _assertStaysClosed(tester, builds);
}

/// E07, attended on iOS: a human connects a hardware keyboard to the
/// Simulator, which `attend` skips unless `--attended` launched this run;
/// once confirmed the scope stays closed while the field holds focus.
///
/// The instruction names the next boot resetting the setting (edges review
/// Important #1): the device-round skill pins the simulator's own hardware
/// keyboard off at boot, so a human who connects one here must redo it
/// every run, not just once.
Future<void> _attendE07iOS(WidgetTester tester, List<bool> builds) async {
  final confirmed = await attend(
    'e07_ios',
    'press Shift-Cmd-K in Simulator to connect the hardware keyboard, '
        'then confirm; the next boot turns it off again',
  );
  if (!confirmed) return;
  debugPrint('fo07/us04/fr02/e07: platform=$hostOSName');
  await _assertStaysClosed(tester, builds);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fo07/us04/fr02: the keyboard-visibility scope proves whichever of '
    'e02/s2, e04/d4, e05, or e07 this target can show',
    (tester) async {
      final builds = await _pumpApp(tester);
      expect(builds, isNotEmpty, reason: 'the reader never built at all');

      if (!_isAndroidOrIOS) {
        await _proveE05(tester, builds);
        return;
      }

      if (hostOSName == 'ios') {
        await _warmUpKeyboard(tester, builds, hasHardwareKeyboard: false);
        await _proveE02(tester, builds);
        return;
      }

      if (await hasHardwareKeyboard()) {
        // fix-10 (DR18): a device whose hardware-keyboard states are both
        // E07 never opens a real soft keyboard in this test, which this
        // warm-up itself now accepts (`hasHardwareKeyboard: true`) instead
        // of failing on its own 30s bound first.
        await _warmUpKeyboard(tester, builds, hasHardwareKeyboard: true);
        await _proveHardwareKeyboardBoth(tester, builds);
        return;
      }
      await _warmUpKeyboard(tester, builds, hasHardwareKeyboard: false);
      await _proveE02(tester, builds);
      await _proveE04(tester, builds);
    },
  );

  // Attended cases skip at registration (`skip:`), never mid-body: a skip
  // raised inside a running test overrides that same test's own earlier
  // assertions, which is why these never share a test with the automated
  // one above (DR11-r1 `iphone`: e02 passed, then the old inline e07
  // attended-skip turned the whole test "skipped").
  testWidgets(
    'fo07/us04/fr02/e06 (android, attended): a human switches Gboard to '
    'floating mode and the scope stays closed',
    (tester) async {
      final builds = await _pumpApp(tester);
      await _attendE06Android(tester, builds);
    },
    skip: !(attended && hostOSName == 'android'),
  );

  testWidgets(
    'fo07/us04/fr02/e07 (android, attended): a human connects a physical '
    'keyboard and the scope stays closed',
    (tester) async {
      final builds = await _pumpApp(tester);
      await _attendE07Android(tester, builds);
    },
    skip: !(attended && hostOSName == 'android'),
  );

  testWidgets('fo07/us04/fr02/e07 (ios, attended): a human connects a hardware '
      'keyboard to the Simulator and the scope stays closed', (tester) async {
    final builds = await _pumpApp(tester);
    await _attendE07iOS(tester, builds);
  }, skip: !(attended && hostOSName == 'ios'));
}
