import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:stratum_ui/src/themes/remote/remote_entry_path.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_root.dart';

const _endSignature = 0x06054b50;
const _zip64EndSignature = 0x06064b50;
const _zip64LocatorSignature = 0x07064b50;
const _centralSignature = 0x02014b50;
const _localSignature = 0x04034b50;

/// The fixed part of an end record, a central header, and a local header.
const _endSize = 22;
const _centralSize = 46;
const _localSize = 30;
const _zip64LocatorSize = 20;

/// An end record and the longest comment it may carry.
const int _endSearch = _endSize + 0xFFFF;

/// What [readRemoteZip] returns: `files`, each file under the theme root
/// by its path relative to that root, and `unread`, the zip path of every
/// entry the install never reads, in central directory order: each entry
/// under `__MACOSX/`, each `.DS_Store`, and each loose file at the zip top
/// beside a theme root folder (FO-04 s03 CLI warning).
typedef RemoteZipContents = ({
  Map<String, Uint8List> files,
  List<String> unread,
});

/// Reads a verified theme zip into memory, writing no file (FO-04 US-01
/// FR-02), parsing the container itself; `archive` supplies only `Inflate`
/// and `getCrc32`.
///
/// Runs in the order of D2 steps 4 to 8 and stops at the first failure:
/// - the end record, then one walk of the central directory that stops at
///   entry [maxEntries] + 1 or a declared size sum past [maxBytes]
///   (`archiveTooLarge`), refusing an encrypted entry, a method other than
///   store or deflate, and a path held twice (`invalidArchive`);
/// - the entry count against the end record, then the container (design
///   Z1 to Z4): every local header against its central header, every
///   extra field, every data descriptor, and the spans tiling the bytes
///   before the directory (`invalidArchive`);
/// - every entry path, file type, and `/`-ending folder entry
///   (`unsafeEntryPath`), the theme root (`missingThemeFile`);
/// - each entry under the root inflated from its own span under one
///   running byte count that stops at [maxBytes] (`archiveTooLarge`), its
///   CRC-32 checked (`invalidArchive`).
///
/// Never writes into [bytes]. Returns the files under the theme root by
/// their path relative to that root, and the entries it never reads
/// ([RemoteZipContents]).
RemoteZipContents readRemoteZip(
  List<int> bytes, {
  required int maxBytes,
  required int maxEntries,
}) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final view = ByteData.sublistView(data);
  final end = _EndRecord.find(view);
  final entries = _walk(data, view, end, maxBytes, maxEntries);
  final spans = _locate(data, view, entries, end);
  for (final span in spans) {
    final entry = span.entry;
    checkEntryPath(entry.name);
    checkEntryFileType(entry.name, externalAttributes: entry.attributes);
    entry.checkFolderEntry(data, span.start);
  }
  final root = findThemeRoot(entries.map((entry) => entry.name));
  final files = <String, Uint8List>{};
  final unread = <String>[];
  var total = 0;
  for (final span in spans) {
    final name = span.entry.name;
    final folder = name.endsWith('/');
    if (isIgnoredEntry(name) || (!folder && !name.startsWith(root))) {
      unread.add(name);
      continue;
    }
    if (folder) continue;
    final content = _inflate(data, span, total, maxBytes);
    total += content.length;
    files[name.substring(root.length)] = content;
  }
  return (files: files, unread: unread);
}

// MARK: - Central directory

/// Walks the central directory in its order, checking each entry as it is
/// reached; reads no local header.
List<_Entry> _walk(
  Uint8List data,
  ByteData view,
  _EndRecord end,
  int maxBytes,
  int maxEntries,
) {
  final entries = <_Entry>[];
  final seen = <String>{};
  final stop = end.directoryStart + end.directorySize;
  var declared = 0;
  var at = end.directoryStart;
  while (at < stop) {
    if (entries.length >= maxEntries) {
      throw RemoteThemeFailure(
        StratumRemoteThemeErrorCode.archiveTooLarge,
        'the zip holds more than maxEntries $maxEntries entries',
        measured: entries.length + 1,
      );
    }
    final entry = _Entry.read(data, view, at, stop)..checkReadable();
    if (!seen.add(entry.name)) {
      throw RemoteThemeFailure(
        StratumRemoteThemeErrorCode.invalidArchive,
        '${entry.label} appears twice in the zip',
        path: entry.name,
      );
    }
    declared += entry.declaredSize;
    if (declared > maxBytes) {
      throw RemoteThemeFailure(
        StratumRemoteThemeErrorCode.archiveTooLarge,
        'the zip declares at least $declared bytes, past maxBytes $maxBytes',
        measured: declared,
      );
    }
    entries.add(entry);
    at = entry.next;
  }
  if (entries.length != end.count) {
    throw _invalid(
      'the end record counts ${end.count} entries; the central directory '
      'holds ${entries.length}',
    );
  }
  if (entries.isEmpty) throw _invalid('the zip is empty');
  return entries;
}

