import 'package:flutter/rendering.dart'
    show BoxHitTestEntry, BoxHitTestResult, RenderProxyBox;
import 'package:stratum_ui/src/src.dart';

/// Lets the EndUser pinch to zoom a web app between [minScale] and
/// [maxScale], pan it, and see it clipped to this widget's bounds; on
/// Android, iOS, macOS, Windows, and Linux it builds [child] alone
/// (CO-01-04 US-01).
///
/// In debug builds on every platform the constructor asserts that
/// [minScale] is above 0 and [maxScale] is at least [minScale]. It extends
/// no component base, as [Slot] does.
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

class _WebZoomViewerState extends State<_WebZoomViewer> {
  final _controller = _HeldTransformationController();

  @override
  void dispose() {
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
      child: widget.child,
    ),
  );
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
