import 'package:stratum_ui/src/src.dart';

class GestureWrapLayout extends StatelessWidget {
  const GestureWrapLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
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
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;
  final SemanticsProperties? semantics;

  ///===== Effect ======///

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

  ///========== Style ==========///
  final WidgetStyle? style;

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
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
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
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: wrapWidget,
      );
    } else {
      // Apply only container styling without gestures
      wrapWidget = ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        transform: transform,
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
