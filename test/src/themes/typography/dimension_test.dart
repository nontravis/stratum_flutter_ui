import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('StratumDimension.parse', () {
    test('reads an int as fixed pixels', () {
      expect(StratumDimension.parse(2), const StratumDimension.fixed(2));
    });

    test('reads a double as fixed pixels', () {
      expect(StratumDimension.parse(0.5), const StratumDimension.fixed(0.5));
    });

    test('reads "50%" as a ratio of 0.5', () {
      expect(
        StratumDimension.parse('50%'),
        const StratumDimension.percent(0.5),
      );
    });

    test('reads "-12.5%" as a ratio of -0.125', () {
      expect(
        StratumDimension.parse('-12.5%'),
        const StratumDimension.percent(-0.125),
      );
    });

    test('rejects "8px" and quotes it in the message', () {
      expect(
        () => StratumDimension.parse('8px'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'expected a number or "N%", got "8px"',
          ),
        ),
      );
    });

    test('rejects "abc"', () {
      expect(
        () => StratumDimension.parse('abc'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects null', () {
      expect(
        () => StratumDimension.parse(null),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'expected a number or "N%", got null',
          ),
        ),
      );
    });
  });

  group('StratumDimension.resolve', () {
    test('a fixed value keeps its pixels whatever the base', () {
      expect(const StratumDimension.fixed(8).resolve(of: 32), 8);
    });

    test('a percent value is that share of the base', () {
      expect(const StratumDimension.percent(0.5).resolve(of: 32), 16);
      expect(const StratumDimension.percent(-0.01).resolve(of: 34), -0.34);
    });
  });

  group('StratumDimension equality', () {
    test('the same kind and number are equal with equal hash codes', () {
      expect(
        StratumDimension.parse('50%'),
        const StratumDimension.percent(0.5),
      );
      expect(
        StratumDimension.parse('50%').hashCode,
        const StratumDimension.percent(0.5).hashCode,
      );
    });

    test('a fixed and a percent value of the same number differ', () {
      expect(
        const StratumDimension.fixed(0.5),
        isNot(const StratumDimension.percent(0.5)),
      );
    });
  });
}
