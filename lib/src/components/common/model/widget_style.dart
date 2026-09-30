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
}
