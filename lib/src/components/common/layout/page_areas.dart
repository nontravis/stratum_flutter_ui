import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

/// The page areas a notice places itself against, in global coordinates
/// (s03 toast invariant 16).
@immutable
class PageAreas {
  const new({this.body, this.footerTop, this.bottomTop, this.left, this.snack});

  /// The body slot's global rect.
  final Rect? body;

  /// The footer slot's global top; null with no footer.
  final double? footerTop;

  /// The bottom slot's global top; null with no bottom.
  final double? bottomTop;

  /// The inline `left` pane's global rect; null below the drawer cut.
  final Rect? left;

  /// The page's resolved `PageLayoutStyle.snack`.
  final WidgetStyle? snack;

  @override
  bool operator ==(Object other) =>
      other is PageAreas &&
      other.body == body &&
      other.footerTop == footerTop &&
      other.bottomTop == bottomTop &&
      other.left == left &&
      other.snack == snack;

  @override
  int get hashCode => Object.hash(body, footerTop, bottomTop, left, snack);
}

/// The handle one `PageLayout` publishes its [PageAreas] through; the
/// host reads the innermost one whose route is current (s03 toast
/// invariant 16).
class PageAreasHandle extends ValueNotifier<PageAreas?> {
  new() : super(null);

  /// The probe at the root of the owning page, while it is mounted.
  _PageAreasProbeState? _probe;

  /// Whether the page is on stage: on its navigator's current route, and
  /// in a shown, ticking branch; [PageAreasProbe] keeps it up to date.
  ///
  /// False while no probe is mounted, so a disposed page never wins.
  bool get isCurrent => _probe?._onStage ?? false;

  /// The probe's context, where the page sits in the tree; null while no
  /// probe is mounted.
  BuildContext? get _context => _probe?.context;

  /// While true, value writes notify no listener.
  bool _quiet = false;

  /// Zeros the value with no notification, for the owning page's
  /// dispose, which runs while the tree is locked and so may not notify
  /// the registry.
  void detach() {
    if (value == null) return;
    _quiet = true;
    value = null;
    _quiet = false;
  }

  /// Tells the registry the page went on or off stage, so a showing
  /// notice reads the current page again.
  void _restaged() => notifyListeners();

  /// Lets [probe] go, when it is the one this handle holds.
  void _release(_PageAreasProbeState probe) {
    if (identical(_probe, probe)) _probe = null;
  }

  @override
  void notifyListeners() {
    if (_quiet) return;
    super.notifyListeners();
  }
}

/// Keeps [handle]'s [PageAreasHandle.isCurrent] up to date from the root
/// of its page: the page's route is current, and no `TickerMode` or
/// `Visibility` above it hides its branch, as a go_router
/// `StatefulShellRoute.indexedStack` or an `IndexedStack` does (s03 toast
/// invariant 16).
///
/// The route and branch reads depend on this leaf alone, whose build
/// returns [child] unchanged, so a push, a pop, or a branch switch
/// rebuilds no page.
class PageAreasProbe extends StatefulWidget {
  const new({super.key, required this.handle, required this.child});

  final PageAreasHandle handle;
  final Widget child;

  @override
  State<PageAreasProbe> createState() => _PageAreasProbeState();
}

class _PageAreasProbeState extends State<PageAreasProbe> {
  /// Whether the page was on stage at this leaf's last dependency change.
  bool _onStage = false;

  /// Whether a deferred notification is already waiting for the frame.
  bool _restaging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.handle._probe = this;
    final onStage =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled &&
        Visibility.of(context);
    if (onStage == _onStage) return;
    _onStage = onStage;
    _restage();
  }

  @override
  void didUpdateWidget(PageAreasProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.handle, widget.handle)) return;
    oldWidget.handle._release(this);
    widget.handle._probe = this;
    _restage();
  }

  @override
  void dispose() {
    widget.handle._release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// Notifies the handle after this frame: the registry's scope sits
  /// above the page, so a notification during this build would ask an
  /// ancestor to rebuild mid-build.
  void _restage() {
    if (_restaging) return;
    _restaging = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _restaging = false;
        if (mounted) widget.handle._restaged();
      })
      ..ensureVisualUpdate();
  }
}

/// The registry the toast host provides above the app's navigator; each
/// mounted `PageLayout` adds its own handle through [maybeOf] and drops
/// it on dispose (s03 toast invariant 16).
///
/// The host keeps the handles and a version notifier the registry
/// exposes, bumped on every registration change and every areas write,
/// so a reader picking the innermost current handle always rebuilds on
/// the next frame — the host's margin builders, from their own context,
/// never host state.
class PageAreasRegistry extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  /// The registry controller above [context], null with no registry: a
  /// *dependent* read, for a reader (the toast host's margin) that must
  /// rebuild on every version bump.
  static PageAreasController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PageAreasScope>()?.controller;

  /// The registry controller above [context], null with no registry: a
  /// non-dependent read, for a page's own registration bookkeeping, which
  /// must not subscribe the page to every other page's areas writes.
  static PageAreasController? controllerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PageAreasScope>()?.controller;

  @override
  State<PageAreasRegistry> createState() => _PageAreasRegistryState();
}

class _PageAreasRegistryState extends State<PageAreasRegistry> {
  final controller = PageAreasController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageAreasScope(
    controller: controller,
    notifier: controller.version,
    child: widget.child,
  );
}

/// Publishes the registry controller to the pages and readers below;
/// the controller's version notifier drives the dependents' rebuilds
/// (s03 toast invariant 16).
class _PageAreasScope extends InheritedNotifier<ValueNotifier<int>> {
  const new({
    required this.controller,
    required super.notifier,
    required super.child,
  });

