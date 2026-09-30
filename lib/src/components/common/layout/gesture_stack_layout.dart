import 'package:stratum_ui/src/src.dart';

class GestureStackLayout extends StatelessWidget {
  const GestureStackLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.clipBehavior = Clip.none,
    this.transform,
    this.textDirection,
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.scrollable = false,
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
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;
  final Clip clipBehavior;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///

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

  ///========== Style ==========///
  final WidgetStyle? style;

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
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
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
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: stackWidget,
      );
    } else {
      // Apply only container styling without gestures
      stackWidget = ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        transform: transform,
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
