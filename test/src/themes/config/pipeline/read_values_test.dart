import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/pipeline/read_values.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';

import '../theme_fixtures.dart';

/// Runs stages 1 to 5 on [base] and [layers].
(StratumThemeConfig, ThemeErrors) _read(
  List<String> layers, {
  String base = baseYaml,
}) {
  final all = sources(layers, base: base);
  final errors = errorsFor(all);
  final roots = loadThemes(all, errors);
  expect(problems(errors), isEmpty, reason: 'stage 1');
  final checked = checkThemeKeys(roots, errors);
  final merged = mergeThemes(checked, errors);
  final resolved = resolveThemeAliases(merged, checked.schema, errors);
  return (readThemeValues(resolved, checked.schema, all, errors), errors);
}

/// The errors stages 1 to 5 report for one layer of [body].
List<String> _problems(String body) => problems(_read([layer(body)]).$2);

const _hex = 'expected "#RRGGBB" or "#RRGGBBAA", got';

const _buttonPrimaryNumber =
    'layer1 color.light.button.primary.normal: $_hex 12 [expected_color]';

const _backgroundInputDisabled =
    'layer1 color.light.background.control.input-disabled: required '
    '[required]';

/// A base whose `splash-screen` slot names `images/splash.svg`.
final String _baseWithSplash = baseYaml.replaceFirst(
  '  splash-screen:\n',
  '  splash-screen: images/splash.svg\n',
);

