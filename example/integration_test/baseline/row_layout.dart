// Frozen by tool/perf_freeze.dart from fe31fdc:lib/src/components/common/layout/row_layout.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// ignore_for_file: type=lint, unused_import
import 'baseline.dart';

import 'package:stratum_ui/src/src.dart';

/// A [Row] on [BaselineBoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A width or max width in [style] forces [MainAxisSize.max], so the row
/// fills the width it is given. [gap] becomes [Row.spacing], and
/// `scrollable` scrolls horizontally.
class BaselineRowLayout extends BaselineBoxLayout {
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
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
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
  final List<Widget> children;

  @override
  Axis get scrollDirection => Axis.horizontal;

  MainAxisSize get _mainAxisSize {
    final style = this.style;
    final fills = style?.width != null || style?.maxWidth != null;
    return fills ? MainAxisSize.max : mainAxisSize;
  }

  @override
  bool get stretchesToViewport => _mainAxisSize == MainAxisSize.max;

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
    if (!crossAxisIntrinsic || style?.height != null) return row;
    return IntrinsicHeight(child: row);
  }
}
