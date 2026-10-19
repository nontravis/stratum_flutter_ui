import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A [PageView] inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// pages slide, and `style.padding` insets the viewport, so it does not
/// slide with them. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them.
///
/// A [focusable] page view, by default one on web or on macOS, Windows, or
/// Linux, is a Tab stop. While it holds focus, the arrows along
/// [scrollDirection] go to the page on that side of the screen, Page Up and
/// Page Down to the previous and next page, and Home and End to the first
/// and last page; End needs a page count. A key page change slides over
/// 300 ms, or jumps when the app or the platform asks for less motion.
/// While a node inside a page holds focus, Page Up, Page Down, Home, and End
/// still change the page and move focus to the new page's first node. Tab
/// finishes one page before the next; with [allowImplicitScrolling] it
/// reaches the neighbor pages, and the view then shows the page it entered
/// whole.
///
/// Previous and next buttons are the job of the components built on this
/// layout: a mouse without a trackpad cannot swipe a page view on desktop.
/// Pass a [PageController] with a `viewportFraction` below 1 to show the
/// neighbor pages.
class PageViewLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.controller,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    required List<Widget> this.children,
    this.dragStartBehavior = DragStartBehavior.start,
    this.allowImplicitScrolling = false,
    this.scrollCacheExtent,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.padEnds = true,
    this.showScrollbar,
    this.focusable,
    this.semanticsLabel,
    this.scrollFocusStyle,
  }) : itemBuilder = null,
       findChildIndexCallback = null,
       itemCount = null;

  const new builder({
    super.key,
    this.style,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.controller,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    required NullableIndexedWidgetBuilder this.itemBuilder,
    this.findChildIndexCallback,
    this.itemCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.allowImplicitScrolling = false,
    this.scrollCacheExtent,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.padEnds = true,
    this.showScrollbar,
    this.focusable,
    this.semanticsLabel,
    this.scrollFocusStyle,
  }) : children = null;

  final WidgetStyle? style;
  final Axis scrollDirection;
  final bool reverse;

  /// Drives the keys too; without one a focusable page view makes its own.
  final PageController? controller;
  final ScrollPhysics? physics;
  final bool pageSnapping;
  final ValueChanged<int>? onPageChanged;

  /// The pages of the default constructor.
  final List<Widget>? children;

  /// Builds the pages of [PageViewLayout.builder].
  final NullableIndexedWidgetBuilder? itemBuilder;

  /// Receives the keys of the pages that [itemBuilder] returns.
  final ChildIndexGetter? findChildIndexCallback;

  /// The page count of [PageViewLayout.builder]; null builds pages without
  /// end, and End then does nothing.
  final int? itemCount;
  final DragStartBehavior dragStartBehavior;
  final bool allowImplicitScrolling;
  final ScrollCacheExtent? scrollCacheExtent;
  final String? restorationId;
  final Clip clipBehavior;
  final HitTestBehavior hitTestBehavior;
  final bool padEnds;

  /// Whether the page view shows a scrollbar; null keeps [PageView]'s
  /// default, none. A non-null value also applies to plain Flutter scroll
  /// views inside the pages; layout scroll views there keep the scroll
  /// behavior's choice.
  final bool? showScrollbar;

  /// Whether the page view is a Tab stop that pages by keyboard; null
  /// means on web, mobile web included, and on macOS, Windows, and Linux.
  final bool? focusable;

  /// Names the focusable page view for a screen reader.
  final String? semanticsLabel;

  /// The view's focus ring style, level 3 (FO-06 US-07 FR-03), beside
  /// `style`, which draws the box.
  final ScrollFocusStyle? scrollFocusStyle;

  @override
  Widget build(BuildContext context) {
    final children = this.children;
    return ScrollViewBox(
      style: style,
      focusable: focusable,
      axis: scrollDirection,
      mode: ScrollFocusMode.pages,
      controller: controller,
      pageCount: children?.length ?? itemCount,
      semanticsLabel: semanticsLabel,
      showScrollbar: showScrollbar,
      scrollFocusStyle: scrollFocusStyle,
      scrollsPadding: false,
      builder: (context, controller, padding) {
        // PageView turns scrollbars off unless it receives a behavior.
        final behavior = ScrollConfiguration.of(context)
            .copyWith(scrollbars: showScrollbar ?? false);
        if (children != null) {
          return PageView(
            scrollDirection: scrollDirection,
            reverse: reverse,
            controller: controller as PageController?,
            physics: physics,
            pageSnapping: pageSnapping,
            onPageChanged: onPageChanged,
            dragStartBehavior: dragStartBehavior,
            allowImplicitScrolling: allowImplicitScrolling,
            scrollCacheExtent: scrollCacheExtent,
            restorationId: restorationId,
            clipBehavior: clipBehavior,
            hitTestBehavior: hitTestBehavior,
            scrollBehavior: behavior,
            padEnds: padEnds,
            children: [
              for (final (index, child) in children.indexed)
                _page(index, child),
            ],
          );
        }
        return PageView.builder(
          scrollDirection: scrollDirection,
          reverse: reverse,
          controller: controller as PageController?,
          physics: physics,
          pageSnapping: pageSnapping,
          onPageChanged: onPageChanged,
          itemBuilder: _buildPage,
          findChildIndexCallback: _findChildIndex,
          itemCount: itemCount,
          dragStartBehavior: dragStartBehavior,
          allowImplicitScrolling: allowImplicitScrolling,
          scrollCacheExtent: scrollCacheExtent,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
          hitTestBehavior: hitTestBehavior,
          scrollBehavior: behavior,
          padEnds: padEnds,
        );
      },
    );
  }

  Widget? _buildPage(BuildContext context, int index) {
    final page = itemBuilder!(context, index);
    return page == null ? null : _page(index, page);
  }

  /// [findChildIndexCallback] with the page's own key, which the page's
  /// wrapper carries inside a [_PageKey].
  ChildIndexGetter? get _findChildIndex {
    final callback = findChildIndexCallback;
    if (callback == null) return null;
    return (key) => callback(key is _PageKey ? key.value : key);
  }

  /// [child] as page [index], keyed by the child's own key, so a keyed page
  /// keeps its State when the pages change order.
  static Widget _page(int index, Widget child) {
    final key = child.key;
    return ScrollFocus.page(
      key: key == null ? null : _PageKey(key),
      index: index,
      child: child,
    );
  }
}

/// The key of a page's wrapper: the page's own key, which may be global,
/// so the wrapper cannot carry it as is.
class _PageKey extends ValueKey<Key> {
  const new(super.value);
}