// MARK: - Local headers

/// Checks the container after the central walk (FO-04 US-01 FR-02 E02,
/// design Z1 to Z4): each local header equals its central header, every
/// extra field is a whole run of records with no ZIP64 or Info-ZIP
/// Unicode Path record, a data descriptor sits only where flags bit 3
/// puts one and equals the directory, and the entries' spans lie back to
/// back from offset 0 to the central directory, which ends where the end
/// record starts, with no byte after the end record's comment. Returns
/// each entry with its data's first byte, in central directory order.
List<_Span> _locate(
  Uint8List data,
  ByteData view,
  List<_Entry> entries,
  _EndRecord end,
) {
  if (end.directoryStart + end.directorySize != end.at) {
    throw _invalid(
      'the central directory does not end where the end record starts',
    );
  }
  if (end.at + _endSize + end.commentLength != data.length) {
    throw _invalid('bytes follow the end record');
  }
  final spans = [
    for (final entry in entries)
      (entry: entry, start: entry.dataStart(data, view, end.directoryStart)),
  ];
  final ordered = [...spans]
    ..sort((a, b) => a.entry.localOffset.compareTo(b.entry.localOffset));
  if (ordered.first.entry.localOffset != 0) {
    throw _invalid(
      'bytes before ${ordered.first.entry.label} belong to no entry',
    );
  }
  for (var i = 0; i < ordered.length; i++) {
    final (:entry, :start) = ordered[i];
    final next = i + 1 < ordered.length
        ? ordered[i + 1].entry.localOffset
        : end.directoryStart;
    entry.checkTail(view, start + entry.compressedSize, next);
  }
  return spans;
}

// MARK: - Inflate

/// Inflates [span] from its own bytes only into an output capped at the
/// [maxBytes] left after [before] bytes, then checks its CRC-32.
///
/// Inflates through `Inflate` into a capped output, never through
/// `ZipFile.decompress`, which on the VM collects a whole entry before
/// its output sees a byte.
Uint8List _inflate(Uint8List data, _Span span, int before, int maxBytes) {
  final entry = span.entry;
  final raw = Uint8List.sublistView(
    data,
    span.start,
    span.start + entry.compressedSize,
  );
  final output = _CappedOutput(maxBytes - before);
  try {
    if (entry.method == 8) {
      Inflate(raw, output: output);
    } else {
      output.writeBytes(raw);
    }
  } on _CapReached catch (reached) {
    final measured = before + reached.measured;
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      'the zip expands to at least $measured bytes, past maxBytes $maxBytes',
      measured: measured,
    );
  } on Object {
    throw _invalid('${entry.label} does not inflate');
  }
  final content = Uint8List.fromList(output.getBytes());
  if (getCrc32(content) != entry.crc) {
    throw _invalid('${entry.label} fails its CRC-32 check');
  }
  return content;
}

// MARK: - Helpers

RemoteThemeFailure _invalid(String message) =>
    RemoteThemeFailure(StratumRemoteThemeErrorCode.invalidArchive, message);

int _u16(ByteData view, int at) => view.getUint16(at, Endian.little);

int _u32(ByteData view, int at) => view.getUint32(at, Endian.little);

/// An entry with the first byte of its data.
typedef _Span = ({_Entry entry, int start});

/// The end of central directory record: where the directory lies and how
/// many entries it holds.
final class _EndRecord {
  const new({
    required this.at,
    required this.directoryStart,
    required this.directorySize,
    required this.count,
    required this.commentLength,
  });

  /// Finds the end record nearest the end within the last 65 557 bytes,
  /// refusing ZIP64, a disk but the first, and a directory outside the
  /// bytes before it.
  factory find(ByteData view) {
    final last = view.lengthInBytes - _endSize;
    final first = max(0, view.lengthInBytes - _endSearch);
    for (var at = last; at >= first; at--) {
      if (_u32(view, at) == _endSignature) return _EndRecord._read(view, at);
    }
    throw _invalid('the bytes are not a readable zip');
  }

  factory _read(ByteData view, int at) {
    final count = _u16(view, at + 10);
    if (_u16(view, at + 4) != 0 ||
        _u16(view, at + 6) != 0 ||
        _u16(view, at + 8) != count) {
      throw _invalid('the zip spans more than one disk');
    }
    if (at >= _zip64LocatorSize &&
        _u32(view, at - _zip64LocatorSize) == _zip64LocatorSignature) {
      throw _invalid('the zip is a ZIP64 zip');
    }
    final start = _u32(view, at + 16);
    final size = _u32(view, at + 12);
    if (start + size > at) {
      throw _invalid('the central directory lies outside the zip');
    }
    if (start + size + 4 <= at &&
        _u32(view, start + size) == _zip64EndSignature) {
      throw _invalid('the zip is a ZIP64 zip');
    }
    return _EndRecord(
      at: at,
      directoryStart: start,
      directorySize: size,
      count: count,
      commentLength: _u16(view, at + 20),
    );
  }

