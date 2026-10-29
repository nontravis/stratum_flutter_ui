import 'dart:io';

import 'package:stratum_ui/stratum_ui.dart';

/// Reads the package's embedded default `theme.yaml` from disk and returns
/// its four theme data, so catalog pages render the shipped default theme
/// (fo11/us01/fr01).
///
/// Uses `dart:io`, so it runs on the VM only; Chrome-run tests never
/// import this file.
Future<StratumThemeSet> loadDefaultThemeSet() async {
  final yaml = File('../assets/themes/default/theme.yaml').readAsStringSync();
  return StratumThemeSet.fromConfig(
    StratumThemeConfig.parse(
      base: StratumThemeSource(
        id: 'stratum-default',
        folder: 'packages/stratum_ui/assets/themes/default',
        yaml: yaml,
      ),
    ),
  );
}
