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
        RenderBoxContainerDefaultsMixin,
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
  ///
  /// Called for every candidate count `cutWrap` measures, on a fresh
  /// probe each time (owner ruling R8), then once more for the final
  /// count, on the child the frame shows; a [Key] in the built widget is
  /// local to each call, but a [GlobalKey] reports a duplicate-key error,
  /// since the probe and the shown child would both claim it at once. A
  /// GlobalKey a descendant's [State] creates for itself, as `Material`
  /// does, is its own per State and reports nothing.
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
///
/// Not `const`: a const `Object()` canonicalizes to one instance, which
/// would make this `==` to [_probeSlot] too.
final _overflowSlot = Object();

/// The slot of the probe child (owner ruling R8): measures a candidate
/// hidden count for `cutWrap`'s trial loop, on a subtree the frame never
/// paints, hit tests, or exposes to semantics.
final _probeSlot = Object();

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
  Element? _overflow;
  Element? _probe;

  /// The widget [_probe] last built, and the hidden count it was built
  /// for; the live overflow child reuses it instead of asking
  /// [WrapOverflowFrame.overflowBuilder] again for the same count.
  Widget? _probeWidget;
  int? _probeHiddenCount;

  /// The hidden count the live overflow child was last built for.
  int? _overflowHiddenCount;

  /// Whether the live overflow child must rebuild in the next layout even
  /// if the hidden count stays the same: the frame's widget or an
  /// inherited widget it reads may have changed.
  bool _overflowDirty = true;

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

  /// Reruns the cut in the next layout: its builder, or an inherited
  /// widget it reads through this element, may have changed.
  void _rebuildOverflow() {
    _overflowDirty = true;
    renderObject.scheduleLayoutCallback();
  }

  @override
  void unmount() {
    renderObject.element = null;
    super.unmount();
  }

  /// Builds a slot per child. A keyed child keeps the flag its slot holds,
  /// so only [applyCut] flips a child already built, in the layout of the
  /// new cut; an unkeyed or new child takes the flag of its index under
  /// the last cut.
  List<Element> _buildChildren(List<Element> old) {
    assert(
      !debugChildrenHaveDuplicateKeys(widget, _frame.children),
      'WrapOverflowFrame.children has duplicate keys',
    );
    final shown = _shown;
    final hiddenByKey = {
      for (final element in old)
        if (element.widget case _WrapSlot(:final Key key, :final hidden))
          key: hidden,
    };
    return updateChildren(old, [
      for (final (i, child) in _frame.children.indexed)
        _slot(
          child,
          hidden: hiddenByKey[_slotKey(child)] ?? (shown != null && i >= shown),
        ),
    ]);
  }

  /// [child] in its [_WrapSlot], keyed by the child's own key, so a keyed
  /// child keeps its State when the children move. A slot's key is never
  /// a [GlobalKey], so Flutter never retakes a slot and the wrap needs no
  /// `forgetChild`.
  static Widget _slot(Widget child, {required bool hidden}) =>
      _WrapSlot(key: _slotKey(child), hidden: hidden, child: child);

  static Key? _slotKey(Widget child) => switch (child.key) {
    null => null,
    final key => ValueKey<Key>(key),
  };

  /// The node that marks the subtree of the child in [slot].
  // Read by the focus handoff after a collapse or an expand (US-14 FR-03
  // E01 to E03), which applyCut gains next.
  // ignore: unused_element
  static FocusNode _nodeOf(Element slot) =>
      ((slot as StatefulElement).state as _WrapSlotState).node;

  @override
  void visitChildren(ElementVisitor visitor) {
    _children.forEach(visitor);
    final overflow = _overflow;
    if (overflow != null) visitor(overflow);
    final probe = _probe;
    if (probe != null) visitor(probe);
  }

  /// Only the shown children and the overflow child are onstage, as
  /// [IndexedStack] keeps its hidden children offstage; the probe (owner
  /// ruling R8) is never onstage, so `find.text` of the overflow label
  /// finds exactly one widget.
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    _children.take(_shown ?? _children.length).forEach(visitor);
    final overflow = _overflow;
    if (overflow != null) visitor(overflow);
  }

  /// Rebuilds the descendants marked dirty since the last layout; the
  /// render object's layout callback.
  void flushDirty() => owner!.buildScope(this);

  /// Builds the overflow child once, from [builtWidget] (the exact
  /// widget [buildProbe] already built for [hiddenCount]), or removes it
  /// at 0, inside the render object's layout. Skips the rebuild when
  /// neither [hiddenCount] nor the frame's widget or its dependencies
  /// changed since the last layout, and the live child's box is still in
  /// its slot: a probe that took a [GlobalKey]-keyed live child back
  /// leaves its [_WrapSlot] mounted but the slot with no box.
  ///
  /// Reports, debug-only, a [GlobalKey] this build took over from the
  /// still-mounted probe: the live slot inflates the widget the probe
  /// holds, so Flutter's retake moves a keyed element out of the probe
  /// (owner ruling R8's GlobalKey caveat). Flutter tracks that move, but
  /// `finalizeTree` unmounts the probe [dropProbe] deactivated before its
  /// own duplicate check, which skips a defunct former parent, so this is
  /// the only report. A key a descendant's [State]
  /// creates for itself (`Material`'s ink renderer, [AnimatedStyledBox]'s
  /// child key) differs per State, never moves, and never reports. It
  /// reports the same way a throwing `overflowBuilder` does, without
  /// aborting the layout.
  void buildOverflow(int hiddenCount, Widget? builtWidget) {
    assert(
      hiddenCount == 0 || _probeHiddenCount == hiddenCount,
      'buildOverflow expects the count buildProbe last measured',
    );
    if (!_overflowDirty &&
        hiddenCount == _overflowHiddenCount &&
        (hiddenCount == 0 || renderObject.overflow != null)) {
      return;
    }
    _overflowDirty = false;
    _overflowHiddenCount = hiddenCount;
    var probeKeys = const <GlobalKey>{};
    assert(() {
      probeKeys = _debugGlobalKeysOf(_probe);
      return true;
    }(), 'debug-only: collects the GlobalKeys the probe holds');
    owner!.buildScope(this, () {
      _overflow = updateChild(
        _overflow,
        hiddenCount == 0 || builtWidget == null
            ? null
            : _slot(builtWidget, hidden: false),
        _overflowSlot,
      );
    });
    assert(() {
      final key = _debugGlobalKeysOf(_overflow)
          .where(probeKeys.contains)
          .firstOrNull;
      if (key != null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts([
              ErrorSummary(
                'WrapOverflowFrame.overflowBuilder built a widget keyed '
                'by a GlobalKey ($key).',
              ),
              ErrorDescription(
                'The probe that measures each candidate count (owner '
                'ruling R8) and the overflow child it shows both '
                "inflate the builder's output, so the overflow child "
                "took the key's element over from the probe.",
              ),
              ErrorHint(
                'Give the widget overflowBuilder returns a local Key, '
                'or none.',
              ),
            ]),
            library: 'stratum_ui',
            context: ErrorDescription('building the overflow child of $widget'),
          ),
        );
      }
      return true;
    }(), 'debug-only: reports a GlobalKey taken over from the probe');
  }

  /// Builds [WrapOverflowFrame.overflowBuilder]'s widget for [hiddenCount]
  /// on a fresh probe slot (owner ruling R8) and remembers it in
  /// [_probeWidget] so [buildOverflow] can reuse it without asking the
  /// builder again. `cutWrap`'s trial loop calls this once per candidate
  /// count, inside the render object's layout; a builder that throws
  /// reports once and shows an [ErrorWidget] on the probe, which
  /// [buildOverflow] then reuses too.
  ///
  /// Drops the previous probe before building the new one: a
  /// ticker-driven "+N" (`AnimatedSize`, `AnimatedSwitcher`, a Stratum
  /// `AnimatedStyledBox`) must measure itself fresh, never resume a
  /// mid-transition state an earlier trial froze under [TickerMode].
  void buildProbe(int hiddenCount) {
    owner!.buildScope(this, () {
      _probe = updateChild(_probe, null, _probeSlot);
      Widget built;
      try {
        built = _frame.overflowBuilder!(this, hiddenCount);
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
      _probeHiddenCount = hiddenCount;
      _probeWidget = built;
      _probe = updateChild(
        _probe,
        _hideable(
          SelectionContainer.disabled(
            child: HeroMode(enabled: false, child: built),
          ),
          hidden: true,
        ),
        _probeSlot,
      );
    });
  }

  /// Drops the probe (owner ruling R8): called once per layout, after
  /// [buildOverflow], so no probe content survives between layouts (N1)
  /// or when `cutWrap` builds no overflow child at all (N2).
  void dropProbe() {
    owner!.buildScope(this, () {
      _probe = updateChild(_probe, null, _probeSlot);
    });
    _probeWidget = null;
    _probeHiddenCount = null;
  }

  /// The [GlobalKey]s in the element tree of [root], [root] included, an
  /// ancestor's before its descendants', so the first one also found in
  /// the probe keys the element Flutter's retake moved; empty for null.
  /// Debug-only, read by [buildOverflow]'s asserts.
  Set<GlobalKey> _debugGlobalKeysOf(Element? root) {
    final keys = <GlobalKey>{};
    void visit(Element element) {
      if (element.widget.key case final GlobalKey key) keys.add(key);
      element.visitChildren(visit);
    }

    if (root != null) visit(root);
    return keys;
  }

  /// Shows the first [shown] children and hides the rest, inside the
  /// render object's layout, so a child the cut hides stops ticking and
  /// leaves focus in the frame of the cut (s03 invariant 39).
  void applyCut(int shown) {
    _shown = shown;
    owner!.buildScope(this, () {
      for (var i = 0; i < _children.length; i++) {
        final slot = _children[i].widget as _WrapSlot;
        final hidden = i >= shown;
        if (slot.hidden == hidden) continue;
        _children[i] = updateChild(
          _children[i],
          _slot(slot.child, hidden: hidden),
          IndexedSlot<Element?>(i, i == 0 ? null : _children[i - 1]),
        )!;
      }
    });
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    if (slot == _overflowSlot) {
      renderObject.overflow = child;
      return;
    }
    if (slot == _probeSlot) {
      renderObject.probe = child;
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
    } else if (slot == _probeSlot) {
      renderObject.probe = null;
    } else {
      renderObject.remove(child);
    }
  }
}

