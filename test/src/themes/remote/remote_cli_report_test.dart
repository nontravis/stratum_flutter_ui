import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/remote/remote_cli_report.dart';
import 'package:stratum_ui/src/themes/remote/remote_install_check.dart';

import 'remote_fakes.dart';

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

    test('sec f3 note: three case variants of one name give all three '
        'pairs, in first-occurrence order', () {
      expect(twinNames(['AB', 'Ab', 'ab']), [
        ('AB', 'Ab'),
        ('AB', 'ab'),
        ('Ab', 'ab'),
      ]);
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
  });
}
