import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:stratum_ui/src/themes/config/animation_config.dart';
import 'package:stratum_ui/src/themes/config/by_window_size.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/pipeline/read_values.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/theme_asset.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';
import 'package:stratum_ui/src/themes/typography/typography.dart';

/// The typed data of a theme: the package default with every app layer
/// merged over it, aliases resolved (spec section 8).
@immutable
class StratumThemeConfig {
  const new({
    required this.name,
    required this.assets,
    required this.space,
    required this.radius,
    required this.layouts,
    required this.palette,
    required this.color,
    required this.typography,
    required this.animation,
    required this.extensions,
  });

  /// Runs the five stages of spec section 7 on [base], the package default
  /// theme, and [layers] in merge order: the app's own `default` when it
  /// has one, then the app theme. An empty [layers] parses [base] alone.
  ///
  /// Synchronous; reads no file. Throws one `StratumThemeFormatException`
  /// that lists every problem.
  factory parse({
    required StratumThemeSource base,
    List<StratumThemeSource> layers = const [],
  }) {
    final sources = [base, ...layers];
    final errors = ThemeErrors([for (final source in sources) source.id]);
    final roots = loadThemes(sources, errors);
    errors.throwIfAny();
    final checked = checkThemeKeys(roots, errors);
    final merged = mergeThemes(checked, errors);
    final resolved = resolveThemeAliases(merged, checked.schema, errors);
    final config = readThemeValues(resolved, checked.schema, sources, errors);
    errors.throwIfAny();
    return config;
  }

  final String name;

  /// Each slot that names an asset (`splash-screen`, `loading`); an empty
  /// slot has no entry.
  final Map<String, StratumThemeAsset> assets;

  final Map<String, StratumByWindowSize<StratumDimension>> space;
  final Map<String, StratumByWindowSize<StratumDimension>> radius;
  final Map<String, StratumByWindowSize<StratumDimension>> layouts;

  /// Every shade by its path under `palette`: `brand.500`,
  /// `app.<ramp>.<shade>`. 88 entries for the package default.
  final Map<String, Color> palette;

  final StratumColorSets color;

  final StratumTypography typography;

  /// The merged `animation` group (spec section 8.1).
  final StratumAnimationConfig animation;

  /// The merged `extensions` group as plain Dart values: maps with string
  /// keys, lists, strings, numbers, booleans, and null. Never alias-resolved
  /// and never checked.
  final Map<String, Object?> extensions;

  @override
  bool operator ==(Object other) =>
      other is StratumThemeConfig &&
      other.name == name &&
      mapEquals(other.assets, assets) &&
      mapEquals(other.space, space) &&
      mapEquals(other.radius, radius) &&
      mapEquals(other.layouts, layouts) &&
      mapEquals(other.palette, palette) &&
      other.color == color &&
      other.typography == typography &&
      other.animation == animation &&
      _deepEquals(other.extensions, extensions);

  @override
  int get hashCode => Object.hash(
    name,
    _mapHash(assets),
    _mapHash(space),
    _mapHash(radius),
    _mapHash(layouts),
    _mapHash(palette),
    color,
    typography,
    animation,
    _deepHash(extensions),
  );
}

/// The four color sets of a theme; each maps a token path inside the set
/// (`brand.normal`, `background.color.brand`, `app.<name>`) to its color.
@immutable
class StratumColorSets {
  const new({
    required this.light,
    required this.dark,
    required this.highContrastLight,
    required this.highContrastDark,
  });

  /// 192 entries for the package default.
  final Map<String, Color> light;
  final Map<String, Color> dark;

  /// Always full: [light] with the `highContrastLight` overlay applied.
  final Map<String, Color> highContrastLight;

  /// Always full: [dark] with the `highContrastDark` overlay applied.
  final Map<String, Color> highContrastDark;

  @override
  bool operator ==(Object other) =>
      other is StratumColorSets &&
      mapEquals(other.light, light) &&
      mapEquals(other.dark, dark) &&
      mapEquals(other.highContrastLight, highContrastLight) &&
      mapEquals(other.highContrastDark, highContrastDark);

  @override
  int get hashCode => Object.hash(
    _mapHash(light),
    _mapHash(dark),
    _mapHash(highContrastLight),
    _mapHash(highContrastDark),
  );
}

int _mapHash(Map<Object?, Object?> map) => Object.hashAllUnordered(
  map.entries.map((entry) => Object.hash(entry.key, entry.value)),
);

bool _deepEquals(Object? a, Object? b) => switch ((a, b)) {
  (final Map<String, Object?> x, final Map<String, Object?> y) =>
    x.length == y.length &&
        x.entries.every(
          (entry) =>
              y.containsKey(entry.key) &&
              _deepEquals(entry.value, y[entry.key]),
        ),
  (final List<Object?> x, final List<Object?> y) =>
    x.length == y.length &&
        Iterable<int>.generate(x.length)
            .every((index) => _deepEquals(x[index], y[index])),
  _ => a == b,
};

int _deepHash(Object? value) => switch (value) {
  final Map<String, Object?> map => Object.hashAllUnordered(
    map.entries.map((entry) => Object.hash(entry.key, _deepHash(entry.value))),
  ),
  final List<Object?> list => Object.hashAll(list.map(_deepHash)),
  _ => value.hashCode,
};
