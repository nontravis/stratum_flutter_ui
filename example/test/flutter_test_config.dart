import 'dart:async';

import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

/// Runs every example test with a Google Fonts family lookup that answers
/// the bare family name, a font wait that ends at once, and the theme
/// stages on the test's own isolate: the package default theme the demos
/// load names its fonts as Google fonts, and `fakeAsync` cannot wait on an
/// isolate.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFontsLookup.family = (name, {required weight, required style}) => name;
  GoogleFontsLookup.pending = () async {};
  ThemeParse.run = (base, layers) async => parseThemeValues(
    base: base,
    layers: layers,
    googleFontExists: (name) => GoogleFontsLookup.exists(name),
  );
  await testMain();
}
