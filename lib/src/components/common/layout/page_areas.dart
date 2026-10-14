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
  new({required this.isCurrentRoute}) : super(null);

  /// Whether the page's route is the current route of its navigator;
  /// a covered route's page never wins.
  final bool Function() isCurrentRoute;

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

  @override
  void notifyListeners() {
    if (_quiet) return;
    super.notifyListeners();
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

  /// The registry controller above [context], null with no registry.
  static PageAreasController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PageAreasScope>()?.controller;

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

  /// The innermost added handle whose route is current; null while none
  /// is (s03 toast invariant 16).
  PageAreasHandle? current() {
    for (final handle in _handles.reversed) {
      if (handle.isCurrentRoute()) return handle;
    }
    return null;
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

/// Writes [child]'s global rect into [report] after layout whenever it
/// changes, post-frame, so a pane drag, a resize within one window size,
/// or the keyboard reaches the registry with no rebuild of the page (s03
/// toast invariant 16).
class PageAreasReporter extends SingleChildRenderObjectWidget {
  const new({super.key, required this.report, required super.child});

  /// Receives the child's global rect after each layout that changes it.
  final ValueChanged<Rect> report;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      PageAreasReporterBox(report);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant PageAreasReporterBox renderObject,
  ) {
    renderObject.report = report;
  }
}

/// [PageAreasReporter]'s render box: compares its global rect after each
/// layout and paint, reporting a change post-frame.
class PageAreasReporterBox extends RenderProxyBox {
  // A render object, not a widget: the class-named constructor follows
  // Flutter's own render-box style.
  // ignore: unnecessary_type_name_in_constructor
  PageAreasReporterBox(this._report);

  ValueChanged<Rect> _report;

  set report(ValueChanged<Rect> value) {
    if (value == _report) return;
    _report = value;
    _changed = true;
  }

  Rect? _lastRect;
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
    _schedule();
  }

  void _schedule() {
    if (!_changed || _detached) return;
    _changed = false;
    final rect = localToGlobal(Offset.zero) & size;
    if (rect == _lastRect) return;
    _lastRect = rect;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_detached) return;
      _report(rect);
    });
  }

  @override
  void detach() {
    _detached = true;
    _lastRect = null;
    super.detach();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _detached = false;
    _changed = true;
  }
}
