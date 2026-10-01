import 'dart:convert';
import 'dart:io';

/// Frame budget at 120 Hz, in milliseconds (spec section 9).
const _budget = 8.3;

/// Largest allowed rise of the median average build time, in percent.
const _maxAverageRise = 5.0;

/// Compares two sets of benchmark runs by paired differences.
///
/// Usage:
/// `dart run tool/perf_pairs.dart <base> <candidate> [<base>=<candidate> ...]`
///
/// `<base>` and `<candidate>` each hold the `run<N>/` directories that
/// `test_driver/perf_driver.dart` writes. Run N of the base pairs with run N
/// of the candidate, so interleaved runs pair with their neighbor. Without
/// scene arguments every scene found on both sides pairs with itself; an
/// argument such as `S2-plain=S2-box` pairs two different scenes, for example
/// within one directory. Prints, per pair, the base and candidate medians,
/// the median of the paired differences, and the spec's pass verdict.
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'usage: dart run tool/perf_pairs.dart <base> <candidate> '
      '[<base scene>=<candidate scene> ...]',
    );
    exitCode = 64;
    return;
  }
  final base = _readRuns(args[0]);
  final candidate = _readRuns(args[1]);
  final pairs = args.length > 2
      ? [for (final arg in args.skip(2)) arg.split('=')]
      : [
          for (final scene in _scenes(base).intersection(_scenes(candidate)))
            [scene, scene],
        ];
  pairs.sort((a, b) => a.last.compareTo(b.last));
  stdout
    ..writeln(
      '| pair | runs | avg build ms | Δ avg % | p99 build ms | Δ p99 build '
      '| p99 raster ms | Δ p99 raster | interval ms | verdict |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final [baseScene, candidateScene] in pairs) {
    final runs = [
      for (final run in base.keys)
        if (base[run]![baseScene] != null &&
            candidate[run]?[candidateScene] != null)
          (base[run]![baseScene]!, candidate[run]![candidateScene]!),
    ];
    if (runs.isEmpty) {
      stdout.writeln('| $baseScene=$candidateScene | 0 | no paired runs |');
      continue;
    }
    stdout.writeln(_row('$baseScene=$candidateScene', runs));
  }
}

String _row(String name, List<(_Summary, _Summary)> runs) {
  double medianOf(double Function(_Summary s) metric, {required bool base}) =>
      _median([for (final (b, c) in runs) metric(base ? b : c)]);
  double deltaOf(double Function(_Summary s) metric) =>
      _median([for (final (b, c) in runs) metric(c) - metric(b)]);

  final averageRise = _median([
    for (final (b, c) in runs) (c.average - b.average) / b.average * 100,
  ]);
  final baseBuild = medianOf((s) => s.p99Build, base: true);
  final candidateBuild = medianOf((s) => s.p99Build, base: false);
  final baseRaster = medianOf((s) => s.p99Raster, base: true);
  final candidateRaster = medianOf((s) => s.p99Raster, base: false);
  final buildDelta = deltaOf((s) => s.p99Build);
  final rasterDelta = deltaOf((s) => s.p99Raster);
  final baseInterval = medianOf((s) => s.interval, base: true);
  final candidateInterval = medianOf((s) => s.interval, base: false);

  bool withinBudget(double baseValue, double candidate, double delta) =>
      candidate < _budget || (baseValue >= _budget && delta <= 0);

  final String verdict;
  if ((candidateInterval - baseInterval).abs() > baseInterval * 0.1) {
    verdict = 'INVALID interval';
  } else if (averageRise <= _maxAverageRise &&
      withinBudget(baseBuild, candidateBuild, buildDelta) &&
      withinBudget(baseRaster, candidateRaster, rasterDelta)) {
    verdict = 'pass';
  } else {
    verdict = 'FAIL';
  }
  String ms(double value) => value.toStringAsFixed(2);
  return '| $name | ${runs.length} '
      '| ${ms(medianOf((s) => s.average, base: true))} → '
      '${ms(medianOf((s) => s.average, base: false))} '
      '| ${averageRise.toStringAsFixed(2)} '
      '| ${ms(baseBuild)} → ${ms(candidateBuild)} | ${ms(buildDelta)} '
      '| ${ms(baseRaster)} → ${ms(candidateRaster)} | ${ms(rasterDelta)} '
      '| ${ms(baseInterval)} / ${ms(candidateInterval)} | $verdict |';
}

class _Summary {
  new(Map<String, dynamic> json)
    : average = (json['average_frame_build_time_millis'] as num).toDouble(),
      p99Build = (json['99th_percentile_frame_build_time_millis'] as num)
          .toDouble(),
      p99Raster = (json['99th_percentile_frame_rasterizer_time_millis'] as num)
          .toDouble(),
      interval = _medianInterval(json);

  final double average;
  final double p99Build;
  final double p99Raster;

  /// Median gap between frame starts, in milliseconds.
  final double interval;
}

/// Run directory name, then scene, then that run's summary.
Map<String, Map<String, _Summary>> _readRuns(String root) {
  final runs = <String, Map<String, _Summary>>{};
  final directories = Directory(root).listSync().whereType<Directory>().where(
    (directory) => directory.uri.pathSegments
        .lastWhere((segment) => segment.isNotEmpty)
        .startsWith('run'),
  );
  for (final directory in directories) {
    final name = directory.uri.pathSegments.lastWhere(
      (segment) => segment.isNotEmpty,
    );
    final files = directory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.timeline_summary.json'),
    );
    runs[name] = {
      for (final file in files)
        file.uri.pathSegments.last.split('.').first: _Summary(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        ),
    };
  }
  return runs;
}

Set<String> _scenes(Map<String, Map<String, _Summary>> runs) {
  return {for (final run in runs.values) ...run.keys};
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

double _medianInterval(Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<num>();
  final intervals = [
    for (var i = 1; i < begins.length; i++) (begins[i] - begins[i - 1]) / 1000,
  ];
  return _median(intervals);
}
