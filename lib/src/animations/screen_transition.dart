import 'package:animations/animations.dart'
    show
        FadeThroughPageTransitionsBuilder,
        SharedAxisPageTransitionsBuilder,
        SharedAxisTransitionType;
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:stratum_ui/src/components/common/style/reduced_motion.dart';
import 'package:stratum_ui/src/src.dart';

/// The `slow` level of the theme above [context], else the package
/// default's (style s03 invariant 14).
AnimationStyle slowOf(BuildContext? context) {
  final theme = context == null
      ? null
      : StratumThemeApplication.maybeOf(context);
  return (theme?.animation ?? StratumAnimation.packageDefault).slow;
}

/// The platform of the Material theme above [context], else
/// [defaultTargetPlatform].
TargetPlatform platformOf(BuildContext? context) =>
    context == null ? defaultTargetPlatform : Theme.of(context).platform;

/// [style]'s duration, else [Duration.zero] for a hand-built [AnimationStyle]
/// that sets none (for example [AnimationStyle.noAnimation]).
Duration durationOf(AnimationStyle style) => style.duration ?? Duration.zero;

/// [style]'s reverse duration, else [durationOf] its own forward duration,
/// for a hand-built [AnimationStyle] that sets none.
Duration reverseDurationOf(AnimationStyle style) =>
    style.reverseDuration ?? durationOf(style);

/// [style]'s curve, else [Curves.easeInOutSine] for a hand-built
/// [AnimationStyle] that sets none.
Curve curveOf(AnimationStyle style) => style.curve ?? Curves.easeInOutSine;

/// The Flutter builder [type] delegates to on [platform] (style s03
/// invariant 21): for [ScreenTransitionType.platform] the builder of
/// `const PageTransitionsTheme()`, or Flutter's zoom where that map names
/// none, never `Theme.of(context).pageTransitionsTheme`, which holds
/// `StratumPageTransitionsBuilder` and would recurse; for
/// [ScreenTransitionType.cupertino] the Cupertino builder on every
/// platform; null for every other type.
PageTransitionsBuilder? flutterTransitionsBuilder(
  ScreenTransitionType type,
  TargetPlatform platform,
) => switch (type) {
  ScreenTransitionType.platform =>
    const PageTransitionsTheme().builders[platform] ??
        const ZoomPageTransitionsBuilder(),
  ScreenTransitionType.cupertino => const CupertinoPageTransitionsBuilder(),
  _ => null,
};

/// The push duration of [type] on [platform]: zero for `none` (ruling R12),
/// else the Flutter builder's for `platform` and `cupertino`, else [slow]'s
/// (US-05 FR-01).
Duration transitionDurationOf(
  ScreenTransitionType type,
  TargetPlatform platform,
  AnimationStyle slow,
) => switch (type) {
  ScreenTransitionType.none => Duration.zero,
  _ =>
    flutterTransitionsBuilder(type, platform)?.transitionDuration ??
        durationOf(slow),
};

/// The pop duration of [type] on [platform]: zero for `none` (ruling R12),
/// else the Flutter builder's for `platform` and `cupertino`, else [slow]'s
/// reverse (US-05 FR-01).
Duration reverseTransitionDurationOf(
  ScreenTransitionType type,
  TargetPlatform platform,
  AnimationStyle slow,
) => switch (type) {
  ScreenTransitionType.none => Duration.zero,
  _ =>
    flutterTransitionsBuilder(type, platform)?.reverseTransitionDuration ??
        reverseDurationOf(slow),
};

