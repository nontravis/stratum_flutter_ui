import 'dart:math' as math;

import 'package:flutter/rendering.dart'
    show
        BaselineOffset,
        BoxHitTestResult,
        BoxParentData,
        ClipRectLayer,
        ContainerBoxParentData,
        ContainerRenderObjectMixin,
        LayerHandle,
        PaintingContext,
        PipelineOwner,
        RenderBox,
        RenderObjectVisitor,
        RenderObjectWithLayoutCallbackMixin;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:stratum_ui/src/components/common/layout/wrap_cut.dart';
import 'package:stratum_ui/src/src.dart';

/// The content of a [WrapLayout] in overflow mode (s03 invariants 36 to
/// 38): [Wrap]'s run rules, cut by [maxRuns] and [maxChildren] at the
/// limit that hides more, and the overflow child of [overflowBuilder],
/// built during layout from the exact hidden count.
///
/// Not exported: [WrapLayout] builds it when `overflowBuilder`, `maxRuns`,
/// or `maxChildren` is set.
class WrapOverflowFrame extends StatefulWidget {
  const new({
    super.key,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 0,
    this.runSpacing = 0,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.maxRuns,
    this.maxChildren,
    this.overflowBuilder,
    required this.children,
  });

  final Axis direction;
  final WrapAlignment alignment;
  final double spacing;
  final double runSpacing;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;

  /// Null reads the ambient [Directionality].
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;

  /// Clips the content that overflows the frame, as [Wrap] does.
  final Clip clipBehavior;
  final int? maxRuns;
  final int? maxChildren;

  /// Builds the overflow child from the number of hidden children, during
  /// layout; null hides them with no indicator.
  final Widget Function(BuildContext context, int hiddenCount)? overflowBuilder;
  final List<Widget> children;

  @override
  State<WrapOverflowFrame> createState() => _WrapOverflowFrameState();
}

class _WrapOverflowFrameState extends State<WrapOverflowFrame> {
  @override
  Widget build(BuildContext context) {
    return _WrapOverflow(
      frame: widget,
      textDirection: widget.textDirection ?? Directionality.maybeOf(context),
    );
  }
}

/// The render widget of [WrapOverflowFrame]; [_WrapOverflowElement]
/// builds its children.
class _WrapOverflow extends RenderObjectWidget {
  const new({required this.frame, required this.textDirection});

  final WrapOverflowFrame frame;
  final TextDirection? textDirection;

  @override
  RenderObjectElement createElement() => _WrapOverflowElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWrapOverflow(this);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWrapOverflow renderObject,
  ) {
    renderObject.configure(this);
  }
}

/// The slot of the overflow child; the children take [IndexedSlot]s.
const _overflowSlot = Object();

/// Builds the children when the wrap builds, and the overflow child
/// inside the render object's layout, as [LayoutBuilder] builds its child
/// (`widgets/layout_builder.dart`, Flutter 3.47.3).
///
/// Its own [BuildScope] makes a dirty descendant rebuild in the wrap's
/// next layout callback, so a build inside layout never flushes another
/// subtree.
class _WrapOverflowElement extends RenderObjectElement {
  new(_WrapOverflow super.widget);

  @override
  _RenderWrapOverflow get renderObject =>
      super.renderObject as _RenderWrapOverflow;

  WrapOverflowFrame get _frame => (widget as _WrapOverflow).frame;

  List<Element> _children = const [];
  final _forgotten = <Element>{};
  Element? _overflow;

  /// The hidden count [_overflow] was built for; null builds it again.
  int? _overflowCount;

  /// How many children the last cut showed; null before the first cut.
  int? _shown;

  @override
  BuildScope get buildScope => _buildScope;
  late final _buildScope = BuildScope(scheduleRebuild: _scheduleRebuild);
  bool _deferred = false;

