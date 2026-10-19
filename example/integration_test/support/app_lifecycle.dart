import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_until.dart';

/// How long [waitForResumed] waits for the app window to gain input focus
/// before failing.
const _resumedTimeout = Duration(seconds: 10);

/// Pumps until `WidgetsBinding.instance.lifecycleState` reads
/// `AppLifecycleState.resumed`, the precondition a keyboard show request
/// needs on Android and iOS (RCA `rca-kv-pixel8.findings.md` revision 2).
///
/// On Android the engine reports `resumed` only once the activity is
/// resumed and its window holds input focus; a show sent before that fails
/// silently (`Ignoring showSoftInput() ... is not served`) and nothing
/// resends it. Call this before the first keyboard action on those hosts,
/// never a fixed delay.
///
/// Fails naming the state it saw after 10 s with no resume.
Future<void> waitForResumed(WidgetTester tester) async {
  final resumed = await pumpUntil(
    tester,
    () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    timeout: _resumedTimeout,
  );
  if (!resumed) {
    fail(
      'the app window never gained focus: lifecycleState='
      '${WidgetsBinding.instance.lifecycleState}',
    );
  }
}
