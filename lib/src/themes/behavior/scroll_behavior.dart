import 'package:stratum_ui/src/src.dart';

/// The design system's scroll behavior: Material scrollbars and physics,
/// with no overscroll glow or stretch on any platform.
class StratumScrollBehavior extends MaterialScrollBehavior {
  const new();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
