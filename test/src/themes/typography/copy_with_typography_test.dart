import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('n1/q8: the typography models are freezed', () {
    test('StratumDimension cases gain copyWith and keep resolve and text', () {
      const fixed = StratumDimension.fixed(8);
      const percent = StratumDimension.percent(0.5);

      expect(
        (fixed as FixedDimension).copyWith(px: 4),
        const FixedDimension(4),
      );
      expect(
        (percent as PercentDimension).copyWith(ratio: 0.25).resolve(of: 40),
        10,
      );
      expect(fixed.toString(), 'StratumDimension.fixed(8.0)');
      expect(percent.toString(), 'StratumDimension.percent(0.5)');
      expect(StratumDimension.parse('50%'), const PercentDimension(0.5));
    });

    test(
      'fo02/us01/fr02: StratumFontRef and StratumSizeMetrics gain copyWith',
      () {
        const ref = StratumFontRef(font: 'body');
        const metrics = StratumSizeMetrics(
          spaceHeight: StratumDimension.fixed(8),
        );

        expect(
          ref.copyWith(mono: 'code'),
          const StratumFontRef(font: 'body', mono: 'code'),
        );
        expect(ref.toString(), 'StratumFontRef(font: body, mono: null)');
        expect(metrics.letterSpacing, const StratumDimension.fixed(0));
        expect(
          metrics.copyWith(letterSpacing: const StratumDimension.fixed(1)),
          const StratumSizeMetrics(
            spaceHeight: StratumDimension.fixed(8),
            letterSpacing: StratumDimension.fixed(1),
          ),
        );
      },
    );

    test('the map holders refuse changes and gain copyWith', () {
      const families = StratumFamilySet(
        types: {FontType.body: StratumFontRef(font: 'body')},
      );
      const style = StratumTypeStyle(
        weight: FontWeight.w700,
        sizes: {
          FontSize.s16: StratumSizeMetrics(
            spaceHeight: StratumDimension.fixed(8),
          ),
        },
      );
      const typography = StratumTypography(
        fonts: {},
        families: {'default': families},
        types: {FontType.body: style},
      );

      expect(
        () => families.types[FontType.code] = const StratumFontRef(font: 'x'),
        throwsUnsupportedError,
      );
      expect(() => style.sizes.clear(), throwsUnsupportedError);
      expect(() => typography.types.clear(), throwsUnsupportedError);
      expect(style.copyWith(weight: FontWeight.w400).weight, FontWeight.w400);
      expect(typography.scaleByWindowSize, isNull);
      expect(
        families.toString(),
        'StratumFamilySet(types: {FontType.body: '
        'StratumFontRef(font: body, mono: null)}, mono: null)',
      );
    });
  });
}
