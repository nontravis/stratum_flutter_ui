import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Frame budget at 120 Hz, in milliseconds (spec section 9.5).
const budget = 8.3;

/// Largest accepted rise of the average build time, in percent.
const maxAverageRise = 5.0;

/// Largest distance of a trace's display period from its run's median
/// period, or from the comparison's, as a fraction of that median.
const maxPeriodDrift = 0.1;

/// Smallest share of the frames a traced window holds at its display
/// period; a trace with fewer lost frames (spec section 9.5).
const minFrameShare = 0.9;

/// Length of every traced window, in milliseconds: `traceWindow` in
/// `integration_test/perf/perf_host.dart`.
const traceWindowMs = 2000.0;

/// Every scene in run order: the keys of `perfScenes` in
/// `integration_test/perf/perf_scenes.dart`.
const catalog = ['S2-plain', 'S1', 'S1-fast', 'S2', 'S2-box', 'S3', 'S4', 'S5'];

/// Most runs one comparison holds: 24 blocks per scene (spec section 9.5).
const maxRuns = 24;

/// Most runs one `--trace-full` call holds: 16 traces, all the binding
/// sends the driver in one message after the last test.
const maxFullRuns = 4;

/// The null-control scene, judged only by the null gate.
const nullScene = 'S2-plain';

/// Root of the run folders, relative to `example/`.
const abbaRoot = 'build/perf/abba';

/// Opens the line the app prints when a run starts: `runMarker` in
/// `integration_test/perf/perf_trace.dart`.
const runMarker = 'PERF_RUN ';

/// Opens the line the app prints after each trace: `summaryMarker` in
/// `integration_test/perf/perf_trace.dart`.
const summaryMarker = 'PERF_SUMMARY ';

/// Where `flutter build macos --profile` writes the app.
const _builtApp = 'build/macos/Build/Products/Profile/stratum_ui_example.app';

const _target = '--target=integration_test/layout_perf_test.dart';

const _usage =
    'usage: dart run tool/perf_abba.dart report\n'
    '       dart run tool/perf_abba.dart run --runs <n> [--from <first>]\n'
    '       dart run tool/perf_abba.dart run --trace-full <scene> --runs <n>';

/// The verdict of a scene or a comparison (spec section 9.5).
enum Verdict { pass, fail, inconclusive, invalid }

/// The metrics read from one trace's summary. The display period is the
/// 10th percentile of the gaps between frame starts, in milliseconds;
/// [frames] counts the frames the trace holds, and [span] is the time from
/// the first frame's start to the last one's, in milliseconds.
typedef TraceMetrics = ({
  double average,
  double p99Build,
  double p99Raster,
  double period,
  int frames,
  double span,
});

/// One trace: its run folder (`r<run>`) and its report key.
typedef Trace = ({
  String run,
  String scene,
  String side,
  int pair,
  TraceMetrics metrics,
});

/// The four traces of one scene in one run, in the order baseline,
/// current, current, baseline (spec section 9.4).
typedef Block = ({
  TraceMetrics base1,
  TraceMetrics cand1,
  TraceMetrics cand2,
  TraceMetrics base2,
});

/// A 95% interval for the median block change, in percent.
typedef ConfidenceInterval = ({double lower, double upper});

/// Runs and judges the in-process ABBA benchmark (spec sections 9.4 and
/// 9.5).
///
/// Usage, from `example/`:
/// - `dart run tool/perf_abba.dart run --runs 12` builds the profile app
///   once and runs all 12 runs in one `flutter drive` invocation, writing
///   each trace's summary as the app prints it, then reports.
/// - `dart run tool/perf_abba.dart run --from 13 --runs 12` adds the one
///   escalation, up to 24 runs (24 blocks per scene), for the scenes the
///   stored runs leave INCONCLUSIVE, plus S2-plain.
/// - `dart run tool/perf_abba.dart run --trace-full <scene> --runs <n>`
///   keeps the full timelines of one scene for at most 4 runs; it never
///   enters a verdict.
/// - `dart run tool/perf_abba.dart report` judges the stored runs again.
///
/// Prints the report, writes it to `build/perf/abba/report.md`, and exits
/// with 0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE.
Future<void> main(List<String> args) async {
  switch (args) {
    case ['report']:
      exitCode = _report();
    case ['run', ...final options] when _option(options, '--runs') != null:
      final runs = _option(options, '--runs')!;
      final full = _text(options, '--trace-full');
      exitCode = full == null
          ? await _run(from: _option(options, '--from') ?? 1, runs: runs)
          : await _traceFull(scene: full, runs: runs);
    default:
      stderr.writeln(_usage);
      exitCode = 64;
  }
}

