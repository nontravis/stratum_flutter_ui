import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy list that scrolls inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// items scroll. `style.padding` becomes the list padding, so it scrolls
/// with the items. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them. A [focusable]
/// list is a Tab stop that scrolls by keyboard; see [ScrollFocus].
class ListViewLayout extends StatelessWidget {
  const new builder({
    super.key,
    this.style,
    this.gap,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    this.itemExtent,
    this.prototypeItem,
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
  }) : assert(
         gap == null ||
             (itemCount != null &&
                 itemExtent == null &&
                 prototypeItem == null &&
                 semanticChildCount == null),
         'gap needs an itemCount and takes no itemExtent, prototypeItem, '
         'or semanticChildCount',
       );

  final WidgetStyle? style;

  /// Space between items along [scrollDirection].
  final double? gap;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final bool shrinkWrap;
  final double? itemExtent;
  final Widget? prototypeItem;
  final int? itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Returns item indices, without separators, also when [gap] is set.
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

  /// Whether the list is a Tab stop that scrolls by keyboard; null means
  /// on web and desktop ([defaultScrollFocusable]).
  final bool? focusable;

  /// Names the focusable list for a screen reader.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    Widget list = ScrollFrame(
      showScrollbar: showScrollbar,
      child: Builder(
        builder: (context) =>
            _buildList(ScrollFocus.controllerOf(context), style?.padding),
      ),
    );
    if (style != null) {
      list = ContainerLayout(style: ScrollFrame.boxStyle(style), child: list);
    }
    return ScrollFocus(
      focusable:
          focusable ??
          defaultScrollFocusable(
            isWeb: kIsWeb,
            platform: defaultTargetPlatform,
          ),
      axis: scrollDirection,
      controller: controller,
      primary: primary,
      semanticsLabel: semanticsLabel,
      borderRadius: style?.borderRadius,
      child: list,
    );
  }

  Widget _buildList(ScrollController? controller, EdgeInsetsGeometry? padding) {
    final gap = this.gap;
    if (gap != null) {
      return ListView.separated(
        scrollDirection: scrollDirection,
        reverse: reverse,
        controller: controller,
        primary: primary,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: padding,
        itemBuilder: itemBuilder,
        findItemIndexCallback: findChildIndexCallback,
        separatorBuilder: (context, index) => scrollDirection == Axis.vertical
            ? SizedBox(height: gap)
            : SizedBox(width: gap),
        itemCount: itemCount!,
        addAutomaticKeepAlives: addAutomaticKeepAlives,
        addRepaintBoundaries: addRepaintBoundaries,
        addSemanticIndexes: addSemanticIndexes,
        scrollCacheExtent: scrollCacheExtent,
        dragStartBehavior: dragStartBehavior,
        keyboardDismissBehavior: keyboardDismissBehavior,
        restorationId: restorationId,
        clipBehavior: clipBehavior,
      );
    }
    return ListView.builder(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemExtent: itemExtent,
      prototypeItem: prototypeItem,
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
    );
  }
}
