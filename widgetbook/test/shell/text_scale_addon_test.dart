import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:stratum_ui_widgetbook/shell/text_scale_addon.dart';
import 'package:stratum_ui_widgetbook/shell/window_size_addon.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/catalog_theme.dart';

void main() {
  final addon = CatalogTextScaleAddon();

  double read(String factor) =>
      addon.valueFromQueryGroup(QueryGroup({'factor': factor}));

  test('fo11/us02/fr01: a text scale outside the toolbar range in the link '
      'clamps to it', () {
    expect(read('-1'), CatalogTextScaleAddon.minFactor);
    expect(read('0'), CatalogTextScaleAddon.minFactor);
    expect(read('40'), CatalogTextScaleAddon.maxFactor);
    expect(read('2'), 2);
  });

  test('fo11/us02/fr01: a text scale that is no finite number reads as 1', () {
    expect(read('NaN'), 1);
    expect(read('Infinity'), 1);
    expect(read('-Infinity'), 1);
  });

  test('fo11/us02/fr01: a link with no text scale reads as 1', () {
    expect(addon.valueFromQueryGroup(null), 1);
  });

  test('fo11/us02/fr01: a viewport or language the toolbar does not list falls '
      'back to its default', () async {
    final addons = catalogAddons({'default': await loadDefaultThemeSet()});
    final viewport = addons.whereType<WindowSizeAddon>().single;
    final locale = addons.whereType<LocaleAddon>().single;
    expect(
      viewport.valueFromQueryGroup(QueryGroup({'name': 'iPhone'})).name,
      'mobile',
    );
    expect(
      locale.valueFromQueryGroup(QueryGroup({'name': 'th-TH'})).languageCode,
      'en',
    );
  });
}
