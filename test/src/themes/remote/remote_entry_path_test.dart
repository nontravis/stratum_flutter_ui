import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_entry_path.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

void main() {
  for (final path in [
    'theme.yaml',
    'fonts/Prompt-Regular.ttf',
    'brand/theme.yaml',
    'a/../b.png',
    'a/./b.png',
    'fonts/',
    '__MACOSX/._theme.yaml',
  ]) {
    test('us01/fr02: "$path" is safe', () {
      expect(() => checkEntryPath(path), returnsNormally);
    });
  }

  for (final path in [
    '/etc/passwd',
    r'\windows\x',
    '../theme.yaml',
    'a/../../b',
    r'a\..\..\b',
    'C:x.png',
    'c:/x.png',
    '',
  ]) {
    test('us01/fr02/e01: "$path" is unsafe_entry_path with the path', () {
      expect(
        () => checkEntryPath(path),
        throwsA(
          isA<RemoteThemeFailure>()
              .having(
                (f) => f.code,
                'code',
                StratumRemoteThemeErrorCode.unsafeEntryPath,
              )
              .having((f) => f.path, 'path', path),
        ),
      );
    });
  }

  test('us01/fr02/e01: a unix symlink entry is a symbolic link', () {
    expect(
      isSymbolicLink(versionMadeBy: 0x031E, externalAttributes: 0xA1FF << 16),
      isTrue,
    );
  });

  test('us01/fr02: a unix file and an MS-DOS entry are no symbolic link', () {
    expect(
      isSymbolicLink(versionMadeBy: 0x031E, externalAttributes: 0x81A4 << 16),
      isFalse,
    );
    expect(
      isSymbolicLink(versionMadeBy: 0x0014, externalAttributes: 0xA1FF << 16),
      isFalse,
    );
  });
}
