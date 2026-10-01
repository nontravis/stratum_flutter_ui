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

/// Scenes per group: `perfGroups` in
/// `integration_test/perf/perf_scenes.dart`.
const groupScenes = <int, List<String>>{
  1: ['S2-plain', 'S1', 'S1-fast', 'S2'],
  2: ['S2-plain', 'S2-box', 'S3'],
  3: ['S2-plain', 'S4', 'S5'],
};

/// Most runs one comparison holds: 24 pairs per scene (spec section 9.5).
const maxRuns = 12;

/// The null-control scene, judged only by the null gate.
const nullScene = 'S2-plain';

/// Root of the run folders, relative to `example/`.
const abbaRoot = 'build/perf/abba';

/// Folder of the prebuilt profile apps, one per group, relative to
/// `example/`.
const appsRoot = 'build/perf-apps';

/// Where `flutter build macos --profile` writes the app.
const _builtApp = 'build/macos/Build/Products/Profile/stratum_ui_example.app';

const _target = '--target=integration_test/layout_perf_test.dart';

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

/// Arguments that build [group]'s profile app with its `PERF_GROUP`.
List<String> buildArgs(int group) {
  return [
    'build',
    'macos',
    '--profile',
    _target,
    '--dart-define=PERF_GROUP=$group',
  ];
}

/// Arguments that run [group] on its prebuilt app, so no invocation builds.
List<String> driveArgs(int group) {
  return [
    'drive',
    '--profile',
    '--endless-trace-buffer',
    '-d',
    'macos',
    '--driver=test_driver/perf_driver.dart',
    _target,
    '--use-application-binary=$appsRoot/g$group.app',
  ];
}

/// Whether run [run] already holds a trace off the frame interval, which
/// leaves out the whole run (spec section 9.5).
bool runLostFrames(List<Trace> traces, int run) {
  return invalidRuns(traces).contains('r$run');
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
  // One build per group for the whole call: every invocation of a group
  // then runs the same binary, and no invocation pays for a build.
  for (final group in groups) {
    final build = await Process.start(
      'flutter',
      buildArgs(group),
      mode: ProcessStartMode.inheritStdio,
    );
    if (await build.exitCode != 0) {
      stderr.writeln('flutter build failed for group $group');
      return 1;
    }
    final app = '$appsRoot/g$group.app';
    final copy = await Process.run('sh', [
      '-c',
      'rm -rf "$app" && mkdir -p $appsRoot && cp -R "$_builtApp" "$app"',
    ]);
    if (copy.exitCode != 0) {
      stderr.writeln('could not copy the group $group app: ${copy.stderr}');
      return 1;
    }
  }
  stdout.writeln('Keep the test window visible until the run ends.');
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
        driveArgs(group),
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
      if (runLostFrames(readRuns(Directory(abbaRoot)).traces, run)) {
        stderr.writeln(
          'run $run lost frames in group $group (window hidden or machine '
          'starved); the run is left out, so its other groups are skipped',
        );
        break;
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
  final result = judge(
    traces,
    loads: loads,
    scenes: [for (final keys in groupScenes.values) ...keys],
  );
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

/// The run `r<run>` that a run folder `r<run>g<group>` belongs to.
String runOf(String folder) => folder.split('g').first;

/// Runs (`r<run>`, every group of the run) with a trace whose frame
/// interval differs by more than [maxIntervalDrift] from the run's median
/// interval, or from the comparison's median interval, which catches a run
/// whose windows all opened on another display (spec section 9.5).
Set<String> invalidRuns(List<Trace> traces) {
  if (traces.isEmpty) return {};
  final overall = median([for (final t in traces) t.metrics.interval]);
  final byRun = <String, List<Trace>>{};
  for (final trace in traces) {
    (byRun[runOf(trace.run)] ??= []).add(trace);
  }
  return {
    for (final MapEntry(key: run, value: runTraces) in byRun.entries)
      if (_drifts(
            runTraces,
            median([for (final t in runTraces) t.metrics.interval]),
          ) ||
          _drifts(runTraces, overall))
        run,
  };
}

bool _drifts(List<Trace> traces, double reference) {
  return traces.any(
    (t) =>
        (t.metrics.interval - reference).abs() > reference * maxIntervalDrift,
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
  required List<String> scenes,
}) {
  final invalid = invalidRuns(traces);
  final valid = [
    for (final trace in traces)
      if (!invalid.contains(runOf(trace.run))) trace,
  ];
  final pairs = pairTraces(valid);
  final nullCi = medianInterval([
    for (final pair in pairs[nullScene] ?? const <TracePair>[])
      averageChange(pair),
  ]);
  final gate = nullGatePasses(nullCi);
  final rows = <String>[];
  final verdicts = <Verdict>[];
  for (final scene in {...scenes, ...pairs.keys}.toList()..sort()) {
    final scenePairs = pairs[scene] ?? const <TracePair>[];
    if (scenePairs.isEmpty) {
      // An expected scene without valid pairs stays in the report: spec
      // section 9.5 makes fewer than 6 pairs INCONCLUSIVE.
      if (scene != nullScene) verdicts.add(Verdict.inconclusive);
      final name = scene == nullScene ? '$scene (null)' : scene;
      final verdict = scene == nullScene ? 'null INVALID' : 'INCONCLUSIVE';
      rows.add('| $name | 0 | - | - | - | - | - | $verdict |');
      continue;
    }
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
  final runs = {for (final trace in valid) runOf(trace.run)};
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
  final interval = ci == null ? '-' : '[${_pct(ci.lower)}, ${_pct(ci.upper)}]';
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
