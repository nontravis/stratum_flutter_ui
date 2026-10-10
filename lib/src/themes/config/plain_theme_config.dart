import 'package:stratum_ui/src/themes/config/animation_config.dart';
import 'package:stratum_ui/src/themes/config/plain_by_window_size.dart';
import 'package:stratum_ui/src/themes/config/theme_asset.dart';
import 'package:stratum_ui/src/themes/typography/typography_parser.dart';

/// Stage 5's result (FO-01 s01 Theme config data): the data of
/// `StratumThemeConfig` with each color an ARGB int, each per-window-size
/// value keyed by window size name, and each type's weight a number, so
/// stages 1 to 5 run in the Dart VM. `convertThemeConfig` builds the public
/// type from it. Internal: not exported.
final class PlainThemeConfig {
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
    required this.opacity,
    required this.extensions,
  });

  final String name;

  /// Each slot that names an asset.
  final Map<String, StratumThemeAsset> assets;
  final Map<String, PlainByWindowSize> space;
  final Map<String, PlainByWindowSize> radius;
  final Map<String, PlainByWindowSize> layouts;

  /// Every shade by its path under `palette`, as `0xAARRGGBB`.
  final Map<String, int> palette;
  final PlainColorSets color;
  final PlainTypography typography;
  final StratumAnimationConfig animation;

  /// The `opacity` group, key to a number from 0 to 1.
  final Map<String, double> opacity;

  /// The merged `extensions` group as plain, unmodifiable Dart values.
  final Map<String, Object?> extensions;
}

/// The four color sets of a theme as stage 5 reads them, each color as
/// `0xAARRGGBB`. Internal: not exported.
final class PlainColorSets {
  const new({
    required this.light,
    required this.dark,
    required this.highContrastLight,
    required this.highContrastDark,
  });

  final Map<String, int> light;
  final Map<String, int> dark;
  final Map<String, int> highContrastLight;
  final Map<String, int> highContrastDark;
}
