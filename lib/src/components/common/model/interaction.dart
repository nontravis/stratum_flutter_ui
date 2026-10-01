import 'package:stratum_ui/src/src.dart';

/// The pointer, focus, and semantics settings of a layout's tap surface.
///
/// A layout passes these to [StratumInkWell], one field to one parameter.
/// It builds the tap surface only when at least one of [onTap],
/// [onDoubleTap], [onLongPress], [onSecondaryTap], [onHover],
/// [onHighlightChanged], or [onFocusChange] is set. A value with none of
/// them still animates the layout's style over 100 ms and adds no tap
/// surface, so pass `const StratumInteraction()` when callbacks come and go:
/// switching `interaction` between null and a value remounts the content on
/// an otherwise bare layout; see `BoxLayout`'s tier rule for the full case.
///
/// The class does not override `==`: callbacks compare by identity.
@immutable
class StratumInteraction {
  const new({
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onHover,
    this.onHighlightChanged,
    this.mouseCursor,
    this.enableFeedback = true,
    this.disabledPressAnimation = false,
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.onFocusChange,
    this.disabled = false,
    this.statesController,
    this.excludeFromSemantics = false,
  });

  final GestureTapCallback? onTap;

  /// Has no keyboard or screen-reader path; never make a function
  /// reachable only by double tap (WCAG 2.1.1).
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onHighlightChanged;
  final MouseCursor? mouseCursor;
  final bool enableFeedback;
  final bool disabledPressAnimation;
  final FocusNode? focusNode;
  final FocusType focusType;
  final bool showFocusOnPrimary;
  final bool canRequestFocus;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  /// Turns off every callback; the layout then reads as a dimmed button.
  final bool disabled;
  final WidgetStatesController? statesController;
  final bool excludeFromSemantics;
}
