import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Wrap] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// `scroll` scrolls across [direction], so a horizontal wrap keeps its
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
    super.scroll,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.gap,
    this.runGap,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.focusGroup,
    required this.children,
  });

  final Axis direction;

  /// Aligns children along [direction] inside each run;
  /// [WidgetStyle.alignment] places the whole wrap inside the box's padded
  /// content instead.
  final WrapAlignment alignment;

  /// Space between children in a run.
  final double? gap;

  /// Space between runs; null uses [gap].
  final double? runGap;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;

  /// Clips the wrap's children that overflow its bounds;
  /// [WidgetStyle.clipBehavior] cuts at the box edge instead.
  final Clip clipBehavior;

  /// Makes the focusable children one roving Tab stop with arrow, Home,
  /// and End keys; see [StratumFocusGroup]. Switching between null and a
  /// value remounts the children.
  final StratumFocusGroup? focusGroup;
  final List<Widget> children;

  @override
  Axis get scrollDirection => flipAxis(direction);

  @override
  Widget buildContent(BuildContext context) {
    final gap = this.gap ?? 0;
    final Widget wrap = Wrap(
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
    final group = focusGroup;
    if (group == null) return wrap;
    return FocusGroupFrame(
      group: group,
      axis: FocusGroupAxis.wrap,
      textDirection: textDirection,
      child: wrap,
    );
  }
}
