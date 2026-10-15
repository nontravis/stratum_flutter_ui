import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/google_font_weights.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';
import '../config/theme_fixtures.dart' show layer, sources;

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
      table: inter
      number: { font: geist, mono: geist-mono }
      code: roboto-mono
      mono: roboto-mono
    th:
      body: font-a
    th_TH:
      header: inter-th
      mono: font-b-mono
  scaleByWindowSize: { watch: 0, mobile: 0, tablet: "50%", desktop: 1 }
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
''';

StratumThemeData _theme([String? yaml]) {
  final document = loadYaml(yaml ?? _yaml()) as YamlMap;
  return fakeStratumTheme(
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

/// A typography whose six types draw the Google font [family]: header at
/// [header], number at [number], body at [body], and paragraph and code at
/// 400. The body font loads in every type's weight, so [family]'s weight
/// set is {[header], [number], [body], 400}.
String _googleYaml(
  String family, {
  int header = 600,
  int number = 600,
  int body = 400,
}) =>
    '''
typography:
  fonts:
    g: { family: "Google/$family" }
  families:
    default:
      header: g
      paragraph: g
      number: g
      code: g
      body: g
      table: g
  types:
    header: { weight: $header, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: $number, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body:
      weight: $body
      sizes:
        s12: { spaceHeight: 4 }
        s16: { spaceHeight: 8 }
''';

/// [recipe] with no weight, then with each of the five weight getters.
List<StratumTextStyle> _weighted(StratumTextStyle recipe) => [
  recipe,
  recipe.light,
  recipe.regular,
  recipe.medium,
  recipe.semiBold,
  recipe.bold,
];

/// The family and the weight [style] draws in.
(String?, FontWeight?) _drawn(TextStyle style) =>
    (style.fontFamily, style.fontWeight);

/// [_recipe] with a custom size that skipped the recipe's debug assert, as
/// a release build reads it; the members the resolver reads forward to
/// [_recipe].
class _ReleaseCustomSize implements StratumTextStyle {
  const new(this._recipe, this.customSize);

  final StratumTextStyle _recipe;

  @override
  final double? customSize;

  @override
  FontType get fontType => _recipe.fontType;

  @override
  FontSize get fontSize => _recipe.fontSize;

  @override
  FontWeight? get fontWeight => _recipe.fontWeight;

  @override
  bool get isMono => _recipe.isMono;

  @override
  FontStyle? get fontStyle => _recipe.fontStyle;

  @override
  TextDecoration? get textDecoration => _recipe.textDecoration;

  @override
  List<Shadow>? get textShadows => _recipe.textShadows;

  @override
  FontColor get colorRole => _recipe.colorRole;

  @override
  Color? get customColor => _recipe.customColor;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

    test('a percent spaceHeight resolves on the custom size', () {
      expect(resolve(StratumTextStyle.body.size(15)).height, 1.5);
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

    test("a type's own window scale wins over the theme-wide one, and table "
        "takes body's own override", () {
      theme = _theme('''
typography:
  fonts: { inter: { family: Inter } }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: inter
  scaleByWindowSize: { tablet: "50%", desktop: 1 }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body:
      weight: 400
      scaleByWindowSize: { desktop: 3 }
      sizes: { s16: { spaceHeight: 8 } }
''');

      expect(
        resolve(StratumTextStyle.body, windowSize: WindowSize.desktop).fontSize,
        19,
      );
      expect(
        resolve(StratumTextStyle.body, windowSize: WindowSize.tablet).fontSize,
        24,
      );
      expect(
        resolve(
          StratumTextStyle.table,
          windowSize: WindowSize.desktop,
        ).fontSize,
        19,
      );
    });

    test('fo02/us04/fr02/e04: a window size the scale omits takes the '
        "nearest smaller one either map sets, the type's own winning "
        'there', () {
      theme = _theme('''
typography:
  fonts: { inter: { family: Inter } }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: inter
  scaleByWindowSize: { tablet: "50%", desktop: 1 }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body:
      weight: 400
      scaleByWindowSize: { desktop: 3 }
      sizes: { s16: { spaceHeight: 8 } }
''');

      expect(resolve(StratumTextStyle.header).fontSize, 24);
      expect(
        resolve(StratumTextStyle.header, windowSize: WindowSize.watch).fontSize,
        24,
      );
      expect(
        resolve(
          StratumTextStyle.header,
          windowSize: WindowSize.bigDesktop,
        ).fontSize,
        17,
      );
      expect(
        resolve(
          StratumTextStyle.body,
          windowSize: WindowSize.bigDesktop,
        ).fontSize,
        19,
      );
    });

    test('fo02/us04/s4, fo02/us04/fr02/e01: a tablet window the theme '
        'omits takes the growth of mobile', () {
      theme = _theme('''
typography:
  fonts: { inter: { family: Inter } }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: inter
  scaleByWindowSize: { mobile: 0, desktop: 1 }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''');

      expect(
        resolve(StratumTextStyle.body, windowSize: WindowSize.tablet).fontSize,
        16,
      );
      expect(
        resolve(StratumTextStyle.body, windowSize: WindowSize.desktop).fontSize,
        17,
      );
    });

    test('fo02/us04/fr02: a theme-wide scalar scale names every window '
        'size, so no window reads the type map alone', () {
      final theme = fakeStratumTheme(
        typography: const StratumTypography(
          fonts: {'inter': StratumFontData(family: 'Inter')},
          families: {
            'default': StratumFamilySet(
              types: {FontType.body: StratumFontRef(font: 'inter')},
            ),
          },
          types: {
            FontType.body: StratumTypeStyle(
              weight: FontWeight.w400,
              sizes: {
                FontSize.s16: StratumSizeMetrics(
                  spaceHeight: StratumDimension.fixed(8),
                ),
              },
            ),
          },
          scaleByWindowSize: StratumByWindowSize.all(StratumDimension.fixed(2)),
        ),
      );

      expect(
        TypographyResolver.resolve(
          StratumTextStyle.body,
          theme: theme,
          locale: _en,
          windowSize: WindowSize.watch,
          textScaler: TextScaler.noScaling,
        ).fontSize,
        18,
      );
    });

    test('fo02/us04/fr02: a theme without a theme-wide scaleByWindowSize '
        "fills an omitted window size from the type's own map, built in "
        'code', () {
      final theme = fakeStratumTheme(
        typography: const StratumTypography(
          fonts: {'inter': StratumFontData(family: 'Inter')},
          families: {
            'default': StratumFamilySet(
              types: {FontType.body: StratumFontRef(font: 'inter')},
            ),
          },
          types: {
            FontType.body: StratumTypeStyle(
              weight: FontWeight.w400,
              scaleByWindowSize: {WindowSize.mobile: StratumDimension.fixed(3)},
              sizes: {
                FontSize.s16: StratumSizeMetrics(
                  spaceHeight: StratumDimension.fixed(8),
                ),
              },
            ),
          },
        ),
      );

      expect(
        TypographyResolver.resolve(
          StratumTextStyle.body,
          theme: theme,
          locale: _en,
          windowSize: WindowSize.tablet,
          textScaler: TextScaler.noScaling,
        ).fontSize,
        19,
      );
    });

    test('fo02/us04/fr02: the same, parsed from yaml with no '
        'scaleByWindowSize key at all', () {
      theme = _theme('''
typography:
  fonts: { inter: { family: Inter } }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: inter
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body:
      weight: 400
      scaleByWindowSize: { mobile: 3 }
      sizes: { s16: { spaceHeight: 8 } }
''');

      expect(
        resolve(StratumTextStyle.body, windowSize: WindowSize.tablet).fontSize,
        19,
      );
    });
  });

  group('TypographyResolver draw-time fallback', () {
    /// A typography built in code, which no load-time check reads: an Inter
    /// body font with [adjustSize], body s16 with [spaceHeight] and a
    /// "-1%" letter spacing, and a theme-wide window scale of 1 on desktop.
    StratumThemeData handBuilt({
      StratumDimension adjustSize = const StratumDimension.fixed(0),
      StratumDimension spaceHeight = const StratumDimension.fixed(8),
      StratumDimension windowScale = const StratumDimension.fixed(1),
    }) => fakeStratumTheme(
      typography: StratumTypography(
        fonts: {
          'inter': StratumFontData(family: 'Inter', adjustSize: adjustSize),
        },
        families: const {
          'default': StratumFamilySet(
            types: {FontType.body: StratumFontRef(font: 'inter')},
          ),
        },
        types: {
          FontType.body: StratumTypeStyle(
            weight: FontWeight.w400,
            sizes: {
              FontSize.s16: StratumSizeMetrics(
                spaceHeight: spaceHeight,
                letterSpacing: const StratumDimension.percent(-0.01),
              ),
            },
          ),
        },
        scaleByWindowSize: StratumByWindowSize({
          WindowSize.desktop: windowScale,
        }),
      ),
    );

    TextStyle resolveIn(
      StratumThemeData theme, {
      WindowSize? windowSize,
      TextScaler textScaler = TextScaler.noScaling,
    }) => TypographyResolver.resolve(
      StratumTextStyle.body,
      theme: theme,
      locale: _en,
      windowSize: windowSize,
      textScaler: textScaler,
    );

    /// Every line `debugPrint` prints until the test ends.
    List<String?> printed() {
      final lines = <String?>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message);
      addTearDown(() => debugPrint = previous);
      return lines;
    }

    for (final (name, adjustSize, windowSize) in [
      ('of 0, adjustSize "-100%"', const StratumDimension.percent(-1), null),
      (
        'below 0 on a desktop window',
        const StratumDimension.fixed(-20),
        WindowSize.desktop,
      ),
      ('infinite', const StratumDimension.fixed(double.infinity), null),
      ('NaN', const StratumDimension.fixed(double.nan), null),
    ]) {
      test('fo02/us02/fr01/e04: a font size $name draws at the requested size, '
          'with no window scale, no adjustSize, and no warning', () {
        final lines = printed();

        final style = resolveIn(
          handBuilt(adjustSize: adjustSize),
          windowSize: windowSize,
        );

        expect(style.fontSize, 16);
        expect(style.height, 24 / 16);
        expect(lines, isEmpty);
      });
    }

    test(
      'fo02/us02/fr01/e05: a line box of 0 draws at the scaled requested size, '
      'with no spaceHeight and no warning',
      () {
        final lines = printed();

        final style = resolveIn(
          handBuilt(spaceHeight: const StratumDimension.fixed(-16)),
        );

        expect(style.fontSize, 16);
        expect(style.height, 1);
        expect(lines, isEmpty);
      },
    );

    test(
      'fo02/us02/fr01/e05: a fixed negative spaceHeight the load check passes '
      'falls back at a text scale below 1',
      () {
        theme = _theme(_yaml(bodyS16: '{ spaceHeight: -4 }'));

        final style = resolve(
          StratumTextStyle.body,
          textScaler: const TextScaler.linear(0.2),
        );

        expect(style.fontSize, 16);
        expect(style.height, closeTo(1, 1e-9));
      },
    );

    test(
      'fo02/us02/fr01/e06: a font size and a line box that both fail give the '
      'requested size and a height of 1',
      () {
        final style = resolveIn(
          handBuilt(
            adjustSize: const StratumDimension.percent(-1),
            spaceHeight: const StratumDimension.fixed(-16),
          ),
        );

        expect(style.fontSize, 16);
        expect(style.height, 1);
      },
    );

    test(
      'fo02/us02/fr01/e07: a font size that falls back keeps letter spacing on '
      'the size with the window scale',
      () {
        final style = resolveIn(
          handBuilt(adjustSize: const StratumDimension.fixed(-20)),
          windowSize: WindowSize.desktop,
        );

        expect(style.fontSize, 16);
        expect(style.letterSpacing, closeTo(-0.17, 1e-9));
      },
    );

    test('fo02/us02/fr01/e07: a letter-spacing basis of -60 offset by an '
        'adjustSize of 60 keeps letter spacing on the requested size, with '
        'no assertion', () {
      final style = resolveIn(
        handBuilt(
          adjustSize: const StratumDimension.fixed(60),
          windowScale: const StratumDimension.fixed(-60),
        ),
        windowSize: WindowSize.desktop,
      );

      expect(style.fontSize, 16);
      expect(style.letterSpacing, closeTo(-0.16, 1e-9));
    });

    test(
      'fo02/us03/fr01: the height divides the line box by the scaled font size '
      'after the fallback',
      () {
        final style = resolveIn(
          handBuilt(
            adjustSize: const StratumDimension.fixed(-20),
            spaceHeight: const StratumDimension.percent(0.5),
          ),
          windowSize: WindowSize.desktop,
          textScaler: const TextScaler.linear(2),
        );

        expect(style.fontSize, 16);
        expect(style.height, 48 / 32);
      },
    );

    test('fo02/us02/s4: a theme that loads draws a small custom size under a '
        'large negative font correction at the size the widget asked for', () {
      theme = _theme(
        _yaml().replaceFirst(
          'inter: { family: Inter }',
          'inter: { family: Inter, adjustSize: -8 }',
        ),
      );

      final style = resolve(StratumTextStyle.body.size(5));

      expect(style.fontSize, 5);
      expect(style.height, 9 / 5);
    });
  });

  group('TypographyResolver custom size', () {
    for (final size in [0.0, -1.0, double.infinity, double.nan]) {
      test(
        'fo02/us01/fr01/e07: a release build reads a custom size of $size as '
        'unset: the text takes s16 for its size and its metrics',
        () {
          final style = resolve(
            _ReleaseCustomSize(StratumTextStyle.body, size),
          );
          final named = resolve(StratumTextStyle.body);

          expect(style.fontSize, named.fontSize);
          expect(style.height, named.height);
          expect(style.letterSpacing, named.letterSpacing);
        },
      );
    }
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

    test("table's family comes from families.<tag>.table; th without table "
        'gets default.table', () {
      expect(
        resolve(StratumTextStyle.table, locale: _thTH).fontFamily,
        'Inter',
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
    default: { header: inter, paragraph: inter, number: inter, code: inter, body: inter, table: inter }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
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
        'Font A',
      ]);
      expect(resolve(StratumTextStyle.body.mono).fontFamilyFallback, [
        'Inter',
        'Font A',
        'Font B Mono',
      ]);
    });

    test(
      "the fallback adds each tag's body font after the type's own fonts",
      () {
        expect(resolve(StratumTextStyle.code).fontFamilyFallback, [
          'Inter',
          'Font A',
        ]);
        expect(
          resolve(
            StratumTextStyle.table,
            locale: const Locale('th'),
          ).fontFamilyFallback,
          ['Font A'],
        );
      },
    );

    test('the fallback drops a font key that shares the primary family', () {
      theme = _theme('''
typography:
  fonts:
    inter: { family: Inter }
    inter-alt: { family: Inter }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: inter
    th:
      body: inter-alt
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''');

      expect(resolve(StratumTextStyle.body).fontFamilyFallback, isNull);
    });
  });

  group('TypographyResolver weight, features, color, and style', () {
    test('the weight defaults to the type and yields to the recipe', () {
      expect(resolve(StratumTextStyle.body).fontWeight, FontWeight.w400);
      expect(resolve(StratumTextStyle.header.s24).fontWeight, FontWeight.w600);
      expect(resolve(StratumTextStyle.body.bold).fontWeight, FontWeight.w700);
    });

    test("table resolves body's sizes and weight, with tabular figures", () {
      final body = resolve(StratumTextStyle.body.s20);
      final table = resolve(StratumTextStyle.table.s20);

      expect(table.fontSize, body.fontSize);
      expect(table.height, body.height);
      expect(table.letterSpacing, body.letterSpacing);
      expect(table.fontWeight, body.fontWeight);
      expect(table.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(body.fontFeatures, isNull);
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

  group('TypographyResolver on a hand-built typography', () {
    TextStyle resolveWith(StratumThemeData theme) => TypographyResolver.resolve(
      StratumTextStyle.body,
      theme: theme,
      locale: _en,
      windowSize: null,
      textScaler: TextScaler.noScaling,
    );

    test('a missing type names itself in a StateError', () {
      final badTheme = fakeStratumTheme(
        typography: const StratumTypography(fonts: {}, families: {}, types: {}),
      );

      expect(
        () => resolveWith(badTheme),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('body'),
          ),
        ),
      );
    });

    test('a missing font key names itself in a StateError', () {
      final badTheme = fakeStratumTheme(
        typography: const StratumTypography(
          fonts: {},
          families: {
            'default': StratumFamilySet(
              types: {FontType.body: StratumFontRef(font: 'ghost')},
            ),
          },
          types: {
            FontType.body: StratumTypeStyle(
              weight: FontWeight.w400,
              sizes: {
                FontSize.s16: StratumSizeMetrics(
                  spaceHeight: StratumDimension.fixed(8),
                ),
              },
            ),
          },
        ),
      );

      expect(
        () => resolveWith(badTheme),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('ghost'),
          ),
        ),
      );
    });

    test('a type with no sizes names itself in a StateError', () {
      final badTheme = fakeStratumTheme(
        typography: const StratumTypography(
          fonts: {'inter': StratumFontData(family: 'Inter')},
          families: {
            'default': StratumFamilySet(
              types: {FontType.body: StratumFontRef(font: 'inter')},
            ),
          },
          types: {
            FontType.body: StratumTypeStyle(weight: FontWeight.w400, sizes: {}),
          },
        ),
      );

      expect(
        () => resolveWith(badTheme),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('body'),
          ),
        ),
      );
    });
  });

  group('TypographyResolver Google Fonts', () {
    final defaultExists = GoogleFontsLookup.exists;
    final defaultFamily = GoogleFontsLookup.family;

    tearDown(() {
      GoogleFontsLookup.exists = defaultExists;
      GoogleFontsLookup.family = defaultFamily;
    });

    test('fo02/us08/fr02: asks the seam for the primary and fallback family, '
        "each at its own snapped weight and the recipe's style", () {
      final calls = <(String, FontWeight, FontStyle?)>[];
      GoogleFontsLookup.exists = (name) => true;
      GoogleFontsLookup.family = (name, {required weight, required style}) {
        calls.add((name, weight, style));
        return 'Resolved $name';
      };
      theme = _theme('''
typography:
  fonts:
    inter: { family: Inter }
    kanit: { family: "Google/Kanit" }
    kanit2: { family: "Google/Kanit2" }
  families:
    default:
      header: kanit
      paragraph: inter
      number: inter
      code: inter
      body: kanit2
      table: inter
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''');

      final style = resolve(StratumTextStyle.header.bold.italic);

      expect(style.fontFamily, 'Resolved Kanit');
      expect(style.fontFamilyFallback, ['Resolved Kanit2']);
      expect(style.fontWeight, FontWeight.w600);
      // Kanit loads in {600}, header's weight; Kanit2, the body font, in
      // every type's weight, {400, 600}: 700 snaps to 600 in both.
      expect(calls, [
        ('Kanit', FontWeight.w600, FontStyle.italic),
        ('Kanit2', FontWeight.w600, FontStyle.italic),
      ]);
    });

    test('a bundled font never calls the Google Fonts seam', () {
      GoogleFontsLookup.family = (name, {required weight, required style}) =>
          throw StateError('should not be called for $name');

      final style = resolve(StratumTextStyle.body);

      expect(style.fontFamily, 'Inter');
    });
  });

  group('fo02/us08/fr02: TypographyResolver Google font weights', () {
    final defaultExists = GoogleFontsLookup.exists;
    final defaultFamily = GoogleFontsLookup.family;
    final calls = <(String, FontWeight, FontStyle?)>[];

    setUp(() {
      calls.clear();
      GoogleFontsLookup.exists = (name) => true;
      GoogleFontsLookup.family = (name, {required weight, required style}) {
        calls.add((name, weight, style));
        return name;
      };
    });

    tearDown(() {
      GoogleFontsLookup.exists = defaultExists;
      GoogleFontsLookup.family = defaultFamily;
    });

    /// Every `debugPrint` line of this test. The resolver warns once per
    /// run, so each warning test uses a family no other test snaps.
    List<String> printed() {
      final lines = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = saved);
      return lines;
    }

    test(
      'fo02/us08/s1: a theme whose body font is Google/Inter draws body text '
      'in the family the library registers for Inter',
      () {
        theme = defaultThemeSet.light.copyWith();

        expect(resolve(StratumTextStyle.body).fontFamily, 'Inter');
        expect(calls.first, ('Inter', FontWeight.w400, null));
      },
    );

    test('fo02/us08/fr02/e03: a weight the theme loads draws as asked, with no '
        'warning', () {
      final lines = printed();
      theme = _theme(_googleYaml('Semi Lato'));

      expect(_drawn(resolve(StratumTextStyle.body.semiBold)), (
        'Semi Lato',
        FontWeight.w600,
      ));
      expect(calls, [('Semi Lato', FontWeight.w600, null)]);
      expect(lines, isEmpty);
    });

    test(
      'fo02/us08/fr02/e04: under the package default, body medium draws Inter '
      '600, header bold Inter 600, body light Inter 400, and number '
      'regular Geist 600',
      () {
        theme = defaultThemeSet.light.copyWith();

        expect(
          [
            resolve(StratumTextStyle.body.medium),
            resolve(StratumTextStyle.header.s24.bold),
            resolve(StratumTextStyle.body.light),
            resolve(StratumTextStyle.number.regular),
          ].map(_drawn),
          [
            ('Inter', FontWeight.w600),
            ('Inter', FontWeight.w600),
            ('Inter', FontWeight.w400),
            ('Geist', FontWeight.w600),
          ],
        );
      },
    );

    test(
      'fo02/us08/fr02/e04: a snap warns once per family and requested weight '
      'per run',
      () {
        final lines = printed();
        const warning =
            'Stratum theme: Google font "Warn Lato" is not loaded in weight '
            '500; drawing 600';

        theme = _theme(_googleYaml('Warn Lato'));
        resolve(StratumTextStyle.body.medium);
        resolve(StratumTextStyle.body.s12.medium);
        theme = _theme(_googleYaml('Warn Lato', header: 400, number: 400));
        resolve(StratumTextStyle.body.medium);

        expect(lines, [warning]);
      },
    );

    test('fo02/us08/fr02/e04: a weight off the hundreds, and w100 and w900, '
        'snap through the resolver as the pure rule says', () {
      theme = _theme(_googleYaml('Odd Lato'));

      // Odd Lato loads in {400, 600}: 450 is nearer 400, w100 snaps up to
      // 400, w900 down to 600.
      expect(
        _drawn(resolve(StratumTextStyle.body.weight(const FontWeight(450)))),
        ('Odd Lato', FontWeight.w400),
      );
      expect(_drawn(resolve(StratumTextStyle.body.weight(FontWeight.w100))), (
        'Odd Lato',
        FontWeight.w400,
      ));
      expect(_drawn(resolve(StratumTextStyle.body.weight(FontWeight.w900))), (
        'Odd Lato',
        FontWeight.w600,
      ));
      expect(calls.map((call) => (call.$1, call.$2)), [
        ('Odd Lato', FontWeight.w400),
        ('Odd Lato', FontWeight.w400),
        ('Odd Lato', FontWeight.w600),
      ]);
    });

    test('s03/inv13: each theme snaps against its own weight set', () {
      theme = _theme(_googleYaml('Switch Lato'));
      final first = resolve(StratumTextStyle.body.medium).fontWeight;
      theme = _theme(_googleYaml('Switch Lato', body: 500));
      final second = resolve(StratumTextStyle.body.medium).fontWeight;
      theme = _theme(_googleYaml('Switch Lato'));
      final third = resolve(StratumTextStyle.body.medium).fontWeight;

      expect(
        [first, second, third],
        [FontWeight.w600, FontWeight.w500, FontWeight.w600],
      );
    });

    test('fo02/us08/fr02/e06: the primary and each Google font in the fallback '
        'list snap against their own sets, ties to the heavier; an app '
        'font keeps the asked weight', () {
      theme = _theme('''
typography:
  fonts:
    lato: { family: "Google/Lato" }
    kanit: { family: "Google/Kanit" }
    brand: { family: Brand }
  families:
    default:
      header: lato
      paragraph: lato
      number: brand
      code: brand
      body: lato
      table: lato
    th:
      header: kanit
      body: brand
  types:
    header: { weight: 700, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''');

      // Lato loads in {400, 600, 700}; Kanit, named only for th's header,
      // in {700}.
      final header = resolve(StratumTextStyle.header.medium);
      expect(_drawn(header), ('Lato', FontWeight.w600));
      expect(header.fontFamilyFallback, ['Kanit', 'Brand']);
      expect(calls, [
        ('Lato', FontWeight.w600, null),
        ('Kanit', FontWeight.w700, null),
      ]);

      calls.clear();
      final number = resolve(StratumTextStyle.number.medium);
      expect(_drawn(number), ('Brand', FontWeight.w500));
      expect(number.fontFamilyFallback, ['Lato']);
      expect(calls, [('Lato', FontWeight.w600, null)]);
    });

    test('fo02/us08/fr02/e06: under the package default, number regular draws '
        'Geist 600 and its Inter and Kanit fallbacks name their 600 faces', () {
      theme = defaultThemeSet.light.copyWith();

      final style = resolve(StratumTextStyle.number.regular);

      expect(_drawn(style), ('Geist', FontWeight.w600));
      // Geist snaps 400 to 600 (set {600}), so the style draws w600; each
      // Google fallback snaps that drawn weight into its own set, so Inter
      // and Kanit (sets {400, 600}) name their 600 faces, never a 400-only
      // face the engine would fake bold from (FR-02 E06).
      expect(calls, [
        ('Geist', FontWeight.w600, null),
        ('Inter', FontWeight.w600, null),
        ('Kanit', FontWeight.w600, null),
      ]);
    });

    test("fo02/us08/fr02/e06: a table font of its own snaps at body's weight, "
        'differently from the fonts the other types name', () {
      // Body draws Inter (set {400, 600}); table draws Roboto Flex
      // (set {400}), so the two snap the same requested weight apart.
      theme = _theme('''
typography:
  fonts:
    inter: { family: "Google/Inter" }
    flex: { family: "Google/Roboto Flex" }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: flex
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''');

      final table = resolve(StratumTextStyle.table.bold);
      final body = resolve(StratumTextStyle.body.bold);

      // Table has no type entry of its own, so Roboto Flex loads only in
      // table's weight — body's 400 — while Inter loads in {400, 600}: the
      // same bold recipe snaps 700 down to 400 for table and to 600 for
      // body.
      expect(_drawn(table), ('Roboto Flex', FontWeight.w400));
      expect(_drawn(body), ('Inter', FontWeight.w600));
    });

    test('s03/inv13: the same recipe snaps differently under different '
        "locale tags, each tag against its own font's set", () {
      // Default's header draws Inter (set {400, 600}); th's header draws
      // Kanit, named only there, in header's weight alone (set {600}), so
      // the same light recipe snaps 300 down to 400 under default but up
      // to 600 under th.
      theme = _theme('''
typography:
  fonts:
    inter: { family: "Google/Inter" }
    kanit: { family: "Google/Kanit" }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: inter
    th: { header: kanit }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''');

      final english = resolve(StratumTextStyle.header.light, locale: _en);
      final thai = resolve(
        StratumTextStyle.header.light,
        locale: const Locale('th'),
      );

      expect(_drawn(english), ('Inter', FontWeight.w400));
      expect(_drawn(thai), ('Kanit', FontWeight.w600));
    });

    test(
      'fo02/us08/fr02/e06: a theme-source primary with Google fallbacks keeps '
      'the resolved weight, and each fallback snaps that weight into its '
      'own set',
      () {
        final brandFont = layer('''
typography:
  fonts:
    brand: { family: DB Heavent, files: [fonts/DBHeavent-Regular.ttf] }
    lato: { family: "Google/Lato" }
    kanit: { family: "Google/Kanit" }
  families:
    default:
      header: brand
      paragraph: lato
      number: lato
      code: lato
      body: lato
      table: lato
    th:
      header: kanit
  types:
    header: { weight: 700, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''');
        theme = fakeStratumTheme(
          typography: StratumThemeConfig.parse(
            base: sources(const []).first,
            layers: [
              StratumThemeSource(
                id: 'brand',
                folder: 'assets/themes/brand',
                yaml: brandFont,
              ),
            ],
          ).typography,
        );

        // The theme font keeps the resolved weight; each Google fallback
        // snaps it into its own set: Lato, the default body font, loads in
        // every type's weight ({400, 600, 700}); Kanit, named only for th's
        // header, in {700} — so bold passes through both, and medium draws
        // Lato 600 but Kanit 700, each nearest in its own set.
        final bold = resolve(StratumTextStyle.header.bold);
        expect(_drawn(bold), ('brand/DB Heavent', FontWeight.w700));
        expect(bold.fontFamilyFallback, ['Kanit', 'Lato']);
        expect(calls, [
          ('Kanit', FontWeight.w700, null),
          ('Lato', FontWeight.w700, null),
        ]);

        calls.clear();
        final medium = resolve(StratumTextStyle.header.medium);
        expect(_drawn(medium), ('brand/DB Heavent', FontWeight.w500));
        expect(medium.fontFamilyFallback, ['Kanit', 'Lato']);
        expect(calls, [
          ('Kanit', FontWeight.w700, null),
          ('Lato', FontWeight.w600, null),
        ]);
      },
    );

    test('fo02/us08/fr02/e07: an italic recipe snaps as a normal one and asks '
        'for the italic face at the snapped weight', () {
      theme = defaultThemeSet.light.copyWith();

      final style = resolve(StratumTextStyle.header.s24.bold.italic);

      expect(style.fontStyle, FontStyle.italic);
      expect(style.fontWeight, FontWeight.w600);
      expect(calls.first, ('Inter', FontWeight.w600, FontStyle.italic));
      expect(calls.map((call) => call.$2).toSet(), {FontWeight.w600});
    });

    test(
      'fo02/us08/fr02/e08: the library is never asked for a weight outside a '
      "Google font's weight set",
      () {
        theme = defaultThemeSet.light.copyWith();
        final sets = GoogleFontWeights.of(theme.typography);

        for (final locale in const [Locale('en'), Locale('th')]) {
          for (final type in FontType.values) {
            for (final recipe in _weighted(StratumTextStyle.type(type))) {
              resolve(recipe, locale: locale);
              resolve(recipe.mono, locale: locale);
              resolve(recipe.italic, locale: locale);
            }
          }
        }

        expect(calls, isNotEmpty);
        for (final (name, weight, _) in calls) {
          expect(sets[name], contains(weight), reason: '$name $weight');
        }
      },
    );

    test('fo02/us05/fr02/e05: a weight the yaml does not declare for a Google '
        'font is never asked of the library', () {
      theme = defaultThemeSet.light.copyWith();

      resolve(StratumTextStyle.body.medium);

      expect(calls, isNotEmpty);
      expect(calls.where((call) => call.$2 == FontWeight.w500), isEmpty);
    });

    test('fo02/us08/fr02/e08: run-time fetching on or off asks the library for '
        "the same weights, each inside its family's weight set", () {
      final fetching = GoogleFonts.config.allowRuntimeFetching;
      addTearDown(() => GoogleFonts.config.allowRuntimeFetching = fetching);
      List<(String, FontWeight, FontStyle?)> drawAll() {
        calls.clear();
        theme = defaultThemeSet.light.copyWith();
        void draw(StratumTextStyle recipe) => resolve(recipe);
        for (final type in FontType.values) {
          _weighted(StratumTextStyle.type(type)).forEach(draw);
        }
        return List.of(calls);
      }

      GoogleFonts.config.allowRuntimeFetching = true;
      final on = drawAll();
      GoogleFonts.config.allowRuntimeFetching = false;
      final off = drawAll();
      final sets = GoogleFontWeights.of(theme.typography);

      // The fake lookup never reads the flag, so equality alone cannot
      // fail; the load-bearing half is that the same in-set weights are
      // asked under both values (the real fetch-off proof lives in the
      // example's perf_fonts_test).
      expect(off, on);
      expect(on, isNotEmpty);
      for (final (name, weight, _) in on) {
        expect(sets[name], contains(weight), reason: '$name $weight');
      }
    });

    test('fo02/us08/fr02/e10: the weight set comes from the theme typography, '
        'with no wait run', () {
      final pending = GoogleFontsLookup.pending;
      addTearDown(() => GoogleFontsLookup.pending = pending);
      GoogleFontsLookup.pending = () => throw StateError('no wait runs here');
      theme = defaultThemeSet.light.copyWith();

      expect(resolve(StratumTextStyle.body.medium).fontWeight, FontWeight.w600);
    });

    test('fo02/us08/fr02/e11: a bold recipe on a font loaded only in 400 draws '
        'with weight 400', () {
      theme = _theme(_googleYaml('Bold Lato', header: 400, number: 400));

      expect(_drawn(resolve(StratumTextStyle.body.bold)), (
        'Bold Lato',
        FontWeight.w400,
      ));
      expect(calls, [('Bold Lato', FontWeight.w400, null)]);
    });
  });

  group('fo02/us07/fr01: TypographyResolver theme font families', () {
    /// The data of the base fixture under [layers], each layer the app
    /// theme of its key, read from `assets/themes/<key>`.
    StratumThemeData themed(Map<String, String> layers) => fakeStratumTheme(
      typography: StratumThemeConfig.parse(
        base: sources(const []).first,
        layers: [
          for (final MapEntry(key: id, value: yaml) in layers.entries)
            StratumThemeSource(id: id, folder: 'assets/themes/$id', yaml: yaml),
        ],
      ).typography,
    );

    final brandFont = layer('''
typography:
  fonts:
    brand: { family: DB Heavent, files: [fonts/DBHeavent-Regular.ttf] }
  families:
    default:
      body: brand''');

    test('fo02/us05/s4: two themes that ship the same family name resolve '
        'apart', () {
      theme = themed({'brand': brandFont});
      final brand = resolve(StratumTextStyle.body);
      theme = themed({'night': brandFont});
      final night = resolve(StratumTextStyle.body);

      expect(brand.fontFamily, 'brand/DB Heavent');
      expect(night.fontFamily, 'night/DB Heavent');
    });

    test('fo02/us05/fr01/e05: a theme that inherits the font draws with its '
        "source's registration", () {
      theme = themed({'default': brandFont, 'brand': layer('name: brand')});

      expect(resolve(StratumTextStyle.body).fontFamily, 'default/DB Heavent');
    });

    test(
      'fo02/us08/fr02/e02: a theme font never asks the Google Fonts seam',
      () {
        final saved = GoogleFontsLookup.family;
        addTearDown(() => GoogleFontsLookup.family = saved);
        GoogleFontsLookup.family = (name, {required weight, required style}) =>
            throw StateError('should not be called for $name');
        theme = themed({'brand': brandFont});

        expect(resolve(StratumTextStyle.body).fontFamily, 'brand/DB Heavent');
      },
    );

    test('fo02/us05/fr01/e07: a theme font carries the resolved weight', () {
      theme = themed({'brand': brandFont});

      expect(resolve(StratumTextStyle.body).fontWeight, FontWeight.w400);
      expect(resolve(StratumTextStyle.body.bold).fontWeight, FontWeight.w700);
    });

    test('S4 wght A: a variable theme font follows fontWeight, so no '
        'font sets a wght axis', () {
      theme = themed({'brand': brandFont});

      expect(resolve(StratumTextStyle.body).fontVariations, isNull);
      expect(resolve(StratumTextStyle.header).fontVariations, isNull);
    });
  });

  group('TypographyResolver cache', () {
    test('fo02/us01/s3: a hit returns the identical instance', () {
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

    test('s03/inv13: a cached style of one theme never serves another, and '
        'a switch back to a theme still in scope serves its own entry', () {
      // Two themes over the same yaml but parsed apart, so each holds its
      // own typography instance and its own cache.
      final a = _theme();
      final b = _theme();
      final recipe = StratumTextStyle.body.s20;

      theme = a;
      final fromA = resolve(recipe);
      theme = b;
      final fromB = resolve(recipe);
      theme = a;

      expect(identical(resolve(recipe), fromA), isTrue);
      expect(identical(fromB, fromA), isFalse);
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
