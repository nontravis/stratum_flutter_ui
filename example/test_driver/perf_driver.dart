import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

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
        await driver.TimelineSummary.summarize(timeline).writeTimelineToFile(
          entry.key,
          destinationDirectory: 'build/perf/run$run',
          pretty: true,
        );
      }
    },
  );
}