String? _text(List<String> options, String name) {
  final index = options.indexOf(name);
  return index < 0 || index + 1 >= options.length ? null : options[index + 1];
}

int? _option(List<String> options, String name) {
  return int.tryParse(_text(options, name) ?? '');
}

/// Why runs [from] to `from + runs - 1` cannot run, or null when they can.
String? runRangeError({required int from, required int runs}) {
  final last = from + runs - 1;
  if (from < 1 || runs < 1 || last > maxRuns) {
    return 'runs $from to $last fall outside 1 to $maxRuns '
        '(24 blocks per scene)';
  }
  return null;
}

/// Why new runs on [current] cannot join the runs stored with [stored]
/// (run folder to code state), or null when every stored run folder
/// recorded [current] (spec section 9.4).
String? codeStateError(Map<String, String> stored, String current) {
  final others = [
    for (final MapEntry(key: folder, value: state) in stored.entries)
      if (state != current) folder,
  ]..sort();
  if (others.isEmpty) return null;
  return '${others.join(', ')} ran on another code state than $current: '
      'rm -rf $abbaRoot for a new comparison';
}

/// Why `run --trace-full [scene] --runs [runs]` cannot run, or null when
/// it can (spec section 9.4).
String? traceFullError({required String scene, required int runs}) {
  if (!catalog.contains(scene)) {
    return 'no scene $scene; the scenes are ${catalog.join(', ')}';
  }
  if (runs < 1 || runs > maxFullRuns) {
    return '--trace-full holds 1 to $maxFullRuns runs '
        '(${maxFullRuns * 4} traces in one message), not $runs';
  }
  return null;
}

/// Arguments that build the profile app for runs [from] to
/// `from + runs - 1` of [scenes]; [full] keeps every timeline.
List<String> buildArgs({
  required int from,
  required int runs,
  required List<String> scenes,
  bool full = false,
}) {
  return [
    'build',
    'macos',
    '--profile',
    _target,
    '--dart-define=PERF_FROM=$from',
    '--dart-define=PERF_RUNS=$runs',
    '--dart-define=PERF_SCENES=${scenes.join(',')}',
    '--dart-define=PERF_FULL=$full',
  ];
}

/// Arguments that run the prebuilt app, so the invocation does not build.
const driveArgs = [
  'drive',
  '--profile',
  '--endless-trace-buffer',
  '-d',
  'macos',
  '--driver=test_driver/perf_driver.dart',
  _target,
  '--use-application-binary=$_builtApp',
];

/// Run folders under [root] that runs [from] to `from + runs - 1` would
/// write into but that exist already.
List<String> clashingRuns(
  Directory root, {
  required int from,
  required int runs,
}) {
  return [
    for (var run = from; run < from + runs; run++)
      if (Directory('${root.path}/r$run').existsSync()) '${root.path}/r$run',
  ];
}

