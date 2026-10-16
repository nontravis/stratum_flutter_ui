import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

/// Runs every test of the package with a Google Fonts family lookup that
/// answers the bare family name and starts no fetch, and a fresh in-memory
/// `shared_preferences` platform store so one test's writes never leak into
/// the next (fo10/us06/fr01).
///
/// The package default theme names its fonts as Google fonts (FO-02 US-07
/// FR-01 E06), and `GoogleFonts.getFont` would load each one over HTTP. A
/// test that checks the lookup replaces it and restores this fake in
/// `tearDown`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFontsLookup.family = (name, {required weight, required style}) => name;
  ThemeParse.run = (base, layers) async => parseThemeValues(
    base: base,
    layers: layers,
    googleFontExists: (name) => GoogleFontsLookup.exists(name),
  );
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  await testMain();
}
