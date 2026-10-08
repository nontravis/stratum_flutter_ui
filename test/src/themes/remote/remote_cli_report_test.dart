import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/remote/remote_cli_report.dart';
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

Future<RemoteInstallCheck> _check(StratumRemoteTheme theme) =>
    checkRemoteInstall(
      theme,
      packageDefault: remotePackageDefault,
      parseValues: _inline,
      nextGeneration: () => 1,
    );

void main() {
  group('us02/fr03: the CLI report', () {
    test('us02/fr03/e07: the defaults line names the package default, and '
        'the app default when one was read', () {
      expect(
        cliDefaultsLine(packageDefault: '/p/theme.yaml'),
        'defaults: /p/theme.yaml (package)',
      );
      expect(
        cliDefaultsLine(packageDefault: '/p/theme.yaml', appDefault: '/a.yaml'),
        'defaults: /p/theme.yaml (package), /a.yaml (app)',
      );
    });

    test('us02/fr03/e03: theme_format gives one line per problem of its '
        'FO-01 report, each with its code', () async {
      try {
        await _check(remoteTheme('brand', body: 'space:\n  a: 1\n  b: 2'));
        fail('the zip passed');
      } on StratumRemoteThemeException catch (error) {
        final lines = cliProblemLines(error);

        expect(lines, hasLength(2));
        for (final line in lines) {
          expect(line, startsWith('theme_format: brand@1:'));
          expect(line, endsWith('[unknown_key]'));
        }
      }
    });

    test('us02/fr03: another failure gives one line, its code and its '
        'message', () {
      const error = StratumRemoteThemeException(
        code: StratumRemoteThemeErrorCode.missingEntry,
        id: 'brand',
        message: 'the theme file names "a.svg", which the zip lacks',
        path: 'a.svg',
      );

      expect(cliProblemLines(error), [
        'missing_entry: the theme file names "a.svg", which the zip lacks',
      ]);
    });

    test('us02/s5, us02/s6, us02/fr03/e05, us02/fr03/e06, us02/fr02/e08, '
        'minor6, d-h: unnamed files and case twins are warnings; the install '
        'accepts the zip', () async {
      final check = await _check(
        remoteTheme(
          'brand',
          files: {
            'Logo.svg': [1],
            'logo.svg': [2],
          },
        ),
      );

      const notNamed = 'is in the zip, but the theme file does not name it';
      expect(cliWarnings(check), [
        'warning: "Logo.svg" $notNamed',
        'warning: "logo.svg" $notNamed',
        'warning: "Logo.svg" and "logo.svg" differ only in letter case',
      ]);
    });

    test('us02/fr03/e05: a file the theme names, and theme.yaml, are no '
        'warning', () async {
      final check = await _check(
        remoteTheme(
          'brand',
          body: 'assets:\n  loading: images/a.svg',
          files: {
            'images/a.svg': [1],
          },
        ),
      );

      expect(cliWarnings(check), isEmpty);
    });

    test('d-h: twinNames pairs names equal when letter case is ignored, '
        'each pair once', () {
      expect(twinNames(['A', 'a', 'b']), [('A', 'a')]);
      expect(twinNames(['A', 'B', 'a', 'b']), [('A', 'a'), ('B', 'b')]);
      expect(twinNames(['a', 'b']), isEmpty);
    });

    test('us02/fr03/e06, r15, sec f3: three case variants of one name give '
        'the two neighbor pairs, in name order', () {
      expect(twinNames(['AB', 'Ab', 'ab']), [('AB', 'Ab'), ('Ab', 'ab')]);
    });

    test('us02/fr03/e06, r15, sec f3: n case variants of one name give '
        'n - 1 pairs, so the output grows linearly', () {
      final names = [
        for (var bits = 0; bits < 200; bits++)
          String.fromCharCodes([
            for (var i = 0; i < 8; i++)
              if ((bits >> i).isOdd) 0x41 else 0x61,
          ]),
      ]..sort();

      expect(twinNames(names), hasLength(199));
    });

    test('sec f2: a long s and a plain s are twins', () {
      expect(twinNames(['ſ', 's']), [('ſ', 's')]);
    });

    test('edge: Theme.yaml beside theme.yaml is both an unnamed file and '
        'a twin', () async {
      final check = await _check(
        remoteTheme(
          'brand',
          files: {
            'Theme.yaml': [1],
          },
        ),
      );

      const notNamed = 'is in the zip, but the theme file does not name it';
      expect(cliWarnings(check), [
        'warning: "Theme.yaml" $notNamed',
        'warning: "Theme.yaml" and "theme.yaml" differ only in letter case',
      ]);
    });

    test('d4, sec f4: hostile zip-supplied names and yaml text reach the '
        'CLI escaped', () async {
      final check = await _check(
        remoteTheme(
          'brand',
          files: {
            'a\u202Ebé.svg': [1],
            'A\u202EBé.svg': [2],
          },
        ),
      );
      for (final line in cliWarnings(check)) {
        expect(line.codeUnits.every((u) => u >= 0x20 && u <= 0x7E), isTrue);
      }

      try {
        await _check(
          remoteTheme(
            'brand',
            body: 'space:\n  "a\\e[2J\\nforged: x [unknown_key]": 1\n  b: 2',
          ),
        );
        fail('the zip passed');
      } on StratumRemoteThemeException catch (error) {
        final lines = cliProblemLines(error);

        expect(lines, hasLength(error.formatException!.errors.length));
        for (final line in lines) {
          expect(line.codeUnits.every((u) => u >= 0x20 && u <= 0x7E), isTrue);
        }
      }
    });

    test('us02/s14, us02/fr03/e13, r15: every entry the install never reads '
        'is a warning, by its zip path, in name order', () async {
      final bytes = buildZip([
        ZipEntryFixture('brand/', const [], deflate: false),
        ZipEntryFixture('brand/theme.yaml', utf8.encode('$remoteSchemaLine\n')),
        ZipEntryFixture('README.html', [1]),
        ZipEntryFixture('__MACOSX/brand/._theme.yaml', [2]),
        ZipEntryFixture('brand/.DS_Store', [3]),
      ]);
      final check = await _check(
        StratumRemoteTheme(
          id: 'brand',
          bytes: bytes,
          checksum: checksumOf(bytes),
        ),
      );

      const unread = 'is in the zip, but the app install never reads it';
      expect(cliWarnings(check), [
        'warning: "README.html" $unread',
        'warning: "__MACOSX/brand/._theme.yaml" $unread',
        'warning: "brand/.DS_Store" $unread',
      ]);
    });

    test('minor6 edge, us02/fr03/e13: an unread entry is never also an '
        'unnamed-file warning', () async {
      final bytes = buildZip([
        ZipEntryFixture('brand/', const [], deflate: false),
        ZipEntryFixture('brand/theme.yaml', utf8.encode('$remoteSchemaLine\n')),
        ZipEntryFixture('README.html', [1]),
      ]);
      final check = await _check(
        StratumRemoteTheme(
          id: 'brand',
          bytes: bytes,
          checksum: checksumOf(bytes),
        ),
      );

      const unread = 'is in the zip, but the app install never reads it';
      expect(cliWarnings(check), ['warning: "README.html" $unread']);
    });

    test('minor6 edge, us02/fr03/e13: _unreadWarning escapes a non-ASCII '
        'letter and a quote in the path', () async {
      final bytes = buildZip([
        ZipEntryFixture('brand/', const [], deflate: false),
        ZipEntryFixture('brand/theme.yaml', utf8.encode('$remoteSchemaLine\n')),
        ZipEntryFixture('a"é.html', [1]),
      ]);
      final check = await _check(
        StratumRemoteTheme(
          id: 'brand',
          bytes: bytes,
          checksum: checksumOf(bytes),
        ),
      );

      const unread = 'is in the zip, but the app install never reads it';
      expect(cliWarnings(check), ['warning: "a\\u0022\\u00e9.html" $unread']);
    });

    test('us02/fr03/e06, rz4, r19 (t28): twin names whose case differs only '
        'past the cut print distinct ids', () async {
      final check = await _check(
        remoteTheme(
          'brand',
          files: {
            '${'b' * 200}X.png': [1],
            '${'b' * 200}x.png': [2],
          },
        ),
      );
      final twin = cliWarnings(check)
          .singleWhere((line) => line.contains('differ only in letter case'));
      final ids = [
        for (final match in RegExp(r'id ([0-9a-f]{32})\]').allMatches(twin))
          match[1],
      ];

      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2));
    });
  });
}
