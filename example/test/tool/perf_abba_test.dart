import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scenes.dart' show perfScenes;
import '../../integration_test/perf/perf_trace.dart' show runLine, summaryLine;
import '../../tool/perf_abba.dart' hide main;

TraceMetrics _metrics({
  double average = 0.25,
  double p99Build = 0.5,
  double p99Raster = 3.5,
  double period = 6.94,
  int frames = 288,
  double span = 1993,
}) {
  return (
    average: average,
    p99Build: p99Build,
    p99Raster: p99Raster,
    period: period,
    frames: frames,
    span: span,
  );
}

Trace _trace(
  String run,
  String scene,
  String side,
  int pair, {
  double average = 0.25,
  double period = 6.94,
  int frames = 288,
  double span = 1993,
}) {
  return (
    run: run,
    scene: scene,
    side: side,
    pair: pair,
    metrics: _metrics(
      average: average,
      period: period,
      frames: frames,
      span: span,
    ),
  );
}

/// The four traces of one block of [scene] in run folder [run]; each side
/// has the same average in both of its slots.
List<Trace> _block(
  String run,
  String scene, {
  double base = 0.2,
  double cand = 0.2,
}) {
  return [
    _trace(run, scene, 'base', 1, average: base),
    _trace(run, scene, 'cand', 1, average: cand),
    _trace(run, scene, 'cand', 2, average: cand),
    _trace(run, scene, 'base', 2, average: base),
  ];
}

/// Blocks of [scene] over [changes], one block per entry, in run folders
/// r1 on.
List<Trace> _blocks(String scene, List<double> changes) {
  return [
    for (var i = 0; i < changes.length; i++)
      ..._block('r${i + 1}', scene, cand: 0.2 * (1 + changes[i] / 100)),
  ];
}

/// The block changes of the phase 3 S4 RCA (12 values, median −10.1%).
const _rcaS4 = [
  -46.1,
  -4.9,
  -6.5,
  -10.4,
  7.3,
  0.0,
  -48.2,
  -20.7,
  -14.2,
  -9.8,
  -21.6,
  -9.0,
];