  /// [LayoutBuilder]'s schedule: a dirty descendant reruns the layout
  /// callback, deferred to the next frame when the tree is idle or in its
  /// post-frame callbacks.
  void _scheduleRebuild() {
    if (_deferred) return;
    final idle = switch (SchedulerBinding.instance.schedulerPhase) {
      SchedulerPhase.idle || SchedulerPhase.postFrameCallbacks => true,
      SchedulerPhase.transientCallbacks ||
      SchedulerPhase.midFrameMicrotasks ||
      SchedulerPhase.persistentCallbacks => false,
    };
    if (!idle) {
      renderObject.scheduleLayoutCallback();
      return;
    }
    _deferred = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _deferred = false;
      if (mounted) renderObject.scheduleLayoutCallback();
    });
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject.element = this;
    _children = _buildChildren(const []);
  }

  @override
  void update(_WrapOverflow newWidget) {
    super.update(newWidget);
    _children = _buildChildren(_children);
    _rebuildOverflow();
  }

  @override
  void markNeedsBuild() => _rebuildOverflow();

  @override
  void performRebuild() {
    _rebuildOverflow();
    super.performRebuild();
  }

  /// Builds the overflow child again in the next layout: its builder, or
  /// an inherited widget it reads through this element, may have changed.
  void _rebuildOverflow() {
    _overflowCount = null;
    renderObject.scheduleLayoutCallback();
  }

  @override
  void unmount() {
    renderObject.element = null;
    super.unmount();
  }

  List<Element> _buildChildren(List<Element> old) {
    final built = updateChildren(
      old,
      _frame.children,
      forgottenChildren: _forgotten,
    );
    _forgotten.clear();
    return built;
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final child in _children) {
      if (!_forgotten.contains(child)) visitor(child);
    }
    final overflow = _overflow;
    if (overflow != null) visitor(overflow);
  }

  /// Only the shown children and the overflow child are onstage, as
  /// [IndexedStack] keeps its hidden children offstage.
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    _children.take(_shown ?? _children.length).forEach(visitor);
    final overflow = _overflow;
    if (overflow != null) visitor(overflow);
  }

  @override
  void forgetChild(Element child) {
    if (child == _overflow) {
      _overflow = null;
    } else {
      _forgotten.add(child);
    }
    super.forgetChild(child);
  }

  /// Rebuilds the descendants marked dirty since the last layout; the
  /// render object's layout callback.
  void flushDirty() => owner!.buildScope(this);

  /// Builds the overflow child for [hiddenCount], or removes it at 0,
  /// inside the render object's layout.
  void buildOverflow(int hiddenCount) {
    if (hiddenCount == _overflowCount) return;
    _overflowCount = hiddenCount;
    owner!.buildScope(this, () {
      final builder = _frame.overflowBuilder;
      Widget? built;
      if (builder != null && hiddenCount > 0) {
        try {
          built = builder(this, hiddenCount);
        } on Object catch (error, stack) {
          final details = FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'stratum_ui',
            context: ErrorDescription('building the overflow child of $widget'),
          );
          FlutterError.reportError(details);
          built = ErrorWidget.builder(details);
        }
      }
      _overflow = updateChild(_overflow, built, _overflowSlot);
    });
  }

  /// Records the cut: the first [shown] children show.
  void applyCut(int shown) => _shown = shown;

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    if (slot == _overflowSlot) {
      renderObject.overflow = child;
      return;
    }
    final previous = (slot! as IndexedSlot<Element?>).value;
    renderObject.insert(child, after: previous?.renderObject as RenderBox?);
  }

  @override
  void moveRenderObjectChild(
    RenderBox child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    final previous = (newSlot! as IndexedSlot<Element?>).value;
    renderObject.move(child, after: previous?.renderObject as RenderBox?);
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) {
    if (slot == _overflowSlot) {
      renderObject.overflow = null;
    } else {
      renderObject.remove(child);
    }
  }
}

class _WrapOverflowParentData extends ContainerBoxParentData<RenderBox> {
  /// Whether the last layout showed the child.
  bool shown = false;
}

/// One run of a cut: its items, indices into the children with -1 for the
/// overflow child, and its extents along and across [Wrap]'s direction.
class _Run {
  final items = <int>[];
  double main = 0;
  double cross = 0;
}

