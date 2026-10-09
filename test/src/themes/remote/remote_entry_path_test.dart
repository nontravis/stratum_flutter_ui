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
    final char = String.fromCharCode(unit);
    for (final (label, path) in [
      ('the first segment', 'ima${char}ges/sub/file.png'),
      ('a middle segment', 'images/s${char}ub/file.png'),
      ('the last segment', 'images/sub/fi${char}le.png'),
      ('a segment alone', 'images/$char/file.png'),
    ]) {
      test('us01/s15, us01/fr02/e14, r15: U+$hex in $label is '
          'unsafe_entry_path with the path', () {
        expect(() => checkEntryPath(path), _unsafe(path));
      });
    }
  }

  for (final (label, path) in [
    ('an accented letter', 'images/é.png'),
    ('a C1 control', 'images/a\u0080b.png'),
    ('a format character', 'images/a\u202Eb.png'),
    ('a Thai letter', 'fonts/ไทย.ttf'),
    ('an emoji', 'images/😀.png'),
    ('a lone surrogate', 'images/a${String.fromCharCode(0xD800)}.png'),
  ]) {
    test('us01/s15, us01/fr02/e14, rz2: $label is unsafe_entry_path with '
        'the path', () {
      expect(() => checkEntryPath(path), _unsafe(path));
    });
  }

  test(r'us01/fr02/e14, rz2: every printable ASCII character but "\" and '
      '"/" passes in a segment', () {
    final segment = String.fromCharCodes([
      for (var unit = 0x20; unit <= 0x7E; unit++)
        if (unit != 0x5C && unit != 0x2F) unit,
    ]);

    expect(() => checkEntryPath('a/$segment'), returnsNormally);
  });

  for (final (path, type) in [
    ('a', 0),
    ('a', 0x8000),
    ('a/', 0),
    ('a/', 0x4000),
  ]) {
    test('us01/fr02: file type 0x${type.toRadixString(16)} on "$path" is '
        'safe', () {
      expect(
        () => checkEntryFileType(
          path,
          externalAttributes: (type | 0x1A4) << 16,
          host: 3,
        ),
        returnsNormally,
      );
    });
  }

  for (final (path, type) in [('theme.yaml', 0x4000), ('a/', 0x8000)]) {
    test('us01/fr02/e01, us01/fr02/e13, rz3, r18 (t27): file type '
        '0x${type.toRadixString(16)} on "$path" is unsafe_entry_path', () {
      expect(
        () => checkEntryFileType(
          path,
          externalAttributes: (type | 0x1ED) << 16,
          host: 3,
        ),
        _unsafe(path),
      );
    });
  }

  for (final host in [0, 3]) {
    for (final (path, attributes) in [
      ('theme.yaml', 0x10),
      ('theme.yaml', (0x81A4 << 16) | 0x10),
      ('a', 0x31),
    ]) {
      test('us01/fr02/e01, rz9 (m3-t6 security): the MS-DOS folder '
          'attribute on "$path", attributes '
          '0x${attributes.toRadixString(16)}, is unsafe_entry_path on host '
          '$host', () {
        expect(
          () => checkEntryFileType(
            path,
            externalAttributes: attributes,
            host: host,
          ),
          _unsafe(path),
        );
      });
    }
  }

  for (final (path, attributes) in [
    ('a/', 0x10),
    ('a/', (0x41ED << 16) | 0x10),
    ('a', 0x20),
    ('a', (0x81A4 << 16) | 0x01),
  ]) {
    test('us01/fr02, rz9: attributes 0x${attributes.toRadixString(16)} on '
        '"$path" are safe', () {
      expect(
        () => checkEntryFileType(path, externalAttributes: attributes, host: 3),
        returnsNormally,
      );
    });
  }

  for (final host in [0, 3]) {
    for (final (tool, path, attributes) in [
      ('none', 'a', 0),
      ('Finder', 'a', (0x81A4 << 16) | 0x4000),
      ('Finder', 'a/', (0x41ED << 16) | 0x4000),
      ('Info-ZIP, read-only', 'a', (0x8124 << 16) | 0x01),
      ('Info-ZIP, read-only', 'a/', (0x416D << 16) | 0x11),
      ('Python zipfile writestr', 'a', 0x0180 << 16),
      ('7-Zip, archive', 'a', (0x81FF << 16) | 0x8020),
      ('Windows, archive', 'a', 0x20),
    ]) {
      test('us01/fr02, rz12: $tool attributes '
          '0x${attributes.toRadixString(16)} on "$path", made on host '
          '$host, are safe', () {
        expect(
          () => checkEntryFileType(
            path,
            externalAttributes: attributes,
            host: host,
          ),
          returnsNormally,
        );
      });
    }
  }

  for (final host in [1, 2, 6, 7, 10, 11, 14, 19, 30, 255]) {
    test('us01/fr02/e01, rz12 (m3-t7b review): an entry made on host $host '
        'is unsafe_entry_path', () {
      expect(
        () => checkEntryFileType(
          'a',
          externalAttributes: 0x81A4 << 16,
          host: host,
        ),
        _unsafe('a'),
      );
    });
  }

  for (final (label, path, attributes) in [
    ('the volume-label bit 0x08', 'theme.yaml', 0x08),
    ('the volume-label bit 0x08', 'a/', (0x41ED << 16) | 0x18),
    ('the hidden bit 0x02', 'a', 0x02),
    ('the system bit 0x04', 'a', 0x04),
    ('the bit 0x40', 'a', 0x40),
    ('the bit 0x80', 'a', 0x80),
    ('the reparse-point bit 0x400', 'a', 0x400),
    ('setuid', 'a', 0x89ED << 16),
    ('setgid', 'a', 0x85ED << 16),
    ('the sticky bit', 'a/', 0x43FF << 16),
  ]) {
    for (final host in [0, 3]) {
      test('us01/fr02/e01, rz12 (m3-t7b review): $label on "$path", made '
          'on host $host, is unsafe_entry_path', () {
        expect(
          () => checkEntryFileType(
            path,
            externalAttributes: attributes,
            host: host,
          ),
          _unsafe(path),
        );
      });
    }
  }

  for (final (label, host, attributes, message) in [
    ('host', 1, 0, 'entry "a" was made on host 1; the install reads only '),
    ('mode', 3, 0x89ED << 16, 'entry "a" carries the setuid, setgid, or '),
    ('bits', 0, 0x0408, 'entry "a" carries the MS-DOS attribute bits 0x0408'),
  ]) {
    test('us01/fr02/e01, rz12: the $label refusal names its rule', () {
      expect(
        () =>
            checkEntryFileType('a', externalAttributes: attributes, host: host),
        throwsA(
          isA<RemoteThemeFailure>().having(
            (f) => f.message,
            'message',
            startsWith(message),
          ),
        ),
      );
    });
  }

  for (final host in [0, 3]) {
    for (final type in [0xA000, 0x1000, 0x2000, 0x6000, 0xC000]) {
      test('us01/fr02/e01: file type 0x${type.toRadixString(16)} is '
          'unsafe_entry_path on host $host', () {
        expect(
          () => checkEntryFileType(
            'link',
            externalAttributes: (type | 0x1FF) << 16,
            host: host,
          ),
          _unsafe('link'),
        );
      });
    }
  }

  test('us01/fr02/e01, rz12: the low attribute half never counts as a file '
      'type, and a bit off its allowlist is refused', () {
    expect(
      () => checkEntryFileType('a', externalAttributes: 0x4000, host: 0),
      returnsNormally,
    );
    expect(
      () => checkEntryFileType('a', externalAttributes: 0x400, host: 0),
      _unsafe('a'),
    );
  });

  test('M6, rz4: an unsafe path reaches the message escaped and cut, its '
      'marker inside the quotes', () {
    final path = '\u001b[31m\n"\\${'é' * 300}/../x';
    final quoted = RegExp('entry "(.*)"');

    expect(
      () => checkEntryPath(path),
      throwsA(
        isA<RemoteThemeFailure>()
            .having((f) => f.path, 'path', path)
            .having(
              (f) => quoted.firstMatch(f.message)!.group(1)!,
              'quoted text',
              allOf(
                startsWith(r'\u001b[31m\u000a\u0022\u005c\u00e9'),
                matches(RegExp(r'\\\[cut 313 chars, id [0-9a-f]{32}\]$')),
                hasLength(lessThanOrEqualTo(253)),
              ),
            )
            .having(
              (f) => f.message,
              'message',
              allOf(isNot(contains('é')), isNot(contains('\n'))),
            ),
      ),
    );
  });
}
