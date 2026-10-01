import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scene.dart';
import '../../integration_test/perf/perf_scenes.dart';
import '../../tool/perf_abba.dart' show groups;

void main() {
  group('abbaSteps', () {
    final steps = abbaSteps([perfScene('S1'), perfScene('S4')]);

    test('warms every scene up on both sides before the first trace', () {
      expect([for (final step in steps.take(4)) step.name], [
        'warm-up S1.base',
        'warm-up S1.cand',
        'warm-up S4.base',
        'warm-up S4.cand',
      ]);
      expect(steps.take(4).any((step) => step.traced), isFalse);
    });

    test('traces one block per scene: baseline, current, current, '
        'baseline', () {
      expect([for (final step in steps.skip(4)) step.reportKey], [
        'S1.base.1',
        'S1.cand.1',
        'S1.cand.2',
        'S1.base.2',
        'S4.base.1',
        'S4.cand.1',
        'S4.cand.2',
        'S4.base.2',
      ]);
      expect(steps.skip(4).every((step) => step.traced), isTrue);
      expect(steps.skip(4).first.name, 'S1.base.1');
    });
  });

  group('perfGroups', () {
    test('covers every catalog scene, with S2-plain first in each group',
        () {
      expect(perfGroups.keys, [1, 2, 3]);
      expect(
        {for (final keys in perfGroups.values) ...keys},
        {for (final scene in perfScenes) scene.key},
      );
      for (final keys in perfGroups.values) {
        expect(keys.first, 'S2-plain');
      }
    });

    test('keeps every invocation within 16 traces', () {
      for (final group in perfGroups.keys) {
        final traced = abbaSteps(perfGroup(group)).where((s) => s.traced);
        expect(traced.length, lessThanOrEqualTo(16), reason: 'group $group');
      }
    });

    test('rejects an unknown group', () {
      expect(() => perfGroup(4), throwsArgumentError);
    });

    test('matches the groups perf_abba runs', () {
      expect(perfGroups.keys, groups);
    });
  });
}
