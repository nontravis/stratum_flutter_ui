import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/theme_convert.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/theme_set.freezed.dart';

/// Whether the application shows a theme's high-contrast data.
enum StratumHighContrastMode {
  /// The platform setting, `MediaQuery.maybeHighContrastOf`; off when no
  /// media query is above. The default.
  system,

  /// Always the high-contrast data.
  on,

  /// Never the high-contrast data.
  off,
}

/// [StratumHighContrastMode]'s name before naming rule R2, kept one minor
/// version.
@Deprecated(
  'Use StratumHighContrastMode instead. HighContrastMode will be removed '
  'after one minor version.',
)
typedef HighContrastMode = StratumHighContrastMode;

/// The four theme data of one theme, one per color set (spec section 7.1).
@valueModel
abstract class StratumThemeSet with _$StratumThemeSet {
  const factory({
    required StratumThemeData light,

    /// Null shows [light] in dark mode (FO-03 US-04 FR-01).
    StratumThemeData? dark,

    /// Null shows [light] when high contrast is on.
    StratumThemeData? highContrastLight,

    /// Null shows the dark pick when high contrast is on.
    StratumThemeData? highContrastDark,
  }) = _StratumThemeSet;

  const new _();

  /// One data per color set of [config]; every other group is shared by
  /// the four, but `shadow`, whose colors each data takes from its own
  /// set, and `system`, whose set of the same name each data takes, and
  /// fields no yaml group fills take section 7.10's defaults. Throws an
  /// [ArgumentError] that names the first token path the generated classes
  /// read and [config] lacks, a shadow layer's color path its set lacks,
  /// or a `system` set [config] lacks.
  factory fromConfig(StratumThemeConfig config) {
    final colors = config.color;
    final lightColor = StratumColorTokens.fromMap(colors.light);
    final darkColor = StratumColorTokens.fromMap(colors.dark);
    final contrastLightColor = StratumColorTokens.fromMap(
      colors.highContrastLight,
    );
    final contrastDarkColor = StratumColorTokens.fromMap(
      colors.highContrastDark,
    );
    final palette = StratumPaletteTokens.fromMap(config.palette);
    final appPalettes = _appPalettes(config.palette);
    final assets = StratumAssetTokens.fromMap(config.assets);
    final animation = StratumAnimation.fromConfig(config.animation);
    final opacity = StratumOpacityTokens.fromMap(config.opacity);
    final border = StratumBorderTokens.fromMap(config.border);
    final blur = StratumBlurTokens.fromMap({
      for (final MapEntry(:key, :value) in config.blur.entries)
        key: convertBlur(value),
    });
    SystemStyle system(String set) =>
        config.system[set] ??
        (throw ArgumentError.value(
          'system.$set',
          'path',
          'no system set at this path in the theme config',
        ));
    StratumThemeData data(
      StratumColorTokens color,
      Map<String, Color> setColors,
      SystemStyle systemStyle, {
      required bool dark,
    }) => StratumThemeData(
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      color: color,
      palette: palette,
      space: config.space,
      radius: config.radius,
      layouts: config.layouts,
      appColors: _appColors(setColors),
      appPalettes: appPalettes,
      assets: assets,
      extensions: config.extensions,
      typography: config.typography,
      animation: animation,
      opacity: opacity,
      border: border,
      shadow: StratumShadowTokens.fromMap({
        for (final MapEntry(key: level, value: layers) in config.shadow.entries)
          level: List<BoxShadow>.unmodifiable([
            for (final layer in layers) convertShadowLayer(layer, setColors),
          ]),
      }),
      blur: blur,
      systemStyle: systemStyle,
    );
    return StratumThemeSet(
      light: data(lightColor, colors.light, system('light'), dark: false),
      dark: data(darkColor, colors.dark, system('dark'), dark: true),
      highContrastLight: data(
        contrastLightColor,
        colors.highContrastLight,
        system('highContrastLight'),
        dark: false,
      ),
      highContrastDark: data(
        contrastDarkColor,
        colors.highContrastDark,
        system('highContrastDark'),
        dark: true,
      ),
    );
  }

  /// Light, normal: [light]. Dark, normal: [dark], else [light].
  /// Light, high contrast: [highContrastLight], else [light].
  /// Dark, high contrast: [highContrastDark], else [dark], else [light].
  StratumThemeData pick({required bool dark, required bool highContrast}) {
    final normal = dark ? this.dark ?? light : light;
    if (!highContrast) return normal;
    return (dark ? highContrastDark : highContrastLight) ?? normal;
  }

  /// The `app.<name>` colors of one color set, by name.
  static Map<String, Color> _appColors(Map<String, Color> colors) =>
      Map.unmodifiable({
        for (final MapEntry(:key, :value) in colors.entries)
          if (key.startsWith('app.')) key.substring(4): value,
      });

  /// The `app.<ramp>.<shade>` entries of the palette, by ramp, then shade.
  static Map<String, Map<String, Color>> _appPalettes(
    Map<String, Color> palette,
  ) {
    final ramps = <String, Map<String, Color>>{};
    for (final MapEntry(:key, :value) in palette.entries) {
      if (key.split('.') case ['app', final ramp, final shade]) {
        (ramps[ramp] ??= {})[shade] = value;
      }
    }
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in ramps.entries)
        key: Map<String, Color>.unmodifiable(value),
    });
  }
}
