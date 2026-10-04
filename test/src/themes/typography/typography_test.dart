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

    test('us07/fr01/e06: reads the five Google fonts, the default family '
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

    test('us07/fr01/e06: the package bundles no font file', () {
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

    test('us07/s1: reads the header weight and the Figma metrics of header '
        's56', () {
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
    });

    test('names table in families.default with no table entry in types', () {
      expect(
        typography.families['default']!.types[FontType.table],
        const StratumFontRef(font: 'inter'),
      );
      expect(typography.types.containsKey(FontType.table), isFalse);
    });
  });

  group('StratumTypography.fromYaml errors', () {
    test('us07/s3, us07/fr02: reports several problems together, each with '
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

    test('us07/fr02: an error carries its code, its source, and the position '
        'of its value, or of its key for an unknown key', () {
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
    });

    final cases = <(String, YamlMap, String)>[
      (
        'us07/fr02/e01: reports no fonts',
        _typography(fonts: '{}'),
        'typography.fonts: expected at least one font',
      ),
      (
        'us07/fr02/e02: reports a font without a family',
        _typography(fonts: '{ inter: { package: stratum_ui } }'),
        'typography.fonts.inter.family: required',
      ),
      (
        'us07/fr02/e03: reports a font family that is not a string',
        _typography(fonts: '{ inter: { family: 12 } }'),
        'typography.fonts.inter.family: expected a string, got 12',
      ),
      (
        'us07/fr02/e03: reports an adjustSize that is not a dimension',
        _typography(fonts: '{ inter: { family: Inter, adjustSize: 2px } }'),
        'typography.fonts.inter.adjustSize: '
            'expected a number or "N%", got "2px"',
      ),
      (
        'us07/fr02/e02: reports no default family set',
        _typography(families: '{ th: { body: inter } }'),
        'typography.families.default: required',
      ),
      (
        'us07/fr02/e05: reports a malformed locale tag',
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
        'us07/fr02/e04: reports a mono reference to an unknown font',
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
        'us07/fr02/e07: reports a weight off the 100 grid',
        _typography(
          types: {
            'header': '{ weight: 650, sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
        'typography.types.header.weight: '
            'expected 100 to 900 in steps of 100, got 650',
      ),
      (
        'us07/fr02/e02: reports a type without a weight',
        _typography(
          types: {'header': '{ sizes: { s16: { spaceHeight: 8 } } }'},
        ),
        'typography.types.header.weight: required',
      ),
      (
        'us07/fr02/e08: reports a type without sizes',
        _typography(types: {'header': '{ weight: 600 }'}),
        'typography.types.header.sizes: expected at least one size',
      ),
      (
        'us07/fr02/e02: reports a size without a spaceHeight',
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
        'us07/fr02/e02: reports a family entry with a mono but no font',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, '
              'number: { mono: inter }, code: inter, body: inter, '
              'table: inter } }',
        ),
        'typography.families.default.number.font: required',
      ),
      (
        'us07/fr02/e02: reports a missing type',
        _typography(types: {'code': null}),
        'typography.types.code: required',
      ),
      (
        'us07/s5, us07/fr02/e09: reports a types.table block',
        _typography(
          types: {
            'table': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
        "typography.types.table: table takes body's metrics; remove this "
            'block',
      ),
      (
        'us07/s6, us07/fr02/e10: reports a default family set without table',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter } }',
        ),
        'typography.families.default.table: no font for type "table"',
      ),
      (
        'us07/fr02/e06: reports two family tags that normalize to the same tag',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter, table: inter }, '
              'th-TH: { body: inter }, th_TH: { body: inter } }',
        ),
        'typography.families.th_TH: duplicate tag "th_TH"',
      ),
      (
        'us07/fr02/e02: reports a default family set with an empty value',
        _typography(families: '{ default: null, th: { body: inter } }'),
        'typography.families.default: required',
      ),
      (
        'us08/s4: a Google font with an empty name',
        _typography(fonts: '{ inter: { family: "Google/" } }'),
        'typography.fonts.inter.family: expected a font name after "Google/"',
      ),
      (
        'us08/s5: a Google font with a package',
        _typography(
          fonts: '{ inter: { family: "Google/Kanit", package: stratum_ui } }',
        ),
        'typography.fonts.inter.package: '
            'package is not allowed with a Google font',
      ),
      (
        'us08/s3: a Google font GoogleFonts.asMap() lacks',
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

  group('StratumTypography.fromYaml Google Fonts', () {
    test(
      'a "Google/<Name>" family parses with source google and the bare name',
      () {
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
      },
    );
  });

  group('us07: StratumTypography.fromYaml font files', () {
    test('us07/fr01/e05: files read into a theme font under the folder and '
        'the id of the file', () {
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
    });

    test('us07/fr01: ttf and otf pass in any case', () {
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
        'us07/fr02/e12: a .. segment',
        '{ inter: { family: Inter, files: [../Brand.woff] } }',
        'typography.fonts.inter.files: $invalid "../Brand.woff"',
      ),
      (
        'us07/fr02/e12: a .. segment with an accepted extension, apart '
            'from the extension rule',
        '{ inter: { family: Inter, files: [fonts/../../Brand.ttf] } }',
        'typography.fonts.inter.files: $invalid "fonts/../../Brand.ttf"',
      ),
      (
        'us07/fr02/e12: a leading /',
        '{ inter: { family: Inter, files: [/fonts/Brand.ttf] } }',
        'typography.fonts.inter.files: $invalid "/fonts/Brand.ttf"',
      ),
      (
        'us07/fr02/e12: another extension',
        '{ inter: { family: Inter, files: [fonts/Brand.woff2] } }',
        'typography.fonts.inter.files: $invalid "fonts/Brand.woff2"',
      ),
      (
        'us07/fr02/e12: an entry that is not a string',
        '{ inter: { family: Inter, files: [5] } }',
        'typography.fonts.inter.files: $invalid 5',
      ),
      (
        'us07/fr02/e12: a files value that is not a list',
        '{ inter: { family: Inter, files: fonts/Brand.ttf } }',
        'typography.fonts.inter.files: $invalid "fonts/Brand.ttf"',
      ),
      (
        'us07/fr02/e13: an empty files list',
        '{ inter: { family: Inter, files: [] } }',
        'typography.fonts.inter.files: expected at least one font file',
      ),
      (
        'us07/fr02/e14: files on a Google font',
        '{ inter: { family: "Google/Kanit", files: [fonts/Kanit.ttf] } }',
        'typography.fonts.inter.files: '
            'files are not allowed with a Google font',
      ),
      (
        'us07/fr02/e15: files with a package',
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

    test('us07/fr02/e14: files on a Google font with an empty or unknown '
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
    test('us07/s2: normalizes th-TH to th_TH and keeps yaml order', () {
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

    test('us07/s4, us07/fr02/e11: reports each unknown key as unknown_key, '
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