  /// Where the end record starts.
  final int at;

  final int directoryStart;
  final int directorySize;

  /// The entry count the end record declares.
  final int count;

  /// The length its comment field declares.
  final int commentLength;
}

/// One central directory header, its fields as the zip declares them.
final class _Entry {
  const new({
    required this.name,
    required this.nameBytes,
    required this.flags,
    required this.method,
    required this.crc,
    required this.compressedSize,
    required this.declaredSize,
    required this.attributes,
    required this.localOffset,
    required this.next,
    required this.centralExtraAt,
    required this.centralExtraLength,
  });

  /// Reads the whole central header at [at], which must end at or before
  /// [stop]; else throws `invalidArchive`.
  factory read(Uint8List data, ByteData view, int at, int stop) {
    if (at + _centralSize > stop || _u32(view, at) != _centralSignature) {
      throw _invalid('the central directory holds no whole header');
    }
    final nameLength = _u16(view, at + 28);
    final next =
        at +
        _centralSize +
        nameLength +
        _u16(view, at + 30) +
        _u16(view, at + 32);
    if (next > stop) {
      throw _invalid('the central directory holds no whole header');
    }
    final nameBytes = Uint8List.sublistView(
      data,
      at + _centralSize,
      at + _centralSize + nameLength,
    );
    return _Entry(
      name: String.fromCharCodes(nameBytes),
      nameBytes: nameBytes,
      flags: _u16(view, at + 8),
      method: _u16(view, at + 10),
      crc: _u32(view, at + 16),
      compressedSize: _u32(view, at + 20),
      declaredSize: _u32(view, at + 24),
      attributes: _u32(view, at + 38),
      localOffset: _u32(view, at + 42),
      next: next,
      centralExtraAt: at + _centralSize + nameLength,
      centralExtraLength: _u16(view, at + 30),
    );
  }

  /// The name read one byte per character (FO-04 US-01 FR-02 E14), so a
  /// byte of 0x80 or more stays one character, which [checkEntryPath]
  /// refuses.
  final String name;
  final Uint8List nameBytes;
  final int flags;
  final int method;
  final int crc;
  final int compressedSize;

  /// The unsigned 32-bit extracted size; no ZIP64 field is read.
  final int declaredSize;

  /// The external file attributes.
  final int attributes;
  final int localOffset;

  /// The offset of the next central header.
  final int next;

  /// Where this entry's central extra field starts, and its length.
  final int centralExtraAt;
  final int centralExtraLength;

  /// This entry named for a message, its path escaped.
  String get label => 'entry "${escapeZipText(name)}"';

  /// Refuses an encrypted entry and a method other than store or deflate.
  void checkReadable() {
    if (flags & 0x1 != 0) throw _invalid('$label is encrypted');
    if (method != 0 && method != 8) {
      throw _invalid(
        '$label uses compression method $method; only store and deflate '
        'are read',
      );
    }
  }

