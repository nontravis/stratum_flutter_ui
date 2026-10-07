import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:stratum_ui/src/themes/remote/remote_entry_path.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

/// The deflate level of every `pack` entry (FO-04 s03 Packed zip).
const int remoteZipDeflateLevel = 6;

/// The DOS date of 1980-01-01, the fixed date of every `pack` entry; its
/// DOS time, 00:00:00, is 0.
const int _dosDate1980 = (0 << 9) | (1 << 5) | 1;

/// Made by Unix, version 2.0, and the version a reader needs, 2.0.
const int _madeBy = (3 << 8) | 20;
const int _needed = 20;

/// General purpose flag bit 11: the name is UTF-8.
const int _utf8Flag = 0x0800;

/// A regular file with mode 0644, in the high 16 bits of the external
/// attributes: the install's file-type rule reads `0x8000` (s03 Entry
/// path).
const int _regularFile = 0x81A4 << 16;

/// The largest value a zip name-length or entry-count field holds.
const int _max16 = 0xFFFF;

/// The largest value a zip size or offset field holds.
const int _max32 = 0xFFFFFFFF;

/// Builds the bytes of a theme zip from [files], keyed by their path
/// relative to the theme root with `/` between segments (FO-04 US-02
/// FR-01): entries in byte-sorted name order, each deflated at
/// [remoteZipDeflateLevel] and dated 1980-01-01 00:00:00, with no extra
/// field, no comment, and no folder entry. The same [files] always give the
/// same bytes. `archive` supplies only `Deflate` and `getCrc32` (design
/// S1).
///
/// Throws [ArgumentError] on a [files] the zip format cannot hold: empty;
/// a key that is empty, ends in `/`, fails to round-trip through UTF-8, or
/// encodes past 0xFFFF bytes; more than 0xFFFF entries; or any content
/// length, packed length, header offset, or directory size past
/// 0xFFFFFFFF. A key [checkEntryPath] refuses throws its own exception.
Uint8List writeRemoteZip(Map<String, List<int>> files) {
  if (files.isEmpty) {
    throw ArgumentError.value(files, 'files', 'must not be empty');
  }
  final names = [
    for (final name in files.keys) (name: name, bytes: _checkedNameBytes(name)),
  ]..sort((a, b) => _compareBytes(a.bytes, b.bytes));
  if (names.length > _max16) {
    throw ArgumentError.value(
      names.length,
      'files.length',
      'must not exceed $_max16 entries',
    );
  }
  final out = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  for (final (:name, bytes: nameBytes) in names) {
    final content = files[name]!;
    final packed = Deflate(content, level: remoteZipDeflateLevel).getBytes();
    final crc = getCrc32(content);
    final offset = out.length;
    checkRemoteZipFieldFits32(
      content.length,
      'files["${escapeZipText(name)}"]',
    );
    checkRemoteZipFieldFits32(
      packed.length,
      'the deflated size of "${escapeZipText(name)}"',
    );
    checkRemoteZipFieldFits32(
      offset,
      'the local header offset of "${escapeZipText(name)}"',
    );
    final flags = nameBytes.every((byte) => byte < 0x80) ? 0 : _utf8Flag;
    out
      ..add(_u32(0x04034b50))
      ..add(_u16(_needed))
      ..add(_u16(flags))
      ..add(_u16(8))
      ..add(_u16(0))
      ..add(_u16(_dosDate1980))
      ..add(_u32(crc))
      ..add(_u32(packed.length))
      ..add(_u32(content.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0))
      ..add(nameBytes)
      ..add(packed);
    central
      ..add(_u32(0x02014b50))
      ..add(_u16(_madeBy))
      ..add(_u16(_needed))
      ..add(_u16(flags))
      ..add(_u16(8))
      ..add(_u16(0))
      ..add(_u16(_dosDate1980))
      ..add(_u32(crc))
      ..add(_u32(packed.length))
      ..add(_u32(content.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u32(_regularFile))
      ..add(_u32(offset))
      ..add(nameBytes);
  }
  final directoryStart = out.length;
  final directory = central.takeBytes();
  checkRemoteZipFieldFits32(directoryStart, 'the central directory offset');
  checkRemoteZipFieldFits32(directory.length, 'the central directory size');
  out
    ..add(directory)
    ..add(_u32(0x06054b50))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(names.length))
    ..add(_u16(names.length))
    ..add(_u32(directory.length))
    ..add(_u32(directoryStart))
    ..add(_u16(0));
  return out.takeBytes();
}

/// The UTF-8 bytes of entry [name]. Throws [ArgumentError] when [name] is
/// empty, ends in `/`, fails to round-trip through UTF-8, or encodes past
/// 0xFFFF bytes. Propagates whatever [checkEntryPath] throws on a [name]
/// it refuses.
List<int> _checkedNameBytes(String name) {
  if (name.isEmpty || name.endsWith('/')) {
    throw ArgumentError(
      'files key "${escapeZipText(name)}" must not be empty or end with '
      '"/"',
    );
  }
  checkEntryPath(name);
  final bytes = utf8.encode(name);
  if (utf8.decode(bytes) != name) {
    throw ArgumentError(
      'files key "${escapeZipText(name)}" does not round-trip through '
      'UTF-8',
    );
  }
  if (bytes.length > _max16) {
    throw ArgumentError(
      'files key "${escapeZipText(name)}" encodes past $_max16 bytes',
    );
  }
  return bytes;
}

/// Throws [ArgumentError] naming [what] when [value] is past the zip
/// format's 32-bit field limit, 0xFFFFFFFF.
///
/// Internal: not exported; [writeRemoteZip] calls this on every size and
/// offset field it writes. Public only so a test reaches the boundary
/// without allocating 4 GiB of real content.
void checkRemoteZipFieldFits32(int value, String what) {
  if (value > _max32) {
    throw ArgumentError('$what is $value, past the $_max32 zip limit');
  }
}

int _compareBytes(List<int> a, List<int> b) {
  final shorter = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < shorter; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return a.length.compareTo(b.length);
}

Uint8List _u16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
