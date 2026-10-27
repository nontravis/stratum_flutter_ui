import 'package:stratum_ui/src/src.dart';

/// A [MaterialPageRoute] that shows its page with no animation and zero
/// push and pop durations, whatever the theme's page transitions builder
/// supplies (FO-05 US-05 FR-02; style s03 INV-15).
class NoPageTransition extends MaterialPageRoute<dynamic> {
  new({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  /// Zero, whatever the theme names (US-05 FR-02 E02).
  @override
  Duration get transitionDuration => Duration.zero;

  /// Zero, whatever the theme names (US-05 FR-02 E02).
  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
