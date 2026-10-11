import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'theme_fixtures.dart';

/// [StratumThemeConfig.parse] of the base fixture or [base] under [layers].
StratumThemeConfig _parse(List<String> layers, {String base = baseYaml}) {
  final all = sources(layers, base: base);
  return StratumThemeConfig.parse(base: all.first, layers: all.sublist(1));
}

/// The text of the exception [_parse] throws for [layers].
String _report(List<String> layers, {String base = baseYaml}) {
  try {
    _parse(layers, base: base);
  } on StratumThemeFormatException catch (exception) {
    return '$exception';
  }
  return 'no exception';
}

/// The app theme `ocean` of spec section 9.
const _ocean = r'''
$schema: stratum-theme/v1.0.0
name: Ocean
spcae:
  md: 12
space:
  md: { mobile: 12, laptop: 20 }
color:
  light:
    brand:
      normal: "#3B82F"
      hover: "{palette.brand.555}"
    app:
      mango: "{palette.app.mango.500}"
palette:
  app:
    mango:
      500: "#FFAA00"
''';

StratumThemeSource _oceanSource(String yaml) =>
    StratumThemeSource(id: 'ocean', folder: 'themes/ocean', yaml: yaml);

void main() {
  group('StratumThemeConfig.parse reports', () {
    test('the spec section 9 sample, text and order exactly', () {
      expect(
        () => StratumThemeConfig.parse(
          base: sources(const []).single,
          layers: [_oceanSource(_ocean)],
        ),
        throwsA(
          isA<StratumThemeFormatException>().having(
            (exception) => '$exception',
            'toString',
            'StratumThemeFormatException: 5 problem(s) in theme.yaml\n'
                '  ocean:3:1 spcae: unknown key "spcae" [unknown_key]\n'
                '  ocean:6:21 space.md.laptop: unknown window size "laptop" '
                '[unknown_key]\n'
                '  ocean:10:15 color.light.brand.normal: expected "#RRGGBB" '
                'or "#RRGGBBAA", got "#3B82F" [expected_color]\n'
                '  ocean:11:14 color.light.brand.hover: "{palette.brand.555}" '
                'names no token [unknown_alias]\n'
                '  ocean:13:7 color.dark.app.mango: required; '
                'color.light.app.mango has no dark value [required]',
          ),
        ),
      );
    });

    test('one stage-1 error and nothing else: the parse stops there, so the '
        'bad color is not reported', () {
      final newer = _ocean.replaceFirst('v1.0.0', 'v1.5.0');

      expect(
        () => StratumThemeConfig.parse(
          base: sources(const []).single,
          layers: [_oceanSource(newer)],
        ),
        throwsA(
          isA<StratumThemeFormatException>().having(
            (exception) => '$exception',
            'toString',
            'StratumThemeFormatException: 1 problem(s) in theme.yaml\n'
                r'  ocean:1:10 $schema: theme needs stratum-theme v1.5; '
                'this app reads up to v1.4 [unsupported_schema]',
          ),
        ),
      );
    });

    test('errors in file order, then by position, the unpositioned last', () {
      final base = baseYaml
          .replaceFirst('name: base', 'name: 12')
          .replaceFirst('      code: inter\n', '');

      const missingCode =
          '  base typography.families.default.code: no font for type '
          '"code" [missing_default_font]';
      const badColor =
          '  layer1:5:15 color.light.brand.normal: expected "#RRGGBB" or '
          '"#RRGGBBAA", got "#1" [expected_color]';
      const badRadius =
          '  layer2:3:7 radius.sm: expected a number or "N%", got "8px" '
          '[expected_dimension]';
      expect(
        _report([
          layer('color:\n  light:\n    brand:\n      normal: "#1"\nspcae: 1'),
          layer('radius:\n  sm: "8px"'),
        ], base: base).split('\n').skip(1),
        [
          '  base:2:7 name: expected a string, got 12 [expected_string]',
          missingCode,
          badColor,
          '  layer1:6:1 spcae: unknown key "spcae" [unknown_key]',
          badRadius,
        ],
      );
    });

    test('the spec section 8.4 sample over the package default, text and '
        'order exactly', () {
      const ocean = r'''
$schema: stratum-theme/v1.0.0
name: Ocean
space:
  md: 5%
animation:
  duration:
    default: medium
    fast: -10
  reverseDuration: 64
  curve:
    enter: easeInOutSin
    exit: "cubic(1.2, 0, 0.6, 1)"
''';
      final base = StratumThemeSource(
        id: 'stratum-default',
        folder: 'packages/stratum_ui/assets/themes/default',
        yaml: File('assets/themes/default/theme.yaml').readAsStringSync(),
      );
      const header = 'StratumThemeFormatException: 6 problem(s) in theme.yaml';
      const space =
          '  ocean:4:7 space.md: expected a number, got "5%"; a percent is '
          'allowed only in layouts [expected_dimension]';
      const level =
          '  ocean:7:14 animation.duration.default: expected one of micro, '
          'veryFast, fast, normal, slow, verySlow, got "medium" '
          '[expected_duration]';
      const fast =
          '  ocean:8:11 animation.duration.fast: expected a number of '
          'milliseconds of 0 or more, got -10 [expected_duration]';
      const reverse =
          '  ocean:9:20 animation.reverseDuration: expected "N%" of 0% or '
          'more, got 64 [expected_duration]';
      const enter =
          '  ocean:11:12 animation.curve.enter: expected a Curves name or '
          '"cubic(a, b, c, d)", got "easeInOutSin" [expected_curve]';
      const exit =
          '  ocean:12:11 animation.curve.exit: expected cubic x values a and '
          'c within 0 and 1, got "cubic(1.2, 0, 0.6, 1)" [expected_curve]';

      expect(
        () =>
            StratumThemeConfig.parse(base: base, layers: [_oceanSource(ocean)]),
        throwsA(
          isA<StratumThemeFormatException>().having(
            (exception) => '$exception'.split('\n'),
            'lines',
            [header, space, level, fast, reverse, enter, exit],
          ),
        ),
      );
    });
  });

  group('StratumThemeConfig.parse layers', () {
    test('the package default, the app default, then the app theme', () {
      final config = _parse([
        layer('''
space:
  md: 12
color:
  light:
    app: { mango: "#FFAA00" }
  dark:
    app: { mango: "#AA7700" }'''),
        layer('space:\n  lg: 24\npalette:\n  brand:\n    500: "#000000"'),
      ]);

      expect(
        config.space['md'],
        const StratumByWindowSize.all(StratumDimension.fixed(12)),
      );
      expect(
        config.space['lg'],
        const StratumByWindowSize.all(StratumDimension.fixed(24)),
      );
      expect(config.color.light['brand.normal'], const Color(0xFF000000));
      expect(config.color.light['app.mango'], const Color(0xFFFFAA00));
      expect(
        config.color.highContrastDark['app.mango'],
        const Color(0xFFAA7700),
      );
    });

    test('each asset slot keeps the folder of the file that set it', () {
      final config = _parse(
        [
          layer('name: app default'),
          layer('assets:\n  loading: assets/loading.json'),
        ],
        base: baseYaml.replaceFirst(
          '  splash-screen:\n',
          '  splash-screen: images/splash.svg\n',
        ),
      );

      expect(config.assets, {
        'splash-screen': const StratumThemeAsset(
          kind: StratumAssetKind.svg,
          path: '$baseFolder/images/splash.svg',
        ),
        'loading': const StratumThemeAsset(
          kind: StratumAssetKind.lottie,
          path: 'themes/layer2/assets/loading.json',
        ),
      });
    });

    test(r'a layer that holds only $schema gives the base alone', () {
      expect(_parse([schemaLine]), _parse(const []));
    });

    test('parsing the same files twice gives equal values', () {
      final layers = [layer('extensions:\n  list: [1, { a: b }]')];

      expect(_parse(layers), _parse(layers));
      expect(_parse(layers).hashCode, _parse(layers).hashCode);
    });

    test('us07/fr01/e05: a font file keeps the folder and the id of the '
        'file that set it', () {
      final config = _parse([
        layer('''
typography:
  fonts:
    brand: { family: Brand, files: [fonts/Brand-Regular.ttf] }'''),
        layer('''
typography:
  fonts:
    brand: { adjustSize: 1 }
    night: { family: Night, files: [fonts/Night.otf] }'''),
      ]);

      expect(
        config.typography.fonts['brand'],
        const StratumFontData(
          family: 'layer1/Brand',
          adjustSize: StratumDimension.fixed(1),
          source: StratumFontSource.theme,
          files: ['themes/layer1/fonts/Brand-Regular.ttf'],
        ),
      );
      expect(
        config.typography.fonts['night'],
        const StratumFontData(
          family: 'layer2/Night',
          source: StratumFontSource.theme,
          files: ['themes/layer2/fonts/Night.otf'],
        ),
      );
    });

    test('an empty layers list parses the base alone', () {
      final config = _parse(const []);

      expect(config.name, 'base');
      expect(config.extensions, isEmpty);
      expect(config.typography.fonts.keys, ['inter']);
    });
  });
}
