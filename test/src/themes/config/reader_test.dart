import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';

void main() {
  group('ThemeReader length bound', () {
    test('fo01/us01/fr01/e16: the bound is 10000 logical pixels', () {
      expect(ThemeReader.maxLength, 10000);
    });

    for (final (value, fits) in <(Object?, bool)>[
      (0, true),
      (10000, true),
      (-10000, true),
      (9999.5, true),
      (10000.001, false),
      (-10001, false),
      (1e300, false),
      (double.infinity, false),
      (double.negativeInfinity, false),
      (double.nan, false),
      ('5', false),
      (null, false),
      (-9223372036854775808, false),
    ]) {
      test('fo01/us01/fr01/e16: isLength($value) is $fits', () {
        expect(ThemeReader.isLength(value), fits);
      });
    }

    for (final (dimension, fits) in <(StratumDimension, bool)>[
      (const StratumDimension.fixed(10000), true),
      (const StratumDimension.fixed(-10000.5), false),
      (const StratumDimension.percent(100), true),
      (const StratumDimension.percent(-100), true),
      (const StratumDimension.percent(100.01), false),
      (const StratumDimension.percent(double.infinity), false),
    ]) {
      test('fo01/us01/fr01/e16: fitsLength($dimension) is $fits', () {
        expect(ThemeReader.fitsLength(dimension), fits);
      });
    }

    test('fo01/us01/fr01/e16: parseLength reads a value within the bound '
        'and drops one past it or of another kind', () {
      expect(ThemeReader.parseLength(16), const StratumDimension.fixed(16));
      expect(
        ThemeReader.parseLength('50%'),
        const StratumDimension.percent(0.5),
      );
      expect(ThemeReader.parseLength(10001), isNull);
      expect(ThemeReader.parseLength('10001%'), isNull);
      expect(ThemeReader.parseLength(double.nan), isNull);
      expect(ThemeReader.parseLength('16px'), isNull);
    });
  });
}
