import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per field of `WidgetStyle`, in its order, the `argsType` of the
/// WidgetStyle playground (fo11/us05/fr02).
///
/// A field whose style value is no scalar takes the nearest knob: a number for
/// the box edges, border, radius, and blur (0 = none), a [Preset] for a
/// gradient, image, shadow, or alignment, and a [Duration] for the animation
/// style, which [toStyle] pairs with `Curves.easeInOutSine`.
class WidgetStyleKnobs {
  const WidgetStyleKnobs({
    this.opacity = 1,
    this.padding = 0,
    this.margin = 0,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    required this.alignment,
    this.border = 0,
    this.borderRadius = 0,
    this.backgroundColor,
    required this.backgroundGradient,
    required this.backgroundImage,
    this.backgroundBlur = 0,
    this.foregroundColor,
    required this.foregroundGradient,
    required this.foregroundImage,
    this.foregroundBlur = 0,
    this.clipBehavior,
    required this.innerShadow,
    required this.dropShadow,
    this.animationStyle = const Duration(milliseconds: 200),
  });

  final double opacity;

  /// The inset on all four sides.
  final double padding;

  /// The outer space on all four sides.
  final double margin;
  final double? width;
  final double? height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final Preset<AlignmentGeometry> alignment;

  /// The width of a border on all four sides, in the theme's gray border
  /// color.
  final double border;

  /// The corner radius on all four corners.
  final double borderRadius;
  final Color? backgroundColor;
  final Preset<Gradient> backgroundGradient;
  final Preset<DecorationImage> backgroundImage;

  /// The blur sigma on both axes.
  final double backgroundBlur;
  final Color? foregroundColor;
  final Preset<Gradient> foregroundGradient;
  final Preset<DecorationImage> foregroundImage;

  /// The blur sigma on both axes.
  final double foregroundBlur;
  final Clip? clipBehavior;
  final Preset<List<BoxShadow>> innerShadow;
  final Preset<List<BoxShadow>> dropShadow;

  /// The duration of the style's animation.
  final Duration animationStyle;

  /// The style these knobs set, read against the theme of [context].
  WidgetStyle toStyle(BuildContext context) => WidgetStyle(
    opacity: opacity,
    padding: _insets(padding),
    margin: _insets(margin),
    width: width,
    height: height,
    minWidth: minWidth,
    maxWidth: maxWidth,
    minHeight: minHeight,
    maxHeight: maxHeight,
    alignment: alignment.build(context),
    border: border > 0
        ? Border.all(
            width: border,
            color: context.theme.color.border.color.gray,
          )
        : null,
    borderRadius: borderRadius > 0 ? BorderRadius.circular(borderRadius) : null,
    backgroundColor: backgroundColor,
    backgroundGradient: backgroundGradient.build(context),
    backgroundImage: backgroundImage.build(context),
    backgroundBlur: _blur(backgroundBlur),
    foregroundColor: foregroundColor,
    foregroundGradient: foregroundGradient.build(context),
    foregroundImage: foregroundImage.build(context),
    foregroundBlur: _blur(foregroundBlur),
    clipBehavior: clipBehavior,
    innerShadow: innerShadow.build(context),
    dropShadow: dropShadow.build(context),
    animationStyle: AnimationStyle(
      duration: animationStyle,
      curve: Curves.easeInOutSine,
    ),
  );
}

EdgeInsets? _insets(double value) => value > 0 ? EdgeInsets.all(value) : null;

ImageBlurFilter? _blur(double sigma) =>
    sigma > 0 ? ImageBlurFilter(sigmaX: sigma, sigmaY: sigma) : null;
