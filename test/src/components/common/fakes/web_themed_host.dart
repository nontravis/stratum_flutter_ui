import 'package:stratum_ui/src/src.dart';

import 'default_theme_yaml.g.dart';

/// The package default light theme, parsed from [defaultThemeYaml], for
/// tests that run on the web.
final StratumThemeData webDefaultTheme = StratumThemeSet.fromConfig(
  StratumThemeConfig.parse(
    base: const StratumThemeSource(
      id: 'stratum-default',
      folder: 'packages/stratum_ui/assets/themes/default',
      yaml: defaultThemeYaml,
    ),
  ),
).light;

/// Places [child] in a [Center] under a [StratumThemeApplication] of
/// [webDefaultTheme] and a left-to-right [Directionality], as `themedHost`
/// does on the Dart VM.
Widget webThemedHost(Widget child) {
  return StratumThemeApplication(
    themes: StratumThemeSet(light: webDefaultTheme),
    themeMode: ThemeMode.light,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}
