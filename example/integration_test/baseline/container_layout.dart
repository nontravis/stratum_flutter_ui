// Frozen by tool/perf_freeze.dart from fd59ffa:lib/src/components/common/layout/container_layout.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import
import 'baseline.dart';

import 'dart:math' as math;
import 'package:stratum_ui/src/src.dart';

/// A box that paints a [WidgetStyle] around [child].
///
/// Every visual value (spacing, size, fill, border, shadows, blur, opacity,
/// and animation) comes from [style], which [BaselineAnimatedStyledBox] builds and
/// animates. The other parameters cover what a style cannot: per-instance
/// layout, behavior, and accessibility.
class BaselineContainerLayout extends StatelessWidget {
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
    this.boxBuilder,
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

  /// Wraps the styled box inside its margin, transform, and opacity; see
  /// [BaselineAnimatedStyledBox.boxBuilder].
  final BaselineStyledBoxBuilder? boxBuilder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final aspect = ratio;
    final duration = style?.animationStyle?.duration ?? Duration.zero;
    Widget content = BaselineAnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: boxBuilder,
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
