import 'package:flutter/rendering.dart'
    show ItemExtentBuilder, ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `ReorderableListViewLayout.builder` constructor param, the
/// `argsType` of its stories (fo11/us04/fr01); `itemCount` counts the slot
/// placeholders the item builder builds.
class ReorderableListViewLayoutKnobs {
  const ReorderableListViewLayoutKnobs({
    required this.style,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    required this.controller,
    this.primary,
    required this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    this.itemExtent,
    required this.itemExtentBuilder,
    this.prototypeItem = SlotPreset.none,
    required this.itemCount,
    required this.itemBuilder,
    this.onReorderItem = true,
    this.onReorderStart = true,
    this.onReorderEnd = true,
    required this.dragStyle,
    this.longPressDrag = true,
    required this.itemsController,
    required this.itemTransitionBuilder,
    required this.scrollCacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
    this.focusable,
    required this.semanticsLabel,
    required this.scrollFocusStyle,
    required this.findChildIndexCallback,
    required this.moveAnnouncement,
    required this.atStartAnnouncement,
    required this.atEndAnnouncement,
  });

  final Preset<WidgetStyle> style;
  final Axis scrollDirection;
  final bool reverse;
  final Preset<ScrollController> controller;
  final bool? primary;
  final Preset<ScrollPhysics> physics;
  final bool? showScrollbar;
  final bool shrinkWrap;
  final double? itemExtent;
  final Preset<ItemExtentBuilder?> itemExtentBuilder;
  final SlotPreset prototypeItem;
  final int itemCount;
  final RequiredPreset<Widget Function(BuildContext context, int index)>
  itemBuilder;

  /// Whether the list reports `onReorderItem called`.
  final bool onReorderItem;

  /// Whether the list reports `onReorderStart called`.
  final bool onReorderStart;

  /// Whether the list reports `onReorderEnd called`.
  final bool onReorderEnd;
  final Preset<WidgetStyle> dragStyle;
  final bool longPressDrag;
  final Preset<ReorderableItemsController> itemsController;
  final Preset<
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      Widget child,
    )?
  >
  itemTransitionBuilder;
  final Preset<ScrollCacheExtent> scrollCacheExtent;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final double? autoScrollerVelocityScalar;
  final bool? focusable;
  final Preset<String> semanticsLabel;
  final Preset<ScrollFocusStyle> scrollFocusStyle;
  final Preset<ChildIndexGetter> findChildIndexCallback;
  final Preset<String Function(int position, int count)> moveAnnouncement;
  final Preset<String> atStartAnnouncement;
  final Preset<String> atEndAnnouncement;
}
