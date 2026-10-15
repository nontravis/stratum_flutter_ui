export 'package:stratum_ui/src/themes/config/escape_text.dart'
    show escapeZipText;

/// Why an install from a theme zip failed: the `code` of
/// `StratumRemoteThemeException`, one value per row of the FO-04 error
/// catalog.
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
