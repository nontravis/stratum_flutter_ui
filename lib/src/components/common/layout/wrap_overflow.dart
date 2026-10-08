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
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_cut.dart';
import 'package:stratum_ui/src/components/common/style/reduced_motion.dart';
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

class _WrapOverflowFrameState extends State<WrapOverflowFrame>
    with SingleTickerProviderStateMixin {
  /// Takes focus when no node can after a collapse hides the focused child
  /// (US-14 FR-03 E06) or an expand removes the focused overflow child
  /// (owner ruling R5); skipped by Tab, so the next Tab moves on from the
  /// wrap's place.
  final _wrapNode = FocusNode(debugLabel: 'WrapLayout', skipTraversal: true);

  @override
  void dispose() {
    _wrapNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion =
        (StratumThemeApplication.maybeOf(context)?.animation ??
                StratumAnimation.packageDefault)
            .defaultStyle;
    return Focus(
      focusNode: _wrapNode,
      includeSemantics: false,
      child: _WrapOverflow(
        frame: widget,
        textDirection: widget.textDirection ?? Directionality.maybeOf(context),
        wrapNode: _wrapNode,
        vsync: this,
        duration: reducesMotion(context)
            ? Duration.zero
            : motion.duration ?? Duration.zero,
        curve: motion.curve ?? Curves.easeInOutSine,
      ),
    );
  }
}

/// The render widget of [WrapOverflowFrame]; [_WrapOverflowElement]
/// builds its children.
class _WrapOverflow extends RenderObjectWidget {
  const new({
    required this.frame,
    required this.textDirection,
    required this.wrapNode,
    required this.vsync,
    required this.duration,
    required this.curve,
  });

  final WrapOverflowFrame frame;
  final TextDirection? textDirection;

  /// The wrap's own node, which takes focus when no node after a collapse
  /// or an expand can.
  final FocusNode wrapNode;

  /// Drives the size move: the frame's own [State], the same for the
  /// render object's whole life.
  final TickerProvider vsync;

  /// How long a size move takes: the theme's default level, zero under
  /// reduced motion.
  final Duration duration;
  final Curve curve;

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
  FocusNode get _wrapNode => (widget as _WrapOverflow).wrapNode;

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

  /// Whether an update of the overflow child in this layout dropped the
  /// focus it held, by removing it or building it anew; [handOffFocus]
  /// hands focus on and clears it.
  bool _overflowHeldFocus = false;

  /// The slots [applyCut] flipped from hidden to shown in this layout, so
  /// an expand finds the first child it shows by slot, whatever index a
  /// children change in the same update gave it (owner ruling R5);
  /// [handOffFocus] reads and clears them.
  final _newlyShown = <Element>{};

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

