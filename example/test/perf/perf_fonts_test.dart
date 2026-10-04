// The test reaches GoogleFonts, the theme types, and the Google Fonts seam
// through package src paths, as perf_host_test.dart does: the example does
// not depend on google_fonts directly.
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

import '../../integration_test/perf/perf_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadPerfTheme);

  // Italic recipes stay out: the example bundles no italic file, and an
  // italic face loads on first use (FO-03 US-05 FR-02 E07).
  test('fo02/us08/fr02/e08, fo02/us08/fr02/e01, fo02/us08/s2: every type of '
      'the package default, with no weight and with each weight getter, mono '
      'too, and every Material text slot, loads only Google font files the '
      'example bundles, with fetching off', () async {
    final savedFamily = GoogleFontsLookup.family;
    addTearDown(() => GoogleFontsLookup.family = savedFamily);
    GoogleFontsLookup.family = (name, {required weight, required style}) =>
        GoogleFonts.getFont(
          name,
          fontWeight: weight,
          fontStyle: style,
        ).fontFamily!;
    final printed = <String>[];
    final savedPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    addTearDown(() => debugPrint = savedPrint);

    final text = await rootBundle.loadString(
      'packages/stratum_ui/assets/themes/default/theme.yaml',
    );
    final theme = StratumThemeSet.fromConfig(
      StratumThemeConfig.parse(
        base: StratumThemeSource(
          id: 'stratum-default',
          folder: 'packages/stratum_ui/assets/themes/default',
          yaml: text,
        ),
      ),
    ).light;
    for (final locale in const [Locale('en'), Locale('th')]) {
      for (final type in FontType.values) {
        final recipe = StratumTextStyle.type(type);
        for (final weighted in [
          recipe,
          recipe.light,
          recipe.regular,
          recipe.medium,
          recipe.semiBold,
          recipe.bold,
        ]) {
          for (final drawn in [weighted, weighted.mono]) {
            TypographyResolver.resolve(
              drawn,
              theme: theme,
              locale: locale,
              windowSize: WindowSize.mobile,
              textScaler: TextScaler.noScaling,
            );
          }
        }
      }
      theme.toThemeData(
        locale: locale,
        windowSize: WindowSize.mobile,
        textScaler: TextScaler.noScaling,
      );
    }
    await GoogleFonts.pendingFonts();

    expect(
      printed.where((line) => line.contains('unable to load font')),
      isEmpty,
    );
  });
}
