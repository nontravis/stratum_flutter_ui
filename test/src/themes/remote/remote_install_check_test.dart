import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/remote/remote_install_check.dart';

import 'remote_fakes.dart';
import 'remote_test_zip.dart';

Future<PlainThemeConfig> _inline(
  StratumThemeSource base,
  List<StratumThemeSource> layers,
) async => parseThemeValues(
  base: base,
  layers: layers,
  googleFontExists: (name) => true,
);

void main() {
  group('s2, r2: checkRemoteInstall runs install steps 1 to 10', () {
    test('a good zip gives plain values, its entries, and the files its '
        'theme names', () async {
      var generations = 0;

      final result = await checkRemoteInstall(
        remoteTheme(
          'brand',
          body: 'assets:\n  loading: images/a.svg',
          files: {
            'images/a.svg': [1],
            'notes.txt': [2],
          },
        ),
        packageDefault: remotePackageDefault,
        parseValues: _inline,
        nextGeneration: () => ++generations,
      );

      expect(generations, 1);
      expect(result.folder, 'stratum-remote/brand/1');
      expect(result.sourceId, 'brand@1');
      expect(
        result.entries.keys,
        unorderedEquals(['theme.yaml', 'images/a.svg', 'notes.txt']),
      );
      expect(result.namedFiles, {'images/a.svg'});
      expect(result.values.palette.values.first, isA<int>());
    });

    test(
      'fo04/us01/fr01/e01: a checksum mismatch throws before a generation is '
      'taken',
      () async {
        var generations = 0;
        final good = remoteTheme('brand');

        await expectLater(
          checkRemoteInstall(
            StratumRemoteTheme(
              id: 'brand',
              bytes: good.bytes,
              checksum: checksumOf([0]),
            ),
            packageDefault: remotePackageDefault,
            parseValues: _inline,
            nextGeneration: () => ++generations,
          ),
          throwsA(
            isA<StratumRemoteThemeException>().having(
              (error) => error.code,
              'code',
              StratumRemoteThemeErrorCode.checksumMismatch,
            ),
          ),
        );
        expect(generations, 0);
      },
    );

    test('fo04/us01/fr03/e01: a theme problem is theme_format with the source '
        '<id>@<generation>', () async {
      await expectLater(
        checkRemoteInstall(
          remoteTheme('brand', body: 'space:\n  nope: 4'),
          packageDefault: remotePackageDefault,
          parseValues: _inline,
          nextGeneration: () => 3,
        ),
        throwsA(
          isA<StratumRemoteThemeException>()
              .having(
                (error) => error.code,
                'code',
                StratumRemoteThemeErrorCode.themeFormat,
              )
              .having(
                (error) => error.formatException!.errors.single.source,
                'source',
                'brand@3',
              ),
        ),
      );
    });

    test('fo04/us01/fr03/e09: a named file the zip lacks is missing_entry with '
        'its path', () async {
      await expectLater(
        checkRemoteInstall(
          remoteTheme('brand', body: 'assets:\n  loading: images/a.svg'),
          packageDefault: remotePackageDefault,
          parseValues: _inline,
          nextGeneration: () => 1,
        ),
        throwsA(
          isA<StratumRemoteThemeException>()
              .having(
                (error) => error.code,
                'code',
                StratumRemoteThemeErrorCode.missingEntry,
              )
              .having((error) => error.path, 'path', 'images/a.svg'),
        ),
      );
    });
  });

  group('fo04/us01/fr03/e01, fo01 fo04/us01/fr01/e07, r16 (t25): hostile theme files '
      'in a zip are theme_format', () {
    /// Anchors a0 to a[depth], each a list of the one before twice, then a
    /// mapping key built from the last.
    String aliasKey(int depth) => [
      'a0: &a0 [x, x]',
      for (var d = 1; d <= depth; d++) 'a$d: &a$d [*a${d - 1}, *a${d - 1}]',
      '? *a$depth',
      ': v',
    ].join('\n');

    for (final (label, text, at) in [
      ('flow nesting 100,000 deep', '[' * 100000, (1, 65)),
      ('a mapping key built from aliases', aliasKey(18), (1, 5)),
      ('a tag whose %-escape is not UTF-8', 'x: !<%FF> y', (1, 4)),
    ]) {
      test('$label is theme_format holding yaml_syntax at the offending '
          'character', () async {
        final bytes = buildZip([
          ZipEntryFixture('theme.yaml', utf8.encode(text)),
        ]);

        await expectLater(
          checkRemoteInstall(
            StratumRemoteTheme(
              id: 'brand',
              bytes: bytes,
              checksum: checksumOf(bytes),
            ),
            packageDefault: remotePackageDefault,
            parseValues: _inline,
            nextGeneration: () => 1,
          ),
          throwsA(
            isA<StratumRemoteThemeException>()
                .having(
                  (e) => e.code,
                  'code',
                  StratumRemoteThemeErrorCode.themeFormat,
                )
                .having(
                  (e) => e.formatException!.errors
                      .where((error) => error.source == 'brand@1')
                      .map((error) => (error.code, error.line, error.column))
                      .single,
                  'zip error',
                  (StratumThemeErrorCode.yamlSyntax, at.$1, at.$2),
                ),
          ),
        );
      });
    }
  });
}
