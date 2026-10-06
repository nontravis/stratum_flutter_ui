import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

/// Parses a theme off the main isolate, since a main-isolate parse pushed
/// a switch frame past 8.3 ms (NFR-P01; design S3). A test swaps [run] for
/// the synchronous parse, because `fakeAsync` cannot wait on an isolate.
///
/// Internal: kept out of `lib/src/themes/themes.dart`.
abstract final class ThemeParse {
  static Future<PlainThemeConfig> Function(
    StratumThemeSource base,
    List<StratumThemeSource> layers,
  )
  _run = _offMain;

  /// Runs stages 1 to 5 of `base` under `layers` as `parseThemeValues`
  /// does; the caller converts the result (design S2).
  static Future<PlainThemeConfig> Function(
    StratumThemeSource base,
    List<StratumThemeSource> layers,
  )
  get run => _run;

  @visibleForTesting
  static set run(
    Future<PlainThemeConfig> Function(
      StratumThemeSource base,
      List<StratumThemeSource> layers,
    )
    value,
  ) => _run = value;

  /// Restores [run] to the background-isolate parse.
  @visibleForTesting
  static void reset() => _run = _offMain;

  static Future<PlainThemeConfig> _offMain(
    StratumThemeSource base,
    List<StratumThemeSource> layers,
  ) => compute(_parse, (base, layers));
}

PlainThemeConfig _parse((StratumThemeSource, List<StratumThemeSource>) input) =>
    parseThemeValues(
      base: input.$1,
      layers: input.$2,
      googleFontExists: GoogleFontsLookup.exists,
    );
