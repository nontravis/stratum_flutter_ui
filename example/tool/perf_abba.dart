import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Frame budget at 120 Hz, in milliseconds (spec section 9.5).
const budget = 8.3;

/// Largest accepted rise of the average build time, in percent.
const maxAverageRise = 5.0;

/// Largest distance of a trace's frame interval from its run's median
/// interval, as a fraction of the median.
const maxIntervalDrift = 0.1;

/// Scene groups per run: the keys of `perfGroups` in
/// `integration_test/perf/perf_scenes.dart`.
const groups = [1, 2, 3];

/// Most runs one comparison holds: 24 pairs per scene (spec section 9.5).
const maxRuns = 12;

/// The null-control scene, judged only by the null gate.
const nullScene = 'S2-plain';

/// Root of the run folders, relative to `example/`.
const abbaRoot = 'build/perf/abba';

const _usage =
    'usage: dart run tool/perf_abba.dart report\n'
    '       dart run tool/perf_abba.dart run --runs <n> [--from <first>]';

/// The verdict of a scene or a comparison (spec section 9.5).
enum Verdict { pass, fail, inconclusive, invalid }

/// The metrics read from one `TimelineSummary`; the interval is the median
/// gap between frame starts, in milliseconds.
typedef TraceMetrics = ({
  double average,
  double p99Build,
  double p99Raster,
  double interval,
});

/// One trace: its run folder (`r<run>g<group>`) and its report key.
typedef Trace = ({
  String run,
  String scene,
  String side,
  int pair,
  TraceMetrics metrics,
});

/// A baseline trace and the current trace it pairs with.
typedef TracePair = ({TraceMetrics base, TraceMetrics cand});

/// A 95% interval for the median paired change, in percent.
typedef ConfidenceInterval = ({double lower, double upper});

/// Runs and judges the in-process ABBA benchmark (spec section 9.5).
///
/// Usage, from `example/`:
/// - `dart run tool/perf_abba.dart run --runs 6` runs `flutter drive` once
///   per run and group, recording `uptime` before each, then reports.
/// - `dart run tool/perf_abba.dart run --from 7 --runs 6` adds the one
///   escalation, up to 12 runs (24 pairs per scene).
/// - `dart run tool/perf_abba.dart report` judges the stored runs again.
///
/// Prints the report, writes it to `build/perf/abba/report.md`, and exits
/// with 0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE.
Future<void> main(List<String> args) async {
  switch (args) {
    case ['report']:
      exitCode = _report();
    case ['run', ...final options] when _option(options, '--runs') != null:
      exitCode = await _run(
        from: _option(options, '--from') ?? 1,
        runs: _option(options, '--runs')!,
      );
    default:
      stderr.writeln(_usage);
      exitCode = 64;
  }
}

int? _option(List<String> options, String name) {
  final index = options.indexOf(name);
  return index < 0 || index + 1 >= options.length
      ? null
      : int.tryParse(options[index + 1]);
}

/// Why runs [from] to `from + runs - 1` cannot run, or null when they can.
String? runRangeError({required int from, required int runs}) {
  final last = from + runs - 1;
  if (from < 1 || runs < 1 || last > maxRuns) {
    return 'runs $from to $last fall outside 1 to $maxRuns '
        '(24 pairs per scene)';
  }
  return null;
}

/// Run folders under [root] that runs [from] to `from + runs - 1` would
/// write into but that exist already.
List<String> clashingRuns(
  Directory root, {
  required int from,
  required int runs,
}) {
  return [
    for (var run = from; run < from + runs; run++)
      for (final group in groups)
        if (Directory('${root.path}/r${run}g$group').existsSync())
          '${root.path}/r${run}g$group',
  ];
}

