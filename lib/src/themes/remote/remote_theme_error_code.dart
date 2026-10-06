/// Why an install from a theme zip failed: the `code` of
/// `StratumRemoteThemeException`, one value per row of the FO-04 error
/// catalog (`docs/specs/stratum_ui/themes/remote/s05_errors.md`).
enum StratumRemoteThemeErrorCode {
  /// The id breaks the remote id rule: only `a-z`, `0-9`, `-`, `_`, and
  /// never `default`.
  invalidId,

  /// The checksum text is not `sha256:` and 64 hex digits.
  invalidChecksum,

  /// The SHA-256 of the bytes differs from the checksum.
  checksumMismatch,

  /// The bytes are not a zip the package reads.
  invalidArchive,

  /// The zip passes `maxEntries` or `maxBytes`.
  archiveTooLarge,

  /// An entry path is not a canonical relative path, or an entry is
  /// neither a file nor a folder, such as a symbolic link.
  unsafeEntryPath,

  /// No `theme.yaml` at a theme root.
  missingThemeFile,

  /// The theme file has problems; wraps `StratumThemeFormatException`.
  themeFormat,

  /// A font file or asset file the theme file names is not in the zip.
  missingEntry;

  static final _capital = RegExp('[A-Z]');

  /// The catalog code, the name in snake_case, such as `invalid_id`.
  String get key =>
      name.replaceAllMapped(_capital, (match) => '_${match[0]!.toLowerCase()}');
}

/// A failed install step, thrown by the pure-Dart steps of
/// `lib/src/themes/remote/` and turned into `StratumRemoteThemeException`
/// by the installer. Internal: not exported.
final class RemoteThemeFailure implements Exception {
  const new(this.code, this.message, {this.path, this.measured});

  /// The failed step's code.
  final StratumRemoteThemeErrorCode code;

  /// What failed, for a person reading the log.
  final String message;

  /// The entry path as the zip holds it, for `unsafeEntryPath`,
  /// `missingEntry`, and a path held twice: untrusted text, escaped before
  /// it is logged or shown.
  final String? path;

  /// The measured count or size, for `archiveTooLarge`.
  final int? measured;

  @override
  String toString() => 'RemoteThemeFailure(${code.key}): $message';
}

/// The longest escaped zip text a message holds before `...` cuts it.
const _maxZipText = 200;

/// Returns [text], which a zip supplied, fit for a message (FO-04 S-06):
/// each UTF-16 code unit outside U+0020 to U+007E, and each `"` and `\`,
/// as `\u` and four lower-case hex digits; past 200 characters, its first
/// 200 and `...`.
String escapeZipText(String text) {
  final out = StringBuffer();
  for (final unit in text.codeUnits) {
    if (out.length > _maxZipText) break;
    if (unit < 0x20 || unit > 0x7E || unit == 0x22 || unit == 0x5C) {
      out.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    } else {
      out.writeCharCode(unit);
    }
  }
  final escaped = out.toString();
  return escaped.length > _maxZipText
      ? '${escaped.substring(0, _maxZipText)}...'
      : escaped;
}
