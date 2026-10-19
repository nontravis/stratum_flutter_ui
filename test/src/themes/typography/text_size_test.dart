import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/text_size.dart';

const _zero = StratumDimension.fixed(0);

/// The sizes of a text of [base] px; the theme-wide window scale is
/// `{ tablet: "50%", desktop: 1 }` unless [themeScale] is given.
TextSize _sizeOf({
  double base = 16,
  String? window,
  Map<String, StratumDimension>? ownScale,
  Map<String, StratumDimension>? themeScale = const {
    'tablet': StratumDimension.percent(0.5),
    'desktop': StratumDimension.fixed(1),
  },
  StratumDimension adjustSize = _zero,
  StratumDimension spaceHeight = const StratumDimension.fixed(8),
  double Function(double size)? scale,
}) => textSizeOf(
  base: base,
  window: window,
  ownScale: ownScale,
  themeScale: themeScale,
  adjustSize: adjustSize,
  spaceHeight: spaceHeight,
  scale: scale ?? (size) => size,
);

void main() {
  group('textSizeOf window scale, s03 step 4', () {
    test('no window size adds no window scale', () {
      final sizes = _sizeOf();

      expect(sizes.windowScale, isNull);
      expect(sizes.size, 16);
    });

    test("a type's own entry wins at its own window size", () {
      final sizes = _sizeOf(
        window: 'desktop',
        ownScale: const {'desktop': StratumDimension.fixed(3)},
      );

      expect(sizes.windowScale, (
        name: 'desktop',
        own: true,
        value: const StratumDimension.fixed(3),
      ));
      expect(sizes.size, 19);
    });

    test("fo02/us04/fr02/e04: a type's own entry at a smaller window size "
        'fills an omitted one; a nearer theme-wide entry fills where it is '
        'nearer', () {
      const own = {'desktop': StratumDimension.fixed(3)};
      const themeScale = {
        'mobile': StratumDimension.fixed(0),
        'desktop': StratumDimension.fixed(1),
      };
      final big = _sizeOf(
        window: 'bigDesktop',
        ownScale: own,
        themeScale: themeScale,
      );
      final tablet = _sizeOf(
        window: 'tablet',
        ownScale: own,
        themeScale: themeScale,
      );

      expect(big.windowScale, (
        name: 'desktop',
        own: true,
        value: const StratumDimension.fixed(3),
      ));
      expect(big.size, 19);
      expect(tablet.windowScale, (
        name: 'mobile',
        own: false,
        value: const StratumDimension.fixed(0),
      ));
      expect(tablet.size, 16);
    });

    test('fo02/us04/fr02: a nearer own entry wins over a farther theme-wide '
        'one, at a window size neither names exactly', () {
      final sizes = _sizeOf(
        window: 'tablet',
        ownScale: const {'mobile': StratumDimension.fixed(3)},
        themeScale: const {'watch': StratumDimension.fixed(1)},
      );

      expect(sizes.windowScale, (
        name: 'mobile',
        own: true,
        value: const StratumDimension.fixed(3),
      ));
      expect(sizes.size, 19);
    });

    test("fo02/us04/fr02: a type's own map alone fills a window size it "
        'omits, from the smallest window size it sets', () {
      final sizes = _sizeOf(
        window: 'mobile',
        ownScale: const {'desktop': StratumDimension.fixed(3)},
        themeScale: null,
      );

      expect(sizes.windowScale, (
        name: 'desktop',
        own: true,
        value: const StratumDimension.fixed(3),
      ));
      expect(sizes.size, 19);
    });

    test('fo02/us04/fr02/e01, fo02/us04/fr02/e02, fo02/us04/fr02/e03: the '
        'theme-wide map fills from the nearest smaller window size, else the '
        'smallest', () {
      const themeScale = {
        'mobile': StratumDimension.fixed(0),
        'desktop': StratumDimension.fixed(1),
      };
      for (final (window, name, size) in [
        ('tablet', 'mobile', 16.0),
        ('bigDesktop', 'desktop', 17.0),
      ]) {
        final sizes = _sizeOf(window: window, themeScale: themeScale);

        expect(sizes.windowScale?.name, name, reason: window);
        expect(sizes.size, size, reason: window);
      }
      final watch = _sizeOf(
        window: 'watch',
        themeScale: const {
          'mobile': StratumDimension.fixed(2),
          'desktop': StratumDimension.fixed(4),
        },
      );
      expect(watch.windowScale?.name, 'mobile');
      expect(watch.size, 18);
    });

    test('fo02/us04/fr02/e05: no window size runs no fill', () {
      final sizes = _sizeOf(
        ownScale: const {'desktop': StratumDimension.fixed(3)},
      );

      expect(sizes.windowScale, isNull);
      expect(sizes.size, 16);
    });

    test('the theme-wide map gives its own entry, else the nearest smaller '
        'one, else the smallest one; a percent resolves against base', () {
      for (final (window, name, size) in [
        ('watch', 'tablet', 24.0),
        ('mobile', 'tablet', 24.0),
        ('tablet', 'tablet', 24.0),
        ('desktop', 'desktop', 17.0),
        ('bigDesktop', 'desktop', 17.0),
      ]) {
        final sizes = _sizeOf(window: window);

        expect(sizes.windowScale?.name, name, reason: window);
        expect(sizes.windowScale?.own, isFalse, reason: window);
        expect(sizes.size, size, reason: window);
      }
    });

    test('no entry when neither map names a window size', () {
      for (final themeScale in [null, const <String, StratumDimension>{}]) {
        final sizes = _sizeOf(window: 'desktop', themeScale: themeScale);

        expect(sizes.windowScale, isNull);
        expect(sizes.size, 16);
      }
    });
  });

  group('textSizeOf size math, s03 steps 5 and 6', () {
    test(
      'fo02/us02/fr01/e02: the font size adds the window scale and adjustSize; '
      'the line box leaves both out',
      () {
        final sizes = _sizeOf(
          window: 'desktop',
          adjustSize: const StratumDimension.fixed(2),
        );

        expect(sizes.size, 17);
        expect(sizes.fontSize, 19);
        expect(sizes.lineBox, 24);
        expect(sizes.drawnFontSize, 19);
        expect(sizes.drawnLineBox, 24);
      },
    );

    test('fo02/us03/fr01/e01: the scaler scales the line box base on its own, '
        'and a percent spaceHeight resolves against the scaled base', () {
      final sizes = _sizeOf(
        window: 'desktop',
        adjustSize: const StratumDimension.fixed(2),
        spaceHeight: const StratumDimension.percent(0.5),
        scale: (size) => size * 2,
      );

      expect(sizes.fontSize, 19);
      expect(sizes.lineBox, 48);
      expect(sizes.drawnLineBox, 48);
    });
  });

  group('textSizeOf fallback, s03 steps 5 and 6', () {
    for (final (name, adjustSize) in [
      ('of 0', const StratumDimension.fixed(-17)),
      ('below 0', const StratumDimension.percent(-1.5)),
      ('infinite', const StratumDimension.fixed(double.infinity)),
      ('NaN', const StratumDimension.fixed(double.nan)),
    ]) {
      test('fo02/us02/fr01/e04: a font size $name draws at base, dropping the '
          'window scale and adjustSize; size and the line box keep their '
          'own rules', () {
        final sizes = _sizeOf(window: 'desktop', adjustSize: adjustSize);

        expect(sizes.drawnFontSize, 16);
        expect(sizes.size, 17);
        expect(sizes.drawnLineBox, 24);
      });
    }

    for (final (name, spaceHeight, scale, drawn) in [
      ('of 0', const StratumDimension.fixed(-16), 1.0, 16.0),
      ('below 0 at text scale 2', const StratumDimension.fixed(-40), 2.0, 32.0),
      ('infinite', const StratumDimension.fixed(double.infinity), 1.0, 16.0),
      ('NaN', const StratumDimension.fixed(double.nan), 1.0, 16.0),
    ]) {
      test('fo02/us02/fr01/e05: a line box $name draws at the scaled base, '
          'dropping spaceHeight; the font size keeps its own rule', () {
        final sizes = _sizeOf(
          spaceHeight: spaceHeight,
          scale: (size) => size * scale,
        );

        expect(sizes.drawnLineBox, drawn);
        expect(sizes.drawnFontSize, 16);
      });
    }

    test('fo02/us02/fr01/e06: both fail together', () {
      final sizes = _sizeOf(
        adjustSize: const StratumDimension.percent(-1),
        spaceHeight: const StratumDimension.fixed(-16),
      );

      expect(sizes.fontSize, 0);
      expect(sizes.lineBox, 0);
      expect(sizes.drawnFontSize, 16);
      expect(sizes.drawnLineBox, 16);
    });

    for (final (value, drawable) in [
      (16.0, true),
      (0.01, true),
      (0.0, false),
      (-1.0, false),
      (double.infinity, false),
      (double.nan, false),
    ]) {
      test('isDrawableSize($value) is $drawable', () {
        expect(isDrawableSize(value), drawable);
      });
    }
  });

  group('textSizeOf letter-spacing basis, s03 step 8, fo02/us02/fr01/e07', () {
    for (final (name, scaleValue) in [
      ('of 0', const StratumDimension.fixed(-16)),
      ('below 0', const StratumDimension.fixed(-20)),
      ('infinite', const StratumDimension.fixed(double.infinity)),
      ('NaN', const StratumDimension.fixed(double.nan)),
    ]) {
      test('fo02/us02/fr01/e07: a letter-spacing basis $name draws at base, '
          'dropping the window scale; size keeps its own rule', () {
        final sizes = _sizeOf(
          window: 'desktop',
          ownScale: {'desktop': scaleValue},
        );

        expect(sizes.drawnSize, 16);
      });
    }

    test('fo02/us02/fr01/e07: a drawable basis keeps the window scale', () {
      final sizes = _sizeOf(
        window: 'desktop',
        ownScale: const {'desktop': StratumDimension.fixed(3)},
      );

      expect(sizes.drawnSize, 19);
    });
  });

  group('nearestFontSize, fo02/us02/fr02', () {
    test('the closest defined size, the smaller one on a tie', () {
      const defined = [FontSize.s14, FontSize.s18];

      expect(nearestFontSize(defined, 16), FontSize.s14);
      expect(nearestFontSize(defined, 17), FontSize.s18);
      expect(nearestFontSize(defined, 5), FontSize.s14);
      expect(nearestFontSize(defined, 100), FontSize.s18);
      expect(nearestFontSize(const [], 16), isNull);
    });
  });
}
