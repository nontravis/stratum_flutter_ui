import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/remote/remote_checksum.dart';
import 'package:stratum_ui/src/themes/remote/remote_id.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_bundle.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_error_code.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_reader.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';

/// One install that passed D2 steps 1 to 10, ready to register.
final class RemoteInstall {
  const new({
    required this.id,
    required this.generation,
    required this.config,
    required this.entries,
  });

  final String id;

  /// This install's generation for [id], 1 for the first install of the run.
  final int generation;

  /// The theme read merged over the package default and the app's
  /// `default`.
  final StratumThemeConfig config;

  /// Every file under the theme root, by its path relative to that root.
  final Map<String, Uint8List> entries;

  /// The overlay folder, `stratum-remote/<id>/<generation>`.
  String get folder => RemoteThemeBundle.folderOf(id, generation);

  /// The parse source id, `<id>@<generation>`, which every theme font
  /// family of this install carries as its prefix.
  String get sourceId => '$id@$generation';
}

/// Runs D2 steps 1 to 10 of FO-04 on a theme zip; the controller runs
/// step 11, the register. Internal: not exported.
abstract final class RemoteThemeInstaller {
  /// The last generation of each id, process-wide, because font
  /// registrations and engine fonts are process-wide.
  static final _generations = <String, int>{};

  static const _lineFeed = 0x0A;

  /// Checks [theme] and reads it over [packageDefault] and [appDefault];
  /// throws [StratumRemoteThemeException] at the first failed step and
  /// changes nothing it does not own.
  static Future<RemoteInstall> prepare(
    StratumRemoteTheme theme, {
    required StratumThemeSource packageDefault,
    StratumThemeSource? appDefault,
  }) async {
    final Map<String, Uint8List> entries;
    try {
      checkRemoteThemeId(theme.id);
      checkChecksumText(theme.checksum);
      // D2 step 3: hash and read one private copy, so the bytes read are
      // the bytes hashed and the app's buffer is never written.
      final bytes = Uint8List.fromList(theme.bytes);
      verifyChecksum(theme.checksum, bytes);
      entries = readRemoteZip(
        bytes,
        maxBytes: theme.maxBytes,
        maxEntries: theme.maxEntries,
      );
    } on RemoteThemeFailure catch (failure) {
      throw _exception(theme.id, failure);
    }
    final generation = (_generations[theme.id] ?? 0) + 1;
    _generations[theme.id] = generation;
    final folder = RemoteThemeBundle.folderOf(theme.id, generation);
    final sourceId = '${theme.id}@$generation';
    final StratumThemeConfig config;
    try {
      config = convertThemeConfig(
        await ThemeParse.run(packageDefault, [
          ?appDefault,
          StratumThemeSource(
            id: sourceId,
            folder: folder,
            yaml: _decodeThemeFile(entries['theme.yaml']!, sourceId),
          ),
        ]),
      );
    } on StratumThemeFormatException catch (report) {
      throw StratumRemoteThemeException(
        code: StratumRemoteThemeErrorCode.themeFormat,
        id: theme.id,
        message: 'the theme file has ${report.errors.length} problem(s)',
        formatException: report,
      );
    }
    _checkNamedFiles(theme.id, folder, config, entries);
    return RemoteInstall(
      id: theme.id,
      generation: generation,
      config: config,
      entries: entries,
    );
  }

  /// D2 step 9: [bytes] decoded as strict UTF-8; a byte that is not valid
  /// UTF-8 throws FO-01's report with one `yaml_syntax` problem at the byte
  /// where decoding stops (FO-04 s05).
  static String _decodeThemeFile(Uint8List bytes, String sourceId) {
    try {
      return RemoteThemeBundle.decodeText(bytes);
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
  static (int?, int?) _position(Uint8List bytes, int? offset) {
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

  /// D2 step 10: every font file and asset slot file the zip's own theme
  /// file names is in the zip; paths of the merge bases are not checked.
  static void _checkNamedFiles(
    String id,
    String folder,
    StratumThemeConfig config,
    Map<String, Uint8List> entries,
  ) {
    final named = [
      for (final font in config.typography.fonts.values) ...font.files,
      for (final asset in config.assets.values) asset.path,
    ];
    for (final path in named) {
      if (!path.startsWith('$folder/')) continue;
      final relative = path.substring(folder.length + 1);
      if (!entries.containsKey(relative)) {
        throw StratumRemoteThemeException(
          code: StratumRemoteThemeErrorCode.missingEntry,
          id: id,
          message:
              'the theme file names "${escapeZipText(relative)}", which the '
              'zip lacks',
          path: relative,
        );
      }
    }
  }

  /// Forgets every generation.
  @visibleForTesting
  static void reset() => _generations.clear();
}

/// The public exception for the install step of [id] that failed with
/// [failure]; library-private, so the internal failure type never reaches
/// the public API.
StratumRemoteThemeException _exception(String id, RemoteThemeFailure failure) =>
    StratumRemoteThemeException(
      code: failure.code,
      id: id,
      message: failure.message,
      path: failure.path,
      measured: failure.measured,
    );
