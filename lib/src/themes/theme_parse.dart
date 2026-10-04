import 'package:stratum_ui/src/src.dart';

/// Parses a theme off the main isolate, since a main-isolate parse pushed
/// a switch frame past 8.3 ms (NFR-P01; design S3). A test swaps [run] for
/// the synchronous parse, because `fakeAsync` cannot wait on an isolate.
///
/// Internal: kept out of `lib/src/themes/themes.dart`.
abstract final class ThemeParse {
  static Future<StratumThemeConfig> Function(
    StratumThemeSource base,
    List<StratumThemeSource> layers,
  )
  _run = _offMain;

  /// Parses `base` under `layers` as `StratumThemeConfig.parse` does.
  static Future<StratumThemeConfig> Function(
    StratumThemeSource base,
    List<StratumThemeSource> layers,
  )
  get run => _run;

  @visibleForTesting
  static set run(
    Future<StratumThemeConfig> Function(
      StratumThemeSource base,
      List<StratumThemeSource> layers,
    )
    value,
  ) => _run = value;

  /// Restores [run] to the background-isolate parse.
  @visibleForTesting
  static void reset() => _run = _offMain;

  static Future<StratumThemeConfig> _offMain(
    StratumThemeSource base,
    List<StratumThemeSource> layers,
  ) => compute(_parse, (base, layers));
}

StratumThemeConfig _parse(
  (StratumThemeSource, List<StratumThemeSource>) input,
) => StratumThemeConfig.parse(base: input.$1, layers: input.$2);
