import 'package:stratum_ui/src/src.dart';

/// Test seam for the engine call a `theme` font needs (see
/// `StratumFontSource.theme`): registering its file bytes under its family
/// through Flutter's [FontLoader], plus the registrations made so far.
///
/// Kept out of `lib/src/themes/themes.dart` and every barrel it feeds, as
/// `GoogleFontsLookup` is, so an app never sees the setter;
/// `theme_controller.dart` and its tests import this file by its package
/// path.
abstract final class ThemeFontLoader {
  static Future<void> Function(String family, List<ByteData> files) _load =
      _register;

  /// Every font file registration so far, keyed `<family>\n<path>`, each
  /// the future of the one load that registers it. An engine registration
  /// lasts the app's run, so outside a test the map only grows.
  static final registrations = <String, Future<void>>{};

  /// Registers `files` under `family` through a [FontLoader].
  static Future<void> Function(String family, List<ByteData> files) get load =>
      _load;

  @visibleForTesting
  static set load(
    Future<void> Function(String family, List<ByteData> files) value,
  ) => _load = value;

  /// Restores [load] and forgets every registration.
  @visibleForTesting
  static void reset() {
    _load = _register;
    registrations.clear();
  }

  static Future<void> _register(String family, List<ByteData> files) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(Future.value(file));
    }
    return loader.load();
  }
}
