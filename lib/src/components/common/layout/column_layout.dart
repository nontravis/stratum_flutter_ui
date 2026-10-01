import 'package:stratum_ui/src/src.dart';

/// A [Column] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A height or max height in [style] forces [MainAxisSize.max], so the
/// column fills the height it is given. [gap] becomes [Column.spacing].
class ColumnLayout extends BoxLayout {
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
    required this.children,
  });

  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  /// Sizes the column to its widest child through [IntrinsicWidth], unless
  /// [style] sets a width.
  final bool crossAxisIntrinsic;

  /// Space between children.
  final double? gap;
  final List<Widget> children;

  MainAxisSize get _mainAxisSize {
    final style = this.style;
    final fills = style?.height != null || style?.maxHeight != null;
    return fills ? MainAxisSize.max : mainAxisSize;
  }

  @override
  Widget buildContent(BuildContext context) {
    final style = this.style;
    final Widget column = Column(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    if (!crossAxisIntrinsic || style?.width != null) return column;
    return IntrinsicWidth(child: column);
  }
}
