import 'dart:math' as math;

import 'package:multi_split_view/multi_split_view.dart'
    show
        Area,
        MultiSplitView,
        MultiSplitViewController,
        MultiSplitViewTheme,
        MultiSplitViewThemeData;
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/src.dart';

/// Two sizes closer than this, in logical pixels, count as equal.
const double _tolerance = 1e-6;

/// One arrow-key or slider step of a divider, in logical pixels.
const double _step = 16;

/// One arrow-key step of a divider with Shift held, in logical pixels.
const double _largeStep = 64;

/// The layout engine's theme: dividers take no layout space and no hit area,
/// since the split draws its own hit layer over each seam.
final _engineTheme = MultiSplitViewThemeData(dividerThickness: 0);

/// One shown pane as the layout engine holds it: its index in
/// [SplitLayout.panes], its size along the axis, and its limits, all in
/// logical pixels.
typedef _PaneArea = ({int pane, double size, double? min, double? max});

/// The start pane's new size after a step of [delta] logical pixels toward
/// the end side, clamped so both panes stay inside their limits.
///
/// The two panes keep their sum, so the end pane's new size is
/// `start + end` minus the result. A null limit does not bind; when the
/// limits leave no room, the start pane takes the lower bound.
///
/// Not exported: `layout.dart` hides it, and its test imports this file by
/// path.
double splitStep({
  required double start,
  required double end,
  required double delta,
  double? startMin,
  double? startMax,
  double? endMin,
  double? endMax,
}) {
  final total = start + end;
  final lower = math.max(startMin ?? 0, total - (endMax ?? total));
  final upper = math.min(startMax ?? total, total - (endMin ?? 0));
  return (start + delta).clamp(lower, math.max(lower, upper));
}

/// What a [SplitLayout] divider passes its [SplitDividerBuilder].
@immutable
class SplitDividerState {
  const new({
    this.hovered = false,
    this.dragging = false,
    this.focused = false,
  });

  /// True while a pointer rests over the divider's hit area and no drag
  /// runs.
  final bool hovered;

  /// True while the EndUser drags the divider.
  final bool dragging;

  /// True while the divider holds keyboard focus and shows its focus ring.
  final bool focused;

  @override
  bool operator ==(Object other) =>
      other is SplitDividerState &&
      other.hovered == hovered &&
      other.dragging == dragging &&
      other.focused == focused;

  @override
  int get hashCode => Object.hash(hovered, dragging, focused);
}

/// Paints a [SplitLayout] divider over its seam for [state].
///
/// The widget fills the divider's hit area, the platform's minimum target
/// size across the seam and the split's full length along it, centered on
/// the seam; it takes no layout space, takes no pointer, and adds no
/// semantics, since the split owns the drag, the keys, the focus ring, and
/// the slider node.
typedef SplitDividerBuilder = Widget Function(
  BuildContext context,
  SplitDividerState state,
);

/// The panes' chosen fractions of a [SplitLayout], the EndUser's last
/// settled move or the app's own value, which the app keeps and passes
/// back to restore them.
///
/// [fractions] holds one entry per pane of [SplitLayout.panes], a null
/// pane's entry included; a null entry means the pane has no chosen
/// fraction yet, and the whole list is null until the EndUser or the app
/// picks one. The shown panes without an entry open at their own size or
/// flex, and the shown panes with one share the rest in proportion to
/// their entries, each within its limits; an entry of 0 keeps its pane
/// collapsed. A move stores only the two panes beside the moved divider,
/// so every other entry, a hidden pane's or one a narrow window clamps,
/// stays as chosen. A list whose length differs from the panes' applies to
/// none.
///
/// It notifies only when a resize settles: a drag's end, one arrow-key,
/// Home, or End step, a slider action, or a set from code that changes
/// [fractions]; never per drag frame and never when a narrower window
/// clamps only the drawn sizes (US-21 FR-02). A [SplitLayout] given none
/// makes its own, as a [ScrollController], and disposes only that one.
class SplitLayoutController extends ChangeNotifier {
  /// Starts with [fractions], such as ones the app kept, to restore them.
  new({List<double?>? fractions}) : _fractions = _held(fractions);

  List<double?>? _fractions;

  /// Each pane's chosen fraction of the split, by its index in
  /// [SplitLayout.panes]; null when none is chosen.
  List<double?>? get fractions => _fractions;

