import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_entry_path.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

Matcher _unsafe(String path) => throwsA(
  isA<RemoteThemeFailure>()
      .having(
        (f) => f.code,
        'code',
        StratumRemoteThemeErrorCode.unsafeEntryPath,
      )
      .having((f) => f.path, 'path', path),
);

void main() {
  for (final path in [
    'theme.yaml',
    'fonts/Prompt-Regular.ttf',
    'brand/theme.yaml',
    'fonts/',
    '__MACOSX/._theme.yaml',
    '.../x',
    'a..b/.c',
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
    '/',
    'a/../b.png',
    'a/./b.png',
    'theme/../x',
    './theme.yaml',
    'a//b',
    'fonts//',
    'a/..',
    r'a\b',
  ]) {
    test('us01/fr02/e01: "$path" is unsafe_entry_path with the path', () {
      expect(() => checkEntryPath(path), _unsafe(path));
    });
  }

  for (final unit in [0x00, 0x09, 0x0A, 0x0D, 0x1B, 0x1F, 0x7F]) {
    final hex = unit.toRadixString(16).padLeft(4, '0');
    final path = 'images/a${String.fromCharCode(unit)}b.png';
    test('us01/s15, us01/fr02/e14, r15: U+$hex in a path is '
        'unsafe_entry_path with the path', () {
      expect(() => checkEntryPath(path), _unsafe(path));
    });
  }

  test('us01/fr02/e14, r15: printable and non-ASCII text stays safe, a C1 '
      'control and a format character included', () {
    for (final path in [
      'images/a b.png',
      'images/~.png',
      'images/é.png',
      'images/a\u0080b.png',
      'images/a\u202Eb.png',
      'fonts/ไทย.ttf',
    ]) {
      expect(() => checkEntryPath(path), returnsNormally, reason: path);
    }
  });

  for (final type in [0, 0x8000, 0x4000]) {
    test('us01/fr02: file type 0x${type.toRadixString(16)} is safe', () {
      expect(
        () => checkEntryFileType('a', externalAttributes: (type | 0x1A4) << 16),
        returnsNormally,
      );
    });
  }

  for (final type in [0xA000, 0x1000, 0x2000, 0x6000, 0xC000]) {
    test('us01/fr02/e01: file type 0x${type.toRadixString(16)} is '
        'unsafe_entry_path, whatever host', () {
      expect(
        () => checkEntryFileType(
          'link',
          externalAttributes: (type | 0x1FF) << 16,
        ),
        _unsafe('link'),
      );
    });
  }

  test('us01/fr02: the low attribute half never counts as a file type', () {
    expect(
      () => checkEntryFileType('a', externalAttributes: 0x400),
      returnsNormally,
    );
  });

  test('M6: an unsafe path reaches the message escaped and cut', () {
    final path = '\u001b[31m\n"\\${'é' * 300}/../x';

    expect(
      () => checkEntryPath(path),
      throwsA(
        isA<RemoteThemeFailure>()
            .having((f) => f.path, 'path', path)
            .having(
              (f) => f.message,
              'message',
              allOf(
                contains(r'\u001b[31m\u000a\u0022\u005c\u00e9'),
                contains('...'),
                isNot(contains('\u00e9')),
                isNot(contains('\n')),
              ),
            )
            .having((f) => f.message.length, 'message length', lessThan(260)),
      ),
    );
  });
}
