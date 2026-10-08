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

/// The push duration of [type] on [platform]: the Flutter builder's for
/// `platform` and `cupertino`, else [slow]'s (US-05 FR-01).
Duration transitionDurationOf(
  ScreenTransitionType type,
  TargetPlatform platform,
  AnimationStyle slow,
) =>
    flutterTransitionsBuilder(type, platform)?.transitionDuration ??
    durationOf(slow);

/// The pop duration of [type] on [platform]: the Flutter builder's for
/// `platform` and `cupertino`, else [slow]'s reverse (US-05 FR-01).
Duration reverseTransitionDurationOf(
  ScreenTransitionType type,
  TargetPlatform platform,
  AnimationStyle slow,
) =>
    flutterTransitionsBuilder(type, platform)?.reverseTransitionDuration ??
    reverseDurationOf(slow);

/// [type]'s transition of [route]'s page [child], for every route of
/// US-05 (FR-01 and FR-03; style s03 invariants 14 and 21).
///
/// [curve] is the caller's; with none, every type but `platform` and
/// `cupertino` runs on [standard], the theme's `standard` curve, and the
/// Flutter motion those two show keeps its own curve. Under reduced motion
/// ([reducesMotion]) every slide, scale, rotation, and size change drops: a
/// type with a fade keeps a fade over the full duration, and any other type
/// shows the page at once. A fade this function draws itself runs on
/// [curve], else [standard], `platform` included (US-05 FR-03).
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
  final curved = animation.drive(CurveTween(curve: resolved));
  switch (type) {
    case ScreenTransitionType.fade:
      return FadeTransition(opacity: curved, child: child);

    case ScreenTransitionType.rightToLeft:
      if (reduced) return child;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: resolved)),
        child: child,
      );

    case ScreenTransitionType.leftToRight:
      if (reduced) return child;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: resolved)),
        child: child,
      );

    case ScreenTransitionType.topToBottom:
      if (reduced) return child;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: resolved)),
        child: child,
      );

    case ScreenTransitionType.bottomToTop:
      if (reduced) return child;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: resolved)),
        child: child,
      );

    case ScreenTransitionType.scale:
      if (reduced) return child;
      return ScaleTransition(
        alignment: alignment!,
        scale: CurvedAnimation(
          parent: animation,
          curve: Interval(0.00, 0.50, curve: resolved),
        ),
        child: child,
      );

    case ScreenTransitionType.rotate:
      if (reduced) return child;
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
      if (reduced) return child;
      return Align(
        alignment: alignment!,
        child: SizeTransition(
          sizeFactor: CurvedAnimation(parent: animation, curve: resolved),
          child: child,
        ),
      );

    case ScreenTransitionType.rightToLeftWithFade:
      if (reduced) {
        return FadeTransition(opacity: curved, child: child);
      }
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: resolved)),
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );

    case ScreenTransitionType.leftToRightWithFade:
      if (reduced) {
        return FadeTransition(opacity: curved, child: child);
      }
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: resolved)),
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );

    case ScreenTransitionType.rightToLeftJoined:
      if (joinOnSecondary) {
        if (reduced) return child;
        return _joinedOnSecondary(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          curve: resolved,
          incoming: const Offset(1, 0),
          outgoing: const Offset(-1, 0),
          child: child,
        );
      }
      assert(childCurrent != null, """
                When using type "rightToLeftJoined" you need argument: 'childCurrent'

                example:
                  child: MyPage(),
                  childCurrent: this

                """);
      if (reduced) return child;
      return Stack(
        children: <Widget>[
          SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-1.0, 0.0),
            ).animate(CurvedAnimation(parent: animation, curve: resolved)),
            child: childCurrent,
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: resolved)),
            child: child,
          ),
        ],
      );

    case ScreenTransitionType.leftToRightJoined:
      if (joinOnSecondary) {
        if (reduced) return child;
        return _joinedOnSecondary(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          curve: resolved,
          incoming: const Offset(-1, 0),
          outgoing: const Offset(1, 0),
          child: child,
        );
      }
      assert(childCurrent != null, """
                When using type "leftToRightJoined" you need argument: 'childCurrent'
                example:
                  child: MyPage(),
                  childCurrent: this

                """);
      if (reduced) return child;
      return Stack(
        children: <Widget>[
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: resolved)),
            child: child,
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(1.0, 0.0),
            ).animate(CurvedAnimation(parent: animation, curve: resolved)),
            child: childCurrent,
          ),
        ],
      );

    case ScreenTransitionType.platform || ScreenTransitionType.cupertino:
      final builder = flutterTransitionsBuilder(
        type,
        Theme.of(context).platform,
      )!;
      if (reduced) {
        return builder is CupertinoPageTransitionsBuilder
            ? child
            : FadeTransition(opacity: curved, child: child);
      }
      return builder.buildTransitions<T>(
        route,
        context,
        curve == null ? animation : animation.drive(CurveTween(curve: curve)),
        curve == null
            ? secondaryAnimation
            : secondaryAnimation.drive(CurveTween(curve: curve)),
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
        secondaryAnimation.drive(CurveTween(curve: resolved)),
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
        secondaryAnimation.drive(CurveTween(curve: resolved)),
        child,
      );
  }
}

/// A joined slide for a route with no current page: this route's page
/// comes in from [incoming] by [animation] and leaves toward [outgoing] by
/// [secondaryAnimation] while the next route covers it (ruling R10).
Widget _joinedOnSecondary({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Curve curve,
  required Offset incoming,
  required Offset outgoing,
  required Widget child,
}) => SlideTransition(
  position: Tween<Offset>(
    begin: Offset.zero,
    end: outgoing,
  ).animate(CurvedAnimation(parent: secondaryAnimation, curve: curve)),
  child: SlideTransition(
    position: Tween<Offset>(
      begin: incoming,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: curve)),
    child: child,
  ),
);
