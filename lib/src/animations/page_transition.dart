import 'package:stratum_ui/src/animations/screen_transition.dart';
import 'package:stratum_ui/src/src.dart';

enum ScreenTransitionType {
  /// Fade Animation
  fade,

  /// Right to left animation
  rightToLeft,

  /// Left to right animation
  leftToRight,

  /// Top the bottom animation
  topToBottom,

  /// bottom the top animation
  bottomToTop,

  /// scale animation
  scale,

  /// Rotate animation
  rotate,

  /// Size animation
  size,

  /// Right to left with fading animation
  rightToLeftWithFade,

  /// Left to right with fading animation
  leftToRightWithFade,

  /// Left to right slide as if joined
  leftToRightJoined,

  /// Right to left slide as if joined
  rightToLeftJoined,

  /// Flutter's default page motion for the platform, the builder of
  /// `const PageTransitionsTheme()`, with its own durations and curve.
  platform,

  /// No animation: the new page shows at once, in push and pop.
  none,

  /// The Cupertino slide with swipe-back on every platform, with its own
  /// durations and curve.
  cupertino,

  /// The current page fades out, then the new page fades in and scales up
  /// (package `animations`).
  fadeThrough,

  /// Both pages move along the x axis and share one fade (package
  /// `animations`).
  sharedAxisHorizontal,

  /// Both pages move along the y axis and share one fade (package
  /// `animations`).
  sharedAxisVertical,

  /// Both pages scale along the z axis and share one fade (package
  /// `animations`).
  sharedAxisScaled,
}

class PageTransition<T> extends PageRouteBuilder<T> {
  /// Page transition constructor. We can pass the next page as a child,
  new({
    required this.child,
    required this.type,
    this.childCurrent,
    this.ctx,
    this.inheritTheme = false,
    this.curve,
    this.alignment,
    this.duration,
    this.reverseDuration,
    super.fullscreenDialog = false,
    super.opaque = false,
    super.settings,
  }) : assert(
         !inheritTheme || ctx != null,
         "'ctx' cannot be null when 'inheritTheme' is true, set ctx: context",
       ),
       super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             inheritTheme ? InheritedTheme.captureAll(ctx!, child) : child,
         maintainState: true,
       );

  /// Child for your next page
  final Widget child;

  /// Child for your next page
  final Widget? childCurrent;

  /// The transition; the theme's type never replaces it (US-05 FR-01 E05).
  final ScreenTransitionType type;

  /// The curve; null takes the theme's `standard` curve (spec G21).
  /// `platform` and `cupertino` keep the Flutter motion's own curve, but
  /// the fade a reduced-motion `platform` draws runs on the theme's.
  final Curve? curve;

  /// Alignment for transitions
  final Alignment? alignment;

  /// The push duration; null takes the theme's `slow` level, 300 ms in the
  /// package default.
  final Duration? duration;

  /// The pop duration; null takes the theme's `slow` level reverse, 192 ms
  /// in the package default.
  final Duration? reverseDuration;

  /// Context for inherit theme
  final BuildContext? ctx;

  /// Optional inherit theme
  final bool inheritTheme;

  /// [type]'s transition (US-05 FR-01, FR-03), by the one function every
  /// route of US-05 shares.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => buildScreenTransition<T>(
    type,
    route: this,
    context: context,
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
    curve: curve,
    standard: curveOf(slowOf(context)),
    alignment: alignment,
    childCurrent: childCurrent,
  );

  /// [duration], else the Flutter builder's for `platform` and `cupertino`,
  /// else the `slow` level of the theme above the navigator, else the
  /// package default's (spec G21).
  @override
  Duration get transitionDuration =>
      duration ??
      transitionDurationOf(
        type,
        platformOf(navigator?.context),
        slowOf(navigator?.context),
      );

  /// [reverseDuration], else the Flutter builder's for `platform` and
  /// `cupertino`, else the `slow` level's reverse duration.
  @override
  Duration get reverseTransitionDuration =>
      reverseDuration ??
      reverseTransitionDurationOf(
        type,
        platformOf(navigator?.context),
        slowOf(navigator?.context),
      );
}
