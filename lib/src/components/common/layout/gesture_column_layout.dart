import 'package:stratum_ui/src/src.dart';

class GestureColumnLayout extends StatelessWidget {
  const GestureColumnLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
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
    this.onEndAnimate,
    this.semantics,
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
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.statesController,
    //===============//
    required this.children,
  });

  ///========== Frame ==========///
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///

  ///========== Style ==========///
  final WidgetStyle? style;

  MainAxisSize get _effectiveMainAxisSize =>
      style?.height != null || style?.maxHeight != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicWidth => crossAxisIntrinsic && style?.width == null;

  ///===== InkWell ======///
  final bool disabled;
  final bool disabledPressAnimation;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onSecondaryPress;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final bool enableFeedback;
  final bool excludeFromSemantics;
  final FocusType focusType;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool canRequestFocus;
  final bool showFocusOnPrimary;
  final WidgetStatesController? statesController;

  final SemanticsProperties? semantics;

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


  @override
  Widget build(BuildContext context) {
    // Build Column content with gap spacing if needed
    var columnContent = _buildColumnContent();

    // Apply intrinsic width only if needed
    if (_needsIntrinsicWidth) {
      columnContent = IntrinsicWidth(child: columnContent);
    }

    // Build the complete widget with container and gestures
    Widget result = GestureContainerLayout(
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
      showFocusOnPrimary: showFocusOnPrimary,
      autofocus: autofocus,
      statesController: statesController,
      onEndAnimate: onEndAnimate,
      semantics: semantics,
      child: columnContent,
    );

    // Apply scrollable wrapper only if needed
    if (scrollable) {
      result = SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: result,
      );
    }

    return result;
  }

  Widget _buildColumnContent() {
    // Optimize for no-gap case
    final effectiveChildren = gap == null || gap! <= 0
        ? children
        : _buildSpacedChildren();

    return Column(
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
    for (int i = 0; i < children.length; i++) {
      spacedChildren[i * 2] = children[i];
      if (i < children.length - 1) {
        spacedChildren[i * 2 + 1] = Gap(gap!);
      }
    }

    return spacedChildren.sublist(0, children.length * 2 - 1);
  }
}
