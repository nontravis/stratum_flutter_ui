import 'package:flutter_test/flutter_test.dart';

import '../../tool/perf_abba.dart' hide main;

TraceMetrics _metrics({
  double average = 0.25,
  double p99Build = 0.5,
  double p99Raster = 3.5,
  double interval = 6.94,
}) {
  return (
    average: average,
    p99Build: p99Build,
    p99Raster: p99Raster,
    interval: interval,
  );
}

Trace _trace(
  String run,
  String scene,
  String side,
  int pair, {
  double average = 0.25,
  double interval = 6.94,
}) {
  return (
    run: run,
    scene: scene,
    side: side,
    pair: pair,
    metrics: _metrics(average: average, interval: interval),
  );
}

/// Pairs of [scene] over [changes], one pair per entry, in runs r1g1 on.
List<Trace> _pairs(String scene, List<double> changes) {
  return [
    for (var i = 0; i < changes.length; i++) ...[
      _trace('r${i + 1}g1', scene, 'base', 1, average: 0.2),
      _trace(
        'r${i + 1}g1',
        scene,
        'cand',
        1,
        average: 0.2 * (1 + changes[i] / 100),
      ),
    ],
  ];
}

/// The paired changes of the phase 3 S4 RCA (12 pairs, median −10.1%).
const _rcaS4 = [
  -46.1, -4.9, -6.5, -10.4, 7.3, 0.0, -48.2, -20.7, -14.2, -9.8, -21.6, -9.0,
];

void main() {
  group('ciRank', () {
    test('matches spec section 9.5', () {
      expect(ciRank(5), isNull);
      expect(ciRank(6), 1);
      expect(ciRank(12), 3);
      expect(ciRank(24), 7);
      expect(ciRank(36), 12);
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
    test('reads the three metrics and the median frame interval', () {
      final metrics = metricsOf({
        'average_frame_build_time_millis': 0.31,
        '99th_percentile_frame_build_time_millis': 1.02,
        '99th_percentile_frame_rasterizer_time_millis': 3.4,
        'frame_begin_times': [0, 6940, 13880, 20820, 40000],
      });
      expect(metrics.average, 0.31);
      expect(metrics.p99Build, 1.02);
      expect(metrics.p99Raster, 3.4);
      expect(metrics.interval, closeTo(6.94, 1e-9));
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

  group('pairTraces', () {
    test('pairs base and cand by run, scene, and pair number', () {
      final pairs = pairTraces([
        _trace('r1g1', 'S1', 'base', 1, average: 0.20),
        _trace('r1g1', 'S1', 'cand', 1, average: 0.22),
        _trace('r1g1', 'S1', 'cand', 2, average: 0.30),
        _trace('r1g1', 'S1', 'base', 2, average: 0.25),
        _trace('r2g1', 'S1', 'base', 1, average: 0.40),
        _trace('r2g1', 'S1', 'cand', 1, average: 0.38),
      ]);
      expect(
        [for (final pair in pairs['S1']!) (pair.base.average, pair.cand.average)],
        unorderedEquals([(0.20, 0.22), (0.25, 0.30), (0.40, 0.38)]),
      );
    });

    test('leaves a trace without its partner out', () {
      final pairs = pairTraces([
        _trace('r1g1', 'S1', 'base', 1),
        _trace('r1g1', 'S1', 'cand', 1),
        _trace('r1g1', 'S1', 'cand', 2),
      ]);
      expect(pairs['S1'], hasLength(1));
    });
  });

  group('invalidRuns', () {
    test('marks a run invalid when one trace\'s interval drifts', () {
      expect(
        invalidRuns([
          _trace('r1g1', 'S1', 'base', 1),
          _trace('r1g1', 'S1', 'cand', 1),
          _trace('r1g1', 'S2', 'base', 1),
          _trace('r1g1', 'S2', 'cand', 1, interval: 16.67),
          _trace('r2g1', 'S1', 'base', 1),
          _trace('r2g1', 'S1', 'cand', 1, interval: 7.3),
        ]),
        {'r1g1'},
      );
    });
  });

  group('averageChange', () {
    test('is the percent change from base to cand', () {
      expect(
        averageChange((base: _metrics(average: 0.2), cand: _metrics(average: 0.21))),
        closeTo(5, 1e-9),
      );
    });
  });

  group('withinBudget', () {
    TracePair pair(double base, double cand) => (
      base: _metrics(p99Build: base, p99Raster: 3),
      cand: _metrics(p99Build: cand, p99Raster: 3),
    );

    test('passes below 8.3 ms', () {
      expect(withinBudget([pair(1, 7.9)]), isTrue);
    });

    test('fails at or above 8.3 ms when the baseline was below', () {
      expect(withinBudget([pair(7, 8.3)]), isFalse);
    });

    test('accepts no worse than a baseline already over budget', () {
      expect(withinBudget([pair(9, 8.9)]), isTrue);
      expect(withinBudget([pair(9, 9.5)]), isFalse);
    });

    test('checks p99 raster too', () {
      expect(
        withinBudget([
          (
            base: _metrics(p99Raster: 3),
            cand: _metrics(p99Raster: 8.4),
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

    test('is inconclusive when the interval straddles +5% or is missing',
        () {
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
      expect(
        sceneVerdict(ci: null, p99WithinBudget: false),
        Verdict.fail,
      );
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
      expect(loadOf(' 10:00:00 up 1 day,  load average: 0.52, 0.40, 0.31'),
          0.52);
      expect(loadOf('no load here'), isNull);
    });
  });

  group('judge', () {
    test('passes S4 on the RCA data behind a quiet null control', () {
      final result = judge([
        ..._pairs('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
        ..._pairs('S4', _rcaS4),
      ], loads: [9.1, 16.4]);
      expect(result.verdict, Verdict.pass);
      expect(result.text, contains('| S4 | 12 |'));
      expect(result.text, contains('[-21.6, -4.9]'));
      expect(result.text, contains('| S2-plain (null) | 6 |'));
      expect(result.text, contains('load 9.1–16.4'));
      expect(result.text, contains('overall: PASS'));
    });

    test('is INVALID when the null interval misses 0', () {
      final result = judge([
        ..._pairs('S2-plain', [3, 2, 1, 4, 5, 2]),
        ..._pairs('S4', _rcaS4),
      ], loads: const []);
      expect(result.verdict, Verdict.invalid);
      expect(result.text, contains('overall: INVALID'));
    });

    test('leaves an invalid run out and lists it', () {
      final result = judge([
        ..._pairs('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
        ..._pairs('S4', _rcaS4),
        _trace('r99g1', 'S4', 'base', 1),
        _trace('r99g1', 'S4', 'cand', 1, interval: 16.67),
        _trace('r99g1', 'S4', 'base', 2),
        _trace('r99g1', 'S4', 'cand', 2),
      ], loads: const []);
      expect(result.text, contains('| S4 | 12 |'));
      expect(result.text, contains('invalid runs: r99g1'));
    });
  });
}
