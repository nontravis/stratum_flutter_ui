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
}
