import 'package:stratum_ui/src/src.dart';

/// Lets the EndUser pinch to zoom a web app between [minScale] and
/// [maxScale], pan it, and see it clipped to this widget's bounds; on
/// Android, iOS, macOS, Windows, and Linux it builds [child] alone
/// (CO-01-04 US-01).
///
/// In debug builds on every platform the constructor asserts that
/// [minScale] is above 0 and [maxScale] is at least [minScale]. It extends
/// no component base, as [Slot] does.
class StratumWebZoom extends StatelessWidget {
  const new({
    super.key,
    this.minScale = 1.0,
    this.maxScale = 2.5,
    required this.child,
  }) : assert(
         minScale > 0,
         'StratumWebZoom: minScale must be above 0, got $minScale',
       ),
       assert(
         maxScale >= minScale,
         'StratumWebZoom: maxScale must be at least minScale, got '
         '$maxScale below $minScale',
       );

  /// Default 1.0, so the app never shows smaller than its own layout.
  final double minScale;

  /// Default 2.5, Flutter's default.
  final double maxScale;

  /// The web app, or the part of it to zoom.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return InteractiveViewer(
      minScale: minScale,
      maxScale: maxScale,
      child: child,
    );
  }
}
