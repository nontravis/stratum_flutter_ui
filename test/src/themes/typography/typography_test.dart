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

    test('reads the four fonts and the default family set', () {
      expect(typography.fonts, {
        'inter': const StratumFontData(family: 'Inter'),
        'geist': const StratumFontData(family: 'Geist'),
        'geist-mono': const StratumFontData(family: 'Geist Mono'),
        'roboto-mono': const StratumFontData(family: 'Roboto Mono'),
      });
      expect(typography.families.keys, ['default']);
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

    test('reads the header weight and the Figma metrics of header s56', () {
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
    test('reports several problems together, each with its yaml path', () {
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

    test('an error carries its code, its source, and the position of its '
        'value, or of its key for an unknown key', () {
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
        'no fonts',
        _typography(fonts: '{}'),
        'typography.fonts: expected at least one font',
      ),
      (
        'a font without a family',
        _typography(fonts: '{ inter: { package: stratum_ui } }'),
        'typography.fonts.inter.family: required',
      ),
      (
        'a font family that is not a string',
        _typography(fonts: '{ inter: { family: 12 } }'),
        'typography.fonts.inter.family: expected a string, got 12',
      ),
      (
        'an adjustSize that is not a dimension',
        _typography(fonts: '{ inter: { family: Inter, adjustSize: 2px } }'),
        'typography.fonts.inter.adjustSize: '
            'expected a number or "N%", got "2px"',
      ),
      (
        'no default family set',
        _typography(families: '{ th: { body: inter } }'),
        'typography.families.default: required',
      ),
      (
        'a malformed locale tag',
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
        'a mono reference to an unknown font',
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
        'a weight off the 100 grid',
        _typography(
          types: {
            'header': '{ weight: 650, sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
        'typography.types.header.weight: '
            'expected 100 to 900 in steps of 100, got 650',
      ),
      (
        'a type without a weight',
        _typography(
          types: {'header': '{ sizes: { s16: { spaceHeight: 8 } } }'},
        ),
        'typography.types.header.weight: required',
      ),
      (
        'a type without sizes',
        _typography(types: {'header': '{ weight: 600 }'}),
        'typography.types.header.sizes: expected at least one size',
      ),
      (
        'a size without a spaceHeight',
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
        'a family entry with a mono but no font',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, '
              'number: { mono: inter }, code: inter, body: inter, '
              'table: inter } }',
        ),
        'typography.families.default.number.font: required',
      ),
      (
        'a missing type',
        _typography(types: {'code': null}),
        'typography.types.code: required',
      ),
      (
        'a types.table block',
        _typography(
          types: {
            'table': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
        "typography.types.table: table takes body's metrics; remove this "
            'block',
      ),
      (
        'a default family set without table',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter } }',
        ),
        'typography.families.default.table: no font for type "table"',
      ),
      (
        'two family tags that normalize to the same tag',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter, table: inter }, '
              'th-TH: { body: inter }, th_TH: { body: inter } }',
        ),
        'typography.families.th_TH: duplicate tag "th_TH"',
      ),
      (
        'a default family set with an empty value',
        _typography(families: '{ default: null, th: { body: inter } }'),
        'typography.families.default: required',
      ),
      (
        'a Google font with an empty name',
        _typography(fonts: '{ inter: { family: "Google/" } }'),
        'typography.fonts.inter.family: expected a font name after "Google/"',
      ),
      (
        'a Google font with a package',
        _typography(
          fonts: '{ inter: { family: "Google/Kanit", package: stratum_ui } }',
        ),
        'typography.fonts.inter.package: '
            'package is not allowed with a Google font',
      ),
      (
        'a Google font GoogleFonts.asMap() lacks',
        _typography(
          fonts: '{ inter: { family: "Google/Not A Real Font 12345" } }',
        ),
        'typography.fonts.inter.family: '
            'unknown Google Fonts family "Not A Real Font 12345"',
      ),
    ];
    for (final (name, node, error) in cases) {
      test('reports $name', () {
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
    test('normalizes th-TH to th_TH and keeps yaml order', () {
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

    test('reports each unknown key as unknown_key, by position', () {
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
