import 'package:stratum_ui/src/src.dart';

class ColumnLayout extends StatelessWidget {
  const ColumnLayout({
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
    this.clipBehavior = Clip.none,
    this.innerShadow,
    this.dropShadow,
    this.backgroundBlur,
    this.transform,
    this.crossAxisIntrinsic = false,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.gap,
    this.scrollable = false,
    this.animate,
    this.animateDuration,
    this.animateCurve,
    this.onEndAnimate,
    this.semantics,
    required this.children,
  }) : _effectiveMainAxisSize = height != null || maxHeight != null
           ? MainAxisSize.max
           : mainAxisSize,
       _needsIntrinsicWidth = crossAxisIntrinsic && width == null;

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
  final Clip clipBehavior;
  final bool repaintBoundary;
  final bool debug;

  ///===== Semantics ======///
  final SemanticsProperties? semantics;

  ///===== Animate ======///
  final bool? animate;
  final Duration? animateDuration;
  final Curve? animateCurve;
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///
  final List<BoxShadow>? innerShadow;
  final List<BoxShadow>? dropShadow;
  final ImageFilter? backgroundBlur;

  ///====== Column ======///
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;
  final bool crossAxisIntrinsic;
  final double? gap;
  final bool scrollable;

  ///===== Child Widget ======///
  final List<Widget> children;

  // Pre-computed values
  final MainAxisSize _effectiveMainAxisSize;
  final bool _needsIntrinsicWidth;

  @override
  Widget build(BuildContext context) {
    // Build Column content first
    var columnContent = _buildColumnContent();

    // Apply intrinsic width only if needed
    if (_needsIntrinsicWidth) {
      columnContent = IntrinsicWidth(child: columnContent);
    }

    // Apply decorations and effects through ContainerLayout
    Widget result = ContainerLayout(
      width: width,
      height: height,
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
      ratio: ratio,
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
      child: columnContent,
    );

    // Apply scrollable wrapper last if needed
    if (scrollable) {
      result = _buildScrollableWrapper(result);
    }

    return result;
  }

  Widget _buildColumnContent() {

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _effectiveMainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
  }

  Widget _buildScrollableWrapper(Widget child) {
    // Simple case for non-max main axis size
    if (_effectiveMainAxisSize != MainAxisSize.max) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        clipBehavior: Clip.none,
        child: child,
      );
    }

    // Complex case with layout builder for max size
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.vertical,
        clipBehavior: Clip.none,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: child,
        ),
      ),
    );
  }

}
