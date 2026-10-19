import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';

void main() {
  group('StratumByWindowSize.valueFor', () {
    test(
      'an omitted size takes the nearest smaller one, else the smallest',
      () {
        final value = StratumByWindowSize(const {
          WindowSize.mobile: 16,
          WindowSize.desktop: 32,
        });

        expect(
          {for (final size in WindowSize.values) size: value.valueFor(size)},
          {
            WindowSize.watch: 16,
            WindowSize.mobile: 16,
            WindowSize.tablet: 16,
            WindowSize.desktop: 32,
            WindowSize.bigDesktop: 32,
          },
        );
      },
    );

    test('one entry gives its value on every size', () {
      final value = StratumByWindowSize(const {WindowSize.desktop: 2});

      for (final size in WindowSize.values) {
        expect(value.valueFor(size), 2, reason: '$size');
      }
    });

    test('.all gives its value on every size', () {
      const value = StratumByWindowSize.all(8);

      for (final size in WindowSize.values) {
        expect(value.valueFor(size), 8, reason: '$size');
      }
    });
  });

  group('StratumByWindowSize.names', () {
    test('fo02/us04/fr02: a map names only the window sizes it declares', () {
      final value = StratumByWindowSize(const {
        WindowSize.mobile: 16,
        WindowSize.desktop: 32,
      });

      expect(
        {for (final size in WindowSize.values) size: value.names(size)},
        {
          WindowSize.watch: false,
          WindowSize.mobile: true,
          WindowSize.tablet: false,
          WindowSize.desktop: true,
          WindowSize.bigDesktop: false,
        },
      );
    });

    test('fo02/us04/fr02: .all names every window size', () {
      const value = StratumByWindowSize.all(8);

      for (final size in WindowSize.values) {
        expect(value.names(size), isTrue, reason: '$size');
      }
    });
  });

  group('StratumByWindowSize equality', () {
    test('equal when every size gives the same value', () {
      final full = StratumByWindowSize({
        for (final size in WindowSize.values) size: 8,
      });

      expect(full, const StratumByWindowSize.all(8));
      expect(full.hashCode, const StratumByWindowSize.all(8).hashCode);
      expect(
        StratumByWindowSize(const {WindowSize.desktop: 2}),
        const StratumByWindowSize.all(2),
      );
    });

    test('different when one size gives another value', () {
      expect(
        StratumByWindowSize(const {
          WindowSize.mobile: 16,
          WindowSize.desktop: 32,
        }),
        isNot(StratumByWindowSize(const {WindowSize.mobile: 16})),
      );
    });
  });

  test('an empty map asserts', () {
    expect(() => StratumByWindowSize<int>(const {}), throwsAssertionError);
  });

  group('windowSizeEntryIndex, OQ11', () {
    test("a window size's own entry, else the nearest smaller one, else the "
        'smallest one', () {
      bool mobileAndDesktop(int index) => index == 1 || index == 3;

      expect(
        [
          for (var index = 0; index < 5; index++)
            windowSizeEntryIndex(index, mobileAndDesktop),
        ],
        [1, 1, 1, 3, 3],
      );
      expect(
        [
          for (var index = 0; index < 5; index++)
            windowSizeEntryIndex(index, (index) => index == 4),
        ],
        [4, 4, 4, 4, 4],
      );
    });

    test('null when no window size has an entry', () {
      expect(windowSizeEntryIndex(2, (index) => false), isNull);
    });
  });
}
