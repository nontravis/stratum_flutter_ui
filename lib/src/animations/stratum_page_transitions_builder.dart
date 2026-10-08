import 'package:stratum_ui/src/animations/screen_transition.dart';
import 'package:stratum_ui/src/src.dart';

/// The page transitions builder `StratumThemeData.toThemeData` installs
/// for every [TargetPlatform] (FO-03 US-08 FR-01 E04), so every
/// [MaterialPageRoute] and [MaterialPage] below the Stratum theme brings
/// its page in with the type [motion]'s `transition` names for the window
/// size (FO-05 US-05 FR-04; style s03 invariants 18 to 20).
/// `PageTransition`, `StratumTransitionPage`, and `NoPageTransition` show
/// their own transition, never this builder's. Internal: not exported.
@immutable
class StratumPageTransitionsBuilder extends PageTransitionsBuilder {
  const new({required this.motion, required this.platform});

  /// The theme's motion: its `transition` types, its `slow` level, and its
  /// `standard` curve.
  final StratumAnimation motion;

  /// The platform `toThemeData` installs this builder for, whose Flutter
  /// builder times `platform`: Flutter reads the durations with no context.
  final TargetPlatform platform;

  /// The type whose durations apply: the theme's type for the window size
  /// of the implicit view, else of `mobile` (invariant 20, ruling R5).
  ScreenTransitionType get _durationType =>
      motion.transition[windowSizeOfView(
        WidgetsBinding.instance.platformDispatcher.implicitView,
      )];

  @override
  Duration get transitionDuration =>
      transitionDurationOf(_durationType, platform, motion.slow);

  @override
  Duration get reverseTransitionDuration =>
      reverseTransitionDurationOf(_durationType, platform, motion.slow);

  /// The theme's type for the window size of the scope above [context],
  /// else of the window's size by FO-07 US-01 FR-01, which never throws
  /// (invariant 19). A type that needs a caller input gets one (ruling R10):
  /// the center for `scale`, `rotate`, and `size`, and the route's own
  /// secondary animation for the joined types.
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final windowSize =
        WindowSizeScope.maybeOf(context) ??
        WindowSize.fromSize(MediaQuery.sizeOf(context));
    return buildScreenTransition<T>(
      motion.transition[windowSize],
      route: route,
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
      standard: curveOf(motion.slow),
      alignment: Alignment.center,
      joinOnSecondary: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is StratumPageTransitionsBuilder &&
      other.motion == motion &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(motion, platform);
}

/// The window size of [view]'s logical size by FO-07 US-01 FR-01, else
/// [WindowSize.mobile] when there is no view, as in a multi-view embedding
/// (ruling R5).
WindowSize windowSizeOfView(FlutterView? view) => view == null
    ? WindowSize.mobile
    : WindowSize.fromSize(view.physicalSize / view.devicePixelRatio);
