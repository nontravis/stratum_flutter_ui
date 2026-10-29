import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `StackLayout` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01); `children` counts the slot placeholders.
class StackLayoutKnobs {
  const StackLayoutKnobs({
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
    required this.alignment,
    this.fit = StackFit.loose,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
    this.children = 3,
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
  final Preset<AlignmentGeometry> alignment;
  final StackFit fit;
  final TextDirection? textDirection;
  final Clip clipBehavior;
  final int children;
}
