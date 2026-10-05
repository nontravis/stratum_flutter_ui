import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:stratum_ui/src/themes/remote/remote_entry_path.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_root.dart';

/// Reads a verified theme zip into memory, writing no file (FO-04 US-01
/// FR-02), in the order of D2 steps 4 to 8, stopping at the first failure:
/// a readable zip (`invalidArchive`), the declared entry count and sizes
/// within [maxEntries] and [maxBytes] (`archiveTooLarge`), every entry
/// path safe and no symbolic link (`unsafeEntryPath`), a theme root
/// (`missingThemeFile`), then each entry inflated under one running byte
/// count that stops at [maxBytes] (`archiveTooLarge`), its CRC-32 checked
/// (`invalidArchive`).
///
/// Inflates through `Inflate` into a capped output, never through
/// `ZipFile.decompress`, which on the VM collects a whole entry before
/// its output sees a byte. Returns each file under the theme root by its
/// path relative to that root. An empty zip and a path held twice are
/// `invalidArchive`.
Map<String, Uint8List> readRemoteZip(
  List<int> bytes, {
  required int maxBytes,
  required int maxEntries,
}) {
  final headers = _directory(bytes);
  if (headers.length > maxEntries) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      'the zip holds ${headers.length} entries, past maxEntries $maxEntries',
      measured: headers.length,
    );
  }
  final declared = headers.fold<int>(0, (sum, h) => sum + h.uncompressedSize);
  if (declared > maxBytes) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.archiveTooLarge,
      'the zip declares $declared bytes, past maxBytes $maxBytes',
      measured: declared,
    );
  }
  for (final header in headers) {
    checkEntryPath(header.filename);
    if (isSymbolicLink(
      versionMadeBy: header.versionMadeBy,
      externalAttributes: header.externalFileAttributes,
    )) {
      throw RemoteThemeFailure(
        StratumRemoteThemeErrorCode.unsafeEntryPath,
        'entry "${header.filename}" is a symbolic link',
        path: header.filename,
      );
    }
  }
  final root = findThemeRoot(headers.map((header) => header.filename));
  final entries = <String, Uint8List>{};
  var total = 0;
  for (final header in headers) {
    final name = header.filename;
    if (name.endsWith('/') || isIgnoredEntry(name) || !name.startsWith(root)) {
      continue;
    }
    final data = _inflate(header, maxBytes - total, total, maxBytes);
    total += data.length;
    entries[name.substring(root.length)] = data;
  }
  return entries;
}

List<ZipFileHeader> _directory(List<int> bytes) {
  final ZipDirectory directory;
  try {
    directory = ZipDirectory()..read(InputMemoryStream(bytes));
  } on Object {
    throw _invalid('the bytes are not a readable zip');
  }
  if (directory.filePosition < 0) {
    throw _invalid('the bytes are not a readable zip');
  }
  if (directory.fileHeaders.isEmpty) throw _invalid('the zip is empty');
  final seen = <String>{};
  for (final header in directory.fileHeaders) {
    if (!seen.add(header.filename)) {
      throw RemoteThemeFailure(
        StratumRemoteThemeErrorCode.invalidArchive,
        'entry "${header.filename}" appears twice in the zip',
        path: header.filename,
      );
    }
    if (header.generalPurposeBitFlag & 0x1 != 0) {
      throw _invalid('entry "${header.filename}" is encrypted');
    }
    if (header.compressionMethod != 0 && header.compressionMethod != 8) {
      throw _invalid(
        'entry "${header.filename}" uses compression method '
        '${header.compressionMethod}; only store and deflate are read',
      );
    }
    if (header.file == null) {
      throw _invalid('entry "${header.filename}" has no local header');
    }
  }
  return directory.fileHeaders;
}

Uint8List _inflate(ZipFileHeader header, int room, int before, int maxBytes) {
  final output = _CappedOutput(room);
  try {
    final raw = header.file!.getStream(decompress: false).toUint8List();
    if (header.compressionMethod == 8) {
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
    throw _invalid('entry "${header.filename}" does not inflate');
  }
  final data = Uint8List.fromList(output.getBytes());
  if (getCrc32(data) != header.crc32) {
    throw _invalid('entry "${header.filename}" fails its CRC-32 check');
  }
  return data;
}

RemoteThemeFailure _invalid(String message) =>
    RemoteThemeFailure(StratumRemoteThemeErrorCode.invalidArchive, message);

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
