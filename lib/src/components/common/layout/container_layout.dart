import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/layout/widget_performance_monitor.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/animated_styled_box.dart';

/// A box that paints a [WidgetStyle] around [child].
///
/// Every visual value (spacing, size, fill, border, shadows, blur, opacity,
/// and animation) comes from [style], which [AnimatedStyledBox] builds and
/// animates. The other parameters cover what a style cannot: per-instance
/// layout, behavior, and accessibility.
class ContainerLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.transform,
    this.transformAlignment,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.semantics,
    this.onEndAnimate,
    this.child,
  });

  final WidgetStyle? style;

  /// Width divided by height for the child; ignored unless greater than 0.
  final double? ratio;

  /// Clockwise rotation in degrees.
  ///
  /// Switching between null and a value adds or removes a wrapper and
  /// rebuilds the subtree; pass 0 when the rotation may change later.
  final double? rotate;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  /// Keeps this box alive when a lazy list scrolls it away.
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;
  final SemanticsProperties? semantics;

  /// Called when a style animation completes.
  ///
  /// An instant change, whose style has no animation duration, does not
  /// call it, so the callback never runs during a build.
  final VoidCallback? onEndAnimate;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final aspect = ratio;
    final duration = style?.animationStyle?.duration ?? Duration.zero;
    Widget content = AnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      child: child,
    );
    final degrees = rotate;
    if (degrees != null) {
      content = Transform.rotate(
        angle: degrees * math.pi / 180,
        child: content,
      );
    }
    if (repaintBoundary) {
      content = RepaintBoundary(child: content);
    }
    if (debug) {
      content = WidgetPerformanceMonitor(child: content);
    }
    if (keepAlive) {
      content = _KeepAlive(child: content);
    }
    final properties = semantics;
    if (properties != null) {
      content = Semantics.fromProperties(
        properties: properties,
        child: content,
      );
    }
    return content;
  }
}

/// Keeps [child] alive inside a lazy list; does nothing elsewhere.
class _KeepAlive extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
