// Frozen by tool/perf_freeze.dart from f64627d:lib/src/components/common/layout/flex_layout.dart. Do not edit; run
// the tool again. Verbatim except this header, the baseline import,
// and the Baseline prefix on the names the frozen files declare.
// The live name StratumFocusGroup is patched to FocusGroup; everything
// else stays verbatim from f64627d.
// ignore_for_file: type=lint, unused_import, unnecessary_import
import 'baseline.dart';

import 'package:flutter/rendering.dart'
    show RenderIntrinsicHeight, RenderIntrinsicWidth, RenderProxyBox;
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Flex] on [BaselineBoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A main-axis size in [style] (a height or max height when [direction] is
/// vertical, a width or max width when it is horizontal) forces
/// [MainAxisSize.max], so the layout fills the extent it is given. [gap]
/// becomes [Flex.spacing], and `scroll` scrolls along [direction] unless
/// its own `direction` says otherwise. [direction] may change between
/// builds; the children keep their State.
///
/// [BaselineColumnLayout] and [BaselineRowLayout] fix [direction].
class BaselineFlexLayout extends BaselineBoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    required this.direction,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
    this.focusGroup,
    required this.children,
  });

  /// The main axis: [Axis.vertical] lays the children out as a column,
  /// [Axis.horizontal] as a row.
  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  /// Sizes the layout to its largest child across [direction], as
  /// [IntrinsicWidth] does in a column and [IntrinsicHeight] in a row,
  /// unless [style] sets that size. A [direction] change keeps the
  /// children's State with it set too; toggling it remounts them.
  final bool crossAxisIntrinsic;

  /// Space between children.
  final double? gap;

  /// Makes the focusable children one roving Tab stop with arrow, Home,
  /// and End keys; see [FocusGroup]. Switching between null and a
  /// value remounts the children.
  final FocusGroup? focusGroup;
  final List<Widget> children;

  @override
  Axis get scrollDirection => direction;

  bool get _vertical => direction == Axis.vertical;

  MainAxisSize get _mainAxisSize {
    final style = this.style;
    final fills = _vertical
        ? style?.height != null || style?.maxHeight != null
        : style?.width != null || style?.maxWidth != null;
    return fills ? MainAxisSize.max : mainAxisSize;
  }

  /// Whether [style] sets the size across [direction].
  bool get _hasCrossSize =>
      _vertical ? style?.width != null : style?.height != null;

  @override
  Widget buildContent(BuildContext context) {
    Widget content = Flex(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    if (crossAxisIntrinsic) {
      content = _CrossIntrinsic(
        direction: direction,
        sizesCross: !_hasCrossSize,
        child: content,
      );
    }
    final group = focusGroup;
    if (group == null) return content;
    return FocusGroupFrame(
      group: group,
      axis: _vertical ? FocusGroupAxis.vertical : FocusGroupAxis.horizontal,
      textDirection: textDirection,
      child: content,
    );
  }
}

/// Sizes the cross axis of a [Flex] along [direction] to its largest
/// child, as [IntrinsicWidth] does for a column and [IntrinsicHeight] for
/// a row; with [sizesCross] false it passes the constraints through.
///
/// One render object serves both axes and both modes, so a
/// [BaselineFlexLayout.direction] change, or a style that starts or stops setting
/// the cross size, updates it in place; swapping [IntrinsicWidth] for
/// [IntrinsicHeight] would remount the children.
class _CrossIntrinsic extends SingleChildRenderObjectWidget {
  const new({
    required this.direction,
    required this.sizesCross,
    required super.child,
  });

  final Axis direction;
  final bool sizesCross;

  @override
  _RenderCrossIntrinsic createRenderObject(BuildContext context) {
    return _RenderCrossIntrinsic(direction: direction, sizesCross: sizesCross);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCrossIntrinsic renderObject,
  ) {
    renderObject
      ..direction = direction
      ..sizesCross = sizesCross;
  }
}

/// The render object of [_CrossIntrinsic]: [RenderIntrinsicWidth] without
/// steps for a vertical [direction], [RenderIntrinsicHeight] for a
/// horizontal one, and a plain proxy when not [sizesCross].
class _RenderCrossIntrinsic extends RenderProxyBox {
  new({required Axis direction, required bool sizesCross})
    : _direction = direction,
      _sizesCross = sizesCross;

  Axis get direction => _direction;
  Axis _direction;
  set direction(Axis value) {
    if (value == _direction) return;
    _direction = value;
    markNeedsLayout();
  }

  bool get sizesCross => _sizesCross;
  bool _sizesCross;
  set sizesCross(bool value) {
    if (value == _sizesCross) return;
    _sizesCross = value;
    markNeedsLayout();
  }

  /// Whether the width is sized to the widest child, as in a column.
  bool get _sizesWidth => _sizesCross && _direction == Axis.vertical;

  /// Whether the height is sized to the tallest child, as in a row.
  bool get _sizesHeight => _sizesCross && _direction == Axis.horizontal;

  static double _finiteWidth(RenderBox child, double width) =>
      width.isFinite ? width : child.getMaxIntrinsicWidth(double.infinity);

  static double _finiteHeight(RenderBox child, double height) =>
      height.isFinite ? height : child.getMaxIntrinsicHeight(double.infinity);

  @override
  double computeMinIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    if (_sizesWidth) return child.getMaxIntrinsicWidth(height);
    return child.getMinIntrinsicWidth(
      _sizesHeight ? _finiteHeight(child, height) : height,
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    return child.getMaxIntrinsicWidth(
      _sizesHeight ? _finiteHeight(child, height) : height,
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    if (_sizesHeight) return child.getMaxIntrinsicHeight(width);
    return child.getMinIntrinsicHeight(
      _sizesWidth ? _finiteWidth(child, width) : width,
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    return child.getMaxIntrinsicHeight(
      _sizesWidth ? _finiteWidth(child, width) : width,
    );
  }

  BoxConstraints _childConstraints(
    RenderBox child,
    BoxConstraints constraints,
  ) {
    if (_sizesWidth && !constraints.hasTightWidth) {
      return constraints.tighten(
        width: child.getMaxIntrinsicWidth(constraints.maxHeight),
      );
    }
    if (_sizesHeight && !constraints.hasTightHeight) {
      return constraints.tighten(
        height: child.getMaxIntrinsicHeight(constraints.maxWidth),
      );
    }
    return constraints;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return child.getDryLayout(_childConstraints(child, constraints));
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    return child.getDryBaseline(
      _childConstraints(child, constraints),
      baseline,
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(child, constraints), parentUsesSize: true);
    size = child.size;
  }
}
