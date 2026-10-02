import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

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
}
