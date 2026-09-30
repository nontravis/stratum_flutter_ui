import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// A [BoxDecoration] that also paints inset shadows.
///
/// Drop shadows are painted outside the box shape when the fill is
/// translucent, so a glass card does not look dimmed by its own shadow.
/// The border is not part of this decoration; paint it with a foreground
/// [BoxDecoration].
@immutable
class StyleDecoration extends Decoration {
  const new({
    this.color,
    this.gradient,
    this.image,
    this.borderRadius,
    this.dropShadow,
    this.innerShadow,
  });

  final Color? color;
  final Gradient? gradient;
  final DecorationImage? image;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? dropShadow;
  final List<BoxShadow>? innerShadow;

  /// Whether the fill hides everything behind the box.
  ///
  /// True when [color] is set with alpha 1.0 and no [gradient] is set, or
  /// when every [gradient] color has alpha 1.0 and [color], if set, has
  /// alpha 1.0. An [image] does not change the result.
  bool get isOpaque {
    final fill = color;
    if (fill != null && fill.a < 1) return false;
    final colors = gradient?.colors;
    if (colors != null) return colors.every((c) => c.a >= 1);
    return fill != null;
  }

  @override
  bool get isComplex =>
      (dropShadow?.isNotEmpty ?? false) || (innerShadow?.isNotEmpty ?? false);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) {
    final radius = borderRadius;
    if (radius == null) return true;
    return radius
        .resolve(textDirection)
        .toRRect(Offset.zero & size)
        .contains(position);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _StylePainter(this, onChanged);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyleDecoration &&
          other.color == color &&
          other.gradient == gradient &&
          other.image == image &&
          other.borderRadius == borderRadius &&
          listEquals(other.dropShadow, dropShadow) &&
          listEquals(other.innerShadow, innerShadow);

  @override
  int get hashCode => Object.hash(
        color,
        gradient,
        image,
        borderRadius,
        _hashList(dropShadow),
        _hashList(innerShadow),
      );

  static int? _hashList(List<BoxShadow>? shadows) =>
      shadows == null ? null : Object.hashAll(shadows);
}

class _StylePainter extends BoxPainter {
  new(this._decoration, VoidCallback? onChanged) : super(onChanged);

  final StyleDecoration _decoration;
  BoxPainter? _shadowPainter;
  BoxPainter? _fillPainter;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    _paintDropShadows(canvas, offset, configuration);
    _fillPainter ??= BoxDecoration(
      color: _decoration.color,
      gradient: _decoration.gradient,
      image: _decoration.image,
      borderRadius: _decoration.borderRadius,
    ).createBoxPainter(onChanged);
    _fillPainter!.paint(canvas, offset, configuration);
  }

  void _paintDropShadows(
    Canvas canvas,
    Offset offset,
    ImageConfiguration configuration,
  ) {
    final shadows = _decoration.dropShadow;
    if (shadows == null || shadows.isEmpty) return;
    _shadowPainter ??= BoxDecoration(
      borderRadius: _decoration.borderRadius,
      boxShadow: shadows,
    ).createBoxPainter(onChanged);
    _shadowPainter!.paint(canvas, offset, configuration);
  }

  @override
  void dispose() {
    _shadowPainter?.dispose();
    _fillPainter?.dispose();
    super.dispose();
  }
}
