import 'package:flutter_test/flutter_test.dart';

/// Pumps a frame every [interval] until [done] holds; returns `false` once
/// [budget] is spent on the monotonic clock.
///
/// It never fails on its own, so a case can log what it saw before it
/// asserts. A `Stopwatch`, never wall-clock time, bounds the wait: a
/// wall-clock step can neither shorten nor stretch it.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration budget = const Duration(seconds: 30),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!done()) {
    if (stopwatch.elapsed > budget) return false;
    await tester.pump(interval);
  }
  return true;
}
