import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/themes/system/system_bars.dart';
import 'package:stratum_ui/src/themes/system/system_style.dart';
import 'package:stratum_ui/src/themes/system/system_style_region.dart';

/// Whether the resolver takes the platform for the web; null reads
/// `kIsWeb`. Tests set it and reset it to null in `tearDown`.
@visibleForTesting
bool? debugSystemStyleIsWebOverride;

bool get _isWeb => debugSystemStyleIsWebOverride ?? kIsWeb;

/// The base layer of the system bar style that a `StratumThemeApplication`
/// places around its child, its hook into the one resolver of its view, and,
/// on the outermost root of the view, the bar color strips painted over
/// every page (FO-03 US-14 FR-01 to FR-04; themes s03 invariants 38 to 43
/// and 45). Internal: not exported.
class SystemStyleRoot extends StatefulWidget {
  const new({
    super.key,
    required this.style,
    required this.background,
    required this.child,
  });

  /// The theme data's `systemStyle` with the app-wide style merged over it.
  final SystemStyle style;

  /// The theme's page background, which automatic icons read where no fill
  /// is declared.
  final Color background;

  final Widget child;

  @override
  State<SystemStyleRoot> createState() => _SystemStyleRootState();
}

class _SystemStyleRootState extends State<SystemStyleRoot> {
  _SystemStyleResolver? _resolver;

  /// Whether another root on the same view lies above this one, so this
  /// root's region is sized to its child (themes s03 invariant 40).
  bool _nested = false;

  /// The bar color strips this root paints; the resolver sets them on the
  /// outermost root of the view and clears them on every other one.
  final _strips = ValueNotifier<_SystemBarStrips?>(null);

  /// The region this root paints; null before its first layout.
  _RenderSystemStyleRoot? get region =>
      context.findRenderObject() as _RenderSystemStyleRoot?;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.of(context);
    if (_resolver?.view != view) {
      _resolver?.detach(this);
      _resolver = _SystemStyleResolver._attach(view, this);
    }
    final above = context.findAncestorStateOfType<_SystemStyleRootState>();
    _nested = above != null && identical(above._resolver, _resolver);
  }

  @override
  void dispose() {
    _resolver?.detach(this);
    _resolver = null;
    _strips.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SystemStyleRootRegion(
    value: SystemStyleBaseRegion(
      style: widget.style,
      background: widget.background,
    ),
    sized: _nested,
    child: CustomPaint(
      foregroundPainter: _SystemBarStripPainter(_strips),
      child: widget.child,
    ),
  );
}

/// The bar colors a root paints, each over the view's padding at its edge
/// in logical pixels: `status` across the `top` padding, and `navigation`
/// across the `bottom` padding with `divider` as its edge line.
typedef _SystemBarStrips = ({
  double top,
  Color? status,
  double bottom,
  Color? navigation,
  Color? divider,
});

/// Paints the bar color strips over the root's child, so every page lies
/// under them, as an opaque system bar lies over the app (themes s03
/// invariant 45). The divider is a line one logical pixel tall on the
/// navigation strip's edge that faces the app, as Android draws its own. A
/// transparent color paints nothing.
class _SystemBarStripPainter extends CustomPainter {
  new(this.strips) : super(repaint: strips);

  final ValueListenable<_SystemBarStrips?> strips;

  @override
  void paint(Canvas canvas, Size size) {
    final value = strips.value;
    if (value == null) return;
    _fill(canvas, Rect.fromLTWH(0, 0, size.width, value.top), value.status);
    final edge = size.height - value.bottom;
    final divider = value.divider;
    final line = divider == null || divider.a == 0
        ? 0.0
        : math.min(1.0, value.bottom);
    _fill(canvas, Rect.fromLTWH(0, edge, size.width, line), divider);
    _fill(
      canvas,
      Rect.fromLTRB(0, edge + line, size.width, size.height),
      value.navigation,
    );
  }

  static void _fill(Canvas canvas, Rect rect, Color? color) {
    if (color == null || color.a == 0 || rect.isEmpty) return;
    canvas.drawRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SystemBarStripPainter oldDelegate) =>
      oldDelegate.strips != strips;
}

