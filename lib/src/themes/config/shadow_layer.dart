import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';

part 'generated/shadow_layer.freezed.dart';

/// One layer of a `shadow.<level>` list in `theme.yaml` (config s03 value
/// objects; invariant 13): a Figma drop shadow as numbers and a color,
/// with no Flutter type, so stage 5 builds it in the Dart VM. FO-03 turns
/// it into a `BoxShadow` for each color set.
@immutable
@themeModel
class StratumShadowLayer with _$StratumShadowLayer {
  const new({
    required this.x,
    required this.y,
    required this.blur,
    required this.spread,
    required this.color,
  });

  /// The horizontal offset in logical pixels; may be negative.
  final double x;

  /// The vertical offset in logical pixels; may be negative.
  final double y;

  /// The Figma blur radius `r`, 0 or more; FO-03 paints it at sigma
  /// `r / 2`.
  final double blur;

  /// The spread in logical pixels; may be negative.
  final double spread;

  /// The layer's color: fixed by the yaml, or a token of the current
  /// color set.
  final StratumLayerColor color;
}

/// The color of one shadow layer (config s03 value objects): a
/// [StratumFixedLayerColor] for a quoted hex, a palette shade, or a
/// built-in transparent step, or a [StratumSetLayerColor] for
/// `"{color.<group>.<name>}"`, which each color set resolves on its own.
@immutable
sealed class StratumLayerColor {
  const new();
}

/// A color the yaml fixed.
@themeModel
final class StratumFixedLayerColor extends StratumLayerColor
    with _$StratumFixedLayerColor {
  const new(this.argb);

  /// The color as `0xAARRGGBB`.
  final int argb;
}

/// A token of the current color set, by its path inside the set:
/// `shadow.primary` for `"{color.shadow.primary}"`.
@themeModel
final class StratumSetLayerColor extends StratumLayerColor
    with _$StratumSetLayerColor {
  const new(this.path);

  /// The token's path inside a color set.
  final String path;
}
