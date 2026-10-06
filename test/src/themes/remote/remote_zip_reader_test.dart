import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_reader.dart';

import 'remote_test_zip.dart';

const int _mb = 1024 * 1024;

Map<String, Uint8List> _read(
  Uint8List zip, {
  int maxBytes = 20 * _mb,
  int maxEntries = 200,
}) => readRemoteZip(zip, maxBytes: maxBytes, maxEntries: maxEntries);

Matcher _fails(
  StratumRemoteThemeErrorCode code, {
  int? measured,
  String? path,
}) => throwsA(
  isA<RemoteThemeFailure>()
      .having((f) => f.code, 'code', code)
      .having((f) => f.measured, 'measured', measured ?? anything)
      .having((f) => f.path, 'path', path ?? anything),
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

    test('M5: a symbolic link made on host 19 is unsafe_entry_path', () {
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
        _fails(StratumRemoteThemeErrorCode.unsafeEntryPath, path: 'link'),
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

    test('M6: a control-character name reaches the message escaped and the '
        'path raw', () {
      const evil = '\u001b[2J\u001b[31mFAKE\u001b[0m\n\u202Exyz/../../x';
      final zip = buildZip([
        ZipEntryFixture('theme.yaml', yaml),
        ZipEntryFixture(evil, [1]),
      ]);

      expect(
        () => _read(zip),
        throwsA(
          isA<RemoteThemeFailure>()
              .having((f) => f.path, 'path', evil)
              .having(
                (f) => f.toString(),
                'toString',
                allOf(
                  isNot(contains('\u001b')),
                  isNot(contains('\n')),
                  isNot(contains('\u202E')),
                  contains(r'\u001b[2J'),
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
}
