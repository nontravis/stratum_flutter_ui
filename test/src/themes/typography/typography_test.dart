import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// A valid style for each type; a test replaces or removes entries.
const _validTypes = <String, String?>{
  'header': '{ weight: 600, sizes: { s16: { spaceHeight: 8 } } }',
  'paragraph': '{ weight: 400, sizes: { s16: { spaceHeight: 10 } } }',
  'number': '{ weight: 600, sizes: { s16: { spaceHeight: 8 } } }',
  'code': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
  'body': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
  'table': '{ extends: body, tabular: true }',
};

const _validFamilies =
    '{ default: { header: inter, paragraph: inter, number: inter, '
    'code: inter, body: inter } }';

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
        FontType.number: const StratumFontRef(
          font: 'geist',
          mono: 'geist-mono',
        ),
        FontType.code: const StratumFontRef(font: 'roboto-mono'),
      });
    });

    test('reads the window scale', () {
      expect(typography.scaleByWindowSize, {
        WindowSize.watch: const StratumDimension.fixed(0),
        WindowSize.mobile: const StratumDimension.fixed(0),
        WindowSize.tablet: const StratumDimension.fixed(0.5),
        WindowSize.desktop: const StratumDimension.fixed(1),
        WindowSize.bigDesktop: const StratumDimension.fixed(2),
      });
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

    test('gives table the body weight and sizes with tabular figures', () {
      final body = typography.types[FontType.body]!;
      final table = typography.types[FontType.table]!;
      expect(table.weight, body.weight);
      expect(table.sizes, body.sizes);
      expect(table.tabular, isTrue);
      expect(table.extendsType, FontType.body);
      expect(body.tabular, isFalse);
    });
  });

  group('StratumTypography.fromYaml errors', () {
    test('reports several problems together, each with its yaml path', () {
      final node = _typography(
        families:
            '{ default: { header: inter, paragraph: inter, number: inter, '
            'body: inter }, th: { body: kanit } }',
        types: {
          'body':
              '{ extends: table, weight: 400, '
              'sizes: { s16: { spaceHeight: 8px } } }',
          'table': '{ extends: body, tabular: true }',
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
          'typography.types.body.sizes.s16.spaceHeight: '
          'expected a number or "N%", got "8px"';
      expect(_errors(node), [
        'typography.families.th.body: unknown font key "kanit"',
        spaceHeight,
        'typography.types.body.extends: cycle body -> table -> body',
        'typography.types.table.extends: cycle table -> body -> table',
        'typography.families.default.code: no font for type "code"',
      ]);
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
              'code: inter, body: inter }, TH: { body: inter } }',
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
              'body: inter } }',
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
        'a tabular flag that is not a bool',
        _typography(types: {'table': '{ extends: body, tabular: yes please }'}),
        'typography.types.table.tabular: '
            'expected true or false, got "yes please"',
      ),
      (
        'a family entry with a mono but no font',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, '
              'number: { mono: inter }, code: inter, body: inter } }',
        ),
        'typography.families.default.number.font: required',
      ),
      (
        'a type that extends itself',
        _typography(types: {'table': '{ extends: table }'}),
        'typography.types.table.extends: cycle table -> table',
      ),
      (
        'an extends that names no type',
        _typography(types: {'table': '{ extends: tabel }'}),
        'typography.types.table.extends: unknown type "tabel"',
      ),
      (
        'a missing type',
        _typography(types: {'code': null}),
        'typography.types.code: required',
      ),
    ];
    for (final (name, node, error) in cases) {
      test('reports $name', () {
        expect(_errors(node), [error]);
      });
    }
  });

  group('StratumTypography.fromYaml extends', () {
    test('merges sizes down a chain and keeps the direct parent', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          types: {
            'body':
                '{ extends: paragraph, sizes: { s14: { spaceHeight: 6 } } }',
            'table':
                '{ extends: body, tabular: true, '
                'sizes: { s14: { spaceHeight: 2 } } }',
          },
        ),
      );

      final table = typography.types[FontType.table]!;
      expect(table.extendsType, FontType.body);
      expect(table.weight, FontWeight.w400);
      expect(table.tabular, isTrue);
      expect(table.sizes, {
        FontSize.s14: const StratumSizeMetrics(
          spaceHeight: StratumDimension.fixed(2),
        ),
        FontSize.s16: const StratumSizeMetrics(
          spaceHeight: StratumDimension.fixed(10),
        ),
      });
    });

    test('lets the default family cover a type through its parent', () {
      expect(_errors(_typography()), isEmpty);
      expect(
        StratumTypography.fromYaml(_typography()).families['default']!.types
            .containsKey(FontType.table),
        isFalse,
      );
    });

    test('lets a type override the window scale of its parent', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          types: {
            'body':
                '{ weight: 400, scaleByWindowSize: { desktop: "10%" }, '
                'sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
      );

      expect(typography.types[FontType.body]!.scaleByWindowSize, {
        WindowSize.desktop: const StratumDimension.percent(0.1),
      });
      expect(
        typography.types[FontType.table]!.scaleByWindowSize,
        typography.types[FontType.body]!.scaleByWindowSize,
      );
      expect(typography.types[FontType.header]!.scaleByWindowSize, isNull);
    });
  });

  group('StratumTypography.fromYaml tags and keys', () {
    test('normalizes th-TH to th_TH and keeps yaml order', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          families:
              '{ th-TH: { body: inter }, default: { header: inter, '
              'paragraph: inter, number: inter, code: inter, body: inter }, '
              'th: { body: inter } }',
        ),
      );

      expect(typography.families.keys, ['th_TH', 'default', 'th']);
    });

    test('warns once per unknown key and skips it', () {
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      final typography = StratumTypography.fromYaml(
        _typography(
          fonts: '{ inter: { family: Inter, weight: 400 } }',
          types: {
            'header':
                '{ weight: 600, sizes: { s16: { spaceHeight: 8 }, '
                's15: { spaceHeight: 8 } } }',
          },
          extra: '  colors: {}',
        ),
      );

      expect(typography.types[FontType.header]!.sizes.keys, [FontSize.s16]);
      expect(warnings, [
        'Stratum theme: skipped unknown key typography.colors',
        'Stratum theme: skipped unknown key typography.fonts.inter.weight',
        'Stratum theme: skipped unknown key typography.types.header.sizes.s15',
      ]);
    });

    test('parsing the same yaml twice gives equal values', () {
      final a = StratumTypography.fromYaml(_typography());
      final b = StratumTypography.fromYaml(_typography());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