/// [Wrap]'s layout with a cut: runs by [cutWrap], placed as `RenderWrap`
/// places them (`rendering/wrap.dart`, Flutter 3.47.3). It paints and hit
/// tests only the shown children and the overflow child.
class _RenderWrapOverflow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _WrapOverflowParentData>,
        RenderObjectWithLayoutCallbackMixin {
  new(_WrapOverflow widget)
    : _frame = widget.frame,
      _textDirection = widget.textDirection;

  /// Builds the children during layout; null once unmounted.
  _WrapOverflowElement? element;

  WrapOverflowFrame _frame;
  TextDirection? _textDirection;

  void configure(_WrapOverflow widget) {
    _frame = widget.frame;
    _textDirection = widget.textDirection;
    markNeedsLayout();
  }

  RenderBox? _overflow;
  RenderBox? get overflow => _overflow;
  set overflow(RenderBox? value) {
    final old = _overflow;
    if (old != null) dropChild(old);
    _overflow = value;
    if (value != null) adoptChild(value);
  }

  /// The children the last layout showed, then the overflow child.
  List<RenderBox> _shownBoxes = const [];
  bool _hasVisualOverflow = false;
  final _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WrapOverflowParentData) {
      child.parentData = _WrapOverflowParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _overflow?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _overflow?.detach();
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    final overflow = _overflow;
    if (overflow != null) redepthChild(overflow);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    final overflow = _overflow;
    if (overflow != null) visitor(overflow);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() => [
    ...super.debugDescribeChildren(),
    if (_overflow case final overflow?)
      overflow.toDiagnosticsNode(name: 'overflow'),
  ];

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void layoutCallback() => element?.flushDirty();

  /// The children in paint order; [ContainerRenderObjectMixin] exposes
  /// only [firstChild] and [childAfter].
  List<RenderBox> getChildrenAsList() {
    final result = <RenderBox>[];
    for (var child = firstChild; child != null; child = childAfter(child)) {
      result.add(child);
    }
    return result;
  }

  bool get _horizontal => _frame.direction == Axis.horizontal;
  double _main(Size size) => _horizontal ? size.width : size.height;
  double _cross(Size size) => _horizontal ? size.height : size.width;
  Size _size(double main, double cross) =>
      _horizontal ? Size(main, cross) : Size(cross, main);
  double _limit(BoxConstraints constraints) =>
      _horizontal ? constraints.maxWidth : constraints.maxHeight;
  BoxConstraints _childConstraints(BoxConstraints constraints) => _horizontal
      ? BoxConstraints(maxWidth: constraints.maxWidth)
      : BoxConstraints(maxHeight: constraints.maxHeight);

  /// Whether text direction and vertical direction flip the main and the
  /// cross axis, as `RenderWrap._areAxesFlipped` reads them.
  (bool, bool) get _flips {
    final horizontal =
        (_textDirection ?? TextDirection.ltr) == TextDirection.rtl;
    final vertical = _frame.verticalDirection == VerticalDirection.up;
    return _horizontal ? (horizontal, vertical) : (vertical, horizontal);
  }

  WrapCut _cutOf(List<Size> sizes, BoxConstraints constraints) => cutWrap(
    extents: [for (final size in sizes) _main(size)],
    limit: _limit(constraints),
    spacing: _frame.spacing,
    maxRuns: _frame.maxRuns,
    maxChildren: _frame.maxChildren,
  );

  /// The runs of [cut] over the children's [sizes], with the overflow
  /// child's [overflow] size at the end of its run.
  List<_Run> _runsOf(WrapCut cut, List<Size> sizes, Size? overflow) {
    final runs = [for (var i = 0; i < cut.runCount; i++) _Run()];
    void add(int run, int item, Size size) {
      final target = runs[run];
      target.main +=
          (target.items.isEmpty ? 0.0 : _frame.spacing) + _main(size);
      target.cross = math.max(target.cross, _cross(size));
      target.items.add(item);
    }

    for (final (i, run) in cut.runOf.indexed) {
      add(run, i, sizes[i]);
    }
    final overflowRun = cut.overflowRun;
    if (overflowRun != null && overflow != null) add(overflowRun, -1, overflow);
    return [
      for (final run in runs)
        if (run.items.isNotEmpty) run,
    ];
  }

  /// The size [runs] need before the constraints apply.
  Size _extentOf(List<_Run> runs) {
    if (runs.isEmpty) return Size.zero;
    var main = 0.0;
    var cross = _frame.runSpacing * (runs.length - 1);
    for (final run in runs) {
      main = math.max(main, run.main);
      cross += run.cross;
    }
    return _size(main, cross);
  }

  @override
  void performLayout() {
    runLayoutCallback();
    final element = this.element!;
    final children = getChildrenAsList();
    final childConstraints = _childConstraints(constraints);
    for (final child in children) {
      child.layout(childConstraints, parentUsesSize: true);
    }
    final cut = cutWrap(
      extents: [for (final child in children) _main(child.size)],
      limit: _limit(constraints),
      spacing: _frame.spacing,
      maxRuns: _frame.maxRuns,
      maxChildren: _frame.maxChildren,
      overflowExtent: _frame.overflowBuilder == null
          ? null
          : (count) => _layOutOverflow(count, childConstraints),
    );
    final overflowRun = cut.overflowRun;
    invokeLayoutCallback<BoxConstraints>((_) {
      if (overflowRun == null) element.buildOverflow(0);
      element.applyCut(cut.shown);
    });
    _place(cut, children, overflowRun == null ? null : _overflow);
  }

  /// Builds the overflow child for [count] and lays it out; its main-axis
  /// extent.
  double _layOutOverflow(int count, BoxConstraints childConstraints) {
    invokeLayoutCallback<BoxConstraints>((_) => element!.buildOverflow(count));
    final overflow = _overflow!..layout(childConstraints, parentUsesSize: true);
    return _main(overflow.size);
  }

  /// Sizes the frame and places the runs of [cut] as `RenderWrap`'s
  /// `_positionChildren` places them.
  void _place(WrapCut cut, List<RenderBox> children, RenderBox? overflow) {
    final runs = _runsOf(cut, [
      for (final child in children) child.size,
    ], overflow?.size);
    final content = _extentOf(runs);
    final box = constraints.constrain(content);
    size = box;
    _hasVisualOverflow =
        box.width < content.width || box.height < content.height;
    RenderBox itemAt(int item) => item < 0 ? overflow! : children[item];
    for (final child in children) {
      (child.parentData! as _WrapOverflowParentData).shown = false;
    }
    _shownBoxes = [
      for (final run in runs)
        for (final item in run.items) itemAt(item),
    ];
    for (final child in _shownBoxes) {
      (child.parentData! as _WrapOverflowParentData).shown = true;
    }
    if (runs.isEmpty) return;
    final (flipMain, flipCross) = _flips;
    final crossAlignment = flipCross
        ? _flipped(_frame.crossAxisAlignment)
        : _frame.crossAxisAlignment;
    final (runLeading, runBetween) = _distribute(
      _frame.runAlignment,
      math.max(0.0, _cross(box) - _cross(content)),
      _frame.runSpacing,
      runs.length,
      flipped: flipCross,
    );
    var runOffset = runLeading;
    for (final run in flipCross ? runs.reversed : runs) {
      final (leading, between) = _distribute(
        _frame.alignment,
        math.max(0.0, _main(box) - run.main),
        _frame.spacing,
        run.items.length,
        flipped: flipMain,
      );
      var childOffset = leading;
      for (final item in flipMain ? run.items.reversed : run.items) {
        final child = itemAt(item);
        final crossOffset =
            _crossFactor(crossAlignment) * (run.cross - _cross(child.size));
        (child.parentData! as _WrapOverflowParentData).offset = _horizontal
            ? Offset(childOffset, runOffset + crossOffset)
            : Offset(runOffset + crossOffset, childOffset);
        childOffset += _main(child.size) + between;
      }
      runOffset += run.cross + runBetween;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final childConstraints = _childConstraints(constraints);
    final sizes = [
      for (final child in getChildrenAsList())
        child.getDryLayout(childConstraints),
    ];
    final cut = _cutOf(sizes, constraints);
    return constraints.constrain(_extentOf(_runsOf(cut, sizes, null)));
  }

  /// The first [count] children, or all of them when null.
  Iterable<RenderBox> _first(int? count) =>
      getChildrenAsList().take(count ?? childCount);

  /// The children the limits keep when each child takes its own run, at
  /// the narrowest main-axis extent.
  int? get _oneRunEach {
    final maxRuns = _frame.maxRuns;
    final maxChildren = _frame.maxChildren;
    if (maxRuns == null) return maxChildren;
    if (maxChildren == null) return maxRuns;
    return math.min(maxRuns, maxChildren);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _horizontal
      ? _first(_oneRunEach).fold(
          0,
          (width, child) =>
              math.max(width, child.getMinIntrinsicWidth(double.infinity)),
        )
      : getDryLayout(BoxConstraints(maxHeight: height)).width;

  @override
  double computeMaxIntrinsicWidth(double height) => _horizontal
      ? _first(_frame.maxChildren).fold(
          0,
          (width, child) => width + child.getMaxIntrinsicWidth(double.infinity),
        )
      : getDryLayout(BoxConstraints(maxHeight: height)).width;

  @override
  double computeMinIntrinsicHeight(double width) => _horizontal
      ? getDryLayout(BoxConstraints(maxWidth: width)).height
      : _first(_oneRunEach).fold(
          0,
          (height, child) =>
              math.max(height, child.getMinIntrinsicHeight(double.infinity)),
        );

  @override
  double computeMaxIntrinsicHeight(double width) => _horizontal
      ? getDryLayout(BoxConstraints(maxWidth: width)).height
      : _first(_frame.maxChildren).fold(
          0,
          (height, child) =>
              height + child.getMaxIntrinsicHeight(double.infinity),
        );

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    var result = BaselineOffset.noBaseline;
    for (final child in _shownBoxes) {
      final offset = (child.parentData! as BoxParentData).offset;
      result = result.minOf(
        BaselineOffset(child.getDistanceToActualBaseline(baseline)) + offset.dy,
      );
    }
    return result.offset;
  }

  @override
  bool paintsChild(RenderBox child) =>
      (child.parentData! as _WrapOverflowParentData).shown;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _shownBoxes.reversed) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  /// The clip of the content: [WrapOverflowFrame.clipBehavior] when the
  /// content overflows, as [Wrap] clips; null paints with no clip.
  Clip? get _clip {
    final clip = _frame.clipBehavior;
    return _hasVisualOverflow && clip != Clip.none ? clip : null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final clip = _clip;
    if (clip == null) {
      _clipLayer.layer = null;
      _paintShown(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintShown,
      clipBehavior: clip,
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintShown(PaintingContext context, Offset offset) {
    for (final child in _shownBoxes) {
      final childOffset = (child.parentData! as BoxParentData).offset;
      context.paintChild(child, childOffset + offset);
    }
  }
}

/// `WrapAlignment._distributeSpace` (`rendering/wrap.dart:95-126`, Flutter
/// 3.47.3): the leading space and the space between [count] items.
(double, double) _distribute(
  WrapAlignment alignment,
  double free,
  double spacing,
  int count, {
  required bool flipped,
}) {
  return switch (alignment) {
    WrapAlignment.start => (flipped ? free : 0.0, spacing),
    WrapAlignment.end => (flipped ? 0.0 : free, spacing),
    WrapAlignment.spaceBetween when count < 2 => (
      flipped ? free : 0.0,
      spacing,
    ),
    WrapAlignment.center => (free / 2, spacing),
    WrapAlignment.spaceBetween => (0.0, free / (count - 1) + spacing),
    WrapAlignment.spaceAround => (free / count / 2, free / count + spacing),
    WrapAlignment.spaceEvenly => (
      free / (count + 1),
      free / (count + 1) + spacing,
    ),
  };
}

/// `WrapCrossAlignment._flipped` (`rendering/wrap.dart:157-161`).
WrapCrossAlignment _flipped(WrapCrossAlignment alignment) =>
    switch (alignment) {
      WrapCrossAlignment.start => WrapCrossAlignment.end,
      WrapCrossAlignment.end => WrapCrossAlignment.start,
      WrapCrossAlignment.center => WrapCrossAlignment.center,
    };

/// `WrapCrossAlignment._alignment` (`rendering/wrap.dart:163-167`).
double _crossFactor(WrapCrossAlignment alignment) => switch (alignment) {
  WrapCrossAlignment.start => 0,
  WrapCrossAlignment.end => 1,
  WrapCrossAlignment.center => 0.5,
};
