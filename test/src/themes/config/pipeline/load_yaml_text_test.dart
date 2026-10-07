import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load_yaml_text.dart';

void main() {
  group('sec f1, us02/fr03/e09: loadYamlText turns every package:yaml '
      'failure into one escaped YamlTextFailure', () {
    test('a YamlException carries the 1-based line and column of its '
        'span', () {
      YamlTextFailure failure() {
        try {
          loadYamlText('x: [1, 2');
        } on YamlTextFailure catch (error) {
          return error;
        }
        fail('loadYamlText did not throw');
      }

      final error = failure();

      expect(error.message, contains('expected'));
      expect(error.at, (line: 1, column: 9));
    });

    test('x: !<%ZZ> y, a malformed percent escape, is the fixed message '
        'with no position', () {
      YamlTextFailure failure() {
        try {
          loadYamlText('x: !<%ZZ> y');
        } on YamlTextFailure catch (error) {
          return error;
        }
        fail('loadYamlText did not throw');
      }

      final error = failure();

      expect(error.message, 'invalid percent escape in a tag');
      expect(error.at, isNull);
    });

    test('x: !<%FF> y, a percent escape that decodes to invalid utf-8, '
        'is a FormatException with no position', () {
      YamlTextFailure failure() {
        try {
          loadYamlText('x: !<%FF> y');
        } on YamlTextFailure catch (error) {
          return error;
        }
        fail('loadYamlText did not throw');
      }

      final error = failure();

      expect(error.message, isNot(contains('Unhandled')));
      expect(error.at, isNull);
    });

    test('x: !!foo%1B%5D0%3Bpwned%07 y, a forged escape sequence in a tag, '
        'escapes the message so it holds no code unit below U+0020', () {
      YamlTextFailure failure() {
        try {
          loadYamlText('x: !!foo%1B%5D0%3Bpwned%07 y');
        } on YamlTextFailure catch (error) {
          return error;
        }
        fail('loadYamlText did not throw');
      }

      final error = failure();

      expect(error.message.codeUnits.any((unit) => unit < 0x20), isFalse);
    });
  });
}
