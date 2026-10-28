// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

/// Runs every catalog test with a Google Fonts family lookup that answers
/// the bare family name and starts no fetch, so no test reaches the
/// network (fo10/us06/fr01, mirrored from the package's own test config).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFontsLookup.family = (name, {required weight, required style}) => name;
  ThemeParse.run = (base, layers) async => parseThemeValues(
    base: base,
    layers: layers,
    googleFontExists: (name) => GoogleFontsLookup.exists(name),
  );
  await testMain();
}
