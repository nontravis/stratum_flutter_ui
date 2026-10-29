import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `WrapLayout` constructor param, the `argsType` of its
/// stories (fo11/us04/fr01); `children` counts the slot placeholders.
class WrapLayoutKnobs {
  const WrapLayoutKnobs({
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
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.gap,
    this.runGap,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    required this.focusGroup,
    this.maxRuns,
    this.maxChildren,
    required this.overflowBuilder,
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
  final Axis direction;
  final WrapAlignment alignment;
  final double? gap;
  final double? runGap;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final Preset<FocusGroup> focusGroup;
  final int? maxRuns;
  final int? maxChildren;
  final Preset<Widget Function(BuildContext context, int hiddenCount)>
  overflowBuilder;
  final int children;
}
