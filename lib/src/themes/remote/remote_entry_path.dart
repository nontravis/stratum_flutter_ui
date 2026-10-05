import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

final _driveLetter = RegExp('^[A-Za-z]:');

/// Checks one entry path (FO-04 US-01 FR-02 E01): not empty, no leading
/// `/` or `\`, no drive letter, and no `..` that leads above the zip root
/// once segments resolve, `\` counting as a separator. Throws
/// `RemoteThemeFailure` `unsafeEntryPath` with the path.
void checkEntryPath(String path) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.startsWith(r'\') ||
      _driveLetter.hasMatch(path)) {
    throw _unsafe(path);
  }
  var depth = 0;
  for (final segment in path.split(RegExp(r'[/\\]'))) {
    if (segment == '..') {
      depth--;
      if (depth < 0) throw _unsafe(path);
    } else if (segment.isNotEmpty && segment != '.') {
      depth++;
    }
  }
}

/// Whether a central directory header marks a unix symbolic link: made on
/// unix (`versionMadeBy` high byte 3) with file type `0xA000` in the high
/// half of the external attributes.
bool isSymbolicLink({
  required int versionMadeBy,
  required int externalAttributes,
}) => versionMadeBy >> 8 == 3 && (externalAttributes >> 16) & 0xF000 == 0xA000;

RemoteThemeFailure _unsafe(String path) => RemoteThemeFailure(
  StratumRemoteThemeErrorCode.unsafeEntryPath,
  'entry "$path" leaves the zip root',
  path: path,
);