  set fractions(List<double?>? value) {
    final held = _held(value);
    if (listEquals(held, _fractions)) return;
    _fractions = held;
    notifyListeners();
  }

  /// An unmodifiable copy of [value].
  static List<double?>? _held(List<double?>? value) {
    assert(
      value == null ||
          value.every((entry) => entry == null || entry.isFinite && entry >= 0),
      'Every fraction is null or a finite number of at least 0.',
    );
    return value == null ? null : List.unmodifiable(value);
  }
}

/// One pane of a [SplitLayout]: its [child] and its size along the split
/// axis, in logical pixels.
///
/// A pane opens at [size], or shares the space the sized panes leave in
/// proportion to [flex], 1 when both are null; [min] and [max] bound it
/// whatever opens it, a drag, a key, or a narrower window, while the
/// window leaves room for every pane's minimum.
@immutable
class SplitPane {
  const new({required this.child, this.size, this.flex, this.min, this.max})
    : assert(
        size == null || flex == null,
        'A pane opens at a size or a flex, never both.',
      ),
      assert(
        min == null || max == null || min <= max,
        "A pane's min cannot pass its max.",
      );

  /// The pane's content, laid out at the pane's full size.
  final Widget child;

  /// The size the pane opens at, in logical pixels.
  final double? size;

  /// The pane's share of the space the sized panes leave.
  final double? flex;

  /// The smallest size the pane takes, in logical pixels.
  final double? min;

  /// The largest size the pane takes, in logical pixels.
  final double? max;
}

/// Lays out its [panes] side by side along [axis], with a divider the
/// EndUser drags between each two neighbors (US-21).
///
/// A null pane does not show, and the shown panes fill the split. Under
/// [TextDirection.rtl] a horizontal split mirrors, so the first pane sits
/// on the right. The divider takes no layout space, so neighbors stay
/// flush, and paints nothing unless [dividerBuilder] paints it. Whether or
/// not one paints, the divider's hit area spans the platform's minimum
/// target size ([TapTargetSize.minimumFor]) centered on the seam, shows a
/// resize cursor on hover, and takes a drag along the axis, while a tap, a
/// scroll, or a drag across the axis that starts there still reaches the
/// pane under it; the divider is a Tab stop after every Tab stop of the
/// pane before it, shows the FO-06 focus ring, steps 16 px by the arrow
/// keys along the axis by screen direction, 64 px with Shift held, and
/// goes to the start pane's minimum and maximum by Home and End; and it
/// reads as a slider valued by the start pane's share of the split, with
/// increase and decrease actions that step it. With [resizable] false no
/// divider takes a drag or focus or adds a slider node, while
/// [dividerBuilder] still paints.
///
/// The split needs a bounded extent along [axis]. It builds on
/// `MultiSplitView` of `multi_split_view` for its layout and its pane
/// limits, and draws its own translucent hit layer over the seams (layout
/// s03 invariant 75).
class SplitLayout extends StatefulWidget {
  const new({
    super.key,
    required this.panes,
    this.axis = Axis.horizontal,
    this.resizable = true,
    this.controller,
    this.dividerLabel,
    this.dividerBuilder,
  });

  /// The panes from the start side; a null pane does not show.
  final List<SplitPane?> panes;

  /// The axis the panes line up along.
  final Axis axis;

  /// Whether the dividers take a drag.
  final bool resizable;

  /// Holds the panes' chosen fractions; null makes one of the split's own.
  final SplitLayoutController? controller;

  /// The screen-reader label of every divider; null reads Stratum's
  /// built-in divider label in the locale's language (FO-09).
  final String? dividerLabel;

  /// Paints each divider over its seam; null paints nothing.
  final SplitDividerBuilder? dividerBuilder;

  @override
  State<SplitLayout> createState() => _SplitLayoutState();
}

class _SplitLayoutState extends State<SplitLayout> {
  /// The layout engine, holding one area per shown pane in screen order.
  final _engine = MultiSplitViewController();

  /// The areas last handed to [_engine], in screen order: a rebuild that
  /// resolves the same areas leaves the engine, and a drag in progress on
  /// it, alone.
  List<_PaneArea>? _pushed;

  /// The split's extent along its axis at the last layout.
  double _space = 0;

  /// Whether the engine holds the panes in reverse, as of the last build:
  /// a horizontal split under [TextDirection.rtl].
  bool _mirrored = false;

