import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scene.dart';
import '../../integration_test/perf/perf_scenes.dart';

void main() {
  group('runSteps', () {
    final steps = runSteps(
      [perfScene('S1'), perfScene('S5')],
      first: 3,
      count: 2,
    );

    test('warms every scene up once per side before the first trace', () {
      expect(
        [for (final step in steps.take(4)) step.name],
        [
          'warm-up S1.base',
          'warm-up S1.cand',
          'warm-up S5.base',
          'warm-up S5.cand',
        ],
      );
      expect(steps.where((step) => !step.traced), hasLength(4));
    });

    test('traces one block per scene per run in list order, numbering runs '
        'from first', () {
      expect(
        [for (final step in steps.skip(4)) step.reportKey],
        [
          'r3.S1.base.1',
          'r3.S1.cand.1',
          'r3.S1.cand.2',
          'r3.S1.base.2',
          'r3.S5.base.1',
          'r3.S5.cand.1',
          'r3.S5.cand.2',
          'r3.S5.base.2',
          'r4.S1.base.1',
          'r4.S1.cand.1',
          'r4.S1.cand.2',
          'r4.S1.base.2',
          'r4.S5.base.1',
          'r4.S5.cand.1',
          'r4.S5.cand.2',
          'r4.S5.base.2',
        ],
      );
      expect(steps.skip(4).every((step) => step.traced), isTrue);
      expect(steps.skip(4).first.name, 'r3.S1.base.1');
    });

    test('opens each run with its first trace', () {
      expect(
        [
          for (final step in steps)
            if (step.startsRun) step.name,
        ],
        ['r3.S1.base.1', 'r4.S1.base.1'],
      );
    });

    test('cools down after S5 only, and not after the last run', () {
      expect(
        [
          for (final step in steps)
            if (step.coolDown) step.name,
        ],
        ['r3.S5.base.2'],
      );
    });

    test('never cools down when the list leaves S5 out', () {
      final steps = runSteps(
        [perfScene('S2-plain'), perfScene('S4')],
        first: 1,
        count: 3,
      );
      expect(steps.where((step) => step.coolDown), isEmpty);
      // Three S2-plain blocks and one S4 block per run.
      expect(steps.where((step) => step.traced), hasLength(48));
    });
  });

  group('runSteps with S2-plain', () {
    final steps = runSteps(
      [perfScene('S2-plain'), perfScene('S1'), perfScene('S3'), perfScene('S5')],
      first: 1,
      count: 2,
    );

    /// The traced keys of run [run], one entry per block: its first key.
    List<String> blocks(int run) => [
      for (final step in steps)
        if (step.run == run && step.pair!.isOdd && step.baseline)
          step.reportKey,
    ];

    test('runs S2-plain at the start, before S3, and after S5, numbering '
        'its pairs 1 to 6', () {
      expect(blocks(1), [
        'r1.S2-plain.base.1',
        'r1.S1.base.1',
        'r1.S2-plain.base.3',
        'r1.S3.base.1',
        'r1.S5.base.1',
        'r1.S2-plain.base.5',
      ]);
      expect(
        [
          for (final step in steps)
            if (step.run == 1 && step.scene.key == 'S2-plain') step.reportKey,
        ],
        [
          for (final pair in [1, 2, 3, 4, 5, 6])
            for (final side in pair.isOdd ? ['base', 'cand'] : ['cand', 'base'])
              'r1.S2-plain.$side.$pair',
        ],
      );
    });

    test('cools down after S5 in every run, before the last S2-plain '
        'block', () {
      expect(
        [
          for (final step in steps)
            if (step.coolDown) step.name,
        ],
        ['r1.S5.base.2', 'r2.S5.base.2'],
      );
    });

    test('warms S2-plain up once per side', () {
      expect(
        [
          for (final step in steps)
            if (!step.traced) step.name,
        ],
        [
          'warm-up S2-plain.base',
          'warm-up S2-plain.cand',
          'warm-up S1.base',
          'warm-up S1.cand',
          'warm-up S3.base',
          'warm-up S3.cand',
          'warm-up S5.base',
          'warm-up S5.cand',
        ],
      );
    });

    test('runs the middle block before the end block when no scene of the '
        'second half is listed', () {
      final steps = runSteps(
        [perfScene('S2-plain'), perfScene('S1')],
        first: 1,
        count: 1,
      );
      expect(
        [
          for (final step in steps)
            if (step.traced && step.baseline && step.pair!.isOdd)
              step.reportKey,
        ],
        [
          'r1.S2-plain.base.1',
          'r1.S1.base.1',
          'r1.S2-plain.base.3',
          'r1.S2-plain.base.5',
        ],
      );
    });
  });
}
