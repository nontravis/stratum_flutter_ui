import 'package:smooth_sheets/smooth_sheets.dart'
    show
        BouncingSheetPhysics,
        ModalSheetRoute,
        Sheet,
        SheetController,
        SheetMetrics,
        SheetOffset,
        SheetScrollConfiguration,
        SheetSnapGrid;
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/layout/modal_layout.dart'
    show ModalLayoutScope, resolveModalLayoutType;
import 'package:stratum_ui/src/src.dart';

/// Shows the [ModalLayout] that [builder] builds above the current page
/// and completes with the value it pops with, else with null when the
/// EndUser dismisses it (US-20 FR-02).
///
/// A null [type] shows a bottom sheet below [WindowSize.tablet] and a
/// centered modal at tablet and above (US-20 FR-03). The route sits over a
/// scrim of the theme's `background/default/normal-inverse` color at its
/// `opacity.scrim` opacity, blurred by `blur/1`; with [showBackground]
/// false no scrim draws, while the page behind still refuses every tap and
/// a tap on it dismisses (US-20 FR-06).
///
/// The route blocks the page behind for screen readers, reads as a named
/// screen labeled [semanticsLabel], else the built-in dialog or sheet
/// label in the current language, keeps Tab inside it, and gives focus
/// back to the opener when it closes. Esc, a tap outside, back, the close
/// button, a tap on the handle, and a drag down on a sheet dismiss it. It
/// enters and leaves over the theme's `normal` level, a sheet sliding and
/// a modal fading, and fades with no slide under reduced motion.
///
/// [useRootNavigator], the default, pushes the route on the root
/// navigator, so it also covers what sits outside a nested navigator,
/// such as a tab bar; false pushes it on the nearest navigator.
///
/// A sheet follows the drag and, after every release, settles on its
/// nearest resting height, hidden, half, or full, over the theme's `fast`
/// level, at once under reduced motion; settling hidden dismisses it. It
/// rises by the keyboard height, and a modal moves clear of the keyboard
/// (US-20 FR-05, FR-07).
Future<T?> showModalLayout<T>(
  BuildContext context, {
  ModalLayoutType? type,
  required WidgetBuilder builder,
  String? semanticsLabel,
  bool showBackground = true,
  bool useRootNavigator = true,
}) {
  final shown = resolveModalLayoutType(type, context.deviceWindow.windowSize);
  final labels = builtInLabelsOf(context);
  final motion = context.theme.animation.normal;
  final duration = motion.duration ?? Duration.zero;
  final reverseDuration = motion.reverseDuration ?? duration;
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  if (shown == ModalLayoutType.modal) {
    return navigator.push(
      _ModalLayoutRoute<T>(
        builder: builder,
        label: semanticsLabel,
        barrierLabel: labels.dismissLabel,
        showBackground: showBackground,
        transitionDuration: duration,
        reverseTransitionDuration: reverseDuration,
      ),
    );
  }
  return navigator.push(
    _SheetLayoutRoute<T>(
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionCurve: motion.curve ?? Curves.easeInOutSine,
      barrierLabel: labels.dismissLabel,
      barrierBuilder: (route, dismiss) => _Scrim(
        animation: route.animation!,
        showBackground: showBackground,
        onDismiss: dismiss,
      ),
      builder: (context) => _SheetContent(
        type: shown,
        label: semanticsLabel,
        showBackground: showBackground,
        builder: builder,
      ),
    ),
  );
}

/// The centered modal's route: a fade over the theme's `normal` level on
/// its `standard` curve, the [_Scrim] as its barrier, and the modal
/// layout centered above the keyboard (US-20 FR-02, FR-05 E05).
class _ModalLayoutRoute<T> extends PopupRoute<T> {
  new({
    required this.builder,
    required this.label,
    required this.barrierLabel,
    required this.showBackground,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
  });

  final WidgetBuilder builder;

  /// The route's semantics label; null reads the built-in dialog label.
  final String? label;

  final bool showBackground;

  @override
  final String barrierLabel;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildModalBarrier() =>
      _Scrim(animation: animation!, showBackground: showBackground);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => ContainerLayout(
    style: WidgetStyle(
      alignment: Alignment.center,
      padding: EdgeInsets.only(bottom: context.deviceWindow.keyboardHeight),
    ),
    child: _RouteScope(
      type: ModalLayoutType.modal,
      label: label,
      showBackground: showBackground,
      onDismiss: _dismiss,
      child: builder(context),
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: _standardCurve(context))),
    child: child,
  );

  /// Dismisses this route when it is the top one (US-20 FR-02).
  void _dismiss() {
    if (isCurrent) navigator?.maybePop();
  }
}

