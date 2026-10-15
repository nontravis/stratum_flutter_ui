import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/typography/typography_parser.dart';

// The convert of design S2: turns the plain values of stages 1 to 5 into
// the public theme types. It cannot fail, because the stages passed every
// value it reads: each weight is 100 to 900 in steps of 100, and each
// window size name is one of `windowSizeNames`. Internal: not exported.

/// [plain] as `StratumByWindowSize`.
StratumByWindowSize<StratumDimension> convertByWindowSize(
  PlainByWindowSize plain,
) {
  final sizes = plain.sizes;
  return sizes == null
      ? StratumByWindowSize.all(plain.all!)
      : StratumByWindowSize(_bySize(sizes));
}

/// [plain] as `StratumTypography`, each weight a [FontWeight].
StratumTypography convertTypography(PlainTypography plain) => StratumTypography(
  fonts: plain.fonts,
  families: plain.families,
  scaleByWindowSize: convertByWindowSize(plain.scaleByWindowSize),
  types: frozenMap({
    for (final MapEntry(key: type, value: style) in plain.types.entries)
      type: StratumTypeStyle(
        weight: FontWeight.values[style.weight ~/ 100 - 1],
        sizes: style.sizes,
        scaleByWindowSize: switch (style.scaleByWindowSize) {
          final scale? => _bySize(scale),
          null => null,
        },
      ),
  }),
);

Map<WindowSize, StratumDimension> _bySize(
  Map<String, StratumDimension> byName,
) => frozenMap({
  for (final MapEntry(:key, :value) in byName.entries)
    WindowSize.values.byName(key): value,
});

/// [plain] as `StratumThemeConfig`, each color a [Color].
StratumThemeConfig convertThemeConfig(PlainThemeConfig plain) =>
    StratumThemeConfig(
      name: plain.name,
      assets: plain.assets,
      space: _tokens(plain.space),
      radius: _tokens(plain.radius),
      layouts: _tokens(plain.layouts),
      palette: _colors(plain.palette),
      color: StratumColorSets(
        light: _colors(plain.color.light),
        dark: _colors(plain.color.dark),
        highContrastLight: _colors(plain.color.highContrastLight),
        highContrastDark: _colors(plain.color.highContrastDark),
      ),
      typography: convertTypography(plain.typography),
      animation: plain.animation,
      opacity: plain.opacity,
      border: plain.border,
      shadow: plain.shadow,
      blur: plain.blur,
      system: frozenMap({
        for (final MapEntry(:key, :value) in plain.system.entries)
          key: convertSystemLook(value),
      }),
      extensions: plain.extensions,
    );

Map<String, StratumByWindowSize<StratumDimension>> _tokens(
  Map<String, PlainByWindowSize> tokens,
) => frozenMap({
  for (final MapEntry(:key, :value) in tokens.entries)
    key: convertByWindowSize(value),
});

/// [plain], one `system` set as stage 5 reads it, as the [SystemStyle] of
/// its eight look fields (config s03 invariant 16).
SystemStyle convertSystemLook(Map<String, Object> plain) => SystemStyle(
  statusBarIcons: _icons(plain['statusBarIcons']),
  statusBarColor: _color(plain['statusBarColor']),
  statusBarContrast: plain['statusBarContrast'] as bool?,
  navigationBarIcons: _icons(plain['navigationBarIcons']),
  navigationBarColor: _color(plain['navigationBarColor']),
  navigationBarDividerColor: _color(plain['navigationBarDividerColor']),
  navigationBarContrast: plain['navigationBarContrast'] as bool?,
  appSwitcherColor: _color(plain['appSwitcherColor']),
);

SystemBarIcons? _icons(Object? name) =>
    name == null ? null : SystemBarIcons.values.byName(name as String);

Color? _color(Object? argb) => argb == null ? null : Color(argb as int);

Map<String, Color> _colors(Map<String, int> argb) => frozenMap({
  for (final MapEntry(:key, :value) in argb.entries) key: Color(value),
});

/// The `BoxShadow` of one shadow [layer] (themes s03
/// `StratumShadowTokens`): its offset and spread as written, its blur by
/// [shadowBlurRadius], and its color fixed by the layer or, for a
/// [StratumSetLayerColor], taken from [setColors], one color set's colors
/// by their path inside the set. Throws an [ArgumentError] naming a set
/// path [setColors] lacks.
BoxShadow convertShadowLayer(
  StratumShadowLayer layer,
  Map<String, Color> setColors,
) => BoxShadow(
  offset: Offset(layer.x, layer.y),
  blurRadius: shadowBlurRadius(layer.blur),
  spreadRadius: layer.spread,
  color: switch (layer.color) {
    StratumFixedLayerColor(:final argb) => Color(argb),
    StratumSetLayerColor(:final path) =>
      setColors[path] ??
          (throw ArgumentError.value(
            path,
            'path',
            'no color at this path in the theme config',
          )),
  },
);

/// The `blurRadius` that paints a Figma shadow blur [blur] at the Figma
/// and CSS strength, sigma `blur / 2` (themes s03 `StratumShadowTokens`).
/// Flutter paints a radius above 0 at sigma `0.57735 * radius + 0.5`
/// (`Shadow.convertRadiusToSigma`), so a blur above 1 takes
/// `(blur / 2 - 0.5) / 0.57735`; a blur above 0 up to 1 takes the
/// smallest positive radius, sigma 0.5, Flutter's floor, which equals
/// `blur / 2` at 1; and 0 stays 0, no blur. Setting the radius, never a
/// sigma, keeps `BoxShadow.lerp` correct.
double shadowBlurRadius(double blur) {
  if (blur <= 0) return 0;
  if (blur <= 1) return double.minPositive;
  return (blur / 2 - 0.5) / 0.57735;
}

/// The background blur of a Figma blur [radius] (themes s03
/// `StratumBlurTokens`): sigma `radius / 2` on both axes, since a Figma
/// radius is twice the CSS and Flutter standard deviation.
ImageBlurFilter convertBlur(double radius) =>
    ImageBlurFilter(sigmaX: radius / 2, sigmaY: radius / 2);
