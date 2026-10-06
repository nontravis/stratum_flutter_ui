import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';
import 'package:stratum_ui/src/themes/typography/typography_parser.dart';

export 'typography_models.dart';

part 'generated/typography.freezed.dart';

/// One entry of `typography.types`. There is no `table` entry: `table`
/// reads `body`'s style in code and always draws tabular figures.
@themeModel
abstract class StratumTypeStyle with _$StratumTypeStyle {
  const factory({
    /// The weight when the text style sets none.
    required FontWeight weight,

    /// The metrics of each size this type defines, smallest first.
    required Map<FontSize, StratumSizeMetrics> sizes,

    /// The window scale of this type, or null for the theme-wide one.
    Map<WindowSize, StratumDimension>? scaleByWindowSize,
  }) = _StratumTypeStyle;

  const new _();

  @override
  String toString() =>
      'StratumTypeStyle(weight: $weight, '
      'scaleByWindowSize: $scaleByWindowSize, sizes: $sizes)';
}

/// The typography of a theme: the `typography:` subtree of `theme.yaml`.
@themeModel
abstract class StratumTypography with _$StratumTypography {
  const factory({
    /// Each font by its key.
    required Map<String, StratumFontData> fonts,

    /// Each family set by its locale tag (`default`, `th`, `th_TH`), in
    /// yaml order.
    required Map<String, StratumFamilySet> families,

    /// The style of every type except `table`, which has no entry here:
    /// its style is `body`'s, read in code.
    required Map<FontType, StratumTypeStyle> types,

    /// The size each window size adds. A window size the yaml map omits
    /// takes the value of the nearest smaller window size it names, else
    /// of the smallest one it names; a theme without the map adds 0
    /// everywhere.
    @Default(
      StratumByWindowSize<StratumDimension>.all(StratumDimension.fixed(0)),
    )
    StratumByWindowSize<StratumDimension> scaleByWindowSize,
  }) = _StratumTypography;

  /// Parses the `typography:` node of one `theme.yaml` file.
  ///
  /// Collects every problem, an unknown key included, and throws one
  /// [StratumThemeFormatException] that lists them all; each error carries
  /// [source] as its file id. A font's `files` resolve against [folder],
  /// the folder of that file, and register under `<source>/<family>`.
  factory fromYaml(
    YamlMap node, {
    String source = 'theme',
    String folder = '',
  }) {
    final origins = <String, ThemeOrigin>{};
    final tree = plainOf(node, path: 'typography', source: 0, origins: origins);
    final errors = ThemeErrors([source]);
    final typography = readTypography(
      tree! as Map<String, Object?>,
      ThemeReader(errors, origins),
      sources: [(id: source, folder: folder)],
      googleFontExists: (name) => GoogleFontsLookup.exists(name),
    );
    errors.throwIfAny();
    return convertTypography(typography);
  }
}
