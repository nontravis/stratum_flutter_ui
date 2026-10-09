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
/// S1). An empty [files] gives the bare 22-byte end record, a zip
/// `readRemoteZip` and the install check refuse as "the zip is empty";
/// that rule lives once, in the reader, not here.
///
/// Throws [RemoteThemeFailure] coded `unsafeEntryPath` on a key that is
/// empty, ends in `/`, or fails [checkEntryPath], which refuses every
/// character outside printable ASCII (US-02 FR-01 E10); coded
/// `archiveTooLarge` on a name past 0xFFFF characters, more than 0xFFFF
/// entries, or any content length, packed length, header offset, or
/// directory size past 0xFFFFFFFF — the same codes `readRemoteZip`
/// throws, so one catch in `pack` reports either.
Uint8List writeRemoteZip(Map<String, List<int>> files) {
  final names = [
    for (final name in files.keys) (name: name, bytes: _checkedNameBytes(name)),
  ]..sort((a, b) => _compareBytes(a.bytes, b.bytes));
  if (names.length > _max16) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      'the zip holds more than $_max16 entries',
      measured: names.length,
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
    out
      ..add(_u32(0x04034b50))
      ..add(_u16(_needed))
      ..add(_u16(0))
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
      ..add(_u16(0))
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

/// The bytes of entry [name], one per character. Throws
/// [RemoteThemeFailure] coded `unsafeEntryPath` when [name] is empty, ends
/// in `/`, fails [checkEntryPath] (propagated as is), or, defensively,
/// holds a code unit past U+007E even once [checkEntryPath] has passed it
/// — so a future change there can never let a code unit silently narrow
/// to 8 bits; coded `archiveTooLarge` when it is past 0xFFFF characters.
List<int> _checkedNameBytes(String name) {
  if (name.isEmpty || name.endsWith('/')) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      'entry "${escapeZipText(name)}" is empty or ends with "/"',
      path: name,
    );
  }
  checkEntryPath(name);
  if (name.codeUnits.any((unit) => unit > 0x7E)) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      'entry "${escapeZipText(name)}" holds a character outside '
      'printable ASCII, U+0020 to U+007E',
      path: name,
    );
  }
  if (name.length > _max16) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      'entry "${escapeZipText(name)}" is past $_max16 bytes',
      measured: name.length,
    );
  }
  return name.codeUnits;
}

/// Throws [RemoteThemeFailure] coded `archiveTooLarge`, naming [what] in
/// its message, when [value] is past the zip format's 32-bit field limit,
/// 0xFFFFFFFF.
///
/// Internal: not exported; [writeRemoteZip] calls this on every size and
/// offset field it writes. Public only so a test reaches the boundary
/// without allocating 4 GiB of real content.
void checkRemoteZipFieldFits32(int value, String what) {
  if (value > _max32) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      '$what is $value, past the $_max32 zip limit',
      measured: value,
    );
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
