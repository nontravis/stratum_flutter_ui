import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';
import '../kit/slot_preset.dart';

/// One field per `ContainerLayout` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01).
class ContainerLayoutKnobs {
  const ContainerLayoutKnobs({
    required this.style,
    this.ratio,
    this.rotate,
    required this.transform,
    required this.transformAlignment,
    this.keepAlive = false,
    this.repaintBoundary = false,
    required this.semantics,
    this.onEndAnimate = true,
    required this.interaction,
    required this.scroll,
    this.fit,
    this.child = SlotPreset.slot,
    required this.builder,
  });

  final Preset<WidgetStyle> style;
  final double? ratio;
  final double? rotate;
  final Preset<Matrix4> transform;
  final Preset<AlignmentGeometry> transformAlignment;
  final bool keepAlive;
  final bool repaintBoundary;
  final Preset<SemanticsProperties> semantics;
  final bool onEndAnimate;
  final Preset<Interaction> interaction;
  final Preset<Scroll> scroll;
  final BoxFit? fit;
  final SlotPreset child;
  final Preset<Widget Function(BuildContext context, InteractionState state)>
  builder;
}
