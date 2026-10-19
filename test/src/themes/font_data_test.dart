import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('qualifiedFamily is the family for an app font', () {
    expect(const StratumFontData(family: 'Inter').qualifiedFamily, 'Inter');
  });

  test('qualifiedFamily prefixes the package of a package font', () {
    expect(
      const StratumFontData(
        family: 'Inter',
        package: 'stratum_ui',
      ).qualifiedFamily,
      'packages/stratum_ui/Inter',
    );
  });

  test('adjustSize defaults to a fixed 0', () {
    expect(
      const StratumFontData(family: 'Inter').adjustSize,
      const StratumDimension.fixed(0),
    );
  });

  test('fonts with the same fields are equal with equal hash codes', () {
    const a = StratumFontData(
      family: 'Font A',
      adjustSize: StratumDimension.fixed(2),
    );
    const b = StratumFontData(
      family: 'Font A',
      adjustSize: StratumDimension.fixed(2),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const StratumFontData(family: 'Font A')));
  });

  test('fo02/us07/fr01: files take part in equality and default to none', () {
    const a = StratumFontData(
      family: 'brand/Brand',
      source: StratumFontSource.theme,
      files: ['assets/themes/brand/fonts/Brand-Regular.ttf'],
    );
    const b = StratumFontData(
      family: 'brand/Brand',
      source: StratumFontSource.theme,
      files: ['assets/themes/brand/fonts/Brand-Regular.ttf'],
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        const StratumFontData(
          family: 'brand/Brand',
          source: StratumFontSource.theme,
          files: ['assets/themes/brand/fonts/Brand-Bold.ttf'],
        ),
      ),
    );
    expect(const StratumFontData(family: 'Inter').files, isEmpty);
  });

  test('fo02/us07/fr01: qualifiedFamily of a theme font is its registered '
      'family', () {
    expect(
      const StratumFontData(
        family: 'brand/DB Heavent',
        source: StratumFontSource.theme,
        files: ['assets/themes/brand/fonts/DBHeavent-Regular.ttf'],
      ).qualifiedFamily,
      'brand/DB Heavent',
    );
  });

  group('5.2: StratumFontData as a freezed value', () {
    // Built at run time from a parameter, so the checks read `==`.
    StratumFontData font(String family) => StratumFontData(
      family: family,
      source: StratumFontSource.theme,
      files: ['fonts/$family.ttf'],
    );

    test('5.2: files compare by content', () {
      expect(font('Geist'), font('Geist'));
      expect(font('Geist').hashCode, font('Geist').hashCode);
      expect(font('Geist'), isNot(font('Inter')));
    });

    test('5.2: copyWith changes one field and keeps the rest', () {
      final copy = font('Geist').copyWith(source: StratumFontSource.app);

      expect(copy.source, StratumFontSource.app);
      expect(copy.family, 'Geist');
      expect(copy.files, ['fonts/Geist.ttf']);
      expect(copy, isNot(font('Geist')));
    });

    test('R4 Q2: its own toString stays', () {
      expect(
        const StratumFontData(family: 'Geist').toString(),
        'StratumFontData(family: Geist, package: null, adjustSize: '
        '${const StratumDimension.fixed(0)}, source: StratumFontSource.app, '
        'files: [])',
      );
    });
  });
}
