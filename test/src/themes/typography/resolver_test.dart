import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';

/// The section 7 setup of the spec, plus a Thai header font, a mono font
/// for th_TH, and a table type with its own window scale.
String _yaml({
  String bodyS16 = '{ spaceHeight: "50%", letterSpacing: "-1%" }',
}) =>
    '''
typography:
  fonts:
    inter: { family: Inter }
    font-a: { family: Font A, adjustSize: 2 }
    inter-th: { family: Inter TH, package: thai_fonts }
    geist: { family: Geist }
    geist-mono: { family: Geist Mono }
    roboto-mono: { family: Roboto Mono }
    font-b-mono: { family: Font B Mono, adjustSize: "10%" }
  families:
    default:
      header: inter
      paragraph: inter
      body: inter
      number: { font: geist, mono: geist-mono }
      code: roboto-mono
      mono: roboto-mono
    th:
      body: font-a
    th_TH:
      header: inter-th
      mono: font-b-mono
  scaleByWindowSize: { tablet: "50%", desktop: 1 }
  types:
    header: { weight: 600, sizes: { s24: { spaceHeight: 10 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 10 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body:
      weight: 400
      sizes:
        s12: { spaceHeight: 4 }
        s16: $bodyS16
        s20: { spaceHeight: 8 }
    table: { extends: body, tabular: true, scaleByWindowSize: { desktop: 3 } }
''';

StratumThemeData _theme([String? yaml]) {
  final document = loadYaml(yaml ?? _yaml()) as YamlMap;
  return FakeStratumTheme(
    typography: StratumTypography.fromYaml(document['typography'] as YamlMap),
  );
}

const _en = Locale('en', 'US');
const _thTH = Locale('th', 'TH');

/// Doubles sizes up to 16 and adds the rest unscaled, like the nonlinear
/// font scaling of Android 14.
class _NonlinearScaler extends TextScaler {
  const new();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize * 2 : 32 + (fontSize - 16);

  @override
  double get textScaleFactor => 2;
}

