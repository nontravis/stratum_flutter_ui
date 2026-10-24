import 'package:flutter_test/flutter_test.dart';

import 'pump_until.dart';

/// Waits until the OS's final report of the request is [expected] and the
/// scope's last build reads the same, re-reading both after every settle
/// pass, so an interim OS report never ends a half (rca-r3 K1: the warm-up
/// hide's tail control update can land after the measured show's inset, and
/// the OS briefly reports `false` after the open request's own `true`).
///
/// One pass waits out the frames already in flight (the report that just
/// landed may still owe the scope a rebuild), then pumps one
/// [_settleFrameGap] frame — pumping, never sleeping, so a report scheduled
/// but not yet delivered still fires on the pumped clock — and the loop then
/// re-reads [osEvents] and [builds]. Pass 1 always runs, budget spent or
/// not, so a slow IME that reaches the loop near the bound still gets one
/// quiet pass and never ends its half on an interim report; the budget is
/// tested only before a further pass. Each pass's frame wait is bounded by
/// [scopeAfterOsEventBound]; the whole loop is bounded by [budget] on the
/// monotonic [stopwatch], started at the request, so a wall-clock step can
/// never shorten or stretch it; on expiry the caller's own check names what
/// it saw, never this helper.
///
/// Lives here, beside [pumpUntil], so a host `testWidgets` can feed plain
/// lists and prove the settle rule with controlled timing; the mobile test
/// imports it.
Future<void> settleKeyboardScope(
  WidgetTester tester,
  List<bool> builds,
  List<bool> osEvents, {
  required bool expected,
  required Stopwatch stopwatch,
  required Duration budget,
}) async {
  bool osAndScopeMatch() =>
      osEvents.isNotEmpty &&
      osEvents.last == expected &&
      builds.isNotEmpty &&
      builds.last == expected;

  do {
    final quiet = await pumpUntil(
      tester,
      () => !tester.binding.hasScheduledFrame,
      budget: scopeAfterOsEventBound,
    );
    if (!quiet) return;
    await tester.pump(_settleFrameGap);
  } while (!osAndScopeMatch() && stopwatch.elapsed < budget);
}

/// One pumped frame per settle pass: long enough that a pending OS report
/// fires between two re-reads, short enough that the scope's matching build
/// lands within a couple of passes. A frame, never a fixed sleep.
const _settleFrameGap = Duration(milliseconds: 100);

/// How long one settle pass bounds its in-flight frame wait (fix-5 item
/// 2.3): short, because this bound measures the scope reacting to an inset
/// Flutter already delivered, never fresh IME latency, which the caller's
/// own request-measured bound covers instead.
const scopeAfterOsEventBound = Duration(seconds: 2);
