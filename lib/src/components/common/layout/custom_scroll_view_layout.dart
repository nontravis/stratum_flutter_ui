import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A [CustomScrollView] that scrolls inside a [WidgetStyle] box.
///
/// Takes either [slivers] or [children]; [children] go into one lazy
/// [SliverList]. The box (fill, border, radius, and shadow) stays in place
/// while the content scrolls. In children mode `style.padding` becomes a
/// [SliverPadding], so it scrolls with the content; with [slivers], wrap
/// them in a [SliverPadding] yourself, because grouping several slivers
/// changes how pinned headers behave. A [focusable] view, by default one
/// on web or on macOS, Windows, or Linux, is a Tab stop whose arrows, Page
/// Up, Page Down, Home, and End scroll it.
class CustomScrollViewLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.slivers,
    this.children,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.showScrollbar,
    this.focusable,
    this.semanticsLabel,
    this.scrollFocusStyle,
  }) : assert(
         (slivers == null) != (children == null),
         'Pass exactly one of slivers and children',
       );

  final WidgetStyle? style;
  final List<Widget>? slivers;
  final List<Widget>? children;
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;

  /// Whether the view is a Tab stop that scrolls by keyboard; null means
  /// on web, mobile web included, and on macOS, Windows, and Linux.
  final bool? focusable;

  /// Names the focusable view for a screen reader.
  final String? semanticsLabel;

  /// The view's focus ring style, level 3 (FO-06 US-07 FR-03), beside
  /// `style`, which draws the box.
  final ScrollFocusStyle? scrollFocusStyle;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    final slivers = this.slivers;
    assert(
      slivers == null || style?.padding == null,
      'style.padding applies to children only; wrap slivers in a '
      'SliverPadding instead',
    );
    return ScrollViewBox(
      style: style,
      focusable: focusable,
      axis: scrollDirection,
      controller: controller,
      semanticsLabel: semanticsLabel,
      showScrollbar: showScrollbar,
      scrollFocusStyle: scrollFocusStyle,
      builder: (context, controller, padding) => CustomScrollView(
        controller: controller,
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        physics: physics,
        semanticChildCount: slivers == null ? children!.length : null,
        slivers: slivers ?? [_buildChildrenSliver(padding)],
      ),
    );
  }

  Widget _buildChildrenSliver(EdgeInsetsGeometry? padding) {
    final sliver = SliverList.list(children: children!);
    if (padding == null) return sliver;
    return SliverPadding(padding: padding, sliver: sliver);
  }
}
