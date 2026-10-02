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
}
