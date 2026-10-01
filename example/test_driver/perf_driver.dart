import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Length of every traced window in `layout_perf_test.dart`.
const _traceWindow = Duration(seconds: 2);

/// Writes one timeline summary per trace key into
/// `build/perf/run<PERF_RUN>/`, so repeated runs never overwrite each other.
Future<void> main() {
  final run = Platform.environment['PERF_RUN'] ?? '0';
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      for (final entry in data.entries) {
        final timeline = driver.Timeline.fromJson(
          entry.value as Map<String, dynamic>,
        );
        final summary = driver.TimelineSummary.summarize(timeline);
        _checkCoverage(entry.key, summary.summaryJson);
        await summary.writeTimelineToFile(
          entry.key,
          destinationDirectory: 'build/perf/run$run',
          pretty: true,
        );
      }
    },
  );
}

/// Throws when a summary does not cover the traced window, which happens
/// when the timeline recorder's ring buffer drops the first frames.
void _checkCoverage(String key, Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<num>();
  final intervals = [
    for (var i = 1; i < begins.length; i++) begins[i] - begins[i - 1],
  ]..sort();
  final interval = intervals[intervals.length ~/ 2];
  final span = begins.last - begins.first;
  stdout.writeln(
    '$key: ${begins.length} frames, '
    'span ${(span / 1000).toStringAsFixed(1)} ms, '
    'frame interval ${(interval / 1000).toStringAsFixed(2)} ms',
  );
  if (span < _traceWindow.inMicroseconds - 2 * interval) {
    throw StateError(
      '$key covers ${span ~/ 1000} ms of the '
      '${_traceWindow.inMilliseconds} ms window; '
      'run flutter drive with --endless-trace-buffer',
    );
  }
}