  /// Builds a slot per child. A slot already built keeps the flag its
  /// [_WrapSlotState] holds, whatever index the build gives it, so only
  /// [applyCut] flips it, in the layout of the new cut. A new slot starts
  /// hidden at an index the last cut hides and shown otherwise (shown for
  /// all before the first cut): its tickers have not fired under the wrap,
  /// and this layout's cut flips it if the guess is wrong. A child keyed
  /// by a [GlobalKey] that moves in from elsewhere can arrive holding
  /// focus, which a slot seeded hidden never drops, since no flip runs for
  /// it; [handOffFocus] hands that focus on too.
  List<Element> _buildChildren(List<Element> old) {
    assert(
      !debugChildrenHaveDuplicateKeys(widget, _frame.children),
      'WrapOverflowFrame.children has duplicate keys',
    );
    final shown = _shown;
    return updateChildren(old, [
      for (final (i, child) in _frame.children.indexed)
        _slot(child, hidden: shown != null && i >= shown),
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

  /// The state of the [_WrapSlot] that [slot] holds.
  static _WrapSlotState _stateOf(Element slot) =>
      (slot as StatefulElement).state as _WrapSlotState;

  /// The node that marks the subtree of the child in [slot].
  static FocusNode _nodeOf(Element slot) => _stateOf(slot).node;

  /// Whether primary focus sits in the child in [slot]; false for null.
  static bool _holdsFocus(Element? slot) =>
      slot != null && _nodeOf(slot).hasFocus;

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
    // Removing the overflow child, or building it anew, drops the focus it
    // holds; compare where focus sits before and after, so handOffFocus
    // hands it on.
    final held = _holdsFocus(_overflow);
    owner!.buildScope(this, () {
      _overflow = updateChild(
        _overflow,
        hiddenCount == 0 || builtWidget == null
            ? null
            : _slot(builtWidget, hidden: false),
        _overflowSlot,
      );
    });
    if (held && !_holdsFocus(_overflow)) _overflowHeldFocus = true;
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
  /// leaves focus in the frame of the cut (s03 invariant 39), which
  /// [handOffFocus] then hands on. The one place a built child's flag
  /// flips.
  void applyCut(int shown) {
    _shown = shown;
    owner!.buildScope(this, () {
      for (final (i, child) in _children.indexed) {
        final slot = _stateOf(child);
        final hidden = i >= shown;
        if (slot.hidden == hidden) continue;
        slot.hidden = hidden;
        if (hidden) {
          _newlyShown.remove(child);
        } else {
          _newlyShown.add(child);
        }
      }
    });
  }

  /// Hands focus on after the frame when this layout dropped it (s03
  /// invariant 39); the render object calls it once per layout, after its
  /// last cut.
  ///
  /// When an update dropped the overflow child's focus, an expand that
  /// showed hidden children hands it to the first of them (owner ruling
  /// R5); any other drop, a collapse or a rebuild that replaces the "+N"
  /// child, or a removal that shows no hidden child, follows FR-03 E01's
  /// chain in [_handOff].
  ///
  /// Otherwise it reads where primary focus sits, not which slots flipped:
  /// a slot this cut hid still holds primary focus here, since the focus
  /// manager applies the unfocus after the frame, and a slot seeded hidden
  /// never flips at all ([_buildChildren]).
  void handOffFocus() {
    final shown = _shown!;
    final expanded = _overflowHeldFocus
        ? _children.take(shown).where(_newlyShown.contains).firstOrNull
        : null;
    _newlyShown.clear();
    if (_overflowHeldFocus) {
      _overflowHeldFocus = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => expanded == null ? _handOff() : _handOffToShown(expanded),
      );
      return;
    }
    if (!_wrapNode.hasFocus) return;
    for (var i = shown; i < _children.length; i++) {
      if (!_holdsFocus(_children[i])) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handOff());
      return;
    }
  }

  /// Focuses the first Tab stop of the overflow child, else of the last
  /// shown child, else the wrap's own node (US-14 FR-03 E01, E06), as
  /// `IndexedStackLayout` hands focus after a switch.
  void _handOff() {
    if (!mounted) return;
    final overflow = _overflow;
    final shown = _shown ?? _children.length;
    final target =
        (overflow == null ? null : firstTabStopIn(_nodeOf(overflow))) ??
        (shown == 0 ? null : firstTabStopIn(_nodeOf(_children[shown - 1])));
    (target ?? _wrapNode).requestFocus();
  }

  /// Focuses the first Tab stop of the child in [slot], the first child an
  /// expand showed, else the wrap's own node (owner ruling R5), as US-09
  /// FR-02 hands focus to the incoming child, after the frame whose expand
  /// dropped the focus of the overflow child.
  void _handOffToShown(Element slot) {
    if (!mounted) return;
    final target = slot.mounted ? firstTabStopIn(_nodeOf(slot)) : null;
    (target ?? _wrapNode).requestFocus();
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

  /// The flag a new slot starts with; a later widget's flag is ignored,
  /// since [_WrapSlotState.hidden] owns it from then on.
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

  /// Whether the cut hides the child; set only by
  /// [_WrapOverflowElement.applyCut], inside the wrap's layout, so a
  /// rebuild of the wrap never flips it.
  bool get hidden => _hidden;
  late bool _hidden = widget.hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    setState(() => _hidden = value);
  }

  @override
  void dispose() {
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _hideable(
      Focus(focusNode: node, includeSemantics: false, child: widget.child),
      hidden: _hidden,
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
      _textDirection = widget.textDirection,
      _duration = widget.duration,
      _curve = widget.curve,
      _controller = AnimationController(vsync: widget.vsync) {
    _controller.addListener(_tick);
  }

  /// Builds the children during layout; null once unmounted.
  _WrapOverflowElement? element;

  WrapOverflowFrame _frame;
  TextDirection? _textDirection;
  final AnimationController _controller;
  Duration _duration;
  Curve _curve;

  /// Whether the last [configure] changed `maxRuns` or `maxChildren`.
  bool _limitsChanged = false;

  /// The size the last layout gave the frame, null before the first:
  /// [computeDryLayout] reads it, since it must not read [size]
  /// (`rendering/box.dart:2276-2286`, Flutter 3.47.3), as
  /// `RenderAnimatedSize` keeps `_currentSize`.
  Size? _lastSize;

  /// The ends of the size move under way; null once a layout ends it, so a
  /// non-null [_from] marks a move a [detach] may have stopped.
  Size? _from;
  Size? _to;

  /// The controller value the last layout read. A tick that moves past it
  /// lays the frame out again; the restart inside layout sets it first, so
  /// its own notification does not re-dirty the layout that is running
  /// (`RenderAnimatedSize._lastValue`, `rendering/animated_size.dart:90-91,
  /// 309-311`, Flutter 3.47.3).
  double? _lastValue;

  void _tick() {
    if (_controller.value != _lastValue) markNeedsLayout();
  }

  void configure(_WrapOverflow widget) {
    final frame = widget.frame;
    if (frame.maxRuns != _frame.maxRuns ||
        frame.maxChildren != _frame.maxChildren) {
      _limitsChanged = true;
    }
    _frame = frame;
    _textDirection = widget.textDirection;
    _duration = widget.duration;
    _curve = widget.curve;
    // Reduced motion that turns on mid-move ends the move in this layout
    // (NFR-U03).
    if (_duration == Duration.zero) _controller.stop();
    markNeedsLayout();
  }

  RenderBox? _overflow;
  RenderBox? get overflow => _overflow;
  set overflow(RenderBox? value) => _swapSlot(() {
    final old = _overflow;
    if (old != null) dropChild(old);
    _overflow = value;
    if (value != null) adoptChild(value);
  });

  /// The probe (owner ruling R8): measures a candidate hidden count, laid
  /// out but never painted, hit tested, or exposed to semantics.
  RenderBox? _probe;
  RenderBox? get probe => _probe;
  set probe(RenderBox? value) => _swapSlot(() {
    final old = _probe;
    if (old != null) dropChild(old);
    _probe = value;
    if (value != null) adoptChild(value);
  });

  /// Whether [performLayout] runs.
  bool _inLayout = false;

  /// Whether [_swapSlot] adopts or drops a child inside [performLayout].
  bool _swappingInLayout = false;

  /// Runs [swap], an adopt or a drop of the overflow child or the probe.
  ///
  /// Inside this frame's own layout, which builds both, the
  /// `markNeedsLayout` that `adoptChild` and `dropChild` call is skipped:
  /// the layout under way lays the child out, and neither child takes part
  /// in the dry layout, the intrinsic sizes, or the dry baseline, so the
  /// cached ones stay valid. [RenderBox.markNeedsLayout] would empty them,
  /// and since it marks the parent only while they hold an entry
  /// (`rendering/box.dart:2840-2860`, Flutter 3.47.3), an intrinsic parent
  /// such as [IntrinsicHeight] would miss the next limit change.
  void _swapSlot(VoidCallback swap) {
    _swappingInLayout = _inLayout;
    try {
      swap();
    } finally {
      _swappingInLayout = false;
    }
  }

  /// Skips the relayout an in-layout [_swapSlot] asks for; see there.
  @override
  void markNeedsLayout() {
    if (_swappingInLayout) return;
    super.markNeedsLayout();
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

  /// Lays out again when [detach] stopped a size move, so the move ends at
  /// its target size in the next layout, as `RenderAnimatedSize.attach`
  /// resumes one (`rendering/animated_size.dart`, Flutter 3.47.3).
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _overflow?.attach(owner);
    _probe?.attach(owner);
    if (_from != null) markNeedsLayout();
  }

  /// Stops a size move, so no ticker marks a detached frame dirty.
  @override
  void detach() {
    _controller.stop();
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
    _controller.dispose();
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
    _inLayout = true;
    try {
      _layOut();
    } finally {
      _inLayout = false;
    }
  }

  /// Builds and measures the children, cuts them, and places the cut.
  void _layOut() {
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
    element!.handOffFocus();
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
    final shown = _animatedSize(box);
    size = shown;
    _lastSize = shown;
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
    final anchor = _anchor(box, shown);
    _positionItems(runs, box, content, (item) => itemAt(item).size, (
      item,
      offset,
    ) {
      (itemAt(item).parentData! as _WrapOverflowParentData).offset =
          offset + anchor;
    });
  }

  /// The size to show for the laid-out [target] (s03 invariant 40): a
  /// `maxRuns` or `maxChildren` change starts a move from the size shown
  /// now to [target] over the theme's default level on its `standard`
  /// curve; under reduced motion, or on any other change, the frame shows
  /// [target] at once.
  Size _animatedSize(Size target) {
    _lastValue = _controller.value;
    final starts = _startsMove(target);
    _limitsChanged = false;
    if (starts) {
      final from = _lastSize!;
      _from = from;
      _to = target;
      _controller.duration = _duration;
      // Set before the restart: forward(from: 0) notifies at once, inside
      // this layout, and _tick must not mark it dirty.
      _lastValue = 0;
      _controller.forward(from: 0);
      return constraints.constrain(from);
    }
    final shown = _movingSize(target, constraints);
    if (shown == null) {
      _controller.stop();
      _from = null;
      _to = null;
    }
    return shown ?? target;
  }

  /// Whether a layout to [target] starts a size move: a limit changed
  /// since the last layout, the size changes, and motion is not reduced.
  bool _startsMove(Size target) {
    final last = _lastSize;
    return _limitsChanged &&
        last != null &&
        last != target &&
        _duration > Duration.zero;
  }

  /// The size the move under way shows under [constraints] while its end
  /// is still [target]; null when no move is under way or it ends.
  Size? _movingSize(Size target, BoxConstraints constraints) {
    final from = _from;
    if (!_controller.isAnimating || from == null || target != _to) return null;
    final t = _curve.transform(_controller.value);
    return constraints.constrain(Size.lerp(from, target, t)!);
  }

  /// The size a layout under [constraints] shows for [target], read
  /// without writing any state, for [computeDryLayout] and
  /// [computeDryBaseline]: the size shown now when the layout would start
  /// a move, the move under way, else [target].
  Size _dryShown(Size target, BoxConstraints constraints) {
    if (_startsMove(target)) return constraints.constrain(_lastSize!);
    return _movingSize(target, constraints) ?? target;
  }

  /// The shift of content placed in [box] while the frame shows [shown]:
  /// on each axis the directions flip, the whole difference, so the
  /// content stays on the wrap's start edge, the edge its first run starts
  /// from (the bottom under [VerticalDirection.up], the right under
  /// right-to-left text), and no run jumps when a move starts (US-14
  /// FR-04, FR-01 E07); zero once the move ends.
  Offset _anchor(Size box, Size shown) {
    final rtl = (_textDirection ?? TextDirection.ltr) == TextDirection.rtl;
    final up = _frame.verticalDirection == VerticalDirection.up;
    return Offset(
      rtl ? shown.width - box.width : 0,
      up ? shown.height - box.height : 0,
    );
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

  /// The size a layout under [constraints] gives the frame, mid-move too,
  /// as `RenderAnimatedSize.computeDryLayout` reads its move
  /// (`rendering/animated_size.dart`, Flutter 3.47.3).
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _dryShown(_dryTarget(constraints), constraints);

  /// The size the cut's runs take under [constraints] once no move runs:
  /// the target of a move, and what the intrinsic sizes measure, so an
  /// intrinsic parent sizes the frame to where it lands, as
  /// `RenderAnimatedSize` reports its child's intrinsics.
  Size _dryTarget(BoxConstraints constraints) {
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
    final anchor = _anchor(box, _dryShown(box, constraints));
    var result = BaselineOffset.noBaseline;
    _positionItems(runs, box, content, (item) => sizes[item], (item, offset) {
      result = result.minOf(
        BaselineOffset(
              children[item].getDryBaseline(childConstraints, baseline),
            ) +
            offset.dy +
            anchor.dy,
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
      : _dryTarget(BoxConstraints(maxHeight: height)).width;

  @override
  double computeMaxIntrinsicWidth(double height) => _horizontal
      ? _first(_frame.maxChildren).fold(
          0,
          (width, child) => width + child.getMaxIntrinsicWidth(double.infinity),
        )
      : _dryTarget(BoxConstraints(maxHeight: height)).width;

  @override
  double computeMinIntrinsicHeight(double width) => _horizontal
      ? _dryTarget(BoxConstraints(maxWidth: width)).height
      : _first(_oneRunEach).fold(
          0,
          (height, child) =>
              math.max(height, child.getMinIntrinsicHeight(double.infinity)),
        );

  @override
  double computeMaxIntrinsicHeight(double width) => _horizontal
      ? _dryTarget(BoxConstraints(maxWidth: width)).height
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

  /// The clip of the content: the animating size while it moves (US-14
  /// FR-04), with [Clip.hardEdge] when [WrapOverflowFrame.clipBehavior] is
  /// none; else [WrapOverflowFrame.clipBehavior] when the content
  /// overflows, as [Wrap] clips; null paints with no clip.
  Clip? get _clip {
    final clip = _frame.clipBehavior;
    if (_controller.isAnimating) {
      return clip == Clip.none ? Clip.hardEdge : clip;
    }
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
