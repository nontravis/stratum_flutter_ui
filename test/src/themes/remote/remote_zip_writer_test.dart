import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