  /// One focus node per divider, from the start side.
  final _dividerNodes = <FocusNode>[];

  /// The controller the split made, while the app passes none.
  SplitLayoutController? _ownController;

  /// The divider the EndUser drags, from the start side; null between
  /// drags.
  final _dragging = ValueNotifier<int?>(null);

  /// The running drag's pointer position along the axis at its start, and
  /// the two neighbors' sizes then.
  ({double origin, double start, double end})? _dragFrom;

  /// What the hit layer redraws for: the engine's sizes and the drag.
  late final _layerChanges = Listenable.merge([_engine, _dragging]);

  /// The traversal policy above the split, and the ordered one built over
  /// it that puts each pane before its divider and the next pane.
  FocusTraversalPolicy? _outerPolicy;
  OrderedTraversalPolicy? _orderPolicy;

  /// Each pane's own traversal policy when none sits above the split.
  final _readingOrder = ReadingOrderTraversalPolicy();

  SplitLayoutController get _controller =>
      widget.controller ?? (_ownController ??= SplitLayoutController());

  bool get _horizontal => widget.axis == Axis.horizontal;

  /// The platform's minimum target size across the seam.
  double get _hitExtent {
    final minimum = TapTargetSize.minimumFor(defaultTargetPlatform);
    return _horizontal ? minimum.width : minimum.height;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChosen);
  }

  @override
  void didUpdateWidget(SplitLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == oldWidget.controller) return;
    final old = oldWidget.controller ?? _ownController;
    old?.removeListener(_onChosen);
    if (widget.controller != null) {
      _ownController?.dispose();
      _ownController = null;
    } else {
      // The split's own controller starts where the app's left the panes.
      _ownController = SplitLayoutController(fractions: old?.fractions);
    }
    _controller.addListener(_onChosen);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChosen);
    _ownController?.dispose();
    _engine.dispose();
    _dragging.dispose();
    for (final node in _dividerNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panes = widget.panes;
    final mirrored = _mirrored =
        _horizontal && Directionality.of(context) == TextDirection.rtl;
    final hit = _hitExtent;
    final label = widget.dividerLabel ?? builtInLabelsOf(context).dividerLabel;
    final outer = FocusTraversalGroup.maybeOf(context);
    if (_orderPolicy == null || outer != _outerPolicy) {
      _outerPolicy = outer;
      _orderPolicy = OrderedTraversalPolicy(secondary: outer);
    }
    final panePolicy = outer ?? _readingOrder;
    return FocusTraversalGroup(
      policy: _orderPolicy,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final space = _horizontal
              ? constraints.maxWidth
              : constraints.maxHeight;
          assert(
            space.isFinite,
            'SplitLayout needs a bounded extent along its axis.',
          );
          _space = space;
          final target = _resolve(panes, _controller.fractions, space);
          _sync(mirrored ? target.reversed.toList() : target);
          return StackLayout(
            clipBehavior: Clip.none,
            children: [
              MultiSplitViewTheme(
                data: _engineTheme,
                child: MultiSplitView(
                  axis: widget.axis,
                  controller: _engine,
                  resizable: false,
                  areaClipBehavior: Clip.none,
                  builder: (context, area) {
                    final pane = area.id as int;
                    // Each pane is one Tab unit: Tab finishes it before the
                    // divider and the next pane.
                    return FocusTraversalOrder(
                      order: NumericFocusOrder(pane.toDouble()),
                      child: FocusTraversalGroup(
                        policy: panePolicy,
                        child: panes[pane]?.child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
                  dividerBuilder: (axis, index, resizable, dragging, _, _) =>
                      const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _layerChanges,
                  builder: (context, _) => _seams(hit: hit, label: label),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Lays the panes out again for the controller's new fractions.
  void _onChosen() => setState(() {});

  /// Hands the two panes beside divider [divider] to the controller once a
  /// move settles: their entries split the sum they held in the ratio of
  /// their drawn sizes, and every other entry stays as chosen.
  ///
  /// A pair with no prior sum takes the drawn sizes at the scale of the
  /// other chosen panes, so those keep their place.
  void _settle(int divider) {
    final areas = _startAreas();
    final drawn = _drawn();
    final total = drawn.fold(0.0, (sum, size) => sum + size);
    final pair = drawn[divider] + drawn[divider + 1];
    if (total <= 0 || pair <= 0) return;
    final panes = widget.panes;
    final old = _controller.fractions;
    final kept = old != null && old.length == panes.length ? old : null;
    final next = <double?>[for (var i = 0; i < panes.length; i++) kept?[i]];
    final start = areas[divider].pane;
    final end = areas[divider + 1].pane;
    final held = (next[start] ?? 0) + (next[end] ?? 0);
    if (next[start] != null && next[end] != null && held > 0) {
      next[start] = held * drawn[divider] / pair;
      next[end] = held * drawn[divider + 1] / pair;
    } else {
      var weights = 0.0;
      var shares = 0.0;
      for (var k = 0; k < areas.length; k++) {
        final entry = next[areas[k].pane];
        if (k == divider || k == divider + 1 || entry == null) continue;
        weights += entry;
        shares += drawn[k] / total;
      }
      final scale = shares > 0 ? weights / shares : 1.0;
      next[start] = scale * drawn[divider] / total;
      next[end] = scale * drawn[divider + 1] / total;
    }
    _controller.fractions = next;
  }

  /// Divider [index]'s focus node, made on first use.
  FocusNode _dividerNode(int index) {
    while (_dividerNodes.length <= index) {
      _dividerNodes.add(
        FocusNode(debugLabel: 'SplitLayout divider ${_dividerNodes.length}'),
      );
    }
    return _dividerNodes[index];
  }

  /// Hands [target], in screen order, to the engine when it differs from
  /// the areas last handed over and from the areas the engine holds.
  void _sync(List<_PaneArea> target) {
    final pushed = _pushed;
    if (pushed != null && _sameAreas(pushed, target)) return;
    _pushed = target;
    if (_sameAreas(_engineAreas(), target)) return;
    _engine.areas = [
      for (final area in target)
        Area(id: area.pane, flex: area.size, min: area.min, max: area.max),
    ];
  }

  /// The engine's areas, in screen order. Each area's flex is its size in
  /// logical pixels, since the flexes sum to the split's extent.
  List<_PaneArea> _engineAreas() => [
    for (final area in _engine.areas)
      (
        pane: area.id as int,
        size: area.flex ?? 0,
        min: area.min,
        max: area.max,
      ),
  ];

  /// The engine's areas from the start side.
  List<_PaneArea> _startAreas() {
    final areas = _engineAreas();
    return _mirrored ? areas.reversed.toList() : areas;
  }

  /// Each shown pane's drawn size from the start side, in logical pixels.
  List<double> _drawn() {
    final areas = _startAreas();
    final sum = areas.fold(0.0, (total, area) => total + area.size);
    return [
      for (final area in areas)
        if (sum > 0) area.size * _space / sum else 0.0,
    ];
  }

  /// The start pane's size once divider [divider], between panes drawn
  /// [start] and [end], moves [delta] toward the end side, within the
  /// limits the engine holds for both neighbors in [areas].
  double _stepped(
    List<_PaneArea> areas,
    int divider,
    double start,
    double end,
    double delta,
  ) {
    return splitStep(
      start: start,
      end: end,
      delta: delta,
      startMin: areas[divider].min,
      startMax: areas[divider].max,
      endMin: areas[divider + 1].min,
      endMax: areas[divider + 1].max,
    );
  }

  /// Draws the panes beside divider [divider] at [start] and [end]; false
  /// when they already sit there.
  bool _place(int divider, double start, double end) {
    final areas = _startAreas();
    final sizes = _drawn();
    if ((start - sizes[divider]).abs() < _tolerance) return false;
    sizes[divider] = start;
    sizes[divider + 1] = end;
    final placed = [
      for (var k = 0; k < areas.length; k++)
        Area(
          id: areas[k].pane,
          flex: sizes[k],
          min: areas[k].min,
          max: areas[k].max,
        ),
    ];
    _engine.areas = _mirrored ? placed.reversed.toList() : placed;
    return true;
  }

  /// Moves divider [divider] [delta] toward the end side, within both
  /// neighbors' limits, by an arrow key, Home, End, or a slider action,
  /// and settles the move.
  void _move(int divider, double delta) {
    final sizes = _drawn();
    final start = _stepped(
      _startAreas(),
      divider,
      sizes[divider],
      sizes[divider + 1],
      delta,
    );
    final end = sizes[divider] + sizes[divider + 1] - start;
    if (_place(divider, start, end)) _settle(divider);
  }

  /// Starts a drag of divider [divider] with the pointer at [position]
  /// along the axis.
  void _onDragStart(int divider, double position) {
    final sizes = _drawn();
    _dragFrom = (
      origin: position,
      start: sizes[divider],
      end: sizes[divider + 1],
    );
    _dragging.value = divider;
  }

  /// Follows the pointer at [position]: the divider sits where the pointer
  /// moved it from the drag's start, within both neighbors' limits.
  void _onDragUpdate(int divider, double position) {
    final from = _dragFrom;
    if (from == null) return;
    final offset = (position - from.origin) * (_mirrored ? -1 : 1);
    final start = _stepped(
      _startAreas(),
      divider,
      from.start,
      from.end,
      offset,
    );
    _place(divider, start, from.start + from.end - start);
  }

  /// Ends the drag of divider [divider], settling it when it moved.
  void _onDragEnd(int divider) {
    final from = _dragFrom;
    _dragFrom = null;
    _dragging.value = null;
    if (from == null) return;
    if ((_drawn()[divider] - from.start).abs() >= _tolerance) {
      _settle(divider);
    }
  }

  /// Drops a drag the gesture arena gave to a pane before it moved.
  void _onDragCancel() {
    _dragFrom = null;
    _dragging.value = null;
  }

  /// Moves divider [divider] by a key along the axis: an arrow steps by
  /// screen direction, [_largeStep] with Shift held, and Home and End take
  /// the start pane to its minimum and maximum. Every other key passes on.
  KeyEventResult _onKey(int divider, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final step = HardwareKeyboard.instance.isShiftPressed ? _largeStep : _step;
    final key = event.logicalKey;
    final delta = switch (key) {
      LogicalKeyboardKey.arrowRight when _horizontal =>
        _mirrored ? -step : step,
      LogicalKeyboardKey.arrowLeft when _horizontal => _mirrored ? step : -step,
      LogicalKeyboardKey.arrowDown when !_horizontal => step,
      LogicalKeyboardKey.arrowUp when !_horizontal => -step,
      LogicalKeyboardKey.home => double.negativeInfinity,
      LogicalKeyboardKey.end => double.infinity,
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    _move(divider, delta);
    return KeyEventResult.handled;
  }

  /// The hit layer: one seam per divider, [hit] across and centered on it,
  /// over the panes; while a drag runs, a cover that keeps the resize
  /// cursor and holds the panes' hover.
  Widget _seams({required double hit, required String label}) {
    final areas = _engineAreas();
    final count = areas.length;
    final sum = areas.fold(0.0, (total, area) => total + area.size);
    final cursor = _horizontal
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow;
    final children = <Widget>[
      if (_dragging.value != null)
        Positioned.fill(child: MouseRegion(cursor: cursor)),
    ];
    var seam = 0.0;
    for (var index = 0; index < count - 1; index++) {
      seam += sum > 0 ? areas[index].size * _space / sum : 0;
      final divider = _mirrored ? count - 2 - index : index;
      children.add(
        Positioned(
          key: ValueKey(divider),
          left: _horizontal ? seam - hit / 2 : 0,
          top: _horizontal ? 0 : seam - hit / 2,
          right: _horizontal ? null : 0,
          bottom: _horizontal ? 0 : null,
          width: _horizontal ? hit : null,
          height: _horizontal ? null : hit,
          child: widget.resizable
              ? _seam(divider, label: label, cursor: cursor)
              : _Seam(axis: widget.axis, builder: widget.dividerBuilder),
        ),
      );
    }
    return StackLayout(clipBehavior: Clip.none, children: children);
  }

  /// The seam between the shown panes [divider] and `divider + 1`.
  Widget _seam(
    int divider, {
    required String label,
    required MouseCursor cursor,
  }) {
    final areas = _startAreas();
    final sizes = _drawn();
    final total = sizes.fold(0.0, (sum, size) => sum + size);
    String percent(double start) =>
        '${(total > 0 ? start / total * 100 : 0).round()}%';
    double stepped(double delta) =>
        _stepped(areas, divider, sizes[divider], sizes[divider + 1], delta);
    return _Seam(
      axis: widget.axis,
      builder: widget.dividerBuilder,
      dragging: _dragging.value == divider,
      cursor: cursor,
      order: areas[divider].pane + 0.5,
      label: label,
      value: percent(sizes[divider]),
      increasedValue: percent(stepped(_step)),
      decreasedValue: percent(stepped(-_step)),
      onIncrease: () => _move(divider, _step),
      onDecrease: () => _move(divider, -_step),
      focusNode: _dividerNode(divider),
      onKey: (event) => _onKey(divider, event),
      onDragStart: (position) => _onDragStart(divider, position),
      onDragUpdate: (position) => _onDragUpdate(divider, position),
      onDragEnd: () => _onDragEnd(divider),
      onDragCancel: _onDragCancel,
    );
  }
}

/// Whether [a] and [b] hold the same panes in the same order, at sizes
/// within [_tolerance] and with the same limits.
bool _sameAreas(List<_PaneArea> a, List<_PaneArea> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].pane != b[i].pane ||
        (a[i].size - b[i].size).abs() >= _tolerance ||
        a[i].min != b[i].min ||
        a[i].max != b[i].max) {
      return false;
    }
  }
  return true;
}

/// Each shown pane of [panes] as an area of a [space] wide split, in
/// [panes] order: a pane with no chosen entry in [fractions] at its own
/// size or flex, and the panes with one sharing the rest in proportion to
/// their entries.
///
/// A pane's limits loosen to its size where the window leaves no room for
/// them, so the engine draws the size as given.
List<_PaneArea> _resolve(
  List<SplitPane?> panes,
  List<double?>? fractions,
  double space,
) {
  final shown = [
    for (var i = 0; i < panes.length; i++)
      if (panes[i] case final pane?) (index: i, pane: pane),
  ];
  final entries = fractions != null && fractions.length == panes.length
      ? fractions
      : null;
  final sized = shown.fold(0.0, (sum, s) => sum + (s.pane.size ?? 0));
  final flexSum = shown.fold(
    0.0,
    (sum, s) => sum + (s.pane.size == null ? s.pane.flex ?? 1 : 0),
  );
  final flexSpace = math.max(0.0, space - sized);
  final own = [
    for (final s in shown)
      s.pane.size ??
          (flexSum > 0 ? flexSpace * (s.pane.flex ?? 1) / flexSum : 0.0),
  ];
  var unchosen = 0.0;
  var weights = 0.0;
  for (var k = 0; k < shown.length; k++) {
    final entry = entries?[shown[k].index];
    if (entry == null) {
      unchosen += own[k];
    } else {
      weights += entry;
    }
  }
  final room = math.max(0.0, space - unchosen);
  final base = [
    for (var k = 0; k < shown.length; k++)
      if (entries?[shown[k].index] case final entry?)
        if (weights > 0) entry / weights * room else 0.0
      else
        own[k],
  ];
  final sizes = _fit(
    base,
    [for (final s in shown) s.pane.min],
    [for (final s in shown) s.pane.max],
    space,
  );
  return [
    for (var k = 0; k < shown.length; k++)
      (
        pane: shown[k].index,
        size: sizes[k],
        min: shown[k].pane.min == null
            ? null
            : math.min(shown[k].pane.min!, sizes[k]),
        max: shown[k].pane.max == null
            ? null
            : math.max(shown[k].pane.max!, sizes[k]),
      ),
  ];
}

/// [base] resized to sum to [space], each size inside its [min] and [max]
/// while the limits leave room: the gap goes to the sizes not at a limit,
/// in proportion to each size. Limits that cannot all hold give way, and
/// every size scales to fill [space].
List<double> _fit(
  List<double> base,
  List<double?> min,
  List<double?> max,
  double space,
) {
  final count = base.length;
  final lower = [for (final value in min) value ?? 0.0];
  final upper = [for (final value in max) value ?? double.infinity];
  final sizes = <double>[
    for (var i = 0; i < count; i++)
      base[i].clamp(lower[i], math.max(lower[i], upper[i])),
  ];
  for (var round = 0; round <= count; round++) {
    final gap = space - sizes.fold(0.0, (sum, size) => sum + size);
    if (gap.abs() < _tolerance) break;
    final free = [
      for (var i = 0; i < count; i++)
        if (gap > 0 ? sizes[i] < upper[i] : sizes[i] > lower[i]) i,
    ];
    if (free.isEmpty) break;
    final weight = free.fold(0.0, (sum, i) => sum + sizes[i]);
    for (final i in free) {
      final share = weight > 0 ? sizes[i] / weight : 1 / free.length;
      sizes[i] = (sizes[i] + gap * share).clamp(lower[i], upper[i]);
    }
  }
  final total = sizes.fold(0.0, (sum, size) => sum + size);
  if ((space - total).abs() < _tolerance || total <= 0) return sizes;
  return [for (final size in sizes) size * space / total];
}

/// One seam of the hit layer, the split's full length along it, painted
/// by [builder].
///
/// With a [focusNode] it takes the drag through a translucent hit area, so
/// a pane under it still takes a tap, a scroll, or a drag across the
/// split's axis that the gesture arena gives it; it shows [cursor] on
/// hover, is a Tab stop at [order] with the focus ring, and is a slider
/// node. With none (resizing off) it only paints, and takes no pointer.
class _Seam extends StatefulWidget {
  const new({
    required this.axis,
    required this.builder,
    this.dragging = false,
    this.cursor = MouseCursor.defer,
    this.order = 0,
    this.label,
    this.value,
    this.increasedValue,
    this.decreasedValue,
    this.onIncrease,
    this.onDecrease,
    this.focusNode,
    this.onKey,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  /// The split's axis; the seam runs across it.
  final Axis axis;

  final SplitDividerBuilder? builder;

  /// Whether the EndUser drags this seam.
  final bool dragging;

  final MouseCursor cursor;

  /// The seam's place in the split's Tab order, between its two panes.
  final double order;

  /// The slider node's label, value, and step values and actions.
  final String? label;
  final String? value;
  final String? increasedValue;
  final String? decreasedValue;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  final FocusNode? focusNode;

  /// Handles a key while [focusNode] holds focus.
  final KeyEventResult Function(KeyEvent event)? onKey;

  /// The drag's start and each move, with the pointer's global position
  /// along [axis].
  final ValueChanged<double>? onDragStart;
  final ValueChanged<double>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  @override
  State<_Seam> createState() => _SeamState();
}

class _SeamState extends State<_Seam> {
  /// Whether a pointer rests over the seam.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.focusNode;
    if (node == null) return _painted(context, const SplitDividerState());
    final horizontal = widget.axis == Axis.horizontal;
    double along(Offset position) => horizontal ? position.dx : position.dy;
    return MouseRegion(
      cursor: widget.cursor,
      opaque: false,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: horizontal
            ? (details) =>
                  widget.onDragStart?.call(along(details.globalPosition))
            : null,
        onHorizontalDragUpdate: horizontal
            ? (details) =>
                  widget.onDragUpdate?.call(along(details.globalPosition))
            : null,
        onHorizontalDragEnd: horizontal
            ? (_) => widget.onDragEnd?.call()
            : null,
        onHorizontalDragCancel: horizontal ? widget.onDragCancel : null,
        onVerticalDragStart: horizontal
            ? null
            : (details) =>
                  widget.onDragStart?.call(along(details.globalPosition)),
        onVerticalDragUpdate: horizontal
            ? null
            : (details) =>
                  widget.onDragUpdate?.call(along(details.globalPosition)),
        onVerticalDragEnd: horizontal ? null : (_) => widget.onDragEnd?.call(),
        onVerticalDragCancel: horizontal ? null : widget.onDragCancel,
        child: Semantics(
          container: true,
          slider: true,
          label: widget.label,
          value: widget.value,
          increasedValue: widget.increasedValue,
          decreasedValue: widget.decreasedValue,
          onIncrease: widget.onIncrease,
          onDecrease: widget.onDecrease,
          child: FocusTraversalOrder(
            order: NumericFocusOrder(widget.order),
            child: Focus(
              focusNode: node,
              onKeyEvent: (node, event) =>
                  widget.onKey?.call(event) ?? KeyEventResult.ignored,
              child: ListenableBuilder(
                listenable: node,
                builder: (context, _) {
                  final focused = node.hasFocus;
                  return StratumFocusBorder(
                    insideEdge: true,
                    state: focused
                        ? FullWidgetState.focused
                        : FullWidgetState.normal,
                    child: _painted(
                      context,
                      SplitDividerState(
                        hovered: _hovered && !widget.dragging,
                        dragging: widget.dragging,
                        focused: focused,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [_Seam.builder]'s widget for [state], filling the seam; it takes no
  /// pointer and adds no semantics.
  Widget _painted(BuildContext context, SplitDividerState state) {
    final painted = widget.builder?.call(context, state);
    return SizedBox.expand(
      child: painted == null
          ? null
          : IgnorePointer(child: ExcludeSemantics(child: painted)),
    );
  }
}
