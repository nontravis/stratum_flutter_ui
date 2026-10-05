import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// The `$schema` line every theme file starts with.
const remoteSchemaLine = r'$schema: stratum-theme/v1.0.0';

/// One entry of a hand-built test zip. [declaredSize] overrides the
/// uncompressed size both headers declare; [madeBy] and [attributes] are
/// the central header's version-made-by and external attributes; [method]
/// overrides the compression method both headers declare; [flags] is the
/// general purpose bit flag.
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
  });

  final String name;
  final List<int> data;
  final bool deflate;
  final int? declaredSize;
  final int madeBy;
  final int attributes;
  final int? method;
  final int flags;
}

/// A zip of [entries], in order, written byte by byte so a test controls
/// every header field.
Uint8List buildZip(List<ZipEntryFixture> entries) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  void u16(BytesBuilder builder, int value) => builder.add(
    (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List(),
  );
  void u32(BytesBuilder builder, int value) => builder.add(
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List(),
  );
  for (final entry in entries) {
    final name = utf8.encode(entry.name);
    final body = entry.deflate ? Deflate(entry.data).getBytes() : entry.data;
    final method = entry.method ?? (entry.deflate ? 8 : 0);
    final crc = getCrc32(entry.data);
    final size = entry.declaredSize ?? entry.data.length;
    final offset = out.length;
    u32(out, 0x04034b50);
    u16(out, 20);
    u16(out, entry.flags);
    u16(out, method);
    u16(out, 0);
    u16(out, 0);
    u32(out, crc);
    u32(out, body.length);
    u32(out, size);
    u16(out, name.length);
    u16(out, 0);
    out
      ..add(name)
      ..add(body);
    u32(central, 0x02014b50);
    u16(central, entry.madeBy);
    u16(central, 20);
    u16(central, entry.flags);
    u16(central, method);
    u16(central, 0);
    u16(central, 0);
    u32(central, crc);
    u32(central, body.length);
    u32(central, size);
    u16(central, name.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, entry.attributes);
    u32(central, offset);
    central.add(name);
  }
  final directoryOffset = out.length;
  final directory = central.toBytes();
  out.add(directory);
  u32(out, 0x06054b50);
  u16(out, 0);
  u16(out, 0);
  u16(out, entries.length);
  u16(out, entries.length);
  u32(out, directory.length);
  u32(out, directoryOffset);
  u16(out, 0);
  return out.toBytes();
}

/// The checksum text of [bytes]: `sha256:` and 64 lowercase hex digits.
String checksumOf(List<int> bytes) => 'sha256:${sha256.convert(bytes)}';
