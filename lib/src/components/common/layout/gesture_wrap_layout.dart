import 'package:stratum_ui/src/src.dart';

class GestureWrapLayout extends StatelessWidget {
  const GestureWrapLayout({
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
    this.innerShadow,
    this.dropShadow,
    this.backgroundBlur,
    this.transform,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.gap,
    this.scrollable = false,
    this.animate = true,
    this.animateDuration,
    this.animateCurve,
    this.onEndAnimate,
    this.semantics,
    //=== InkWell ===//
    this.disabledPressAnimation = false,
    this.disabled = false,
    this.onPress,
    this.onSecondaryPress,
    this.onDoubleTap,
    this.onLongPress,
    this.onHighlightChanged,
    this.onHover,
    this.mouseCursor,
    this.enableFeedback = true,
    this.excludeFromSemantics = false,
    this.focusType = FocusType.focusedVisible,
    this.focusNode,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.showFocusOnPrimary = true,
    this.statesController,
    //===============//
    required this.children,
  }) : _effectiveSpacing = spacing ?? gap ?? 0.0,
       _effectiveRunSpacing = runSpacing ?? gap ?? 0.0,
       _hasGestures =
           !disabled &&
           (onPress != null ||
               onSecondaryPress != null ||
               onDoubleTap != null ||
               onLongPress != null ||
               onHighlightChanged != null ||
               onHover != null ||
               onFocusChange != null);

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
  final EdgeInsets? padding;
  final EdgeInsets? margin;
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

  ///===== InkWell ======///
  final bool disabledPressAnimation;
  final bool disabled;
  final GestureTapCallback? onPress;
  final GestureTapCallback? onSecondaryPress;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final bool enableFeedback;
  final bool excludeFromSemantics;
  final ValueChanged<bool>? onFocusChange;
  final FocusType focusType;
  final bool autofocus;
  final bool showFocusOnPrimary;
  final FocusNode? focusNode;
  final bool canRequestFocus;
  final WidgetStatesController? statesController;

  ///====== Wrap ======///
  final Axis direction;
  final WrapAlignment alignment;
  final double? spacing;
  final WrapAlignment runAlignment;
  final double? runSpacing;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final double? gap;
  final bool scrollable;

  ///===== Child Widget ======///
  final List<Widget> children;

  // Pre-computed values
  final double _effectiveSpacing;
  final double _effectiveRunSpacing;
  final bool _hasGestures;

  @override
  Widget build(BuildContext context) {
    // Build the core Wrap widget
    Widget wrapWidget = Wrap(
      direction: direction,
      alignment: alignment,
      spacing: _effectiveSpacing,
      runSpacing: _effectiveRunSpacing,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
      children: children,
    );

    // Apply gesture container only if gestures are needed
    if (_hasGestures) {
      wrapWidget = GestureContainerLayout(
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
        clipBehavior: clipBehavior,
        innerShadow: innerShadow,
        dropShadow: dropShadow,
        backgroundBlur: backgroundBlur,
        transform: transform,
        focusType: focusType,
        disabled: disabled,
        disabledPressAnimation: disabledPressAnimation,
        onTap: onPress,
        onSecondaryPress: onSecondaryPress,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onHighlightChanged: onHighlightChanged,
        onHover: onHover,
        mouseCursor: mouseCursor,
        enableFeedback: enableFeedback,
        excludeFromSemantics: excludeFromSemantics,
        focusNode: focusNode,
        canRequestFocus: canRequestFocus,
        onFocusChange: onFocusChange,
        autofocus: autofocus,
        showFocusOnPrimary: showFocusOnPrimary,
        statesController: statesController,
        animate: animate,
        animateDuration: animateDuration,
        animateCurve: animateCurve,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: wrapWidget,
      );
    } else {
      // Apply only container styling without gestures
      wrapWidget = ContainerLayout(
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
        child: wrapWidget,
      );
    }

    // Apply scrollable wrapper only if needed
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: direction == Axis.horizontal
            ? Axis.vertical
            : Axis.horizontal,
        child: wrapWidget,
      );
    }

    return wrapWidget;
  }
}
