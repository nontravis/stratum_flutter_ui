@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

StratumThemeSource _default() => StratumThemeSource(
  id: 'stratum-default',
  folder: 'packages/stratum_ui/assets/themes/default',
  yaml: File('assets/themes/default/theme.yaml').readAsStringSync(),
);

bool _exists(String name) => GoogleFontsLookup.exists(name);

void main() {
  group('s2/q9: stages 1 to 5 yield plain values and the convert is total', () {
    test('parseThemeValues gives ARGB ints, window-size names, and weight '
        'numbers', () {
      final plain = parseThemeValues(
        base: _default(),
        googleFontExists: _exists,
      );

      expect(plain.palette['brand.500'], isA<int>());
      expect(plain.color.light['brand.normal'], plain.palette['brand.500']);
      expect(
        plain.typography.types[FontType.body]!.weight,
        inInclusiveRange(100, 900),
      );
      for (final token in plain.space.values) {
        expect(
          token.all != null ||
              token.sizes!.keys.every(windowSizeNames.contains),
          isTrue,
        );
      }
    });

    test('StratumThemeConfig.parse is the stages, then the convert', () {
      final plain = parseThemeValues(
        base: _default(),
        googleFontExists: _exists,
      );
      final config = convertThemeConfig(plain);

      expect(config, StratumThemeConfig.parse(base: _default()));
      expect(config.palette['brand.500'], Color(plain.palette['brand.500']!));
    });

    test('q9: the stages refuse what the convert could not take', () {
      const layer = StratumThemeSource(
        id: 'brand',
        folder: 'assets/themes/brand',
        yaml:
            r'$schema: stratum-theme/v1.0.0'
            '\nspace:\n  md: { phablet: 4 }'
            '\ntypography:\n  types:\n    body: { weight: 450 }',
      );

      expect(
        () => parseThemeValues(
          base: _default(),
          layers: [layer],
          googleFontExists: _exists,
        ),
        throwsA(
          isA<StratumThemeFormatException>().having(
            (report) => [for (final error in report.errors) error.code],
            'codes',
            containsAll([
              StratumThemeErrorCode.unknownKey,
              StratumThemeErrorCode.invalidWeight,
            ]),
          ),
        ),
      );
    });
  });

  group('us10/fr01: the shadow blur radius (ruling R10) and the blur '
      'sigma', () {
    double sigmaOf(double blur) =>
        BoxShadow(blurRadius: shadowBlurRadius(blur)).blurSigma;

    test('a Figma blur r paints at sigma r / 2 from r = 1 up, at 0.5 below '
        '1, and at 0 for r = 0', () {
      expect(shadowBlurRadius(0), 0);
      expect(sigmaOf(0), 0);
      expect(shadowBlurRadius(0.25), double.minPositive);
      expect(sigmaOf(0.25), 0.5);
      expect(sigmaOf(0.5), 0.5);
      expect(sigmaOf(1), 0.5);
      for (final blur in [2.0, 8.0, 16.0, 24.0, 32.0, 64.0]) {
        expect(sigmaOf(blur), blur / 2, reason: 'r = $blur');
      }
      for (final blur in [1.5, 3.0, 4.0, 40.0, 80.0]) {
        expect(sigmaOf(blur), closeTo(blur / 2, 1e-9), reason: 'r = $blur');
      }
    });

    test('convertShadowLayer keeps the offset and the spread and takes a '
        'fixed color or the set color at its path', () {
      final fixed = convertShadowLayer(
        const StratumShadowLayer(
          x: -2,
          y: 3,
          blur: 8,
          spread: -1,
          color: StratumFixedLayerColor(0x1F000000),
        ),
        const {},
      );
      final fromSet = convertShadowLayer(
        const StratumShadowLayer(
          x: 0,
          y: 0,
          blur: 1,
          spread: 0,
          color: StratumSetLayerColor('shadow.primary'),
        ),
        const {'shadow.primary': Color(0x26000000)},
      );

      expect(fixed.offset, const Offset(-2, 3));
      expect(fixed.spreadRadius, -1);
      expect(fixed.color, const Color(0x1F000000));
      expect(fixed.blurSigma, 4);
      expect(fromSet.color, const Color(0x26000000));
      expect(fromSet.blurSigma, 0.5);
    });

    test('convertShadowLayer throws an ArgumentError naming a set path the '
        'set lacks', () {
      expect(
        () => convertShadowLayer(
          const StratumShadowLayer(
            x: 0,
            y: 0,
            blur: 1,
            spread: 0,
            color: StratumSetLayerColor('shadow.tertiary'),
          ),
          const {},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            'shadow.tertiary',
          ),
        ),
      );
    });

    test('convertBlur halves the Figma radius on both axes', () {
      expect(convertBlur(16), const ImageBlurFilter(sigmaX: 8, sigmaY: 8));
      expect(convertBlur(0), const ImageBlurFilter());
    });
  });
}
