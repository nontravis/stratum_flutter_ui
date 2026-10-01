import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Row] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A width or max width in [style] forces [MainAxisSize.max], so the row
/// fills the width it is given. [gap] becomes [Row.spacing], and `scroll`
/// scrolls horizontally unless its `direction` says otherwise.
class RowLayout extends BoxLayout {
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
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
    this.focusGroup,
    required this.children,
  });

  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  /// Sizes the row to its tallest child through [IntrinsicHeight], unless
  /// [style] sets a height.
  final bool crossAxisIntrinsic;

  /// Space between children.
  final double? gap;

  /// Makes the focusable children one roving Tab stop with arrow, Home,
  /// and End keys; see [StratumFocusGroup]. Switching between null and a
  /// value remounts the children.
  final StratumFocusGroup? focusGroup;
  final List<Widget> children;

  @override
  Axis get scrollDirection => Axis.horizontal;

  MainAxisSize get _mainAxisSize {
    final style = this.style;
    final fills = style?.width != null || style?.maxWidth != null;
    return fills ? MainAxisSize.max : mainAxisSize;
  }

  @override
  Widget buildContent(BuildContext context) {
    final style = this.style;
    final Widget row = Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    final content = crossAxisIntrinsic && style?.height == null
        ? IntrinsicHeight(child: row)
        : row;
    final group = focusGroup;
    if (group == null) return content;
    return FocusGroupFrame(
      group: group,
      axis: FocusGroupAxis.horizontal,
      textDirection: textDirection,
      child: content,
    );
  }
}
