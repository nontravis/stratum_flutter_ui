import 'package:flutter_test/flutter_test.dart';

/// Pumps a frame every [interval] until [done] holds; returns `false` once
/// [timeout] passes.
///
/// It never fails on its own, so a case can log what it saw before it
/// asserts.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await tester.pump(interval);
  }
  return true;
}