/// The sheet's route: a slide on the theme's `standard` curve, or a fade
/// with no slide under reduced motion (US-20 FR-02 E05).
///
/// The package's swipe dismissal stays off: a drag never drives the route
/// animation, and the sheet dismisses by settling on its hidden resting
/// height through [_SnapPhysics] instead (US-20 FR-07).
class _SheetLayoutRoute<T> extends ModalSheetRoute<T> {
  new({
    required super.builder,
    required super.transitionDuration,
    required this.reverseTransitionDuration,
    required super.transitionCurve,
    required super.barrierLabel,
    required super.barrierBuilder,
  });

  @override
  final Duration reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!context.reducesMotion) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: transitionCurve)),
      child: child,
    );
  }
}

/// The sheet: hidden, half, and full resting heights, the settle of
/// [_SnapPhysics] after every release, a dismissal when it settles hidden,
/// the scroll handoff to the body, the keyboard lift, and the full-height
/// state the [ModalLayout] reads (US-20 FR-04 E03, FR-05, FR-07).
class _SheetContent extends StatefulWidget {
  const new({
    required this.type,
    required this.label,
    required this.showBackground,
    required this.builder,
  });

  final ModalLayoutType type;

  /// The route's semantics label; null reads the built-in sheet label.
  final String? label;

  final bool showBackground;
  final WidgetBuilder builder;

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  final _controller = SheetController();

  /// Whether the sheet's top has reached the status bar.
  var _fullHeight = false;

  /// The status bar height at the last build.
  var _statusBar = 0.0;

  /// The pointers down on the sheet, a trackpad pan included: while any
  /// is, a drag may still move it, so reaching the hidden height dismisses
  /// nothing yet.
  var _pointers = 0;

  /// Whether the sheet sits hidden and has asked the route to pop, so it
  /// asks once each time it settles there.
  var _hidden = false;

