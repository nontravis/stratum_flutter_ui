import 'package:stratum_ui/src/animations/screen_transition.dart';
import 'package:stratum_ui/src/src.dart';

/// A page for a declarative router's page builder, such as go_router's
/// `pageBuilder` (`key: state.pageKey`), or a Navigator 2.0 page list.
/// Its route brings [child] in with [type], any of the nineteen
/// [ScreenTransitionType]s, never the type the theme names for the window
/// size (FO-05 US-05 FR-05; style s03 invariant 22), on the durations and
/// curve of FR-01 and FR-03.
class StratumTransitionPage<T> extends Page<T> {
  const new({
    required this.child,
    required this.type,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The new page.
  final Widget child;

  /// The transition; the theme's type never replaces it.
  final ScreenTransitionType type;

  @override
  Route<T> createRoute(BuildContext context) =>
      _StratumTransitionPageRoute<T>(this);
}

/// The route of a [StratumTransitionPage]. It reads its page from
/// [settings], so a new page under the same key updates it in place.
class _StratumTransitionPageRoute<T> extends PageRoute<T> {
  new(StratumTransitionPage<T> page) : super(settings: page);

  StratumTransitionPage<T> get _page => settings as StratumTransitionPage<T>;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  /// The Flutter builder's for `platform` and `cupertino`, else the `slow`
  /// level of the theme above the navigator (US-05 FR-01).
  @override
  Duration get transitionDuration => transitionDurationOf(
    _page.type,
    platformOf(navigator?.context),
    slowOf(navigator?.context),
  );

  /// The Flutter builder's for `platform` and `cupertino`, else the `slow`
  /// level's reverse duration.
  @override
  Duration get reverseTransitionDuration => reverseTransitionDurationOf(
    _page.type,
    platformOf(navigator?.context),
    slowOf(navigator?.context),
  );

  /// [StratumTransitionPage.child] in a route scope, as a [MaterialPage]'s
  /// route gives it, so a screen reader announces the new page's name.
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  /// [StratumTransitionPage.type]'s transition. A type that needs a caller
  /// input gets one (ruling R10): the center for `scale`, `rotate`, and
  /// `size`, and the route's own secondary animation for the joined types.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => buildScreenTransition<T>(
    _page.type,
    route: this,
    context: context,
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
    standard: curveOf(slowOf(context)),
    alignment: Alignment.center,
    joinOnSecondary: true,
  );

  /// The transition the route below leaves by (US-05 FR-01; style s03
  /// invariant 21), by the one function every route of US-05 shares.
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      delegatedScreenTransition(
        _page.type,
        platformOf(navigator?.context),
        joinOnSecondary: true,
      );

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}
