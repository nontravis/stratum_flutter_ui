import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/material.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';

/// The disabled look and behavior the component bases wrap around every
/// component (FO-08 US-07; base s03 invariants 12 to 17 and 19).
///
/// It stays in the tree whether [disabled] is true or false: a toggle
/// changes only its values, so the component keeps its elements and its
/// `State`. While [disabled] and [contributesSemantics] are both true, it
/// reports the component disabled on one container node of its own; it
/// forms no node while either is false. It decides that node from these
/// two values alone, never from what the component builds, so the node
/// is right in every frame.
///
/// It extends no component base, so the bases never wrap it in itself.
///
/// While [disabled] is true it paints the component at the theme's
/// `opacity.disabled` unless [dims] is false, shows
/// `SystemMouseCursors.forbidden`, lets no pointer event reach the
/// component, and keeps the component and every node inside it out of
/// focus and Tab order. A gesture already in progress when [disabled]
/// turns true is cancelled, so a press runs no tap and a drag gets no
/// further update.
class StratumDisabled extends StatefulWidget {
  const new({
    super.key,
    required this.disabled,
    this.dims = true,
    this.contributesSemantics = true,
    required this.child,
  });

  /// The component's `disabled` prop.
  final bool disabled;

  /// The component's `dimsWhenDisabled` hook: false keeps full opacity
  /// while every other disabled rule holds (US-07 FR-04).
  final bool dims;

  /// The component's `contributesSemantics` declaration: false, as a
  /// caret declares, forms no disabled node while every other disabled
  /// rule holds (US-07 FR-03 E01).
  final bool contributesSemantics;

  final Widget child;

  @override
  State<StratumDisabled> createState() => _StratumDisabledState();
}

class _StratumDisabledState extends State<StratumDisabled> {
  /// The pointers down inside the component now.
  final _down = <int>{};

  @override
  void didUpdateWidget(StratumDisabled oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disabled || !widget.disabled) return;
    // IgnorePointer refuses only new pointers: Flutter routes a pointer
    // already down along the path hit at its down, so cancel each one
    // (gestures/binding.dart:340@3.47.7). A drag recognizer reports the
    // cancel of an accepted drag as its end (monodrag.dart:753-766).
    _down
      ..forEach(GestureBinding.instance.cancelPointer)
      ..clear();
  }

  void _onDown(PointerDownEvent event) => _down.add(event.pointer);

  void _onEnd(PointerEvent event) => _down.remove(event.pointer);

  /// The same layers in every build: the `Semantics` layer, which while it
  /// reports is a container node with `enabled` false and otherwise adds
  /// no node and no flag (US-07 FR-03 E01, E02), then the cursor, pointer,
  /// pointer-tracking, focus, and opacity layers. It reads the theme only
  /// while it dims, so a widget on either base with no theme above it
  /// builds while enabled.
  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled;
    final reports = disabled && widget.contributesSemantics;
    final opacity = disabled && widget.dims
        ? StratumThemeApplication.of(context).opacity.disabled
        : 1.0;
    return Semantics(
      container: reports,
      enabled: reports ? !disabled : null,
      child: MouseRegion(
        opaque: false,
        cursor: disabled ? SystemMouseCursors.forbidden : MouseCursor.defer,
        child: IgnorePointer(
          ignoring: disabled,
          child: Listener(
            onPointerDown: _onDown,
            onPointerUp: _onEnd,
            onPointerCancel: _onEnd,
            child: ExcludeFocus(
              excluding: disabled,
              child: Opacity(
                opacity: opacity,
                alwaysIncludeSemantics: true,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The message a base element's debug assertion raises when [built], what
/// [component] built at its root, is a `ParentDataWidget` (base s03
/// invariant 12, US-07 FR-01 E07).
///
/// Public, not private, so both base elements' libraries can call it;
/// `base.dart` does not export this file, so it stays out of the package's
/// public API.
String boxRootAssertionMessage(Type component, Widget built) =>
    'Incorrect use of ParentDataWidget: $component builds a '
    '${built.runtimeType} at its root.\n'
    'A component on either base builds one box widget at its root, never a '
    'ParentDataWidget (Expanded, Flexible, Positioned) or a sliver.\n'
    "Move the ${built.runtimeType} to $component's call site instead.";
