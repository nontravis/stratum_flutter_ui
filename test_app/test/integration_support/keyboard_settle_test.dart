// Host proof of `integration_test/common/support/keyboard_settle.dart`'s
// settle rule (impl-task-60 fix-1): a device run cannot order the OS's
// interim report after the request's own report on demand, so these cases
// feed the helper plain lists with the exact ordering rca-r3 K1 traced —
// the OS reports `true`, then a stale `false` (the warm-up hide's tail
// control update), then the final `true` — and prove the loop re-reads
// both lists after every pumped frame instead of taking the first match
// and returning before the stale report lands.
//
// fix-2 adds the pass-1 guarantee: a budget already spent at entry still
// gets one full quiet pass, so a slow IME that reaches the loop near the
// bound never ends its half on an interim report.
//
// Timing: under `testWidgets` a fake timer fires when a pump advances the
// fake clock past it, and the helper pumps a frame per pass, so reports
// land between passes exactly as the plugin stream delivers them between
// the device's frames. No concurrent pumper: `pump` is guarded.
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/common/support/keyboard_settle.dart';

/// Appends [value] to [target] at fake time [at], the way a plugin stream
/// event delivers on its own schedule.
Timer _reportAt(Duration at, List<bool> target, bool value) {
  return Timer(at, () => target.add(value));
}

void _cancelAll(List<Timer> timers) {
  for (final t in timers) {
    t.cancel();
  }
}