void main() {
  group('ciRank', () {
    test('matches spec section 9.5', () {
      expect(ciRank(5), isNull);
      expect(ciRank(6), 1);
      expect(ciRank(12), 3);
      expect(ciRank(24), 7);
      expect(ciRank(36), 12);
      expect(ciRank(72), 28);
    });
  });

  group('medianInterval', () {
    test('gives the RCA S4 interval', () {
      expect(medianInterval(_rcaS4), (lower: -21.6, upper: -4.9));
    });

    test('gives no interval below 6 values', () {
      expect(medianInterval([1, 2, 3, 4, 5]), isNull);
    });
  });

  group('metricsOf', () {
    test(
      'reads the three metrics, the frame count, and the display period',
      () {
        final metrics = metricsOf({
          'average': 0.31,
          'p99Build': 1.02,
          'p99Raster': 3.4,
          'begins': [for (var i = 0; i < 10; i++) i * 6940, 100000],
        });
        expect(metrics.average, 0.31);
        expect(metrics.p99Build, 1.02);
        expect(metrics.p99Raster, 3.4);
        expect(metrics.frames, 11);
        expect(metrics.period, closeTo(6.94, 1e-9));
        expect(metrics.span, closeTo(100, 1e-9));
      },
    );

    test('takes the 10th-percentile gap, which skipped frames do not move', () {
      // Nine of ten gaps skip a frame: the median gap would read 13.88 ms.
      final metrics = metricsOf({
        'average': 0.31,
        'p99Build': 1.02,
        'p99Raster': 3.4,
        'begins': [0, 6940, for (var i = 1; i <= 9; i++) 6940 + i * 13880],
      });
      expect(metrics.period, closeTo(6.94, 1e-9));
    });
  });

  group('traceOf', () {
    test('reads scene, side, and pair from the report key', () {
      final trace = traceOf('r1', 'S2-plain.base.2.summary.json', _metrics());
      expect(trace?.run, 'r1');
      expect(trace?.scene, 'S2-plain');
      expect(trace?.side, 'base');
      expect(trace?.pair, 2);
    });

    test('skips files that are not ABBA summaries', () {
      expect(traceOf('r1', 'S1.summary.json', _metrics()), isNull);
      expect(traceOf('r1', 'S1.left.1.summary.json', _metrics()), isNull);
      expect(traceOf('r1', 'S1.base.1.timeline.json', _metrics()), isNull);
      expect(
        traceOf('r1', 'S1.base.1.timeline_summary.json', _metrics()),
        isNull,
      );
    });
  });

  group('blockTraces', () {
    test('makes one block per run folder and scene', () {
      final blocks = blockTraces([
        ..._block('r1', 'S1', base: 0.2, cand: 0.3),
        ..._block('r1', 'S2-plain'),
        ..._block('r2', 'S1', base: 0.4, cand: 0.4),
        ..._block('r1', 'S2'),
      ]);
      expect(blocks.keys, unorderedEquals(['S1', 'S2', 'S2-plain']));
      expect([
        for (final block in blocks['S1']!) block.cand1.average,
      ], unorderedEquals([0.3, 0.4]));
    });

    test('leaves out a block that misses any of its four traces', () {
      final blocks = blockTraces([
        ..._block('r1', 'S1'),
        ..._block('r2', 'S1').take(3),
      ]);
      expect(blocks['S1'], hasLength(1));
    });
  });

  group('blockChange', () {
    test('compares the sums of the two slots of each side', () {
      final change = blockChange((
        base1: _metrics(average: 0.2),
        cand1: _metrics(average: 0.25),
        cand2: _metrics(average: 0.3),
        base2: _metrics(average: 0.3),
      ));
      expect(change, closeTo(10, 1e-9));
    });
  });

  group('lostFrames', () {
    test('needs 90% of the frames the window holds at its period', () {
      // 2000 ms at 6.94 ms holds 288 frames; 90% is 259.4.
      expect(lostFrames(_metrics(frames: 259)), isTrue);
      expect(lostFrames(_metrics(frames: 260)), isFalse);
      expect(lostFrames(_metrics(period: 16.67, frames: 110)), isFalse);
    });
  });

  group('shortTrace', () {
    test('needs the window minus two frames at its display period', () {
      // 2000 ms less two 6.94 ms frames is 1986.12 ms.
      expect(shortTrace(_metrics(span: 1986)), isTrue);
      expect(shortTrace(_metrics(span: 1986.2)), isFalse);
      expect(shortTrace(_metrics(period: 16.67, span: 1967)), isFalse);
    });
  });

  group('invalidRuns', () {
    test("marks a run invalid when one trace's display period drifts", () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          _trace('r1', 'S2', 'base', 1),
          _trace('r1', 'S2', 'cand', 1, period: 16.67),
          ..._block('r2', 'S1'),
        ]).keys,
        ['r1'],
      );
    });

    test('marks a run invalid when one whole scene ran on another '
        'display', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          ..._block('r1', 'S3'),
          _trace('r1', 'S4', 'base', 1, period: 16.67),
          _trace('r1', 'S4', 'cand', 1, period: 16.67),
          ..._block('r2', 'S1'),
        ]),
        {'r1': 'display period'},
      );
    });

    test('marks a run invalid when all of it ran on another display', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          ..._block('r2', 'S1'),
          ..._block('r3', 'S1'),
          _trace('r4', 'S1', 'base', 1, period: 16.67),
          _trace('r4', 'S1', 'cand', 1, period: 16.67),
        ]).keys,
        ['r4'],
      );
    });

    test('marks a run invalid on lost frames and names the side', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          _trace('r2', 'S4', 'base', 1),
          _trace('r2', 'S4', 'cand', 1, frames: 120),
          _trace('r3', 'S4', 'base', 1, frames: 19),
          _trace('r3', 'S4', 'cand', 1, frames: 130),
        ]),
        {
          'r2': 'lost frames on current',
          'r3': 'lost frames on baseline and current',
        },
      );
    });

    test('marks a run invalid on a short trace', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          _trace('r2', 'S1', 'base', 1),
          _trace('r2', 'S1', 'cand', 1, span: 1900),
        ]),
        {'r2': 'short trace'},
      );
    });
  });

  group('withinBudget', () {
    Block block(double base, double cand) => (
      base1: _metrics(p99Build: base, p99Raster: 3),
      cand1: _metrics(p99Build: cand, p99Raster: 3),
      cand2: _metrics(p99Build: cand, p99Raster: 3),
      base2: _metrics(p99Build: base, p99Raster: 3),
    );

    test('passes below 8.3 ms', () {
      expect(withinBudget([block(1, 7.9)]), isTrue);
    });

    test('fails at or above 8.3 ms when the baseline was below', () {
      expect(withinBudget([block(7, 8.3)]), isFalse);
    });

    test('accepts no worse than a baseline already over budget', () {
      expect(withinBudget([block(9, 8.9)]), isTrue);
      expect(withinBudget([block(9, 9.5)]), isFalse);
    });

    test('checks p99 raster too', () {
      expect(
        withinBudget([
          (
            base1: _metrics(p99Raster: 3),
            cand1: _metrics(p99Raster: 8.4),
            cand2: _metrics(p99Raster: 8.4),
            base2: _metrics(p99Raster: 3),
          ),
        ]),
        isFalse,
      );
    });
  });

  group('nullGatePasses', () {
    test('needs an interval that contains 0', () {
      expect(nullGatePasses((lower: -3, upper: 4)), isTrue);
      expect(nullGatePasses((lower: 0, upper: 4)), isTrue);
      expect(nullGatePasses((lower: 1, upper: 6)), isFalse);
      expect(nullGatePasses(null), isFalse);
    });
  });

  group('sceneVerdict', () {
    test('passes when the upper bound is at most +5%', () {
      expect(
        sceneVerdict(ci: (lower: -21.6, upper: -4.9), p99WithinBudget: true),
        Verdict.pass,
      );
      expect(
        sceneVerdict(ci: (lower: -1, upper: 5), p99WithinBudget: true),
        Verdict.pass,
      );
    });

    test('fails when the lower bound is above +5%', () {
      expect(
        sceneVerdict(ci: (lower: 5.1, upper: 9), p99WithinBudget: true),
        Verdict.fail,
      );
    });

    test('is inconclusive when the interval straddles +5% or is missing', () {
      expect(
        sceneVerdict(ci: (lower: 5, upper: 9), p99WithinBudget: true),
        Verdict.inconclusive,
      );
      expect(
        sceneVerdict(ci: (lower: -2, upper: 8), p99WithinBudget: true),
        Verdict.inconclusive,
      );
      expect(
        sceneVerdict(ci: null, p99WithinBudget: true),
        Verdict.inconclusive,
      );
    });

    test('fails on a missed budget, whatever the average', () {
      expect(
        sceneVerdict(ci: (lower: -20, upper: -5), p99WithinBudget: false),
        Verdict.fail,
      );
      expect(sceneVerdict(ci: null, p99WithinBudget: false), Verdict.fail);
    });
  });

  group('overallVerdict', () {
    test('orders INVALID, FAIL, INCONCLUSIVE, PASS', () {
      expect(
        overallVerdict(nullGate: false, scenes: [Verdict.fail]),
        Verdict.invalid,
      );
      expect(
        overallVerdict(
          nullGate: true,
          scenes: [Verdict.inconclusive, Verdict.fail],
        ),
        Verdict.fail,
      );
      expect(
        overallVerdict(
          nullGate: true,
          scenes: [Verdict.pass, Verdict.inconclusive],
        ),
        Verdict.inconclusive,
      );
      expect(
        overallVerdict(nullGate: true, scenes: [Verdict.pass, Verdict.pass]),
        Verdict.pass,
      );
    });

    test('maps verdicts to exit codes 0, 1, 1, 2', () {
      expect(exitCodeOf(Verdict.pass), 0);
      expect(exitCodeOf(Verdict.fail), 1);
      expect(exitCodeOf(Verdict.invalid), 1);
      expect(exitCodeOf(Verdict.inconclusive), 2);
    });
  });

  group('callExit', () {
    test('gives the verdict exit code when flutter drive exits 0', () {
      expect(callExit(driveExit: 0, verdict: Verdict.pass), 0);
      expect(callExit(driveExit: 0, verdict: Verdict.fail), 1);
      expect(callExit(driveExit: 0, verdict: Verdict.inconclusive), 2);
    });

    test('gives 1 whenever flutter drive exits non-zero, whatever the '
        'stored verdict', () {
      expect(callExit(driveExit: 1, verdict: Verdict.pass), 1);
      expect(callExit(driveExit: 2, verdict: Verdict.inconclusive), 1);
      expect(callExit(driveExit: 70, verdict: Verdict.fail), 1);
    });
  });

  group('loadOf', () {
    test('reads the one-minute load average', () {
      expect(
        loadOf('18:27  up 9 days, 5 users, load averages: 16.19 13.38 13.78'),
        16.19,
      );
      expect(
        loadOf(' 10:00:00 up 1 day,  load average: 0.52, 0.40, 0.31'),
        0.52,
      );
      expect(loadOf('no load here'), isNull);
    });
  });

  group('judge', () {
    test('passes S4 on the RCA data behind a quiet null control', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: [9.1, 16.4],
        scenes: const ['S2-plain', 'S4'],
      );
      expect(result.verdict, Verdict.pass);
      expect(result.text, contains('| scene | blocks |'));
      expect(result.text, contains('| S4 | 12 |'));
      expect(result.text, contains('[-21.6, -4.9]'));
      expect(result.text, contains('| S2-plain (null) | 6 |'));
      expect(result.text, contains('load 9.1–16.4'));
      expect(result.text, contains('overall: PASS'));
    });

    test('is INVALID when the null interval misses 0', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [3, 2, 1, 4, 5, 2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4'],
      );
      expect(result.verdict, Verdict.invalid);
      expect(result.text, contains('overall: INVALID'));
    });

    test('leaves an invalid run out and lists it with its reason', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
          _trace('r99', 'S4', 'base', 1),
          _trace('r99', 'S4', 'cand', 1, frames: 30),
          _trace('r99', 'S4', 'cand', 2),
          _trace('r99', 'S4', 'base', 2),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4'],
      );
      expect(result.text, contains('| S4 | 12 |'));
      expect(
        result.text,
        contains('invalid runs: r99 (lost frames on current)'),
      );
    });

    test('keeps an expected scene without blocks as INCONCLUSIVE', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4', 'S5'],
      );
      expect(
        result.text,
        contains('| S5 | 0 | - | - | - | - | - | INCONCLUSIVE |'),
      );
      expect(result.verdict, Verdict.inconclusive);
    });

    test('lists run folders that recorded another code state', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4'],
        codeStates: const {'r1': 'abc 111', 'r2': 'abc 111', 'r3': 'def 222'},
      );
      expect(
        result.text,
        contains('code states differ: abc 111 in r1, r2; def 222 in r3'),
      );
    });

    test('gives each judged scene its verdict, S2-plain left out', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
          ..._blocks('S1', [-2, 8, 1, 9, 3, 7]),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S1', 'S4', 'S5'],
      );
      expect(result.scenes, {
        'S1': Verdict.inconclusive,
        'S4': Verdict.pass,
        'S5': Verdict.inconclusive,
      });
    });
  });

  group('codeStateError', () {
    test('accepts runs on the stored code state', () {
      expect(codeStateError(const {}, 'abc 111'), isNull);
      expect(codeStateError(const {'r1': 'abc 111'}, 'abc 111'), isNull);
    });

    test('refuses runs on another code state', () {
      expect(
        codeStateError(const {'r1': 'abc 111', 'r2': 'abc 222'}, 'abc 111'),
        contains('r2'),
      );
    });
  });

  group('runRangeError', () {
    test('accepts runs within the cap of 24 runs', () {
      expect(runRangeError(from: 1, runs: 12), isNull);
      expect(runRangeError(from: 13, runs: 12), isNull);
    });

    test('refuses runs beyond the cap or outside 1', () {
      expect(runRangeError(from: 13, runs: 13), contains('1 to 24'));
      expect(runRangeError(from: 0, runs: 1), isNotNull);
      expect(runRangeError(from: 1, runs: 0), isNotNull);
    });
  });

  group('clashingRuns', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('abba'));
    tearDown(() => root.deleteSync(recursive: true));

    test('refuses run folders that exist', () {
      Directory('${root.path}/r2').createSync();
      expect(clashingRuns(root, from: 1, runs: 6), ['${root.path}/r2']);
      expect(clashingRuns(root, from: 3, runs: 4), isEmpty);
    });
  });

  group('one app', () {
    test('builds one profile app for the runs and scenes of a call', () {
      expect(buildArgs(from: 13, runs: 12, scenes: const ['S2-plain', 'S4']), [
        'build',
        'macos',
        '--profile',
        '--target=integration_test/layout_perf_test.dart',
        '--dart-define=PERF_FROM=13',
        '--dart-define=PERF_RUNS=12',
        '--dart-define=PERF_SCENES=S2-plain,S4',
        '--dart-define=PERF_FULL=false',
      ]);
      expect(
        buildArgs(from: 1, runs: 2, scenes: const ['S4'], full: true),
        contains('--dart-define=PERF_FULL=true'),
      );
    });

    test('drives the prebuilt app', () {
      expect(
        driveArgs,
        contains(
          '--use-application-binary='
          'build/macos/Build/Products/Profile/stratum_ui_example.app',
        ),
      );
      expect(driveArgs, contains('--endless-trace-buffer'));
      expect(driveArgs, contains('--driver=test_driver/perf_driver.dart'));
      expect(
        driveArgs,
        contains('--target=integration_test/layout_perf_test.dart'),
      );
    });

    test('lists the scenes of perfScenes in run order', () {
      expect(catalog, [for (final scene in perfScenes) scene.key]);
    });
  });

  group('summary lines', () {
    final appSummary = {
      'average_frame_build_time_millis': 0.31,
      '99th_percentile_frame_build_time_millis': 1.02,
      '99th_percentile_frame_rasterizer_time_millis': 3.4,
      'frame_begin_times': [for (var i = 0; i < 288; i++) 7000000 + i * 6940],
    };

    test('parse back the values the app encodes, behind the flutter: '
        'prefix', () {
      final line = 'flutter: ${summaryLine('r3.S2.cand.2', appSummary)}';
      final summary = summaryOf(line)!;
      expect(summary['key'], 'r3.S2.cand.2');
      final metrics = metricsOf(summary);
      expect(metrics.average, 0.31);
      expect(metrics.p99Build, 1.02);
      expect(metrics.p99Raster, 3.4);
      expect(metrics.frames, 288);
      expect(metrics.period, closeTo(6.94, 1e-9));
      expect(metrics.span, closeTo(287 * 6.94, 1e-9));
    });

    test('ignore lines without a marker', () {
      expect(summaryOf('flutter: 00:41 +16: r1.S1.base.1'), isNull);
      expect(runMark('flutter: 00:41 +16: r1.S1.base.1'), isNull);
    });

    test('read the run of a run line', () {
      expect(runMark('flutter: ${runLine(13)}'), 13);
    });

    test('refuse a cut line, a bad key, and fewer than two frames', () {
      final line = summaryLine('r3.S2.cand.2', appSummary);
      expect(
        () => summaryOf(line.substring(0, line.length - 40)),
        throwsFormatException,
      );
      expect(
        () => summaryOf(summaryLine('S2.cand.2', appSummary)),
        throwsFormatException,
      );
      expect(
        () => summaryOf(
          summaryLine('r3.S2.cand.2', {
            ...appSummary,
            'frame_begin_times': [7000000],
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('recordDrive', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('abba'));
    tearDown(() => root.deleteSync(recursive: true));

    Map<String, dynamic> summary(int frames) => {
      'average_frame_build_time_millis': 0.31,
      '99th_percentile_frame_build_time_millis': 1.02,
      '99th_percentile_frame_rasterizer_time_millis': 3.4,
      'frame_begin_times': [for (var i = 0; i < frames; i++) i * 6940],
    };

    Future<String> load() async => ' 18:27  up 9 days, load averages: 9.10 ';

    test('writes each summary to its run folder, records load and code per '
        'run, and reports a cut line', () async {
      final cut = summaryLine('r1.S1.cand.1', summary(288));
      final echoed = <String>[];
      final problems = await recordDrive(
        Stream.fromIterable([
          'Resolving dependencies...',
          'flutter: ${runLine(1)}',
          'flutter: ${summaryLine('r1.S1.base.1', summary(288))}',
          'flutter: ${cut.substring(0, 900)}',
          'flutter: ${summaryLine('r1.S1.cand.2', summary(287))}',
        ]),
        root: root,
        code: 'abc 111',
        load: load,
        echo: echoed.add,
      );

      expect(problems, hasLength(1));
      expect(problems.single, startsWith('skipped a summary line'));
      final run = '${root.path}/r1';
      expect(File('$run/code.txt').readAsStringSync(), 'abc 111');
      expect(
        File('$run/load.txt').readAsStringSync(),
        '18:27  up 9 days, load averages: 9.10',
      );
      expect(
        [
          for (final file in Directory(run).listSync())
            file.uri.pathSegments.last,
        ]..sort(),
        [
          'S1.base.1.summary.json',
          'S1.cand.2.summary.json',
          'code.txt',
          'load.txt',
        ],
      );
      final stored = readRuns(root);
      expect([for (final t in stored.traces) t.metrics.frames]..sort(), [
        287,
        288,
      ]);
      expect(stored.loads, [9.1]);
      expect(stored.codeStates, {'r1': 'abc 111'});
      expect(echoed, contains('Resolving dependencies...'));
    });

    test('writes a summary before the next line arrives, so a crash loses '
        'only the trace in progress', () async {
      final lines = StreamController<String>();
      final done = recordDrive(
        lines.stream,
        root: root,
        code: 'abc 111',
        load: load,
        echo: (_) {},
      );
      lines.add(summaryLine('r2.S4.base.1', summary(288)));
      await pumpEventQueue();

      final file = File('${root.path}/r2/S4.base.1.summary.json');
      expect(file.existsSync(), isTrue);
      expect(
        jsonDecode(file.readAsStringSync()),
        containsPair('key', 'r2.S4.base.1'),
      );
      await lines.close();
      expect(await done, isEmpty);
    });
  });

  group('escalationScenes', () {
    test('measures every scene when no run is stored', () {
      final verdicts = judge(const [], loads: const [], scenes: catalog).scenes;
      expect(escalationScenes(verdicts), catalog);
    });

    test(
      'measures the INCONCLUSIVE scenes in catalog order, plus S2-plain',
      () {
        expect(
          escalationScenes({
            'S1': Verdict.pass,
            'S1-fast': Verdict.inconclusive,
            'S2': Verdict.fail,
            'S2-box': Verdict.pass,
            'S3': Verdict.pass,
            'S4': Verdict.inconclusive,
            'S5': Verdict.pass,
          }),
          ['S2-plain', 'S1-fast', 'S4'],
        );
      },
    );

    test('leaves S2-plain alone when no scene is INCONCLUSIVE', () {
      expect(escalationScenes({'S1': Verdict.pass, 'S4': Verdict.fail}), [
        nullScene,
      ]);
    });
  });

  group('callScenes', () {
    test('measures the whole catalog on a first call', () {
      expect(callScenes(from: 1, stored: const []), (
        scenes: catalog,
        error: null,
      ));
    });

    test('measures the whole catalog on a continuation at or below run 12, '
        'skipping the escalation rules', () {
      final allPass = [
        ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
        for (final scene in catalog.where((s) => s != 'S2-plain'))
          ..._blocks(scene, _rcaS4),
      ];
      expect(callScenes(from: 5, stored: allPass), (
        scenes: catalog,
        error: null,
      ));
      expect(callScenes(from: 12, stored: allPass), (
        scenes: catalog,
        error: null,
      ));
    });

    test('above run 12, measures the INCONCLUSIVE scenes plus S2-plain, in '
        'catalog order', () {
      final stored = [
        ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
        ..._blocks('S1', _rcaS4),
        ..._blocks('S1-fast', [-2, 8, 1, 9, 3, 7]),
      ];
      final call = callScenes(from: 13, stored: stored);
      expect(call.error, isNull);
      expect(call.scenes, [
        'S2-plain',
        'S1-fast',
        'S2',
        'S2-box',
        'S3',
        'S4',
        'S5',
      ]);
    });

    test('refuses above run 12 when the stored S2-plain interval excludes '
        '0: an INVALID comparison is not escalated', () {
      final stored = [
        ..._blocks('S2-plain', [3, 2, 1, 4, 5, 2]),
        ..._blocks('S4', _rcaS4),
      ];
      final call = callScenes(from: 13, stored: stored);
      expect(call.error, isNotNull);
      expect(call.scenes, isEmpty);
    });

    test('refuses above run 12 when no scene is INCONCLUSIVE', () {
      final allPass = [
        ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
        for (final scene in catalog.where((s) => s != 'S2-plain'))
          ..._blocks(scene, _rcaS4),
      ];
      final call = callScenes(from: 13, stored: allPass);
      expect(
        call.error,
        'the stored runs leave no scene INCONCLUSIVE; no run is added',
      );
      expect(call.scenes, isEmpty);
    });

    test('a missing null interval still allows an escalation', () {
      // Fewer than 6 S2-plain blocks: no interval, so the refusal above
      // does not fire, and the escalation rule decides instead.
      final stored = [
        ..._blocks('S2-plain', [-3, 2, -1]),
        ..._blocks('S1', _rcaS4),
      ];
      final call = callScenes(from: 13, stored: stored);
      expect(call.error, isNull);
      expect(call.scenes, contains(nullScene));
    });
  });

  group('traceFullError', () {
    test('accepts one catalog scene for 1 to 4 runs', () {
      expect(traceFullError(scene: 'S4', runs: 1), isNull);
      expect(traceFullError(scene: 'S4', runs: 4), isNull);
    });

    test('refuses more than 4 runs, the 16 traces of one message', () {
      expect(traceFullError(scene: 'S4', runs: 5), contains('1 to 4'));
      expect(traceFullError(scene: 'S4', runs: 0), isNotNull);
    });

    test('refuses a scene outside the catalog', () {
      expect(traceFullError(scene: 'S9', runs: 1), contains('S9'));
    });
  });
}
