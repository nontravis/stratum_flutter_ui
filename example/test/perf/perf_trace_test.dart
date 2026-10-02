import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scene.dart';
import '../../integration_test/perf/perf_scenes.dart';
import '../../integration_test/perf/perf_trace.dart';
import '../../test_driver/perf_driver.dart' show driverTimeout;

void main() {
  group('summaryLine', () {
    final line = summaryLine('r2.S4.cand.1', {
      'average_frame_build_time_millis': 0.31,
      '99th_percentile_frame_build_time_millis': 1.02,
      '99th_percentile_frame_rasterizer_time_millis': 3.4,
      'frame_begin_times': [5000000, 5006940, 5013880],
      'frame_build_times': [310, 290, 330],
    });

    test('starts with the summary marker and holds compact JSON', () {
      expect(line, startsWith('PERF_SUMMARY {'));
      expect(line.substring(summaryMarker.length), isNot(contains(' ')));
    });

    test('keeps the key, the three metrics, and frame starts relative to the '
        'first frame', () {
      expect(jsonDecode(line.substring(summaryMarker.length)), {
        'key': 'r2.S4.cand.1',
        'average': 0.31,
        'p99Build': 1.02,
        'p99Raster': 3.4,
        'begins': [0, 6940, 13880],
      });
    });
  });

  group('runLine', () {
    test('names the run after the run marker', () {
      expect(runLine(7), 'PERF_RUN 7');
    });
  });

  group('driverTimeout', () {
    test('waits out a 24-run call at 2.6 s per traced step, with half again '
        'as margin', () {
      final traced = runSteps(
        perfScenes,
        first: 1,
        count: 24,
      ).where((step) => step.traced).length;
      expect(traced, 768);
      expect(
        driverTimeout,
        greaterThan(const Duration(milliseconds: 2600) * traced * 1.5),
      );
    });
  });
}
