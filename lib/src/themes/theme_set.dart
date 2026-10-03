import 'package:stratum_ui/src/src.dart';

/// Whether the application shows a theme's high-contrast data.
enum HighContrastMode {
  /// The platform setting, `MediaQuery.maybeHighContrastOf`; off when no
  /// media query is above. The default.
  system,

  /// Always the high-contrast data.
  on,

  /// Never the high-contrast data.
  off,
}

/// The four theme data of one theme, one per color set (spec section 7.1).
@immutable
class StratumThemeSet {
  const new({
    required this.light,
    this.dark,
    this.highContrastLight,
    this.highContrastDark,
  });

  /// One data per color set of [config]; every other group is shared by
  /// the four, and fields no yaml group fills take section 7.10's
  /// defaults. Throws an [ArgumentError] that names the first token path
  /// the generated classes read and [config] lacks.
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
    StratumThemeData data(
      StratumColorTokens color,
      Map<String, Color> setColors, {
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
      systemOverlayStyle: dark ? AppSystemUI.dark : AppSystemUI.light,
      systemOverlayInverseStyle: dark ? AppSystemUI.light : AppSystemUI.dark,
    );
    return StratumThemeSet(
      light: data(lightColor, colors.light, dark: false),
      dark: data(darkColor, colors.dark, dark: true),
      highContrastLight: data(
        contrastLightColor,
        colors.highContrastLight,
        dark: false,
      ),
      highContrastDark: data(
        contrastDarkColor,
        colors.highContrastDark,
        dark: true,
      ),
    );
  }

  final StratumThemeData light;

  /// Null shows [light] in dark mode (FO-03 US-04 FR-01).
  final StratumThemeData? dark;

  /// Null shows [light] when high contrast is on.
  final StratumThemeData? highContrastLight;

  /// Null shows the dark pick when high contrast is on.
  final StratumThemeData? highContrastDark;

  /// Light, normal: [light]. Dark, normal: [dark], else [light].
  /// Light, high contrast: [highContrastLight], else [light].
  /// Dark, high contrast: [highContrastDark], else [dark], else [light].
  StratumThemeData pick({required bool dark, required bool highContrast}) {
    final normal = dark ? this.dark ?? light : light;
    if (!highContrast) return normal;
    return (dark ? highContrastDark : highContrastLight) ?? normal;
  }

  /// Equal when each member is the identical instance (spec G7).
  @override
  bool operator ==(Object other) =>
      other is StratumThemeSet &&
      identical(other.light, light) &&
      identical(other.dark, dark) &&
      identical(other.highContrastLight, highContrastLight) &&
      identical(other.highContrastDark, highContrastDark);

  @override
  int get hashCode => Object.hash(
    identityHashCode(light),
    identityHashCode(dark),
    identityHashCode(highContrastLight),
    identityHashCode(highContrastDark),
  );

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
