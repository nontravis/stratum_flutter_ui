import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `PageViewLayout.builder` constructor param, the `argsType`
/// of its stories (fo11/us04/fr01); `itemCount` counts the slot pages the
/// item builder builds.
class PageViewLayoutKnobs {
  const PageViewLayoutKnobs({
    required this.style,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    required this.controller,
    required this.physics,
    this.pageSnapping = true,
    this.onPageChanged = true,
    required this.itemBuilder,
    required this.findChildIndexCallback,
    this.itemCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.allowImplicitScrolling = false,
    required this.scrollCacheExtent,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.padEnds = true,
    this.showScrollbar,
    this.focusable,
    required this.semanticsLabel,
    required this.scrollFocusStyle,
  });

  final Preset<WidgetStyle> style;
  final Axis scrollDirection;
  final bool reverse;
  final Preset<PageController> controller;
  final Preset<ScrollPhysics> physics;
  final bool pageSnapping;

  /// Whether the page reports `onPageChanged called`.
  final bool onPageChanged;
  final Preset<Widget? Function(BuildContext context, int index)> itemBuilder;
  final Preset<ChildIndexGetter> findChildIndexCallback;
  final int? itemCount;
  final DragStartBehavior dragStartBehavior;
  final bool allowImplicitScrolling;
  final Preset<ScrollCacheExtent> scrollCacheExtent;
  final String? restorationId;
  final Clip clipBehavior;
  final HitTestBehavior hitTestBehavior;
  final bool padEnds;
  final bool? showScrollbar;
  final bool? focusable;

  /// Names the view for a screen reader.
  final Preset<String> semanticsLabel;
  final Preset<ScrollFocusStyle> scrollFocusStyle;
}
