import 'package:flutter/material.dart';

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

  /// A `Semantics` layer that always stays: while it reports, a container
  /// node with `enabled` false; otherwise it sets no property, so it adds
  /// no node and no flag (US-07 FR-03 E01, E02).
  @override
  Widget build(BuildContext context) {
    final reports = disabled && contributesSemantics;
    return Semantics(
      container: reports,
      enabled: reports ? !disabled : null,
      child: child,
    );
  }
}
