import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// The `$schema` line every theme file starts with.
const remoteSchemaLine = r'$schema: stratum-theme/v1.0.0';

/// One entry of a hand-built test zip.
///
/// - [declaredSize]: the uncompressed size both headers declare.
/// - [madeBy], [attributes]: the central version-made-by and external
///   attributes.
/// - [method]: the compression method both headers declare.
/// - [flags]: the central general purpose bit flag, and the local one
///   unless [localFlags] is set.
/// - [localFlags], [localMethod], [localName]: local-header-only values.
/// - [body]: the raw data both headers frame, written as is; [crc] then
///   overrides the CRC-32 of [data].
/// - [centralExtra]: the central header's extra field.
/// - [localAt]: writes no local header; the central header points at this
///   offset instead.
/// - [rawName]: the name's bytes in both headers, in place of [name] in
///   UTF-8.
final class ZipEntryFixture {
  new(
    this.name,
    this.data, {
    this.deflate = true,
    this.declaredSize,
    this.madeBy = 20,
    this.attributes = 0,
    this.method,
    this.flags = 0,
    this.localFlags,
    this.localMethod,
    this.localName,
    this.body,
    this.crc,
    this.centralExtra = const [],
    this.localAt,
    this.rawName,
  });

  final String name;
  final List<int> data;
  final bool deflate;
  final int? declaredSize;
  final int madeBy;
  final int attributes;
  final int? method;
  final int flags;
  final int? localFlags;
  final int? localMethod;
  final String? localName;
  final List<int>? body;
  final int? crc;
  final List<int> centralExtra;
  final int? localAt;
  final List<int>? rawName;

  List<int> get _body => body ?? (deflate ? Deflate(data).getBytes() : data);

  int get _method => method ?? (body == null && deflate ? 8 : 0);

  int get _crc => crc ?? getCrc32(data);

  int get _size => declaredSize ?? data.length;

  /// This entry's local header followed by its data.
  Uint8List get localBytes {
    final name = localName != null
        ? utf8.encode(localName!)
        : rawName ?? utf8.encode(this.name);
    final out = BytesBuilder();
    _u32(out, 0x04034b50);
    _u16(out, 20);
    _u16(out, localFlags ?? flags);
    _u16(out, localMethod ?? _method);
    _u16(out, 0);
    _u16(out, 0);
    _u32(out, _crc);
    _u32(out, _body.length);
    _u32(out, _size);
    _u16(out, name.length);
    _u16(out, 0);
    out
      ..add(name)
      ..add(_body);
    return out.toBytes();
  }
}

void _u16(BytesBuilder builder, int value) => builder.add(
  (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List(),
);

void _u32(BytesBuilder builder, int value) => builder.add(
  (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List(),
);

/// A zip of [entries], in order, written byte by byte so a test controls
/// every header field.
///
/// - [endCount]: the entry count the end record declares.
/// - [disk]: the end record's disk number.
/// - [zip64Record]: writes a ZIP64 end record after the central directory.
/// - [zip64Locator]: writes a ZIP64 locator right before the end record.
/// - [directoryOffset]: the central directory offset the end record
///   declares.
Uint8List buildZip(
  List<ZipEntryFixture> entries, {
  int? endCount,
  int disk = 0,
  bool zip64Record = false,
  bool zip64Locator = false,
  int? directoryOffset,
}) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  for (final entry in entries) {
    final name = entry.rawName ?? utf8.encode(entry.name);
    final offset = entry.localAt ?? out.length;
    if (entry.localAt == null) out.add(entry.localBytes);
    _u32(central, 0x02014b50);
    _u16(central, entry.madeBy);
    _u16(central, 20);
    _u16(central, entry.flags);
    _u16(central, entry._method);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, entry._crc);
    _u32(central, entry._body.length);
    _u32(central, entry._size);
    _u16(central, name.length);
    _u16(central, entry.centralExtra.length);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, entry.attributes);
    _u32(central, offset);
    central
      ..add(name)
      ..add(entry.centralExtra);
  }
  final start = out.length;
  final directory = central.toBytes();
  out.add(directory);
  final record = out.length;
  if (zip64Record) {
    _u32(out, 0x06064b50);
    out.add(Uint8List(52));
  }
  if (zip64Locator) {
    _u32(out, 0x07064b50);
    _u32(out, 0);
    _u32(out, record);
    _u32(out, 0);
    _u32(out, 1);
  }
  _u32(out, 0x06054b50);
  _u16(out, disk);
  _u16(out, 0);
  _u16(out, endCount ?? entries.length);
  _u16(out, endCount ?? entries.length);
  _u32(out, directory.length);
  _u32(out, directoryOffset ?? start);
  _u16(out, 0);
  return out.toBytes();
}

/// The checksum text of [bytes]: `sha256:` and 64 lowercase hex digits.
String checksumOf(List<int> bytes) => 'sha256:${sha256.convert(bytes)}';

/// [plain] under ZipCrypto with all-zero keys, the state `archive` decodes
/// with when a local header sets flag bit 0 and no password is given.
List<int> zeroKeyEncrypt(List<int> plain) {
  var k0 = 0;
  var k1 = 0;
  var k2 = 0;
  final out = <int>[];
  for (final byte in plain) {
    final t = (k2 & 0xffff) | 2;
    out.add(byte ^ (((t * (t ^ 1)) >> 8) & 0xff));
    k0 = getCrc32Byte(k0, byte);
    k1 = (_mul32((k1 + (k0 & 0xff)) & 0xffffffff, 134775813) + 1) & 0xffffffff;
    k2 = getCrc32Byte(k2, k1 >> 24);
  }
  return out;
}

/// [a] times [b] modulo 2^32, exact on the web too, where an int product
/// past 2^53 loses bits.
int _mul32(int a, int b) {
  final low = (a & 0xffff) * b;
  final high = ((a >> 16) * b) & 0xffff;
  return (low + (high << 16)) & 0xffffffff;
}

/// A zip whose one entry, `theme.yaml` holding [plain], sets flag bit 0 in
/// its local header only, its body zero-key encrypted, so a reader that
/// trusts the local flag decrypts it in place and accepts it.
Uint8List localOnlyEncryptedZip(List<int> plain) => buildZip([
  ZipEntryFixture(
    'theme.yaml',
    plain,
    localFlags: 1,
    body: zeroKeyEncrypt([...List<int>.filled(12, 7), ...plain]),
  ),
]);
