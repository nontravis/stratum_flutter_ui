import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_overflow.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Wrap] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// `scroll` scrolls across [direction], so a horizontal wrap keeps its
/// width, wraps into runs, and scrolls vertically.
///
/// [maxRuns], [maxChildren], and [overflowBuilder] cut the wrap and count
/// what they hide (US-14). With all three null the wrap builds Flutter's
/// [Wrap], unchanged; otherwise it lays out by [Wrap]'s run rules and cuts
/// its children. A limit or [overflowBuilder] cannot go with `scroll`.
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
    this.maxRuns,
    this.maxChildren,
    this.overflowBuilder,
    required this.children,
  }) : assert(
         maxRuns == null || maxRuns >= 1,
         'maxRuns is at least 1: a wrap with a run limit shows at least one '
         'run',
       ),
       assert(
         maxChildren == null || maxChildren >= 0,
         'maxChildren is at least 0: 0 shows the overflowBuilder child alone',
       ),
       assert(
         scroll == null ||
             (maxRuns == null &&
                 maxChildren == null &&
                 overflowBuilder == null),
         'maxRuns, maxChildren, and overflowBuilder cut the runs that scroll '
         'scrolls through: set the limits or scroll on a WrapLayout, not both',
       );

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

  /// Shows only the children of the first [maxRuns] runs; null sets no run
  /// limit. At least 1. With [maxChildren] also set, the limit that hides
  /// more wins, and children hide from the end. A hidden child stays
  /// mounted with its State but does not paint, take hits, take focus, or
  /// appear in semantics, and its tickers stop until a limit change shows
  /// it again.
  final int? maxRuns;

  /// Shows only the first [maxChildren] children; null sets no child
  /// limit. At least 0: 0 shows the [overflowBuilder] child alone.
  final int? maxChildren;

  /// Builds the "+N" child from the number of hidden children, during
  /// layout, so the first frame shows the right count; null hides the
  /// children with no indicator.
  ///
  /// The child follows the last shown child in the last allowed run; when
  /// it does not fit within [maxRuns] runs, more children hide from the
  /// end until it fits. No child hidden builds none. With it set,
  /// switching both limits between null and a value keeps the children's
  /// State; with it null, that switch remounts them, as a [focusGroup]
  /// switch does.
  ///
  /// While it measures, the wrap calls the builder once for each hidden
  /// count it tries, then shows the widget built for the last. That
  /// widget must not carry a [GlobalKey] or a [FocusNode] the app owns: a
  /// measuring copy and the shown child build it at once, and debug
  /// builds report it. A key or a node that a [State] inside the child
  /// creates for itself is its own per copy, and is safe.
  ///
  /// Expand or collapse by changing [maxRuns] or [maxChildren]: the size
  /// moves from the old to the new size over the theme's default level
  /// (`fast`, 125 ms in the package default) on the theme's `standard`
  /// curve, with the content clipped to it, and changes at once under
  /// reduced motion. Children an expand shows appear at once; a change of
  /// constraints, children, or [gap] lays out at once.
  final Widget Function(BuildContext context, int hiddenCount)? overflowBuilder;
  final List<Widget> children;

  /// Overflow mode (s03 invariant 36): a limit or [overflowBuilder] set.
  bool get _cuts =>
      overflowBuilder != null || maxRuns != null || maxChildren != null;

  @override
  Axis get scrollDirection => flipAxis(direction);

  @override
  Widget buildContent(BuildContext context) {
    final gap = this.gap ?? 0;
    final wrap = _cuts
        ? WrapOverflowFrame(
            direction: direction,
            alignment: alignment,
            spacing: gap,
            runSpacing: runGap ?? gap,
            runAlignment: runAlignment,
            crossAxisAlignment: crossAxisAlignment,
            textDirection: textDirection,
            verticalDirection: verticalDirection,
            clipBehavior: clipBehavior,
            maxRuns: maxRuns,
            maxChildren: maxChildren,
            overflowBuilder: overflowBuilder,
            children: children,
          )
        : Wrap(
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
