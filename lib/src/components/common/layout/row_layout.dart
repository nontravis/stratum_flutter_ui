import 'package:stratum_ui/src/src.dart';

/// A row on [FlexLayout]: style, interaction, semantics, and scrolling come
/// from [BoxLayout].
///
/// A width or max width in `style` forces [MainAxisSize.max], so the row
/// fills the width it is given. `gap` becomes [Flex.spacing], and `scroll`
/// scrolls horizontally unless its `direction` says otherwise.
class RowLayout extends FlexLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
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
  }) : super(direction: Axis.horizontal);
}
