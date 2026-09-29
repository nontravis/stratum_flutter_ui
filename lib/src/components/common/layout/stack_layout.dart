import 'package:stratum_ui/src/src.dart';

class StackLayout extends StatelessWidget {
  const StackLayout({
    super.key,
    this.ratio,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.rotate,
    this.decoration,
    this.padding,
    this.margin,
    this.border,
    this.borderRadius,
    this.backgroundColor,
    this.backgroundGradient,
    this.backgroundImage,
    this.foregroundColor,
    this.foregroundGradient,
    this.foregroundImage,
    this.opacity,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.clipBehavior = Clip.hardEdge,
    this.innerShadow,
    this.dropShadow,
    this.backgroundBlur,
    this.transform,
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.textDirection,
    this.scrollable = false,
    this.animate,
    this.animateDuration,
    this.animateCurve,
    this.onEndAnimate,
    this.semantics,
    required this.children,
  }) : _hasContainerFeatures = ratio != null ||
            width != null ||
            height != null ||
            minWidth != null ||
            maxWidth != null ||
            minHeight != null ||
            maxHeight != null ||
            rotate != null ||
            decoration != null ||
            padding != null ||
            margin != null ||
            border != null ||
            borderRadius != null ||
            backgroundColor != null ||
            backgroundGradient != null ||
            backgroundImage != null ||
            foregroundColor != null ||
            foregroundGradient != null ||
            foregroundImage != null ||
            opacity != null ||
            keepAlive ||
            repaintBoundary ||
            debug ||
            innerShadow != null ||
            dropShadow != null ||
            backgroundBlur != null ||
            transform != null ||
            animate != null;

  ///========== Frame ==========///
  // If you use width,height will override min and max width, height.
  final double? width;
  final double? height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final BorderRadius? borderRadius;
  final Matrix4? transform;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final DecorationImage? backgroundImage;
  final Color? foregroundColor;
  final Gradient? foregroundGradient;
  final DecorationImage? foregroundImage;
  final double? opacity;
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;
  final Clip clipBehavior;

  ///===== Animate ======///
  final bool? animate;
  final Duration? animateDuration;
  final Curve? animateCurve;
  final VoidCallback? onEndAnimate;
  final SemanticsProperties? semantics;


  ///===== Effect ======///
  final List<BoxShadow>? innerShadow;
  final List<BoxShadow>? dropShadow;
  final ImageFilter? backgroundBlur;

  ///====== Stack ======///
  final TextDirection? textDirection;
  final StackFit fit;
  final AlignmentGeometry alignment;
  final bool scrollable;

  ///===== Child Widget ======///
  final List<Widget> children;

  // Pre-computed values
  final bool _hasContainerFeatures;

  @override
  Widget build(BuildContext context) {
    // Build the core Stack widget
    Widget stackWidget = Stack(
      textDirection: textDirection,
      fit: fit,
      alignment: alignment,
      clipBehavior: clipBehavior,
      children: children,
    );

    // Apply container features only if needed
    if (_hasContainerFeatures) {
      stackWidget = ContainerLayout(
        ratio: ratio,
        width: width,
        height: height,
        minWidth: minWidth,
        maxWidth: maxWidth,
        minHeight: minHeight,
        maxHeight: maxHeight,
        rotate: rotate,
        decoration: decoration,
        padding: padding,
        margin: margin,
        border: border,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        backgroundGradient: backgroundGradient,
        backgroundImage: backgroundImage,
        foregroundColor: foregroundColor,
        foregroundGradient: foregroundGradient,
        foregroundImage: foregroundImage,
        opacity: opacity,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        debug: debug,
        clipBehavior: clipBehavior,
        innerShadow: innerShadow,
        dropShadow: dropShadow,
        backgroundBlur: backgroundBlur,
        transform: transform,
        animate: animate,
        animateDuration: animateDuration,
        animateCurve: animateCurve,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: stackWidget,
      );
    }

    // Apply scrollable wrapper only if needed
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: stackWidget,
      );
    }

    return stackWidget;
  }
}
