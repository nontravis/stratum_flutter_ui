import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// A valid style for each type except `table`, which takes no `types` entry;
/// a test replaces or removes entries.
const _validTypes = <String, String?>{
  'header': '{ weight: 600, sizes: { s16: { spaceHeight: 8 } } }',
  'paragraph': '{ weight: 400, sizes: { s16: { spaceHeight: 10 } } }',
  'number': '{ weight: 600, sizes: { s16: { spaceHeight: 8 } } }',
  'code': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
  'body': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
};

const _validFamilies =
    '{ default: { header: inter, paragraph: inter, number: inter, '
    'code: inter, body: inter, table: inter } }';

/// The `typography:` node of a small valid theme, with the sections a test
/// passes swapped in. A `null` entry in [types] removes that type.
YamlMap _typography({
  String fonts = '{ inter: { family: Inter } }',
  String families = _validFamilies,
  Map<String, String?> types = const {},
  String extra = '',
}) {
  final typeLines = [
    for (final MapEntry(:key, :value) in {..._validTypes, ...types}.entries)
      if (value != null) '    $key: $value',
  ].join('\n');
  final document = loadYaml('''
typography:
  fonts: $fonts
  families: $families
  types:
$typeLines
$extra''') as YamlMap;
  return document['typography'] as YamlMap;
}

