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
}

class PageTransition<T> extends PageRouteBuilder<T> {
  /// Child for your next page
  final Widget child;

  /// Child for your next page
  final Widget? childCurrent;

  /// Transition types
  ///  fade,rightToLeft,leftToRight, upToDown,downToUp,scale,rotate,size,rightToLeftWithFade,leftToRightWithFade
  final ScreenTransitionType type;

  /// The curve; null takes the theme's `slow` level curve, `standard`
  /// (spec G21).
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

  /// Page transition constructor. We can pass the next page as a child,
  PageTransition({
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
         inheritTheme ? ctx != null : true,
         "'ctx' cannot be null when 'inheritTheme' is true, set ctx: context",
       ),
       super(
         pageBuilder:
             (
               BuildContext context,
               Animation<double> animation,
               Animation<double> secondaryAnimation,
             ) {
               return inheritTheme
                   ? InheritedTheme.captureAll(ctx!, child)
                   : child;
             },
         maintainState: true,
         transitionsBuilder:
             (
               BuildContext context,
               Animation<double> animation,
               Animation<double> secondaryAnimation,
               Widget child,
             ) {
               final resolved = curve ?? _curveOf(_slowOf(context));
               switch (type) {
                 case ScreenTransitionType.fade:
                   return FadeTransition(opacity: animation, child: child);

                 /// PageTransitionType.rightToLeft which is the give us right to left transition
                 case ScreenTransitionType.rightToLeft:
                   return SlideTransition(
                     position:
                         Tween<Offset>(
                           begin: const Offset(1, 0),
                           end: Offset.zero,
                         ).animate(
                           CurvedAnimation(parent: animation, curve: resolved),
                         ),
                     child: child,
                   );

                 /// PageTransitionType.leftToRight which is the give us left to right transition
                 case ScreenTransitionType.leftToRight:
                   return SlideTransition(
                     position:
                         Tween<Offset>(
                           begin: const Offset(-1, 0),
                           end: Offset.zero,
                         ).animate(
                           CurvedAnimation(parent: animation, curve: resolved),
                         ),
                     child: child,
                   );

                 /// PageTransitionType.topToBottom which is the give us up to down transition
                 case ScreenTransitionType.topToBottom:
                   return SlideTransition(
                     position:
                         Tween<Offset>(
                           begin: const Offset(0, -1),
                           end: Offset.zero,
                         ).animate(
                           CurvedAnimation(parent: animation, curve: resolved),
                         ),
                     child: child,
                   );

                 /// PageTransitionType.downToUp which is the give us down to up transition
                 case ScreenTransitionType.bottomToTop:
                   return SlideTransition(
                     position:
                         Tween<Offset>(
                           begin: const Offset(0, 1),
                           end: Offset.zero,
                         ).animate(
                           CurvedAnimation(parent: animation, curve: resolved),
                         ),
                     child: child,
                   );

                 /// PageTransitionType.scale which is the scale functionality for transition you can also use curve for this transition

                 case ScreenTransitionType.scale:
                   return ScaleTransition(
                     alignment: alignment!,
                     scale: CurvedAnimation(
                       parent: animation,
                       curve: Interval(0.00, 0.50, curve: resolved),
                     ),
                     child: child,
                   );

                 /// PageTransitionType.rotate which is the rotate functionality for transition you can also use alignment for this transition

                 case ScreenTransitionType.rotate:
                   return RotationTransition(
                     alignment: alignment!,
                     turns: animation,
                     child: ScaleTransition(
                       alignment: alignment,
                       scale: animation,
                       child: FadeTransition(opacity: animation, child: child),
                     ),
                   );

                 /// PageTransitionType.size which is the rotate functionality for transition you can also use curve for this transition

                 case ScreenTransitionType.size:
                   return Align(
                     alignment: alignment!,
                     child: SizeTransition(
                       sizeFactor: CurvedAnimation(
                         parent: animation,
                         curve: resolved,
                       ),
                       child: child,
                     ),
                   );

                 /// PageTransitionType.rightToLeftWithFade which is the fade functionality from right o left

                 case ScreenTransitionType.rightToLeftWithFade:
                   return SlideTransition(
                     position:
                         Tween<Offset>(
                           begin: const Offset(1.0, 0.0),
                           end: Offset.zero,
                         ).animate(
                           CurvedAnimation(parent: animation, curve: resolved),
                         ),
                     child: FadeTransition(
                       opacity: animation,
                       child: SlideTransition(
                         position: Tween<Offset>(
                           begin: const Offset(1, 0),
                           end: Offset.zero,
                         ).animate(animation),
                         child: child,
                       ),
                     ),
                   );

                 /// PageTransitionType.leftToRightWithFade which is the fade functionality from left o right with curve

                 case ScreenTransitionType.leftToRightWithFade:
                   return SlideTransition(
                     position:
                         Tween<Offset>(
                           begin: const Offset(-1.0, 0.0),
                           end: Offset.zero,
                         ).animate(
                           CurvedAnimation(parent: animation, curve: resolved),
                         ),
                     child: FadeTransition(
                       opacity: animation,
                       child: SlideTransition(
                         position: Tween<Offset>(
                           begin: const Offset(-1, 0),
                           end: Offset.zero,
                         ).animate(animation),
                         child: child,
                       ),
                     ),
                   );

                 case ScreenTransitionType.rightToLeftJoined:
                   assert(childCurrent != null, """
                When using type "rightToLeftJoined" you need argument: 'childCurrent'

                example:
                  child: MyPage(),
                  childCurrent: this

                """);
                   return Stack(
                     children: <Widget>[
                       SlideTransition(
                         position:
                             Tween<Offset>(
                               begin: Offset.zero,
                               end: const Offset(-1.0, 0.0),
                             ).animate(
                               CurvedAnimation(
                                 parent: animation,
                                 curve: resolved,
                               ),
                             ),
                         child: childCurrent,
                       ),
                       SlideTransition(
                         position:
                             Tween<Offset>(
                               begin: const Offset(1.0, 0.0),
                               end: Offset.zero,
                             ).animate(
                               CurvedAnimation(
                                 parent: animation,
                                 curve: resolved,
                               ),
                             ),
                         child: child,
                       ),
                     ],
                   );

                 case ScreenTransitionType.leftToRightJoined:
                   assert(childCurrent != null, """
                When using type "leftToRightJoined" you need argument: 'childCurrent'
                example:
                  child: MyPage(),
                  childCurrent: this

                """);
                   return Stack(
                     children: <Widget>[
                       SlideTransition(
                         position:
                             Tween<Offset>(
                               begin: const Offset(-1.0, 0.0),
                               end: Offset.zero,
                             ).animate(
                               CurvedAnimation(
                                 parent: animation,
                                 curve: resolved,
                               ),
                             ),
                         child: child,
                       ),
                       SlideTransition(
                         position:
                             Tween<Offset>(
                               begin: Offset.zero,
                               end: const Offset(1.0, 0.0),
                             ).animate(
                               CurvedAnimation(
                                 parent: animation,
                                 curve: resolved,
                               ),
                             ),
                         child: childCurrent,
                       ),
                     ],
                   );
               }
             },
       );

  /// [duration], else the `slow` level of the theme above the navigator,
  /// else the package default's (spec G21).
  @override
  Duration get transitionDuration =>
      duration ?? _durationOf(_slowOf(navigator?.context));

  /// [reverseDuration], else the `slow` level's reverse duration.
  @override
  Duration get reverseTransitionDuration =>
      reverseDuration ?? _reverseDurationOf(_slowOf(navigator?.context));

  /// The `slow` level of the theme above [context], else the package
  /// default's.
  static AnimationStyle _slowOf(BuildContext? context) {
    final theme = context == null
        ? null
        : StratumThemeApplication.maybeOf(context);
    return (theme?.animation ?? StratumAnimation.packageDefault).slow;
  }
}

/// [style]'s duration, else [Duration.zero] for a hand-built [AnimationStyle]
/// that sets none (for example [AnimationStyle.noAnimation]).
Duration _durationOf(AnimationStyle style) => style.duration ?? Duration.zero;

/// [style]'s reverse duration, else [_durationOf] its own forward duration,
/// for a hand-built [AnimationStyle] that sets none.
Duration _reverseDurationOf(AnimationStyle style) =>
    style.reverseDuration ?? _durationOf(style);

/// [style]'s curve, else [Curves.easeInOutSine] for a hand-built
/// [AnimationStyle] that sets none.
Curve _curveOf(AnimationStyle style) => style.curve ?? Curves.easeInOutSine;
