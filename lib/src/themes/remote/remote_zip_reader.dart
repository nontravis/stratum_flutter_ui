import 'dart:convert';
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

/// Reads a verified theme zip into memory, writing no file (FO-04 US-01
/// FR-02), parsing the container itself; `archive` supplies only `Inflate`
/// and `getCrc32`.
///
/// Runs in the order of D2 steps 4 to 8 and stops at the first failure:
/// - the end record, then one walk of the central directory that stops at
///   entry [maxEntries] + 1 or a declared size sum past [maxBytes]
///   (`archiveTooLarge`), refusing an encrypted entry, a method other than
///   store or deflate, and a path held twice (`invalidArchive`);
/// - the entry count against the end record, then every local header
///   against its central header and no two entries sharing bytes
///   (`invalidArchive`);
/// - every entry path and file type (`unsafeEntryPath`), the theme root
///   (`missingThemeFile`);
/// - each entry under the root inflated from its own span under one
///   running byte count that stops at [maxBytes] (`archiveTooLarge`), its
///   CRC-32 checked (`invalidArchive`).
///
/// Never writes into [bytes]. Returns each file under the theme root by
/// its path relative to that root.
Map<String, Uint8List> readRemoteZip(
  List<int> bytes, {
  required int maxBytes,
  required int maxEntries,
}) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final view = ByteData.sublistView(data);
  final end = _EndRecord.find(view);
  final entries = _walk(data, view, end, maxBytes, maxEntries);
  final spans = _locate(data, view, entries, end.directoryStart);
  for (final entry in entries) {
    checkEntryPath(entry.name);
    checkEntryFileType(entry.name, externalAttributes: entry.attributes);
  }
  final root = findThemeRoot(entries.map((entry) => entry.name));
  final files = <String, Uint8List>{};
  var total = 0;
  for (final span in spans) {
    final name = span.entry.name;
    if (name.endsWith('/') || isIgnoredEntry(name) || !name.startsWith(root)) {
      continue;
    }
    final content = _inflate(data, span, total, maxBytes);
    total += content.length;
    files[name.substring(root.length)] = content;
  }
  return files;
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

/// Checks each entry's local header against its central one and that no
/// two entries share bytes; returns each entry with its data's first byte.
List<_Span> _locate(
  Uint8List data,
  ByteData view,
  List<_Entry> entries,
  int directoryStart,
) {
  final spans = [
    for (final entry in entries)
      (entry: entry, start: entry.dataStart(data, view, directoryStart)),
  ];
  final ordered = [...spans]
    ..sort((a, b) => a.entry.localOffset.compareTo(b.entry.localOffset));
  for (var i = 1; i < ordered.length; i++) {
    final previous = ordered[i - 1];
    if (ordered[i].entry.localOffset <
        previous.start + previous.entry.compressedSize) {
      throw _invalid(
        '${ordered[i].entry.label} shares bytes with '
        '${previous.entry.label}',
      );
    }
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
    required this.directoryStart,
    required this.directorySize,
    required this.count,
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
    return _EndRecord(directoryStart: start, directorySize: size, count: count);
  }

  final int directoryStart;
  final int directorySize;

  /// The entry count the end record declares.
  final int count;
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
      name: utf8.decode(nameBytes, allowMalformed: true),
      nameBytes: nameBytes,
      flags: _u16(view, at + 8),
      method: _u16(view, at + 10),
      crc: _u32(view, at + 16),
      compressedSize: _u32(view, at + 20),
      declaredSize: _u32(view, at + 24),
      attributes: _u32(view, at + 38),
      localOffset: _u32(view, at + 42),
      next: next,
    );
  }

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

  /// Checks this entry's local header matches its central header and its
  /// span ends at or before [directoryStart]; returns its data's first
  /// byte.
  int dataStart(Uint8List data, ByteData view, int directoryStart) {
    final at = localOffset;
    if (at + _localSize > directoryStart || _u32(view, at) != _localSignature) {
      throw _invalid('$label has no local header');
    }
    if (_u16(view, at + 6) & 0x1 != 0) throw _invalid('$label is encrypted');
    if (_u16(view, at + 8) != method) {
      throw _invalid('$label declares another method in its local header');
    }
    final nameLength = _u16(view, at + 26);
    final start = at + _localSize + nameLength + _u16(view, at + 28);
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
    return start;
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
