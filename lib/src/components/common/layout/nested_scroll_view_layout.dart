import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A [NestedScrollView] inside a [WidgetStyle] box: a header that
/// collapses as the body scrolls.
///
/// The box (fill, border, radius, and shadow) stays in place, and
/// `style.padding` insets the viewport, so it does not scroll. Scroll
/// behavior and physics come from [resolveScrollBehavior]; [physics]
/// applies on top of them.
///
/// The layout is not a Tab stop. The scroll views in [body] are, and their
/// keys scroll the header and the body as one range: an arrow or a page
/// first collapses or expands the header and then scrolls the body, Home
/// expands the header and returns the body to its start, and End scrolls
/// the body to its end. [body] should be a vertical layout scroll view,
/// such as `ListViewLayout`, whose `controller` is null and whose
/// `primary` is null or true, so it attaches to the inner controller; a
/// scroll view with its own controller scrolls on its own, as in Flutter.
///
/// The scroll views of a `TabBarView` body share the inner controller.
/// Build them with `showScrollbar: false`: a desktop scrollbar asserts
/// while a tab swipe attaches two of them to the controller it watches.
class NestedScrollViewLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.showScrollbar,
    required this.headerSliverBuilder,
    required this.body,
    this.dragStartBehavior = DragStartBehavior.start,
    this.floatHeaderSlivers = false,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.restorationId,
  });

  final WidgetStyle? style;

  /// The outer controller, over which the header collapses.
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;

  /// Whether the outer view shows a scrollbar; null keeps
  /// [NestedScrollView]'s default, none. The scroll views in [body] keep the
  /// scroll behavior's choice either way.
  final bool? showScrollbar;
  final NestedScrollViewHeaderSliversBuilder headerSliverBuilder;
  final Widget body;
  final DragStartBehavior dragStartBehavior;
  final bool floatHeaderSlivers;
  final Clip clipBehavior;
  final HitTestBehavior hitTestBehavior;
  final String? restorationId;

  @override
  Widget build(BuildContext context) {
    return ScrollViewBox(
      style: style,
      focusable: false,
      axis: scrollDirection,
      controller: controller,
      showScrollbar: showScrollbar,
      scrollsPadding: false,
      builder: (context, controller, padding) => NestedScrollView(
        controller: controller,
        scrollDirection: scrollDirection,
        reverse: reverse,
        physics: physics,
        headerSliverBuilder: headerSliverBuilder,
        body: body,
        dragStartBehavior: dragStartBehavior,
        floatHeaderSlivers: floatHeaderSlivers,
        clipBehavior: clipBehavior,
        hitTestBehavior: hitTestBehavior,
        restorationId: restorationId,
        // NestedScrollView turns the outer scrollbar off unless it receives
        // a behavior.
        scrollBehavior: ScrollConfiguration.of(
          context,
        ).copyWith(scrollbars: showScrollbar ?? false),
      ),
    );
  }
}
