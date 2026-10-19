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

  group('ThemeReader.dimension', () {
    /// The value `dimension` reads from [value] at the path `a`, and each
    /// error it reports, as `path: message`.
    (StratumDimension?, List<String>) read(
      Object? value, {
      required bool percent,
      bool required = false,
    }) {
      final errors = ThemeErrors(['theme']);
      final dimension = ThemeReader(
        errors,
        {},
      ).dimension(value, 'a', percent: percent, required: required);
      return (dimension, [for (final error in errors.sorted) '$error']);
    }

    for (final (value, percent, expected) in <(Object?, bool, String)>[
      ('8px', false, 'a: expected a number or "N%", got "8px"'),
      (
        '50%',
        false,
        'a: expected a number, got "50%"; a percent is allowed only in '
            'layouts',
      ),
      (
        '20000%',
        false,
        'a: expected a number, got "20000%"; a percent is allowed only in '
            'layouts',
      ),
      (10001, false, 'a: expected a number from -10000 to 10000, got 10001'),
      (
        '-10001%',
        true,
        'a: expected a number or "N%" from -10000 to 10000, got "-10001%"',
      ),
      (
        double.infinity,
        true,
        'a: expected a number or "N%" from -10000 to 10000, got Infinity',
      ),
    ]) {
      test('fo01/us01/fr01/e16, fo02/us07/fr02/e16: $value with percent '
          '$percent: not a number or "N%" first, then a percent where none '
          'is allowed, then the bound', () {
        final (dimension, errors) = read(value, percent: percent);

        expect(dimension, isNull);
        expect(errors, [expected]);
      });
    }

    for (final (value, percent, expected)
        in <(Object?, bool, StratumDimension)>[
          (-10000, false, const StratumDimension.fixed(-10000)),
          ('10000%', true, const StratumDimension.percent(100)),
          ('-12.5%', true, const StratumDimension.percent(-0.125)),
        ]) {
      test('fo01/us01/fr01/e16, fo02/us07/fr01: $value at or within the '
          'bound reads, negatives included', () {
        final (dimension, errors) = read(value, percent: percent);

        expect(dimension, expected);
        expect(errors, isEmpty);
      });
    }

    test('a null value reports required only when required is set', () {
      expect(read(null, percent: true, required: true).$2, ['a: required']);
      expect(read(null, percent: true).$2, isEmpty);
    });
  });
}
