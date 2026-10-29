import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `ListViewLayout.builder` constructor param, the `argsType`
/// of its stories (fo11/us04/fr01); `itemCount` counts the slot
/// placeholders the item builder builds.
class ListViewLayoutKnobs {
  const ListViewLayoutKnobs({
    required this.style,
    this.gap,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    required this.controller,
    this.primary,
    required this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    this.itemExtent,
    this.prototypeItem = SlotPreset.none,
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

  /// Space between items along `scrollDirection`.
  final double? gap;
  final Axis scrollDirection;
  final bool reverse;
  final Preset<ScrollController> controller;
  final bool? primary;
  final Preset<ScrollPhysics> physics;
  final bool? showScrollbar;
  final bool shrinkWrap;
  final double? itemExtent;
  final SlotPreset prototypeItem;
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

  /// Names the list for a screen reader.
  final Preset<String> semanticsLabel;
  final Preset<ScrollFocusStyle> scrollFocusStyle;
}
