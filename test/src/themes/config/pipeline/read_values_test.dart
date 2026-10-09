import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/pipeline/read_values.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
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
}
