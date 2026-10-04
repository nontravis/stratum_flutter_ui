// Frozen by tool/perf_freeze.dart from d107dcb:lib/src/components/common/layout/flex_layout.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import
import 'baseline.dart';

import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Flex] on [BaselineBoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A main-axis size in [style] (a height or max height when [direction] is
/// vertical, a width or max width when it is horizontal) forces
/// [MainAxisSize.max], so the layout fills the extent it is given. [gap]
/// becomes [Flex.spacing], and `scroll` scrolls along [direction] unless
/// its own `direction` says otherwise. [direction] may change between
/// builds; the children keep their State.
///
/// [BaselineColumnLayout] and [BaselineRowLayout] fix [direction].
class BaselineFlexLayout extends BaselineBoxLayout {
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
    required this.direction,
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

  /// The main axis: [Axis.vertical] lays the children out as a column,
  /// [Axis.horizontal] as a row.
  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  /// Sizes the layout to its largest child across [direction], through
  /// [IntrinsicWidth] in a column and [IntrinsicHeight] in a row, unless
  /// [style] sets that size.
  final bool crossAxisIntrinsic;

  /// Space between children.
  final double? gap;

  /// Makes the focusable children one roving Tab stop with arrow, Home,
  /// and End keys; see [StratumFocusGroup]. Switching between null and a
  /// value remounts the children.
  final StratumFocusGroup? focusGroup;
  final List<Widget> children;

  @override
  Axis get scrollDirection => direction;

  bool get _vertical => direction == Axis.vertical;

  MainAxisSize get _mainAxisSize {
    final style = this.style;
    final fills = _vertical
        ? style?.height != null || style?.maxHeight != null
        : style?.width != null || style?.maxWidth != null;
    return fills ? MainAxisSize.max : mainAxisSize;
  }

  /// Whether [style] sets the size across [direction].
  bool get _hasCrossSize =>
      _vertical ? style?.width != null : style?.height != null;

  @override
  Widget buildContent(BuildContext context) {
    final Widget flex = Flex(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    var content = flex;
    if (crossAxisIntrinsic && !_hasCrossSize) {
      content = _vertical
          ? IntrinsicWidth(child: flex)
          : IntrinsicHeight(child: flex);
    }
    final group = focusGroup;
    if (group == null) return content;
    return FocusGroupFrame(
      group: group,
      axis: _vertical ? FocusGroupAxis.vertical : FocusGroupAxis.horizontal,
      textDirection: textDirection,
      child: content,
    );
  }
}