void main() {
  testWidgets(
    'open half: an interim hidden between two shown never ends the wait',
    (tester) async {
      final builds = <bool>[false];
      final osEvents = <bool>[];
      final timers = <Timer>[
        // The request's own `true`, the stale `false` (rca-r3 K1: the
        // warm-up hide's tail control update), then the final `true`.
        _reportAt(const Duration(milliseconds: 100), osEvents, true),
        _reportAt(const Duration(milliseconds: 110), builds, true),
        _reportAt(const Duration(milliseconds: 200), osEvents, false),
        _reportAt(const Duration(milliseconds: 210), builds, false),
        _reportAt(const Duration(milliseconds: 300), osEvents, true),
        _reportAt(const Duration(milliseconds: 310), builds, true),
      ];
      addTearDown(() => _cancelAll(timers));

      await settleKeyboardScope(
        tester,
        builds,
        osEvents,
        expected: true,
        stopwatch: Stopwatch()..start(),
        budget: const Duration(seconds: 10),
      );

      expect(osEvents, [true, false, true]);
      expect(builds.last, isTrue, reason: 'the scope reads the final shown');
      expect(osEvents.last, isTrue, reason: 'the OS ended on shown');
    },
  );

  testWidgets(
    'open half: the OS ending hidden fails the caller, not silently passing',
    (tester) async {
      final builds = <bool>[false];
      final osEvents = <bool>[];
      final timers = <Timer>[
        _reportAt(const Duration(milliseconds: 100), osEvents, true),
        _reportAt(const Duration(milliseconds: 110), builds, true),
        // The OS truly ends hidden; nothing more ever arrives.
        _reportAt(const Duration(milliseconds: 200), osEvents, false),
        _reportAt(const Duration(milliseconds: 210), builds, false),
      ];
      addTearDown(() => _cancelAll(timers));

      // A short budget, so the case runs in milliseconds, never the
      // device's request-measured bound.
      await settleKeyboardScope(
        tester,
        builds,
        osEvents,
        expected: true,
        stopwatch: Stopwatch()..start(),
        budget: const Duration(milliseconds: 400),
      );

      // The helper returned without matching; the caller's own check (the
      // mobile test's _expectScopeFollowedOs) then fails naming the OS's
      // end state. Prove the mismatch the caller sees.
      expect(
        osEvents.last,
        isFalse,
        reason: 'the OS truly ended hidden, so the caller fails',
      );
      expect(builds.last, isFalse);
    },
  );

  testWidgets(
    'close half: an interim shown between two hidden never ends the wait',
    (tester) async {
      final builds = <bool>[true];
      final osEvents = <bool>[];
      final timers = <Timer>[
        _reportAt(const Duration(milliseconds: 100), osEvents, false),
        _reportAt(const Duration(milliseconds: 110), builds, false),
        _reportAt(const Duration(milliseconds: 200), osEvents, true),
        _reportAt(const Duration(milliseconds: 210), builds, true),
        _reportAt(const Duration(milliseconds: 300), osEvents, false),
        _reportAt(const Duration(milliseconds: 310), builds, false),
      ];
      addTearDown(() => _cancelAll(timers));

      await settleKeyboardScope(
        tester,
        builds,
        osEvents,
        expected: false,
        stopwatch: Stopwatch()..start(),
        budget: const Duration(seconds: 10),
      );

      expect(osEvents, [false, true, false]);
      expect(builds.last, isFalse, reason: 'the scope reads the final hidden');
      expect(osEvents.last, isFalse, reason: 'the OS ended on hidden');
    },
  );

  testWidgets(
    'open half: a stale hidden landing after the match is still caught '
    '(the rca-r3 K1 ordering)',
    (tester) async {
      final builds = <bool>[false];
      final osEvents = <bool>[];
      // The IME animation keeps frames in flight until just after the stale
      // `false` lands and before the final `true`: the pre-fix body matched
      // on the request's own `true`, its quiet gate pumped out the stale
      // report's rebuild, and the half ended reading the interim `false`.
      final ticker = Ticker((_) {})..start();
      final timers = <Timer>[
        Timer(const Duration(milliseconds: 200), ticker.stop),
        _reportAt(const Duration(milliseconds: 80), osEvents, true),
        _reportAt(const Duration(milliseconds: 90), builds, true),
        _reportAt(const Duration(milliseconds: 150), osEvents, false),
        _reportAt(const Duration(milliseconds: 210), builds, false),
        _reportAt(const Duration(milliseconds: 300), osEvents, true),
        _reportAt(const Duration(milliseconds: 310), builds, true),
      ];
      addTearDown(() {
        ticker.stop();
        _cancelAll(timers);
      });

      await settleKeyboardScope(
        tester,
        builds,
        osEvents,
        expected: true,
        stopwatch: Stopwatch()..start(),
        budget: const Duration(seconds: 10),
      );

      expect(osEvents, [true, false, true]);
      expect(builds.last, isTrue, reason: 'the scope reads the final shown');
      expect(osEvents.last, isTrue, reason: 'the OS ended on shown');
    },
  );

  testWidgets('a budget already spent at entry still settles one quiet pass '
      '(fix-2, review Important 1)', (tester) async {
    final builds = <bool>[false];
    final osEvents = <bool>[true];
    builds.add(true);
    // The interim state is still landing when the helper is entered with
    // its whole budget already spent — the slow-IME shape: the inset wait
    // consumed the bound, the OS then flips to its final report during
    // the helper's own first pass.
    final ticker = Ticker((_) {})..start();
    final timers = <Timer>[
      Timer(const Duration(milliseconds: 200), ticker.stop),
      _reportAt(const Duration(milliseconds: 80), osEvents, false),
      _reportAt(const Duration(milliseconds: 150), osEvents, true),
      _reportAt(const Duration(milliseconds: 160), builds, false),
      _reportAt(const Duration(milliseconds: 230), builds, true),
    ];
    addTearDown(() {
      ticker.stop();
      _cancelAll(timers);
    });
    // A zero budget: spent at entry, yet pass 1 still runs in full and
    // waits out the interim flip — the slow-IME shape the review found.
    await settleKeyboardScope(
      tester,
      builds,
      osEvents,
      expected: true,
      stopwatch: Stopwatch()..start(),
      budget: Duration.zero,
    );

    // Pass 1 ran despite the spent budget and waited out the interim
    // flip; the helper returned on the final state, never the interim.
    expect(osEvents, [true, false, true]);
    expect(builds.last, isTrue, reason: 'the scope reads the final shown');
    expect(osEvents.last, isTrue, reason: 'the OS ended on shown');
  });
}
