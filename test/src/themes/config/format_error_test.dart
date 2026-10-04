import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';

void main() {
  const spcae = StratumThemeFormatError(
    code: StratumThemeErrorCode.unknownKey,
    source: 'ocean',
    path: 'spcae',
    message: 'unknown key "spcae"',
    line: 3,
    column: 1,
  );

  test('an error prints as <path>: <message>', () {
    expect('$spcae', 'spcae: unknown key "spcae"');
  });

  test('the exception prints each error with its source, position, path, '
      'message, and catalog key', () {
    const exception = StratumThemeFormatException([
      spcae,
      StratumThemeFormatError(
        code: StratumThemeErrorCode.required,
        source: 'ocean',
        path: 'typography.types.code',
        message: 'required',
      ),
      StratumThemeFormatError(
        code: StratumThemeErrorCode.yamlSyntax,
        source: 'base',
        path: '',
        message: 'Duplicate mapping key.',
        line: 3,
        column: 1,
      ),
    ]);

    expect(
      '$exception',
      'StratumThemeFormatException: 3 problem(s) in theme.yaml\n'
          '  ocean:3:1 spcae: unknown key "spcae" [unknown_key]\n'
          '  ocean typography.types.code: required [required]\n'
          '  base:3:1 (root): Duplicate mapping key. [yaml_syntax]',
    );
  });

  test('two errors with the same fields are equal', () {
    const same = StratumThemeFormatError(
      code: StratumThemeErrorCode.unknownKey,
      source: 'ocean',
      path: 'spcae',
      message: 'unknown key "spcae"',
      line: 3,
      column: 1,
    );

    expect(same, spcae);
    expect(same.hashCode, spcae.hashCode);
    expect(
      same,
      isNot(
        const StratumThemeFormatError(
          code: StratumThemeErrorCode.unknownKey,
          source: 'ocean',
          path: 'spcae',
          message: 'unknown key "spcae"',
        ),
      ),
    );
  });

  test('two exceptions over equal, non-identical error lists are equal', () {
    ThemeErrors buildErrors() => ThemeErrors(['ocean'])
      ..add(
        StratumThemeErrorCode.unknownKey,
        'spcae',
        'unknown key "spcae"',
        source: 0,
        at: (line: 3, column: 1),
      );
    final a = StratumThemeFormatException(buildErrors().sorted);
    final b = StratumThemeFormatException(buildErrors().sorted);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(identical(a.errors, b.errors), isFalse);
    expect(a, isNot(const StratumThemeFormatException([])));
  });

  test('each of the 25 codes has its snake_case catalog key', () {
    expect(
      {for (final code in StratumThemeErrorCode.values) code: code.key},
      {
        StratumThemeErrorCode.yamlSyntax: 'yaml_syntax',
        StratumThemeErrorCode.unsupportedSchema: 'unsupported_schema',
        StratumThemeErrorCode.required: 'required',
        StratumThemeErrorCode.expectedMap: 'expected_map',
        StratumThemeErrorCode.expectedString: 'expected_string',
        StratumThemeErrorCode.expectedDimension: 'expected_dimension',
        StratumThemeErrorCode.expectedColor: 'expected_color',
        StratumThemeErrorCode.unknownKey: 'unknown_key',
        StratumThemeErrorCode.unknownAlias: 'unknown_alias',
        StratumThemeErrorCode.aliasCycle: 'alias_cycle',
        StratumThemeErrorCode.aliasNotToken: 'alias_not_token',
        StratumThemeErrorCode.invalidAsset: 'invalid_asset',
        StratumThemeErrorCode.expectedDuration: 'expected_duration',
        StratumThemeErrorCode.expectedCurve: 'expected_curve',
        StratumThemeErrorCode.emptyFonts: 'empty_fonts',
        StratumThemeErrorCode.unknownFontKey: 'unknown_font_key',
        StratumThemeErrorCode.invalidTag: 'invalid_tag',
        StratumThemeErrorCode.duplicateTag: 'duplicate_tag',
        StratumThemeErrorCode.invalidWeight: 'invalid_weight',
        StratumThemeErrorCode.emptySizes: 'empty_sizes',
        StratumThemeErrorCode.tableBlock: 'table_block',
        StratumThemeErrorCode.missingDefaultFont: 'missing_default_font',
        StratumThemeErrorCode.unknownGoogleFont: 'unknown_google_font',
        StratumThemeErrorCode.emptyGoogleFont: 'empty_google_font',
        StratumThemeErrorCode.googleFontPackage: 'google_font_package',
      },
    );
  });
}