/// [type]'s transition of [route]'s page [child], for every route of
/// US-05 (FR-01 and FR-03; style s03 invariants 14 and 21).
///
/// [curve] is the caller's; with none, every type but `platform` and
/// `cupertino` runs on [standard], the theme's `standard` curve, and the
/// Flutter motion those two show keeps its own curve. Under reduced motion
/// ([reducesMotion]) every slide, scale, rotation, and size change drops: a
/// type with a fade keeps a fade over the full duration, and any other type
/// shows the page at once and hides it while the route pops; the Cupertino
/// slide of `platform` on iOS and of `cupertino` moves only while a pop
/// gesture tracks the finger, so the swipe-back stays (FR-04 E04). A fade
/// this function draws itself runs on [curve], else [standard], `platform`
/// included (US-05 FR-03).
///
/// [joinOnSecondary] is for a route with no current page, the theme's
/// builder and `StratumTransitionPage` (ruling R10): a joined type then
/// slides this route's page in by [animation] and out by
/// [secondaryAnimation] instead of painting [childCurrent].
Widget buildScreenTransition<T>(
  ScreenTransitionType type, {
  required PageRoute<T> route,
  required BuildContext context,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
  required Curve standard,
  Curve? curve,
  Alignment? alignment,
  Widget? childCurrent,
  bool joinOnSecondary = false,
}) {
  final resolved = curve ?? standard;
  final reduced = reducesMotion(context);
  final tween = _curveTweenOf(resolved);
  final curved = animation.drive(tween);
  switch (type) {
    case ScreenTransitionType.fade:
      return FadeTransition(opacity: curved, child: child);

    case ScreenTransitionType.rightToLeft:
      if (reduced) return _atOnce(route, animation, child);
      return SlideTransition(
        position: _fromRight.animate(curved),
        child: child,
      );

    case ScreenTransitionType.leftToRight:
      if (reduced) return _atOnce(route, animation, child);
      return SlideTransition(position: _fromLeft.animate(curved), child: child);

    case ScreenTransitionType.topToBottom:
      if (reduced) return _atOnce(route, animation, child);
      return SlideTransition(position: _fromTop.animate(curved), child: child);

    case ScreenTransitionType.bottomToTop:
      if (reduced) return _atOnce(route, animation, child);
      return SlideTransition(
        position: _fromBottom.animate(curved),
        child: child,
      );

    case ScreenTransitionType.scale:
      if (reduced) return _atOnce(route, animation, child);
      return ScaleTransition(
        alignment: alignment!,
        scale: animation.drive(
          CurveTween(curve: Interval(0.00, 0.50, curve: resolved)),
        ),
        child: child,
      );

    case ScreenTransitionType.rotate:
      if (reduced) return _atOnce(route, animation, child);
      return RotationTransition(
        alignment: alignment!,
        turns: curved,
        child: ScaleTransition(
          alignment: alignment,
          scale: curved,
          child: FadeTransition(opacity: curved, child: child),
        ),
      );

    case ScreenTransitionType.size:
      if (reduced) return _atOnce(route, animation, child);
      return Align(
        alignment: alignment!,
        child: SizeTransition(sizeFactor: curved, child: child),
      );

    case ScreenTransitionType.rightToLeftWithFade:
      if (reduced) {
        return FadeTransition(opacity: curved, child: child);
      }
      final slide = _fromRight.animate(curved);
      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
        ),
      );

    case ScreenTransitionType.leftToRightWithFade:
      if (reduced) {
        return FadeTransition(opacity: curved, child: child);
      }
      final slide = _fromLeft.animate(curved);
      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
        ),
      );

    case ScreenTransitionType.rightToLeftJoined:
      if (joinOnSecondary) {
        if (reduced) return _atOnce(route, animation, child);
        return _joinedOnSecondary(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          tween: tween,
          incoming: _fromRight,
          outgoing: _toLeft,
          child: child,
        );
      }
      assert(childCurrent != null, """
                When using type "rightToLeftJoined" you need argument: 'childCurrent'

                example:
                  child: MyPage(),
                  childCurrent: this

                """);
      if (reduced) return _atOnce(route, animation, child);
      return Stack(
        children: <Widget>[
          SlideTransition(
            position: _toLeft.animate(curved),
            child: childCurrent,
          ),
          SlideTransition(position: _fromRight.animate(curved), child: child),
        ],
      );

    case ScreenTransitionType.leftToRightJoined:
      if (joinOnSecondary) {
        if (reduced) return _atOnce(route, animation, child);
        return _joinedOnSecondary(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          tween: tween,
          incoming: _fromLeft,
          outgoing: _toRight,
          child: child,
        );
      }
      assert(childCurrent != null, """
                When using type "leftToRightJoined" you need argument: 'childCurrent'
                example:
                  child: MyPage(),
                  childCurrent: this

                """);
      if (reduced) return _atOnce(route, animation, child);
      return Stack(
        children: <Widget>[
          SlideTransition(position: _fromLeft.animate(curved), child: child),
          SlideTransition(
            position: _toRight.animate(curved),
            child: childCurrent,
          ),
        ],
      );

    case ScreenTransitionType.platform || ScreenTransitionType.cupertino:
      final builder = flutterTransitionsBuilder(
        type,
        Theme.of(context).platform,
      )!;
      final gesture = route.popGestureInProgress;
      if (reduced) {
        if (builder is! CupertinoPageTransitionsBuilder) {
          return FadeTransition(opacity: curved, child: child);
        }
        // The swipe-back stays (FR-04 E04): the builder runs on held
        // animations, and on the route's own only while a pop gesture
        // tracks the finger.
        return _atOnce(
          route,
          animation,
          builder.buildTransitions<T>(
            route,
            context,
            gesture ? animation : kAlwaysCompleteAnimation,
            gesture ? secondaryAnimation : kAlwaysDismissedAnimation,
            child,
          ),
        );
      }
      return builder.buildTransitions<T>(
        route,
        context,
        _onCallerCurve(animation, curve, gesture: gesture),
        _onCallerCurve(secondaryAnimation, curve, gesture: gesture),
        child,
      );
    case ScreenTransitionType.none:
      return child;
    case ScreenTransitionType.fadeThrough:
      if (reduced) return FadeTransition(opacity: curved, child: child);
      return FadeThroughPageTransitionsBuilder(
        fillColor: Theme.of(context).canvasColor,
      ).buildTransitions<T>(
        route,
        context,
        curved,
        secondaryAnimation.drive(tween),
        child,
      );
    case ScreenTransitionType.sharedAxisHorizontal ||
        ScreenTransitionType.sharedAxisVertical ||
        ScreenTransitionType.sharedAxisScaled:
      if (reduced) return FadeTransition(opacity: curved, child: child);
      return SharedAxisPageTransitionsBuilder(
        transitionType: switch (type) {
          ScreenTransitionType.sharedAxisVertical =>
            SharedAxisTransitionType.vertical,
          ScreenTransitionType.sharedAxisScaled =>
            SharedAxisTransitionType.scaled,
          _ => SharedAxisTransitionType.horizontal,
        },
        fillColor: Theme.of(context).canvasColor,
      ).buildTransitions<T>(
        route,
        context,
        curved,
        secondaryAnimation.drive(tween),
        child,
      );
  }
}

