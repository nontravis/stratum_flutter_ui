import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `GridViewLayout.builder` constructor param, the `argsType`
/// of its stories (fo11/us04/fr01); `itemCount` counts the slot
/// placeholders the item builder builds.
class GridViewLayoutKnobs {
  const GridViewLayoutKnobs({
    required this.style,
    required this.gridDelegate,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    required this.controller,
    this.primary,
    required this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    required this.itemCount,
    required this.itemBuilder,
    required this.findChildIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    required this.scrollCacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.focusable,
    required this.semanticsLabel,
    required this.scrollFocusStyle,
  });

  final Preset<WidgetStyle> style;
  final Preset<SliverGridDelegate> gridDelegate;
  final Axis scrollDirection;
  final bool reverse;
  final Preset<ScrollController> controller;
  final bool? primary;
  final Preset<ScrollPhysics> physics;
  final bool? showScrollbar;
  final bool shrinkWrap;
  final int itemCount;
  final Preset<Widget? Function(BuildContext context, int index)> itemBuilder;
  final Preset<ChildIndexGetter> findChildIndexCallback;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final Preset<ScrollCacheExtent> scrollCacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final bool? focusable;

  /// Names the grid for a screen reader.
  final Preset<String> semanticsLabel;
  final Preset<ScrollFocusStyle> scrollFocusStyle;
}
