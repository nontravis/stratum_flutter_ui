import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_installer.dart';

import 'remote_fakes.dart';
import 'remote_test_zip.dart';

Future<RemoteInstall> _prepare(StratumRemoteTheme theme) =>
    RemoteThemeInstaller.prepare(theme, packageDefault: remotePackageDefault);

Matcher _fails(StratumRemoteThemeErrorCode code) => throwsA(
  isA<StratumRemoteThemeException>().having((e) => e.code, 'code', code),
);

const _fontBody = '''
typography:
  fonts:
    brand: { family: Prompt, files: [fonts/Prompt-Regular.ttf] }''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    useSyncParse();
    recordRemoteFontLoads();
  });

  test(
    'fo04/us01/s1: a good zip parses over default under its generation',
    () async {
      final install = await _prepare(
        remoteTheme(
          'brand',
          body: _fontBody,
          files: {
            'fonts/Prompt-Regular.ttf': [1, 2, 3],
          },
        ),
      );

      expect(install.generation, 1);
      expect(install.folder, 'stratum-remote/brand/1');
      expect(install.sourceId, 'brand@1');
      expect(
        install.config.typography.fonts['brand']!.family,
        'brand@1/Prompt',
      );
      expect(install.config.typography.fonts['brand']!.files, [
        'stratum-remote/brand/1/fonts/Prompt-Regular.ttf',
      ]);
      expect(
        install.entries.keys,
        containsAll(<String>['theme.yaml', 'fonts/Prompt-Regular.ttf']),
      );
    },
  );

  test(
    'fo04/us01/fr03/e03, fo03/us05/fr01/e03: each install of an id takes the '
    'next generation, and its font family carries it',
    () async {
      await _prepare(remoteTheme('brand'));
      final second = await _prepare(remoteTheme('brand'));
      final other = await _prepare(remoteTheme('night'));

      expect(second.generation, 2);
      expect(second.sourceId, 'brand@2');
      expect(other.generation, 1);
    },
  );

  test('fo04/us01/fr01: a bad id and a bad checksum text give invalid_id '
      'first', () {
    final theme = remoteTheme('brand');
    expect(
      _prepare(
        StratumRemoteTheme(id: 'Brand', bytes: theme.bytes, checksum: 'x'),
      ),
      _fails(StratumRemoteThemeErrorCode.invalidId),
    );
  });

  test('fo04/us01/fr01: a bad checksum text over bytes that would mismatch '
      'gives invalid_checksum first', () {
    expect(
      _prepare(
        StratumRemoteTheme(
          id: 'brand',
          bytes: Uint8List.fromList([1]),
          checksum: 'sha256:xyz',
        ),
      ),
      _fails(StratumRemoteThemeErrorCode.invalidChecksum),
    );
  });

  test('fo04/us01/fr01: a mismatch over bytes that are no zip gives '
      'checksum_mismatch first, before any entry is read', () {
    final junk = Uint8List.fromList(utf8.encode('not a zip'));
    expect(
      _prepare(
        StratumRemoteTheme(id: 'brand', bytes: junk, checksum: checksumOf([0])),
      ),
      _fails(StratumRemoteThemeErrorCode.checksumMismatch),
    );
  });

  test('fo04/us01/s11, fo04/us01/fr01/e02: default is invalid_id', () {
    expect(
      _prepare(remoteTheme('default')),
      _fails(StratumRemoteThemeErrorCode.invalidId),
    );
  });

  test('fo04/us01/fr01/e03: a bad checksum text is invalid_checksum', () {
    final theme = remoteTheme('brand');
    expect(
      _prepare(
        StratumRemoteTheme(
          id: 'brand',
          bytes: theme.bytes,
          checksum: 'md5:abc',
        ),
      ),
      _fails(StratumRemoteThemeErrorCode.invalidChecksum),
    );
  });

  test('fo04/us01/s4, fo04/us01/fr01/e01: a mismatch is checksum_mismatch', () {
    final theme = remoteTheme('brand');
    expect(
      _prepare(
        StratumRemoteTheme(
          id: 'brand',
          bytes: theme.bytes,
          checksum: checksumOf(utf8.encode('x')),
        ),
      ),
      _fails(StratumRemoteThemeErrorCode.checksumMismatch),
    );
  });

  test(
    'fo04/us01/s12: a zip past maxBytes is archive_too_large with the size',
    () {
      expect(
        _prepare(
          remoteTheme(
            'brand',
            files: {'a.bin': List.filled(5000, 0)},
            maxBytes: 4096,
          ),
        ),
        throwsA(
          isA<StratumRemoteThemeException>()
              .having(
                (e) => e.code,
                'code',
                StratumRemoteThemeErrorCode.archiveTooLarge,
              )
              .having((e) => e.measured, 'measured', isNotNull),
        ),
      );
    },
  );

  test('fo04/us01/s6, fo04/us01/fr03/e01: a theme file with problems is theme_format '
      'wrapping the FO-01 report', () async {
    await expectLater(
      _prepare(remoteTheme('brand', body: 'spcae:\n  md: 12')),
      throwsA(
        isA<StratumRemoteThemeException>()
            .having(
              (e) => e.code,
              'code',
              StratumRemoteThemeErrorCode.themeFormat,
            )
            .having((e) => e.formatException?.errors, 'errors', isNotEmpty),
      ),
    );
  });

  test('fo04/us01/s13, fo04/us01/fr03/e09: a named font file the zip lacks is '
      'missing_entry with the path', () {
    expect(
      _prepare(remoteTheme('brand', body: _fontBody)),
      throwsA(
        isA<StratumRemoteThemeException>()
            .having(
              (e) => e.code,
              'code',
              StratumRemoteThemeErrorCode.missingEntry,
            )
            .having((e) => e.path, 'path', 'fonts/Prompt-Regular.ttf'),
      ),
    );
  });

  test('fo04/us01/fr03/e09: a named asset slot file the zip lacks is '
      'missing_entry with the path', () {
    expect(
      _prepare(
        remoteTheme('brand', body: 'assets:\n  loading: images/loading.png'),
      ),
      throwsA(
        isA<StratumRemoteThemeException>()
            .having(
              (e) => e.code,
              'code',
              StratumRemoteThemeErrorCode.missingEntry,
            )
            .having((e) => e.path, 'path', 'images/loading.png'),
      ),
    );
  });

  test('I2: a local-only encrypted zip is invalid_archive and leaves the '
      'app buffer unchanged', () async {
    final bytes = localOnlyEncryptedZip(
      utf8.encode('$remoteSchemaLine\nname: brand\n'),
    );
    final before = Uint8List.fromList(bytes);

    await expectLater(
      _prepare(
        StratumRemoteTheme(
          id: 'brand',
          bytes: bytes,
          checksum: checksumOf(bytes),
        ),
      ),
      _fails(StratumRemoteThemeErrorCode.invalidArchive),
    );
    expect(bytes, before);
  });

  test('M6: a missing_entry path reaches the message escaped and the path '
      'raw', () async {
    await expectLater(
      _prepare(
        remoteTheme('brand', body: 'assets:\n  loading: "images/\\e\\n.png"'),
      ),
      throwsA(
        isA<StratumRemoteThemeException>()
            .having(
              (e) => e.code,
              'code',
              StratumRemoteThemeErrorCode.missingEntry,
            )
            .having((e) => e.path, 'path', 'images/\u001b\n.png')
            .having(
              (e) => e.toString(),
              'toString',
              allOf(
                contains(r'images/\u001b\u000a.png'),
                isNot(contains('\u001b')),
                isNot(contains('\n')),
              ),
            ),
      ),
    );
  });

  test(
    'fo04/us01/s10: a one-folder zip resolves fonts and assets against it',
    () async {
      final install = await _prepare(
        remoteTheme(
          'brand',
          folder: 'brand',
          body: 'assets:\n  loading: images/loading.png',
          files: {
            'images/loading.png': [1],
          },
        ),
      );

      expect(
        install.config.assets['loading']!.path,
        'stratum-remote/brand/1/images/loading.png',
      );
    },
  );

  test('fo04/us01/s7, fo04/us01/fr03/e10: a Google font in a zip parses as a bundled '
      'theme does', () async {
    recordRemoteGoogleFonts();
    final install = await _prepare(
      remoteTheme(
        'brand',
        body: 'typography:\n  fonts:\n    brand: { family: Google/Prompt }',
      ),
    );

    expect(
      install.config.typography.fonts['brand']!.source,
      StratumFontSource.google,
    );
  });
}
