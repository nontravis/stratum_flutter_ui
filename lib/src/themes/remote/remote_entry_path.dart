import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

final _driveLetter = RegExp('^[A-Za-z]:');

/// Whether [path] holds a character outside printable ASCII, U+0020 to
/// U+007E: a control character, U+0000 to U+001F or U+007F, or any
/// character past U+007E (FO-04 US-01 FR-02 E14, US-02 FR-01 E10).
bool _outsidePrintableAscii(String path) =>
    path.codeUnits.any((unit) => unit < 0x20 || unit > 0x7E);

/// Checks one entry path (FO-04 US-01 FR-02 E01, E14) is printable ASCII,
/// canonical, and relative.
///
/// Every character is U+0020 to U+007E, so no tool that decodes a name's
/// bytes another way reads another name; with a directory entry's one
/// trailing `/` set aside, the path is not empty, holds no `\`, starts
/// with no drive letter, and splits on `/` into segments none of which is
/// empty, `.`, or `..`. Throws `RemoteThemeFailure` `unsafeEntryPath` with
/// the path.
void checkEntryPath(String path) {
  if (_outsidePrintableAscii(path)) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      'entry "${escapeZipText(path)}" holds a character outside printable '
      'ASCII, U+0020 to U+007E',
      path: path,
    );
  }
  final trimmed = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed.isEmpty ||
      trimmed.contains(r'\') ||
      _driveLetter.hasMatch(trimmed) ||
      trimmed
          .split('/')
          .any(
            (segment) => segment.isEmpty || segment == '.' || segment == '..',
          )) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      'entry "${escapeZipText(path)}" is no canonical relative path',
      path: path,
    );
  }
}

/// The hosts whose attributes the install reads, the high byte of an
/// entry's central version made by (design Z6, RZ12): 0, MS-DOS and
/// Windows, as Java's `ZipOutputStream`, the JDK's `jar`, and Python's
/// `zipfile` on Windows write it, and 3, Unix and macOS, as Finder,
/// Info-ZIP, `tar`, Python's `zipfile`, and `pack` write it.
const _allowedHosts = {0, 3};

/// The low attribute bits the install allows on any entry (design Z6,
/// RZ12): the MS-DOS read-only bit 0x01 and archive bit 0x20, Finder's
/// marker 0x4000, and 7-Zip's marker 0x8000. The MS-DOS folder attribute
/// 0x10 is allowed on a path ending in `/` only.
const int _allowedLowBits = 0x01 | 0x20 | 0x4000 | 0x8000;

/// Checks the host and attributes of the entry at [path] (FO-04 US-01
/// FR-02 E01, E13; design Z6, RZ9, RZ12): [host], the high byte of its
/// central version made by, is 0 or 3; the MS-DOS folder attribute, bit
/// `0x10`, sits only on a path ending in `/`, since a tool such as
/// libarchive reads it as a folder; the file type, the high 16 bits of
/// [externalAttributes] masked by `0xF000`, is none or `S_IFDIR`
/// (`0x4000`) on a path ending in `/`, none or `S_IFREG` (`0x8000`) on any
/// other, so a symbolic link, and a folder type on a file's name, are
/// refused; beside the type, the high 16 bits hold only permission bits
/// within `0o777`, so setuid, setgid, and sticky are refused; and the low
/// 16 bits hold only [_allowedLowBits] and that folder attribute, so the
/// volume-label bit 0x08, which UnZip skips an entry for, is refused. Each
/// rule reads the same on either host. Throws `RemoteThemeFailure`
/// `unsafeEntryPath` with the path.
void checkEntryFileType(
  String path, {
  required int externalAttributes,
  required int host,
}) {
  final folder = path.endsWith('/');
  if (!_allowedHosts.contains(host)) {
    throw _unsafeAttributes(
      path,
      'was made on host $host; the install reads only hosts 0 (MS-DOS and '
      'Windows) and 3 (Unix and macOS)',
    );
  }
  if (!folder && externalAttributes & 0x10 != 0) {
    throw _unsafeAttributes(
      path,
      'carries the MS-DOS folder attribute, not a file',
    );
  }
  final type = (externalAttributes >> 16) & 0xF000;
  if (type != 0 && type != (folder ? 0x4000 : 0x8000)) {
    throw _unsafeAttributes(
      path,
      'has file type 0x${type.toRadixString(16)}, not '
      '${folder ? 'a folder' : 'a file'}',
    );
  }
  if ((externalAttributes >> 16) & 0x0E00 != 0) {
    throw _unsafeAttributes(path, 'carries the setuid, setgid, or sticky bit');
  }
  final other = externalAttributes & 0xFFFF & ~(_allowedLowBits | 0x10);
  if (other != 0) {
    throw _unsafeAttributes(
      path,
      'carries the MS-DOS attribute bits '
      '0x${other.toRadixString(16).padLeft(4, '0')}, which the install '
      'does not allow',
    );
  }
}

/// The `unsafeEntryPath` failure for the entry at [path], saying [why].
RemoteThemeFailure _unsafeAttributes(String path, String why) =>
    RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      'entry "${escapeZipText(path)}" $why',
      path: path,
    );