/// The transition a route of [type] hands the route below it, so the page
/// below leaves in step with [type]'s page coming in, for every route of
/// US-05 (FR-01; style s03 invariant 21).
///
/// For `platform` and `cupertino` it is the Flutter builder's own on
/// [platform], which may itself be null. For `fadeThrough`, the shared-axis
/// types, and, on a route that joins on its secondary animation
/// ([joinOnSecondary], as in [buildScreenTransition]), the joined types, it
/// draws the outgoing half of [buildScreenTransition] on the page below,
/// on [curve], else the theme's `standard` curve. Every other type gets
/// null, so a route below that moves only for its own kind, such as a
/// [MaterialPageRoute], stays still. A route that is not [opaque] gets null
/// for every type too, by the rule of [leavesUnder]: the page below shows
/// through it, so it stays as it was rather than parked where the outgoing
/// half ends.
///
/// A page never moves twice: Flutter holds the secondary animation of the
/// page below's own transition while this one runs, and
/// [kAlwaysCompleteAnimation] keeps the incoming half out of this one.
/// Under reduced motion ([reducesMotion]) the page below stays still but
/// for a Cupertino pop gesture, which it tracks as in
/// [buildScreenTransition].
DelegatedTransitionBuilder? delegatedScreenTransition(
  ScreenTransitionType type,
  TargetPlatform platform, {
  required bool opaque,
  Curve? curve,
  bool joinOnSecondary = false,
}) => switch (type) {
  _ when !opaque => null,
  ScreenTransitionType.platform || ScreenTransitionType.cupertino =>
    _flutterDelegate(flutterTransitionsBuilder(type, platform)!, curve),
  ScreenTransitionType.rightToLeftJoined ||
  ScreenTransitionType.leftToRightJoined when !joinOnSecondary => null,
  ScreenTransitionType.rightToLeftJoined ||
  ScreenTransitionType.leftToRightJoined ||
  ScreenTransitionType.fadeThrough ||
  ScreenTransitionType.sharedAxisHorizontal ||
  ScreenTransitionType.sharedAxisVertical ||
  ScreenTransitionType.sharedAxisScaled => _outgoingHalf(type, curve),
  _ => null,
};

