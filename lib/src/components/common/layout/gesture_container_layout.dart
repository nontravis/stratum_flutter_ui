import 'package:stratum_ui/src/src.dart';

/// A [ContainerLayout] that reacts to taps, hover, and focus.
///
/// Interaction comes from [StratumInkWell], placed through
/// [ContainerLayout.boxBuilder] inside the style's margin, transform, and
/// opacity, so the overlay, focus ring, and hit area match the styled box.
/// Without any callback it builds a plain [ContainerLayout].
class GestureContainerLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.transform,
    this.transformAlignment,
    this.onEndAnimate,
    //=== InkWell ===//
    this.disabledPressAnimation = false,
    this.disabled = false,
    this.onTap,
    this.onSecondaryTap,
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
    this.semantics,
    //===============//
    this.child,
  });

  ///========== Frame ==========///
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final AlignmentGeometry? transformAlignment;
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///========== Style ==========///
  /// Style changes animate over 100 ms unless the style sets its own
  /// `animationStyle`, keeping the old `animate: true` default.
  final WidgetStyle? style;

  ///===== InkWell ======///
  final bool disabledPressAnimation;
  final bool disabled;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onSecondaryTap;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final bool enableFeedback;
  final bool excludeFromSemantics;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final FocusType focusType;
  final bool showFocusOnPrimary;
  final bool autofocus;
  final bool canRequestFocus;
  final WidgetStatesController? statesController;

  final SemanticsProperties? semantics;

  ///===== Child Widget ======///
  final Widget? child;

  static const _defaultAnimation = AnimationStyle(
    duration: Duration(milliseconds: 100),
  );

  WidgetStyle? get _effectiveStyle {
    final style = this.style;
    if (style == null || style.animationStyle != null) return style;
    return style.copyWith(animationStyle: _defaultAnimation);
  }

  /// Whether any callback asks for [StratumInkWell]. `disabled` does not
  /// count, so a disabled layout still reads as a dimmed button.
  bool get _hasInteraction =>
      onTap != null ||
      onSecondaryTap != null ||
      onDoubleTap != null ||
      onLongPress != null ||
      onHighlightChanged != null ||
      onHover != null ||
      onFocusChange != null;

  @override
  Widget build(BuildContext context) {
    // Interaction and semantics both enter through boxBuilder, inside the
    // margin, so adding or removing a callback never changes the root and
    // the child keeps its State.
    return ContainerLayout(
      style: _effectiveStyle,
      ratio: ratio,
      rotate: rotate,
      transform: transform,
      transformAlignment: transformAlignment,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      debug: debug,
      onEndAnimate: onEndAnimate,
      boxBuilder: _hasInteraction
          ? _buildInkWell
          : semantics == null
          ? null
          : _buildSemantics,
      child: child,
    );
  }

  Widget _buildSemantics(WidgetStyle style, Widget box) {
    final properties = semantics;
    if (properties == null) return box;
    return Semantics.fromProperties(properties: properties, child: box);
  }

  Widget _buildInkWell(WidgetStyle style, Widget box) {
    return StratumInkWell(
      borderRadius: style.borderRadius,
      disabled: disabled,
      disabledPressAnimation: disabledPressAnimation,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      onHover: onHover,
      onHighlightChanged: onHighlightChanged,
      statesController: statesController,
      mouseCursor: mouseCursor,
      focusNode: focusNode,
      focusType: focusType,
      showFocusOnPrimary: showFocusOnPrimary,
      canRequestFocus: canRequestFocus,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      semantics: semantics,
      excludeFromSemantics: excludeFromSemantics,
      enableFeedback: enableFeedback,
      child: box,
    );
  }
}