  final PageAreasController controller;
}

/// Owns the pages' handles: added in mount order, dropped on dispose,
/// and the innermost current one wins a read (s03 toast invariant 16).
class PageAreasController extends ChangeNotifier {
  // A plain unnamed constructor; the lint wants `new`, which this
  // package reserves for widgets.
  // ignore: unnecessary_type_name_in_constructor
  PageAreasController();

  final _handles = <PageAreasHandle>[];

  /// Bumped on every change, so the scope rebuilds its readers.
  final version = ValueNotifier<int>(0);

  /// Adds [handle], the hosting page calling this from its own mount.
  void add(PageAreasHandle handle) {
    _handles.add(handle);
    handle.addListener(_handleWrote);
    version.value++;
  }

  /// Drops [handle]; safe once its page has disposed it.
  void remove(PageAreasHandle handle) {
    if (!_handles.remove(handle)) return;
    handle.removeListener(_handleWrote);
    version.value++;
  }

  void _handleWrote() => version.value++;

  /// The innermost handle on stage; null while none is (s03 toast
  /// invariant 16; N14).
  ///
  /// Walks from the most recently added on-stage handle, promoting an
  /// earlier one only when it truly nests inside the pick so far
  /// ([_nestedIn]): tree position wins over add order. Siblings that
  /// nest in neither direction keep the add-order tie-break.
  PageAreasHandle? current() {
    PageAreasHandle? best;
    for (final handle in _handles.reversed) {
      if (!handle.isCurrent) continue;
      if (best == null || _nestedIn(handle, best)) best = handle;
    }
    return best;
  }

  /// Whether [candidate]'s page sits below [of]'s in the widget tree, so
  /// [candidate] is the one actually nested inside [of] regardless of
  /// which one registered first.
  static bool _nestedIn(PageAreasHandle candidate, PageAreasHandle of) {
    final target = of._context;
    final from = candidate._context;
    if (target == null || from == null) return false;
    var nested = false;
    from.visitAncestorElements((element) {
      if (element == target) {
        nested = true;
        return false;
      }
      return true;
    });
    return nested;
  }

  @override
  void dispose() {
    for (final handle in _handles) {
      handle.removeListener(_handleWrote);
    }
    _handles.clear();
    version.dispose();
    super.dispose();
  }
}

/// Writes [child]'s global rect into [report] whenever it changes,
/// post-frame, so a pane drag, a resize within one window size, the
/// keyboard, or a route transition reaches the registry with no rebuild
/// of the page (s03 toast invariant 16).
class PageAreasReporter extends SingleChildRenderObjectWidget {
  const new({super.key, required this.report, required super.child});

  /// Receives the child's global rect after each move that changes it.
  final ValueChanged<Rect> report;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      PageAreasReporterBox(report, ModalRoute.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant PageAreasReporterBox renderObject,
  ) {
    renderObject
      ..report = report
      ..route = ModalRoute.of(context);
  }
}

/// [PageAreasReporter]'s render box: compares its global rect after a
/// layout, after a paint at a new offset, and once its route comes to
/// rest, reporting a change post-frame.
///
/// A route transition moves the page by a paint-time transform with no
/// layout or paint of this box, so only the route's rest catches it; a
/// parent that moves this box without laying it out repaints it at a new
/// offset. Neither measures per frame.
class PageAreasReporterBox extends RenderProxyBox {
  // A render object, not a widget: the class-named constructor follows
  // Flutter's own render-box style.
  // ignore: unnecessary_type_name_in_constructor
  PageAreasReporterBox(this._report, this._route);

  ValueChanged<Rect> _report;

  set report(ValueChanged<Rect> value) {
    if (value == _report) return;
    _report = value;
    _changed = true;
  }

  /// The route whose transitions move this box; null outside a route.
  ModalRoute<Object?>? _route;

  set route(ModalRoute<Object?>? value) {
    if (identical(value, _route)) return;
    if (attached) _unlistenRoute();
    _route = value;
    if (attached) _listenRoute();
  }

  Rect? _lastRect;
  Offset? _lastOffset;
  bool _changed = false;
  bool _detached = false;

  @override
  void performLayout() {
    super.performLayout();
    _changed = true;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (offset != _lastOffset) {
      _lastOffset = offset;
      _changed = true;
    }
    if (!_changed || _detached) return;
    _changed = false;
    _compare();
  }

  /// Measures the global rect and reports a change after this frame.
  void _compare() {
    final rect = localToGlobal(Offset.zero) & size;
    if (rect == _lastRect) return;
    _lastRect = rect;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      _report(rect);
      return;
    }
    scheduler.addPostFrameCallback((_) {
      if (_detached) return;
      _report(rect);
    });
  }

  void _listenRoute() {
    _route?.animation?.addStatusListener(_onRouteStatus);
    _route?.secondaryAnimation?.addStatusListener(_onRouteStatus);
  }

  void _unlistenRoute() {
    _route?.animation?.removeStatusListener(_onRouteStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteStatus);
  }

  /// Measures again after the frame in which the route comes to rest:
  /// fully in, with nothing above it moving it aside.
  void _onRouteStatus(AnimationStatus status) {
    final route = _route;
    if (route == null) return;
    final atRest =
        (route.animation?.isCompleted ?? true) &&
        (route.secondaryAnimation?.isDismissed ?? true);
    if (!atRest) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_detached || !hasSize) return;
        _compare();
      })
      ..ensureVisualUpdate();
  }

  @override
  void detach() {
    _detached = true;
    _lastRect = null;
    _lastOffset = null;
    _unlistenRoute();
    super.detach();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _detached = false;
    _changed = true;
    _listenRoute();
  }
}
