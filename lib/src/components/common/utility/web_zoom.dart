import 'package:flutter/rendering.dart'
    show BoxHitTestEntry, BoxHitTestResult, RenderProxyBox;
import 'package:stratum_ui/src/animations/screen_transition.dart'
    show curveOf, durationOf;
import 'package:stratum_ui/src/src.dart';

/// Lets the EndUser pinch to zoom a web app between [minScale] and
/// [maxScale], pan it, and see it clipped to this widget's bounds; on
/// Android, iOS, macOS, Windows, and Linux it builds [child] alone
/// (CO-01-04 US-01).
///
/// - In debug builds on every platform the constructor asserts that
///   [minScale] is above 0 and [maxScale] is at least [minScale].
/// - New limits that leave the zoom outside them ease it to the nearest
///   limit about the viewport's center, at once under reduced motion; the
///   center stays fixed only as far as the app's bounds allow, as a pinch
///   does (R16).
/// - It extends no component base, as [StratumSlot] does.
class StratumWebZoom extends StatelessWidget {
  const new({
    super.key,
    this.minScale = 1.0,
    this.maxScale = 2.5,
    required this.child,
  }) : assert(
         minScale > 0,
         'StratumWebZoom: minScale must be above 0, got $minScale',
       ),
       assert(
         maxScale >= minScale,
         'StratumWebZoom: maxScale must be at least minScale, got '
         '$maxScale below $minScale',
       );

  /// Default 1.0, so the app never shows smaller than its own layout.
  final double minScale;

  /// Default 2.5, Flutter's default.
  final double maxScale;

  /// The web app, or the part of it to zoom.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return _WebZoomViewer(minScale: minScale, maxScale: maxScale, child: child);
  }
}

/// The web branch: one pinch zoom under a guard that keeps a mouse wheel
/// scroll from changing the transform (US-01 FR-03; web_zoom s01 "Wheel
/// guard").
class _WebZoomViewer extends StatefulWidget {
  const new({
    required this.minScale,
    required this.maxScale,
    required this.child,
  });

  final double minScale;
  final double maxScale;
  final Widget child;

  @override
  State<_WebZoomViewer> createState() => _WebZoomViewerState();
}

