import 'dart:convert';
import 'dart:io';

const _metrics = [
  'average_frame_build_time_millis',
  '99th_percentile_frame_build_time_millis',
  '99th_percentile_frame_rasterizer_time_millis',
];

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
      final perScene = values.putIfAbsent(scene, () => {});
      for (final metric in _metrics) {
        perScene
            .putIfAbsent(metric, () => [])
            .add((json[metric] as num).toDouble());
      }
    }
  }
  stdout
    ..writeln('| Scene | avg build ms | p99 build ms | p99 raster ms | runs |')
    ..writeln('|---|---|---|---|---|');
  for (final scene in values.keys.toList()..sort()) {
    final perScene = values[scene]!;
    String median(String metric) {
      final sorted = [...perScene[metric]!]..sort();
      return sorted[sorted.length ~/ 2].toStringAsFixed(2);
    }

    stdout.writeln(
      '| $scene | ${median(_metrics[0])} | ${median(_metrics[1])} '
      '| ${median(_metrics[2])} | ${perScene[_metrics[0]]!.length} |',
    );
  }
}
