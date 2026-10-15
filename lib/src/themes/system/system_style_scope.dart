import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/themes/system/system_style.dart';
import 'package:stratum_ui/src/themes/system/system_style_region.dart';

/// Sets the system bar style of the screen, or the part of it, that
/// [child] paints, over the app-wide style, on any screen and any router
/// (FO-03 US-14 FR-01, FR-03, FR-04).
///
/// Its look fields apply at a bar whose point [child] covers; its bar
/// mode, rotation lock, and app switcher label apply while [child] paints,
/// so a dialog over the page keeps them, a page with no style that covers
/// it takes the app-wide style, and going back restores them, with no
/// restore code. Scopes nest, the inner one winning field by field. It
/// draws nothing and adds no semantics node, focus node, or gesture; a bar
/// color it sets, the theme application paints under the bar.
class SystemStyleScope extends StatelessWidget {
  const new({super.key, required this.style, required this.child});

  /// The fields to set; a null field takes the layer below.
  final SystemStyle style;

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemStyleLayerRegion(style.behavior),
    sized: false,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemStyleLayerRegion(style.look),
      child: child,
    ),
  );
}
