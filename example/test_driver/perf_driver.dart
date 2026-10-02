import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Longest wait for the app's tests to end. One invocation holds every run
/// of a call: 12 runs take about 18 minutes and the cap of 24 about 35,
/// past `integrationDriver`'s default of 20 minutes.
const driverTimeout = Duration(hours: 1);

/// Where `run --trace-full` timelines go, relative to `example/`.
const fullRoot = 'build/perf/full';

/// Writes each full timeline the app kept as `<key>.timeline.json` under
/// [fullRoot]. Only `run --trace-full` keeps timelines; every other
/// invocation's report data is empty, because the app sends its summaries
/// over stdout (spec section 9.4).
Future<void> main() {
  return integrationDriver(
    timeout: driverTimeout,
    responseDataCallback: (data) async {
      for (final entry in (data ?? const <String, dynamic>{}).entries) {
        final timeline = driver.Timeline.fromJson(
          entry.value as Map<String, dynamic>,
        );
        await driver.TimelineSummary.summarize(timeline).writeTimelineToFile(
          entry.key,
          destinationDirectory: fullRoot,
          includeSummary: false,
        );
        stdout.writeln('wrote $fullRoot/${entry.key}.timeline.json');
      }
    },
  );
}
