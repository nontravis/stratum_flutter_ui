import 'dart:convert';
import 'dart:typed_data';

import 'package:stratum_ui/src/themes/config/format_error.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';
import 'package:stratum_ui/src/themes/remote/remote_checksum.dart';
import 'package:stratum_ui/src/themes/remote/remote_id.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_reader.dart';

/// Runs theme.yaml stages 1 to 5 of `base` under `layers`: the app passes
/// `ThemeParse.run`, which runs them off the main isolate, and the CLI
/// runs them inline.
typedef ThemeValuesParser = Future<PlainThemeConfig> Function(
  StratumThemeSource base,
  List<StratumThemeSource> layers,
);

/// The first segment of every key the overlay bundle serves from memory.
const remoteFolderRoot = 'stratum-remote';

/// The overlay folder of install [generation] of [id].
String remoteFolderOf(String id, int generation) =>
    '$remoteFolderRoot/$id/$generation';

/// The parse source id of install [generation] of [id], `<id>@<generation>`.
String remoteSourceIdOf(String id, int generation) => '$id@$generation';

/// Decodes a zip entry as strict UTF-8: the one text decode of install step
/// 9 and of every later read, so a theme that installed always reads again
/// (FO-04 s03 INV-4). Throws [FormatException] whose `offset` is the
/// byte where decoding stops.
String decodeRemoteText(Uint8List bytes) => utf8.decode(bytes);

/// A theme zip that passed install steps 1 to 10 (FO-04 s01 Install check).
final class RemoteInstallCheck {
  const new({
    required this.id,
    required this.generation,
    required this.values,
    required this.entries,
    required this.namedFiles,
    required this.unreadEntries,
  });

  final String id;

  /// This check's generation for [id].
  final int generation;

  /// The theme read merged over the package default and the app default,
  /// as plain values.
  final PlainThemeConfig values;

  /// Every file under the theme root, by its path relative to that root.
  final Map<String, Uint8List> entries;

  /// Every path, relative to the theme root, that the zip's own theme file
  /// names as a font file or an asset slot.
  final Set<String> namedFiles;

  /// The zip path of every entry the install never reads: each entry under
  /// `__MACOSX/`, each `.DS_Store`, and each loose file at the zip top
  /// beside a theme root folder (FO-04 s03 CLI warning), in central
  /// directory order.
  final List<String> unreadEntries;

  /// The overlay folder, `stratum-remote/<id>/<generation>`.
  String get folder => remoteFolderOf(id, generation);

  /// The parse source id, `<id>@<generation>`.
  String get sourceId => remoteSourceIdOf(id, generation);
}

/// Runs install steps 1 to 10 of FO-04 on [theme] (s01 Install check), in
/// Flutter-free Dart (the guard in
/// `test/src/themes/flutter_free_imports_test.dart` proves it), for the
/// installer and the `stratum_theme` CLI alike: the id rule, the checksum
/// text, one private copy of the bytes and its SHA-256, the zip within its
/// caps, the entry paths and file types, the theme root, the strict UTF-8
/// decode of `theme.yaml` and its stages 1 to 5 over [packageDefault] and
/// [appDefault] through [parseValues], then every font file and asset slot
/// it names.
///
/// Calls [nextGeneration] once, after the zip reads, for this check's
/// generation. Throws `StratumRemoteThemeException` at the first failed
/// step; registers nothing (the controller runs step 11).
Future<RemoteInstallCheck> checkRemoteInstall(
  StratumRemoteTheme theme, {
  required StratumThemeSource packageDefault,
  StratumThemeSource? appDefault,
  required ThemeValuesParser parseValues,
  required int Function() nextGeneration,
}) async {
  final RemoteZipContents read;
  try {
    checkRemoteThemeId(theme.id);
    checkChecksumText(theme.checksum);
    // Step 3: hash and read one private copy, so the bytes read are the
    // bytes hashed and the app's buffer is never written.
    final bytes = Uint8List.fromList(theme.bytes);
    verifyChecksum(theme.checksum, bytes);
    read = readRemoteZip(
      bytes,
      maxBytes: theme.maxBytes,
      maxEntries: theme.maxEntries,
    );
  } on RemoteThemeFailure catch (failure) {
    throw _exception(theme.id, failure);
  }
  final entries = read.files;
  final generation = nextGeneration();
  final folder = remoteFolderOf(theme.id, generation);
  final sourceId = remoteSourceIdOf(theme.id, generation);
  final PlainThemeConfig values;
  try {
    values = await parseValues(packageDefault, [
      ?appDefault,
      StratumThemeSource(
        id: sourceId,
        folder: folder,
        yaml: _decodeThemeFile(entries['theme.yaml']!, sourceId),
      ),
    ]);
  } on StratumThemeFormatException catch (report) {
    throw StratumRemoteThemeException(
      code: StratumRemoteThemeErrorCode.themeFormat,
      id: theme.id,
      message: 'the theme file has ${report.errors.length} problem(s)',
      formatException: report,
    );
  }
  final named = _namedFiles(folder, values);
  for (final path in named) {
    if (!entries.containsKey(path)) {
      throw StratumRemoteThemeException(
        code: StratumRemoteThemeErrorCode.missingEntry,
        id: theme.id,
        message:
            'the theme file names "${escapeZipText(path)}", which the zip '
            'lacks',
        path: path,
      );
    }
  }
  return RemoteInstallCheck(
    id: theme.id,
    generation: generation,
    values: values,
    entries: entries,
    namedFiles: {...named},
    unreadEntries: read.unread,
  );
}

/// Step 10's paths, in the order the theme names them: every font file,
/// then every asset slot, of the zip's own theme file, relative to its
/// root; the merge bases' paths fall outside [folder] and are skipped.
List<String> _namedFiles(String folder, PlainThemeConfig values) => [
  for (final path in [
    for (final font in values.typography.fonts.values) ...font.files,
    for (final asset in values.assets.values) asset.path,
  ])
    if (path.startsWith('$folder/')) path.substring(folder.length + 1),
];

const _lineFeed = 0x0A;

/// Step 9: [bytes] decoded as strict UTF-8; a byte that is not valid UTF-8
/// throws FO-01's report with one `yaml_syntax` problem at the byte where
/// decoding stops (FO-04 s05).
String _decodeThemeFile(Uint8List bytes, String sourceId) {
  try {
    return decodeRemoteText(bytes);
  } on FormatException catch (error) {
    final (line, column) = _position(bytes, error.offset);
    throw StratumThemeFormatException([
      StratumThemeFormatError(
        code: StratumThemeErrorCode.yamlSyntax,
        source: sourceId,
        path: '',
        message: 'not valid UTF-8 text',
        line: line,
        column: column,
      ),
    ]);
  }
}

/// The 1-based line and column of byte [offset] of [bytes], counting
/// line-feed bytes for the line and bytes for the column; both null when
/// [offset] is.
(int?, int?) _position(Uint8List bytes, int? offset) {
  if (offset == null) return (null, null);
  var line = 1;
  var lineStart = 0;
  for (var index = 0; index < offset; index++) {
    if (bytes[index] == _lineFeed) {
      line++;
      lineStart = index + 1;
    }
  }
  return (line, offset - lineStart + 1);
}

/// The public exception for the install step of [id] that failed with
/// [failure], so the internal failure type never reaches the public API.
StratumRemoteThemeException _exception(String id, RemoteThemeFailure failure) =>
    StratumRemoteThemeException(
      code: failure.code,
      id: id,
      message: failure.message,
      path: failure.path,
      measured: failure.measured,
    );
