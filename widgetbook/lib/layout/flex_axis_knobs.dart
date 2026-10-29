import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `ColumnLayout` and `RowLayout` constructor param (the two
/// take the same ones), the `argsType` of their stories (fo11/us04/fr01);
/// `children` counts the slot placeholders.
class FlexAxisKnobs {
  const FlexAxisKnobs({
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
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
    required this.focusGroup,
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
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;
  final bool crossAxisIntrinsic;
  final double? gap;
  final Preset<FocusGroup> focusGroup;
  final int children;
}
