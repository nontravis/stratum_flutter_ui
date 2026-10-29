import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `NestedScrollViewLayout` constructor param, the `argsType`
/// of its stories (fo11/us04/fr01).
class NestedScrollViewLayoutKnobs {
  const NestedScrollViewLayoutKnobs({
    required this.style,
    required this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    required this.physics,
    this.showScrollbar,
    required this.headerSliverBuilder,
    this.body = SlotPreset.slot,
    this.dragStartBehavior = DragStartBehavior.start,
    this.floatHeaderSlivers = false,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.restorationId,
  });

  final Preset<WidgetStyle> style;
  final Preset<ScrollController> controller;
  final Axis scrollDirection;
  final bool reverse;
  final Preset<ScrollPhysics> physics;
  final bool? showScrollbar;

  /// Builds the header slivers.
  final Preset<NestedScrollViewHeaderSliversBuilder> headerSliverBuilder;
  final SlotPreset body;
  final DragStartBehavior dragStartBehavior;
  final bool floatHeaderSlivers;
  final Clip clipBehavior;
  final HitTestBehavior hitTestBehavior;
  final String? restorationId;
}
