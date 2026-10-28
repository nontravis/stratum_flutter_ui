import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:stratum_ui/src/themes/remote/remote_entry_path.dart';
import 'package:stratum_ui/src/themes/remote/remote_inflate.dart';
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
/// FR-02), parsing the container itself and inflating through
/// [inflateRaw]; `archive` supplies only `getCrc32` (design RZ11).
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
/// - every entry, those it never reads included, inflated from its own
///   span under one running byte count that stops at [maxBytes]
///   (`archiveTooLarge`), its output as long as its declared size, its
///   deflate stream ending at its data's last byte, and its CRC-32
///   checked (`invalidArchive`, or `unsafeEntryPath` for a folder entry);
///   the output of an entry it does not keep is dropped.
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
    checkEntryFileType(
      entry.name,
      externalAttributes: entry.attributes,
      host: entry.host,
    );
    entry.checkFolderEntry();
  }
  final root = findThemeRoot(entries.map((entry) => entry.name));
  final files = <String, Uint8List>{};
  final unread = <String>[];
  var total = 0;
  final budget = HuffmanBlockBudget();
  for (final span in spans) {
    final content = _inflate(data, span, total, maxBytes, budget);
    total += content.length;
    final name = span.entry.name;
    final folder = name.endsWith('/');
    if (isIgnoredEntry(name) || (!folder && !name.startsWith(root))) {
      unread.add(name);
      continue;
    }
    if (folder) continue;
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
/// extra field is a whole run of records of the ids the install allows,
/// a data descriptor sits only where flags bit 3
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

/// Inflates [span] from its own bytes only, through [inflateRaw], into an
/// output capped at the [maxBytes] left after [before] bytes (FO-04 US-01
/// FR-02 E07, E10, E13; design Z5, RZ11): refuses, through
/// [_Entry.mismatch], a deflate stream that is malformed anywhere, does
/// not end at its data's last byte, or ends before its final block; an
/// output of another length than its declared size; and a CRC-32
/// mismatch.
Uint8List _inflate(
  Uint8List data,
  _Span span,
  int before,
  int maxBytes,
  HuffmanBlockBudget budget,
) {
  final entry = span.entry;
  final raw = Uint8List.sublistView(
    data,
    span.start,
    span.start + entry.compressedSize,
  );
  final limit = maxBytes - before;
  final Uint8List content;
  try {
    if (entry.method == 8) {
      content = inflateRaw(
        raw,
        sizeHint: entry.declaredSize,
        limit: limit,
        budget: budget,
      );
    } else {
      if (raw.length > limit) throw InflateLimitReached(raw.length);
      content = Uint8List.fromList(raw);
    }
  } on InflateLimitReached catch (reached) {
    final measured = before + reached.measured;
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      'the zip expands to at least $measured bytes, past maxBytes $maxBytes',
      measured: measured,
    );
  } on InflateFailure catch (failure) {
    throw entry.mismatch(failure.reason);
  }
  if (content.length != entry.declaredSize) {
    throw entry.mismatch(
      'inflates to ${content.length} bytes, not the ${entry.declaredSize} '
      'its header declares',
    );
  }
  if (getCrc32(content) != entry.crc) {
    throw entry.mismatch('fails its CRC-32 check');
  }
  return content;
}

// MARK: - Helpers

RemoteThemeFailure _invalid(String message) =>
    RemoteThemeFailure(StratumRemoteThemeErrorCode.invalidArchive, message);

int _u16(ByteData view, int at) => view.getUint16(at, Endian.little);

int _u32(ByteData view, int at) => view.getUint32(at, Endian.little);

/// The extra-field record ids the install allows (design Z3, RZ9): NTFS
/// times (0x000a), the extended timestamp (0x5455), Info-ZIP's old Unix
/// record, which Finder writes (0x5855), Info-ZIP's Unix owner ids
/// (0x7875), and the jar marker (0xcafe).
const _allowedExtraIds = {0x000a, 0x5455, 0x5855, 0x7875, 0xcafe};

