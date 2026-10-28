import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/stratum_caret_style.freezed.dart';

/// The caret's box style (CO-01-03 US-01 FR-04; caret s03 INV-14), a
/// style type of its own (FO-08 US-02 FR-01 E04): the caret's box holds no
/// child, so it shows only these 16 of `WidgetStyle`'s fields, each of its
/// `WidgetStyle` type, and leaves out `padding`, `alignment`,
/// `foregroundBlur`, `clipBehavior`, and the four min and max sizes. Every
/// field styles the box, never the glyph. Registered under `StratumCaret`
/// in `componentPartDefaults` it restyles every caret's box (FO-03 US-06
/// FR-01); passed as one caret's `customStyle` it wins field by field.
@valueModel
abstract class StratumCaretStyle with _$StratumCaretStyle {
  const factory({
    /// Fades the box; the glyph keeps its look.
    double? opacity,

    /// Grows the box; the glyph stays centered inside it at full size.
    EdgeInsetsGeometry? margin,

    /// Grows the box past its side, never below it; the glyph keeps its
    /// size, centered.
    double? width,

    /// Grows the box past its side, never below it; the glyph keeps its
    /// size, centered.
    double? height,

    /// The box's border.
    Border? border,

    /// The box's corner radius.
    BorderRadiusGeometry? borderRadius,

    /// The box's fill behind the glyph.
    Color? backgroundColor,

    /// The box's gradient fill behind the glyph.
    Gradient? backgroundGradient,

    /// The box's image fill behind the glyph.
    DecorationImage? backgroundImage,

    /// Blurs what lies behind the box.
    ImageBlurFilter? backgroundBlur,

    /// A layer over the box's fill, under the glyph.
    Color? foregroundColor,

    /// A gradient layer over the box's fill, under the glyph.
    Gradient? foregroundGradient,

    /// An image layer over the box's fill, under the glyph.
    DecorationImage? foregroundImage,

    /// The box's inner shadows.
    List<BoxShadow>? innerShadow,

    /// The box's drop shadows.
    List<BoxShadow>? dropShadow,

    /// The motion from one box style to the next.
    AnimationStyle? animationStyle,
  }) = _StratumCaretStyle;

  const new _();

  /// The box's `WidgetStyle` of these 16 fields, every other field null.
  WidgetStyle toWidgetStyle() => WidgetStyle(
    opacity: opacity,
    margin: margin,
    width: width,
    height: height,
    border: border,
    borderRadius: borderRadius,
    backgroundColor: backgroundColor,
    backgroundGradient: backgroundGradient,
    backgroundImage: backgroundImage,
    backgroundBlur: backgroundBlur,
    foregroundColor: foregroundColor,
    foregroundGradient: foregroundGradient,
    foregroundImage: foregroundImage,
    innerShadow: innerShadow,
    dropShadow: dropShadow,
    animationStyle: animationStyle,
  );
}