/// The errors `fromYaml` reports for [node], as `path: message` lines.
List<String> _errors(YamlMap node) {
  try {
    StratumTypography.fromYaml(node);
  } on StratumThemeFormatException catch (exception) {
    return [for (final error in exception.errors) '$error'];
  }
  return const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StratumTypography.fromYaml on the default theme', () {
    late StratumTypography typography;

    setUpAll(() async {
      final text = await rootBundle.loadString(
        'assets/themes/default/theme.yaml',
      );
      final document = loadYaml(text) as YamlMap;
      typography = StratumTypography.fromYaml(
        document['typography'] as YamlMap,
      );
    });

    test('fo02/us07/fr01/e06: reads the five Google fonts, the default family '
        'set, and Thai', () {
      expect(typography.fonts, {
        'inter': const StratumFontData(
          family: 'Inter',
          source: StratumFontSource.google,
        ),
        'geist': const StratumFontData(
          family: 'Geist',
          source: StratumFontSource.google,
        ),
        'geist-mono': const StratumFontData(
          family: 'Geist Mono',
          source: StratumFontSource.google,
        ),
        'roboto-mono': const StratumFontData(
          family: 'Roboto Mono',
          source: StratumFontSource.google,
        ),
        'kanit': const StratumFontData(
          family: 'Kanit',
          source: StratumFontSource.google,
        ),
      });
      expect(typography.families.keys, ['default', 'th']);
      expect(typography.families['th']!.types, {
        FontType.header: const StratumFontRef(font: 'kanit'),
        FontType.paragraph: const StratumFontRef(font: 'kanit'),
        FontType.body: const StratumFontRef(font: 'kanit'),
        FontType.table: const StratumFontRef(font: 'kanit'),
      });
      final defaults = typography.families['default']!;
      expect(defaults.mono, 'roboto-mono');
      expect(defaults.types, {
        FontType.header: const StratumFontRef(font: 'inter'),
        FontType.paragraph: const StratumFontRef(font: 'inter'),
        FontType.body: const StratumFontRef(font: 'inter'),
        FontType.table: const StratumFontRef(font: 'inter'),
        FontType.number: const StratumFontRef(
          font: 'geist',
          mono: 'geist-mono',
        ),
        FontType.code: const StratumFontRef(font: 'roboto-mono'),
      });
    });

    test('fo02/us07/fr01/e06: the package bundles no font file', () {
      final fontFile = RegExp(r'\.(ttf|otf)$', caseSensitive: false);

      expect(
        Directory('assets')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => fontFile.hasMatch(file.path)),
        isEmpty,
      );
    });

    test('reads the window scale', () {
      expect(
        typography.scaleByWindowSize,
        StratumByWindowSize(const {
          WindowSize.watch: StratumDimension.fixed(0),
          WindowSize.mobile: StratumDimension.fixed(0),
          WindowSize.tablet: StratumDimension.fixed(0.5),
          WindowSize.desktop: StratumDimension.fixed(1),
          WindowSize.bigDesktop: StratumDimension.fixed(2),
        }),
      );
    });

    test(
      'fo02/us07/s1: reads the header weight and the Figma metrics of header '
      's56',
      () {
        final header = typography.types[FontType.header]!;
        expect(header.weight, FontWeight.w600);
        expect(header.sizes.keys, [
          FontSize.s12,
          FontSize.s14,
          FontSize.s18,
          FontSize.s20,
          FontSize.s24,
          FontSize.s36,
          FontSize.s56,
        ]);
        expect(
          header.sizes[FontSize.s56],
          StratumSizeMetrics(
            spaceHeight: const StratumDimension.fixed(16),
            letterSpacing: StratumDimension.parse('-2.4%'),
          ),
        );
      },
    );

    test('names table in families.default with no table entry in types', () {
      expect(
        typography.families['default']!.types[FontType.table],
        const StratumFontRef(font: 'inter'),
      );
      expect(typography.types.containsKey(FontType.table), isFalse);
    });
  });

  group('StratumTypography.fromYaml errors', () {
    test('fo02/us07/s3, fo02/us07/fr02: reports several problems together, each with '
        'its yaml path', () {
      final node = _typography(
        families:
            '{ default: { header: inter, paragraph: inter, number: inter, '
            'body: inter, table: inter }, th: { body: kanit } }',
        types: {
          'body':
              '{ weight: 400, sizes: { s16: { spaceHeight: 8 }, '
              's14: { spaceHeight: 8px } } }',
          'table': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
        },
      );

      expect(
        () => StratumTypography.fromYaml(node),
        throwsA(
          isA<StratumThemeFormatException>().having(
            (exception) => '$exception',
            'toString',
            contains('typography.families.th.body: unknown font key "kanit"'),
          ),
        ),
      );
      const spaceHeight =
          'typography.types.body.sizes.s14.spaceHeight: '
          'expected a number or "N%", got "8px"';
      const tableBlock =
          "typography.types.table: table takes body's metrics; remove this "
          'block';
      expect(_errors(node), [
        'typography.families.th.body: unknown font key "kanit"',
        spaceHeight,
        tableBlock,
        'typography.families.default.code: no font for type "code"',
      ]);
    });

    test(
      'fo02/us07/fr02: an error carries its code, its source, and the position '
      'of its value, or of its key for an unknown key',
      () {
        expect(
          () => StratumTypography.fromYaml(
            _typography(fonts: '{ inter: { family: 12, weight: 400 } }'),
            source: 'ocean',
          ),
          throwsA(
            isA<StratumThemeFormatException>().having(
              (exception) => exception.errors,
              'errors',
              const [
                StratumThemeFormatError(
                  code: StratumThemeErrorCode.expectedString,
                  source: 'ocean',
                  path: 'typography.fonts.inter.family',
                  message: 'expected a string, got 12',
                  line: 2,
                  column: 29,
                ),
                StratumThemeFormatError(
                  code: StratumThemeErrorCode.unknownKey,
                  source: 'ocean',
                  path: 'typography.fonts.inter.weight',
                  message: 'unknown key "weight"',
                  line: 2,
                  column: 33,
                ),
              ],
            ),
          ),
        );
      },
    );

    final cases = <(String, YamlMap, String)>[
      (
        'fo02/us07/fr02/e01: reports no fonts',
        _typography(fonts: '{}'),
        'typography.fonts: expected at least one font',
      ),
      (
        'fo02/us07/fr02/e02: reports a font without a family',
        _typography(fonts: '{ inter: { package: stratum_ui } }'),
        'typography.fonts.inter.family: required',
      ),
      (
        'fo02/us07/fr02/e03: reports a font family that is not a string',
        _typography(fonts: '{ inter: { family: 12 } }'),
        'typography.fonts.inter.family: expected a string, got 12',
      ),
      (
        'fo02/us07/fr02/e03: reports an adjustSize that is not a dimension',
        _typography(fonts: '{ inter: { family: Inter, adjustSize: 2px } }'),
        'typography.fonts.inter.adjustSize: '
            'expected a number or "N%", got "2px"',
      ),
      (
        'fo02/us07/fr02/e02: reports no default family set',
        _typography(families: '{ th: { body: inter } }'),
        'typography.families.default: required',
      ),
      (
        'fo02/us07/fr02/e05: reports a malformed locale tag',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter, table: inter }, '
              'TH: { body: inter } }',
        ),
        'typography.families.TH: expected "default", a language such as '
            '"th", or a language and country such as "th_TH"',
      ),
      (
        'fo02/us07/fr02/e04: reports a mono reference to an unknown font',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, '
              'number: { font: inter, mono: geist-mono }, code: inter, '
              'body: inter, table: inter } }',
        ),
        'typography.families.default.number.mono: '
            'unknown font key "geist-mono"',
      ),
      (
        'fo02/us07/fr02/e07: reports a weight off the 100 grid',
        _typography(
          types: {
            'header': '{ weight: 650, sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
        'typography.types.header.weight: '
            'expected 100 to 900 in steps of 100, got 650',
      ),
      (
        'fo02/us07/fr02/e02: reports a type without a weight',
        _typography(
          types: {'header': '{ sizes: { s16: { spaceHeight: 8 } } }'},
        ),
        'typography.types.header.weight: required',
      ),
      (
        'fo02/us07/fr02/e08: reports a type without sizes',
        _typography(types: {'header': '{ weight: 600 }'}),
        'typography.types.header.sizes: expected at least one size',
      ),
      (
        'fo02/us07/fr02/e02: reports a size without a spaceHeight',
        _typography(
          types: {
            'header':
                '{ weight: 600, sizes: { s16: { spaceHeight: 8 }, '
                's14: { letterSpacing: 1 } } }',
          },
        ),
        'typography.types.header.sizes.s14.spaceHeight: required',
      ),
      (
        'fo02/us07/fr02/e02: reports a family entry with a mono but no font',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, '
              'number: { mono: inter }, code: inter, body: inter, '
              'table: inter } }',
        ),
        'typography.families.default.number.font: required',
      ),
      (
        'fo02/us07/fr02/e02: reports a missing type',
        _typography(types: {'code': null}),
        'typography.types.code: required',
      ),
      (
        'fo02/us07/s5, fo02/us07/fr02/e09: reports a types.table block',
        _typography(
          types: {
            'table': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
        "typography.types.table: table takes body's metrics; remove this "
            'block',
      ),
      (
        'fo02/us07/s6, fo02/us07/fr02/e10: reports a default family set without table',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter } }',
        ),
        'typography.families.default.table: no font for type "table"',
      ),
      (
        'fo02/us07/fr02/e06: reports two family tags that normalize to the same tag',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter, table: inter }, '
              'th-TH: { body: inter }, th_TH: { body: inter } }',
        ),
        'typography.families.th_TH: duplicate tag "th_TH"',
      ),
      (
        'fo02/us07/fr02/e02: reports a default family set with an empty value',
        _typography(families: '{ default: null, th: { body: inter } }'),
        'typography.families.default: required',
      ),
      (
        'fo02/us08/s4: a Google font with an empty name',
        _typography(fonts: '{ inter: { family: "Google/" } }'),
        'typography.fonts.inter.family: expected a font name after "Google/"',
      ),
      (
        'fo02/us08/s5: a Google font with a package',
        _typography(
          fonts: '{ inter: { family: "Google/Kanit", package: stratum_ui } }',
        ),
        'typography.fonts.inter.package: '
            'package is not allowed with a Google font',
      ),
      (
        'fo02/us08/s3: a Google font GoogleFonts.asMap() lacks',
        _typography(
          fonts: '{ inter: { family: "Google/Not A Real Font 12345" } }',
        ),
        'typography.fonts.inter.family: '
            'unknown Google Fonts family "Not A Real Font 12345"',
      ),
    ];
    for (final (name, node, error) in cases) {
      test(name, () {
        expect(_errors(node), [error]);
      });
    }
  });

  group('StratumTypography.fromYaml length bound', () {
    const bound = 'expected a number or "N%" from -10000 to 10000, got';
    final cases = <(String, YamlMap, String)>[
      (
        'an adjustSize past the bound',
        _typography(fonts: '{ inter: { family: Inter, adjustSize: 20000 } }'),
        'typography.fonts.inter.adjustSize: $bound 20000',
      ),
      (
        'an adjustSize percent below the bound',
        _typography(
          fonts: '{ inter: { family: Inter, adjustSize: "-20000%" } }',
        ),
        'typography.fonts.inter.adjustSize: $bound "-20000%"',
      ),
      (
        'an infinite theme-wide scaleByWindowSize entry',
        _typography(extra: '  scaleByWindowSize: { desktop: .inf }'),
        'typography.scaleByWindowSize.desktop: $bound Infinity',
      ),
      (
        'a negative-infinite theme-wide scaleByWindowSize entry',
        _typography(extra: '  scaleByWindowSize: { desktop: -.inf }'),
        'typography.scaleByWindowSize.desktop: $bound -Infinity',
      ),
      (
        "a NaN entry of a type's own scaleByWindowSize",
        _typography(
          types: {
            'header':
                '{ weight: 600, sizes: { s16: { spaceHeight: 8 } }, '
                'scaleByWindowSize: { mobile: .nan } }',
          },
        ),
        'typography.types.header.scaleByWindowSize.mobile: $bound NaN',
      ),
      (
        'a spaceHeight below the bound',
        _typography(
          types: {
            'body':
                '{ weight: 400, sizes: { s16: { spaceHeight: 8 }, '
                's14: { spaceHeight: -10001 } } }',
          },
        ),
        'typography.types.body.sizes.s14.spaceHeight: $bound -10001',
      ),
      (
        'a letterSpacing percent past the bound',
        _typography(
          types: {
            'body':
                '{ weight: 400, sizes: { s16: { spaceHeight: 8, '
                'letterSpacing: "10001%" } } }',
          },
        ),
        'typography.types.body.sizes.s16.letterSpacing: $bound "10001%"',
      ),
    ];
    for (final (name, node, error) in cases) {
      test('fo02/us07/fr02/e16: reports $name', () {
        expect(_errors(node), [error]);
      });
    }

    test('fo02/us07/fr01: the four lengths read a number or a percent at the '
        'bound, negatives included', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          fonts: '{ inter: { family: Inter, adjustSize: "10000%" } }',
          types: {
            'body':
                '{ weight: 400, sizes: { s16: { spaceHeight: "10000%", '
                'letterSpacing: -10000 } }, '
                'scaleByWindowSize: { mobile: 10000 } }',
          },
          extra: '  scaleByWindowSize: { desktop: "-50%" }',
        ),
      );

      expect(
        typography.fonts['inter']!.adjustSize,
        const StratumDimension.percent(100),
      );
      final body = typography.types[FontType.body]!;
      expect(
        body.sizes[FontSize.s16],
        const StratumSizeMetrics(
          spaceHeight: StratumDimension.percent(100),
          letterSpacing: StratumDimension.fixed(-10000),
        ),
      );
      expect(body.scaleByWindowSize, {
        WindowSize.mobile: const StratumDimension.fixed(10000),
      });
      expect(
        typography.scaleByWindowSize!.valueFor(WindowSize.desktop),
        const StratumDimension.percent(-0.5),
      );
    });
  });

  group('StratumTypography.fromYaml draw size', () {
    test('fo02/us07/fr02/e17, fo02/us07/fr02/e19: an adjustSize that draws s10 and s12 '
        'at 0 px or less is one error, named by s10', () {
      const expected =
          'typography.fonts.inter.adjustSize: expected an adjustSize that '
          'keeps s10 above 0 px, got -12 (s10 draws at -2 px)';
      expect(
        _errors(
          _typography(fonts: '{ inter: { family: Inter, adjustSize: -12 } }'),
        ),
        [expected],
      );
    });

    test(
      'fo02/us07/fr02/e17: a percent adjustSize of "-100%" draws every size at '
      '0 px',
      () {
        const expected =
            'typography.fonts.inter.adjustSize: expected an adjustSize that '
            'keeps s10 above 0 px, got "-100%" (s10 draws at 0 px)';
        expect(
          _errors(
            _typography(
              fonts: '{ inter: { family: Inter, adjustSize: "-100%" } }',
            ),
          ),
          [expected],
        );
      },
    );

    test('fo02/us07/fr02/e17, fo02/us07/fr02/e19: a theme-wide window scale entry is '
        'blamed once, at the entry every larger window size reads, named by '
        'its smallest window size', () {
      const expected =
          'typography.scaleByWindowSize.watch: expected a scaleByWindowSize '
          'that keeps s10 above 0 px, got -14 (s10 draws at -4 px)';
      expect(
        _errors(_typography(extra: '  scaleByWindowSize: { watch: -14 }')),
        [expected],
      );
    });

    test("fo02/us07/fr02/e17: a type's own window scale entry is blamed at the "
        "type's path", () {
      const expected =
          'typography.types.header.scaleByWindowSize.desktop: expected a '
          'scaleByWindowSize that keeps s10 above 0 px, got -11 (s10 '
          'draws at -1 px)';
      expect(
        _errors(
          _typography(
            types: {
              'header':
                  '{ weight: 600, sizes: { s16: { spaceHeight: 8 } }, '
                  'scaleByWindowSize: { desktop: -11 } }',
            },
          ),
        ),
        [expected],
      );
    });

    test('fo02/us07/fr02/e19: a refused own scaleByWindowSize entry blames no '
        'theme-wide entry it would fall through to', () {
      const expected =
          'typography.types.header.scaleByWindowSize.watch: expected a '
          'number or "N%" from -10000 to 10000, got 20000';
      expect(
        _errors(
          _typography(
            fonts:
                '{ small: { family: Small }, '
                'big: { family: Big, adjustSize: 10 } }',
            families:
                '{ default: { header: small, paragraph: big, number: big, '
                'code: big, body: big, table: big } }',
            types: {
              'header':
                  '{ weight: 600, sizes: { s16: { spaceHeight: 8 } }, '
                  'scaleByWindowSize: { watch: 20000 } }',
            },
            extra:
                '  scaleByWindowSize: { watch: -14, mobile: 0, tablet: 0, '
                'desktop: 0, bigDesktop: 0 }',
          ),
        ),
        [expected],
      );
    });

    test('fo02/us04/fr02: a refused own entry at a smaller window size '
        'shadows a larger window that falls back to it too', () {
      const expected =
          'typography.types.header.scaleByWindowSize.mobile: expected a '
          'number or "N%" from -10000 to 10000, got 20000';
      expect(
        _errors(
          _typography(
            types: {
              'header':
                  '{ weight: 600, sizes: { s16: { spaceHeight: 8 } }, '
                  'scaleByWindowSize: { mobile: 20000 } }',
            },
          ),
        ),
        [expected],
      );
    });

    test('fo02/us07/fr02/e19: an own scaleByWindowSize refused as a whole '
        'blames no theme-wide entry it would fall through to', () {
      const expected =
          'typography.types.header.scaleByWindowSize: expected a map, '
          'got 5';
      expect(
        _errors(
          _typography(
            fonts:
                '{ inter: { family: Inter }, '
                'big: { family: Big, adjustSize: -6 } }',
            families:
                '{ default: { header: big, paragraph: inter, number: inter, '
                'code: inter, body: inter, table: inter } }',
            types: {
              'header':
                  '{ weight: 600, sizes: { s16: { spaceHeight: 8 } }, '
                  'scaleByWindowSize: 5 }',
            },
            extra: '  scaleByWindowSize: { watch: -5 }',
          ),
        ),
        [expected],
      );
    });

    test(
      'fo02/us07/fr02/e18, fo02/us07/fr02/e19: a spaceHeight is blamed at the '
      'defined size whose metrics fail, once for body and table',
      () {
        const expected =
            'typography.types.body.sizes.s10.spaceHeight: expected a '
            'spaceHeight that keeps s10 above 0 px, got -12 (line box -2 '
            'px)';
        expect(
          _errors(
            _typography(
              types: {
                'body':
                    '{ weight: 400, sizes: { s16: { spaceHeight: 8 }, '
                    's10: { spaceHeight: -12 } } }',
              },
            ),
          ),
          [expected],
        );
      },
    );

    test('fo02/us07/fr02/e18: a size the type lacks is checked against the '
        'nearest defined size', () {
      const expected =
          'typography.types.body.sizes.s14.spaceHeight: expected a '
          'spaceHeight that keeps s10 above 0 px, got -11 (line box -1 '
          'px)';
      expect(
        _errors(
          _typography(
            types: {
              'body': '{ weight: 400, sizes: { s14: { spaceHeight: -11 } } }',
            },
          ),
        ),
        [expected],
      );
    });

    test('fo02/us07/fr02/e19: a spaceHeight the length bound refuses blames no '
        'other declared size that falls back to it', () {
      const expected =
          'typography.types.body.sizes.s10.spaceHeight: expected a number '
          'or "N%" from -10000 to 10000, got 99999';
      expect(
        _errors(
          _typography(
            types: {
              'body':
                  '{ weight: 400, sizes: { s10: { spaceHeight: 99999 }, '
                  's16: { spaceHeight: -12 } } }',
            },
          ),
        ),
        [expected],
      );
    });

    test('fo02/us07/fr02/e17, fo02/us07/fr02/e19: a refused nearest size blames no '
        'line box, but still checks the font size at that size', () {
      const e16 =
          'typography.types.body.sizes.s10.spaceHeight: expected a number '
          'or "N%" from -10000 to 10000, got 99999';
      const e17 =
          'typography.fonts.tiny.adjustSize: expected an adjustSize that '
          'keeps s10 above 0 px, got -11 (s10 draws at -1 px)';
      expect(
        _errors(
          _typography(
            fonts:
                '{ inter: { family: Inter }, '
                'tiny: { family: Tiny, adjustSize: -11 } }',
            families:
                '{ default: { header: inter, paragraph: inter, '
                'number: inter, code: inter, body: tiny, table: inter } }',
            types: {
              'body':
                  '{ weight: 400, sizes: { s10: { spaceHeight: 99999 }, '
                  's16: { spaceHeight: 8 } } }',
            },
          ),
        ),
        [e17, e16],
      );
    });

    test('fo02/us07/fr02/e19: two scale entries failing independently report '
        'two errors in one load', () {
      const watch =
          'typography.scaleByWindowSize.watch: expected a scaleByWindowSize '
          'that keeps s10 above 0 px, got -14 (s10 draws at -4 px)';
      const bigDesktop =
          'typography.scaleByWindowSize.bigDesktop: expected a '
          'scaleByWindowSize that keeps s10 above 0 px, got -50 (s10 draws '
          'at -40 px)';
      expect(
        _errors(
          _typography(
            extra: '  scaleByWindowSize: { watch: -14, bigDesktop: -50 }',
          ),
        ),
        [watch, bigDesktop],
      );
    });

    test('fo02/us07/fr02/e17: a theme-wide mono font is checked for every type '
        'but code, and a code mono is not checked', () {
      const expected =
          'typography.fonts.tiny.adjustSize: expected an adjustSize that '
          'keeps s10 above 0 px, got -11 (s10 draws at -1 px)';
      expect(
        _errors(
          _typography(
            fonts:
                '{ inter: { family: Inter }, '
                'tiny: { family: Tiny, adjustSize: -11 } }',
            families:
                '{ default: { header: inter, paragraph: inter, '
                'number: inter, code: { font: inter, mono: tiny }, '
                'body: inter, table: inter, mono: tiny } }',
          ),
        ),
        [expected],
      );
      expect(
        _errors(
          _typography(
            fonts:
                '{ inter: { family: Inter }, '
                'tiny: { family: Tiny, adjustSize: -11 } }',
            families:
                '{ default: { header: inter, paragraph: inter, '
                'number: inter, code: { font: inter, mono: tiny }, '
                'body: inter, table: inter } }',
          ),
        ),
        isEmpty,
      );
    });

    test('fo02/us07/fr02/e19: at one size and window size, the first type in '
        'FontType order, then the first font in tag order, names the '
        'message', () {
      const firstType =
          'typography.scaleByWindowSize.watch: expected a scaleByWindowSize '
          'that keeps s10 above 0 px, got -13 (s10 draws at -1 px)';
      expect(
        _errors(
          _typography(
            fonts:
                '{ inter: { family: Inter }, '
                'big: { family: Big, adjustSize: 2 } }',
            families:
                '{ default: { header: big, paragraph: inter, number: inter, '
                'code: inter, body: inter, table: inter }, '
                'th: { paragraph: big } }',
            extra: '  scaleByWindowSize: { watch: -13 }',
          ),
        ),
        [firstType],
      );
      const firstFont =
          'typography.scaleByWindowSize.watch: expected a scaleByWindowSize '
          'that keeps s10 above 0 px, got -13 (s10 draws at -3 px)';
      expect(
        _errors(
          _typography(
            fonts:
                '{ inter: { family: Inter }, '
                'big: { family: Big, adjustSize: 2 } }',
            families:
                '{ default: { header: inter, paragraph: inter, '
                'number: inter, code: inter, body: inter, table: inter }, '
                'th: { header: big } }',
            extra: '  scaleByWindowSize: { watch: -13 }',
          ),
        ),
        [firstFont],
      );
    });

    test('fo02/us07/fr02/e19: a value the length bound refuses draws no second '
        'error at its path', () {
      const expected =
          'typography.fonts.inter.adjustSize: expected a number or "N%" '
          'from -10000 to 10000, got -20000';
      expect(
        _errors(
          _typography(
            fonts: '{ inter: { family: Inter, adjustSize: -20000 } }',
          ),
        ),
        [expected],
      );
    });

    test(
      'fo02/us07/fr02/e19, review focus 2: a font, a type, or a size that did '
      'not parse is left out of the check, with no crash and no second '
      'error',
      () {
        const weight =
            'typography.types.header.weight: expected 100 to 900 in steps of '
            '100, got 650';
        const spaceHeight =
            'typography.types.paragraph.sizes.s10.spaceHeight: expected a '
            'number or "N%", got "x"';

        expect(
          _errors(
            _typography(
              fonts: '{ inter: { family: Inter }, tiny: { adjustSize: -12 } }',
              families:
                  '{ default: { header: inter, paragraph: inter, '
                  'number: inter, code: inter, body: tiny, table: inter } }',
              types: {
                'header':
                    '{ weight: 650, sizes: { s16: { spaceHeight: -20 } } }',
                'paragraph':
                    '{ weight: 400, sizes: { s10: { spaceHeight: x } } }',
              },
            ),
          ),
          [
            weight,
            'typography.types.paragraph.sizes: expected at least one size',
            spaceHeight,
            'typography.fonts.tiny.family: required',
          ],
        );
      },
    );

    test(
      'fo02/us07/fr02/e17, review focus 5: a fractional size shows rounded to '
      'two decimals',
      () {
        const expected =
            'typography.fonts.inter.adjustSize: expected an adjustSize that '
            'keeps s10 above 0 px, got "-104.5%" (s10 draws at -0.45 px)';

        expect(
          _errors(
            _typography(
              fonts: '{ inter: { family: Inter, adjustSize: "-104.5%" } }',
            ),
          ),
          [expected],
        );
      },
    );

    test('s03/inv14: the package default theme passes', () {
      final node = loadYaml(
        File('assets/themes/default/theme.yaml').readAsStringSync(),
      ) as YamlMap;

      expect(_errors(node['typography'] as YamlMap), isEmpty);
    });

    test('fo02/us04/fr02: the draw-size check reads the either-map fill, so '
        'a theme-wide entry no text reads draws no error', () {
      const ownMobile = 'scaleByWindowSize: { mobile: 0 }';
      expect(
        _errors(
          _typography(
            types: {
              'header':
                  '{ weight: 600, sizes: { s16: { spaceHeight: 8 } }, '
                  '$ownMobile }',
              'paragraph':
                  '{ weight: 400, sizes: { s16: { spaceHeight: 10 } }, '
                  '$ownMobile }',
              'number':
                  '{ weight: 600, sizes: { s16: { spaceHeight: 8 } }, '
                  '$ownMobile }',
              'code':
                  '{ weight: 400, sizes: { s16: { spaceHeight: 8 } }, '
                  '$ownMobile }',
              'body':
                  '{ weight: 400, sizes: { s16: { spaceHeight: 8 } }, '
                  '$ownMobile }',
            },
            extra: '  scaleByWindowSize: { mobile: -14 }',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('StratumTypography.fromYaml Google Fonts', () {
    test('fo02/us08/fr01: a "Google/<Name>" family parses with source google '
        'and the bare name', () {
      final typography = StratumTypography.fromYaml(
        _typography(fonts: '{ inter: { family: "Google/Kanit" } }'),
      );

      expect(
        typography.fonts['inter'],
        const StratumFontData(
          family: 'Kanit',
          source: StratumFontSource.google,
        ),
      );
    });
  });

  group('us07: StratumTypography.fromYaml font files', () {
    test(
      'fo02/us07/fr01/e05: files read into a theme font under the folder and '
      'the id of the file',
      () {
        final typography = StratumTypography.fromYaml(
          _typography(
            fonts:
                '{ inter: { family: Inter }, brand: { family: Brand, '
                'files: [fonts/Brand-Regular.ttf, fonts/Brand-Bold.OTF] } }',
          ),
          source: 'brand',
          folder: 'assets/themes/brand/',
        );

        expect(
          typography.fonts['brand'],
          const StratumFontData(
            family: 'brand/Brand',
            source: StratumFontSource.theme,
            files: [
              'assets/themes/brand/fonts/Brand-Regular.ttf',
              'assets/themes/brand/fonts/Brand-Bold.OTF',
            ],
          ),
        );
        expect(
          () => typography.fonts['brand']!.files.add('fonts/More.ttf'),
          throwsUnsupportedError,
        );
      },
    );

    test('fo02/us07/fr01: ttf and otf pass in any case', () {
      expect(
        _errors(
          _typography(
            fonts:
                '{ inter: { family: Inter, '
                'files: [fonts/A.TTF, fonts/B.Otf, fonts/C.ttf] } }',
          ),
        ),
        isEmpty,
      );
    });

    const invalid =
        'expected a path inside the theme folder ending in .ttf or .otf, got';
    final cases = <(String, String, String)>[
      (
        'fo02/us07/fr02/e12: a .. segment',
        '{ inter: { family: Inter, files: [../Brand.woff] } }',
        'typography.fonts.inter.files: $invalid "../Brand.woff"',
      ),
      (
        'fo02/us07/fr02/e12: a .. segment with an accepted extension, apart '
            'from the extension rule',
        '{ inter: { family: Inter, files: [fonts/../../Brand.ttf] } }',
        'typography.fonts.inter.files: $invalid "fonts/../../Brand.ttf"',
      ),
      (
        'fo02/us07/fr02/e12: a leading /',
        '{ inter: { family: Inter, files: [/fonts/Brand.ttf] } }',
        'typography.fonts.inter.files: $invalid "/fonts/Brand.ttf"',
      ),
      (
        'fo02/us07/fr02/e12: another extension',
        '{ inter: { family: Inter, files: [fonts/Brand.woff2] } }',
        'typography.fonts.inter.files: $invalid "fonts/Brand.woff2"',
      ),
      (
        'fo02/us07/fr02/e12: an entry that is not a string',
        '{ inter: { family: Inter, files: [5] } }',
        'typography.fonts.inter.files: $invalid 5',
      ),
      (
        'fo02/us07/fr02/e12: a files value that is not a list',
        '{ inter: { family: Inter, files: fonts/Brand.ttf } }',
        'typography.fonts.inter.files: $invalid "fonts/Brand.ttf"',
      ),
      (
        'fo02/us07/fr02/e13: an empty files list',
        '{ inter: { family: Inter, files: [] } }',
        'typography.fonts.inter.files: expected at least one font file',
      ),
      (
        'fo02/us07/fr02/e14: files on a Google font',
        '{ inter: { family: "Google/Kanit", files: [fonts/Kanit.ttf] } }',
        'typography.fonts.inter.files: '
            'files are not allowed with a Google font',
      ),
      (
        'fo02/us07/fr02/e15: files with a package',
        '{ inter: { family: Inter, package: brand_fonts, '
            'files: [fonts/Inter.ttf] } }',
        'typography.fonts.inter.package: package is not allowed with files',
      ),
    ];
    for (final (name, fonts, error) in cases) {
      test('reports $name', () {
        expect(_errors(_typography(fonts: fonts)), [error]);
      });
    }

    test('fo02/us07/fr02/e14: files on a Google font with an empty or unknown '
        'name reports that error and google_font_files, not one alone', () {
      const filesError =
          'typography.fonts.inter.files: files are not allowed with a '
          'Google font';
      const unknownError =
          'typography.fonts.inter.family: unknown Google Fonts family '
          '"Nope"';
      const emptyError =
          'typography.fonts.inter.family: expected a font name after '
          '"Google/"';
      expect(
        _errors(
          _typography(
            fonts: '{ inter: { family: "Google/Nope", files: [fonts/A.ttf] } }',
          ),
        ),
        const [unknownError, filesError],
      );
      expect(
        _errors(
          _typography(
            fonts: '{ inter: { family: "Google/", files: [fonts/A.ttf] } }',
          ),
        ),
        const [emptyError, filesError],
      );
    });
  });

  group('StratumTypography.fromYaml table', () {
    test('parses with table named only in families.default, not types', () {
      expect(_errors(_typography()), isEmpty);
      final typography = StratumTypography.fromYaml(_typography());

      expect(typography.types.containsKey(FontType.table), isFalse);
      expect(
        typography.families['default']!.types[FontType.table],
        const StratumFontRef(font: 'inter'),
      );
    });

    test('a tag without table falls through the chain to default.table', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter, table: inter }, '
              'th: { body: inter } }',
        ),
      );

      expect(
        typography.families['th']!.types.containsKey(FontType.table),
        isFalse,
      );
      expect(
        typography.families['default']!.types[FontType.table],
        const StratumFontRef(font: 'inter'),
      );
    });
  });

  group('StratumTypography.fromYaml tags and keys', () {
    test('fo02/us07/s2: normalizes th-TH to th_TH and keeps yaml order', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          families:
              '{ th-TH: { body: inter }, default: { header: inter, '
              'paragraph: inter, number: inter, code: inter, body: inter, '
              'table: inter }, th: { body: inter } }',
        ),
      );

      expect(typography.families.keys, ['th_TH', 'default', 'th']);
    });

    test('fo02/us07/s4, fo02/us07/fr02/e11: reports each unknown key as unknown_key, '
        'by position', () {
      final node = _typography(
        fonts: '{ inter: { family: Inter, weight: 400 } }',
        types: {
          'header':
              '{ weight: 600, sizes: { s16: { spaceHeight: 8 }, '
              's15: { spaceHeight: 8 } } }',
        },
        extra: '  colors: {}',
      );

      expect(_errors(node), [
        'typography.fonts.inter.weight: unknown key "weight"',
        'typography.types.header.sizes.s15: unknown key "s15"',
        'typography.colors: unknown key "colors"',
      ]);
    });

    test('parsing the same yaml twice gives equal values', () {
      final a = StratumTypography.fromYaml(_typography());
      final b = StratumTypography.fromYaml(_typography());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('every map the parser builds rejects mutation', () {
      final typography = StratumTypography.fromYaml(_typography());

      expect(
        () =>
            typography.fonts['extra'] = const StratumFontData(family: 'Extra'),
        throwsUnsupportedError,
      );
      expect(
        () => typography.families['extra'] = const StratumFamilySet(types: {}),
        throwsUnsupportedError,
      );
      expect(
        () => typography.families['default']!.types[FontType.body] =
            const StratumFontRef(font: 'inter'),
        throwsUnsupportedError,
      );
      expect(
        () => typography.types[FontType.body]!.sizes[FontSize.s10] =
            const StratumSizeMetrics(spaceHeight: StratumDimension.fixed(1)),
        throwsUnsupportedError,
      );
    });
  });
}
