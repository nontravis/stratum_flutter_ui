import 'package:stratum_ui/src/src.dart';

class GestureStackLayout extends StatelessWidget {
  const GestureStackLayout({
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
    this.clipBehavior = Clip.none,
    this.innerShadow,
    this.dropShadow,
    this.backgroundBlur,
    this.transform,
    this.textDirection,
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.scrollable = false,
    this.animate = true,
    this.animateDuration,
    this.animateCurve,
    this.onEndAnimate,
    //=== InkWell ===//
    this.disabledPressAnimation = false,
    this.disabled = false,
    this.onTap,
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
    this.semantics,
    //===============//
    required this.children,
  }) : _hasGestures = !disabled && (onTap != null ||
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
  final Clip clipBehavior;

  ///===== Animate ======///
  final bool? animate;
  final Duration? animateDuration;
  final Curve? animateCurve;
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///
  final List<BoxShadow>? innerShadow;
  final List<BoxShadow>? dropShadow;
  final ImageFilter? backgroundBlur;

  ///===== InkWell ======///
  final bool disabledPressAnimation;
  final bool disabled;
  final GestureTapCallback? onTap;
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
  final FocusNode? focusNode;
  final bool canRequestFocus;
  final bool showFocusOnPrimary;
  final WidgetStatesController? statesController;

  final SemanticsProperties? semantics;


  ///====== Stack ======///
  final TextDirection? textDirection;
  final StackFit fit;
  final AlignmentGeometry alignment;
  final bool scrollable;

  ///===== Child Widget ======///
  final List<Widget> children;

  // Pre-computed values
  final bool _hasGestures;

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

    // Apply gesture container only if gestures are needed
    if (_hasGestures) {
      stackWidget = GestureContainerLayout(
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
        onTap: onTap,
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
        child: stackWidget,
      );
    } else {
      // Apply only container styling without gestures
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
