import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_reader.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_writer.dart';

Map<String, List<int>> get _files => {
  'theme.yaml': utf8.encode('name: x\n' * 50),
  'images/logo.svg': utf8.encode('<svg/>'),
  'images/Logo.svg': utf8.encode('<svg a/>'),
  'é.txt': <int>[],
  'big.bin': List<int>.generate(70000, (i) => i * 7 % 251),
};

const _sorted = [
  'big.bin',
  'images/Logo.svg',
  'images/logo.svg',
  'theme.yaml',
  'é.txt',
];

/// Matches a thrown [RemoteThemeFailure] coded [code], and [path] or
/// [measured] when given.
Matcher _failure(
  StratumRemoteThemeErrorCode code, {
  String? path,
  int? measured,
}) {
  var matcher = isA<RemoteThemeFailure>().having((f) => f.code, 'code', code);
  if (path != null) {
    matcher = matcher.having((f) => f.path, 'path', path);
  }
  if (measured != null) {
    matcher = matcher.having((f) => f.measured, 'measured', measured);
  }
  return throwsA(matcher);
}

void main() {
  group('us02/fr01, s03 packed zip: writeRemoteZip', () {
    test('us02/s2, us02/fr01/e05: the same files give the same bytes in any '
        'order', () {
      expect(
        writeRemoteZip(_files),
        writeRemoteZip(Map.fromEntries(_files.entries.toList().reversed)),
      );
    });

    test('us02/fr02/e05: the reader the app installs with gets every file '
        'back byte for byte', () {
      final read = readRemoteZip(
        writeRemoteZip(_files),
        maxBytes: 20 * 1024 * 1024,
        maxEntries: 200,
      );

      expect(read.keys.toSet(), _files.keys.toSet());
      for (final MapEntry(:key, :value) in _files.entries) {
        expect(read[key], Uint8List.fromList(value), reason: key);
      }
    });

    test('s03 packed zip: another zip reader reads it, names byte-sorted, '
        'every time 1980-01-01', () {
      final zip = ZipDecoder().decodeBytes(writeRemoteZip(_files));

      expect([for (final file in zip.files) file.name], _sorted);
      for (final file in zip.files) {
        expect(file.lastModTime, 0x00210000, reason: file.name);
      }
    });

    test('s03 packed zip: each central header is deflate, 00:00 on '
        '1980-01-01, a regular file 0644, with no extra field or comment, '
        'and the UTF-8 flag only on a non-ASCII name', () {
      final bytes = writeRemoteZip(_files);
      final view = ByteData.sublistView(bytes);
      final end = bytes.length - 22;
      expect(view.getUint32(end, Endian.little), 0x06054b50);
      var at = view.getUint32(end + 16, Endian.little);
      final names = <String>[];
      for (var i = 0; i < view.getUint16(end + 10, Endian.little); i++) {
        final nameLength = view.getUint16(at + 28, Endian.little);
        final name = utf8.decode(bytes.sublist(at + 46, at + 46 + nameLength));
        names.add(name);
        expect(
          view.getUint16(at + 8, Endian.little),
          name == 'é.txt' ? 0x0800 : 0,
          reason: name,
        );
        expect(view.getUint16(at + 10, Endian.little), 8, reason: name);
        expect(view.getUint16(at + 12, Endian.little), 0, reason: name);
        expect(view.getUint16(at + 14, Endian.little), 0x0021, reason: name);
        expect(view.getUint16(at + 30, Endian.little), 0, reason: name);
        expect(view.getUint16(at + 32, Endian.little), 0, reason: name);
        expect(
          view.getUint32(at + 38, Endian.little),
          0x81A40000,
          reason: name,
        );
        at += 46 + nameLength;
      }
      expect(names, _sorted);
    });

    test('s03 packed zip: a name past U+FFFF sorts by its 4-byte UTF-8 '
        'lead, not a UTF-16 code-unit compare', () {
      final zip = ZipDecoder().decodeBytes(
        writeRemoteZip(const {
          'images/logo.svg': <int>[],
          'images/😀.svg': <int>[],
          'theme.yaml': <int>[],
        }),
      );

      expect(
        [for (final file in zip.files) file.name],
        ['images/logo.svg', 'images/😀.svg', 'theme.yaml'],
      );
    });

    test('an empty files map gives the bare end record, which '
        'readRemoteZip refuses as "the zip is empty", one place for that '
        'rule', () {
      expect(writeRemoteZip(const {}), hasLength(22));
      expect(
        () => readRemoteZip(
          writeRemoteZip(const {}),
          maxBytes: 20 * 1024 * 1024,
          maxEntries: 200,
        ),
        throwsA(
          isA<RemoteThemeFailure>().having(
            (f) => f.code,
            'code',
            StratumRemoteThemeErrorCode.invalidArchive,
          ),
        ),
      );
    });
  });

  group('writeRemoteZip refuses input the zip format cannot hold', () {
    test('a key that is empty, as unsafe_entry_path with the path', () {
      expect(
        () => writeRemoteZip({'': <int>[]}),
        _failure(StratumRemoteThemeErrorCode.unsafeEntryPath, path: ''),
      );
    });

    test('a key ending in "/", since readRemoteZip drops such an entry '
        'silently', () {
      expect(
        () => writeRemoteZip({'images/': <int>[]}),
        _failure(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'images/'),
      );
    });

    test('a key that fails the entry path rule, propagating '
        "checkEntryPath's own exception", () {
      expect(
        () => writeRemoteZip({'../theme.yaml': <int>[]}),
        _failure(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: '../theme.yaml',
        ),
      );
    });

    test('a key whose UTF-8 does not round-trip, such as an unpaired '
        'surrogate', () {
      const name = 'a\u{D800}.txt';
      expect(
        () => writeRemoteZip({name: <int>[]}),
        _failure(StratumRemoteThemeErrorCode.unsafeEntryPath, path: name),
      );
    });

    test('a name that encodes past 0xFFFF UTF-8 bytes, as '
        'archive_too_large with the encoded length', () {
      expect(
        () => writeRemoteZip({'x' * 65536: <int>[]}),
        _failure(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 65536),
      );
    });

    test('more than 0xFFFF entries, as archive_too_large with the count', () {
      final files = {
        for (var i = 0; i <= 0xFFFF; i++) 'f$i': <int>[1],
      };
      expect(
        () => writeRemoteZip(files),
        _failure(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 65536),
      );
    });

    test("checkRemoteZipFieldFits32 refuses only past the format's 4 GiB "
        'field limit, reached without allocating 4 GiB', () {
      expect(
        () => checkRemoteZipFieldFits32(0xFFFFFFFF, 'test'),
        returnsNormally,
      );
      expect(
        () => checkRemoteZipFieldFits32(0x100000000, 'test'),
        _failure(
          StratumRemoteThemeErrorCode.archiveTooLarge,
          measured: 0x100000000,
        ),
      );
    });

    test('us02/fr01/e10, r15: a key holding a control character, through '
        "checkEntryPath's own exception", () {
      const name = 'images/a\nb.svg';
      expect(
        () => writeRemoteZip({name: <int>[]}),
        _failure(StratumRemoteThemeErrorCode.unsafeEntryPath, path: name),
      );
    });
  });
}
