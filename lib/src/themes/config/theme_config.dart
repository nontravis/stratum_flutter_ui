import 'dart:ui' show Color;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/animation_config.dart';
import 'package:stratum_ui/src/themes/config/by_window_size.dart';
import 'package:stratum_ui/src/themes/config/pipeline/parse_values.dart';
import 'package:stratum_ui/src/themes/config/theme_asset.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';
import 'package:stratum_ui/src/themes/typography/typography.dart';

part 'generated/theme_config.freezed.dart';

/// The typed data of a theme: the package default with every app layer
/// merged over it, aliases resolved (spec section 8).
@themeModel
abstract class StratumThemeConfig with _$StratumThemeConfig {
  const factory({
    required String name,

    /// Each slot that names an asset (`splash-screen`, `loading`); an empty
    /// slot has no entry.
    required Map<String, StratumThemeAsset> assets,
    required Map<String, StratumByWindowSize<StratumDimension>> space,
    required Map<String, StratumByWindowSize<StratumDimension>> radius,
    required Map<String, StratumByWindowSize<StratumDimension>> layouts,

    /// Every shade by its path under `palette`: `brand.500`,
    /// `app.<ramp>.<shade>`. 88 entries for the package default.
    required Map<String, Color> palette,
    required StratumColorSets color,
    required StratumTypography typography,

    /// The merged `animation` group (spec section 8.1).
    required StratumAnimationConfig animation,

    /// The merged `opacity` group: `disabled`, the opacity of a disabled
    /// component (FO-08 US-07), from 0 to 1; 0.5 in the package default.
    required Map<String, double> opacity,

    /// The merged `extensions` group as plain Dart values: maps with string
    /// keys, lists, strings, numbers, booleans, and null. Never
    /// alias-resolved and never checked.
    required Map<String, Object?> extensions,
  }) = _StratumThemeConfig;

  /// Runs the five stages of spec section 7 on [base], the package default
  /// theme, and [layers] in merge order: the app's own `default` when it
  /// has one, then the app theme. An empty [layers] parses [base] alone.
  ///
  /// Synchronous; reads no file. Throws one `StratumThemeFormatException`
  /// that lists every problem.
  factory parse({
    required StratumThemeSource base,
    List<StratumThemeSource> layers = const [],
  }) => convertThemeConfig(
    parseThemeValues(
      base: base,
      layers: layers,
      googleFontExists: (name) => GoogleFontsLookup.exists(name),
    ),
  );
}

/// The four color sets of a theme; each maps a token path inside the set
/// (`brand.normal`, `background.color.brand`, `app.<name>`) to its color.
@themeModel
abstract class StratumColorSets with _$StratumColorSets {
  const factory({
    /// 192 entries for the package default.
    required Map<String, Color> light,
    required Map<String, Color> dark,

    /// Always full: [light] with the `highContrastLight` overlay applied.
    required Map<String, Color> highContrastLight,

    /// Always full: [dark] with the `highContrastDark` overlay applied.
    required Map<String, Color> highContrastDark,
  }) = _StratumColorSets;
}
