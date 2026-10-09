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
/// focus and Tab order. A tap on it then reaches an ancestor's gesture
/// detector, as a tap on a Flutter button with no `onPressed` does; enabled,
/// it reports exactly the hit its child reports. It also gives the component a
/// [StratumDisabledScope], so a tap surface inside cancels a press already
/// down through its own recognizers, while a gesture an ancestor already
/// won, such as an enclosing scroll, goes on (R13). A gesture detector the
/// app writes inside the component finishes a gesture already under way.
class StratumDisabled extends StatelessWidget {
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

  /// The same layers in every build: the `Semantics` layer, which while it
  /// reports is a container node with `enabled` false and otherwise adds
  /// no node and no flag (US-07 FR-03 E01, E02), then the cursor, pointer,
  /// disabled scope, focus, and opacity layers. It reads the theme only
  /// while it dims, so a widget on either base with no theme above it
  /// builds while enabled.
  @override
  Widget build(BuildContext context) {
    final reports = disabled && contributesSemantics;
    final opacity = disabled && dims
        ? StratumThemeApplication.of(context).opacity.disabled
        : 1.0;
    return Semantics(
      container: reports,
      enabled: reports ? !disabled : null,
      // A non-opaque region reports no hit to its ancestors
      // (rendering/proxy_box.dart:3339-3341@3.47.7). Enabled, it reports
      // its child's hit; disabled, it is hit across its bounds, so the
      // cursor shows and an ancestor's detector gets the tap.
      child: MouseRegion(
        hitTestBehavior: disabled
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        cursor: disabled ? SystemMouseCursors.forbidden : MouseCursor.defer,
        child: IgnorePointer(
          ignoring: disabled,
          child: StratumDisabledScope(
            // An enabled component inside a disabled one is disabled too.
            disabled: disabled || StratumDisabledScope.of(context),
            child: ExcludeFocus(
              excluding: disabled,
              child: Opacity(
                opacity: opacity,
                alwaysIncludeSemantics: true,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells a tap surface whether it sits inside a disabled component (R13;
/// base s03 invariant 14).
///
/// [IgnorePointer] refuses only a new pointer: Flutter routes a pointer
/// already down along the path it hit at its down
/// (`gestures/binding.dart:438@3.47.7`). A tap surface that depends on this
/// scope turns its handlers off when it reads true, so Flutter disposes its
/// recognizers and the press already down on it runs no action.
///
/// Not exported: `base.dart` does not export this file, and the tap
/// surface imports it by path.
class StratumDisabledScope extends InheritedWidget {
  const new({super.key, required this.disabled, required super.child});

  /// True inside a disabled component, also inside an enabled one nested
  /// in a disabled one.
  final bool disabled;

  /// Whether [context] sits inside a disabled component; false outside
  /// every component. Rebuilds [context] when the answer changes.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StratumDisabledScope>()
          ?.disabled ??
      false;

  @override
  bool updateShouldNotify(StratumDisabledScope oldWidget) =>
      disabled != oldWidget.disabled;
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
