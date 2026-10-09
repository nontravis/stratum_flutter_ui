import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_cut.dart';

/// Twelve 40 px children.
final _twelve = List<double>.filled(12, 40);

void main() {
  group('cutWrap', () {
    test("us14/fr01/e07: runs follow Flutter's run rule", () {
      final cut = cutWrap(
        extents: List<double>.filled(5, 40),
        limit: 100,
        spacing: 10,
      );

      expect(cut.runOf, [0, 0, 1, 1, 2]);
      expect(cut.overflowRun, isNull);
      expect(cut.runCount, 3);
    });

    test('us14/fr01/e07: a child within precisionErrorTolerance of the limit '
        'stays in its run', () {
      final cut = cutWrap(extents: [50, 50], limit: 100 - 1e-11, spacing: 0);

      expect(cut.runOf, [0, 0]);
    });

    test('us14/fr01/e07: an oversize child takes a run of its own', () {
      final cut = cutWrap(extents: [300, 40], limit: 190, spacing: 10);

      expect(cut.runOf, [0, 1]);
    });

    test('us14/s1, us14/fr01, us14/fr02: two runs hold 8 children and the '
        'overflow child, which counts 4', () {
      final counts = <int>[];
      final cut = cutWrap(
        extents: _twelve,
        limit: 230,
        spacing: 10,
        maxRuns: 2,
        overflowExtent: (count) {
          counts.add(count);
          return 30;
        },
      );

      expect(cut.runOf, [0, 0, 0, 0, 1, 1, 1, 1]);
      expect(cut.overflowRun, 1);
      expect(counts, [4]);
    });

    test(
      'us14/s2, us14/fr01/e01, s03/inv37: the limit that hides more wins',
      () {
        final counts = <int>[];
        double more(int count) {
          counts.add(count);
          return 30;
        }

        final byChildren = cutWrap(
          extents: _twelve,
          limit: 230,
          spacing: 10,
          maxRuns: 2,
          maxChildren: 5,
          overflowExtent: more,
        );
        final byRuns = cutWrap(
          extents: _twelve,
          limit: 230,
          spacing: 10,
          maxRuns: 2,
          maxChildren: 10,
          overflowExtent: more,
        );

        expect(byChildren.runOf, [0, 0, 0, 0, 1]);
        expect(byChildren.overflowRun, 1);
        expect(byRuns.shown, 8);
        expect(counts, [7, 4]);
      },
    );

    test('us14/s3, us14/fr02/e01: with nothing hidden no overflow child is '
        'asked for', () {
      var asked = false;
      final cut = cutWrap(
        extents: List<double>.filled(4, 40),
        limit: 230,
        spacing: 10,
        maxRuns: 2,
        overflowExtent: (_) {
          asked = true;
          return 30;
        },
      );

      expect(cut.runOf, [0, 0, 0, 0]);
      expect(cut.overflowRun, isNull);
      expect(asked, isFalse);
    });

    test('us14/fr01/e04: an overflow child with both limits null shows every '
        'child and is never asked for', () {
      var asked = false;
      final cut = cutWrap(
        extents: _twelve,
        limit: 230,
        spacing: 10,
        overflowExtent: (_) {
          asked = true;
          return 30;
        },
      );

      expect(cut.shown, 12);
      expect(cut.overflowRun, isNull);
      expect(asked, isFalse);
    });

    test('us14/fr02/e02: with no overflow extent the cut hides with no '
        'overflow child', () {
      final cut = cutWrap(
        extents: _twelve,
        limit: 230,
        spacing: 10,
        maxRuns: 2,
      );

      expect(cut.shown, 8);
      expect(cut.overflowRun, isNull);
      expect(cut.runCount, 2);
    });

    test('us14/fr02/e03: below maxRuns an overflow child that does not fit '
        'opens a new run', () {
      for (final maxRuns in [null, 3]) {
        final cut = cutWrap(
          extents: _twelve,
          limit: 190,
          spacing: 10,
          maxRuns: maxRuns,
          maxChildren: 4,
          overflowExtent: (_) => 30,
        );

        expect(cut.runOf, [0, 0, 0, 0], reason: 'maxRuns $maxRuns');
        expect(cut.overflowRun, 1, reason: 'maxRuns $maxRuns');
      }
    });

    test('us14/fr02/e04, s03/inv37: at the maxRuns cap shown children hide '
        'from the end, one at a time, and the count grows with each', () {
      final counts = <int>[];
      final cut = cutWrap(
        extents: _twelve,
        limit: 190,
        spacing: 10,
        maxRuns: 2,
        overflowExtent: (count) {
          counts.add(count);
          return 90;
        },
      );

      expect(cut.runOf, [0, 0, 0, 0, 1, 1]);
      expect(cut.overflowRun, 1);
      expect(counts, [4, 5, 6]);
    });

    test('us14/fr02/e04: under maxRuns 1 an oversize first child hides for '
        'an overflow child that fits alone, which counts it', () {
      final counts = <int>[];
      final cut = cutWrap(
        extents: [400, 40, 40],
        limit: 230,
        spacing: 10,
        maxRuns: 1,
        overflowExtent: (count) {
          counts.add(count);
          return 30;
        },
      );

      expect(cut.runOf, isEmpty);
      expect(cut.overflowRun, 0);
      expect(counts, [2, 3]);
    });

    test('us14/fr02/e05: an overflow child wider than a run sits alone in the '
        'last allowed run', () {
      final counts = <int>[];
      double wide(int count) {
        counts.add(count);
        return 300;
      }

      final two = cutWrap(
        extents: _twelve,
        limit: 190,
        spacing: 10,
        maxRuns: 2,
        overflowExtent: wide,
      );
      expect(two.runOf, [0, 0, 0, 0]);
      expect(two.overflowRun, 1);
      expect(counts, [4, 5, 6, 7, 8]);

      counts.clear();
      final one = cutWrap(
        extents: _twelve,
        limit: 190,
        spacing: 10,
        maxRuns: 1,
        overflowExtent: wide,
      );
      expect(one.runOf, isEmpty);
      expect(one.overflowRun, 0);
      expect(counts, [8, 9, 10, 11, 12]);
    });

    test('us14/fr01/e03, us14/fr02/e06: maxChildren 0 shows the overflow child '
        'alone with every child counted', () {
      final counts = <int>[];
      final counted = cutWrap(
        extents: List<double>.filled(5, 40),
        limit: 230,
        spacing: 10,
        maxChildren: 0,
        overflowExtent: (count) {
          counts.add(count);
          return 30;
        },
      );
      final bare = cutWrap(
        extents: List<double>.filled(5, 40),
        limit: 230,
        spacing: 10,
        maxChildren: 0,
      );

      expect(counted.runOf, isEmpty);
      expect(counted.overflowRun, 0);
      expect(counted.runCount, 1);
      expect(counts, [5]);
      expect(bare.runOf, isEmpty);
      expect(bare.overflowRun, isNull);
      expect(bare.runCount, 0);
    });

    test('no children cut to nothing', () {
      final cut = cutWrap(
        extents: const [],
        limit: 230,
        spacing: 10,
        maxRuns: 2,
        overflowExtent: (_) => 30,
      );

      expect(cut.runOf, isEmpty);
      expect(cut.overflowRun, isNull);
      expect(cut.runCount, 0);
    });
  });
}
