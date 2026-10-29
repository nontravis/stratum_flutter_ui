import 'package:stratum_ui/stratum_ui.dart';

import '../kit/preset.dart';

/// One field per `CustomScrollViewLayout` constructor param, the `argsType`
/// of its stories (fo11/us04/fr01); `children` counts the slot
/// placeholders the one lazy list builds. The constructor takes exactly one
/// of `slivers` and `children`, so the Playground passes the slivers while
/// their preset is set and the children count otherwise.
class CustomScrollViewLayoutKnobs {
  const CustomScrollViewLayoutKnobs({
    required this.style,
    required this.slivers,
    this.children = 3,
    required this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    required this.physics,
    this.showScrollbar,
    this.focusable,
    required this.semanticsLabel,
    required this.scrollFocusStyle,
  });

  final Preset<WidgetStyle> style;

  /// The slivers the preset builds, or null in the `children` mode.
  final Preset<List<Widget>?> slivers;
  final int children;
  final Preset<ScrollController> controller;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final Preset<ScrollPhysics> physics;
  final bool? showScrollbar;
  final bool? focusable;
  final Preset<String> semanticsLabel;
  final Preset<ScrollFocusStyle> scrollFocusStyle;
}