  /// Refuses an entry whose name ends in `/` unless it holds no bytes:
  /// file type none or `S_IFDIR`, a declared extracted size of 0, and
  /// compressed data that is either empty (compressed size 0) or the
  /// 2-byte empty deflate stream `03 00` (method deflate, compressed
  /// size 2), what Java's `ZipOutputStream` writes for a folder (FO-04
  /// US-01 FR-02 E13), so no other bytes hide under a name the reader
  /// skips. [data] and [start] are this entry's own span, from `_locate`.
  void checkFolderEntry(Uint8List data, int start) {
    if (!name.endsWith('/')) return;
    final type = (attributes >> 16) & 0xF000;
    final folder = type == 0 || type == 0x4000;
    final noBytes =
        compressedSize == 0 ||
        (method == 8 &&
            compressedSize == 2 &&
            data[start] == 0x03 &&
            data[start + 1] == 0x00);
    if (folder && declaredSize == 0 && noBytes) return;
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      '$label ends with "/" but is no folder entry with no bytes',
      path: name,
    );
  }

  /// Checks this entry's local header equals its central header (design
  /// Z2): flags, method, CRC-32, both sizes, and name, the three numbers
  /// allowed to be all 0 with flags bit 3; a data descriptor only on a
  /// deflate entry; both extra fields whole (Z3); and its data ends at or
  /// before [directoryStart]. Returns its data's first byte.
  int dataStart(Uint8List data, ByteData view, int directoryStart) {
    final at = localOffset;
    if (at + _localSize > directoryStart || _u32(view, at) != _localSignature) {
      throw _invalid('$label has no local header');
    }
    final localFlags = _u16(view, at + 6);
    if (localFlags & 0x1 != 0) throw _invalid('$label is encrypted');
    if (localFlags != flags) {
      throw _invalid('$label declares other flags in its local header');
    }
    if (_u16(view, at + 8) != method) {
      throw _invalid('$label declares another method in its local header');
    }
    if (flags & 0x8 != 0 && method != 8) {
      throw _invalid('$label is stored with a data descriptor');
    }
    final localCrc = _u32(view, at + 14);
    final localPacked = _u32(view, at + 18);
    final localSize = _u32(view, at + 22);
    final deferred =
        flags & 0x8 != 0 && localCrc == 0 && localPacked == 0 && localSize == 0;
    if (!deferred &&
        (localCrc != crc ||
            localPacked != compressedSize ||
            localSize != declaredSize)) {
      throw _invalid(
        '$label declares another CRC-32 or size in its local '
        'header',
      );
    }
    final nameLength = _u16(view, at + 26);
    final extraLength = _u16(view, at + 28);
    final start = at + _localSize + nameLength + extraLength;
    if (start + compressedSize > directoryStart) {
      throw _invalid('$label runs past the bytes before the directory');
    }
    final localName = Uint8List.sublistView(
      data,
      at + _localSize,
      at + _localSize + nameLength,
    );
    if (!_sameBytes(localName, nameBytes)) {
      throw _invalid('$label holds another name in its local header');
    }
    _checkExtra(view, at + _localSize + nameLength, extraLength, 'local');
    _checkExtra(view, centralExtraAt, centralExtraLength, 'central');
    return start;
  }

  /// Checks the bytes from this entry's data end, [dataEnd], to the next
  /// span or the central directory, [next] (design Z1, Z4): none, unless
  /// flags bit 3 is set; then exactly its data descriptor, 12 bytes
  /// (CRC-32, compressed size, size) or 16 starting `50 4b 07 08`, equal
  /// to the directory. Refuses a 12-byte descriptor whose CRC-32 field
  /// happens to be `50 4b 07 08`: a tool that peeks for the signature,
  /// such as Java's `ZipInputStream`, would then read 16 bytes instead
  /// and disagree with this reader.
  void checkTail(ByteData view, int dataEnd, int next) {
    if (next < dataEnd) throw _invalid('$label shares bytes with the next');
    final gap = next - dataEnd;
    if (flags & 0x8 == 0) {
      if (gap != 0) throw _invalid('bytes after $label belong to no entry');
      return;
    }
    final int at;
    if (gap == 16 && _u32(view, dataEnd) == 0x08074b50) {
      at = dataEnd + 4;
    } else if (gap == 12) {
      if (_u32(view, dataEnd) == 0x08074b50) {
        throw _invalid(
          '$label has an unsigned 12-byte data descriptor starting with '
          'the signed signature',
        );
      }
      at = dataEnd;
    } else {
      throw _invalid(
        '$label has no 12-byte or signed 16-byte data '
        'descriptor',
      );
    }
    if (_u32(view, at) != crc ||
        _u32(view, at + 4) != compressedSize ||
        _u32(view, at + 8) != declaredSize) {
      throw _invalid(
        'the data descriptor of $label differs from the '
        'directory',
      );
    }
  }

  /// Checks the [where] extra field of [length] bytes at [at] is a run of
  /// whole records, a 2-byte id, a 2-byte length, and that many bytes,
  /// holding no ZIP64 record (0x0001) and no Info-ZIP Unicode Path record
  /// (0x7075); every other record is ignored (design Z3).
  void _checkExtra(ByteData view, int at, int length, String where) {
    final end = at + length;
    var i = at;
    while (i < end) {
      if (i + 4 > end || i + 4 + _u16(view, i + 2) > end) {
        throw _invalid(
          'the $where extra field of $label holds no whole '
          'record',
        );
      }
      final id = _u16(view, i);
      if (id == 0x0001 || id == 0x7075) {
        throw _invalid(
          'the $where extra field of $label holds a '
          '${id == 0x0001 ? 'ZIP64' : 'Info-ZIP Unicode Path'} record',
        );
      }
      i += 4 + _u16(view, i + 2);
    }
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class _CapReached implements Exception {
  const new(this.measured);
  final int measured;
}

/// An output that refuses any write that would take it past [_cap] bytes,
/// so inflating stops at the cap whatever the header declared.
final class _CappedOutput extends OutputMemoryStream {
  new(this._cap);

  final int _cap;

  void _room(int count) {
    if (length + count > _cap) throw _CapReached(length + count);
  }

  @override
  void writeByte(int value) {
    _room(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _room(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _room(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _room(count);
    super.writeBackReference(distance, count);
  }
}
