import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/google_font_weights.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';

/// Figma line heights by size (file wjRe9eL7863nMRfFats8jZ, node
/// 56740:3360, read 2026-10-02).
const _header = {56: 72, 36: 48, 24: 34, 20: 28, 18: 24, 14: 20, 12: 20};
const _paragraph = {20: 32, 18: 30, 16: 26, 14: 24};
const _body = {18: 28, 16: 24, 14: 24, 12: 16, 10: 16};
const _table = {18: 28, 16: 24, 14: 24, 12: 16};
const _number = {36: 48, 24: 32, 18: 24, 16: 24, 14: 24, 12: 16};
const _code = {18: 24, 16: 24, 14: 24, 12: 16};

StratumTextStyle _at(StratumTextStyle style, int size) => switch (size) {
  10 => style.s10,
  12 => style.s12,
  14 => style.s14,
  16 => style.s16,
  18 => style.s18,
  20 => style.s20,
  24 => style.s24,
  36 => style.s36,
  48 => style.s48,
  56 => style.s56,
  _ => throw ArgumentError.value(size, 'size'),
};

/// A Figma text style: its name, the recipe for it, its size and line
/// height, and its family and weight.
typedef _FigmaStyle = ({
  String name,
  StratumTextStyle recipe,
  int size,
  int lineHeight,
  String family,
  FontWeight weight,
});

/// The Figma styles of [type] at each size of [lineHeights], once per
/// weight name in [weights].
List<_FigmaStyle> _styles(
  String type,
  Map<int, int> lineHeights,
  String family,
  Map<String, (StratumTextStyle, FontWeight)> weights,
) => [
  for (final MapEntry(key: size, value: lineHeight) in lineHeights.entries)
    for (final MapEntry(key: weightName, value: (recipe, weight))
        in weights.entries)
      (
        name: '$type/$size $weightName',
        recipe: _at(recipe, size),
        size: size,
        lineHeight: lineHeight,
        family: family,
        weight: weight,
      ),
];

final _figma = <_FigmaStyle>[
  ..._styles('header', _header, 'Inter', {
    'semibold': (StratumTextStyle.header, FontWeight.w600),
  }),
  ..._styles('paragraph', _paragraph, 'Inter', {
    'regular': (StratumTextStyle.paragraph, FontWeight.w400),
    'semibold': (StratumTextStyle.paragraph.semiBold, FontWeight.w600),
  }),
  ..._styles('body', _body, 'Inter', {
    'regular': (StratumTextStyle.body, FontWeight.w400),
    'medium': (StratumTextStyle.body.medium, FontWeight.w500),
    'semibold': (StratumTextStyle.body.semiBold, FontWeight.w600),
  }),
  ..._styles('table', _table, 'Inter', {
    'regular': (StratumTextStyle.table, FontWeight.w400),
  }),
  ..._styles('number', _number, 'Geist', {
    'semibold': (StratumTextStyle.number, FontWeight.w600),
  }),
  ..._styles(
    'number',
    {10: 16},
    'Geist Mono',
    {'mono': (StratumTextStyle.number.mono, FontWeight.w600)},
  ),
  ..._styles('code', _code, 'Roboto Mono', {
    'regular': (StratumTextStyle.code, FontWeight.w400),
  }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StratumThemeData theme;

  setUpAll(() async {
    final text = await rootBundle.loadString(
      'assets/themes/default/theme.yaml',
    );
    final document = loadYaml(text) as YamlMap;
    theme = fakeStratumTheme(
      typography: StratumTypography.fromYaml(document['typography'] as YamlMap),
    );
  });

  TextStyle resolve(StratumTextStyle recipe) => TypographyResolver.resolve(
    recipe,
    theme: theme,
    locale: const Locale('en'),
    windowSize: WindowSize.mobile,
    textScaler: TextScaler.noScaling,
  );

  test('covers the 45 Figma text styles', () {
    expect(_figma, hasLength(45));
  });

  for (final style in _figma) {
    test('${style.name} matches Figma at scale 1 on mobile', () {
      final resolved = resolve(style.recipe);
      final loaded = GoogleFontWeights.of(theme.typography)[style.family]!;

      expect(resolved.fontSize, style.size);
      expect(
        resolved.height! * resolved.fontSize!,
        closeTo(style.lineHeight, 1e-9),
      );
      expect(resolved.fontFamily, style.family);
      // The Figma weight, snapped into the weights the package default
      // loads the family in: body medium (500) draws Inter 600 (FO-02
      // US-08 FR-02 E04).
      expect(resolved.fontWeight, GoogleFontWeights.snap(style.weight, loaded));
    });
  }

  test('table draws tabular figures on the body font', () {
    expect(resolve(StratumTextStyle.table.s14).fontFeatures, [
      const FontFeature.tabularFigures(),
    ]);
  });

  test('a laid-out line of each type is as tall as Figma says', () {
    final samples = {
      'header/24': (StratumTextStyle.header.s24, 34.0),
      'paragraph/16': (StratumTextStyle.paragraph.s16, 26.0),
      'body/12': (StratumTextStyle.body.s12, 16.0),
      'table/18': (StratumTextStyle.table.s18, 28.0),
      'number/36': (StratumTextStyle.number.s36, 48.0),
      'code/14': (StratumTextStyle.code.s14, 24.0),
    };
    for (final MapEntry(key: name, value: (recipe, lineHeight))
        in samples.entries) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag ปู่', style: resolve(recipe)),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);

      expect(
        painter.computeLineMetrics().single.height,
        closeTo(lineHeight, 0.01),
        reason: name,
      );
    }
  });
}
