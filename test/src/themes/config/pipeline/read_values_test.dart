import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/pipeline/read_values.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/system_names.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/config/transition_names.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

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
  return (
    convertThemeConfig(
      readThemeValues(
        resolved,
        checked.schema,
        all,
        errors,
        googleFontExists: (name) => GoogleFontsLookup.exists(name),
      ),
    ),
    errors,
  );
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

    test('reports a palette.app ramp written as an alias string once', () {
      const expected =
          'layer1 palette.app.mango: expected a map, got '
          '"{palette.brand.555}" [expected_map]';
      expect(_problems('palette:\n  app:\n    mango: "{palette.brand.555}"'), [
        expected,
      ]);
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

    test('an entry that aliases its own window-size token reports '
        'expected_dimension at the entry, and the token drops', () {
      const expected =
          'layer1 space.md.mobile: expected a number or "N%", got '
          '{mobile: {space.md}} [expected_dimension]';
      final (config, errors) = _read([
        layer('space:\n  md: { mobile: "{space.md}" }'),
      ]);

      expect(problems(errors), [expected]);
      expect(config.space.containsKey('md'), isFalse);
    });

    test('an entry that aliases a sibling still holding alias text '
        'reports expected_dimension; the sibling itself still reads', () {
      final (config, errors) = _read([
        layer(
          'space:\n  md: { mobile: "{space.lg}" }\n'
          '  lg: { mobile: "{radius.sm}" }',
        ),
      ]);
      const expected =
          'layer1 space.md.mobile: expected a number or "N%", got '
          '{mobile: {radius.sm}} [expected_dimension]';

      expect(problems(errors), [expected]);
      expect(config.space.containsKey('md'), isFalse);
      expect(
        config.space['lg']!.valueFor(WindowSize.mobile),
        const StratumDimension.fixed(8),
      );
    });

    test('a percent in space, radius, or a window-size entry is '
        'expected_dimension, and the token drops', () {
      final (config, errors) = _read([
        layer(
          'space:\n  md: 5%\n  gutter: { mobile: 16, desktop: "10%" }\n'
          'radius:\n  sm: "50%"',
        ),
      ]);

      const spaceMd =
          'layer1 space.md: expected a number, got "5%"; a percent is '
          'allowed only in layouts [expected_dimension]';
      const gutterDesktop =
          'layer1 space.gutter.desktop: expected a number, got "10%"; a '
          'percent is allowed only in layouts [expected_dimension]';
      const radiusSm =
          'layer1 radius.sm: expected a number, got "50%"; a percent is '
          'allowed only in layouts [expected_dimension]';
      expect(problems(errors), [spaceMd, gutterDesktop, radiusSm]);
      expect(config.space.containsKey('md'), isFalse);
      expect(
        config.space['gutter']!.valueFor(WindowSize.bigDesktop),
        const StratumDimension.fixed(16),
      );
    });

    test('a percent in layouts reads, scalar and per window size', () {
      final (config, errors) = _read([
        layer('layouts:\n  max-width-read: { mobile: 100%, desktop: 80% }'),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        config.layouts['max-width-read']!.valueFor(WindowSize.mobile),
        const StratumDimension.percent(1),
      );
      expect(
        config.layouts['max-width-read']!.valueFor(WindowSize.desktop),
        const StratumDimension.percent(0.8),
      );
    });

    test('a space alias to a layouts percent reports at the holder', () {
      const expected =
          'layer1 space.lg: expected a number, got "80%"; a percent is '
          'allowed only in layouts [expected_dimension]';

      expect(
        _problems(
          'layouts:\n  max-width-read: 80%\nspace:\n'
          '  lg: "{layouts.max-width-read}"',
        ),
        [expected],
      );
    });

    test('a radius alias to a space percent reports once, at the space '
        'token', () {
      const expected =
          'layer1 space.md: expected a number, got "5%"; a percent is '
          'allowed only in layouts [expected_dimension]';

      expect(_problems('space:\n  md: 5%\nradius:\n  sm: "{space.md}"'), [
        expected,
      ]);
    });
  });

  group('readThemeValues length bound', () {
    const fixed = 'expected a number from -10000 to 10000, got';
    const layout = 'expected a number or "N%" from -10000 to 10000, got';
    final cases = <(String, String, String)>[
      (
        'a space token past the bound',
        'space:\n  md: 10001',
        'layer1 space.md: $fixed 10001 [expected_dimension]',
      ),
      (
        'an infinite space token',
        'space:\n  lg: .inf',
        'layer1 space.lg: $fixed Infinity [expected_dimension]',
      ),
      (
        'a NaN radius token',
        'radius:\n  sm: .nan',
        'layer1 radius.sm: $fixed NaN [expected_dimension]',
      ),
      (
        'a radius token below the bound',
        'radius:\n  sm: -10001',
        'layer1 radius.sm: $fixed -10001 [expected_dimension]',
      ),
      (
        'a window-size entry of 1e300',
        'space:\n  gutter: { mobile: 16, desktop: 1e300 }',
        'layer1 space.gutter.desktop: $fixed 1e+300 [expected_dimension]',
      ),
      (
        'a layouts width past the bound',
        'layouts:\n  max-width-read: 10001',
        'layer1 layouts.max-width-read: $layout 10001 [expected_dimension]',
      ),
      (
        'a layouts percent past the bound',
        'layouts:\n  max-width-read: "10001%"',
        'layer1 layouts.max-width-read: $layout "10001%" '
            '[expected_dimension]',
      ),
    ];
    for (final (name, body, expected) in cases) {
      test('fo01/us01/fr01/e16: reports $name', () {
        expect(_problems(body), [expected]);
      });
    }

    test('fo01/us01/fr01/e16: reports a layouts percent whose digits '
        'overflow to infinity', () {
      final found = _problems('layouts:\n  max-width-read: "${'9' * 400}%"');

      expect(found, hasLength(1));
      expect(
        found.single,
        startsWith('layer1 layouts.max-width-read: $layout "999'),
      );
      expect(found.single, endsWith('[expected_dimension]'));
    });

    test('fo01/us01/fr01/e16: values at the bound read in space, radius, '
        'and layouts', () {
      final (config, errors) = _read([
        layer(
          'space:\n  md: 10000\n  lg: -10000\nradius:\n  sm: 10000\n'
          'layouts:\n  max-width-read: { mobile: "10000%", desktop: -10000 }',
        ),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        config.space['md'],
        const StratumByWindowSize.all(StratumDimension.fixed(10000)),
      );
      expect(
        config.space['lg'],
        const StratumByWindowSize.all(StratumDimension.fixed(-10000)),
      );
      expect(
        config.radius['sm'],
        const StratumByWindowSize.all(StratumDimension.fixed(10000)),
      );
      expect(
        config.layouts['max-width-read']!.valueFor(WindowSize.mobile),
        const StratumDimension.percent(100),
      );
      expect(
        config.layouts['max-width-read']!.valueFor(WindowSize.desktop),
        const StratumDimension.fixed(-10000),
      );
    });

    test('fo01/us01/fr01/e16: a space alias to a token past the bound '
        'reports once, at the target', () {
      expect(_problems('space:\n  md: 10001\n  lg: "{space.md}"'), [
        'layer1 space.md: $fixed 10001 [expected_dimension]',
      ]);
    });

    test('fo01/us01/fr01/e16: a space alias to a layouts percent past the '
        'bound reports once, at the layouts token', () {
      const expected =
          'layer1 layouts.max-width-read: $layout "20000%" '
          '[expected_dimension]';
      expect(
        _problems(
          'layouts:\n  max-width-read: "20000%"\nspace:\n'
          '  lg: "{layouts.max-width-read}"',
        ),
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

  group('readThemeValues animation', () {
    test('reads the levels, the default, the reverse ratio, and the '
        'curves', () {
      final (config, errors) = _read([]);

      expect(problems(errors), isEmpty);
      expect(config.animation.durations, {
        'micro': const Duration(milliseconds: 30),
        'veryFast': const Duration(milliseconds: 75),
        'fast': const Duration(milliseconds: 125),
        'normal': const Duration(milliseconds: 200),
        'slow': const Duration(milliseconds: 300),
        'verySlow': const Duration(milliseconds: 400),
      });
      expect(config.animation.defaultLevel, 'fast');
      expect(config.animation.reverseRatio, 0.64);
      expect(config.animation.curves, {
        'standard': const StratumNamedCurve('easeInOutSine'),
        'enter': const StratumNamedCurve('easeOut'),
        'exit': const StratumNamedCurve('easeIn'),
      });
      expect(config.animation.curves['standard']!.curve, Curves.easeInOutSine);
    });

    test('a layer that changes fast alone keeps the other levels', () {
      final (config, errors) = _read([
        layer('animation:\n  duration:\n    fast: 100'),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        config.animation.durations['fast'],
        const Duration(milliseconds: 100),
      );
      expect(
        config.animation.durations['slow'],
        const Duration(milliseconds: 300),
      );
    });

    test('fo01/us01/fr01: a layer that sets no micro keeps the base 30 ms', () {
      final (config, errors) = _read([
        layer('animation:\n  duration:\n    veryFast: 60'),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        config.animation.durations['micro'],
        const Duration(milliseconds: 30),
      );
      expect(
        config.animation.durations['veryFast'],
        const Duration(milliseconds: 60),
      );
    });

    test('fo01/us01/fr01: a layer may name micro as the default', () {
      final (config, errors) = _read([
        layer('animation:\n  duration:\n    default: micro'),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.animation.defaultLevel, 'micro');
    });

    test('fo01/us01/fr01: a layer may set its own micro value', () {
      final (config, errors) = _read([
        layer('animation:\n  duration:\n    micro: 20'),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        config.animation.durations['micro'],
        const Duration(milliseconds: 20),
      );
    });

    test('fo01/us01/fr01: reads animation.transition, platform for every '
        'window size in the base', () {
      final (config, errors) = _read([]);

      expect(problems(errors), isEmpty);
      expect(config.animation.transitions, {
        'watch': 'platform',
        'mobile': 'platform',
        'tablet': 'platform',
        'desktop': 'platform',
        'bigDesktop': 'platform',
      });
    });

    test('a layer that changes desktop alone keeps the other window '
        'sizes', () {
      final (config, errors) = _read([
        layer('animation:\n  transition:\n    desktop: rightToLeft'),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.animation.transitions['desktop'], 'rightToLeft');
      expect(config.animation.transitions['mobile'], 'platform');
    });

    test('every one of the 19 type names reads', () {
      expect(transitionTypeNames, hasLength(19));
      for (final name in transitionTypeNames) {
        final (config, errors) = _read([
          layer('animation:\n  transition:\n    mobile: $name'),
        ]);

        expect(problems(errors), isEmpty, reason: name);
        expect(config.animation.transitions['mobile'], name);
      }
    });

    test('0 ms, a fraction, 150%, and a new default read', () {
      final (config, errors) = _read([
        layer(
          'animation:\n  duration:\n    default: normal\n    fast: 0\n'
          '    slow: 12.5\n  reverseDuration: "150%"',
        ),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.animation.durations['fast'], Duration.zero);
      expect(
        config.animation.durations['slow'],
        const Duration(microseconds: 12500),
      );
      expect(config.animation.defaultLevel, 'normal');
      expect(config.animation.reverseRatio, 1.5);
    });

    test('reads cubic with spaces, without spaces, and with .5', () {
      final (config, errors) = _read([
        layer(
          'animation:\n  curve:\n    standard: "cubic(0.37, 0, 0.63, 1)"\n'
          '    enter: "cubic(0.4,0,0.2,1)"\n'
          '    exit: "cubic( .5 , -0.28 , .5 , 1.2 )"',
        ),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.animation.curves, {
        'standard': const StratumCubicCurve(0.37, 0, 0.63, 1),
        'enter': const StratumCubicCurve(0.4, 0, 0.2, 1),
        'exit': const StratumCubicCurve(0.5, -0.28, 0.5, 1.2),
      });
      final standard = config.animation.curves['standard']!;
      expect(standard.curve, isA<Cubic>());
      expect(standard.curve, same(standard.curve));
    });

    test('every curve name of the table reads', () {
      for (final name in StratumNamedCurve.names) {
        final (config, errors) = _read([
          layer('animation:\n  curve:\n    standard: $name'),
        ]);

        expect(problems(errors), isEmpty, reason: name);
        expect(
          config.animation.curves['standard']!.curve,
          same(StratumCurveConvert.byName[name]),
          reason: name,
        );
      }
    });

    final cases = <(String, String, String)>[
      (
        'a negative level',
        'animation:\n  duration:\n    fast: -10',
        'layer1 animation.duration.fast: expected a number of milliseconds '
            'of 0 or more, got -10 [expected_duration]',
      ),
      (
        'a level written as text',
        'animation:\n  duration:\n    fast: "125ms"',
        'layer1 animation.duration.fast: expected a number of milliseconds '
            'of 0 or more, got "125ms" [expected_duration]',
      ),
      (
        'a level written as a window-size map',
        'animation:\n  duration:\n    fast: { mobile: 100 }',
        'layer1 animation.duration.fast: expected a number of milliseconds '
            'of 0 or more, got {mobile: 100} [expected_duration]',
      ),
      (
        'an infinite level',
        'animation:\n  duration:\n    fast: .inf',
        'layer1 animation.duration.fast: expected a number of milliseconds '
            'of 0 or more, got Infinity [expected_duration]',
      ),
      (
        'a negative micro level',
        'animation:\n  duration:\n    micro: -10',
        'layer1 animation.duration.micro: expected a number of milliseconds '
            'of 0 or more, got -10 [expected_duration]',
      ),
      (
        'a default that names no level',
        'animation:\n  duration:\n    default: medium',
        'layer1 animation.duration.default: expected one of micro, '
            'veryFast, fast, normal, slow, verySlow, got "medium" '
            '[expected_duration]',
      ),
      (
        'a reverse duration without %',
        'animation:\n  reverseDuration: 64',
        'layer1 animation.reverseDuration: expected "N%" of 0% or more, got '
            '64 [expected_duration]',
      ),
      (
        'a negative reverse duration',
        'animation:\n  reverseDuration: "-5%"',
        'layer1 animation.reverseDuration: expected "N%" of 0% or more, got '
            '"-5%" [expected_duration]',
      ),
      (
        'a misspelled curve name',
        'animation:\n  curve:\n    enter: easeInOutSin',
        'layer1 animation.curve.enter: expected a Curves name or "cubic(a, '
            'b, c, d)", got "easeInOutSin" [expected_curve]',
      ),
      (
        'a curve name in the wrong case',
        'animation:\n  curve:\n    enter: EaseIn',
        'layer1 animation.curve.enter: expected a Curves name or "cubic(a, '
            'b, c, d)", got "EaseIn" [expected_curve]',
      ),
      (
        'a cubic x value outside 0 and 1',
        'animation:\n  curve:\n    exit: "cubic(1.2, 0, 0.6, 1)"',
        'layer1 animation.curve.exit: expected cubic x values a and c within '
            '0 and 1, got "cubic(1.2, 0, 0.6, 1)" [expected_curve]',
      ),
      (
        'a cubic with three values',
        'animation:\n  curve:\n    exit: "cubic(0.4, 0, 0.2)"',
        'layer1 animation.curve.exit: expected a Curves name or "cubic(a, '
            'b, c, d)", got "cubic(0.4, 0, 0.2)" [expected_curve]',
      ),
      (
        'a brace string, which is no alias here',
        'animation:\n  curve:\n    standard: "{animation.curve.enter}"',
        'layer1 animation.curve.standard: expected a Curves name or '
            '"cubic(a, b, c, d)", got "{animation.curve.enter}" '
            '[expected_curve]',
      ),
    ];
    for (final (name, body, expected) in cases) {
      test('reports $name', () {
        expect(_problems(body), [expected]);
      });
    }

    final transitionCases = <(String, String, String)>[
      (
        'an unknown transition type',
        'animation:\n  transition:\n    desktop: slideUp',
        'layer1 animation.transition.desktop: expected one of the 19 page '
            'transition types, such as platform or fade, got "slideUp" '
            '[expected_transition]',
      ),
      (
        'a transition type in the wrong case',
        'animation:\n  transition:\n    mobile: Fade',
        'layer1 animation.transition.mobile: expected one of the 19 page '
            'transition types, such as platform or fade, got "Fade" '
            '[expected_transition]',
      ),
      (
        'a number as a transition type',
        'animation:\n  transition:\n    watch: 3',
        'layer1 animation.transition.watch: expected one of the 19 page '
            'transition types, such as platform or fade, got 3 '
            '[expected_transition]',
      ),
    ];
    for (final (name, body, expected) in transitionCases) {
      test('us01/fr01/e11: reports $name', () {
        expect(_problems(body), [expected]);
      });
    }

    test('a token alias to an animation value is alias_not_token', () {
      const expected =
          'layer1 space.md: "{animation.duration.fast}" is outside the token '
          'groups [alias_not_token]';

      expect(_problems('space:\n  md: "{animation.duration.fast}"'), [
        expected,
      ]);
    });
  });

  group('readThemeValues opacity', () {
    test('fo01/us01/fr01: reads opacity.disabled and scrim 0.5 from the '
        'base', () {
      final (config, errors) = _read([]);

      expect(problems(errors), isEmpty);
      expect(config.opacity, {'disabled': 0.5, 'scrim': 0.5});
    });

    test('fo08/us07/fr01/e02: a layer that sets disabled to 0.3 wins', () {
      final (config, errors) = _read([layer('opacity:\n  disabled: 0.3')]);

      expect(problems(errors), isEmpty);
      expect(config.opacity['disabled'], 0.3);
    });

    test('fo08/us07/fr01/e03: a layer that leaves opacity out keeps the '
        "base's 0.5", () {
      final (config, errors) = _read([layer('name: ocean')]);

      expect(problems(errors), isEmpty);
      expect(config.opacity['disabled'], 0.5);
    });

    test('0, 1, a whole number, and a fraction read as opacities', () {
      for (final (yaml, expected) in [
        ('0', 0.0),
        ('1', 1.0),
        ('1.0', 1.0),
        ('0.25', 0.25),
      ]) {
        final (config, errors) = _read([layer('opacity:\n  disabled: $yaml')]);

        expect(problems(errors), isEmpty, reason: yaml);
        expect(config.opacity['disabled'], expected, reason: yaml);
      }
    });

    const expectedNumber =
        'layer1 opacity.disabled: expected a number from 0 to 1, got';
    final opacityCases = <(String, String, String)>[
      ('a value above 1', '1.5', '$expectedNumber 1.5 [expected_opacity]'),
      ('a value below 0', '-0.1', '$expectedNumber -0.1 [expected_opacity]'),
      ('NaN', '.nan', '$expectedNumber NaN [expected_opacity]'),
      ('infinity', '.inf', '$expectedNumber Infinity [expected_opacity]'),
      (
        'minus infinity',
        '-.inf',
        '$expectedNumber -Infinity [expected_opacity]',
      ),
      ('a quoted number', '"0.5"', '$expectedNumber "0.5" [expected_opacity]'),
      ('a boolean', 'true', '$expectedNumber true [expected_opacity]'),
      ('a percent', '50%', '$expectedNumber "50%" [expected_opacity]'),
      (
        'a brace string, which is no alias here',
        '"{space.md}"',
        '$expectedNumber "{space.md}" [expected_opacity]',
      ),
    ];
    for (final (name, value, expected) in opacityCases) {
      test('fo01/us01/fr01/e12: reports $name', () {
        expect(_problems('opacity:\n  disabled: $value'), [expected]);
      });
    }

    test('an empty disabled value is required', () {
      expect(_problems('opacity:\n  disabled:'), [
        'layer1 opacity.disabled: required [required]',
      ]);
    });

    test('fo01/us01/fr01/e12: a v1.3 file with scrim 1.2 reports '
        'expected_opacity', () {
      const scrimBadValue =
          'layer1 opacity.scrim: expected a number from 0 to 1, got 1.2 '
          '[expected_opacity]';
      final (_, errors) = _read([
        '\$schema: stratum-theme/v1.3.0\nopacity:\n  scrim: 1.2\n',
      ]);

      expect(problems(errors), [scrimBadValue]);
    });
  });

  group('readThemeValues border, shadow, and blur', () {
    test('fo01/us01/fr01: reads the three groups from the base', () {
      final (config, errors) = _read([]);

      expect(problems(errors), isEmpty);
      expect(config.border, {'sm': 0.5, 'md': 1.0, 'lg': 1.5});
      expect(config.blur, {
        '1': 4.0,
        '2': 8.0,
        '3': 16.0,
        '4': 24.0,
        '5': 40.0,
        '6': 80.0,
      });
      expect(config.shadow.keys, ['1', '2', '3', '4', '5', '6']);
      expect(config.shadow['1'], const [
        StratumShadowLayer(
          x: 0,
          y: 1,
          blur: 2,
          spread: 0,
          color: StratumSetLayerColor('brand.hover'),
        ),
        StratumShadowLayer(
          x: 0,
          y: 0,
          blur: 1,
          spread: 0,
          color: StratumFixedLayerColor(0x26000000),
        ),
      ]);
      expect(config.shadow['2'], isEmpty);
    });

    test('fo01/us01/fr01: a layer that leaves the three groups out keeps '
        "the base's values", () {
      final (config, errors) = _read([layer('name: ocean')]);

      expect(problems(errors), isEmpty);
      expect(config.border['md'], 1);
      expect(config.shadow['1'], hasLength(2));
      expect(config.blur['3'], 16);
    });

    test('fo01/us04/fr01: a layer that sets one border width keeps the '
        'other two', () {
      final (config, errors) = _read([layer('border:\n  md: 2')]);

      expect(problems(errors), isEmpty);
      expect(config.border, {'sm': 0.5, 'md': 2.0, 'lg': 1.5});
    });

    test('fo01/us04/fr01/e05: a list of three layers replaces the default '
        'list whole; x, y, and spread may be negative', () {
      final (config, errors) = _read([
        layer('''
shadow:
  "1":
    - {x: 1, y: 2, blur: 3, spread: 4, color: "#FF0000"}
    - {x: -1, y: -2, blur: 0, spread: -4, color: "#00FF0080"}
    - {x: 0, y: 0, blur: 0.5, spread: 0, color: "{color.brand.normal}"}'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.shadow['1'], const [
        StratumShadowLayer(
          x: 1,
          y: 2,
          blur: 3,
          spread: 4,
          color: StratumFixedLayerColor(0xFFFF0000),
        ),
        StratumShadowLayer(
          x: -1,
          y: -2,
          blur: 0,
          spread: -4,
          color: StratumFixedLayerColor(0x8000FF00),
        ),
        StratumShadowLayer(
          x: 0,
          y: 0,
          blur: 0.5,
          spread: 0,
          color: StratumSetLayerColor('brand.normal'),
        ),
      ]);
    });

    test('fo01/us04/fr01/e05: an empty list replaces the default list and '
        'means no shadow', () {
      final (config, errors) = _read([layer('shadow:\n  "1": []')]);

      expect(problems(errors), isEmpty);
      expect(config.shadow['1'], isEmpty);
      expect(config.shadow, hasLength(6));
    });

    const layerOf = '{x: 0, y: 1, blur: 2, spread: 0, color: "#000000"}';
    String level2(String item) => 'shadow:\n  "2":\n    - $item';
    const nonNegative = 'expected a number from 0 to 10000, got';
    const signed = 'expected a number from -10000 to 10000, got';
    const keys = 'expected the keys x, y, blur, spread, and color, got';
    final cases = <(String, String, String, String)>[
      (
        'fo01/us01/fr01/e13',
        'a negative border width',
        'border:\n  sm: -1',
        'layer1 border.sm: $nonNegative -1 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a border width that is a word',
        'border:\n  md: thin',
        'layer1 border.md: $nonNegative "thin" [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a border width per window size',
        'border:\n  md: { mobile: 1 }',
        'layer1 border.md: $nonNegative {mobile: 1} [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'an infinite border width',
        'border:\n  lg: .inf',
        'layer1 border.lg: $nonNegative Infinity [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a negative blur radius',
        'blur:\n  "3": -4',
        'layer1 blur.3: $nonNegative -4 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a quoted blur radius',
        'blur:\n  "1": "4"',
        'layer1 blur.1: $nonNegative "4" [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a NaN blur radius',
        'blur:\n  "2": .nan',
        'layer1 blur.2: $nonNegative NaN [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a negative layer blur',
        level2(layerOf.replaceFirst('blur: 2', 'blur: -2')),
        'layer1 shadow.2.0.blur: $nonNegative -2 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a quoted layer x',
        level2(layerOf.replaceFirst('x: 0', 'x: "0"')),
        'layer1 shadow.2.0.x: $signed "0" [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a word for layer y',
        level2(layerOf.replaceFirst('y: 1', 'y: one')),
        'layer1 shadow.2.0.y: $signed "one" [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a boolean layer spread',
        level2(layerOf.replaceFirst('spread: 0', 'spread: true')),
        'layer1 shadow.2.0.spread: $signed true [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'an infinite layer x',
        level2(layerOf.replaceFirst('x: 0', 'x: -.inf')),
        'layer1 shadow.2.0.x: $signed -Infinity [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e14',
        'a shadow level that is a number',
        'shadow:\n  "2": 4',
        'layer1 shadow.2: expected a list of shadow layers, got 4 '
            '[expected_shadow]',
      ),
      (
        'fo01/us01/fr01/e14',
        'a shadow level that is one layer, not a list',
        'shadow:\n  "2": $layerOf',
        'layer1 shadow.2: expected a list of shadow layers, got {x: 0, y: 1, '
            'blur: 2, spread: 0, color: #000000} [expected_shadow]',
      ),
      (
        'fo01/us01/fr01/e14',
        'a layer that is a number',
        level2('4'),
        'layer1 shadow.2.0: expected a map of x, y, blur, spread, and color, '
            'got 4 [expected_shadow]',
      ),
      (
        'fo01/us01/fr01/e14',
        'a layer without a color',
        level2('{x: 0, y: 1, blur: 2, spread: 0}'),
        'layer1 shadow.2.0: $keys "x", "y", "blur", "spread" '
            '[expected_shadow]',
      ),
      (
        'fo01/us01/fr01/e14',
        'a layer with a sixth key',
        level2(layerOf.replaceFirst('}', ', z: 1}')),
        'layer1 shadow.2.0: $keys "x", "y", "blur", "spread", "color", "z" '
            '[expected_shadow]',
      ),
      (
        'fo01/us01/fr01/e14',
        'an empty layer',
        level2('{}'),
        'layer1 shadow.2.0: $keys none [expected_shadow]',
      ),
      (
        'fo01/us01/fr01/e15',
        'a layer color that is a word',
        level2(layerOf.replaceFirst('"#000000"', 'red')),
        'layer1 shadow.2.0.color: $_hex "red" [expected_color]',
      ),
      (
        'fo01/us01/fr01/e15',
        'a layer color that is a number',
        level2(layerOf.replaceFirst('"#000000"', '12')),
        'layer1 shadow.2.0.color: $_hex 12 [expected_color]',
      ),
      (
        'fo01/us01/fr01/e15',
        'a bad color in the second layer, at its own index',
        'shadow:\n  "2":\n    - $layerOf\n'
            '    - ${layerOf.replaceFirst('"#000000"', 'nope')}',
        'layer1 shadow.2.1.color: $_hex "nope" [expected_color]',
      ),
      (
        'fo01/us01/fr01/e05',
        'an empty border width',
        'border:\n  sm:',
        'layer1 border.sm: required [required]',
      ),
      (
        'fo01/us01/fr01/e05',
        'an empty shadow level',
        'shadow:\n  "2":',
        'layer1 shadow.2: required [required]',
      ),
      (
        'fo01/us01/fr01/e05',
        'an empty layer x',
        level2(layerOf.replaceFirst('x: 0', 'x: null')),
        'layer1 shadow.2.0.x: required [required]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a border width past the length bound',
        'border:\n  md: 10001',
        'layer1 border.md: $nonNegative 10001 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a blur radius of 1e300',
        'blur:\n  "1": 1e300',
        'layer1 blur.1: $nonNegative 1e+300 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a layer blur past the length bound',
        level2(layerOf.replaceFirst('blur: 2', 'blur: 10000.5')),
        'layer1 shadow.2.0.blur: $nonNegative 10000.5 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a layer x of 1e200',
        level2(layerOf.replaceFirst('x: 0', 'x: 1e200')),
        'layer1 shadow.2.0.x: $signed 1e+200 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a layer spread below the length bound',
        level2(layerOf.replaceFirst('spread: 0', 'spread: -10001')),
        'layer1 shadow.2.0.spread: $signed -10001 [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a NaN layer y',
        level2(layerOf.replaceFirst('y: 1', 'y: .nan')),
        'layer1 shadow.2.0.y: $signed NaN [expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a layer x of int min',
        level2(layerOf.replaceFirst('x: 0', 'x: -9223372036854775808')),
        'layer1 shadow.2.0.x: $signed -9223372036854775808 '
            '[expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a layer y of int min',
        level2(layerOf.replaceFirst('y: 1', 'y: -9223372036854775808')),
        'layer1 shadow.2.0.y: $signed -9223372036854775808 '
            '[expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e13',
        'a layer spread of int min',
        level2(
          layerOf.replaceFirst('spread: 0', 'spread: -9223372036854775808'),
        ),
        'layer1 shadow.2.0.spread: $signed -9223372036854775808 '
            '[expected_dimension]',
      ),
      (
        'fo01/us01/fr01/e14',
        'a shadow level of nine layers',
        'shadow:\n  "2":\n${'    - $layerOf\n' * 9}',
        'layer1 shadow.2: expected at most 8 shadow layers, got 9 '
            '[expected_shadow]',
      ),
      (
        'fo01/us01/fr01/e14',
        'a nine-layer level once; stage 5 reads none of its layers',
        'shadow:\n  "2":\n${'    - {x: 0, color: red}\n' * 9}',
        'layer1 shadow.2: expected at most 8 shadow layers, got 9 '
            '[expected_shadow]',
      ),
    ];
    for (final (tag, name, body, expected) in cases) {
      test('$tag: reports $name', () {
        expect(_problems(body), [expected]);
      });
    }

    test('fo01/us01/fr01/e14: a level of eight layers reads all eight', () {
      final (config, errors) = _read([
        layer('shadow:\n  "2":\n${'    - $layerOf\n' * 8}'),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.shadow['2'], hasLength(8));
    });

    test('fo01/us01/fr01/e13: a width, a radius, and a layer at the length '
        'bound read', () {
      final (config, errors) = _read([
        layer('''
border:
  md: 10000
blur:
  "1": 10000
shadow:
  "2":
    - {x: -10000, y: 10000, blur: 10000, spread: -10000, color: "#000000"}'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.border['md'], 10000);
      expect(config.blur['1'], 10000);
      expect(config.shadow['2'], const [
        StratumShadowLayer(
          x: -10000,
          y: 10000,
          blur: 10000,
          spread: -10000,
          color: StratumFixedLayerColor(0xFF000000),
        ),
      ]);
    });
  });

  group('readThemeValues border, blur, and shadow color aliases', () {
    test('fo01/us01/fr01: a layer reads a color set reference, a palette '
        'alias, a transparent alias, and a hex', () {
      final (config, errors) = _read([
        layer('''
shadow:
  "1":
    - {x: 0, y: 1, blur: 2, spread: 0, color: "{color.brand.normal}"}
    - {x: 0, y: 1, blur: 2, spread: 0, color: "{palette.brand.600}"}
    - {x: 0, y: 1, blur: 2, spread: 0, color: "{transparent.black.12}"}
    - {x: 0, y: 1, blur: 2, spread: 0, color: "#123456"}'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        [for (final layer in config.shadow['1']!) layer.color],
        const [
          StratumSetLayerColor('brand.normal'),
          StratumFixedLayerColor(0xFF2563EB),
          StratumFixedLayerColor(0x1F000000),
          StratumFixedLayerColor(0xFF123456),
        ],
      );
    });

    test('fo01/us03/fr01: an app theme that sets blur."4" to "{blur.3}" '
        'reads radius 16', () {
      final (config, errors) = _read([layer('blur:\n  "4": "{blur.3}"')]);

      expect(problems(errors), isEmpty);
      expect(config.blur['4'], 16);
    });

    test("fo01/us03/fr01: a border alias inside its group reads its target's "
        'width', () {
      final (config, errors) = _read([layer('border:\n  lg: "{border.md}"')]);

      expect(problems(errors), isEmpty);
      expect(config.border['lg'], 1);
    });

    test('fo01/us01/fr01/e13: a blur alias to a negative radius reports '
        'once, at the target', () {
      const expected =
          'layer1 blur.3: expected a number from 0 to 10000, got -1 '
          '[expected_dimension]';
      expect(_problems('blur:\n  "3": -1\n  "4": "{blur.3}"'), [expected]);
    });

    test('fo01/us01/fr01/e13: a border alias to a width past the length '
        'bound reports once, at the target', () {
      const expected =
          'layer1 border.md: expected a number from 0 to 10000, got 10001 '
          '[expected_dimension]';
      expect(_problems('border:\n  md: 10001\n  lg: "{border.md}"'), [
        expected,
      ]);
    });

    test('fo01/us01/fr01/e04: a layer color alias to a bad shade reports '
        'once, at the shade', () {
      const layer =
          'palette:\n  brand:\n    600: red\nshadow:\n  "1":\n'
          '    - {x: 0, y: 1, blur: 2, spread: 0, '
          'color: "{palette.brand.600}"}';
      expect(_problems(layer), [
        'layer1 palette.brand.600: $_hex "red" [expected_color]',
      ]);
    });

    test('fo01/us03/fr01/e05: a layer color alias that fails in stage 4 '
        'reports nothing in stage 5', () {
      const expected =
          'layer1 shadow.1.0.color: "{space.md}" names a space token, not a '
          'color [alias_not_token]';
      expect(
        _problems(
          'shadow:\n  "1":\n'
          '    - {x: 0, y: 1, blur: 2, spread: 0, color: "{space.md}"}',
        ),
        [expected],
      );
    });
  });

  group('readThemeValues system', () {
    const lightLook = SystemStyle(
      statusBarIcons: SystemBarIcons.auto,
      statusBarColor: Color(0x00000000),
      statusBarContrast: false,
      navigationBarIcons: SystemBarIcons.auto,
      navigationBarColor: Color(0x00000000),
      navigationBarDividerColor: Color(0x00000000),
      navigationBarContrast: true,
      appSwitcherColor: Color(0xFF3B82F6),
    );

    test('fo01/us01/fr01: reads the four sets of the base, each alias '
        'resolved', () {
      final (config, errors) = _read([]);

      expect(problems(errors), isEmpty);
      expect(config.system, {
        'light': lightLook,
        'dark': lightLook.copyWith(appSwitcherColor: const Color(0xFF2563EB)),
        'highContrastLight': lightLook,
        'highContrastDark': lightLook.copyWith(
          appSwitcherColor: const Color(0xFF2563EB),
        ),
      });
    });

    test('us14/fr01/e03: a high-contrast set lays its keys over its base '
        'set and leaves the base alone', () {
      final (config, errors) = _read([
        layer('system:\n  highContrastDark:\n    statusBarIcons: light'),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        config.system['highContrastDark']!.statusBarIcons,
        SystemBarIcons.light,
      );
      expect(config.system['dark']!.statusBarIcons, SystemBarIcons.auto);
      expect(
        config.system['highContrastDark']!.appSwitcherColor,
        const Color(0xFF2563EB),
      );
    });

    test('us14/fr01/e03: a high-contrast set reads its color aliases in '
        'its own color set', () {
      final (config, errors) = _read([
        layer(
          'color:\n  highContrastLight:\n    brand:\n'
          '      normal: "#000001"',
        ),
      ]);

      expect(problems(errors), isEmpty);
      expect(
        config.system['highContrastLight']!.appSwitcherColor,
        const Color(0xFF000001),
      );
      expect(config.system['light']!.appSwitcherColor, const Color(0xFF3B82F6));
    });

    test('fo01/us01/fr01: a layer sets a color by hex or by a palette '
        'alias', () {
      final (config, errors) = _read([
        layer(
          'system:\n  light:\n    statusBarColor: "{palette.gray.950}"\n'
          '    navigationBarColor: "#11223344"',
        ),
      ]);

      expect(problems(errors), isEmpty);
      expect(config.system['light']!.statusBarColor, const Color(0xFF030712));
      expect(
        config.system['light']!.navigationBarColor,
        const Color(0x44112233),
      );
    });

    final cases = <(String, String, String)>[
      (
        'fo01/us01/fr01/e17: a number for a color',
        'system:\n  light:\n    statusBarColor: 12',
        'layer1 system.light.statusBarColor: $_hex 12 [expected_color]',
      ),
      (
        'fo01/us01/fr01/e17: an alias to a space token',
        'system:\n  dark:\n    appSwitcherColor: "{space.md}"',
        'layer1 system.dark.appSwitcherColor: $_hex 16 (from "{space.md}") '
            '[expected_color]',
      ),
      (
        'fo01/us01/fr01/e17: an alias into the system group',
        'system:\n  light:\n    statusBarColor: '
            '"{system.dark.statusBarColor}"',
        'layer1 system.light.statusBarColor: "{system.dark.statusBarColor}" '
            'is outside the token groups [alias_not_token]',
      ),
      (
        'fo01/us01/fr01/e18: an icons value outside auto, light, dark',
        'system:\n  light:\n    statusBarIcons: bright',
        'layer1 system.light.statusBarIcons: expected one of auto, light, '
            'dark, got "bright" [expected_bar_icons]',
      ),
      (
        'fo01/us01/fr01/e18: an icons value in another case',
        'system:\n  dark:\n    navigationBarIcons: Auto',
        'layer1 system.dark.navigationBarIcons: expected one of auto, light, '
            'dark, got "Auto" [expected_bar_icons]',
      ),
      (
        'fo01/us01/fr01/e19: a quoted boolean',
        'system:\n  light:\n    navigationBarContrast: "true"',
        'layer1 system.light.navigationBarContrast: expected true or false, '
            'got "true" [expected_boolean]',
      ),
      (
        'fo01/us01/fr01/e19: a number for a contrast flag',
        'system:\n  dark:\n    statusBarContrast: 1',
        'layer1 system.dark.statusBarContrast: expected true or false, got 1 '
            '[expected_boolean]',
      ),
      (
        'fo01/us01/fr01/e05: an empty icons value',
        'system:\n  light:\n    statusBarIcons:',
        'layer1 system.light.statusBarIcons: required [required]',
      ),
    ];
    for (final (name, body, expected) in cases) {
      test('$name reports once, in its base set only', () {
        expect(_problems(body), [expected]);
      });
    }

    test('systemBarIconNames follows SystemBarIcons', () {
      expect(systemBarIconNames, [
        for (final icons in SystemBarIcons.values) icons.name,
      ]);
    });
  });
}