/// Whether the [size]-byte body at [at] of an extra-field record of the
/// allowed [id] fills EITHER of that id's two layouts, the local header's
/// or the central one (FO-04 US-01 FR-02 E02, s03 INV-14; design
/// FU4, RZF4). A tool that copies one header's record into the other
/// unchanged, such as Python's `zipfile` or Java's `ZipOutputStream`,
/// writes a body that fills only one of the two layouts; this reads
/// either, never a mix of their bytes. Only the length and the flag,
/// version, and size bytes that fix a shape are judged, never a time, a
/// user or group id, or a reserved byte:
/// - 0x000a: 4 reserved bytes, then tag 0x0001 of size 24, 32 bytes in
///   all, the same on both layouts (APPNOTE 4.5.5);
/// - 0x5455: a flags byte with bits 3 to 7 clear, then 4 bytes for each
///   of bits 0 to 2 set (the local layout) or 4 bytes only when bit 0 is
///   set (the central layout);
/// - 0x5855: 8 bytes (both layouts) or 12 (the local layout);
/// - 0x7875: version 1, a user-id size, the user id, a group-id size, the
///   group id, the same on both layouts;
/// - 0xcafe: empty, the same on both layouts.
bool _fitsExtraLayout(ByteData view, int id, int at, int size) {
  int byte(int offset) => view.getUint8(at + offset);
  switch (id) {
    case 0x000a:
      return size == 32 &&
          _u16(view, at + 4) == 0x0001 &&
          _u16(view, at + 6) == 24;
    case 0x5455:
      if (size < 1 || byte(0) & 0xF8 != 0) return false;
      final flags = byte(0);
      final localTimes =
          (flags & 0x01) + (flags >> 1 & 0x01) + (flags >> 2 & 0x01);
      return size == 1 + 4 * localTimes || size == 1 + 4 * (flags & 0x01);
    case 0x5855:
      return size == 8 || size == 12;
    case 0x7875:
      return size >= 3 &&
          byte(0) == 1 &&
          size >= 3 + byte(1) &&
          size == 3 + byte(1) + byte(2 + byte(1));
    case 0xcafe:
      return size == 0;
  }
  return false;
}

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
    required this.host,
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
      host: data[at + 5],
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

  /// The host that made the entry, the high byte of its central version
  /// made by (design Z6, RZ12).
  final int host;

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

  /// Refuses an entry whose name ends in `/` unless its declared size and
  /// CRC-32 are 0 (FO-04 US-01 FR-02 E13); its file type is
  /// [checkEntryFileType]'s, and that its data holds no bytes, stored with
  /// a compressed size of 0 or any deflate stream that inflates to
  /// nothing, is proved by `_inflate`.
  void checkFolderEntry() {
    if (!name.endsWith('/') || (declaredSize == 0 && crc == 0)) return;
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      '$label ends with "/" but declares bytes',
      path: name,
    );
  }

  /// The failure for this entry's data, saying [why]: `unsafeEntryPath`
  /// with the path for a folder entry (E13), else `invalidArchive` (E10).
  RemoteThemeFailure mismatch(String why) => name.endsWith('/')
      ? RemoteThemeFailure(
          StratumRemoteThemeErrorCode.unsafeEntryPath,
          '$label ends with "/" but its data $why',
          path: name,
        )
      : _invalid('$label $why');

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
  /// each of an id in [_allowedExtraIds] (design Z3, RZ9), so a ZIP64
  /// record (0x0001), an Info-ZIP Unicode Path record (0x7075), and a
  /// record that tells another tool a file type, such as libarchive's
  /// 0x6c78, are refused; and each record's body fills either of its
  /// id's two layouts, [_fitsExtraLayout] (design FU4, RZF4).
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
      final hex = '0x${id.toRadixString(16).padLeft(4, '0')}';
      if (!_allowedExtraIds.contains(id)) {
        throw _invalid(
          'the $where extra field of $label holds a record of id $hex, '
          'which the install does not read',
        );
      }
      final size = _u16(view, i + 2);
      if (!_fitsExtraLayout(view, id, i + 4, size)) {
        throw _invalid(
          'the $where extra field of $label holds a record of id '
          '$hex whose $size-byte body fits no layout of that id',
        );
      }
      i += 4 + size;
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
