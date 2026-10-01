import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:stratum_ui/src/components/common/focus_spread.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';
import 'package:stratum_ui/src/themes/constant/focus_type.dart';

/// The tap surface of the design system.
///
/// Builds on [InkWell] for gestures, keyboard activation, focus, and hover,
/// and adds what [InkWell] leaves out:
///
/// * a flat overlay over [child]: the theme's `overlayHover` while hovered
///   and `overlayActive` while pressed;
/// * a [FocusSpread] ring, shown per [focusType];
/// * a semantics node with a button role and a disabled flag.
///
/// Primitives name callbacks after the gesture ([onTap]); components built
/// on this widget name theirs after the intent (`onPressed`).
class StratumInkWell extends StatefulWidget {
  const new({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onHover,
    this.onHighlightChanged,
    this.disabled = false,
    this.statesController,
    this.borderRadius,
    this.disabledPressAnimation = false,
    this.mouseCursor,
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.onFocusChange,
    this.semantics,
    this.excludeFromSemantics = false,
    this.enableFeedback = true,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;

  /// Called with true when a pointer enters and false when it leaves, also
  /// when no activation callback is set.
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onHighlightChanged;

  /// Turns off every callback, the overlay, the ring, and focus; semantics
  /// then report a disabled button.
  final bool disabled;

  /// Receives the interaction states from [InkWell] and drives the overlay.
  ///
  /// A controller that starts with a state, for example
  /// `{WidgetState.hovered}`, shows that state without a pointer.
  final WidgetStatesController? statesController;

  /// Shape of the overlay and the focus ring.
  final BorderRadiusGeometry? borderRadius;

  /// Turns off the hover and press overlay.
  final bool disabledPressAnimation;
  final MouseCursor? mouseCursor;
  final FocusNode? focusNode;

  /// Whether this widget takes focus, when it shows the ring, and whether
  /// a tap requests focus ([FocusType.focused] only).
  final FocusType focusType;

  /// Shows the ring only while this widget holds primary focus.
  final bool showFocusOnPrimary;
  final bool canRequestFocus;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  /// Replaces the default button role; `container` and `enabled` are still
  /// set. Applies also when [excludeFromSemantics] is true.
  final SemanticsProperties? semantics;
  final bool excludeFromSemantics;

  /// Plays the platform click and long-press feedback.
  final bool enableFeedback;

  @override
  State<StratumInkWell> createState() => _StratumInkWellState();
}

class _StratumInkWellState extends State<StratumInkWell> {
  // Created on first use and kept until dispose, as TextField does, so a
  // node that InkWell's Focus still holds is never disposed mid-update.
  FocusNode? _internalFocusNode;
  WidgetStatesController? _internalStatesController;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  WidgetStatesController get _statesController =>
      widget.statesController ??
      (_internalStatesController ??= WidgetStatesController());

  bool get _hasActivation =>
      widget.onTap != null ||
      widget.onDoubleTap != null ||
      widget.onLongPress != null ||
      widget.onSecondaryTap != null;

  bool get _canFocus =>
      !widget.disabled &&
      widget.focusType != FocusType.none &&
      widget.canRequestFocus;

  bool get _hasRing =>
      widget.focusType == FocusType.focused ||
      widget.focusType == FocusType.focusedVisible;

  bool get _ringVisible {
    if (widget.disabled) return false;
    final node = _focusNode;
    final focused = widget.showFocusOnPrimary
        ? node.hasPrimaryFocus
        : node.hasFocus;
    if (!focused) return false;
    return switch (widget.focusType) {
      FocusType.focused => true,
      FocusType.focusedVisible =>
        FocusManager.instance.highlightMode ==
            FocusHighlightMode.traditional,
      FocusType.none || FocusType.invisible => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void didUpdateWidget(StratumInkWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
        _handleFocusChange,
      );
      _focusNode.addListener(_handleFocusChange);
    }
    if (oldWidget.statesController != null &&
        widget.statesController == null) {
      // InkWell rewrites only `disabled` on a swap, so a hover or press the
      // internal controller held before the caller's took over is stale.
      _internalStatesController?.value = <WidgetState>{};
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _internalStatesController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_hasRing) setState(() {});
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (widget.focusType == FocusType.focusedVisible &&
        _focusNode.hasFocus) {
      setState(() {});
    }
  }

  void _handleTap() {
    if (widget.focusType == FocusType.focused) _focusNode.requestFocus();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.color;
    final disabled = widget.disabled;
    final canFocus = _canFocus;
    final onHover = widget.onHover;

    Widget result = InkWell(
      onTap: disabled || widget.onTap == null ? null : _handleTap,
      onDoubleTap: disabled ? null : widget.onDoubleTap,
      onLongPress: disabled ? null : widget.onLongPress,
      onSecondaryTap: disabled ? null : widget.onSecondaryTap,
      onHighlightChanged: disabled ? null : widget.onHighlightChanged,
      onFocusChange: widget.onFocusChange,
      mouseCursor:
          widget.mouseCursor ??
          (disabled ? SystemMouseCursors.forbidden : null),
      focusNode: _focusNode,
      canRequestFocus: canFocus,
      autofocus: widget.autofocus && canFocus,
      statesController: _statesController,
      enableFeedback: widget.enableFeedback,
      excludeFromSemantics: widget.excludeFromSemantics,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: _StateOverlay(
        states: _statesController,
        hoverColor: colors.overlayHover,
        pressedColor: colors.overlayActive,
        enabled: !disabled && !widget.disabledPressAnimation,
        borderRadius: widget.borderRadius,
        child: widget.child,
      ),
    );
    result = Material(type: MaterialType.transparency, child: result);
    if (onHover != null) {
      // Kept in place while disabled so toggling disabled never changes
      // the structure below.
      result = MouseRegion(
        onEnter: disabled ? null : (_) => onHover(true),
        onExit: disabled ? null : (_) => onHover(false),
        child: result,
      );
    }
    if (_hasRing) {
      result = FocusSpread(
        focus: _ringVisible,
        borderRadius: widget.borderRadius,
        child: result,
      );
    }
    // A caller's semantics apply even with excludeFromSemantics, the usual
    // way to replace the gesture semantics with a custom label and actions.
    final properties = widget.semantics;
    if (properties != null) {
      result = Semantics.fromProperties(properties: properties, child: result);
    }
    if (!widget.excludeFromSemantics) {
      final hasActivation = _hasActivation;
      result = Semantics(
        container: true,
        enabled: hasActivation ? !disabled : null,
        button: hasActivation && properties == null ? true : null,
        child: result,
      );
    }
    return result;
  }
}

/// Paints the hover and press overlay over [child] from [states].
///
/// It listens to [states] itself, below [InkWell]: [InkWell] updates the
/// controller inside its own update, and a listener above it would call
/// `setState` while a descendant builds.
class _StateOverlay extends StatelessWidget {
  const new({
    required this.states,
    required this.hoverColor,
    required this.pressedColor,
    required this.enabled,
    required this.borderRadius,
    required this.child,
  });

  static const _duration = Duration(milliseconds: 100);

  final WidgetStatesController states;
  final Color hoverColor;
  final Color pressedColor;
  final bool enabled;
  final BorderRadiusGeometry? borderRadius;
  final Widget child;

  /// The color to animate to. The idle color is [hoverColor] at alpha 0,
  /// because a tween needs a non-null end and fading the alpha keeps the
  /// hue steady.
  Color _target(Set<WidgetState> value) {
    final idle = hoverColor.withValues(alpha: 0);
    if (!enabled || value.contains(WidgetState.disabled)) return idle;
    if (value.contains(WidgetState.pressed)) return pressedColor;
    if (value.contains(WidgetState.hovered)) return hoverColor;
    return idle;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: states,
      builder: (context, child) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _target(states.value)),
        duration: _duration,
        curve: Curves.easeInOutSine,
        // Alpha 0 becomes no color, so an idle surface paints nothing.
        builder: (context, color, child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: color == null || color.a == 0 ? null : color,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
        child: child,
      ),
      child: child,
    );
  }
}
