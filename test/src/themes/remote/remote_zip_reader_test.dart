import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show Deflate;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_reader.dart';

import 'remote_test_zip.dart';

const int _mb = 1024 * 1024;

/// A deterministic 3000-byte payload, M1-T2's probe `_small`: large enough
/// that a stored block must declare its length rather than fall out as the
/// empty-folder special case.
final _small = Uint8List.fromList([
  for (var i = 0; i < 3000; i++) (i * 7) % 251,
]);

Map<String, Uint8List> _read(
  Uint8List zip, {
  int maxBytes = 20 * _mb,
  int maxEntries = 200,
}) => readRemoteZip(zip, maxBytes: maxBytes, maxEntries: maxEntries).files;

List<String> _unread(Uint8List zip) =>
    readRemoteZip(zip, maxBytes: 20 * _mb, maxEntries: 200).unread;

Matcher _fails(
  StratumRemoteThemeErrorCode code, {
  int? measured,
  String? path,
  Object? message,
}) => throwsA(
  isA<RemoteThemeFailure>()
      .having((f) => f.code, 'code', code)
      .having((f) => f.measured, 'measured', measured ?? anything)
      .having((f) => f.path, 'path', path ?? anything)
      .having((f) => f.message, 'message', message ?? anything),
);

void main() {
  final yaml = utf8.encode('$remoteSchemaLine\nname: brand\n');

  test('us01/fr02: entries inflate into memory, relative to the root', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture('fonts/a.ttf', [1, 2, 3], deflate: false),
    ]);

    final entries = _read(zip);

    expect(entries.keys, ['theme.yaml', 'fonts/a.ttf']);
    expect(entries['theme.yaml'], yaml);
    expect(entries['fonts/a.ttf'], [1, 2, 3]);
  });

  test('us01/fr02/e05: a one-folder zip keys entries below that folder', () {
    final zip = buildZip([
      ZipEntryFixture('brand/', const [], deflate: false),
      ZipEntryFixture('brand/theme.yaml', yaml),
      ZipEntryFixture('__MACOSX/brand/._theme.yaml', [9]),
      ZipEntryFixture('brand/.DS_Store', [9]),
    ]);

    expect(_read(zip).keys, ['theme.yaml']);
  });

  test('us01/fr02/e02: bytes that are no zip are invalid_archive', () {
    expect(
      () => _read(Uint8List.fromList(utf8.encode('not a zip'))),
      _fails(StratumRemoteThemeErrorCode.invalidArchive),
    );
  });

  test('us01/fr02/e02: a zip cut in half is invalid_archive', () {
    final zip = buildZip([ZipEntryFixture('theme.yaml', yaml)]);
    expect(
      () => _read(zip.sublist(0, zip.length ~/ 2)),
      _fails(StratumRemoteThemeErrorCode.invalidArchive),
    );
  });

  test('us01/fr02/e10: corrupt deflate data fails its CRC-32 check, '
      'invalid_archive', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', utf8.encode('a: 1\n' * 50)),
    ]);
    zip[40] ^= 0xFF;
    expect(
      () => _read(zip),
      _fails(StratumRemoteThemeErrorCode.invalidArchive),
    );
  });

  test('us01/fr02/e10: an encrypted entry, or a method other than store '
      'and deflate, is invalid_archive', () {
    expect(
      () => _read(buildZip([ZipEntryFixture('theme.yaml', yaml, flags: 1)])),
      _fails(StratumRemoteThemeErrorCode.invalidArchive),
    );
    for (final method in [12, 14]) {
      expect(
        () => _read(
          buildZip([
            ZipEntryFixture('theme.yaml', yaml, deflate: false, method: method),
          ]),
        ),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    }
  });

  test('us01/fr02/e06: more entries than maxEntries is archive_too_large with '
      'the count', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      for (var i = 0; i < 3; i++) ZipEntryFixture('f$i.txt', [i]),
    ]);
    expect(
      () => _read(zip, maxEntries: 3),
      _fails(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 4),
    );
  });

  test('us01/s12, us01/fr02/e06: declared sizes past maxBytes are '
      'archive_too_large with the sum, before any entry inflates', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml, declaredSize: 600),
      ZipEntryFixture('a.bin', [1], declaredSize: 500),
    ]);
    expect(
      () => _read(zip, maxBytes: 1000),
      _fails(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 1100),
    );
  });

  test(
    'us01/fr02/e07: a header that understates its size stops at the cap',
    () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('big.bin', Uint8List(_mb), declaredSize: 100),
      ]);
      expect(
        () => _read(zip, maxBytes: 64 * 1024),
        throwsA(
          isA<RemoteThemeFailure>()
              .having(
                (f) => f.code,
                'code',
                StratumRemoteThemeErrorCode.archiveTooLarge,
              )
              .having(
                (f) => f.measured,
                'measured',
                inInclusiveRange(64 * 1024 + 1, 64 * 1024 + 258),
              ),
        ),
      );
    },
  );

  test('us01/fr02/e07: a stored entry past its header stops at the cap', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture(
        'a.bin',
        Uint8List(5000),
        deflate: false,
        declaredSize: 10,
      ),
    ]);
    expect(
      () => _read(zip, maxBytes: 4096),
      _fails(StratumRemoteThemeErrorCode.archiveTooLarge),
    );
  });

  test('us01/fr02/e08: a raised maxBytes lets the same zip through', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture('a.bin', Uint8List(5000)),
    ]);
    expect(
      () => _read(zip, maxBytes: 4096),
      _fails(StratumRemoteThemeErrorCode.archiveTooLarge),
    );
    expect(_read(zip, maxBytes: 8192).keys, ['theme.yaml', 'a.bin']);
  });

  test('us01/s5, us01/fr02/e01: an escaping path refuses the whole zip', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture('../evil.txt', [1]),
    ]);
    expect(
      () => _read(zip),
      _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: '../evil.txt'),
    );
  });

  test('us01/fr02/e14: a central-header name holding a raw control byte '
      'is unsafe_entry_path before the theme root search', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture('\x01evil.txt', [1]),
    ]);
    expect(
      () => _read(zip),
      _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: '\x01evil.txt'),
    );
  });

  test('us01/fr02/e01: a symbolic link entry is unsafe_entry_path', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture(
        'link',
        utf8.encode('../../etc'),
        deflate: false,
        madeBy: 0x031E,
        attributes: 0xA1FF << 16,
      ),
    ]);
    expect(
      () => _read(zip),
      _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'link'),
    );
  });

  test('us01/fr02/e03: a zip with no theme root is missing_theme_file', () {
    expect(
      () => _read(buildZip([ZipEntryFixture('a/b/theme.yaml', yaml)])),
      _fails(StratumRemoteThemeErrorCode.missingThemeFile),
    );
  });

  test('us01/fr02/e11, review focus 2: a path held twice is '
      'invalid_archive naming it', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture('a.txt', [1]),
      ZipEntryFixture('a.txt', [2]),
    ]);
    expect(
      () => _read(zip),
      _fails(StratumRemoteThemeErrorCode.invalidArchive, path: 'a.txt'),
    );
  });

  test('us01/fr02/e09: an empty zip is invalid_archive', () {
    expect(
      () => _read(buildZip([])),
      _fails(StratumRemoteThemeErrorCode.invalidArchive),
    );
  });

  test('us01/fr02: a loose top file beside one folder stays out', () {
    final zip = buildZip([
      ZipEntryFixture('README.md', [1]),
      ZipEntryFixture('brand/theme.yaml', yaml),
    ]);
    expect(_read(zip).keys, ['theme.yaml']);
  });

  test('us02/fr03/e13, r15: the reader names every entry under a root '
      'folder that it never reads', () {
    final zip = buildZip([
      ZipEntryFixture('brand/', const [], deflate: false),
      ZipEntryFixture('brand/theme.yaml', yaml),
      ZipEntryFixture('__MACOSX/', const [], deflate: false),
      ZipEntryFixture('__MACOSX/brand/._theme.yaml', [9]),
      ZipEntryFixture('brand/.DS_Store', [9]),
      ZipEntryFixture('README.md', [1]),
      ZipEntryFixture('other/', const [], deflate: false),
    ]);

    expect(_read(zip).keys, ['theme.yaml']);
    expect(_unread(zip), [
      '__MACOSX/',
      '__MACOSX/brand/._theme.yaml',
      'brand/.DS_Store',
      'README.md',
    ]);
  });

  test('us02/fr03/e13, r15: a zip-root theme leaves only the ignored '
      'entries unread', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture('.DS_Store', [9]),
      ZipEntryFixture('images/.DS_Store', [9]),
      ZipEntryFixture('images/a.svg', [1]),
    ]);

    expect(_read(zip).keys, ['theme.yaml', 'images/a.svg']);
    expect(_unread(zip), ['.DS_Store', 'images/.DS_Store']);
  });

  test('minor6 edge, us02/fr03/e13, r15: a .DS_Store three folders deep is '
      'unread', () {
    final zip = buildZip([
      ZipEntryFixture('brand/', const [], deflate: false),
      ZipEntryFixture('brand/theme.yaml', yaml),
      ZipEntryFixture('brand/sub/sub2/.DS_Store', [9]),
    ]);

    expect(_read(zip).keys, ['theme.yaml']);
    expect(_unread(zip), ['brand/sub/sub2/.DS_Store']);
  });

  test('minor6 edge, us02/fr03/e13, r15: a folder entry inside the theme '
      'root is neither unread nor a file', () {
    final zip = buildZip([
      ZipEntryFixture('brand/', const [], deflate: false),
      ZipEntryFixture('brand/theme.yaml', yaml),
      ZipEntryFixture('brand/images/', const [], deflate: false),
    ]);

    expect(_read(zip).keys, ['theme.yaml']);
    expect(_unread(zip), isEmpty);
  });

  test('us01/fr02: an unreadable zip and a cap fault give invalid_archive '
      'first', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml, flags: 1),
      ZipEntryFixture('a.txt', [1]),
    ]);
    expect(
      () => _read(zip, maxEntries: 1),
      _fails(StratumRemoteThemeErrorCode.invalidArchive),
    );
  });

  test('us01/fr02: a cap fault and an unsafe path give archive_too_large '
      'first', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', yaml),
      ZipEntryFixture('../evil.txt', [1]),
    ]);
    expect(
      () => _read(zip, maxEntries: 1),
      _fails(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 2),
    );
  });

  test('us01/fr02: an unsafe path and no theme root give '
      'unsafe_entry_path first', () {
    final zip = buildZip([
      ZipEntryFixture('/etc/x', [1]),
    ]);
    expect(
      () => _read(zip),
      _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: '/etc/x'),
    );
  });

  test('us01/fr02/e10: a CRC fault and an unsafe path give '
      'unsafe_entry_path first, since CRC-32 is checked as each entry '
      'inflates', () {
    final zip = buildZip([
      ZipEntryFixture('theme.yaml', utf8.encode('a: 1\n' * 50)),
      ZipEntryFixture('../evil.txt', [1]),
    ]);
    zip[40] ^= 0xFF;
    expect(
      () => _read(zip),
      _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: '../evil.txt'),
    );
  });

  group('R11 container walk', () {
    test('I1: past maxEntries stops at entry maxEntries + 1, before any '
        'local header is read', () {
      final zip = buildZip([
        for (var i = 0; i < 1000; i++)
          ZipEntryFixture('e$i', const [], deflate: false, localAt: 0),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 201),
      );
    });

    test('I2: a local-only encryption flag is invalid_archive and leaves '
        'the input buffer unchanged', () {
      final zip = localOnlyEncryptedZip(yaml);
      final before = Uint8List.fromList(zip);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
      expect(zip, before);
    });

    test('I3: an entry whose span overlaps another is invalid_archive', () {
      final inner = ZipEntryFixture('b.txt', [1, 2, 3], deflate: false);
      final zip = buildZip([
        ZipEntryFixture('a.bin', inner.localBytes, deflate: false),
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('b.txt', [1, 2, 3], deflate: false, localAt: 35),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    List<int> zip64Extra(int low, int high) =>
        (ByteData(12)
              ..setUint16(0, 1, Endian.little)
              ..setUint16(2, 8, Endian.little)
              ..setUint32(4, low, Endian.little)
              ..setUint32(8, high, Endian.little))
            .buffer
            .asUint8List();

    test('M3: a ZIP64 negative size never lowers the declared size sum', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('a', [1], declaredSize: 0xFFFFFF00),
        ZipEntryFixture(
          'b',
          [1],
          declaredSize: 0xFFFFFFFF,
          centralExtra: zip64Extra(0, 0x80000000),
        ),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.archiveTooLarge),
      );
    });

    test('M3: the declared size is the 32-bit central field, never a ZIP64 '
        'extra', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture(
          'b',
          [1],
          declaredSize: 0xFFFFFFFF,
          centralExtra: zip64Extra(1, 0),
        ),
      ]);

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.archiveTooLarge,
          measured: 0xFFFFFFFF + yaml.length,
        ),
      );
    });

    test('M4: a central entry with no local header is invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('ghost.txt', const [], deflate: false, localAt: 40),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('M5, rz12: a symbolic link made on host 19 is unsafe_entry_path '
        'by its host, which the type rule never reaches', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture(
          'link',
          utf8.encode('../../etc'),
          deflate: false,
          madeBy: (19 << 8) | 20,
          attributes: 0xA1FF << 16,
        ),
      ]);

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: 'link',
          message: contains('was made on host 19'),
        ),
      );
    });

    test('rz12 (review m3-t7d): a symbolic link made on host 0, as 7-Zip '
        'writes one with its marker 0x8000, is unsafe_entry_path by its '
        'type', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture(
          'link',
          utf8.encode('../../etc'),
          deflate: false,
          madeBy: 0x0014,
          attributes: (0xA1FF << 16) | 0x8000,
        ),
      ]);

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: 'link',
          message: contains('has file type 0xa000'),
        ),
      );
    });

    for (final (finding, names) in [
      ('M1', ['theme/theme.yaml', 'theme/../x.txt']),
      ('M2', ['theme.yaml', './theme.yaml']),
    ]) {
      test('$finding: "${names.last}" is unsafe_entry_path', () {
        final zip = buildZip([
          for (final name in names) ZipEntryFixture(name, yaml),
        ]);

        expect(
          () => _read(zip),
          _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: names.last),
        );
      });
    }

    test('rz2, us01/fr02/e14 (c-2): a path holding U+202E, a format '
        'character, refuses as unsafe_entry_path with the printable-ASCII '
        'message, each byte of its UTF-8 printed as its own escape', () {
      const evil = 'images/a\u202Eb.png';
      final decoded = String.fromCharCodes(utf8.encode(evil));
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture(evil, [1]),
      ]);

      expect(
        () => _read(zip),
        throwsA(
          isA<RemoteThemeFailure>()
              .having(
                (f) => f.code,
                'code',
                StratumRemoteThemeErrorCode.unsafeEntryPath,
              )
              .having((f) => f.path, 'path', decoded)
              .having(
                (f) => f.message,
                'message',
                allOf(
                  contains('outside printable ASCII'),
                  contains(r'\u00e2\u0080\u00ae'),
                  isNot(contains('\u202E')),
                ),
              ),
        ),
      );
    });

    test('a local name that differs from the central name is '
        'invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml, localName: '../../evil'),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('a local method that differs from the central method is '
        'invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml, deflate: false, localMethod: 8),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('an end record counting other than the entries walked is '
        'invalid_archive', () {
      final zip = buildZip([ZipEntryFixture('theme.yaml', yaml)], endCount: 3);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('a ZIP64 locator alone is invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
      ], zip64Locator: true);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('a ZIP64 end record alone is invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
      ], zip64Record: true);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    for (final maxEntries in [0, -1]) {
      test('a maxEntries of $maxEntries refuses a one-entry zip as '
          'archive_too_large', () {
        final zip = buildZip([ZipEntryFixture('theme.yaml', yaml)]);

        expect(
          () => _read(zip, maxEntries: maxEntries),
          _fails(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 1),
        );
      });
    }

    test('a disk other than the first is invalid_archive', () {
      final zip = buildZip([ZipEntryFixture('theme.yaml', yaml)], disk: 1);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('a central directory past the end record is invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
      ], directoryOffset: 0x7FFFFFF0);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('a central header cut short is invalid_archive', () {
      final zip = buildZip([ZipEntryFixture('theme.yaml', yaml)]);
      final start = ByteData.sublistView(zip)
          .getUint32(zip.length - 6, Endian.little);
      final cut = BytesBuilder()
        ..add(zip.sublist(0, start + 10))
        ..add(zip.sublist(zip.length - 22));
      final bytes = cut.toBytes();
      ByteData.sublistView(bytes)
          .setUint32(bytes.length - 10, 10, Endian.little);

      expect(
        () => _read(bytes),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });
  });

  test('us01/fr02: no theme root and a lying header give '
      'missing_theme_file first', () {
    final zip = buildZip([
      ZipEntryFixture('a/b/theme.yaml', yaml),
      ZipEntryFixture('a/big.bin', Uint8List(_mb), declaredSize: 1),
    ]);
    expect(
      () => _read(zip, maxBytes: 1024),
      _fails(StratumRemoteThemeErrorCode.missingThemeFile),
    );
  });

  group('r15 folder entries', () {
    test('us01/fr02/e13: a folder entry with no bytes, typed none or '
        'directory, is read past', () {
      for (final attributes in [0, 0x41ED << 16]) {
        final zip = buildZip([
          ZipEntryFixture(
            'brand/',
            const [],
            deflate: false,
            attributes: attributes,
          ),
          ZipEntryFixture('brand/theme.yaml', yaml),
        ]);
        expect(_read(zip).keys, ['theme.yaml'], reason: '$attributes');
      }
    });

    test('us01/fr02/e13, r15: a folder entry deflated to the 2-byte empty '
        'stream, "03 00", is read past', () {
      final zip = buildZip([
        ZipEntryFixture('brand/', const []),
        ZipEntryFixture('brand/theme.yaml', yaml),
      ]);
      expect(_read(zip).keys, ['theme.yaml']);
    });

    for (final (label, body) in [
      (
        '01 00 00 ff ff, what Java writes at level 0',
        [0x01, 0x00, 0x00, 0xFF, 0xFF],
      ),
      (
        'an empty stored block, then an empty final fixed block',
        [0x00, 0x00, 0x00, 0xFF, 0xFF, 0x03, 0x00],
      ),
    ]) {
      test('us01/fr02/e13, rz3: a folder entry deflated to nothing as '
          '$label is read past', () {
        final zip = buildZip([
          ZipEntryFixture('brand/', const [], method: 8, body: body),
          ZipEntryFixture('brand/theme.yaml', yaml),
        ]);

        expect(_read(zip).keys, ['theme.yaml']);
      });
    }

    for (final (label, entry) in [
      (
        'a deflate stream that inflates to bytes under a size and CRC-32 '
            'of 0',
        ZipEntryFixture(
          'hidden/',
          const [],
          method: 8,
          body: Deflate([1, 2, 3]).getBytes(),
        ),
      ),
      (
        'stored bytes under a size and CRC-32 of 0',
        ZipEntryFixture('hidden/', const [], deflate: false, body: [1, 2, 3]),
      ),
      (
        'a deflate stream that inflates to a single byte under a size and '
            'CRC-32 of 0',
        ZipEntryFixture(
          'hidden/',
          const [],
          method: 8,
          body: Deflate([9]).getBytes(),
        ),
      ),
      (
        'a single stored byte under a size and CRC-32 of 0',
        ZipEntryFixture('hidden/', const [], deflate: false, body: [9]),
      ),
    ]) {
      test('us01/s15, us01/fr02/e13, rz3: a "/"-ending entry with $label is '
          'unsafe_entry_path', () {
        final zip = buildZip([ZipEntryFixture('theme.yaml', yaml), entry]);

        expect(
          () => _read(zip),
          _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'hidden/'),
        );
      });
    }

    for (final (label, entry) in [
      ('stored bytes', ZipEntryFixture('hidden/', [1, 2, 3], deflate: false)),
      (
        'bytes under a declared size of 0',
        ZipEntryFixture('hidden/', [1, 2, 3], deflate: false, declaredSize: 0),
      ),
      (
        'a regular file type and no bytes',
        ZipEntryFixture(
          'hidden/',
          const [],
          deflate: false,
          attributes: 0x81A4 << 16,
        ),
      ),
      (
        'a deflated 2-byte stream other than the empty one',
        ZipEntryFixture(
          'hidden/',
          const [],
          method: 8,
          body: const [0x01, 0x00],
        ),
      ),
    ]) {
      test('us01/s15, us01/fr02/e13, r15: a "/"-ending entry with $label is '
          'unsafe_entry_path', () {
        final zip = buildZip([ZipEntryFixture('theme.yaml', yaml), entry]);
        expect(
          () => _read(zip),
          _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'hidden/'),
        );
      });
    }

    test('edge i1, us01/fr02/e13: a folder entry declaring bytes is '
        'refused', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('hidden/', const [], deflate: false, declaredSize: 5),
      ]);
      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'hidden/'),
      );
    });
  });

  group('r17 printable ASCII names', () {
    List<int> nameWith(List<int> high) => [
      ...'fonts/'.codeUnits,
      ...high,
      ...'.ttf'.codeUnits,
    ];

    for (final (label, high, flags, escaped) in [
      ('the overlong c0 8a', [0xC0, 0x8A], 0, r'fonts/\u00c0\u008a.ttf'),
      (
        'the surrogate ed a0 80',
        [0xED, 0xA0, 0x80],
        0,
        r'fonts/\u00ed\u00a0\u0080.ttf',
      ),
      ('the CP437 byte 9b', [0x9B], 0, r'fonts/\u009b.ttf'),
      (
        'the CP437 byte 9b under flags bit 11',
        [0x9B],
        0x0800,
        r'fonts/\u009b.ttf',
      ),
    ]) {
      test('us01/s15, us01/fr02/e14, rz2, r17 (t26): a name holding $label '
          'is unsafe_entry_path, each byte one character', () {
        final bytes = nameWith(high);
        final zip = buildZip([
          ZipEntryFixture('theme.yaml', yaml),
          ZipEntryFixture('x', [1], rawName: bytes, flags: flags),
        ]);

        expect(
          () => _read(zip),
          throwsA(
            isA<RemoteThemeFailure>()
                .having(
                  (f) => f.code,
                  'code',
                  StratumRemoteThemeErrorCode.unsafeEntryPath,
                )
                .having((f) => f.path, 'path', String.fromCharCodes(bytes))
                .having((f) => f.message, 'message', contains(escaped)),
          ),
        );
      });
    }

    test('us01/fr02/e14, rz2, r17 (t28): two names that differ only in a '
        'high byte refuse on the first in directory order, never as one '
        'name held twice', () {
      final first = [...'__MACOSX/Q'.codeUnits, 0xFF];
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('a', [1], rawName: first),
        ZipEntryFixture('b', [2], rawName: [...'__MACOSX/Q'.codeUnits, 0xFE]),
      ]);

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: String.fromCharCodes(first),
        ),
      );
    });

    test('us01/fr02/e14, rz2: an ASCII name with flags bit 11 set installs '
        'and reads the same name', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture(
          'fonts/a.ttf',
          [1, 2, 3],
          deflate: false,
          flags: 0x0800,
        ),
      ]);

      expect(_read(zip)['fonts/a.ttf'], [1, 2, 3]);
    });

    test('us01/fr02/e14, rz2: a name whose local bytes differ from the '
        'central bytes only in one high byte is invalid_archive, naming '
        'the mismatch in its local header message', () {
      final central = [...'fonts/'.codeUnits, 0xFF, ...'.ttf'.codeUnits];
      final local = [...'fonts/'.codeUnits, 0xFE, ...'.ttf'.codeUnits];
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('x', [1], rawName: central, localRawName: local),
      ]);

      expect(
        () => _read(zip),
        throwsA(
          isA<RemoteThemeFailure>()
              .having(
                (f) => f.code,
                'code',
                StratumRemoteThemeErrorCode.invalidArchive,
              )
              .having(
                (f) => f.message,
                'message',
                contains('holds another name in its local header'),
              ),
        ),
      );
    });

    test('us01/s15, us01/fr02/e14, rz2, r17 (t26): a high byte at the first '
        r'position is unsafe_entry_path, escaped as its own \u00XX', () {
      final bytes = [0x9B, ...'fonts.ttf'.codeUnits];
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('x', [1], rawName: bytes),
      ]);

      expect(
        () => _read(zip),
        throwsA(
          isA<RemoteThemeFailure>()
              .having(
                (f) => f.code,
                'code',
                StratumRemoteThemeErrorCode.unsafeEntryPath,
              )
              .having((f) => f.path, 'path', String.fromCharCodes(bytes))
              .having((f) => f.message, 'message', contains(r'\u009b')),
        ),
      );
    });
  });

  group('r18 container', () {
    /// A ZIP64 extra record of [size] for both sizes.
    List<int> zip64Extra(int size) => [
      0x01, 0x00, 0x10, 0x00, //
      size & 0xFF, (size >> 8) & 0xFF, (size >> 16) & 0xFF, size >> 24,
      0, 0, 0, 0,
      size & 0xFF, (size >> 8) & 0xFF, (size >> 16) & 0xFF, size >> 24,
      0, 0, 0, 0,
    ];

    final payload = ZipEntryFixture('payload.txt', utf8.encode('evil'));

    test('us01/fr02/e02, rz3: a Finder-style entry, flags bit 3 with a '
        'signed 16-byte descriptor and a local CRC-32 and sizes of 0, '
        'installs', () {
      final zip = buildZip([
        ZipEntryFixture(
          'theme.yaml',
          yaml,
          flags: 0x8,
          localCrc: 0,
          localCompressedSize: 0,
          localSize: 0,
          descriptor: dataDescriptor(yaml),
        ),
      ]);

      expect(_read(zip).keys, ['theme.yaml']);
    });

    test('us01/fr02/e02, rz3: a 12-byte descriptor with the local CRC-32 '
        'and sizes repeated installs', () {
      final zip = buildZip([
        ZipEntryFixture(
          'theme.yaml',
          yaml,
          flags: 0x8,
          descriptor: dataDescriptor(yaml, signed: false),
        ),
      ]);

      expect(_read(zip).keys, ['theme.yaml']);
    });

    String hex4(int id) => '0x${id.toRadixString(16).padLeft(4, '0')}';

    /// An extra-field record of [id] holding [body].
    List<int> record(int id, List<int> body) => [
      id & 0xFF,
      id >> 8,
      body.length & 0xFF,
      body.length >> 8,
      ...body,
    ];

    /// 0x000a's body in its one layout: 4 reserved bytes, tag 0x0001 of
    /// size 24, and three 8-byte times; 7-Zip 26.04 writes it centrally.
    final ntfs = [0, 0, 0, 0, 0x01, 0x00, 0x18, 0x00, ...List.filled(24, 7)];

    for (final (tool, id, local, central) in [
      ('7-Zip 26.04', 0x000a, null, ntfs),
      (
        'Info-ZIP 3.0',
        0x5455,
        [0x03, ...List.filled(8, 7)],
        [0x03, 1, 2, 3, 4],
      ),
      (
        'bsdtar and tar -a',
        0x5455,
        [0x07, ...List.filled(12, 7)],
        [0x01, 1, 2, 3, 4],
      ),
      ('Finder ditto', 0x5855, List.filled(12, 7), List.filled(8, 7)),
      (
        'Info-ZIP 3.0, bsdtar, and tar -a',
        0x7875,
        [1, 4, 0xF5, 1, 0, 0, 4, 0x14, 0, 0, 0],
        [1, 4, 0xF5, 1, 0, 0, 4, 0x14, 0, 0, 0],
      ),
      ('jar', 0xcafe, <int>[], <int>[]),
      (
        'a Python zipfile repack, which writes the central body into the '
            'local field too',
        0x5455,
        [0x03, 1, 2, 3, 4],
        [0x03, 1, 2, 3, 4],
      ),
      (
        'a Java ZipInputStream repack, which writes the local body into '
            'the central field too',
        0x5855,
        List.filled(12, 7),
        List.filled(12, 7),
      ),
    ]) {
      test('us01/fr02/e02, rz9, rzf4: an extra record of id ${hex4(id)} in '
          'the layout $tool writes, and an end record comment, '
          'install', () {
        final zip = buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localExtra: local == null ? const [] : record(id, local),
            centralExtra: record(id, central),
          ),
        ], comment: utf8.encode('note'));

        expect(_read(zip).keys, ['theme.yaml']);
      });
    }

    for (final (label, id, local, central) in [
      ('a 0x000a of the 32-byte layout, local and central', 0x000a, ntfs, ntfs),
      (
        'a 0x5455 of flags 0x01, 5 bytes local and 5 central',
        0x5455,
        [0x01, 1, 2, 3, 4],
        [0x01, 1, 2, 3, 4],
      ),
      (
        'a 0x5455 of flags 0x00, 1 byte local and 1 central',
        0x5455,
        [0x00],
        [0x00],
      ),
      (
        'a 0x5455 of flags 0x06, 9 bytes local and 1 central',
        0x5455,
        [0x06, ...List.filled(8, 7)],
        [0x06],
      ),
      ('an 8-byte 0x5855 local', 0x5855, List.filled(8, 7), List.filled(8, 7)),
      (
        'a 0x7875 of user id 0',
        0x7875,
        [1, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0],
        [1, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0],
      ),
      ('a 0x7875 of sizes 0 and 0', 0x7875, [1, 0, 0], [1, 0, 0]),
      (
        'a 0x7875 of sizes 2 and 8',
        0x7875,
        [1, 2, 1, 0, 8, ...List.filled(8, 0)],
        [1, 2, 1, 0, 8, ...List.filled(8, 0)],
      ),
    ]) {
      test('us01/fr02/e02, rzf4: $label, a layout the source defines and '
          'no tool here writes, installs', () {
        final zip = buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localExtra: record(id, local),
            centralExtra: record(id, central),
          ),
        ]);

        expect(_read(zip).keys, ['theme.yaml']);
      });
    }

    test('us01/fr02/e02, rzf4 (rq-a): a 9-byte 0x5455 of flags 0x03 in the '
        'central extra field, which fits the local layout, installs', () {
      final zip = buildZip([
        ZipEntryFixture(
          'theme.yaml',
          yaml,
          centralExtra: record(0x5455, [0x03, ...List.filled(8, 7)]),
        ),
      ]);

      expect(_read(zip).keys, ['theme.yaml']);
    });

    for (final (label, where, id, body) in [
      ('an empty 0x000a', 'central', 0x000a, <int>[]),
      ('a 3-byte 0x000a', 'central', 0x000a, [1, 2, 3]),
      ('a 31-byte 0x000a', 'central', 0x000a, ntfs.sublist(0, 31)),
      ('a 31-byte 0x000a', 'local', 0x000a, ntfs.sublist(0, 31)),
      ('a 33-byte 0x000a', 'local', 0x000a, [...ntfs, 0]),
      ('a 33-byte 0x000a', 'central', 0x000a, [...ntfs, 0]),
      (
        'a 36-byte 0x000a holding a second attribute',
        'central',
        0x000a,
        [...ntfs, 0x02, 0x00, 0x00, 0x00],
      ),
      (
        'a 0x000a of tag 0x0002',
        'central',
        0x000a,
        [0, 0, 0, 0, 0x02, 0x00, 0x18, 0x00, ...List.filled(24, 7)],
      ),
      (
        'a 0x000a of attribute size 23',
        'central',
        0x000a,
        [0, 0, 0, 0, 0x01, 0x00, 0x17, 0x00, ...List.filled(24, 7)],
      ),
      ('an empty 0x5455', 'local', 0x5455, <int>[]),
      ('an empty 0x5455', 'central', 0x5455, <int>[]),
      ('a 1-byte 0x5455 of flags 0x07', 'local', 0x5455, [0x07]),
      ('a 1-byte 0x5455 of flags 0x01', 'central', 0x5455, [0x01]),
      ('a 5-byte 0x5455 of flags 0x00', 'central', 0x5455, [0x00, 1, 2, 3, 4]),
      ('a 0x5455 of flags 0x08', 'local', 0x5455, [0x08]),
      ('a 0x5455 of flags 0x80', 'central', 0x5455, [0x80]),
      ('an empty 0x5855', 'local', 0x5855, <int>[]),
      ('a 10-byte 0x5855', 'local', 0x5855, List.filled(10, 7)),
      ('an empty 0x7875', 'local', 0x7875, <int>[]),
      (
        'a 0x7875 of version 0',
        'central',
        0x7875,
        [0, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0],
      ),
      (
        'a 0x7875 of version 2',
        'central',
        0x7875,
        [2, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0],
      ),
      (
        'a 0x7875 one byte short of its sizes',
        'local',
        0x7875,
        [1, 4, 0, 0, 0, 0, 4, 0, 0, 0],
      ),
      (
        'a 0x7875 one byte past its sizes',
        'central',
        0x7875,
        [1, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0],
      ),
      (
        'a 0x7875 whose user-id size runs past its body',
        'local',
        0x7875,
        [1, 9, 0],
      ),
      (
        'a 0x7875 whose group-id size runs past its body',
        'local',
        0x7875,
        [1, 4, 0, 0, 0, 0, 9],
      ),
      ('a 3-byte 0xcafe', 'local', 0xcafe, [1, 2, 3]),
      ('a 1-byte 0xcafe', 'central', 0xcafe, [0]),
    ]) {
      test('us01/fr02/e02, rzf4 (t7b): $label in the $where extra field is '
          'invalid_archive', () {
        final zip = buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localExtra: where == 'local' ? record(id, body) : const [],
            centralExtra: where == 'central' ? record(id, body) : const [],
          ),
        ]);

        expect(
          () => _read(zip),
          _fails(
            StratumRemoteThemeErrorCode.invalidArchive,
            message: contains(
              'the $where extra field of entry "theme.yaml" holds a '
              'record of id ${hex4(id)} whose ${body.length}-byte body '
              'fits no layout of that id',
            ),
          ),
        );
      });
    }

    for (final (label, where, id) in [
      ("libarchive's 'xl' file-type record", 'local', 0x6c78),
      ("libarchive's 'xl' file-type record", 'central', 0x6c78),
      ('a record of id 0', 'local', 0x0000),
      ('a WinZip AES record', 'central', 0x9901),
    ]) {
      test('us01/fr02/e02, rz9 (m3-t6 security): $label, ${hex4(id)}, in '
          'the $where extra field is invalid_archive', () {
        final record = [id & 0xFF, id >> 8, 0x01, 0x00, 0x00];
        final zip = buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localExtra: where == 'local' ? record : const [],
            centralExtra: where == 'central' ? record : const [],
          ),
        ]);

        expect(
          () => _read(zip),
          _fails(
            StratumRemoteThemeErrorCode.invalidArchive,
            message: contains('holds a record of id ${hex4(id)}'),
          ),
        );
      });
    }

    test('us01/fr02/e01, rz9 (m3-t6 security): an entry named theme.yaml '
        'with the MS-DOS folder attribute, made on FAT, is '
        'unsafe_entry_path', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml, madeBy: 0x0014, attributes: 0x10),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'theme.yaml'),
      );
    });

    test('us01/fr02/e13, rz9: a folder entry with the MS-DOS folder '
        'attribute, as Info-ZIP writes it, installs', () {
      final zip = buildZip([
        ZipEntryFixture(
          'brand/',
          const [],
          deflate: false,
          madeBy: 0x031E,
          attributes: (0x41ED << 16) | 0x10,
        ),
        ZipEntryFixture('brand/theme.yaml', yaml),
      ]);

      expect(_read(zip).keys, ['theme.yaml']);
    });

    for (final (tool, madeBy, folder, file) in [
      ('Finder (ditto)', 0x0315, (0x41ED << 16) | 0x4000, 0x81A44000),
      ('Info-ZIP', 0x031E, (0x41ED << 16) | 0x10, 0x81A4 << 16),
      ('Info-ZIP, read-only', 0x031E, (0x416D << 16) | 0x11, 0x81240001),
      ('tar -a and bsdtar', 0x0314, 0x41ED << 16, 0x81A4 << 16),
      ('Python zipfile', 0x0314, (0x41ED << 16) | 0x10, 0x0180 << 16),
      (
        'Python zipfile on Windows',
        0x0014,
        (0x41FF << 16) | 0x10,
        0x81B6 << 16,
      ),
      ('Java and jar', 0x0014, 0, 0),
      ('stratum_theme pack', 0x0314, 0x41ED << 16, 0x81A4 << 16),
      ('7-Zip', 0x0314, (0x41ED << 16) | 0x8010, (0x81A4 << 16) | 0x8020),
      ('Windows, archive bit', 0x0014, 0x10, 0x20),
    ]) {
      test('us01/fr02/e01, rz12: a zip with the host byte and attributes '
          '$tool writes installs', () {
        final zip = buildZip([
          ZipEntryFixture(
            'brand/',
            const [],
            deflate: false,
            madeBy: madeBy,
            attributes: folder,
          ),
          ZipEntryFixture(
            'brand/theme.yaml',
            yaml,
            madeBy: madeBy,
            attributes: file,
          ),
        ]);

        expect(_read(zip).keys, ['theme.yaml']);
      });
    }

    for (final (label, madeBy, attributes, message) in [
      (
        'the MS-DOS volume-label bit 0x08, made on FAT',
        0x0014,
        0x08,
        'MS-DOS attribute bits 0x0008',
      ),
      (
        'the MS-DOS volume-label bit 0x08, made on NTFS (host 11)',
        0x0B14,
        0x08,
        'made on host 11',
      ),
      (
        'an Amiga folder type, high half 0x0800 (host 1)',
        0x0114,
        0x0800 << 16,
        'made on host 1',
      ),
      (
        'the setuid bit, made on Unix',
        0x031E,
        0x89ED << 16,
        'setuid, setgid, or sticky',
      ),
      (
        'the MS-DOS reparse-point bit 0x400, made on FAT',
        0x0014,
        0x400,
        'MS-DOS attribute bits 0x0400',
      ),
    ]) {
      test('us01/fr02/e01, rz12 (m3-t7b review): a root theme.yaml with '
          '$label, beside a benign brand/theme.yaml, is unsafe_entry_path', () {
        final zip = buildZip([
          ZipEntryFixture(
            'theme.yaml',
            utf8.encode('$remoteSchemaLine\nname: hostile\n'),
            madeBy: madeBy,
            attributes: attributes,
          ),
          ZipEntryFixture('brand/theme.yaml', yaml),
        ]);

        expect(
          () => _read(zip),
          _fails(
            StratumRemoteThemeErrorCode.unsafeEntryPath,
            path: 'theme.yaml',
            message: contains(message),
          ),
        );
      });
    }

    for (final (label, zip) in [
      (
        'p2: a folder entry whose local header declares 152 stored bytes '
            'the directory does not',
        () => buildZip([
          ZipEntryFixture('theme.yaml', yaml),
          ZipEntryFixture(
            'hidden/',
            const [],
            deflate: false,
            localCompressedSize: 152,
            localSize: 152,
            descriptor: List<int>.filled(152, 0x41),
          ),
        ]),
      ),
      (
        'p3: flags bit 3 with a whole deflate stream and descriptor after a '
            'central compressed size of 0',
        () => buildZip([
          ZipEntryFixture('theme.yaml', yaml),
          ZipEntryFixture(
            'hidden/',
            const [],
            method: 8,
            flags: 0x8,
            body: const [],
            localCrc: 0,
            localCompressedSize: 0,
            localSize: 0,
            descriptor: [
              ...Deflate(List<int>.filled(152, 0x41)).getBytes(),
              ...dataDescriptor(List<int>.filled(152, 0x41)),
            ],
          ),
        ]),
      ),
      (
        'p4: a whole local entry no central header lists, between two that '
            'it does',
        () => buildZip(
          [
            ZipEntryFixture('theme.yaml', yaml),
            ZipEntryFixture('a.txt', [1]),
          ],
          gaps: {1: payload.localBytes},
        ),
      ),
      (
        'p4b: a whole local entry no central header lists, before the first',
        () => buildZip([
          ZipEntryFixture('theme.yaml', yaml),
        ], prefix: payload.localBytes),
      ),
      (
        'p5: local sizes 0xFFFFFFFF with a local ZIP64 record',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localCompressedSize: 0xFFFFFFFF,
            localSize: 0xFFFFFFFF,
            localExtra: zip64Extra(yaml.length),
          ),
        ]),
      ),
      (
        'a local ZIP64 record under sizes that agree',
        () => buildZip([
          ZipEntryFixture('theme.yaml', yaml, localExtra: zip64Extra(40)),
        ]),
      ),
      (
        'a central ZIP64 record under a small declared size',
        () => buildZip([
          ZipEntryFixture('theme.yaml', yaml, centralExtra: zip64Extra(40)),
        ]),
      ),
      (
        'an Info-ZIP Unicode Path record in the central extra field',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            centralExtra: const [0x75, 0x70, 0x05, 0x00, 1, 0, 0, 0, 0],
          ),
        ]),
      ),
      (
        'an Info-ZIP Unicode Path record in the local extra field',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localExtra: const [0x75, 0x70, 0x05, 0x00, 1, 0, 0, 0, 0],
          ),
        ]),
      ),
      (
        'a local extra field that is no whole record',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localExtra: const [0x55, 0x54, 0x09, 0x00, 1],
          ),
        ]),
      ),
      (
        'a local extra field that ends with a fragment shorter than a '
            'record header',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            localExtra: const [0x55, 0x54, 0x01, 0x00, 0x00, 1, 2, 3],
          ),
        ]),
      ),
      (
        'a central extra field that ends with a fragment shorter than a '
            'record header',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            centralExtra: const [0x55, 0x54, 0x01, 0x00, 0x00, 1, 2, 3],
          ),
        ]),
      ),
      (
        'p9: a local size of 192 against the central one',
        () => buildZip([ZipEntryFixture('theme.yaml', yaml, localSize: 192)]),
      ),
      (
        'local flags that differ from the central ones',
        () =>
            buildZip([ZipEntryFixture('theme.yaml', yaml, localFlags: 0x0800)]),
      ),
      (
        'a local CRC-32 that differs with flags bit 3 clear',
        () => buildZip([ZipEntryFixture('theme.yaml', yaml, localCrc: 1)]),
      ),
      (
        'flags bit 3 with a local CRC-32 of 0 but local sizes that differ',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            flags: 0x8,
            localCrc: 0,
            localSize: 1,
            descriptor: dataDescriptor(yaml),
          ),
        ]),
      ),
      (
        'a stored entry with flags bit 3 and a descriptor',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            deflate: false,
            flags: 0x8,
            descriptor: dataDescriptor(yaml, deflate: false),
          ),
        ]),
      ),
      (
        'a descriptor with 8-byte sizes',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            flags: 0x8,
            descriptor: dataDescriptor(yaml, zip64: true),
          ),
        ]),
      ),
      (
        'a 16-byte descriptor that does not start 50 4b 07 08',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            flags: 0x8,
            descriptor: [0, 0, 0, 0, ...dataDescriptor(yaml, signed: false)],
          ),
        ]),
      ),
      (
        'a descriptor whose CRC-32 differs from the directory',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            flags: 0x8,
            descriptor: dataDescriptor(utf8.encode('other')),
          ),
        ]),
      ),
      (
        'a 12-byte descriptor whose CRC-32 field is the signed signature, '
            'which Java reads as a 16-byte one',
        () => buildZip([
          ZipEntryFixture('theme.yaml', yaml),
          ZipEntryFixture(
            'hidden/',
            const [],
            method: 8,
            flags: 0x8,
            body: const [],
            crc: 0x08074b50,
            descriptor: const [0x50, 0x4b, 0x07, 0x08, 0, 0, 0, 0, 0, 0, 0, 0],
          ),
        ]),
      ),
      (
        'flags bit 3 with no descriptor after the data',
        () => buildZip([ZipEntryFixture('theme.yaml', yaml, flags: 0x8)]),
      ),
      (
        'a byte after the end record comment',
        () => buildZip([ZipEntryFixture('theme.yaml', yaml)], afterEnd: [0]),
      ),
      (
        'a byte between the central directory and the end record',
        () => buildZip([ZipEntryFixture('theme.yaml', yaml)], beforeEnd: [0]),
      ),
    ]) {
      test('us01/fr02/e02, rz3, r18: $label is invalid_archive', () {
        expect(
          () => _read(zip()),
          _fails(StratumRemoteThemeErrorCode.invalidArchive),
        );
      });
    }

    test('us01/fr02/e02, rzf7 (t6): a central directory that lists two '
        'valid entries out of their local-header order installs', () {
      final first = ZipEntryFixture('theme.yaml', yaml).localBytes;
      final zip = buildZip(
        [
          ZipEntryFixture('a.txt', [1], localAt: first.length),
          ZipEntryFixture('theme.yaml', yaml, localAt: 0),
        ],
        prefix: [
          ...first,
          ...ZipEntryFixture('a.txt', [1]).localBytes,
        ],
      );

      expect(_read(zip).keys, ['a.txt', 'theme.yaml']);
    });

    test('us01/fr02/e02, rzf7 (d4): a central directory that lists two '
        'entries out of their local-header order, with a 1-byte gap '
        'between their local headers, is invalid_archive', () {
      final first = ZipEntryFixture('theme.yaml', yaml).localBytes;
      final zip = buildZip(
        [
          ZipEntryFixture('a.txt', [1], localAt: first.length + 1),
          ZipEntryFixture('theme.yaml', yaml, localAt: 0),
        ],
        prefix: [
          ...first,
          0,
          ...ZipEntryFixture('a.txt', [1]).localBytes,
        ],
      );

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.invalidArchive,
          message: contains(
            'bytes after entry "theme.yaml" belong to no entry',
          ),
        ),
      );
    });

    for (final (label, zip, message) in [
      (
        'one byte between two spans',
        () => buildZip(
          [
            ZipEntryFixture('theme.yaml', yaml),
            ZipEntryFixture('a.txt', [1]),
          ],
          gaps: {
            1: [0],
          },
        ),
        'bytes after entry "theme.yaml" belong to no entry',
      ),
      (
        'one byte before the first span',
        () => buildZip([ZipEntryFixture('theme.yaml', yaml)], prefix: [0]),
        'bytes before entry "theme.yaml" belong to no entry',
      ),
      (
        "an end record whose comment length runs past the zip's last byte",
        () {
          final whole = buildZip([
            ZipEntryFixture('theme.yaml', yaml),
          ], comment: utf8.encode('note'));
          return Uint8List.sublistView(whole, 0, whole.length - 2);
        },
        'bytes follow the end record',
      ),
      (
        'an 8-byte data descriptor after a flags-bit-3 deflate entry',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            flags: 0x8,
            descriptor: dataDescriptor(yaml, signed: false).sublist(0, 8),
          ),
        ]),
        'has no 12-byte or signed 16-byte data descriptor',
      ),
      (
        'a 20-byte data descriptor after a flags-bit-3 deflate entry',
        () => buildZip([
          ZipEntryFixture(
            'theme.yaml',
            yaml,
            flags: 0x8,
            descriptor: dataDescriptor(yaml, signed: false, zip64: true),
          ),
        ]),
        'has no 12-byte or signed 16-byte data descriptor',
      ),
    ]) {
      test('us01/fr02/e02, rzf7 (t6): $label is invalid_archive', () {
        expect(
          () => _read(zip()),
          _fails(
            StratumRemoteThemeErrorCode.invalidArchive,
            message: contains(message),
          ),
        );
      });
    }

    test('z8: a cap fault and a local header fault give archive_too_large '
        'first, before any local header is read', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml, localSize: 999),
        ZipEntryFixture('a.txt', [1]),
      ]);

      expect(
        () => _read(zip, maxEntries: 1),
        _fails(StratumRemoteThemeErrorCode.archiveTooLarge, measured: 2),
      );
    });

    test('z8: a local header fault and an unsafe path give invalid_archive '
        'first', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml, localSize: 999),
        ZipEntryFixture('../evil.txt', [1]),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });
  });

  group('r18 every entry inflates', () {
    List<int> storedBlock(List<int> data) => [
      0,
      data.length & 0xFF,
      data.length >> 8,
      (data.length & 0xFF) ^ 0xFF,
      (data.length >> 8) ^ 0xFF,
      ...data,
    ];

    test('us01/fr02/e10, rz3, r18 (t27 p11): a whole local entry after the '
        'final deflate block, inside the span, is invalid_archive', () {
      final hidden = ZipEntryFixture('payload.txt', utf8.encode('evil'));
      final zip = buildZip([
        ZipEntryFixture(
          'theme.yaml',
          yaml,
          method: 8,
          body: [...Deflate(yaml).getBytes(), ...hidden.localBytes],
        ),
      ]);

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.invalidArchive,
          message: contains('holds bytes after its final deflate block'),
        ),
      );
    });

    test('us01/fr02/e10, us01/fr02/e13, rz3, r18 (t27 p11): the same hidden '
        "local entry after an empty folder's final deflate block is "
        'unsafe_entry_path, not invalid_archive', () {
      final hidden = ZipEntryFixture('payload.txt', utf8.encode('evil'));
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture(
          'brand/',
          const [],
          method: 8,
          body: [...Deflate(const <int>[]).getBytes(), ...hidden.localBytes],
        ),
      ]);

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: 'brand/',
          message: contains('holds bytes after its final deflate block'),
        ),
      );
    });

    test('us01/fr02/e10, rz3: a deflate stream with no final block is '
        'invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml, method: 8, body: storedBlock(yaml)),
      ]);

      expect(
        () => _read(zip),
        _fails(
          StratumRemoteThemeErrorCode.invalidArchive,
          message: contains('ends before its final deflate block'),
        ),
      );
    });

    test('us01/fr02/e06, us01/fr02/e07, rz3: maxBytes exactly equal to a read '
        'entry plus an unread one installs; one byte more in the unread '
        'entry is archive_too_large, measured there', () {
      final macBytes = List<int>.filled(100, 7);
      final total = yaml.length + macBytes.length;
      final atCap = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('__MACOSX/x', macBytes),
      ]);

      expect(_read(atCap, maxBytes: total).keys, ['theme.yaml']);

      final overCap = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('__MACOSX/x', [...macBytes, 7]),
      ]);

      expect(
        () => _read(overCap, maxBytes: total),
        _fails(
          StratumRemoteThemeErrorCode.archiveTooLarge,
          measured: total + 1,
        ),
      );
    });

    test('us01/fr02/e10, rz3: a deflate stream whose output exceeds 65,535 '
        'bytes through chained stored blocks installs; the same stream with '
        'one trailing byte is invalid_archive', () {
      List<int> stored(List<int> chunk, {required bool last}) => [
        if (last) 1 else 0,
        chunk.length & 0xFF,
        chunk.length >> 8,
        (chunk.length & 0xFF) ^ 0xFF,
        (chunk.length >> 8) ^ 0xFF,
        ...chunk,
      ];

      final chunk1 = List<int>.generate(65535, (i) => i % 256);
      final chunk2 = List<int>.generate(5000, (i) => (i * 3) % 256);
      final data = [...chunk1, ...chunk2];
      final body = [
        ...stored(chunk1, last: false),
        ...stored(chunk2, last: true),
      ];

      expect(
        _read(
          buildZip([
            ZipEntryFixture('theme.yaml', data, method: 8, body: body),
          ]),
        ).keys,
        ['theme.yaml'],
      );

      expect(
        () => _read(
          buildZip([
            ZipEntryFixture(
              'theme.yaml',
              data,
              method: 8,
              body: [...body, 0x99],
            ),
          ]),
        ),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    for (final (label, entry) in [
      (
        'stored with a compressed size of 0',
        ZipEntryFixture('empty.txt', const [], deflate: false),
      ),
      (
        'deflated to the 2-byte empty stream "03 00"',
        ZipEntryFixture('empty.txt', const []),
      ),
    ]) {
      test('us01/fr02/e13, rz3: a genuinely empty, non-folder file, $label, '
          'installs as an empty file, not a folder', () {
        final zip = buildZip([ZipEntryFixture('theme.yaml', yaml), entry]);

        final files = _read(zip);

        expect(files.keys, unorderedEquals(['theme.yaml', 'empty.txt']));
        expect(files['empty.txt'], isEmpty);
      });
    }

    test('us01/fr02/e01, rz3, r18 (t27): an entry named theme.yaml typed '
        'S_IFDIR is unsafe_entry_path', () {
      final zip = buildZip([
        ZipEntryFixture(
          'theme.yaml',
          yaml,
          madeBy: 0x031E,
          attributes: 0x41ED << 16,
        ),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'theme.yaml'),
      );
    });

    test('us01/fr02/e10, rz3, review focus: a __MACOSX/ entry the install '
        'never reads, whose CRC-32 fails, is invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('__MACOSX/._theme.yaml', [1, 2, 3], crc: 7),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });

    test('us01/fr02/e07, rz3: entries the install never reads count toward '
        'maxBytes', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('__MACOSX/big', Uint8List(_mb), declaredSize: 1),
      ]);

      expect(
        () => _read(zip, maxBytes: 64 * 1024),
        _fails(StratumRemoteThemeErrorCode.archiveTooLarge),
      );
    });

    for (final (label, entry) in [
      (
        'a stored entry whose compressed size differs from its size',
        ZipEntryFixture('a.bin', [1, 2, 3], deflate: false, declaredSize: 2),
      ),
      (
        'a deflate entry that inflates past its declared size within the cap',
        ZipEntryFixture('a.bin', Uint8List(100), declaredSize: 50),
      ),
      (
        'a deflate entry that inflates short of its declared size',
        ZipEntryFixture('a.bin', Uint8List(100), declaredSize: 150),
      ),
    ]) {
      test('us01/fr02/e10, rz3: $label is invalid_archive', () {
        final zip = buildZip([ZipEntryFixture('theme.yaml', yaml), entry]);

        expect(
          () => _read(zip),
          _fails(StratumRemoteThemeErrorCode.invalidArchive),
        );
      });
    }

    // Owner ruling RZ11, 2026-10-08: "ตัวคลายเข้มงวดของเรา (Recommended)"
    // — the package's own strict inflate refuses the stream ends RZ8 had
    // accepted, and every other malformed block (design Z5).
    for (final (label, data, vector, reason) in [
      (
        'v10 a reserved block type after the output',
        _small,
        [...storedBlock(_small), 0x07],
        'has a deflate block of the reserved type',
      ),
      (
        'v11 a stored LEN and NLEN that disagree after the output',
        _small,
        [...storedBlock(_small), 0x01, 0x05, 0x00, 0x34, 0x12],
        'NLEN is not the complement of its LEN',
      ),
      (
        'v14 an empty final stored block with a wrong NLEN',
        const <int>[],
        const [1, 0, 0, 0x12, 0x34],
        'NLEN is not the complement of its LEN',
      ),
      (
        'W1 an empty stored block with NLEN 0x4241 before the data',
        yaml,
        [0x00, 0x00, 0x00, 0x41, 0x42, ...Deflate(yaml).getBytes()],
        'NLEN is not the complement of its LEN',
      ),
    ]) {
      test('us01/fr02/e10, rz11 (m1-t2, m3-t7 security): $label is '
          'invalid_archive', () {
        final zip = buildZip([
          ZipEntryFixture('theme.yaml', data, method: 8, body: vector),
        ]);

        expect(
          () => _read(zip),
          _fails(
            StratumRemoteThemeErrorCode.invalidArchive,
            message: contains(reason),
          ),
        );
      });
    }

    final carrier = [
      for (var i = 0; i < 1000; i++) ...[0, 0, 0, 0x48, 0x49],
      0x03,
      0x00,
    ];

    test('us01/fr02/e13, rz11 (m3-t7 security W2): a folder entry of 1,000 '
        'empty stored blocks carrying 2,000 chosen bytes is '
        'unsafe_entry_path', () {
      final zip = buildZip([
        ZipEntryFixture('brand/', const [], method: 8, body: carrier),
        ZipEntryFixture('brand/theme.yaml', yaml),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'brand/'),
      );
    });

    test('us01/fr02/e10, rz11 (m3-t7 security W2): the same carrier in an '
        '__MACOSX/ entry the install never reads is invalid_archive', () {
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture('__MACOSX/x', const [], method: 8, body: carrier),
      ]);

      expect(
        () => _read(zip),
        _fails(StratumRemoteThemeErrorCode.invalidArchive),
      );
    });
  });

  group('us01/fr02/e10, rz13: one Huffman-block budget per zip', () {
    // Two of remote_inflate_test's 92-bit max-fill dynamic blocks, 23 bytes
    // whole, each building three full tables and writing nothing.
    const twoMaxFillBlocks = [
      0x04, 0xC1, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0xFF, 0xD5, //
      0x48, 0x10, 0x1C, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF1, 0x5F,
      0x8D,
    ];
    // Four empty fixed blocks, 5 bytes whole.
    const fourEmptyFixedBlocks = [0x02, 0x08, 0x20, 0x80, 0x00];
    const emptyFinalStored = [0x01, 0x00, 0x00, 0xFF, 0xFF];

    List<int> folderData(List<int> blocks, int times) => [
      for (var i = 0; i < times; i++) ...blocks,
      ...emptyFinalStored,
    ];

    Uint8List folders(int count, List<int> data) => buildZip([
      ZipEntryFixture('theme.yaml', yaml, deflate: false),
      for (var i = 0; i < count; i++)
        ZipEntryFixture(
          'd${i.toString().padLeft(5, '0')}/',
          const [],
          method: 8,
          body: data,
        ),
    ]);

    test('review m3-t7e Important 1: 65,534 empty folder entries of 16 '
        'max-fill blocks each, which took 8.5 to 9.2 s, are refused at the '
        'second folder entry in under 2 s', () {
      final zip = folders(65534, folderData(twoMaxFillBlocks, 8));
      final clock = Stopwatch()..start();

      expect(
        () => _read(zip, maxEntries: 65535),
        _fails(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: 'd00001/',
          message: contains('starts more Huffman blocks than its zip allows'),
        ),
      );
      expect(clock.elapsedMilliseconds, lessThan(2000));
    });

    test('2,000 folder entries holding 03 00, as Java writes an empty '
        'folder, read: each entry pays for its own block', () {
      final zip = folders(2000, const [0x03, 0x00]);

      expect(_read(zip, maxEntries: 2001), {'theme.yaml': yaml});
    });

    test('the budget spans the entries: 5 folder entries of 4 empty '
        'Huffman blocks read, 20 of the 21 their 16 free and 5 own allow, '
        'and a 6th is refused at its third block', () {
      final data = folderData(fourEmptyFixedBlocks, 1);

      expect(_read(folders(5, data)), {'theme.yaml': yaml});
      expect(
        () => _read(folders(6, data)),
        _fails(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: 'd00005/',
          message: contains('starts more Huffman blocks than its zip allows'),
        ),
      );
    });

    test('each read has a budget of its own', () {
      final zip = folders(5, folderData(fourEmptyFixedBlocks, 1));

      expect(_read(zip), {'theme.yaml': yaml});
      expect(_read(zip), {'theme.yaml': yaml});
    });

    test('output an earlier entry inflated pays for a later entry: after '
        '3,000 deflated bytes, 7 folder entries of 4 empty blocks read and '
        'an 8th is refused', () {
      Uint8List zip(int count) => buildZip([
        ZipEntryFixture('theme.yaml', yaml, deflate: false),
        ZipEntryFixture('a.bin', _small),
        for (var i = 0; i < count; i++)
          ZipEntryFixture(
            'd$i/',
            const [],
            method: 8,
            body: folderData(fourEmptyFixedBlocks, 1),
          ),
      ]);

      expect(_read(zip(7)), {'theme.yaml': yaml, 'a.bin': _small});
      expect(
        () => _read(zip(8)),
        _fails(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          path: 'd7/',
          message: contains('starts more Huffman blocks than its zip allows'),
        ),
      );
    });
  });
}
