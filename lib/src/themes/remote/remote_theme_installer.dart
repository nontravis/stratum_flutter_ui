import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/remote/remote_install_check.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_bundle.dart';
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
  String get sourceId => remoteSourceIdOf(id, generation);
}

/// Runs D2 steps 1 to 10 of FO-04 on a theme zip; the controller runs
/// step 11, the register. Internal: not exported.
abstract final class RemoteThemeInstaller {
  /// The last generation of each id, process-wide, because font
  /// registrations and engine fonts are process-wide.
  static final _generations = <String, int>{};

  /// Runs the install check (steps 1 to 10), then the convert; the
  /// controller runs step 11, the register (FO-04 s03 invariant 16).
  /// Throws [StratumRemoteThemeException] at the first failed step and
  /// changes nothing it does not own.
  static Future<RemoteInstall> prepare(
    StratumRemoteTheme theme, {
    required StratumThemeSource packageDefault,
    StratumThemeSource? appDefault,
  }) async {
    final check = await checkRemoteInstall(
      theme,
      packageDefault: packageDefault,
      appDefault: appDefault,
      parseValues: ThemeParse.run,
      nextGeneration: () =>
          _generations[theme.id] = (_generations[theme.id] ?? 0) + 1,
    );
    return RemoteInstall(
      id: theme.id,
      generation: check.generation,
      config: convertThemeConfig(check.values),
      entries: check.entries,
    );
  }

  /// Forgets every generation.
  @visibleForTesting
  static void reset() => _generations.clear();
}