Future<int> _run({required int from, required int runs}) async {
  final rangeError = runRangeError(from: from, runs: runs);
  if (rangeError != null) {
    stderr.writeln(rangeError);
    return 64;
  }
  final clashes = clashingRuns(Directory(abbaRoot), from: from, runs: runs);
  if (clashes.isNotEmpty) {
    stderr.writeln(
      '${clashes.join(', ')} exist: rm -rf $abbaRoot for a new comparison, '
      'or pass --from after the last stored run',
    );
    return 64;
  }
  for (var run = from; run < from + runs; run++) {
    for (final group in groups) {
      final directory = Directory('$abbaRoot/r${run}g$group')
        ..createSync(recursive: true);
      final uptime = await Process.run('uptime', const []);
      final load = (uptime.stdout as String).trim();
      File('${directory.path}/load.txt').writeAsStringSync(load);
      stdout.writeln('run $run group $group: $load');
      final drive = await Process.start(
        'flutter',
        [
          'drive',
          '--profile',
          '--endless-trace-buffer',
          '-d',
          'macos',
          '--driver=test_driver/perf_driver.dart',
          '--target=integration_test/layout_perf_test.dart',
          '--dart-define=PERF_GROUP=$group',
        ],
        environment: {'PERF_RUN': '$run', 'PERF_GROUP': '$group'},
        mode: ProcessStartMode.inheritStdio,
      );
      final code = await drive.exitCode;
      if (code != 0) {
        stderr.writeln(
          'flutter drive exited $code on run $run group $group; '
          'rm -rf $abbaRoot/r${run}g* and pass --from $run to continue',
        );
        return 1;
      }
    }
  }
  return _report();
}

int _report() {
  final root = Directory(abbaRoot);
  if (!root.existsSync()) {
    stderr.writeln('no runs in $abbaRoot');
    return 64;
  }
  final (:traces, :loads) = readRuns(root);
  final result = judge(traces, loads: loads);
  stdout.write(result.text);
  File('$abbaRoot/report.md').writeAsStringSync(result.text);
  return exitCodeOf(result.verdict);
}

/// Reads the metrics of one `*.timeline_summary.json` map.
TraceMetrics metricsOf(Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<num>();
  double read(String key) => (summary[key] as num).toDouble();
  return (
    average: read('average_frame_build_time_millis'),
    p99Build: read('99th_percentile_frame_build_time_millis'),
    p99Raster: read('99th_percentile_frame_rasterizer_time_millis'),
    interval: median([
      for (var i = 1; i < begins.length; i++)
        (begins[i] - begins[i - 1]) / 1000,
    ]),
  );
}

/// The trace in [fileName] of [run], or null when the name is not
/// `<scene>.<side>.<pair>.timeline_summary.json`.
Trace? traceOf(String run, String fileName, TraceMetrics metrics) {
  final parts = fileName.split('.');
  if (parts.length != 5 ||
      parts[3] != 'timeline_summary' ||
      parts[4] != 'json') {
    return null;
  }
  final [scene, side, pairText, _, _] = parts;
  final pair = int.tryParse(pairText);
  if (pair == null || (side != 'base' && side != 'cand')) return null;
  return (run: run, scene: scene, side: side, pair: pair, metrics: metrics);
}

/// Runs with a trace whose frame interval differs by more than
/// [maxIntervalDrift] from the run's median interval.
Set<String> invalidRuns(List<Trace> traces) {
  final byRun = <String, List<Trace>>{};
  for (final trace in traces) {
    (byRun[trace.run] ??= []).add(trace);
  }
  return {
    for (final MapEntry(key: run, value: runTraces) in byRun.entries)
      if (_drifts(runTraces)) run,
  };
}

bool _drifts(List<Trace> traces) {
  final middle = median([for (final t in traces) t.metrics.interval]);
  return traces.any(
    (t) => (t.metrics.interval - middle).abs() > middle * maxIntervalDrift,
  );
}

/// Scene to its pairs: the `base` and `cand` traces with the same run,
/// scene, and pair number. A trace without its partner is left out.
Map<String, List<TracePair>> pairTraces(List<Trace> traces) {
  final sides = <(String, String, int), Map<String, TraceMetrics>>{};
  for (final trace in traces) {
    (sides[(trace.run, trace.scene, trace.pair)] ??= {})[trace.side] =
        trace.metrics;
  }
  final pairs = <String, List<TracePair>>{};
  for (final MapEntry(key: (_, scene, _), value: bySide) in sides.entries) {
    final base = bySide['base'];
    final cand = bySide['cand'];
    if (base != null && cand != null) {
      (pairs[scene] ??= []).add((base: base, cand: cand));
    }
  }
  return pairs;
}