void main() {
  late StratumThemeData theme;

  setUp(() => theme = _theme());

  TextStyle resolve(
    StratumTextStyle recipe, {
    Locale locale = _en,
    WindowSize? windowSize = WindowSize.mobile,
    TextScaler textScaler = TextScaler.noScaling,
  }) => TypographyResolver.resolve(
    recipe,
    theme: theme,
    locale: locale,
    windowSize: windowSize,
    textScaler: textScaler,
  );

  group('TypographyResolver, the spec section 7 example', () {
    final recipe = StratumTextStyle.body.s16.medium;

    test('at a text scale of 2.0', () {
      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
        textScaler: const TextScaler.linear(2),
      );

      expect(style.fontFamily, 'Font A');
      expect(style.fontFamilyFallback, ['Inter']);
      expect(style.fontSize, 19);
      expect(style.height, closeTo(48 / 38, 1e-9));
      expect(style.letterSpacing, closeTo(-0.34, 1e-9));
      expect(style.fontWeight, FontWeight.w500);
      expect(style.leadingDistribution, TextLeadingDistribution.even);
    });

    test('at a text scale of 1.0, tracking based before adjustSize', () {
      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
      );

      expect(style.fontSize, 19);
      expect(style.height, closeTo(24 / 19, 1e-9));
      expect(style.letterSpacing, closeTo(-0.17, 1e-9));
    });

    test('a fixed spaceHeight keeps its pixels at a text scale of 2.0', () {
      theme = _theme(_yaml(bodyS16: '{ spaceHeight: 8 }'));

      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
        textScaler: const TextScaler.linear(2),
      );

      expect(style.height, closeTo((32 + 8) / 38, 1e-9));
    });

    test('a nonlinear scaler scales each value on its own', () {
      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
        textScaler: const _NonlinearScaler(),
      );

      expect(style.fontSize, 19);
      expect(style.height, closeTo(48 / 35, 1e-9));
      expect(style.letterSpacing, closeTo(-0.33, 1e-9));
    });
  });

  group('TypographyResolver line box', () {
    test('a percent spaceHeight keeps the height at any scale', () {
      final s16 = StratumTextStyle.body.s16;

      expect(resolve(s16).height, 1.5);
      expect(resolve(s16, textScaler: const TextScaler.linear(2)).height, 1.5);
    });

    test('a fixed spaceHeight tightens the height as text grows', () {
      final s20 = StratumTextStyle.body.s20;

      expect(resolve(s20).height, closeTo(28 / 20, 1e-9));
      expect(
        resolve(s20, textScaler: const TextScaler.linear(2)).height,
        closeTo(48 / 40, 1e-9),
      );
    });

    test('the window scale grows the font but not the line box', () {
      final style = resolve(
        StratumTextStyle.body.s20,
        windowSize: WindowSize.desktop,
      );

      expect(style.fontSize, 21);
      expect(style.height! * style.fontSize!, closeTo(28, 1e-9));
    });
  });

  group('TypographyResolver sizes', () {
    test('a missing size takes the nearest one, the smaller on a tie', () {
      final s14 = resolve(StratumTextStyle.body.s14);
      final s18 = resolve(StratumTextStyle.body.s18);
      final s24 = resolve(StratumTextStyle.body.s24);

      expect(s14.fontSize, 14);
      expect(s14.height, closeTo((14 + 4) / 14, 1e-9));
      expect(s18.height, closeTo((18 + 9) / 18, 1e-9));
      expect(s24.height, closeTo((24 + 8) / 24, 1e-9));
    });

    test('a missing size warns once per type and size', () {
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      resolve(StratumTextStyle.code.s36);
      resolve(
        StratumTextStyle.code.s36,
        textScaler: const TextScaler.linear(2),
      );

      expect(warnings, ['Stratum theme: code has no size s36; using s16']);
    });

    test('a custom size beyond either end takes the end size', () {
      final small = resolve(StratumTextStyle.body.size(4));
      final large = resolve(StratumTextStyle.body.size(100));

      expect(small.height, closeTo((4 + 4) / 4, 1e-9));
      expect(large.fontSize, 100);
      expect(large.height, closeTo((100 + 8) / 100, 1e-9));
    });

    test('a custom size takes the nearest metrics without a warning', () {
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      final style = resolve(StratumTextStyle.body.size(13));

      expect(style.fontSize, 13);
      expect(style.height, closeTo((13 + 4) / 13, 1e-9));
      expect(warnings, isEmpty);
    });
  });

  group('TypographyResolver window scale', () {
    test('a null window size adds nothing', () {
      expect(resolve(StratumTextStyle.body, windowSize: null).fontSize, 16);
    });

    test('a percent window scale resolves against the requested size', () {
      expect(
        resolve(StratumTextStyle.body, windowSize: WindowSize.tablet).fontSize,
        24,
      );
    });

    test("a type's own window scale wins over the theme-wide one", () {
      expect(
        resolve(
          StratumTextStyle.table,
          windowSize: WindowSize.desktop,
        ).fontSize,
        19,
      );
      expect(
        resolve(StratumTextStyle.table, windowSize: WindowSize.tablet).fontSize,
        24,
      );
    });
  });

  group('TypographyResolver fonts', () {
    test('the locale tags run from th_TH to th to default', () {
      expect(
        resolve(StratumTextStyle.header.s24, locale: _thTH).fontFamily,
        'packages/thai_fonts/Inter TH',
      );
      expect(
        resolve(
          StratumTextStyle.header.s24,
          locale: const Locale('th'),
        ).fontFamily,
        'Inter',
      );
      expect(
        resolve(StratumTextStyle.body, locale: const Locale('th')).fontFamily,
        'Font A',
      );
      expect(resolve(StratumTextStyle.body).fontFamily, 'Inter');
    });

    test('an empty country code counts as no country', () {
      expect(
        resolve(
          StratumTextStyle.body,
          locale: const Locale('th', ''),
        ).fontFamily,
        'Font A',
      );
    });

    test('the lookup walks extends inside each tag', () {
      expect(
        resolve(StratumTextStyle.table, locale: _thTH).fontFamily,
        'Font A',
      );
    });

    test('mono takes the type mono, then the tag mono, then warns', () {
      expect(resolve(StratumTextStyle.number.mono).fontFamily, 'Geist Mono');
      expect(
        resolve(StratumTextStyle.number.mono, locale: _thTH).fontFamily,
        'Geist Mono',
      );
      expect(resolve(StratumTextStyle.body.mono).fontFamily, 'Roboto Mono');
      expect(
        resolve(StratumTextStyle.body.mono, locale: _thTH).fontFamily,
        'Font B Mono',
      );
    });

    test("mono applies the mono font's own adjustSize", () {
      final style = resolve(StratumTextStyle.body.mono, locale: _thTH);

      expect(style.fontSize, closeTo(16 + 1.6, 1e-9));
      expect(style.height, closeTo(24 / 17.6, 1e-9));
    });

    test('mono on code changes nothing; on table it keeps tabular figures', () {
      expect(
        resolve(StratumTextStyle.code.mono),
        resolve(StratumTextStyle.code),
      );

      final table = resolve(StratumTextStyle.table.mono);
      expect(table.fontFamily, 'Roboto Mono');
      expect(table.fontFeatures, [const FontFeature.tabularFigures()]);
    });

    test('mono without any mono font keeps the primary and warns', () {
      theme = _theme('''
typography:
  fonts: { inter: { family: Inter } }
  families:
    default: { header: inter, paragraph: inter, number: inter, code: inter, body: inter }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    table: { extends: body, tabular: true }
''');
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      expect(resolve(StratumTextStyle.body.mono).fontFamily, 'Inter');
      expect(warnings, ['Stratum theme: no mono font for body; using Inter']);
    });

    test('the fallback lists the same type from every other tag', () {
      expect(resolve(StratumTextStyle.body).fontFamilyFallback, ['Font A']);
      expect(resolve(StratumTextStyle.header.s24).fontFamilyFallback, [
        'packages/thai_fonts/Inter TH',
      ]);
      expect(resolve(StratumTextStyle.body.mono).fontFamilyFallback, [
        'Inter',
        'Font A',
        'Font B Mono',
      ]);
      expect(resolve(StratumTextStyle.code).fontFamilyFallback, isNull);
    });
  });

  group('TypographyResolver weight, features, color, and style', () {
    test('the weight defaults to the type and yields to the recipe', () {
      expect(resolve(StratumTextStyle.body).fontWeight, FontWeight.w400);
      expect(resolve(StratumTextStyle.header.s24).fontWeight, FontWeight.w600);
      expect(resolve(StratumTextStyle.body.bold).fontWeight, FontWeight.w700);
    });

    test('a tabular type draws tabular figures', () {
      expect(resolve(StratumTextStyle.table).fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
      expect(resolve(StratumTextStyle.body).fontFeatures, isNull);
    });

    test('each FontColor maps to its theme text color', () {
      for (final role in FontColor.values) {
        expect(
          resolve(StratumTextStyle.body.fontColor(role)).color,
          fakeTextColors[role],
          reason: '$role',
        );
      }
    });

    test('a custom color wins over the FontColor', () {
      expect(
        resolve(StratumTextStyle.body.color(const Color(0xFF123456))).color,
        const Color(0xFF123456),
      );
    });

    test('italic, decoration, and shadows pass through', () {
      final style = resolve(
        StratumTextStyle.body.italic.underline.shadows(const [
          Shadow(blurRadius: 2),
        ]),
      );

      expect(style.fontStyle, FontStyle.italic);
      expect(style.decoration, TextDecoration.underline);
      expect(style.shadows, const [Shadow(blurRadius: 2)]);
    });
  });

  group('TypographyResolver cache', () {
    test('a hit returns the identical instance', () {
      final recipe = StratumTextStyle.body.s20;

      expect(identical(resolve(recipe), resolve(recipe)), isTrue);
    });

    test('a different window size gives a different instance', () {
      final recipe = StratumTextStyle.body.s20;

      expect(
        identical(
          resolve(recipe),
          resolve(recipe, windowSize: WindowSize.desktop),
        ),
        isFalse,
      );
    });

    test('each theme keeps its own cache', () {
      final recipe = StratumTextStyle.body.s20;
      final first = resolve(recipe);
      theme = _theme();

      expect(identical(resolve(recipe), first), isFalse);
      expect(resolve(recipe), first);
    });

    test('the 513th entry clears the cache', () {
      final first = resolve(StratumTextStyle.body.size(1000));
      for (var i = 1; i < TypographyResolver.maxCacheEntries; i++) {
        resolve(StratumTextStyle.body.size(1000.0 + i));
      }
      expect(
        identical(resolve(StratumTextStyle.body.size(1000)), first),
        isTrue,
      );

      resolve(StratumTextStyle.body.size(2000));

      expect(
        identical(resolve(StratumTextStyle.body.size(1000)), first),
        isFalse,
      );
    });
  });
}
