import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderObjectVisitor, RenderProxyBox, SemanticsConfiguration;
import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// The disabled look and behavior the component bases wrap around every
/// component (FO-08 US-07; base s03 invariants 12 to 17).
///
/// It stays in the tree whether [disabled] is true or false: a toggle
/// changes only its values, so the component keeps its elements and its
/// `State`. While [disabled] is true and the component contributes
/// semantics, it reports the component disabled on one container node of
/// its own; it adds no node when the component contributes none.
///
/// It extends no component base, so the bases never wrap it in itself.
class StratumDisabled extends StatelessWidget {
  const new({
    super.key,
    required this.disabled,
    this.dims = true,
    required this.child,
  });

  /// The component's `disabled` prop.
  final bool disabled;

  /// The component's `dimsWhenDisabled` hook: false keeps full opacity
  /// while every other disabled rule holds (US-07 FR-04).
  final bool dims;

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _DisabledSemantics(disabled: disabled, child: child);
}

/// Forms the disabled node only while [disabled] is true and the subtree
/// contributes semantics.
class _DisabledSemantics extends SingleChildRenderObjectWidget {
  const new({required this.disabled, required super.child});

  final bool disabled;

  @override
  _RenderDisabledSemantics createRenderObject(BuildContext context) =>
      _RenderDisabledSemantics(disabled: disabled);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDisabledSemantics renderObject,
  ) {
    renderObject.disabled = disabled;
  }
}

class _RenderDisabledSemantics extends RenderProxyBox {
  new({required bool disabled}) : _disabled = disabled;

  bool _disabled;

  bool? _cachedContributes;

  set disabled(bool value) {
    if (value == _disabled) return;
    _disabled = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    super.visitChildrenForSemantics(visitor);
    if (!_disabled || _cachedContributes == null) return;
    if (_subtreeContributes() == _cachedContributes) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) markNeedsSemanticsUpdate();
    });
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (!_disabled) return;
    final contributes = _cachedContributes = _subtreeContributes();
    if (!contributes) return;
    config
      ..isSemanticBoundary = true
      ..isEnabled = false;
  }

  /// Whether a render object below, in semantics order, adds to the
  /// semantics tree: one whose configuration is annotated or a boundary.
  bool _subtreeContributes() {
    var found = false;
    void visit(RenderObject child) {
      if (found) return;
      final probe = SemanticsConfiguration();
      child.describeSemanticsConfiguration(probe);
      if (probe.isSemanticBoundary || probe.hasBeenAnnotated) {
        found = true;
        return;
      }
      child.visitChildrenForSemantics(visit);
    }

    super.visitChildrenForSemantics(visit);
    return found;
  }
}
