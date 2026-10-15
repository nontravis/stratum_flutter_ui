import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/google_font_weights.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';

StratumFontData _google(String family) =>
    StratumFontData(family: family, source: StratumFontSource.google);

/// A typography over [fonts] and [families] whose types weigh [weights].
StratumTypography _typography(
  Map<String, StratumFontData> fonts,
  Map<String, StratumFamilySet> families, {
  Map<FontType, FontWeight> weights = const {
    FontType.header: FontWeight.w600,
    FontType.paragraph: FontWeight.w400,
    FontType.number: FontWeight.w600,
    FontType.code: FontWeight.w400,
    FontType.body: FontWeight.w400,
  },
}) => StratumTypography(
  fonts: fonts,
  families: families,
  types: {
    for (final MapEntry(key: type, value: weight) in weights.entries)
      type: StratumTypeStyle(weight: weight, sizes: const {}),
  },
);

void main() {
  group('fo02/us08/fr02, s03/inv13: GoogleFontWeights.of', () {
    test('the package default loads Inter, Roboto Mono, and Kanit in 400 '
        'and 600, Geist and Geist Mono in 600', () {
      expect(GoogleFontWeights.of(defaultThemeSet.light.typography), {
        'Inter': {FontWeight.w400, FontWeight.w600},
        'Geist': {FontWeight.w600},
        'Geist Mono': {FontWeight.w600},
        'Roboto Mono': {FontWeight.w400, FontWeight.w600},
        'Kanit': {FontWeight.w400, FontWeight.w600},
      });
    });

    test('a font a tag names for a type, as font or mono, loads in that '
        "type's weight, table taking body's", () {
      final typography = _typography(
        {
          'a': _google('A'),
          'b': _google('B'),
          'c': _google('C'),
          'body': _google('Body'),
        },
        const {
          'default': StratumFamilySet(
            types: {
              FontType.header: StratumFontRef(font: 'a'),
              FontType.paragraph: StratumFontRef(font: 'body'),
              FontType.number: StratumFontRef(font: 'body', mono: 'b'),
              FontType.code: StratumFontRef(font: 'body'),
              FontType.body: StratumFontRef(font: 'body'),
              FontType.table: StratumFontRef(font: 'c'),
            },
          ),
        },
        weights: const {
          FontType.header: FontWeight.w600,
          FontType.paragraph: FontWeight.w400,
          FontType.number: FontWeight.w500,
          FontType.code: FontWeight.w400,
          FontType.body: FontWeight.w300,
        },
      );

      expect(GoogleFontWeights.of(typography), {
        'A': {FontWeight.w600},
        'B': {FontWeight.w500},
        'C': {FontWeight.w300},
        'Body': {
          FontWeight.w300,
          FontWeight.w400,
          FontWeight.w500,
          FontWeight.w600,
        },
      });
    });

    test("every tag's body font and theme-wide mono load in every type's "
        'weight', () {
      final typography = _typography(
        {
          'app': const StratumFontData(family: 'App'),
          'body': _google('Body'),
          'mono': _google('Mono'),
          'thai': _google('Thai'),
        },
        const {
          'default': StratumFamilySet(
            types: {
              FontType.header: StratumFontRef(font: 'app'),
              FontType.paragraph: StratumFontRef(font: 'app'),
              FontType.number: StratumFontRef(font: 'app'),
              FontType.code: StratumFontRef(font: 'app'),
              FontType.body: StratumFontRef(font: 'body'),
              FontType.table: StratumFontRef(font: 'app'),
            },
            mono: 'mono',
          ),
          'th': StratumFamilySet(
            types: {FontType.body: StratumFontRef(font: 'thai')},
          ),
        },
      );
      final every = {FontWeight.w400, FontWeight.w600};

      expect(GoogleFontWeights.of(typography), {
        'Body': every,
        'Mono': every,
        'Thai': every,
      });
    });

    test('an app font and a theme font load in no weight', () {
      final typography = _typography(
        const {
          'app': StratumFontData(family: 'App'),
          'brand': StratumFontData(
            family: 'brand/Brand',
            source: StratumFontSource.theme,
          ),
        },
        const {
          'default': StratumFamilySet(
            types: {
              FontType.header: StratumFontRef(font: 'brand'),
              FontType.paragraph: StratumFontRef(font: 'app'),
              FontType.number: StratumFontRef(font: 'app'),
              FontType.code: StratumFontRef(font: 'app'),
              FontType.body: StratumFontRef(font: 'brand'),
              FontType.table: StratumFontRef(font: 'app'),
            },
            mono: 'app',
          ),
        },
      );

      expect(GoogleFontWeights.of(typography), isEmpty);
    });

    test('two font keys of one Google family share one weight set', () {
      final typography = _typography(
        {
          'app': const StratumFontData(family: 'App'),
          'inter': _google('Inter'),
          'inter-code': _google('Inter'),
        },
        const {
          'default': StratumFamilySet(
            types: {
              FontType.header: StratumFontRef(font: 'inter'),
              FontType.paragraph: StratumFontRef(font: 'app'),
              FontType.number: StratumFontRef(font: 'app'),
              FontType.code: StratumFontRef(font: 'inter-code'),
              FontType.body: StratumFontRef(font: 'app'),
              FontType.table: StratumFontRef(font: 'app'),
            },
          ),
        },
        weights: const {
          FontType.header: FontWeight.w600,
          FontType.paragraph: FontWeight.w400,
          FontType.number: FontWeight.w600,
          FontType.code: FontWeight.w300,
          FontType.body: FontWeight.w400,
        },
      );

      expect(GoogleFontWeights.of(typography), {
        'Inter': {FontWeight.w300, FontWeight.w600},
      });
    });

    test('a type the typography lacks adds no weight', () {
      final typography = _typography(
        {'g': _google('G')},
        const {
          'default': StratumFamilySet(
            types: {FontType.header: StratumFontRef(font: 'g')},
          ),
        },
        weights: const {FontType.body: FontWeight.w400},
      );

      expect(GoogleFontWeights.of(typography), {'G': <FontWeight>{}});
    });

    test('computed once per typography, and unmodifiable', () {
      final typography = defaultThemeSet.light.typography;
      final weights = GoogleFontWeights.of(typography);

      expect(GoogleFontWeights.of(typography), same(weights));
      expect(() => weights['Lato'] = {FontWeight.w400}, throwsUnsupportedError);
      expect(
        () => weights['Inter']!.add(FontWeight.w100),
        throwsUnsupportedError,
      );
    });
  });

  group('fo02/us08/fr02: GoogleFontWeights.snap', () {
    final loaded = {FontWeight.w400, FontWeight.w600};

    test('fo02/us08/fr02/e03: a weight in the set stays', () {
      expect(GoogleFontWeights.snap(FontWeight.w600, loaded), FontWeight.w600);
    });

    test('fo02/us08/fr02/e04: a weight outside the set takes the nearest', () {
      expect(GoogleFontWeights.snap(FontWeight.w300, loaded), FontWeight.w400);
      expect(GoogleFontWeights.snap(FontWeight.w700, loaded), FontWeight.w600);
      expect(
        GoogleFontWeights.snap(FontWeight.w900, {FontWeight.w400}),
        FontWeight.w400,
      );
    });

    test('fo02/us08/fr02/e05: a tie takes the heavier, in any set order', () {
      expect(GoogleFontWeights.snap(FontWeight.w500, loaded), FontWeight.w600);
      expect(
        GoogleFontWeights.snap(FontWeight.w500, {
          FontWeight.w600,
          FontWeight.w400,
        }),
        FontWeight.w600,
      );
    });

    test(
      'fo02/us08/fr02/e05: a weight off the hundreds snaps the same way',
      () {
        final near = {FontWeight.w400, FontWeight.w500};

        expect(
          GoogleFontWeights.snap(const FontWeight(450), near),
          FontWeight.w500,
        );
        expect(
          GoogleFontWeights.snap(const FontWeight(430), near),
          FontWeight.w400,
        );
      },
    );

    test('fo02/us08/fr02/e09: an empty set keeps the weight', () {
      expect(
        GoogleFontWeights.snap(FontWeight.w500, const {}),
        FontWeight.w500,
      );
    });
  });
}
