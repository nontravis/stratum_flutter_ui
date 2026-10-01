// Frozen by tool/perf_freeze.dart from fe31fdc:lib/src/components/common/layout/container_layout.dart. Do not edit; run
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
    super.scrollable,
    this.child,
  });

  final Widget? child;

  @override
  Widget buildContent(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}
