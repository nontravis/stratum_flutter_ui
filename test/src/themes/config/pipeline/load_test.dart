import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';

import '../theme_fixtures.dart';

/// Runs stage 1 on the base fixture and [layers].
(List<YamlMap>, ThemeErrors) _load(List<String> layers) {
  final all = sources(layers);
  final errors = errorsFor(all);
  return (loadThemes(all, errors), errors);
}

void main() {
  test('returns the root map of every file when all of them load', () {
    final (roots, errors) = _load([layer('name: ocean')]);

    expect(problems(errors), isEmpty);
    expect(roots, hasLength(2));
    expect(roots.last['name'], 'ocean');
  });

  test('reports a syntax error in each of two files, a duplicate key '
      'included, with the position of each', () {
    final (_, errors) = _load([
      layer('space:\n\tmd: 16'),
      layer('name: a\nname: b'),
    ]);

    expect(errors.sorted, const [
      StratumThemeFormatError(
        code: StratumThemeErrorCode.yamlSyntax,
        source: 'layer1',
        path: '',
        message: 'Tab characters are not allowed as indentation.',
        line: 3,
        column: 1,
      ),
      StratumThemeFormatError(
        code: StratumThemeErrorCode.yamlSyntax,
        source: 'layer2',
        path: '',
        message: 'Duplicate mapping key.',
        line: 3,
        column: 1,
      ),
    ]);
  });

  test('reports a list root and an empty file as expected_map at the root; '
      'the empty file has no position', () {
    final (_, errors) = _load(['- a\n- b', '']);

    expect(errors.sorted, const [
      StratumThemeFormatError(
        code: StratumThemeErrorCode.expectedMap,
        source: 'layer1',
        path: '',
        message: 'expected a map, got [a, b]',
        line: 1,
        column: 1,
      ),
      StratumThemeFormatError(
        code: StratumThemeErrorCode.expectedMap,
        source: 'layer2',
        path: '',
        message: 'expected a map, got null',
      ),
    ]);
  });

  group(r'$schema', () {
    final cases = <(String, String, StratumThemeErrorCode, String, int?)>[
      (
        'absent',
        'name: ocean',
        StratumThemeErrorCode.required,
        'required',
        null,
      ),
      (
        'a number',
        r'$schema: 1',
        StratumThemeErrorCode.expectedString,
        'expected a string, got 1',
        10,
      ),
      (
        'without the v',
        r'$schema: stratum-theme/1.0.0',
        StratumThemeErrorCode.unsupportedSchema,
        'expected "stratum-theme/v<major>.<minor>.<patch>", '
            'got "stratum-theme/1.0.0"',
        10,
      ),
      (
        'without the name',
        r'$schema: v1.0',
        StratumThemeErrorCode.unsupportedSchema,
        'expected "stratum-theme/v<major>.<minor>.<patch>", got "v1.0"',
        10,
      ),
      (
        'a newer minor',
        r'$schema: stratum-theme/v1.2.0',
        StratumThemeErrorCode.unsupportedSchema,
        'theme needs stratum-theme v1.2; this app reads up to v1.1',
        10,
      ),
      (
        'another major',
        r'$schema: stratum-theme/v2.0.0',
        StratumThemeErrorCode.unsupportedSchema,
        'theme needs stratum-theme v2.0; this app reads up to v1.1',
        10,
      ),
    ];
    for (final (name, yaml, code, message, column) in cases) {
      test('reports $name', () {
        final (_, errors) = _load([yaml]);

        expect(errors.sorted, [
          StratumThemeFormatError(
            code: code,
            source: 'layer1',
            path: r'$schema',
            message: message,
            line: column == null ? null : 1,
            column: column,
          ),
        ]);
      });
    }

    test('accepts a newer patch', () {
      final (roots, errors) = _load([r'$schema: stratum-theme/v1.0.7']);

      expect(problems(errors), isEmpty);
      expect(roots, hasLength(2));
    });

    test('fo01/us01/fr01/e08: accepts every v1.0 and v1.1 patch', () {
      for (final version in ['v1.0.0', 'v1.0.7', 'v1.1.0', 'v1.1.4']) {
        final (roots, errors) = _load(['\$schema: stratum-theme/$version']);

        expect(problems(errors), isEmpty, reason: version);
        expect(roots, hasLength(2), reason: version);
      }
    });
  });
}