class _WebZoomViewerState extends State<_WebZoomViewer>
    with SingleTickerProviderStateMixin {
  final _controller = _HeldTransformationController();

  /// Eases the scale into new limits (web_zoom s03 invariant 7).
  late final _ease = AnimationController(vsync: this)..addListener(_onEase);

  /// The theme's `standard` curve, set in [_easeIntoLimits].
  final _curve = CurveTween(curve: Curves.easeInOutSine);

  /// From the scale the ease starts at to the nearest new limit.
  final _scales = Tween<double>(begin: 1, end: 1);

  /// The scale the ease shows now.
  late final Animation<double> _scale = _ease.drive(_curve).drive(_scales);

  @override
  void didUpdateWidget(_WebZoomViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.minScale != oldWidget.minScale ||
        widget.maxScale != oldWidget.maxScale) {
      _easeIntoLimits();
    }
  }

  @override
  void dispose() {
    _ease.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _WheelGuard(
    controller: _controller,
    child: InteractiveViewer(
      transformationController: _controller,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      onInteractionStart: _onInteractionStart,
      onInteractionEnd: _onInteractionEnd,
      child: widget.child,
    ),
  );

  /// Yields to a real gesture so it is never fought by the ease; a mouse
  /// wheel also fires this while the guard holds, so it is left alone
  /// (US-01 FR-01 E05).
  void _onInteractionStart(ScaleStartDetails details) {
    if (!_controller.held) _ease.stop();
  }

  /// Eases back into the limits once a real gesture ends; a mouse wheel
  /// notch also fires this while the guard holds, so it is left alone, and
  /// a notch mid-ease never restarts the ease from curve 0 (US-01 FR-01
  /// E05).
  void _onInteractionEnd(ScaleEndDetails details) {
    if (_controller.held || _ease.isAnimating) return;
    _easeIntoLimits();
  }

  /// Takes a scale outside the limits to the nearest one, over the theme's
  /// default motion level, or at once under reduced motion (US-01 FR-01
  /// E05). `InteractiveViewer` never re-clamps on new limits.
  void _easeIntoLimits() {
    _ease.stop();
    final scale = _controller.value.getMaxScaleOnAxis();
    final limit = clampDouble(scale, widget.minScale, widget.maxScale);
    if (limit == scale) return;
    if (context.reducesMotion) {
      _zoomTo(limit);
      return;
    }
    final style =
        (StratumThemeApplication.maybeOf(context)?.animation ??
                StratumAnimation.packageDefault)
            .defaultStyle;
    _ease.duration = durationOf(style);
    _curve.curve = curveOf(style);
    _scales
      ..begin = scale
      ..end = limit;
    _ease.forward(from: 0);
  }

  void _onEase() => _zoomTo(_scale.value);

  /// Sets the scale to [scale] about the viewport's center, so the point of
  /// the app there stays in place; before the first layout it does nothing.
  ///
  /// The viewport's size is the last layout's; `BuildContext.size` throws
  /// during the build that calls [didUpdateWidget].
  void _zoomTo(double scale) {
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final size = viewport.size;
    final center = size.center(Offset.zero);
    final matrix = _controller.value;
    final ratio = scale / matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    _controller.value = Matrix4.diagonal3Values(scale, scale, scale)
      ..setTranslationRaw(
        _clampToBounds(
          center.dx + (translation.x - center.dx) * ratio,
          size.width,
          scale,
        ),
        _clampToBounds(
          center.dy + (translation.y - center.dy) * ratio,
          size.height,
          scale,
        ),
        0,
      );
  }

  /// The nearest point to [value] that keeps the app's content from
  /// crossing the viewport's edge on this axis, as `InteractiveViewer`'s own
  /// pinch does with its default zero boundary margin (R16).
  double _clampToBounds(double value, double extent, double scale) {
    final bound = extent * (1 - scale);
    return bound <= 0
        ? clampDouble(value, bound, 0)
        : clampDouble(value, 0, bound);
  }
}

/// Ignores every new transform while [held].
class _HeldTransformationController extends TransformationController {
  bool held = false;

  @override
  set value(Matrix4 newValue) {
    if (held) return;
    super.value = newValue;
  }
}

/// Holds the controller from just before `InteractiveViewer`'s own
/// listener sees a mouse wheel scroll until just after: `InteractiveViewer`
/// turns every such scroll into scale (`interactive_viewer.dart:932-936`),
/// and Flutter hands a pointer signal to every hit-test entry in order, so
/// no child can stop it.
class _WheelGuard extends SingleChildRenderObjectWidget {
  const new({required this.controller, required super.child});

  final _HeldTransformationController controller;

  @override
  _RenderWheelGuard createRenderObject(BuildContext context) =>
      _RenderWheelGuard(controller);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWheelGuard renderObject,
  ) {
    renderObject.controller = controller;
  }
}

/// One of the guard's two hit-test entries: the [first] runs before every
/// entry of its subtree, the other after them.
final class _GuardEntry extends BoxHitTestEntry {
  new(super.target, super.localPosition, {required this.first});

  final bool first;
}

class _RenderWheelGuard extends RenderProxyBox {
  new(this.controller);

  _HeldTransformationController controller;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(_GuardEntry(this, position, first: true));
    final hit = hitTestChildren(result, position: position);
    result.add(_GuardEntry(this, position, first: false));
    return hit;
  }

  /// A trackpad scroll pans in `InteractiveViewer` and a browser pinch
  /// arrives as a `PointerScaleEvent`, so only a mouse wheel scroll holds.
  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (entry is! _GuardEntry) return;
    if (event is! PointerScrollEvent) return;
    if (event.kind == PointerDeviceKind.trackpad) return;
    controller.held = entry.first;
  }
}
