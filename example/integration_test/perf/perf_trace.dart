import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test.dart';

import 'perf_host.dart';

/// Opens the line the app prints when a run starts (spec section 9.4).
/// `tool/perf_abba.dart` reads the same marker.
const runMarker = 'PERF_RUN ';

/// Opens the line the app prints after each trace (spec section 9.4).
/// `tool/perf_abba.dart` reads the same marker.
const summaryMarker = 'PERF_SUMMARY ';

/// The line that opens run [run]: `PERF_RUN <run>`.
String runLine(int run) => '$runMarker$run';

/// The line that reports the trace [key] from a `TimelineSummary.summaryJson`
/// map: [summaryMarker], then compact JSON with the key, the three metrics
/// the verdict reads, and each frame's build start in microseconds,
/// relative to the first frame (spec section 9.4).
String summaryLine(String key, Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<int>();
  final json = jsonEncode({
    'key': key,
    'average': summary['average_frame_build_time_millis'],
    'p99Build': summary['99th_percentile_frame_build_time_millis'],
    'p99Raster': summary['99th_percentile_frame_rasterizer_time_millis'],
    'begins': [for (final begin in begins) begin - begins.first],
  });
  return '$summaryMarker$json';
}

/// Prints [line] for `flutter drive`, which forwards the app's print output
/// with a `flutter: ` prefix.
void _emit(String line) {
  // The benchmark's only channel to the host: the app runs in the App
  // Sandbox and cannot write under `example/build/`.
  // ignore: avoid_print
  print(line);
}

/// Prints the line that opens run [run].
void printRunLine(int run) => _emit(runLine(run));

/// Traces [action] under [key], prints the trace's summary line, and drops
/// its timeline from the binding's report data, so memory stays flat over
/// hundreds of traces. With [full], the timeline stays for the driver to
/// write (`run --trace-full`).
Future<void> traceStep(
  IntegrationTestWidgetsFlutterBinding binding,
  String key,
  Future<void> Function() action, {
  required bool full,
}) async {
  await binding.traceAction(action, streams: perfStreams, reportKey: key);
  final data = binding.reportData!;
  final timeline =
      (full ? data[key] : data.remove(key)) as Map<String, dynamic>;
  final summary = driver.TimelineSummary.summarize(
    driver.Timeline.fromJson(timeline),
  );
  _emit(summaryLine(key, summary.summaryJson));
}
