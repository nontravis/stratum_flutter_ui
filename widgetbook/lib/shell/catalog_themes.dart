import 'package:stratum_ui/stratum_ui.dart';

/// One entry of the toolbar's theme list: a theme set shown in one mode.
typedef CatalogTheme = ({String id, ThemeMode mode, StratumThemeSet themes});

/// The toolbar's theme list: each theme of [setsById] as `'<id> · Light'`
/// then `'<id> · Dark'`, in the order [setsById] iterates (fo11/us02/fr01).
Map<String, CatalogTheme> catalogThemes(Map<String, StratumThemeSet> setsById) {
  return {
    for (final MapEntry(:key, :value) in setsById.entries) ...{
      '$key · Light': (id: key, mode: ThemeMode.light, themes: value),
      '$key · Dark': (id: key, mode: ThemeMode.dark, themes: value),
    },
  };
}

/// Loads every bundled theme of the app, `default` first, keyed by id
/// (fo11/us02/fr01).
///
/// Reads [bundle], or the root bundle when null.
Future<Map<String, StratumThemeSet>> loadCatalogThemes({
  AssetBundle? bundle,
}) async {
  final controller = await StratumThemeController.preload(bundle: bundle);
  final sets = <String, StratumThemeSet>{};
  for (final id in controller.themeIds) {
    await controller.switchTo(id);
    sets[id] = controller.themes;
  }
  return sets;
}
