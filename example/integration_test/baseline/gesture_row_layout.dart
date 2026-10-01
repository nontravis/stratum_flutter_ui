// Frozen by tool/perf_freeze.dart from fd59ffa:lib/src/components/common/layout/gesture_row_layout.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import
import 'baseline.dart';

import 'package:stratum_ui/src/src.dart';

class BaselineGestureRowLayout extends StatelessWidget {
  const BaselineGestureRowLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
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
    this.onEndAnimate,
    this.semantics,
    //=== InkWell ===//
    this.disabledPressAnimation = false,
    this.disabled = false,
    this.disableFocused = false,
    this.onTap,
    this.onSecondaryTap,
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
      style?.width != null || style?.maxWidth != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicHeight =>
      crossAxisIntrinsic && style?.height == null;

  ///===== InkWell ======///
  final bool disabledPressAnimation;
  final bool disabled;
  final bool disableFocused;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onSecondaryTap;
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


  @override
  Widget build(BuildContext context) {
    // Build Row content with gap spacing if needed
    var rowContent = _buildRowContent();

    // Apply intrinsic height only if needed
    if (_needsIntrinsicHeight) {
      rowContent = IntrinsicHeight(child: rowContent);
    }

    // Build the complete widget with container and gestures
    Widget result = BaselineGestureContainerLayout(
      style: style,
      ratio: ratio,
      rotate: rotate,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      transform: transform,
      focusType: focusType,
      disabledPressAnimation: disabledPressAnimation,
      disabled: disabled,
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
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
