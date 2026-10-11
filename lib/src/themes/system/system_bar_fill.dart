import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/themes/system/system_style_region.dart';

/// Declares [color], the fill [child] paints, for the automatic bar icons
/// of a bar whose point [child] covers (FO-03 US-14 FR-02, FR-05).
///
/// Wrap every surface that paints under the status bar or the navigation
/// bar, a header, a full-screen video, or a translucent scrim, so the
/// icons take the color of higher contrast against it; a translucent
/// [color] blends over the fills beneath it. It draws nothing and adds no
/// semantics node, focus node, or gesture: [child] paints the fill itself.
class SystemBarFill extends StatelessWidget {
  const new({super.key, required this.color, required this.child});

  /// The color [child] paints under the bar, its alpha included.
  final Color color;

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemBarFillRegion(color),
    child: child,
  );
}