void main() {
  group('readThemeValues colors', () {
    test('the base fixture reads whole; the high-contrast sets are full', () {
      final (config, errors) = _read([]);

      expect(problems(errors), isEmpty);
      expect(config.name, 'base');
      expect(config.color.light, {
        'brand.normal': const Color(0xFF3B82F6),
        'brand.hover': const Color(0xFF2563EB),
        'button.primary.normal': const Color(0xFF3B82F6),
        'background.control.input-disabled': const Color(0x08000000),
        'transparent.0': const Color(0x00FFFFFF),
      });
      expect(config.color.highContrastLight, config.color.light);
      expect(config.color.highContrastDark, config.color.dark);
      expect(config.palette, {
        'brand.500': const Color(0xFF3B82F6),
        'brand.600': const Color(0xFF2563EB),
        'brand.700': const Color(0xFF1D4ED8),
        'gray.950': const Color(0xFF030712),
      });
    });

    test('reads #RRGGBB and #RRGGBBAA, alpha last, in either case', () {
      final (config, errors) = _read([
        layer('''
palette:
  brand:
    700: "#1d4ed8cc"
color:
  light:
    brand:
      normal: "#FF000014"
      hover: "#3b82f6"'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.color.light['brand.normal'], const Color(0x14FF0000));
      expect(config.color.light['brand.hover'], const Color(0xFF3B82F6));
      expect(
        config.color.light['button.primary.normal'],
        const Color(0x14FF0000),
      );
      expect(config.color.dark['brand.hover'], const Color(0xCC1D4ED8));
    });

    test('reports a short hex, a hex without #, a number, and null', () {
      expect(
        _problems('''
color:
  light:
    brand:
      normal: "#FFF"
      hover: "FFFFFF"
    button:
      primary:
        normal: 12
    background:
      control:
        input-disabled:'''),
        [
          'layer1 color.light.brand.normal: $_hex "#FFF" [expected_color]',
          'layer1 color.light.brand.hover: $_hex "FFFFFF" [expected_color]',
          _buttonPrimaryNumber,
          _backgroundInputDisabled,
        ],
      );
    });

    test('checks the kind after resolution, at the holder, naming the '
        'alias', () {
      const expected =
          'layer1 color.light.brand.normal: $_hex 16 (from "{space.md}") '
          '[expected_color]';
      expect(
        _problems('color:\n  light:\n    brand:\n      normal: "{space.md}"'),
        [expected],
      );
    });

    test('reports a failed target once, at the target', () {
      expect(_problems('palette:\n  brand:\n    500: "#XYZ"'), [
        'layer1 palette.brand.500: $_hex "#XYZ" [expected_color]',
      ]);
    });

    test('reports an unquoted alias in a shade once, at the shade', () {
      const expected =
          'layer1 palette.brand.500: $_hex {palette.gray.950: null} '
          '[expected_color]';
      expect(_problems('palette:\n  brand:\n    500: {palette.gray.950}'), [
        expected,
      ]);
    });

    test('reports a window-size map on a color token as expected_color', () {
      const expected =
          'layer1 color.light.brand.normal: $_hex {mobile: #FFFFFF} '
          '[expected_color]';
      expect(
        _problems(
          'color:\n  light:\n    brand:\n      normal: { mobile: "#FFFFFF" }',
        ),
        [expected],
      );
    });

    test('reports a palette.app ramp written as one color', () {
      const expected =
          'layer1 palette.app.mango: expected a map, got "#FFAA00" '
          '[expected_map]';
      expect(_problems('palette:\n  app:\n    mango: "#FFAA00"'), [expected]);
    });

    test('reads app colors and app ramps', () {
      final (config, errors) = _read([
        layer('''
palette:
  app:
    mango: { 500: "#FFAA00" }
color:
  light:
    app: { mango: "{palette.app.mango.500}" }
  dark:
    app: { mango: "#AA7700" }'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.palette['app.mango.500'], const Color(0xFFFFAA00));
      expect(config.color.light['app.mango'], const Color(0xFFFFAA00));
      expect(
        config.color.highContrastLight['app.mango'],
        const Color(0xFFFFAA00),
      );
      expect(
        config.color.highContrastDark['app.mango'],
        const Color(0xFFAA7700),
      );
    });
  });

  group('readThemeValues dimensions', () {
    test('reads a scalar for every window size and a map per window size', () {
      final (config, _) = _read([]);

      expect(
        config.space['md'],
        const StratumByWindowSize.all(StratumDimension.fixed(16)),
      );
      expect(
        config.space['gutter']!.valueFor(WindowSize.tablet),
        const StratumDimension.fixed(16),
      );
      expect(
        config.space['gutter']!.valueFor(WindowSize.bigDesktop),
        const StratumDimension.fixed(32),
      );
      expect(
        config.layouts['max-width-read'],
        const StratumByWindowSize.all(StratumDimension.fixed(720)),
      );
    });

    test('reports an unknown window size, an empty map, and a bad value; '
        'the valid entries still read', () {
      final (config, errors) = _read([
        layer(
          'space:\n  md: { mobile: 12, laptop: 20 }\n  lg: {}\n'
          '  gutter: "16px"',
        ),
      ]);

      const gutterBadValue =
          'layer1 space.gutter: expected a number or "N%", got "16px" '
          '[expected_dimension]';
      expect(problems(errors), [
        'layer1 space.md.laptop: unknown window size "laptop" [unknown_key]',
        'layer1 space.lg: required [required]',
        gutterBadValue,
      ]);
      expect(
        config.space['md']!.valueFor(WindowSize.desktop),
        const StratumDimension.fixed(12),
      );
    });

    test('reports an entry whose alias names a window-size map', () {
      const expected =
          'layer1 radius.sm.desktop: expected a number or "N%", got '
          '{mobile: 16, desktop: 32} [expected_dimension]';
      expect(
        _problems('radius:\n  sm: { mobile: 4, desktop: "{space.gutter}" }'),
        [expected],
      );
    });
  });

  group('readThemeValues assets', () {
    test('each kind maps from its extension, in any case', () {
      expect(
        {
          for (final extension in [
            'png',
            'jpg',
            'jpeg',
            'webp',
            'gif',
            'svg',
            'json',
            'lottie',
            'PNG',
            'bmp',
          ])
            extension: StratumAssetKind.fromExtension(extension),
        },
        {
          'png': StratumAssetKind.image,
          'jpg': StratumAssetKind.image,
          'jpeg': StratumAssetKind.image,
          'webp': StratumAssetKind.image,
          'gif': StratumAssetKind.image,
          'svg': StratumAssetKind.svg,
          'json': StratumAssetKind.lottie,
          'lottie': StratumAssetKind.lottie,
          'PNG': StratumAssetKind.image,
          'bmp': null,
        },
      );
    });

    test('a slot resolves against the folder of the file that set it', () {
      final (config, errors) = _read([
        layer('assets:\n  loading: anim/Loading.LOTTIE'),
      ], base: _baseWithSplash);

      expect(problems(errors), isEmpty);
      expect(config.assets, {
        'splash-screen': const StratumThemeAsset(
          kind: StratumAssetKind.svg,
          path: '$baseFolder/images/splash.svg',
        ),
        'loading': const StratumThemeAsset(
          kind: StratumAssetKind.lottie,
          path: 'themes/layer1/anim/Loading.LOTTIE',
        ),
      });
    });

    test('a null or empty slot names no asset and clears a lower one', () {
      final (config, errors) = _read([
        layer('assets:\n  splash-screen: ""'),
      ], base: _baseWithSplash);

      expect(problems(errors), isEmpty);
      expect(config.assets, isEmpty);
    });

    final cases = <(String, String, String)>[
      (
        'a .. segment',
        'assets/../splash.png',
        'expected a path inside the theme folder, got "assets/../splash.png" '
            '[invalid_asset]',
      ),
      (
        'a leading /',
        '/splash.png',
        'expected a path inside the theme folder, got "/splash.png" '
            '[invalid_asset]',
      ),
      (
        'a .bmp file',
        'splash.bmp',
        'expected one of png, jpg, jpeg, webp, svg, gif, json, lottie, got '
            '"splash.bmp" [invalid_asset]',
      ),
      (
        'no extension',
        'splash',
        'expected one of png, jpg, jpeg, webp, svg, gif, json, lottie, got '
            '"splash" [invalid_asset]',
      ),
      ('a number', '12', 'expected a string, got 12 [expected_string]'),
    ];
    for (final (name, value, expected) in cases) {
      test('reports $name', () {
        expect(_problems('assets:\n  loading: $value'), [
          'layer1 assets.loading: $expected',
        ]);
      });
    }
  });

  group('readThemeValues extensions and typography', () {
    test(
      'extensions read as plain values, brace strings kept, unmodifiable',
      () {
        final (config, errors) = _read([
          layer('''
extensions:
  1: one
  link: "{palette.brand.500}"
  list: [a, { b: 2 }]
  flag: true'''),
        ]);

        expect(problems(errors), isEmpty);
        expect(config.extensions, {
          '1': 'one',
          'link': '{palette.brand.500}',
          'list': [
            'a',
            {'b': 2},
          ],
          'flag': true,
        });
        expect(() => config.extensions['x'] = 1, throwsUnsupportedError);
      },
    );

    test("typography errors join the list, each at its layer's position", () {
      final (_, errors) = _read([
        layer('''
color:
  light:
    brand:
      normal: "#1"
typography:
  scaleByWindowSize: { laptop: 1 }
  types:
    header: { weight: 650 }'''),
      ]);

      const scaleError =
          'layer1 typography.scaleByWindowSize.laptop: '
          'unknown window size "laptop" [unknown_key]';
      const weightError =
          'layer1 typography.types.header.weight: '
          'expected 100 to 900 in steps of 100, got 650 [invalid_weight]';
      expect(problems(errors), [
        'layer1 color.light.brand.normal: $_hex "#1" [expected_color]',
        scaleError,
        weightError,
      ]);
      expect(errors.sorted[1].line, 7);
      expect(errors.sorted[1].column, 24);
    });
  });
}