/// One child of the wrap: shown, or hidden with its tickers stopped and
/// out of focus, keeping its State, as [IndexedStack] hides a child with
/// [ExcludeFocus] and `IndexedStackLayout` adds [TickerMode].
class _WrapSlot extends StatefulWidget {
  const new({super.key, required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  State<_WrapSlot> createState() => _WrapSlotState();
}

class _WrapSlotState extends State<_WrapSlot> {
  /// Marks the child's subtree, so the wrap can tell whether focus sits in
  /// it and find its first Tab stop; takes no focus itself.
  final node = FocusNode(
    debugLabel: 'WrapLayout child',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void dispose() {
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _hideable(
      Focus(focusNode: node, includeSemantics: false, child: widget.child),
      hidden: widget.hidden,
    );
  }
}

/// [child] with its tickers stopped and out of focus while [hidden]; the
/// one wrapper of a [_WrapSlot] and of the probe (owner ruling R8), so
/// both leave tickers and focus the same way.
Widget _hideable(Widget child, {required bool hidden}) => TickerMode(
  enabled: !hidden,
  child: ExcludeFocus(excluding: hidden, child: child),
);

class _WrapOverflowParentData extends ContainerBoxParentData<RenderBox> {
  /// Whether the last layout showed the child.
  bool shown = false;
}

/// The children's boxes, in child order, and the sizes a layout gave them.
typedef _Measured = ({List<RenderBox> boxes, List<Size> sizes});

extension _MeasuredMatch on _Measured {
  /// Whether [other] holds the same boxes at the same sizes.
  bool matches(_Measured other) =>
      listEquals(boxes, other.boxes) && listEquals(sizes, other.sizes);
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
        RenderBoxContainerDefaultsMixin<RenderBox, _WrapOverflowParentData>,
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

  /// The probe (owner ruling R8): measures a candidate hidden count, laid
  /// out but never painted, hit tested, or exposed to semantics.
  RenderBox? _probe;
  RenderBox? get probe => _probe;
  set probe(RenderBox? value) {
    final old = _probe;
    if (old != null) dropChild(old);
    _probe = value;
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
    _probe?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _overflow?.detach();
    _probe?.detach();
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    final overflow = _overflow;
    if (overflow != null) redepthChild(overflow);
    final probe = _probe;
    if (probe != null) redepthChild(probe);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    final overflow = _overflow;
    if (overflow != null) visitor(overflow);
    final probe = _probe;
    if (probe != null) visitor(probe);
  }

  /// Only the shown children and the overflow child reach semantics, as
  /// [IndexedStack] reports only its shown child; the probe (owner ruling
  /// R8) never does, since it holds an interim count no assistive
  /// technology should announce.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      _shownBoxes.forEach(visitor);

  @override
  List<DiagnosticsNode> debugDescribeChildren() => [
    ...super.debugDescribeChildren(),
    if (_overflow case final overflow?)
      overflow.toDiagnosticsNode(name: 'overflow'),
    if (_probe case final probe?) probe.toDiagnosticsNode(name: 'probe'),
  ];

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void layoutCallback() => element?.flushDirty();

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
    final childConstraints = _childConstraints(constraints);
    var measured = _measure(childConstraints);
    var cut = _cutAndApply(measured.sizes, childConstraints);
    // Flipping a child's TickerMode rebuilds what reads it; a child whose
    // root does can take another render object or size, so the cut runs
    // once more over what the flip left, and reports a second change
    // rather than cutting on.
    var now = _measure(childConstraints);
    if (!now.matches(measured)) {
      measured = now;
      cut = _cutAndApply(measured.sizes, childConstraints);
      now = _measure(childConstraints);
      if (!now.matches(measured)) _debugReportUnsettledCut();
    }
    final overflowRun = cut.overflowRun;
    if (overflowRun != null) {
      _overflow!.layout(childConstraints, parentUsesSize: true);
    }
    _place(cut, now.boxes, overflowRun == null ? null : _overflow);
  }

  /// Lays out every child under [childConstraints]: the boxes, in child
  /// order, and the sizes they took.
  _Measured _measure(BoxConstraints childConstraints) {
    final boxes = getChildrenAsList();
    for (final box in boxes) {
      box.layout(childConstraints, parentUsesSize: true);
    }
    return (boxes: boxes, sizes: [for (final box in boxes) box.size]);
  }

  /// Cuts the children's [sizes], measuring each candidate count on the
  /// probe, then builds the overflow child and flips the children's slots
  /// to the cut, inside this layout.
  WrapCut _cutAndApply(List<Size> sizes, BoxConstraints childConstraints) {
    final element = this.element!;
    final cut = cutWrap(
      extents: [for (final size in sizes) _main(size)],
      limit: _limit(constraints),
      spacing: _frame.spacing,
      maxRuns: _frame.maxRuns,
      maxChildren: _frame.maxChildren,
      overflowExtent: _frame.overflowBuilder == null
          ? null
          : (count) => _layOutProbe(count, childConstraints),
    );
    invokeLayoutCallback<BoxConstraints>((_) {
      if (cut.overflowRun == null) {
        element.buildOverflow(0, null);
      } else {
        element.buildOverflow(sizes.length - cut.shown, element._probeWidget);
      }
      element
        ..applyCut(cut.shown)
        ..dropProbe();
    });
    return cut;
  }

  /// Reports, debug-only, a cut that a second flip changed again: the
  /// frame places the children as they are now by the last cut, which may
  /// overflow a run, instead of cutting without end.
  void _debugReportUnsettledCut() {
    assert(() {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError.fromParts([
            ErrorSummary(
              'A child of WrapOverflowFrame changed its render object or '
              'size each time the cut showed or hid it.',
            ),
            ErrorDescription(
              'Showing or hiding a child flips its TickerMode, which '
              'rebuilds what reads it. A child whose root reads TickerMode '
              'and so takes another render object or size moves the cut; '
              'the frame cut twice, then placed the children by the last '
              'cut.',
            ),
            ErrorHint(
              'Keep the render object and the size of a child the same '
              'whether it ticks or not.',
            ),
          ]),
          library: 'stratum_ui',
          context: ErrorDescription('laying out $this'),
        ),
      );
      return true;
    }(), 'debug-only: reports a cut a flip changed twice');
  }

