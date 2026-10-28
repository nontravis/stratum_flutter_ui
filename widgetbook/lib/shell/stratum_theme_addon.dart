import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'catalog_themes.dart';

/// The toolbar's theme setting: publishes the picked theme set and mode to
/// the story through a [StratumThemeApplication] (fo11/us02/fr01).
ThemeAddon<CatalogTheme> stratumThemeAddon(Map<String, CatalogTheme> themes) {
  return ThemeAddon<CatalogTheme>(
    themes,
    (context, theme, child) => StratumThemeApplication(
      themes: theme.themes,
      themeMode: theme.mode,
      child: child,
    ),
  );
}
