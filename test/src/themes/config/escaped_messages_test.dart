import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load_yaml_text.dart'
    show yamlPropertyMessage;

import 'theme_fixtures.dart';

/// The report of [body] parsed as one layer over the fixture base.
StratumThemeFormatException _report(String body) {
  final all = sources([layer(body)]);
  try {
    StratumThemeConfig.parse(base: all.first, layers: all.skip(1).toList());
  } on StratumThemeFormatException catch (report) {
    return report;
  }
  fail('the layer parsed with no problem');
}

void main() {
  group(
    'fo01 fo01/us02/fr01/e05, minor8, r8: yaml-supplied text is escaped',
    () {
      test('a key with control and Thai characters: message and both texts '
          'escaped, the path field raw', () {
        final report = _report('space:\n  "md\\aไทย": 4');
        final error = report.errors.single;

        expect(error.code, StratumThemeErrorCode.unknownKey);
        expect(error.path, 'space.md\u0007ไทย');
        expect(error.message, r'unknown key "md\u0007\u0e44\u0e17\u0e22"');
        expect(
          error.toString(),
          r'space.md\u0007\u0e44\u0e17\u0e22: '
          r'unknown key "md\u0007\u0e44\u0e17\u0e22"',
        );
        expect(
          report.toString(),
          allOf(
            contains(r'space.md\u0007\u0e44\u0e17\u0e22: unknown key'),
            isNot(contains('\u0007')),
            isNot(contains('ไ')),
          ),
        );
      });

      test('a color value with a control character', () {
        final error = _report('palette:\n  brand:\n    500: "red\\a"')
            .errors
            .single;

        expect(
          error.message,
          r'expected "#RRGGBB" or "#RRGGBBAA", got "red\u0007"',
        );
      });

      test('a dimension value with a tab', () {
        final error = _report('space:\n  md: "8px\\t"').errors.single;

        expect(error.message, r'expected a number or "N%", got "8px\u0009"');
      });

      test('an app color name in the pairing message', () {
        final error = _report(
          'color:\n  light:\n    app:\n      "\\u00e9": "#000000"',
        ).errors.single;

        expect(
          error.message,
          r'required; color.light.app.\u00e9 has no dark '
          'value',
        );
      });

      test('an alias text', () {
        final error = _report(
          'palette:\n  brand:\n    500: "{palette.brand.\\u00e9}"',
        ).errors.single;

        expect(error.message, r'"{palette.brand.\u00e9}" names no token');
      });

      test('m1-t6 fix-1 f1, rz6 (1): a tag is refused at its "!" before the '
          'yaml package reads it, so nothing it would inject reaches the '
          'message', () {
        final report = _report('name: !!%1B%5B2J%0A%20%20forged x');
        final error = report.errors.single;

        expect(error.code, StratumThemeErrorCode.yamlSyntax);
        expect(error.message, yamlPropertyMessage);
        expect((error.line, error.column), (2, 7));
        expect(report.toString().split('\n'), hasLength(2));
      });

      test('m1-t6 fix-1 f2, rz6 (1): a malformed percent escape in a tag is '
          'yaml_syntax at its "!", with no ArgumentError path left', () {
        final error = _report('name: !<%ZZ> x').errors.single;

        expect(error.code, StratumThemeErrorCode.yamlSyntax);
        expect(error.message, yamlPropertyMessage);
      });

      test('sec f1, us02/fr03/e09: a percent escape that decodes to invalid '
          'utf-8 in a tag is one yaml_syntax error, not a thrown '
          'FormatException', () {
        final error = _report('name: !<%FF> x').errors.single;

        expect(error.code, StratumThemeErrorCode.yamlSyntax);
        expect(error.message, isNot(contains('Unhandled')));
      });
    },
  );
}
