import 'package:stratum_ui/src/src.dart';

/// A [Wrap] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// `scrollable` scrolls across [direction], so a horizontal wrap keeps its
/// width, wraps into runs, and scrolls vertically.
class WrapLayout extends BoxLayout {
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
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.gap,
    this.runGap,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    required this.children,
  });

  final Axis direction;
  final WrapAlignment alignment;

  /// Space between children in a run.
  final double? gap;

  /// Space between runs; null uses [gap].
  final double? runGap;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final List<Widget> children;

  @override
  Axis get scrollDirection => flipAxis(direction);

  @override
  Widget buildContent(BuildContext context) {
    final gap = this.gap ?? 0;
    return Wrap(
      direction: direction,
      alignment: alignment,
      spacing: gap,
      runSpacing: runGap ?? gap,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}
