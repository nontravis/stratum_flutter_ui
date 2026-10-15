import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/layout/scrim.dart' show Scrim;
import 'package:stratum_ui/src/src.dart';

/// A [PageLayout] side that holds a drawer: [left] is the start side and
/// [right] the end side, so under [TextDirection.rtl] [left] opens from the
/// right edge.
enum PageDrawerSide {
  /// The start side, `PageLayout.left`.
  left,

  /// The end side, `PageLayout.right`.
  right,
}

/// The drawer type a side with no type takes on [platform]: `slide` on iOS
/// and `front` elsewhere (US-19 FR-02 E01, E02).
PageDrawerType defaultDrawerType(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
    ? PageDrawerType.slide
    : PageDrawerType.front;

/// [side]'s drawer type on [platform].
PageDrawerType resolveDrawerType(PageSide side, TargetPlatform platform) =>
    side.type ?? defaultDrawerType(platform);

/// A drawer's width on a screen [screenWidth] wide: 80% of it, at most
/// [max], else 360, and at least [min] (US-19 FR-04 E01 to E03).
double drawerWidth(double screenWidth, {double? min, double? max}) {
  final upper = max ?? 360;
  final lower = math.min(min ?? 0, upper);
  return (screenWidth * 0.8).clamp(lower, upper);
}

/// The width of the right overlay drawer at [window]: 450 at
/// [WindowSize.bigDesktop] and 400 below it, the Figma `RIGHT_DRAWER`
/// frames (US-19 FR-01 E04).
double overlayDrawerWidth(WindowSize window) =>
    window == WindowSize.bigDesktop ? 450 : 400;

/// The width [side]'s inline pane opens at on [window] while no width is
/// chosen: the Figma page layout's side widths, `left` 280 and `right` 380
/// at [WindowSize.bigDesktop], the 1600 `DESKTOP` frame, and `left` 260 and
/// `right` 320 below it, the 1200 `TABLET` frame (US-19 FR-06 E10).
double inlinePaneWidth(PageDrawerSide side, WindowSize window) {
  final wide = window == WindowSize.bigDesktop;
  return switch (side) {
    PageDrawerSide.left => wide ? 280 : 260,
    PageDrawerSide.right => wide ? 380 : 320,
  };
}

/// The drawer a [PageDrawerStage] draws: its `side`, that side's `config`
/// and resolved `type`, its `width`, and whether it sits `atLeft`, on the
/// physical left screen edge.
typedef _Drawn = ({
  PageDrawerSide side,
  PageSide config,
  PageDrawerType type,
  double width,
  bool atLeft,
});

/// The drawers of a [PageLayout] around [child], the page: both sides below
/// the drawer cut, and the right overlay drawer at and above it (layout s03
/// invariants 65 to 69).
///
/// While [shown] names a side, its panel from [panel] sits on that side's
/// screen edge at the drawer width, and the page behind sits under the
/// [Scrim]; [progress] moves them by the side's type, or only fades the
/// panel under `context.reducesMotion`. The panel reads as its own named
/// screen, keeps focus in [focusNode], and closes by Esc; the scrim reads
/// the dismiss label and closes by a tap; back closes it while [open]
/// holds, before the route pops. A drag on the shown drawer, or one from a
/// side's screen edge while [edgeSwipe] holds, reports through
/// [onDragStart], [onDragUpdate], and [onDragEnd]; on iOS the start edge of
/// a page that can go back is left to the back swipe (US-19 FR-03 E03).
class PageDrawerStage extends StatelessWidget {
  const new({
    super.key,
    required this.progress,
    required this.shown,
    required this.open,
    required this.left,
    required this.right,
    required this.edgeSwipe,
    required this.focusNode,
    required this.panel,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  /// The drawer's 0-to-1 animation, already on the theme's `standard` curve
  /// in time and following a drag one to one.
  final Animation<double> progress;

  /// The side whose drawer shows, opening, open, or closing; null when
  /// none shows.
  final PageDrawerSide? shown;

  /// Whether a drawer is open or opening, so back closes it first.
  final bool open;

  /// The start side's drawer; null when that side has no drawer.
  final PageSide? left;

  /// The end side's drawer; null when that side has no drawer.
  final PageSide? right;

  /// Whether a swipe from a side's screen edge opens its drawer.
  final bool edgeSwipe;

  /// The focus scope the shown panel keeps focus in.
  final FocusScopeNode focusNode;

  /// Builds the panel box of a side, with the given corners on its screen
  /// corners.
  final Widget Function(PageDrawerSide side, BorderRadius corners) panel;

  /// Closes the open drawer.
  final VoidCallback onClose;

  /// Starts a drag of a side's drawer.
  final ValueChanged<PageDrawerSide> onDragStart;

  /// Receives each drag step as a share of the drawer width, positive
  /// toward open.
  final ValueChanged<double> onDragUpdate;

  /// Receives the release velocity in logical pixels per second, positive
  /// toward open.
  final ValueChanged<double> onDragEnd;

  /// The page.
  final Widget child;

  /// The width of the strip on a screen edge that starts an edge swipe.
  static const double _edgeWidth = 20;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final reduced = context.reducesMotion;
    final drawn = _drawn(context, platform);
    final behind =
        drawn != null && !reduced && drawn.type == PageDrawerType.back;
    final panel = drawn == null ? null : _panel(context, drawn, reduced);
    final canPop = ModalRoute.canPopOf(context) ?? false;
    return PopScope<Object?>(
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: GestureDetector(
        excludeFromSemantics: true,
        onHorizontalDragStart: drawn == null
            ? null
            : (_) => onDragStart(drawn.side),
        onHorizontalDragUpdate: drawn == null
            ? null
            : (details) => onDragUpdate(
                (details.primaryDelta ?? 0) * _toward(drawn) / drawn.width,
              ),
        onHorizontalDragEnd: drawn == null
            ? null
            : (details) =>
                  onDragEnd((details.primaryVelocity ?? 0) * _toward(drawn)),
        child: StackLayout(
          fit: StackFit.expand,
          children: [
            (behind ? panel : null) ?? const SizedBox.shrink(),
            _page(context, drawn, reduced),
            (behind ? null : panel) ?? const SizedBox.shrink(),
            _edge(context, PageDrawerSide.left, platform, canPop),
            _edge(context, PageDrawerSide.right, platform, canPop),
          ],
        ),
      ),
    );
  }

  PageSide? _configOf(PageDrawerSide side) => switch (side) {
    PageDrawerSide.left => left,
    PageDrawerSide.right => right,
  };

  /// The drawer that shows; null when none shows or [shown] opens as a
  /// page.
  _Drawn? _drawn(BuildContext context, TargetPlatform platform) {
    final side = shown;
    final config = side == null ? null : _configOf(side);
    if (side == null || config == null) return null;
    final type = resolveDrawerType(config, platform);
    if (type == PageDrawerType.page) return null;
    final place = _placeOf(context, side, config);
    return (
      side: side,
      config: config,
      type: type,
      width: place.width,
      atLeft: place.atLeft,
    );
  }

  /// The drawer width of [side] and whether it sits on the physical left
  /// screen edge.
  ({double width, bool atLeft}) _placeOf(
    BuildContext context,
    PageDrawerSide side,
    PageSide config,
  ) {
    // A drawer never runs past the screen, even the overlay drawer on a
    // screen narrower than its width.
    final screen = context.deviceWindow.width;
    return (
      width: math.min(
        drawerWidth(screen, min: config.minWidth, max: config.maxWidth),
        screen,
      ),
      atLeft:
          (side == PageDrawerSide.left) ==
          (Directionality.of(context) == TextDirection.ltr),
    );
  }

  /// The physical x direction [drawn] opens toward: +1 from the left edge.
  static double _toward(_Drawn drawn) => drawn.atLeft ? 1 : -1;

  /// [child] with the scrim over it while a drawer shows, moved aside by a
  /// `back` or `slide` drawer, and then scaled by the side's page scale and
  /// rounded with the screen radius (US-19 FR-02 E04).
  ///
  /// Every frame keeps the same widgets around [child], so the page keeps
  /// its state as a drawer opens and closes. While a drawer shows, the page
  /// is its own semantics container, so the scrim hides only the page from
  /// screen readers, even when a `back` panel paints under it.
  Widget _page(BuildContext context, _Drawn? drawn, bool reduced) {
    final motion =
        !reduced &&
            drawn != null &&
            (drawn.type == PageDrawerType.back ||
                drawn.type == PageDrawerType.slide)
        ? drawn
        : null;
    final scale = motion?.config.pageScale;
    final screen = context.deviceWindow.radius ?? BorderRadius.zero;
    return Semantics(
      container: drawn != null,
      child: AnimatedBuilder(
        animation: motion == null ? kAlwaysDismissedAnimation : progress,
        builder: (context, page) {
          final t = motion == null ? 0.0 : progress.value;
          final shift = motion == null
              ? 0.0
              : t * motion.width * _toward(motion);
          final size = scale == null ? 1.0 : 1 - (1 - scale) * t;
          final corners = scale == null
              ? BorderRadius.zero
              : BorderRadius.lerp(BorderRadius.zero, screen, t) ??
                    BorderRadius.zero;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(size, size, 1)
              ..setTranslationRaw(shift, 0, 0),
            child: ClipRRect(
              borderRadius: corners,
              clipBehavior: corners == BorderRadius.zero
                  ? Clip.none
                  : Clip.antiAlias,
              child: page,
            ),
          );
        },
        child: StackLayout(
          fit: StackFit.expand,
          children: [
            child,
            if (drawn != null)
              Scrim(animation: progress, onDismiss: onClose)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  /// [drawn]'s panel on its screen edge, under the named route scope, the
  /// focus scope, and Esc; it moves in for `front` and `slide`, stays still
  /// for `back` and `permanent`, and only fades when [reduced] (US-19
  /// FR-02, FR-04, FR-05).
  Widget _panel(BuildContext context, _Drawn drawn, bool reduced) {
    final screen = context.deviceWindow.radius ?? BorderRadius.zero;
    final corners = drawn.atLeft
        ? BorderRadius.only(
            topLeft: screen.topLeft,
            bottomLeft: screen.bottomLeft,
          )
        : BorderRadius.only(
            topRight: screen.topRight,
            bottomRight: screen.bottomRight,
          );
    final scoped = Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label:
          drawn.config.semanticsLabel ?? builtInLabelsOf(context).drawerLabel,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
        child: FocusScope(
          node: focusNode,
          child: FocusTraversalGroup(child: panel(drawn.side, corners)),
        ),
      ),
    );
    final slides =
        drawn.type == PageDrawerType.front ||
        drawn.type == PageDrawerType.slide;
    final Widget moved;
    if (reduced) {
      moved = FadeTransition(opacity: progress, child: scoped);
    } else if (slides) {
      moved = AnimatedBuilder(
        animation: progress,
        builder: (context, box) => Transform.translate(
          offset: Offset(
            (progress.value - 1) * drawn.width * _toward(drawn),
            0,
          ),
          child: box,
        ),
        child: scoped,
      );
    } else {
      moved = scoped;
    }
    return Positioned(
      top: 0,
      bottom: 0,
      width: drawn.width,
      left: drawn.atLeft ? 0 : null,
      right: drawn.atLeft ? null : 0,
      child: moved,
    );
  }

  /// The strip on [side]'s screen edge that starts an edge swipe; an empty
  /// box where the side has no drawer, [edgeSwipe] is off, another side's
  /// drawer shows, or the iOS back swipe owns the edge (US-19 FR-03 E03 to
  /// E05).
  Widget _edge(
    BuildContext context,
    PageDrawerSide side,
    TargetPlatform platform,
    bool canPop,
  ) {
    final config = _configOf(side);
    // Flutter's iOS back swipe starts on the start edge, where `left` sits.
    final backSwipe =
        side == PageDrawerSide.left && platform == TargetPlatform.iOS && canPop;
    final other = shown != null && shown != side;
    if (!edgeSwipe || config == null || backSwipe || other) {
      return const SizedBox.shrink();
    }
    final place = _placeOf(context, side, config);
    final toward = place.atLeft ? 1.0 : -1.0;
    return Positioned(
      top: 0,
      bottom: 0,
      width: _edgeWidth,
      left: place.atLeft ? 0 : null,
      right: place.atLeft ? null : 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onHorizontalDragStart: (_) => onDragStart(side),
        onHorizontalDragUpdate: (details) =>
            onDragUpdate((details.primaryDelta ?? 0) * toward / place.width),
        onHorizontalDragEnd: (details) =>
            onDragEnd((details.primaryVelocity ?? 0) * toward),
      ),
    );
  }
}