/// The code under test, as `code.txt` records it (spec section 9.4):
/// `git rev-parse HEAD` and a hash of `git diff HEAD -- lib example`, both
/// run from the repository root.
Future<String> codeState() async {
  final head = await Process.run('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: '..');
  final diff = await Process.run('sh', [
    '-c',
    'git diff HEAD -- lib example | shasum',
  ], workingDirectory: '..');
  final hash = (diff.stdout as String).split(' ').first;
  return '${(head.stdout as String).trim()} $hash';
}

/// The scenes a call measures (spec section 9.5): each scene that
/// [verdicts] leaves INCONCLUSIVE, plus S2-plain, which the null gate
/// judges over every run, in catalog order. With no stored run every scene
/// is INCONCLUSIVE, so a first call measures the whole catalog.
List<String> escalationScenes(Map<String, Verdict> verdicts) {
  return [
    for (final scene in catalog)
      if (scene == nullScene || verdicts[scene] == Verdict.inconclusive) scene,
  ];
}

/// The scenes of a `run --from [from]` call against [stored] traces, or a
/// refusal with its reason (spec section 9.5). `from` 1 to 12 measures the
/// whole catalog, the first comparison's runs. Above 12, refuses while the
/// stored S2-plain interval exists and excludes 0 (an INVALID comparison is
/// not escalated; a missing interval still allows runs), refuses when no
/// scene is INCONCLUSIVE, else gives the INCONCLUSIVE scenes plus S2-plain
/// in catalog order.
({List<String> scenes, String? error}) callScenes({
  required int from,
  required List<Trace> stored,
}) {
  if (from <= 12) return (scenes: catalog, error: null);
  final judged = judge(stored, loads: const [], scenes: catalog);
  if (judged.nullCi != null && !nullGatePasses(judged.nullCi)) {
    return (
      scenes: const [],
      error:
          'the stored runs are INVALID (the null interval excludes 0); '
          'run --from above 12 refuses, and the comparison runs again',
    );
  }
  final scenes = escalationScenes(judged.scenes);
  if (scenes.length == 1) {
    return (
      scenes: const [],
      error: 'the stored runs leave no scene INCONCLUSIVE; no run is added',
    );
  }
  return (scenes: scenes, error: null);
}

/// The run number of a `PERF_RUN <run>` line, or null for any other line.
int? runMark(String line) {
  final index = line.indexOf(runMarker);
  if (index < 0) return null;
  return int.tryParse(line.substring(index + runMarker.length).trim());
}

final _summaryKey = RegExp(r'^r\d+\.[^.]+\.(base|cand)\.[12]$');

/// The summary a `PERF_SUMMARY` line carries, or null for a line without
/// the marker. `flutter drive` prefixes the app's lines with `flutter: `,
/// so the marker may sit anywhere in the line.
///
/// Throws a [FormatException] when the line holds no complete summary: a
/// cut line, a key other than `r<run>.<scene>.<side>.<pair>`, or fewer than
/// two frames.
Map<String, dynamic>? summaryOf(String line) {
  final index = line.indexOf(summaryMarker);
  if (index < 0) return null;
  final payload = line.substring(index + summaryMarker.length);
  final json = jsonDecode(payload);
  if (json
      case {
        'key': final String key,
        'average': num _,
        'p99Build': num _,
        'p99Raster': num _,
        'begins': final List<dynamic> begins,
      }
      when _summaryKey.hasMatch(key) &&
          begins.length >= 2 &&
          begins.every((begin) => begin is num)) {
    return json as Map<String, dynamic>;
  }
  throw FormatException('not a complete summary', _clip(payload));
}

/// Writes each summary line of [lines], the stdout of `flutter drive`, to
/// `r<run>/<scene>.<side>.<pair>.summary.json` under [root] as it arrives,
/// and on each run line records [load] and [code] in that run's folder
/// (spec section 9.4). Hands every other line to [echo], stdout by
/// default. Returns one problem per line that does not parse as a complete
/// summary; that line is skipped.
Future<List<String>> recordDrive(
  Stream<String> lines, {
  required Directory root,
  required String code,
  required Future<String> Function() load,
  void Function(String line)? echo,
}) async {
  final log = echo ?? stdout.writeln;
  final problems = <String>[];
  await for (final line in lines) {
    final run = runMark(line);
    if (run != null) {
      final folder = Directory('${root.path}/r$run')
        ..createSync(recursive: true);
      File('${folder.path}/code.txt').writeAsStringSync(code);
      final uptime = (await load()).trim();
      File('${folder.path}/load.txt').writeAsStringSync(uptime);
      log('run $run: $uptime');
      continue;
    }
    final Map<String, dynamic>? summary;
    try {
      summary = summaryOf(line);
    } on FormatException catch (error) {
      final problem =
          'skipped a summary line that does not parse (${error.message}): '
          '${_clip(line)}';
      problems.add(problem);
      log(problem);
      continue;
    }
    if (summary == null) {
      log(line);
      continue;
    }
    final key = summary['key'] as String;
    final dot = key.indexOf('.');
    final folder = Directory('${root.path}/${key.substring(0, dot)}')
      ..createSync(recursive: true);
    File('${folder.path}/${key.substring(dot + 1)}.summary.json')
        .writeAsStringSync(jsonEncode(summary));
    log('$key: ${(summary['begins'] as List).length} frames');
  }
  return problems;
}

String _clip(String text) {
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}

/// Builds the profile app with [args]; false when the build fails.
Future<bool> _build(List<String> args) async {
  final build = await Process.start(
    'flutter',
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await build.exitCode == 0) return true;
  stderr.writeln('flutter build failed');
  return false;
}

Future<String> _uptime() async {
  return (await Process.run('uptime', const [])).stdout as String;
}

Future<int> _run({required int from, required int runs}) async {
  final rangeError = runRangeError(from: from, runs: runs);
  if (rangeError != null) {
    stderr.writeln(rangeError);
    return 64;
  }
  final root = Directory(abbaRoot);
  final clashes = clashingRuns(root, from: from, runs: runs);
  if (clashes.isNotEmpty) {
    stderr.writeln(
      '${clashes.join(', ')} exist: rm -rf $abbaRoot for a new comparison, '
      'or pass --from after the last stored run',
    );
    return 64;
  }
  final code = await codeState();
  final stored = root.existsSync() ? readRuns(root) : null;
  if (stored != null) {
    final stateError = codeStateError(stored.codeStates, code);
    if (stateError != null) {
      stderr.writeln(stateError);
      return 64;
    }
  }
  // The call's scenes: the whole catalog through run 12, or an escalation
  // chosen from the stored runs above it (spec section 9.5).
  final call = callScenes(from: from, stored: stored?.traces ?? const []);
  if (call.error != null) {
    stderr.writeln(call.error);
    return 64;
  }
  final scenes = call.scenes;
  // One build and one invocation for the whole call (spec section 9.4).
  if (!await _build(buildArgs(from: from, runs: runs, scenes: scenes))) {
    return 1;
  }
  stdout.writeln(
    'runs $from to ${from + runs - 1} of ${scenes.join(', ')}. '
    'Keep the test window visible until the run ends.',
  );
  final drive = await Process.start('flutter', driveArgs);
  drive.stderr.listen(stderr.add);
  final problems = await recordDrive(
    drive.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    root: root,
    code: code,
    load: _uptime,
  );
  final exit = await drive.exitCode;
  for (final problem in problems) {
    stderr.writeln(problem);
  }
  if (exit != 0) {
    // Every summary the app printed is on disk: judge them.
    stderr.writeln(
      'flutter drive exited $exit; the stored runs are judged, and '
      '--from adds runs after the last stored run',
    );
  }
  final verdict = _writeReport();
  return verdict == null ? 64 : callExit(driveExit: exit, verdict: verdict);
}

Future<int> _traceFull({required String scene, required int runs}) async {
  final error = traceFullError(scene: scene, runs: runs);
  if (error != null) {
    stderr.writeln(error);
    return 64;
  }
  final args = buildArgs(from: 1, runs: runs, scenes: [scene], full: true);
  if (!await _build(args)) return 1;
  stdout.writeln('Keep the test window visible until the run ends.');
  final drive = await Process.start(
    'flutter',
    driveArgs,
    mode: ProcessStartMode.inheritStdio,
  );
  return drive.exitCode;
}

/// Judges the stored runs, prints the report, and writes it to
/// `build/perf/abba/report.md`; returns the overall verdict, or null when
/// [abbaRoot] holds no runs.
Verdict? _writeReport() {
  final root = Directory(abbaRoot);
  if (!root.existsSync()) {
    stderr.writeln('no runs in $abbaRoot');
    return null;
  }
  final (:traces, :loads, :codeStates) = readRuns(root);
  final result = judge(
    traces,
    loads: loads,
    scenes: catalog,
    codeStates: codeStates,
  );
  stdout.write(result.text);
  File('$abbaRoot/report.md').writeAsStringSync(result.text);
  return result.verdict;
}

int _report() {
  final verdict = _writeReport();
  return verdict == null ? 64 : exitCodeOf(verdict);
}

/// Reads the metrics of one summary: the JSON of a `PERF_SUMMARY` line, as
/// a `*.summary.json` file holds it.
TraceMetrics metricsOf(Map<String, dynamic> summary) {
  final begins = (summary['begins'] as List).cast<num>();
  double read(String key) => (summary[key] as num).toDouble();
  final gaps = [
    for (var i = 1; i < begins.length; i++) (begins[i] - begins[i - 1]) / 1000,
  ]..sort();
  return (
    average: read('average'),
    p99Build: read('p99Build'),
    p99Raster: read('p99Raster'),
    // Nearest-rank 10th percentile.
    period: gaps[math.max(0, (gaps.length * 0.1).ceil() - 1)],
    frames: begins.length,
    span: (begins.last - begins.first) / 1000,
  );
}

/// The trace in [fileName] of [run], or null when the name is not
/// `<scene>.<side>.<pair>.summary.json`.
Trace? traceOf(String run, String fileName, TraceMetrics metrics) {
  final parts = fileName.split('.');
  if (parts.length != 5 || parts[3] != 'summary' || parts[4] != 'json') {
    return null;
  }
  final [scene, side, pairText, _, _] = parts;
  final pair = int.tryParse(pairText);
  if (pair == null || (side != 'base' && side != 'cand')) return null;
  return (run: run, scene: scene, side: side, pair: pair, metrics: metrics);
}

/// Whether [metrics] holds fewer than [minFrameShare] of the frames its
/// traced window holds at its display period (spec section 9.5).
bool lostFrames(TraceMetrics metrics) {
  return metrics.frames < minFrameShare * traceWindowMs / metrics.period;
}

/// Whether [metrics] covers less than the traced window minus two frames at
/// its display period, which happens when the timeline recorder's buffer
/// drops the first frames (spec section 9.4).
bool shortTrace(TraceMetrics metrics) {
  return metrics.span < traceWindowMs - 2 * metrics.period;
}

/// Runs (`r<run>`) left out of the analysis, each with its reason (spec
/// section 9.5): a trace whose display period differs by more than
/// [maxPeriodDrift] from the run's median period or from the comparison's,
/// which also catches a run whose windows all opened on another display; a
/// trace that lost frames, named by side, because frames lost on the
/// current side only can signal a regression; or a short trace.
Map<String, String> invalidRuns(List<Trace> traces) {
  if (traces.isEmpty) return {};
  final overall = median([for (final t in traces) t.metrics.period]);
  final byRun = <String, List<Trace>>{};
  for (final trace in traces) {
    (byRun[trace.run] ??= []).add(trace);
  }
  final reasons = <String, String>{};
  for (final MapEntry(key: run, value: runTraces) in byRun.entries) {
    final runMedian = median([for (final t in runTraces) t.metrics.period]);
    final drifts = runTraces.any(
      (t) =>
          _drifts(t.metrics.period, runMedian) ||
          _drifts(t.metrics.period, overall),
    );
    final lostSides = {
      for (final t in runTraces)
        if (lostFrames(t.metrics)) t.side == 'base' ? 'baseline' : 'current',
    }.toList()..sort();
    final short = runTraces.any((t) => shortTrace(t.metrics));
    final parts = [
      if (drifts) 'display period',
      if (lostSides.isNotEmpty) 'lost frames on ${lostSides.join(' and ')}',
      if (short) 'short trace',
    ];
    if (parts.isNotEmpty) reasons[run] = parts.join('; ');
  }
  return reasons;
}

bool _drifts(double period, double reference) {
  return (period - reference).abs() > reference * maxPeriodDrift;
}

/// Scene to its blocks: the four traces of the scene in one run.
/// A block that misses any of its four traces is left out.
Map<String, List<Block>> blockTraces(List<Trace> traces) {
  final slots = <(String, String), Map<String, TraceMetrics>>{};
  for (final trace in traces) {
    (slots[(trace.run, trace.scene)] ??= {})['${trace.side}${trace.pair}'] =
        trace.metrics;
  }
  final blocks = <String, List<Block>>{};
  for (final MapEntry(key: (_, scene), value: slot) in slots.entries) {
    if (slot case {
      'base1': final base1,
      'cand1': final cand1,
      'cand2': final cand2,
      'base2': final base2,
    }) {
      (blocks[scene] ??= []).add((
        base1: base1,
        cand1: cand1,
        cand2: cand2,
        base2: base2,
      ));
    }
  }
  return blocks;
}

/// The block's change in average build time, in percent: both current
/// traces against both baseline traces, which cancels an effect of the
/// slot position (spec section 9.5).
double blockChange(Block block) {
  final base = block.base1.average + block.base2.average;
  final cand = block.cand1.average + block.cand2.average;
  return (cand / base - 1) * 100;
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

List<TraceMetrics> _baseOf(Block b) => [b.base1, b.base2];

List<TraceMetrics> _candOf(Block b) => [b.cand1, b.cand2];

/// Whether the current side keeps the p99 budget for build and for raster
/// (spec section 9.5).
bool withinBudget(List<Block> blocks) {
  bool keeps(double Function(TraceMetrics metrics) metric) {
    double mean(List<TraceMetrics> side) =>
        (metric(side.first) + metric(side.last)) / 2;
    final base = median([for (final b in blocks) ..._baseOf(b).map(metric)]);
    final cand = median([for (final b in blocks) ..._candOf(b).map(metric)]);
    final delta = median([
      for (final b in blocks) mean(_candOf(b)) - mean(_baseOf(b)),
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
/// [ci] is null when the scene has fewer than 6 blocks.
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

/// The exit code of a `run` call (spec section 9.5): 1 whenever
/// `flutter drive` exited non-zero, a cut call that never reached a
/// complete comparison; otherwise [verdict]'s exit code.
int callExit({required int driveExit, required Verdict verdict}) {
  return driveExit != 0 ? 1 : exitCodeOf(verdict);
}

/// The one-minute load average in an `uptime` line, or null.
double? loadOf(String uptime) {
  final match = RegExp(r'load averages?: ([\d.]+)').firstMatch(uptime);
  return match == null ? null : double.tryParse(match[1]!);
}

/// Every trace, recorded load, and recorded code state (run folder to
/// state) under [root].
({List<Trace> traces, List<double> loads, Map<String, String> codeStates})
readRuns(Directory root) {
  final traces = <Trace>[];
  final loads = <double>[];
  final codeStates = <String, String>{};
  for (final directory in root.listSync().whereType<Directory>()) {
    final run = directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final loadFile = File('${directory.path}/load.txt');
    final load = loadFile.existsSync()
        ? loadOf(loadFile.readAsStringSync())
        : null;
    if (load != null) loads.add(load);
    final codeFile = File('${directory.path}/code.txt');
    if (codeFile.existsSync()) {
      codeStates[run] = codeFile.readAsStringSync().trim();
    }
    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.summary.json')) continue;
      final summary =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final trace = traceOf(run, name, metricsOf(summary));
      if (trace != null) traces.add(trace);
    }
  }
  return (traces: traces, loads: loads, codeStates: codeStates);
}

/// A report line naming each recorded code state with its run folders, or
/// null when every run folder recorded the same state.
String? codeMismatch(Map<String, String> codeStates) {
  final byState = <String, List<String>>{};
  for (final MapEntry(key: folder, value: state) in codeStates.entries) {
    (byState[state] ??= []).add(folder);
  }
  if (byState.length < 2) return null;
  final states = byState.keys.toList()..sort();
  return 'code states differ: ${[for (final state in states) '$state in ${(byState[state]!..sort()).join(', ')}'].join('; ')}';
}

/// Judges [traces] and returns the report text, the overall verdict, the
/// verdict of each scene other than S2-plain, and the null control's
/// confidence interval (null below 6 S2-plain blocks).
({
  String text,
  Verdict verdict,
  Map<String, Verdict> scenes,
  ConfidenceInterval? nullCi,
})
judge(
  List<Trace> traces, {
  required List<double> loads,
  required List<String> scenes,
  Map<String, String> codeStates = const {},
}) {
  final invalid = invalidRuns(traces);
  final valid = [
    for (final trace in traces)
      if (!invalid.containsKey(trace.run)) trace,
  ];
  final blocks = blockTraces(valid);
  final nullCi = medianInterval([
    for (final block in blocks[nullScene] ?? const <Block>[])
      blockChange(block),
  ]);
  final gate = nullGatePasses(nullCi);
  final rows = <String>[];
  final verdicts = <String, Verdict>{};
  for (final scene in {...scenes, ...blocks.keys}.toList()..sort()) {
    final sceneBlocks = blocks[scene] ?? const <Block>[];
    if (sceneBlocks.isEmpty) {
      // An expected scene without valid blocks stays in the report: spec
      // section 9.5 makes fewer than 6 blocks INCONCLUSIVE.
      if (scene != nullScene) verdicts[scene] = Verdict.inconclusive;
      final name = scene == nullScene ? '$scene (null)' : scene;
      final verdict = scene == nullScene ? 'null INVALID' : 'INCONCLUSIVE';
      rows.add('| $name | 0 | - | - | - | - | - | $verdict |');
      continue;
    }
    final ci = medianInterval([for (final b in sceneBlocks) blockChange(b)]);
    final String verdictText;
    if (scene == nullScene) {
      verdictText = gate ? 'null ok' : 'null INVALID';
    } else {
      final verdict = sceneVerdict(
        ci: ci,
        p99WithinBudget: withinBudget(sceneBlocks),
      );
      verdicts[scene] = verdict;
      verdictText = verdict.name.toUpperCase();
    }
    rows.add(_row(scene, sceneBlocks, ci, verdictText));
  }
  final verdict = overallVerdict(nullGate: gate, scenes: verdicts.values);
  final runs = {for (final trace in valid) trace.run};
  final periods = [for (final trace in valid) trace.metrics.period];
  final text = StringBuffer()
    ..writeln(
      'runs ${runs.length}, '
      'load ${_range(loads)}, '
      'interval ${periods.isEmpty ? '-' : _ms(median(periods))} ms, '
      'null resolution '
      '${nullCi == null ? '-' : '±${_pct((nullCi.upper - nullCi.lower) / 2)}%'}',
    );
  if (invalid.isNotEmpty) {
    final names = invalid.keys.toList()..sort();
    text.writeln(
      'invalid runs: '
      '${[for (final run in names) '$run (${invalid[run]})'].join(', ')}',
    );
  }
  final mismatch = codeMismatch(codeStates);
  if (mismatch != null) text.writeln(mismatch);
  text
    ..writeln(
      '| scene | blocks | avg build ms base → cand | median Δ% | 95% CI '
      '| p99 build ms | p99 raster ms | verdict |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|')
    ..writeAll(rows.map((row) => '$row\n'))
    ..writeln('overall: ${verdict.name.toUpperCase()}');
  return (
    text: text.toString(),
    verdict: verdict,
    scenes: verdicts,
    nullCi: nullCi,
  );
}

String _row(
  String scene,
  List<Block> blocks,
  ConfidenceInterval? ci,
  String verdict,
) {
  String sides(double Function(TraceMetrics m) metric) =>
      '${_ms(median([for (final b in blocks) ..._baseOf(b).map(metric)]))} → '
      '${_ms(median([for (final b in blocks) ..._candOf(b).map(metric)]))}';
  final name = scene == nullScene ? '$scene (null)' : scene;
  final change = median([for (final b in blocks) blockChange(b)]);
  final interval = ci == null ? '-' : '[${_pct(ci.lower)}, ${_pct(ci.upper)}]';
  return '| $name | ${blocks.length} | ${sides((m) => m.average)} '
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