class _SystemStyleRootRegion extends SingleChildRenderObjectWidget {
  const new({required this.value, required this.sized, required super.child});

  final SystemStyleBaseRegion value;

  final bool sized;

  @override
  _RenderSystemStyleRoot createRenderObject(BuildContext context) =>
      _RenderSystemStyleRoot(value, sized: sized);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSystemStyleRoot renderObject,
  ) => renderObject
    ..value = value
    ..sized = sized;
}

/// Paints [value] as an annotation around its child, unsized on the
/// outermost root of the view and sized to the child on a nested one, so a
/// nested theme counts only at a bar it lies under (themes s03 invariant
/// 40), and keeps the layer it pushed, so the resolver searches every layer
/// painted inside it.
class _RenderSystemStyleRoot extends RenderProxyBox {
  new(this._value, {required bool sized}) : _sized = sized;

  SystemStyleBaseRegion _value;

  set value(SystemStyleBaseRegion value) {
    if (value == _value) return;
    _value = value;
    markNeedsPaint();
  }

  bool _sized;

  set sized(bool value) {
    if (value == _sized) return;
    _sized = value;
    markNeedsPaint();
  }

  final _layer = LayerHandle<AnnotatedRegionLayer<SystemUiOverlayStyle>>();
  Offset _paintOffset = Offset.zero;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final layer = AnnotatedRegionLayer<SystemUiOverlayStyle>(
      _value,
      size: _sized ? size : null,
      offset: _sized ? offset : null,
    );
    _layer.layer = layer;
    _paintOffset = offset;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }

  /// Every system style annotation painted inside this root at
  /// [position], a point of the view in logical pixels, front to back.
  List<SystemUiOverlayStyle> annotationsAt(Offset position) {
    final layer = _layer.layer;
    if (layer == null || !attached || !hasSize) return const [];
    return layer
        .findAllAnnotations<SystemUiOverlayStyle>(
          globalToLocal(position) + _paintOffset,
        )
        .annotations
        .toList();
  }

  /// Every Stratum region painted inside this root, front to back in the
  /// order of [annotationsAt], wherever it lies and whatever clips it, so a
  /// scope in a clipped tab view still sets the behavior (themes s03
  /// invariant 39). An offstage route and a hidden `IndexedStack` child
  /// push no layer, so only what painted counts.
  List<SystemStyleRegion> painted() {
    final layer = _layer.layer;
    if (layer == null || !attached) return const [];
    final regions = <SystemStyleRegion>[];
    void visit(Layer layer) {
      if (layer is ContainerLayer) {
        for (
          var child = layer.lastChild;
          child != null;
          child = child.previousSibling
        ) {
          visit(child);
        }
      }
      if (layer case AnnotatedRegionLayer<SystemUiOverlayStyle>(
        value: final SystemStyleRegion region,
      )) {
        regions.add(region);
      }
    }

    visit(layer);
    return regions;
  }
}

/// The one writer of the system chrome for one view (FO-03 US-14 FR-02 to
/// FR-04; themes s03 invariants 39 to 43 and 45). Every
/// `StratumThemeApplication` on the view shares it; it lives while one of
/// them is in the tree.
final class _SystemStyleResolver {
  new _(this.view);

  static final _byView = <ui.FlutterView, _SystemStyleResolver>{};

  static _SystemStyleResolver _attach(
    ui.FlutterView view,
    _SystemStyleRootState host,
  ) {
    final resolver = _byView.putIfAbsent(
      view,
      () => _SystemStyleResolver._(view),
    );
    resolver._hosts.add(host);
    resolver._renderView ??= resolver._findRenderView();
    resolver._renderView?.automaticSystemUiAdjustment = false;
    resolver._schedule();
    return resolver;
  }

  final ui.FlutterView view;
  final _hosts = <_SystemStyleRootState>[];
  RenderView? _renderView;
  bool _scheduled = false;
  SystemBarMode? _barMode;
  List<DeviceOrientation>? _orientations;
  (String, int)? _description;

  /// The app widget's `Title` at the last send; `WidgetsApp` builds a new
  /// one each time it rebuilds.
  Title? _sentTitle;

  void detach(_SystemStyleRootState host) {
    _hosts.remove(host);
    if (_hosts.isNotEmpty) return;
    _renderView?.automaticSystemUiAdjustment = true;
    _byView.remove(view);
  }