/// Whether a page moves out under [next], by its own secondary animation
/// or by [next]'s delegated transition (US-05 FR-01; style s03 invariant
/// 21): only under a page route that is opaque or hands its own delegated
/// transition. A page seen through a translucent route stays as it was,
/// unless that route hands a delegate, which then owns how the page
/// beneath looks, as Flutter's Cupertino sheet scales it back; a
/// translucent route of US-05 hands none ([delegatedScreenTransition]).
/// Every route of US-05 holds to it on both sides: `canTransitionTo` for
/// the route above and `canTransitionFrom` for itself.
bool leavesUnder(TransitionRoute<dynamic> next) =>
    next is PageRoute && (next.opaque || next.delegatedTransition != null);

/// [builder]'s own delegated transition, null when it has none, with the
/// caller's [curve] as in [buildScreenTransition].
DelegatedTransitionBuilder? _flutterDelegate(
  PageTransitionsBuilder builder,
  Curve? curve,
) {
  final flutter = builder.delegatedTransition;
  if (flutter == null) return null;
  final cupertino = builder is CupertinoPageTransitionsBuilder;
  return (context, animation, secondaryAnimation, allowSnapshotting, child) {
    final reduced = reducesMotion(context);
    if (reduced && !cupertino) return null;
    final gesture = ModalRoute.of(context)?.popGestureInProgress ?? false;
    return flutter(
      context,
      animation,
      reduced && !gesture
          ? kAlwaysDismissedAnimation
          : _onCallerCurve(secondaryAnimation, curve, gesture: gesture),
      allowSnapshotting,
      child,
    );
  };
}

/// [child] shown at once under reduced motion (US-05 FR-03), and gone
/// while [route] pops by its own [animation], so a pop never paints the
/// popped page for the whole reverse duration; a pop gesture still moves it.
Widget _atOnce<T>(
  PageRoute<T> route,
  Animation<double> animation,
  Widget child,
) => Offstage(
  offstage:
      animation.status == AnimationStatus.reverse &&
      !route.popGestureInProgress,
  child: child,
);

/// [type]'s outgoing half on the page below: [buildScreenTransition] of
/// that page's own route, held complete, leaving by its secondary animation.
DelegatedTransitionBuilder _outgoingHalf(
  ScreenTransitionType type,
  Curve? curve,
) => (context, animation, secondaryAnimation, allowSnapshotting, child) {
  final route = ModalRoute.of(context);
  if (route is! PageRoute<Object?> || child == null || reducesMotion(context)) {
    return null;
  }
  return buildScreenTransition<Object?>(
    type,
    route: route,
    context: context,
    animation: kAlwaysCompleteAnimation,
    secondaryAnimation: secondaryAnimation,
    child: child,
    standard: curveOf(slowOf(context)),
    curve: curve,
    joinOnSecondary: true,
  );
};

/// [animation] on the caller's [curve], else unchanged: with no caller
/// curve, or while a pop [gesture] drives the Flutter builder's own linear
/// tracking (cupertino/route.dart:238-240).
Animation<double> _onCallerCurve(
  Animation<double> animation,
  Curve? curve, {
  required bool gesture,
}) => curve == null || gesture
    ? animation
    : animation.drive(_curveTweenOf(curve));

/// A joined slide for a route with no current page: this route's page
/// comes in by [incoming] on [animation] and leaves by [outgoing] on
/// [secondaryAnimation], both through [tween], while the next route covers
/// it (ruling R10).
Widget _joinedOnSecondary({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required CurveTween tween,
  required Tween<Offset> incoming,
  required Tween<Offset> outgoing,
  required Widget child,
}) => SlideTransition(
  position: outgoing.animate(secondaryAnimation.drive(tween)),
  child: SlideTransition(
    position: incoming.animate(animation.drive(tween)),
    child: child,
  ),
);

/// The constant slides of [buildScreenTransition], built once rather than
/// on every frame of a transition, as Flutter's own transitions keep
/// theirs.
final _fromRight = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
final _fromLeft = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero);
final _fromTop = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero);
final _fromBottom = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero);
final _toLeft = Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0));
final _toRight = Tween<Offset>(begin: Offset.zero, end: const Offset(1, 0));

/// The one [CurveTween] of each curve: a route rebuilds its transition on
/// every frame, and its curve stays the same through it.
final _curveTweens = Expando<CurveTween>('curveTweens');

/// [curve]'s [CurveTween], built on its first use.
CurveTween _curveTweenOf(Curve curve) =>
    _curveTweens[curve] ??= CurveTween(curve: curve);
