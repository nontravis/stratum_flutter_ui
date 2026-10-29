import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'catalog_themes.dart';

/// The toolbar's theme setting: publishes the picked theme set and mode to
/// the story through a [StratumThemeApplication] (fo11/us02/fr01).
///
/// Below the application, paints the picked data's
/// `color.background.defaults.normal` behind the story and styles a plain
/// `Text` from the Stratum Material theme's `bodyMedium`, so a dark pick
/// draws on the dark canvas and every story's dark-mode contrast is judged
/// against the background a dark app shows (US-02 S1; s03 INV-6).
ThemeAddon<CatalogTheme> stratumThemeAddon(Map<String, CatalogTheme> themes) {
  return ThemeAddon<CatalogTheme>(
    themes,
    (context, theme, child) => StratumThemeApplication(
      themes: theme.themes,
      themeMode: theme.mode,
      child: Builder(
        builder: (context) {
          final data = StratumThemeApplication.of(context);
          return ContainerLayout(
            style: WidgetStyle(
              backgroundColor: data.color.background.defaults.normal,
            ),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!,
              child: child,
            ),
          );
        },
      ),
    ),
  );
}
