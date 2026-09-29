import 'package:stratum_ui/src/src.dart';

class ContainerLayout extends StatelessWidget {
  const new({
    super.key,
    this.ratio,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.rotate,
    this.alignment,
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
    this.transformAlignment,
    this.animate,
    this.animateDuration,
    this.animateCurve,
    this.onEndAnimate,
    this.semantics,
    this.child,
  });

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
  final BorderRadiusGeometry? borderRadius;
  final AlignmentGeometry? alignment;
  final AlignmentGeometry? transformAlignment;
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

  ///===== Animate ======///
  final bool? animate;
  final Duration? animateDuration;
  final Curve? animateCurve;
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///
  final List<BoxShadow>? innerShadow;
  final List<BoxShadow>? dropShadow;
  final ImageFilter? backgroundBlur;

  ///===== Semantics ======///
  final SemanticsProperties? semantics;

  ///===== Child Widget ======///
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Build the core container first
    var content = _buildCoreContainer(context);

    // Apply drop shadow if needed
    if (dropShadow != null && dropShadow!.isNotEmpty) {
      content = _buildDropShadowWrapper(context, content);
    }

    // Apply effects and transformations only if needed
    if (backgroundBlur != null) {
      content = BackdropFilter(
        filter: backgroundBlur!,
        child: content,
      );
    }

    if (opacity != null && opacity! < 1.0) {
      content = Opacity(opacity: opacity!, child: content);
    }

    if (rotate != null) {
      content = Transform.rotate(
        angle: rotate! * (3.14159 / 180),
        child: content,
      );
    }

    // Apply performance optimizations only if needed
    if (repaintBoundary) {
      content = RepaintBoundary(child: content);
    }

    if (debug) {
      content = WidgetPerformanceMonitor(debug: debug, child: content);
    }

    if (keepAlive) {
      content = KeepAlive(keepAlive: true, child: content);
    }

    if (semantics != null) {
      content = Semantics.fromProperties(
        properties: semantics!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildCoreContainer(BuildContext context) {
    // Process child with ratio if needed
    var processedChild = child;
    if (processedChild != null && ratio != null && ratio! > 0) {
      processedChild = AspectRatio(aspectRatio: ratio!, child: processedChild);
    }

    // Build inner shadow decorations
    final effectiveInnerShadow = _buildInnerShadow();

    // Determine if we need clipping
    final needsClipping = clipBehavior != Clip.none && borderRadius != null;

    // Create the main container widget
    final containerWidget = animate != true
        ? Container(
            alignment: alignment,
            padding: padding,
            margin: margin,
            width: width,
            height: height,
            constraints: _buildConstraints(),
            transform: transform,
            transformAlignment: transformAlignment,
            clipBehavior: needsClipping ? Clip.none : clipBehavior,
            decoration: _buildDecoration(effectiveInnerShadow),
            foregroundDecoration: _buildForegroundDecoration(),
            child: processedChild ?? const SizedBox(),
          )
        : AnimatedContainer(
            duration: animateDuration ?? const Duration(milliseconds: 100),
            curve: animateCurve ?? Curves.easeInOutCubic,
            onEnd: onEndAnimate,
            alignment: alignment,
            padding: padding,
            margin: margin,
            width: width,
            height: height,
            constraints: _buildConstraints(),
            transform: transform,
            transformAlignment: transformAlignment,
            clipBehavior: needsClipping ? Clip.none : clipBehavior,
            decoration: _buildDecoration(effectiveInnerShadow),
            foregroundDecoration: _buildForegroundDecoration(),
            child: processedChild ?? const SizedBox(),
          );

    // Apply clipping if needed
    if (needsClipping) {
      return ClipRRect(
        borderRadius: borderRadius!,
        clipBehavior: clipBehavior,
        child: containerWidget,
      );
    }

    return containerWidget;
  }

  Widget _buildDropShadowWrapper(BuildContext context, Widget child) {
    return animate != true
        ? Container(
            decoration: BoxDecoration(
              color: context.theme.color.bg,
              borderRadius: borderRadius,
              boxShadow: decoration?.boxShadow ?? dropShadow,
            ),
            child: child,
          )
        : AnimatedContainer(
            duration: animateDuration ?? const Duration(milliseconds: 100),
            curve: animateCurve ?? Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: context.theme.color.bg,
              borderRadius: borderRadius,
              boxShadow: decoration?.boxShadow ?? dropShadow,
            ),
            child: child,
          );
  }

  BoxConstraints? _buildConstraints() {
    if (width != null ||
        height != null ||
        minWidth != null ||
        maxWidth != null ||
        minHeight != null ||
        maxHeight != null) {
      return BoxConstraints(
        minWidth: minWidth ?? 0.0,
        maxWidth: maxWidth ?? double.infinity,
        minHeight: minHeight ?? 0.0,
        maxHeight: maxHeight ?? double.infinity,
      );
    }
    return null;
  }

  BoxDecoration _buildDecoration(List<BoxShadow>? effectiveInnerShadow) {
    return BoxDecoration(
      color: effectiveInnerShadow?.isEmpty ?? true
          ? decoration?.color ?? backgroundColor
          : null,
      gradient: decoration?.gradient ?? backgroundGradient,
      image: decoration?.image ?? backgroundImage,
      borderRadius: decoration?.borderRadius ?? borderRadius,
      boxShadow: effectiveInnerShadow,
    );
  }

  BoxDecoration? _buildForegroundDecoration() {
    if (foregroundColor == null &&
        foregroundGradient == null &&
        foregroundImage == null &&
        decoration?.border == null &&
        border == null) {
      return null;
    }

    return BoxDecoration(
      color: foregroundColor,
      gradient: foregroundGradient,
      image: foregroundImage,
      borderRadius: decoration?.borderRadius ?? borderRadius,
      border: decoration?.border ?? border,
    );
  }

  List<BoxShadow>? _buildInnerShadow() {
    if (innerShadow == null || innerShadow!.isEmpty) {
      return null;
    }

    final shadows = <BoxShadow>[];
    final bgColor = decoration?.color ?? backgroundColor ?? Colors.transparent;

    // Add shadow color layers
    for (final shadow in innerShadow!) {
      shadows.add(BoxShadow(color: shadow.color));
    }

    // Add inner shadow effect layers
    for (final shadow in innerShadow!) {
      shadows.add(
        BoxShadow(
          color: bgColor,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
          offset: shadow.offset,
        ),
      );
    }

    return shadows;
  }
}
