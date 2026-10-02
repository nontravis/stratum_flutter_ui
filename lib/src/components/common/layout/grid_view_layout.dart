import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy grid that scrolls inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// items scroll. `style.padding` becomes the grid padding, so it scrolls
/// with the items. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them. A [focusable]
/// grid, by default one on web or on macOS, Windows, or Linux, is a Tab
/// stop whose arrows, Page Up, Page Down, Home, and End scroll it.
class GridViewLayout extends StatelessWidget {
  const new builder({
    super.key,
    this.style,
    required this.gridDelegate,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    required this.itemCount,
    required this.itemBuilder,
    this.findChildIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.scrollCacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.focusable,
    this.semanticsLabel,
  });

  final WidgetStyle? style;
  final SliverGridDelegate gridDelegate;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final bool shrinkWrap;
  final int? itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ChildIndexGetter? findChildIndexCallback;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final ScrollCacheExtent? scrollCacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  /// Whether the grid is a Tab stop that scrolls by keyboard; null means
  /// on web, mobile web included, and on macOS, Windows, and Linux.
  final bool? focusable;

  /// Names the focusable grid for a screen reader.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    final focusable =
        this.focusable ??
        defaultScrollFocusable(isWeb: kIsWeb, platform: defaultTargetPlatform);
    Widget grid = ScrollFrame(
      showScrollbar: showScrollbar,
      child: Builder(
        builder: (context) => GridView.builder(
          gridDelegate: gridDelegate,
          scrollDirection: scrollDirection,
          reverse: reverse,
          controller: ScrollFocus.controllerOf(context),
          primary: primary,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: style?.padding,
          itemBuilder: itemBuilder,
          findChildIndexCallback: findChildIndexCallback,
          itemCount: itemCount,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          scrollCacheExtent: scrollCacheExtent,
          semanticChildCount: semanticChildCount,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
        ),
      ),
    );
    if (focusable) grid = ScrollFocus.contentGroup(grid);
    if (style != null) {
      grid = ContainerLayout(style: ScrollFrame.boxStyle(style), child: grid);
    }
    return ScrollFocus(
      focusable: focusable,
      axis: scrollDirection,
      controller: controller,
      primary: primary,
      semanticsLabel: semanticsLabel,
      borderRadius: style?.borderRadius,
      child: grid,
    );
  }
}
