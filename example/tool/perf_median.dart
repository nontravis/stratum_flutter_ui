import 'dart:convert';
import 'dart:io';

const _metrics = [
  'average_frame_build_time_millis',
  '99th_percentile_frame_build_time_millis',
  '99th_percentile_frame_rasterizer_time_millis',
  'frame_count',
  _frameInterval,
];

/// Median gap between frame starts, in milliseconds. Comparing runs with a
/// different interval (another display or refresh rate) is not valid.
const _frameInterval = 'frame_interval_millis';

/// Prints the median of each metric per scene across `build/perf/run*/`.
void main() {
  final values = <String, Map<String, List<double>>>{};
  final runs = Directory('build/perf').listSync().whereType<Directory>();
  for (final run in runs) {
    final summaries = run.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.timeline_summary.json'),
    );
    for (final file in summaries) {
      final scene = file.uri.pathSegments.last.split('.').first;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      json[_frameInterval] = _medianInterval(json);
      final perScene = values.putIfAbsent(scene, () => {});
      for (final metric in _metrics) {
        perScene
            .putIfAbsent(metric, () => [])
            .add((json[metric] as num).toDouble());
      }
    }
  }
  stdout
    ..writeln(
      '| Scene | avg build ms | p99 build ms | p99 raster ms '
      '| frames | frame interval ms | runs |',
    )
    ..writeln('|---|---|---|---|---|---|---|');
  for (final scene in values.keys.toList()..sort()) {
    final perScene = values[scene]!;
    String median(String metric, [int digits = 2]) {
      final sorted = [...perScene[metric]!]..sort();
      return sorted[sorted.length ~/ 2].toStringAsFixed(digits);
    }

    stdout.writeln(
      '| $scene | ${median(_metrics[0])} | ${median(_metrics[1])} '
      '| ${median(_metrics[2])} | ${median(_metrics[3], 0)} '
      '| ${median(_frameInterval)} | ${perScene[_metrics[0]]!.length} |',
    );
  }
}

double _medianInterval(Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<num>();
  final intervals = [
    for (var i = 1; i < begins.length; i++) begins[i] - begins[i - 1],
  ]..sort();
  return intervals[intervals.length ~/ 2] / 1000;
}
