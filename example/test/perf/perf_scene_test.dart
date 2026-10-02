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
      expect(steps.where((step) => step.traced), hasLength(24));
    });
  });
}
