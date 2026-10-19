import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures every [FlutterError.reportError] call made during the current
/// test, restoring the previous handler in [addTearDown] (PD12).
///
/// Call once per test, before the call expected to report.
List<FlutterErrorDetails> captureErrorReports() {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = previous);
  return reported;
}
