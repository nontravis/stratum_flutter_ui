// ignore: implementation_imports, StratumLabels is internal and no barrel exports it; its delegates are the only list that holds the Stratum, Material, Cupertino, and widgets delegates together.
import 'package:stratum_ui/src/components/common/l10n/stratum_labels.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'catalog_themes.dart';
import 'catalog_tree.dart';
import 'grid_overlay_addon.dart';
import 'rtl_addon.dart';
import 'stratum_theme_addon.dart';
import 'window_size_addon.dart';

/// The toolbar, first addon outermost (fo11/us02/fr01 to fr03; D7).
///
/// [RtlAddon] sits inside [LocaleAddon] so its direction wins over the one
/// `Localizations` inserts; the theme addon sits inside [WindowSizeAddon] so
/// the `WindowSizeScope` it inserts reads the viewport size.
List<Addon<dynamic>> catalogAddons(Map<String, StratumThemeSet> setsById) => [
  WindowSizeAddon(),
  LocaleAddon(const [
    Locale('en'),
    Locale('th'),
  ], StratumLabels.localizationsDelegates),
  RtlAddon(),
  TextScaleAddon(),
  stratumThemeAddon(catalogThemes(setsById)),
  GridOverlayAddon(),
  SemanticsAddon(),
];

/// The catalog's [Config]: [components] in section order, under the toolbar
/// built from [themes].
Config catalogConfig({
  required List<Component> components,
  required Map<String, StratumThemeSet> themes,
}) => Config(
  components: orderBySection(components),
  addons: catalogAddons(themes),
);
