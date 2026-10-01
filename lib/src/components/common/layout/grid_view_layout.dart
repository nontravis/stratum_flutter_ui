import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy grid that scrolls inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// items scroll. `style.padding` becomes the grid padding, so it scrolls
/// with the items. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them.
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

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    Widget grid = ScrollFrame(
      showScrollbar: showScrollbar,
      child: GridView.builder(
        gridDelegate: gridDelegate,
        scrollDirection: scrollDirection,
        reverse: reverse,
        controller: controller,
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
    );
    if (style != null) {
      grid = ContainerLayout(style: ScrollFrame.boxStyle(style), child: grid);
    }
    return grid;
  }
}