  /// Measures a candidate hidden count on the probe (owner ruling R8) and
  /// lays it out there; its main-axis extent. The live overflow child
  /// builds once, after `cutWrap` settles on a count, from the exact
  /// widget the probe's last call built.
  double _layOutProbe(int count, BoxConstraints childConstraints) {
    invokeLayoutCallback<BoxConstraints>((_) => element!.buildProbe(count));
    final probe = _probe!..layout(childConstraints, parentUsesSize: true);
    return _main(probe.size);
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
    _positionItems(runs, box, content, (item) => itemAt(item).size, (
      item,
      offset,
    ) {
      (itemAt(item).parentData! as _WrapOverflowParentData).offset = offset;
    });
  }

  /// `RenderWrap._positionChildren` (`rendering/wrap.dart:772-839`): walks
  /// [runs] and calls [place] with each item's offset; [sizeOf] gives an
  /// item's size, real for [_place] and dry for [computeDryBaseline], so
  /// neither copies the other's arithmetic.
  void _positionItems(
    List<_Run> runs,
    Size box,
    Size content,
    Size Function(int item) sizeOf,
    void Function(int item, Offset offset) place,
  ) {
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
        final size = sizeOf(item);
        final crossOffset =
            _crossFactor(crossAlignment) * (run.cross - _cross(size));
        place(
          item,
          _horizontal
              ? Offset(childOffset, runOffset + crossOffset)
              : Offset(runOffset + crossOffset, childOffset),
        );
        childOffset += _main(size) + between;
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

  /// `RenderWrap.computeDryBaseline` (`rendering/wrap.dart:617-648`): the
  /// dry layout's baseline, over the children left out of the cut's
  /// overflow child (FR-02 E07, D3: the query never throws).
  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final children = getChildrenAsList();
    final childConstraints = _childConstraints(constraints);
    final sizes = [
      for (final child in children) child.getDryLayout(childConstraints),
    ];
    final cut = _cutOf(sizes, constraints);
    final runs = _runsOf(cut, sizes, null);
    final content = _extentOf(runs);
    final box = constraints.constrain(content);
    var result = BaselineOffset.noBaseline;
    _positionItems(runs, box, content, (item) => sizes[item], (item, offset) {
      result = result.minOf(
        BaselineOffset(
              children[item].getDryBaseline(childConstraints, baseline),
            ) +
            offset.dy,
      );
    });
    return result.offset;
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
