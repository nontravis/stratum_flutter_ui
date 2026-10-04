// Frozen by tool/perf_freeze.dart from ff3c890:lib/src/components/common/layout/column_layout.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import, unnecessary_import
import 'baseline.dart';

import 'package:stratum_ui/src/src.dart';

/// A column on [BaselineFlexLayout]: style, interaction, semantics, and scrolling
/// come from [BaselineBoxLayout].
///
/// A height or max height in `style` forces [MainAxisSize.max], so the
/// column fills the height it is given. `gap` becomes [Flex.spacing].
class BaselineColumnLayout extends BaselineFlexLayout {
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
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.crossAxisIntrinsic,
    super.gap,
    super.focusGroup,
    required super.children,
  }) : super(direction: Axis.vertical);
}