/// The pair's change in average build time, in percent.
double averageChange(TracePair pair) {
  return (pair.cand.average / pair.base.average - 1) * 100;
}

/// The median of [values], which must not be empty.
double median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Rank k of the distribution-free 95% interval [x(k), x(n−k+1)] for the
/// median of [n] values: the largest k with P(Bin(n, ½) ≤ k − 1) ≤ 0.025.
/// Null below 6 values, where no such k exists.
int? ciRank(int n) {
  int? rank;
  var probability = math.pow(0.5, n).toDouble();
  var cumulative = 0.0;
  for (var k = 1; k <= n ~/ 2; k++) {
    cumulative += probability;
    if (cumulative > 0.025) break;
    rank = k;
    probability *= (n - k + 1) / k;
  }
  return rank;
}

/// The 95% interval for the median of [changes], or null below 6 values.
ConfidenceInterval? medianInterval(List<double> changes) {
  final k = ciRank(changes.length);
  if (k == null) return null;
  final sorted = [...changes]..sort();
  return (lower: sorted[k - 1], upper: sorted[sorted.length - k]);
}

/// Whether the current side keeps the p99 budget for build and for raster
/// (spec section 9.5).
bool withinBudget(List<TracePair> pairs) {
  bool keeps(double Function(TraceMetrics metrics) metric) {
    final base = median([for (final p in pairs) metric(p.base)]);
    final cand = median([for (final p in pairs) metric(p.cand)]);
    final delta = median([
      for (final p in pairs) metric(p.cand) - metric(p.base),
    ]);
    return cand < budget || (base >= budget && delta <= 0);
  }

  return keeps((m) => m.p99Build) && keeps((m) => m.p99Raster);
}

/// Whether the null control's interval exists and contains 0.
bool nullGatePasses(ConfidenceInterval? ci) {
  return ci != null && ci.lower <= 0 && ci.upper >= 0;
}

/// The verdict of one scene other than S2-plain (spec section 9.5).
///
/// [ci] is null when the scene has fewer than 6 pairs.
Verdict sceneVerdict({
  required ConfidenceInterval? ci,
  required bool p99WithinBudget,
}) {
  if (!p99WithinBudget) return Verdict.fail;
  if (ci == null) return Verdict.inconclusive;
  if (ci.upper <= maxAverageRise) return Verdict.pass;
  if (ci.lower > maxAverageRise) return Verdict.fail;
  return Verdict.inconclusive;
}

/// The verdict of a comparison: INVALID, then FAIL, then INCONCLUSIVE,
/// then PASS.
Verdict overallVerdict({
  required bool nullGate,
  required Iterable<Verdict> scenes,
}) {
  if (!nullGate) return Verdict.invalid;
  if (scenes.contains(Verdict.fail)) return Verdict.fail;
  if (scenes.contains(Verdict.inconclusive)) return Verdict.inconclusive;
  return Verdict.pass;
}

/// The exit code for [verdict].
int exitCodeOf(Verdict verdict) {
  return switch (verdict) {
    Verdict.pass => 0,
    Verdict.fail || Verdict.invalid => 1,
    Verdict.inconclusive => 2,
  };
}

/// The one-minute load average in an `uptime` line, or null.
double? loadOf(String uptime) {
  final match = RegExp(r'load averages?: ([\d.]+)').firstMatch(uptime);
  return match == null ? null : double.tryParse(match[1]!);
}

