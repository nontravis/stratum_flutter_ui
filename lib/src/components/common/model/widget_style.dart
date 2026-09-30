import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';

part 'generated/widget_style.freezed.dart';

@freezed
class WidgetStyle with _$WidgetStyle {
  const new({
    this.opacity,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.alignment,
    this.border,
    this.borderRadius,
    this.backgroundColor,
    this.backgroundGradient,
    this.backgroundImage,
    this.backgroundBlur,
    this.foregroundColor,
    this.foregroundGradient,
    this.foregroundImage,
    this.foregroundBlur,
    this.clipBehavior,
    this.innerShadow,
    this.dropShadow,
    this.animationStyle,
  });
  final double? opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Tight width. Min and max constraints win when they conflict, as in
  /// `Container`.
  final double? width;

  /// Tight height. Min and max constraints win when they conflict, as in
  /// `Container`.
  final double? height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  /// Aligns the child inside the padded box.
  final AlignmentGeometry? alignment;
  final Border? border;
  final BorderRadiusGeometry? borderRadius;
  final Color? backgroundColor;

  final Gradient? backgroundGradient;
  final DecorationImage? backgroundImage;

  final ImageBlurFilter? backgroundBlur;

  /// Painted over the child, e.g. a hover or pressed tint.
  ///
  /// Unlike `ButtonStyle.foregroundColor`, this is not the text or icon color.
  final Color? foregroundColor;
  final Gradient? foregroundGradient;
  final DecorationImage? foregroundImage;

  /// Blurs the child itself, while [backgroundBlur] blurs what is behind it.
  final ImageBlurFilter? foregroundBlur;

  final List<BoxShadow>? innerShadow;
  final List<BoxShadow>? dropShadow;

  final Clip? clipBehavior;

  final AnimationStyle? animationStyle;

  /// Returns a copy where every non-null field of [other] replaces this one.
  ///
  /// A null field in [other] keeps this value, so null cannot clear a field.
  /// Pass an empty value instead: `[]` for shadows, `EdgeInsets.zero` for
  /// spacing, `AnimationStyle.noAnimation` for [animationStyle]. Lists are
  /// replaced whole, never concatenated.
  WidgetStyle merge(WidgetStyle? other) {
    if (other == null) return this;
    return WidgetStyle(
      opacity: other.opacity ?? opacity,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      width: other.width ?? width,
      height: other.height ?? height,
      minWidth: other.minWidth ?? minWidth,
      maxWidth: other.maxWidth ?? maxWidth,
      minHeight: other.minHeight ?? minHeight,
      maxHeight: other.maxHeight ?? maxHeight,
      alignment: other.alignment ?? alignment,
      border: other.border ?? border,
      borderRadius: other.borderRadius ?? borderRadius,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      backgroundGradient: other.backgroundGradient ?? backgroundGradient,
      backgroundImage: other.backgroundImage ?? backgroundImage,
      backgroundBlur: other.backgroundBlur ?? backgroundBlur,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      foregroundGradient: other.foregroundGradient ?? foregroundGradient,
      foregroundImage: other.foregroundImage ?? foregroundImage,
      foregroundBlur: other.foregroundBlur ?? foregroundBlur,
      clipBehavior: other.clipBehavior ?? clipBehavior,
      innerShadow: other.innerShadow ?? innerShadow,
      dropShadow: other.dropShadow ?? dropShadow,
      animationStyle: other.animationStyle ?? animationStyle,
    );
  }

  /// Interpolates between two styles, for implicit animation.
  ///
  /// Returns [a] at `t == 0` and [b] at `t == 1`. A null style counts as
  /// `const WidgetStyle()`. A size switches at `t = 0.5` when one side is
  /// null, because null means unconstrained. [clipBehavior] switches at
  /// `t = 0.5`, and [animationStyle] always comes from [b]. Opacity,
  /// spacing, sizes, and blur are clamped to legal values, so a curve that
  /// overshoots cannot throw.
  static WidgetStyle? lerp(WidgetStyle? a, WidgetStyle? b, double t) {
    if (identical(a, b)) return a;
    if (t == 0) return a;
    if (t == 1) return b;
    final from = a ?? const WidgetStyle();
    final to = b ?? const WidgetStyle();
    return WidgetStyle(
      opacity: _lerpOpacity(from.opacity, to.opacity, t),
      padding: _lerpSpacing(from.padding, to.padding, t),
      margin: _lerpSpacing(from.margin, to.margin, t),
      width: _lerpSize(from.width, to.width, t),
      height: _lerpSize(from.height, to.height, t),
      minWidth: _lerpSize(from.minWidth, to.minWidth, t),
      maxWidth: _lerpSize(from.maxWidth, to.maxWidth, t),
      minHeight: _lerpSize(from.minHeight, to.minHeight, t),
      maxHeight: _lerpSize(from.maxHeight, to.maxHeight, t),
      alignment: AlignmentGeometry.lerp(from.alignment, to.alignment, t),
      border: Border.lerp(from.border, to.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        from.borderRadius,
        to.borderRadius,
        t,
      ),
      backgroundColor: Color.lerp(
        from.backgroundColor,
        to.backgroundColor,
        t,
      ),
      backgroundGradient: Gradient.lerp(
        from.backgroundGradient,
        to.backgroundGradient,
        t,
      ),
      backgroundImage: DecorationImage.lerp(
        from.backgroundImage,
        to.backgroundImage,
        t,
      ),
      backgroundBlur: ImageBlurFilter.lerp(
        from.backgroundBlur,
        to.backgroundBlur,
        t,
      ),
      foregroundColor: Color.lerp(
        from.foregroundColor,
        to.foregroundColor,
        t,
      ),
      foregroundGradient: Gradient.lerp(
        from.foregroundGradient,
        to.foregroundGradient,
        t,
      ),
      foregroundImage: DecorationImage.lerp(
        from.foregroundImage,
        to.foregroundImage,
        t,
      ),
      foregroundBlur: ImageBlurFilter.lerp(
        from.foregroundBlur,
        to.foregroundBlur,
        t,
      ),
      clipBehavior: t < 0.5 ? from.clipBehavior : to.clipBehavior,
      innerShadow: BoxShadow.lerpList(from.innerShadow, to.innerShadow, t),
      dropShadow: BoxShadow.lerpList(from.dropShadow, to.dropShadow, t),
      animationStyle: to.animationStyle,
    );
  }

  static double? _lerpOpacity(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    final value = lerpDouble(a ?? 1, b ?? 1, t)!;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  static EdgeInsetsGeometry? _lerpSpacing(
    EdgeInsetsGeometry? a,
    EdgeInsetsGeometry? b,
    double t,
  ) {
    final value = EdgeInsetsGeometry.lerp(a, b, t);
    if (value == null || value.isNonNegative) return value;
    return value.clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity);
  }

  static double? _lerpSize(double? a, double? b, double t) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    final value = lerpDouble(a, b, t)!;
    return value < 0 ? 0 : value;
  }
}
