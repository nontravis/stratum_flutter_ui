import 'package:stratum_ui/src/components/common/layout/flex_layout.dart';
import 'package:stratum_ui/src/src.dart';

/// A column on [FlexLayout]: style, interaction, semantics, and scrolling
/// come from [BoxLayout].
///
/// A height or max height in `style` forces [MainAxisSize.max], so the
/// column fills the height it is given. `gap` becomes [Flex.spacing].
class ColumnLayout extends FlexLayout {
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
