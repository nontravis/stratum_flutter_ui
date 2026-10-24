import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_until.dart';

/// How long [waitForResumed] waits for the app window to gain input focus
/// before failing.
const _resumedTimeout = Duration(seconds: 10);

/// The last OS lifecycle state this process observed, surviving the
/// per-test reset [installLifecycleObserver] documents.
AppLifecycleState? _lastKnownLifecycleState;

/// Whether [installLifecycleObserver] has already added its observer.
bool _lifecycleObserverInstalled = false;

/// Installs a process-wide observer that records every OS lifecycle state
/// into [_lastKnownLifecycleState], seeded from the binding's current
/// state; a no-op past the first call.
///
/// `flutter_test` calls `ServicesBinding.instance.resetInternalState()`
/// after every test (flutter_test/lib/src/binding.dart:2168), which nulls
/// `WidgetsBinding.instance.lifecycleState`
/// (scheduler/binding.dart:400-404). The OS never resends `resumed` to a
/// window that stayed resumed, so [waitForResumed] would otherwise see
/// `null` for the rest of the process. This observer is never removed, so
/// the record it keeps outlives that reset.
///
/// Call this no later than the first test of a file; [waitForResumed]
/// also calls it lazily.
void installLifecycleObserver() {
  if (_lifecycleObserverInstalled) return;
  _lifecycleObserverInstalled = true;
  _lastKnownLifecycleState = WidgetsBinding.instance.lifecycleState;
  WidgetsBinding.instance.addObserver(_LifecycleRecorder());
}

/// Feeds every OS lifecycle change into [_lastKnownLifecycleState]; never
/// disposed, so it keeps recording across `flutter_test`'s per-test reset.
class _LifecycleRecorder with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastKnownLifecycleState = state;
  }
}

/// Pumps until the app window is known resumed, the precondition a
/// keyboard show request needs on Android and iOS (RCA
/// `rca-kv-pixel8.findings.md` revision 2).
///
/// Reads `WidgetsBinding.instance.lifecycleState` when non-null, else
/// [installLifecycleObserver]'s own record of the last OS state, since the
/// binding's own field reads `null` for every test after the first
/// (`installLifecycleObserver`'s doc explains why).
///
/// On Android the engine reports `resumed` only once the activity is
/// resumed and its window holds input focus; a show sent before that fails
/// silently (`Ignoring showSoftInput() ... is not served`) and nothing
/// resends it. Call this before the first keyboard action on those hosts,
/// never a fixed delay.
///
/// Fails naming the state it saw after [timeout] with no resume.
Future<void> waitForResumed(
  WidgetTester tester, {
  Duration timeout = _resumedTimeout,
}) async {
  installLifecycleObserver();
  AppLifecycleState? currentState() =>
      WidgetsBinding.instance.lifecycleState ?? _lastKnownLifecycleState;
  final resumed = await pumpUntil(
    tester,
    () => currentState() == AppLifecycleState.resumed,
    budget: timeout,
  );
  if (!resumed) {
    fail('the app window never gained focus: lifecycleState=${currentState()}');
  }
}