  RenderView? _findRenderView() {
    for (final renderView in RendererBinding.instance.renderViews) {
      if (renderView.flutterView == view) return renderView;
    }
    return null;
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(
      _onFrame,
      debugLabel: '_SystemStyleResolver',
    );
  }

  void _onFrame(Duration _) {
    _scheduled = false;
    if (_hosts.isEmpty) return;
    _apply();
    _schedule();
  }

  /// The host nearest the root, whose layer holds every other host's.
  _SystemStyleRootState? get _outermost {
    _SystemStyleRootState? outermost;
    for (final host in _hosts) {
      final region = host.region;
      if (region == null || !region.attached) continue;
      if (outermost == null || region.depth < outermost.region!.depth) {
        outermost = host;
      }
    }
    return outermost;
  }

  void _apply() {
    _renderView ??= _findRenderView();
    _renderView?.automaticSystemUiAdjustment = false;
    final outermost = _outermost;
    final region = outermost?.region;
    if (region == null) return;
    final ratio = view.devicePixelRatio;
    final size = view.physicalSize / ratio;
    final padding = view.padding;
    final status = Offset(size.width / 2, padding.top / ratio / 2);
    final platform = defaultTargetPlatform;
    final android = !_isWeb && platform == TargetPlatform.android;
    final navigation = Offset(
      size.width / 2,
      size.height - 1 / ratio - padding.bottom / ratio / 2,
    );
    final bars = resolveSystemBars(
      region.annotationsAt(status),
      navigation: android ? region.annotationsAt(navigation) : null,
      painted: region.painted(),
    );
    final strips = bars == null
        ? null
        : (
            top: padding.top / ratio,
            status: bars.statusBarColor,
            bottom: padding.bottom / ratio,
            navigation: bars.navigationBarColor,
            divider: bars.navigationBarDividerColor,
          );
    for (final host in _hosts) {
      host._strips.value = identical(host, outermost) ? strips : null;
    }
    if (bars == null) return;
    final mobile =
        !_isWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
    if (!_isWeb) SystemChrome.setSystemUIOverlayStyle(bars.overlay);
    if (mobile && bars.barMode != _barMode) {
      _barMode = bars.barMode;
      unawaited(_setMode(bars.barMode));
    }
    if (mobile && !listEquals(bars.orientations, _orientations)) {
      _orientations = bars.orientations;
      unawaited(SystemChrome.setPreferredOrientations(bars.orientations));
    }
    _sendDescription(bars);
  }

  static Future<void> _setMode(SystemBarMode mode) => switch (mode) {
    SystemBarMode.edgeToEdge => SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    ),
    SystemBarMode.immersive => SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersive,
    ),
    SystemBarMode.immersiveSticky => SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    ),
    SystemBarMode.leanBack => SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.leanBack,
    ),
    SystemBarMode.topOnly => SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.top],
    ),
    SystemBarMode.bottomOnly => SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.bottom],
    ),
  };

  /// Sends the merged label, else the title of the nearest app widget
  /// `Title` read now, with the merged `appSwitcherColor` made opaque, when
  /// either changed or the app widget rebuilt, which builds a new `Title`
  /// that may have sent its own description (themes s03 invariant 42).
  void _sendDescription(SystemBars bars) {
    final title = _title();
    final color = bars.appSwitcherColor;
    final label = bars.appSwitcherLabel ?? title?.title;
    if (color == null || label == null) return;
    final description = (label, color.withValues(alpha: 1).toARGB32());
    if (identical(title, _sentTitle) && description == _description) return;
    _sentTitle = title;
    _description = description;
    unawaited(
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(
          label: description.$1,
          primaryColor: description.$2,
        ),
      ),
    );
  }

  /// The nearest `Title` above the deepest host that has one.
  Title? _title() {
    Title? title;
    var deepest = -1;
    for (final host in _hosts) {
      final region = host.region;
      if (!host.mounted || region == null || region.depth <= deepest) continue;
      final found = host.context.findAncestorWidgetOfExactType<Title>();
      if (found == null) continue;
      title = found;
      deepest = region.depth;
    }
    return title;
  }
}