/// Every trace and recorded load under [root].
({List<Trace> traces, List<double> loads}) readRuns(Directory root) {
  final traces = <Trace>[];
  final loads = <double>[];
  for (final directory in root.listSync().whereType<Directory>()) {
    final run = directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final loadFile = File('${directory.path}/load.txt');
    final load = loadFile.existsSync()
        ? loadOf(loadFile.readAsStringSync())
        : null;
    if (load != null) loads.add(load);
    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.timeline_summary.json')) continue;
      final summary =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final trace = traceOf(run, name, metricsOf(summary));
      if (trace != null) traces.add(trace);
    }
  }
  return (traces: traces, loads: loads);
}

/// Judges [traces] and returns the report text and the overall verdict.
({String text, Verdict verdict}) judge(
  List<Trace> traces, {
  required List<double> loads,
}) {
  final invalid = invalidRuns(traces);
  final valid = [
    for (final trace in traces)
      if (!invalid.contains(trace.run)) trace,
  ];
  final pairs = pairTraces(valid);
  final nullCi = medianInterval([
    for (final pair in pairs[nullScene] ?? const <TracePair>[])
      averageChange(pair),
  ]);
  final gate = nullGatePasses(nullCi);
  final rows = <String>[];
  final verdicts = <Verdict>[];
  for (final scene in pairs.keys.toList()..sort()) {
    final scenePairs = pairs[scene]!;
    final ci = medianInterval([for (final p in scenePairs) averageChange(p)]);
    final String verdictText;
    if (scene == nullScene) {
      verdictText = gate ? 'null ok' : 'null INVALID';
    } else {
      final verdict = sceneVerdict(
        ci: ci,
        p99WithinBudget: withinBudget(scenePairs),
      );
      verdicts.add(verdict);
      verdictText = verdict.name.toUpperCase();
    }
    rows.add(_row(scene, scenePairs, ci, verdictText));
  }
  final verdict = overallVerdict(nullGate: gate, scenes: verdicts);
  final runs = {for (final trace in valid) trace.run.split('g').first};
  final invocations = {for (final trace in valid) trace.run};
  final intervals = [for (final trace in valid) trace.metrics.interval];
  final text = StringBuffer()
    ..writeln(
      'runs ${runs.length} (${invocations.length} invocations), '
      'load ${_range(loads)}, '
      'interval ${intervals.isEmpty ? '-' : _ms(median(intervals))} ms, '
      'null resolution '
      '${nullCi == null ? '-' : '±${_pct((nullCi.upper - nullCi.lower) / 2)}%'}',
    );
  if (invalid.isNotEmpty) {
    text.writeln('invalid runs: ${(invalid.toList()..sort()).join(', ')}');
  }
  text
    ..writeln(
      '| scene | pairs | avg build ms base → cand | median Δ% | 95% CI '
      '| p99 build ms | p99 raster ms | verdict |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|')
    ..writeAll(rows.map((row) => '$row\n'))
    ..writeln('overall: ${verdict.name.toUpperCase()}');
  return (text: text.toString(), verdict: verdict);
}

String _row(
  String scene,
  List<TracePair> pairs,
  ConfidenceInterval? ci,
  String verdict,
) {
  String sides(double Function(TraceMetrics m) metric) =>
      '${_ms(median([for (final p in pairs) metric(p.base)]))} → '
      '${_ms(median([for (final p in pairs) metric(p.cand)]))}';
  final name = scene == nullScene ? '$scene (null)' : scene;
  final change = median([for (final p in pairs) averageChange(p)]);
  final interval = ci == null
      ? '-'
      : '[${_pct(ci.lower)}, ${_pct(ci.upper)}]';
  return '| $name | ${pairs.length} | ${sides((m) => m.average)} '
      '| ${_pct(change)} | $interval | ${sides((m) => m.p99Build)} '
      '| ${sides((m) => m.p99Raster)} | $verdict |';
}

String _ms(double value) => value.toStringAsFixed(2);

String _pct(double value) => value.toStringAsFixed(1);

String _range(List<double> values) {
  if (values.isEmpty) return '-';
  final sorted = [...values]..sort();
  return '${sorted.first.toStringAsFixed(1)}–${sorted.last.toStringAsFixed(1)}';
}
