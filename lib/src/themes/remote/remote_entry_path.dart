import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

final _driveLetter = RegExp('^[A-Za-z]:');

/// Whether [path] holds a character outside printable ASCII, U+0020 to
/// U+007E: a control character, U+0000 to U+001F or U+007F, or any
/// character past U+007E (FO-04 US-01 FR-02 E14, US-02 FR-01 E10).
bool _outsidePrintableAscii(String path) =>
    path.codeUnits.any((unit) => unit < 0x20 || unit > 0x7E);

/// The characters no Windows name may hold, anywhere in an entry path
/// (FO-04 US-01 FR-02 E01; design FU3, RZF3): `:` takes in the drive
/// letter, and `\` and `/` are refused or split on elsewhere.
const _windowsForbidden = ':<>"|?*';

/// The device names Windows reserves, upper case (FO-04 US-01 FR-02 E01;
/// design FU3, RZF3).
const _reservedDeviceNames = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// Checks one entry path (FO-04 US-01 FR-02 E01, E14) is printable ASCII,
/// canonical, relative, and made of names Windows creates unchanged.
///
/// Every character is U+0020 to U+007E, so no tool that decodes a name's
/// bytes another way reads another name; with a directory entry's one
/// trailing `/` set aside, the path is not empty, holds no `\`, starts
/// with no drive letter, and splits on `/` into segments none of which is
/// empty, `.`, or `..`. Then every segment is a name Windows creates
/// unchanged (design FU3, RZF3): the path holds no `:`, `<`, `>`, `"`,
/// `|`, `?`, or `*`; no segment is dots only, ends in `.` or a space, or
/// is a reserved device name before its first `.`, compared ignoring ASCII
/// letter case, with no space or dot trimmed. Throws `RemoteThemeFailure`
/// `unsafeEntryPath` with the path.
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
  final segments = trimmed.split('/');
  if (trimmed.isEmpty ||
      trimmed.contains(r'\') ||
      _driveLetter.hasMatch(trimmed) ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      'entry "${escapeZipText(path)}" is no canonical relative path',
      path: path,
    );
  }
  final why = _windowsNameFault(trimmed, segments);
  if (why != null) {
    throw RemoteThemeFailure(
      StratumRemoteThemeErrorCode.unsafeEntryPath,
      'entry "${escapeZipText(path)}" $why',
      path: path,
    );
  }
}

/// Why the canonical path [trimmed], split into [segments], holds a name
/// Windows would not create unchanged, or null when every segment is one
/// (FO-04 US-01 FR-02 E01; design FU3, RZF3): rules 3 and 4 read the whole
/// name, then rules 2, 1, and 5 each segment, dots only before a trailing
/// dot so `...` names its own rule.
String? _windowsNameFault(String trimmed, List<String> segments) {
  for (final unit in trimmed.codeUnits) {
    final char = String.fromCharCode(unit);
    if (_windowsForbidden.contains(char)) {
      return 'holds "${escapeZipText(char)}", which no Windows name holds';
    }
  }
  for (final segment in segments) {
    if (segment.codeUnits.every((unit) => unit == 0x2E)) {
      return 'has a segment of dots only, which Windows does not create';
    }
    if (segment.endsWith('.') || segment.endsWith(' ')) {
      return 'has a segment ending in a dot or a space, which Windows drops';
    }
    final device = segment.split('.').first.toUpperCase();
    if (_reservedDeviceNames.contains(device)) {
      return 'names the device $device, which Windows reserves';
    }
  }
  return null;
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
