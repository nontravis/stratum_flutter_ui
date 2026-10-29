import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'catalog_themes.dart';
import 'catalog_tree.dart';
import 'grid_overlay_addon.dart';
import 'rtl_addon.dart';
import 'stage_addon.dart';
import 'stratum_theme_addon.dart';
import 'text_scale_addon.dart';
import 'window_size_addon.dart';

/// The toolbar, first addon outermost (fo11/us02/fr01 to fr03; D7).
///
/// [RtlAddon] sits inside [LocaleAddon] so its direction wins over the one
/// `Localizations` inserts; the theme addon sits inside [WindowSizeAddon] so
/// the `WindowSizeScope` it inserts reads the viewport size. [StageAddon]
/// sits innermost and off the toolbar, so the routes and overlays a story
/// opens build under every setting above it.
List<Addon<dynamic>> catalogAddons(Map<String, StratumThemeSet> setsById) => [
  WindowSizeAddon(),
  LocaleAddon(const [
    Locale('en'),
    Locale('th'),
  ], GlobalMaterialLocalizations.delegates),
  RtlAddon(),
  CatalogTextScaleAddon(),
  stratumThemeAddon(catalogThemes(setsById)),
  GridOverlayAddon(),
  SemanticsAddon(),
  StageAddon(),
];

/// The catalog's [Config]: [components] in section order, under the toolbar
/// built from [themes], opening at [initialRoute].
Config catalogConfig({
  required List<Component> components,
  required Map<String, StratumThemeSet> themes,
  String initialRoute = '/',
}) => Config(
  initialRoute: initialRoute,
  components: orderBySection(components),
  addons: catalogAddons(themes),
);
