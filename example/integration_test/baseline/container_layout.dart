// Frozen by tool/perf_freeze.dart from 49a2d6b:lib/src/components/common/layout/container_layout.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import
import 'baseline.dart';

import 'package:stratum_ui/src/src.dart';

/// A box that paints a [WidgetStyle] around [child].
///
/// Every visual value (spacing, size, fill, border, shadows, blur, opacity,
/// and animation) comes from `style`, which [BaselineAnimatedStyledBox] builds and
/// animates. The other parameters come from [BaselineBoxLayout] and cover what a
/// style cannot: per-instance layout, interaction, behavior, and
/// accessibility.
class BaselineContainerLayout extends BaselineBoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    this.fit,
    this.child,
  }) : assert(
         fit == null || scroll == null,
         'fit needs a box with an extent to fit into; a scrolling box has '
         'none along its scroll axis',
       );

  /// Scales [child] into the box's padded area through [FittedBox].
  ///
  /// `style.alignment` becomes [FittedBox.alignment], centered when null,
  /// and builds no [Align], so the padded area's constraints reach the
  /// [FittedBox] unchanged and [BoxFit.cover] and [BoxFit.fill] reach the
  /// edges of a box with a fixed size. A change of `style.alignment` takes
  /// effect at once. The [FittedBox] does not clip: set
  /// `style.clipBehavior` to crop a [BoxFit.cover] child at the box edge,
  /// with its `borderRadius`. Null builds no [FittedBox].
  final BoxFit? fit;
  final Widget? child;

  @override
  bool get alignsContent => fit == null;

  @override
  Widget buildContent(BuildContext context) {
    final content = child ?? const SizedBox.shrink();
    final fit = this.fit;
    if (fit == null) return content;
    return FittedBox(
      fit: fit,
      alignment: style?.alignment ?? Alignment.center,
      child: content,
    );
  }
}
