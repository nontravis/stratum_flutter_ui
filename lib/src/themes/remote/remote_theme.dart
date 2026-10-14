import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';

/// A theme zip the app downloaded, with the checksum it fetched from its
/// own API, never from a file beside the zip (FO-04 US-01 FR-01, FR-02).
///
/// Hand it to `StratumThemeController.install`, or to `preload` and
/// `StratumThemePreloader` as `remoteThemes`. Ask the server for the zip of
/// `StratumSchemaVersion.current`: a zip of a newer schema is refused.
@immutable
class StratumRemoteTheme {
  const new({
    required this.id,
    required this.bytes,
    required this.checksum,
    this.maxBytes = defaultMaxBytes,
    this.maxEntries = defaultMaxEntries,
  });

  /// The default cap on the total extracted size: 20 MB.
  static const int defaultMaxBytes = 20 * 1024 * 1024;

  /// The default cap on the entry count.
  static const defaultMaxEntries = 200;

  /// The `<id>` of `<id>.zip`: only `a-z`, `0-9`, `-`, and `_`, and never
  /// `default`. The theme registers under it, replacing an earlier install
  /// of that id, or a bundled theme of that id, for the app's run.
  final String id;

  /// The whole zip as the app downloaded and kept it.
  final Uint8List bytes;

  /// The expected checksum: `sha256:` followed by 64 hex digits.
  final String checksum;

  /// The cap on the total extracted size, in bytes.
  final int maxBytes;

  /// The cap on the entry count.
  final int maxEntries;

  @override
  String toString() => 'StratumRemoteTheme($id, ${bytes.length} bytes)';
}

/// Thrown by `StratumThemeController.install` for a theme zip it refused,
/// and handed to `onRemoteThemeError` for a kept zip that failed at
/// preload; nothing registers and the active theme stays (FO-04 US-01).
@immutable
class StratumRemoteThemeException implements Exception {
  const new({
    required this.code,
    required this.id,
    required this.message,
    this.path,
    this.measured,
    this.formatException,
  });

  /// Which step failed; see `StratumRemoteThemeErrorCode`.
  final StratumRemoteThemeErrorCode code;

  /// The id of the refused zip.
  final String id;

  /// What failed, for a person reading the log.
  final String message;

  /// The entry path exactly as the zip holds it, for `unsafeEntryPath`,
  /// `missingEntry`, and an `invalidArchive` path held twice: untrusted
  /// text the app escapes before it logs or shows it.
  final String? path;

  /// The measured entry count or size, for `archiveTooLarge`.
  final int? measured;

  /// FO-01's report with every problem and its yaml path, for
  /// `themeFormat`.
  final StratumThemeFormatException? formatException;

  @override
  String toString() =>
      'StratumRemoteThemeException(${code.key}) "${escapeZipText(id)}": '
      '$message';
}
