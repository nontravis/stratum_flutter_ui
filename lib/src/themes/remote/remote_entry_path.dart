import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

final _driveLetter = RegExp('^[A-Za-z]:');

/// The file types an entry may carry: none, `S_IFREG`, and `S_IFDIR`.
const _safeFileTypes = {0, 0x8000, 0x4000};

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

/// Checks the file type of the entry at [path], the high 16 bits of
/// [externalAttributes] masked by `0xF000`, is none, a file, or a folder,
/// whatever host made the zip; else throws `RemoteThemeFailure`
/// `unsafeEntryPath` with the path, so a symbolic link is refused.
void checkEntryFileType(String path, {required int externalAttributes}) {
  final type = (externalAttributes >> 16) & 0xF000;
  if (_safeFileTypes.contains(type)) return;
  throw RemoteThemeFailure(
    StratumRemoteThemeErrorCode.unsafeEntryPath,
    'entry "${escapeZipText(path)}" has file type '
    '0x${type.toRadixString(16)}, neither a file nor a folder',
    path: path,
  );
}
