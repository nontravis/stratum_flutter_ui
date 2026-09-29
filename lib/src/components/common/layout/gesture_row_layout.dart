import 'package:stratum_ui/src/src.dart';

class GestureRowLayout extends StatelessWidget {
  const GestureRowLayout({
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
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
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
    this.disableFocused = false,
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
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.statesController,
    //===============//
    required this.children,
  }) : _effectiveMainAxisSize = width != null || maxWidth != null
            ? MainAxisSize.max
            : mainAxisSize,
       _needsIntrinsicHeight = crossAxisIntrinsic && height == null;

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
  final Clip clipBehavior;
  final bool repaintBoundary;

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
  final bool disableFocused;
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
  final bool showFocusOnPrimary;
  final bool canRequestFocus;
  final WidgetStatesController? statesController;

  ///====== Row ======///
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;
  final bool crossAxisIntrinsic;
  final double? gap;
  final bool scrollable;

  ///===== Semantics ======///
  final SemanticsProperties? semantics;


  ///===== Child Widget ======///
  final List<Widget> children;

  // Pre-computed values
  final MainAxisSize _effectiveMainAxisSize;
  final bool _needsIntrinsicHeight;

  @override
  Widget build(BuildContext context) {
    // Build Row content with gap spacing if needed
    var rowContent = _buildRowContent();

    // Apply intrinsic height only if needed
    if (_needsIntrinsicHeight) {
      rowContent = IntrinsicHeight(child: rowContent);
    }

    // Build the complete widget with container and gestures
    Widget result = GestureContainerLayout(
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
      disabledPressAnimation: disabledPressAnimation,
      disabled: disabled,
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
      child: rowContent,
    );

    // Apply scrollable wrapper only if needed
    if (scrollable) {
      result = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: result,
      );
    }

    return result;
  }

  Widget _buildRowContent() {
    // Optimize for no-gap case
    final effectiveChildren = gap == null || gap! <= 0
        ? children
        : _buildSpacedChildren();

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _effectiveMainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      children: effectiveChildren,
    );
  }

  List<Widget> _buildSpacedChildren() {
    if (children.isEmpty) return children;
    if (children.length == 1) return children;

    // Pre-allocate list with exact size for efficiency
    final spacedChildren = List<Widget>.filled(
      children.length * 2 - 1,
      const SizedBox(),
      growable: false,
    );

    // Build spaced children list efficiently
    for (var i = 0; i < children.length; i++) {
      spacedChildren[i * 2] = children[i];
      if (i < children.length - 1) {
        spacedChildren[i * 2 + 1] = Gap(gap!);
      }
    }

    return spacedChildren.sublist(0, children.length * 2 - 1);
  }
}
