import 'package:flutter/material.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';

/// The disabled look and behavior the component bases wrap around every
/// component (FO-08 US-07; base s03 invariants 12 to 18).
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
/// focus and Tab order.
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
  /// focus, and opacity layers. It reads the theme only while it dims, so
  /// a widget on either base with no theme above it builds while enabled.
  @override
  Widget build(BuildContext context) {
    final reports = disabled && contributesSemantics;
    final opacity = disabled && dims
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
    );
  }
}