  /// The settle of the last build, which also brings a sheet a pop scope
  /// keeps back to full height.
  late _SnapPhysics _physics;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMoved);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onMoved)
      ..dispose();
    super.dispose();
  }

  void _onMoved() {
    final metrics = _controller.metrics;
    if (metrics == null || !mounted) return;
    final tolerance = Tolerance.defaultTolerance.distance;
    if (metrics.offset > tolerance) {
      _hidden = false;
    } else if (_pointers == 0 && !_hidden) {
      _hidden = true;
      _settleHidden();
    }
    final reaches = metrics.rect.top <= _statusBar + tolerance;
    if (reaches != _fullHeight) setState(() => _fullHeight = reaches);
  }

  /// Pops the route with null once the sheet settles hidden (US-20 FR-07
  /// E02); a route a pop scope keeps open brings the sheet back to full
  /// height, and the scope still hears the attempt. Does nothing once the
  /// route is no longer the top one, so it never pops another route.
  ///
  /// The settle reports its last offset from inside its own tick, so the
  /// way back starts after the frame, once that settle has ended.
  void _settleHidden() {
    final route = ModalRoute.of(context);
    if (!(route?.isCurrent ?? false)) return;
    if (route?.popDisposition == RoutePopDisposition.doNotPop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _controller.animateTo(
            const SheetOffset(1),
            duration: _physics.duration > Duration.zero
                ? _physics.duration
                // WORKAROUND: smooth_sheets 1.3.0 animateTo asserts a
                // non-zero duration and exposes no jump; remove when it
                // does.
                : const Duration(microseconds: 1),
            curve: _physics.curve,
          ),
        );
      });
    }
    Navigator.maybePop(context);
  }

  /// Dismisses this route when it is the top one (US-20 FR-02).
  void _dismiss() {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = context.deviceWindow;
    final snap = context.theme.animation.fast;
    _statusBar = window.safeArea.top;
    _physics = _SnapPhysics(
      duration: context.reducesMotion
          ? Duration.zero
          : snap.duration ?? Duration.zero,
      curve: snap.curve ?? Curves.easeInOutSine,
    );
    return Sheet(
      controller: _controller,
      snapGrid: const SheetSnapGrid(
        snaps: [SheetOffset(0), SheetOffset(0.5), SheetOffset(1)],
      ),
      physics: _physics,
      scrollConfiguration: const SheetScrollConfiguration(),
      padding: EdgeInsets.only(bottom: window.keyboardHeight),
      // The sheet lays its child out at the viewport's full width; the
      // align hands the modal layout its own content width, at its own
      // height.
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers--,
          onPointerCancel: (_) => _pointers--,
          onPointerPanZoomStart: (_) => _pointers++,
          onPointerPanZoomEnd: (_) => _pointers--,
          child: Builder(
            builder: (context) => PrimaryScrollController(
              controller: PrimaryScrollController.of(context),
              automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
              child: _RouteScope(
                type: widget.type,
                label: widget.label,
                showBackground: widget.showBackground,
                fullHeight: _fullHeight,
                onDismiss: _dismiss,
                child: widget.builder(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheet physics that settles a released drag on the nearest resting
/// height over [duration] on [curve], and at once when [duration] is zero
/// (US-20 FR-07 E01, E03), instead of the package spring.
class _SnapPhysics extends BouncingSheetPhysics {
  const new({required this.duration, required this.curve});

  final Duration duration;
  final Curve curve;

  @override
  Simulation? createBallisticSimulation(
    double velocity,
    SheetMetrics metrics,
    SheetSnapGrid snapGrid,
  ) {
    final target = snapGrid
        .getSnapOffset(metrics, metrics.offset, velocity)
        .resolve(metrics);
    if ((target - metrics.offset).abs() < Tolerance.defaultTolerance.distance) {
      return null;
    }
    return _CurveSimulation(
      from: metrics.offset,
      to: target,
      duration: duration,
      curve: curve,
    );
  }
}

/// Moves from [from] to [to] over a duration on [curve]; done at once, at
/// [to], when the duration is zero.
class _CurveSimulation extends Simulation {
  new({
    required this.from,
    required this.to,
    required Duration duration,
    required this.curve,
  }) : _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final double from;
  final double to;
  final Curve curve;
  final double _seconds;

  /// The time step of [dx]'s finite difference, in seconds.
  static const double _step = 1e-3;

  @override
  double x(double time) =>
      isDone(time) ? to : from + (to - from) * curve.transform(time / _seconds);

  @override
  double dx(double time) =>
      isDone(time) ? 0 : (x(time + _step) - x(time)) / _step;

  @override
  bool isDone(double time) => time >= _seconds;
}

/// The route's scrim: the theme's `normal-inverse` color, its own alpha
/// times the `opacity.scrim` opacity as a Figma layer opacity, blurred by `blur/1`, fading with [animation],
/// over a [ModalBarrier] that blocks the page behind for taps and screen
/// readers, reads the dismiss label, and dismisses on a tap; with
/// [showBackground] false only the barrier stays (US-20 FR-06).
///
/// It reads the theme from its own context, so a theme switch restyles an
/// open scrim (US-20 FR-06 E02, E06).
class _Scrim extends StatelessWidget {
  const new({
    required this.animation,
    required this.showBackground,
    this.onDismiss,
  });

  final Animation<double> animation;
  final bool showBackground;

  /// Dismisses the route; null pops the nearest navigator's top route.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = theme.color.background.defaults.normalInverse;
    return StackLayout(
      fit: StackFit.expand,
      children: [
        if (showBackground)
          IgnorePointer(
            child: FadeTransition(
              opacity: animation.drive(
                CurveTween(curve: _standardCurve(context)),
              ),
              child: ContainerLayout(
                style: WidgetStyle(
                  backgroundColor: color.withValues(
                    alpha: color.a * theme.data.opacity.scrim,
                  ),
                  backgroundBlur: theme.blur.level1,
                ),
              ),
            ),
          ),
        ModalBarrier(
          semanticsLabel: builtInLabelsOf(context).dismissLabel,
          onDismiss: onDismiss,
        ),
      ],
    );
  }
}

/// The route state and semantics around the modal layout: a named route
/// scope labeled [label], a focus scope that takes focus when it shows,
/// Esc as a dismissal, a transparent [Material] so an SDK widget such as a
/// list tile works in it, and the [ModalLayoutScope] (US-20 FR-02, FR-07
/// E05; layout s03 inv. 73).
class _RouteScope extends StatelessWidget {
  const new({
    required this.type,
    required this.label,
    required this.showBackground,
    required this.onDismiss,
    this.fullHeight = false,
    required this.child,
  });

  final ModalLayoutType type;

  /// The route's label; null reads the built-in dialog label for a modal
  /// and the sheet label for a sheet, in the current language.
  final String? label;

  final bool showBackground;
  final VoidCallback onDismiss;
  final bool fullHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    namesRoute: true,
    explicitChildNodes: true,
    label:
        label ??
        switch (type) {
          ModalLayoutType.modal => builtInLabelsOf(context).dialogLabel,
          _ => builtInLabelsOf(context).sheetLabel,
        },
    child: FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Material(
          type: MaterialType.transparency,
          child: ModalLayoutScope(
            type: type,
            onDismiss: onDismiss,
            showBackground: showBackground,
            fullHeight: fullHeight,
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// The theme's `standard` curve at [context], the `normal` level's curve.
Curve _standardCurve(BuildContext context) =>
    context.theme.animation.normal.curve ?? Curves.easeInOutSine;
