import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/perf_abba.dart' hide main;

TraceMetrics _metrics({
  double average = 0.25,
  double p99Build = 0.5,
  double p99Raster = 3.5,
  double period = 6.94,
  int frames = 288,
}) {
  return (
    average: average,
    p99Build: p99Build,
    p99Raster: p99Raster,
    period: period,
    frames: frames,
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
}) {
  return (
    run: run,
    scene: scene,
    side: side,
    pair: pair,
    metrics: _metrics(average: average, period: period, frames: frames),
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
/// r1g1 on.
List<Trace> _blocks(String scene, List<double> changes) {
  return [
    for (var i = 0; i < changes.length; i++)
      ..._block('r${i + 1}g1', scene, cand: 0.2 * (1 + changes[i] / 100)),
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
          'average_frame_build_time_millis': 0.31,
          '99th_percentile_frame_build_time_millis': 1.02,
          '99th_percentile_frame_rasterizer_time_millis': 3.4,
          'frame_begin_times': [for (var i = 0; i < 10; i++) i * 6940, 100000],
        });
        expect(metrics.average, 0.31);
        expect(metrics.p99Build, 1.02);
        expect(metrics.p99Raster, 3.4);
        expect(metrics.frames, 11);
        expect(metrics.period, closeTo(6.94, 1e-9));
      },
    );

    test('takes the 10th-percentile gap, which skipped frames do not move', () {
      // Nine of ten gaps skip a frame: the median gap would read 13.88 ms.
      final metrics = metricsOf({
        'average_frame_build_time_millis': 0.31,
        '99th_percentile_frame_build_time_millis': 1.02,
        '99th_percentile_frame_rasterizer_time_millis': 3.4,
        'frame_begin_times': [
          0,
          6940,
          for (var i = 1; i <= 9; i++) 6940 + i * 13880,
        ],
      });
      expect(metrics.period, closeTo(6.94, 1e-9));
    });
  });

  group('traceOf', () {
    test('reads scene, side, and pair from the report key', () {
      final trace = traceOf(
        'r1g2',
        'S2-plain.base.2.timeline_summary.json',
        _metrics(),
      );
      expect(trace?.run, 'r1g2');
      expect(trace?.scene, 'S2-plain');
      expect(trace?.side, 'base');
      expect(trace?.pair, 2);
    });

    test('skips files that are not ABBA summaries', () {
      expect(traceOf('r1g1', 'S1.timeline_summary.json', _metrics()), isNull);
      expect(
        traceOf('r1g1', 'S1.left.1.timeline_summary.json', _metrics()),
        isNull,
      );
      expect(traceOf('r1g1', 'S1.base.1.timeline.json', _metrics()), isNull);
    });
  });

  group('blockTraces', () {
    test('makes one block per run folder and scene', () {
      final blocks = blockTraces([
        ..._block('r1g1', 'S1', base: 0.2, cand: 0.3),
        ..._block('r1g2', 'S2-plain'),
        ..._block('r2g1', 'S1', base: 0.4, cand: 0.4),
        ..._block('r1g1', 'S2'),
      ]);
      expect(blocks.keys, unorderedEquals(['S1', 'S2', 'S2-plain']));
      expect([
        for (final block in blocks['S1']!) block.cand1.average,
      ], unorderedEquals([0.3, 0.4]));
    });

    test('leaves out a block that misses any of its four traces', () {
      final blocks = blockTraces([
        ..._block('r1g1', 'S1'),
        ..._block('r2g1', 'S1').take(3),
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

  group('invalidRuns', () {
    test("marks a run invalid when one trace's display period drifts", () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          _trace('r1g1', 'S2', 'base', 1),
          _trace('r1g1', 'S2', 'cand', 1, period: 16.67),
          ..._block('r2g1', 'S1'),
        ]).keys,
        ['r1'],
      );
    });

    test('marks a run invalid when one whole invocation ran on another '
        'display', () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          ..._block('r1g2', 'S3'),
          _trace('r1g3', 'S4', 'base', 1, period: 16.67),
          _trace('r1g3', 'S4', 'cand', 1, period: 16.67),
          ..._block('r2g1', 'S1'),
        ]),
        {'r1': 'display period'},
      );
    });

    test('marks a run invalid when all of it ran on another display', () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          ..._block('r2g1', 'S1'),
          ..._block('r3g1', 'S1'),
          _trace('r4g1', 'S1', 'base', 1, period: 16.67),
          _trace('r4g1', 'S1', 'cand', 1, period: 16.67),
        ]).keys,
        ['r4'],
      );
    });

    test('marks a run invalid on lost frames and names the side', () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          _trace('r2g1', 'S4', 'base', 1),
          _trace('r2g1', 'S4', 'cand', 1, frames: 120),
          _trace('r3g1', 'S4', 'base', 1, frames: 19),
          _trace('r3g1', 'S4', 'cand', 1, frames: 130),
        ]),
        {
          'r2': 'lost frames on current',
          'r3': 'lost frames on baseline and current',
        },
      );
    });
  });

  group('runInvalid', () {
    test('is true once a trace of the run lost frames', () {
      final traces = [
        ..._block('r6g1', 'S1'),
        _trace('r7g1', 'S1', 'base', 1),
        _trace('r7g1', 'S1', 'cand', 1, frames: 40),
      ];
      expect(runInvalid(traces, 7), isTrue);
      expect(runInvalid(traces, 6), isFalse);
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
          _trace('r99g1', 'S4', 'base', 1),
          _trace('r99g1', 'S4', 'cand', 1, frames: 30),
          _trace('r99g1', 'S4', 'cand', 2),
          _trace('r99g1', 'S4', 'base', 2),
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
        codeStates: const {
          'r1g1': 'abc 111',
          'r2g1': 'abc 111',
          'r3g1': 'def 222',
        },
      );
      expect(
        result.text,
        contains('code states differ: abc 111 in r1g1, r2g1; def 222 in r3g1'),
      );
    });
  });

  group('codeStateError', () {
    test('accepts runs on the stored code state', () {
      expect(codeStateError(const {}, 'abc 111'), isNull);
      expect(codeStateError(const {'r1g1': 'abc 111'}, 'abc 111'), isNull);
    });

    test('refuses runs on another code state', () {
      expect(
        codeStateError(const {'r1g1': 'abc 111', 'r1g2': 'abc 222'}, 'abc 111'),
        contains('r1g2'),
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
      Directory('${root.path}/r2g3').createSync();
      expect(clashingRuns(root, from: 1, runs: 6), ['${root.path}/r2g3']);
      expect(clashingRuns(root, from: 3, runs: 4), isEmpty);
    });
  });

  group('prebuilt apps', () {
    test('builds one profile app per group with its PERF_GROUP', () {
      expect(buildArgs(2), [
        'build',
        'macos',
        '--profile',
        '--target=integration_test/layout_perf_test.dart',
        '--dart-define=PERF_GROUP=2',
      ]);
    });

    test('drives a group on its prebuilt app', () {
      final args = driveArgs(3);
      expect(args, contains('--use-application-binary=build/perf-apps/g3.app'));
      expect(args, contains('--endless-trace-buffer'));
      expect(args, contains('--driver=test_driver/perf_driver.dart'));
      expect(args, contains('--target=integration_test/layout_perf_test.dart'));
    });
  });
}
