import 'package:stratum_ui/src/src.dart';

/// Makes the focusable children of a [ColumnLayout], [RowLayout], or
/// [WrapLayout] one roving Tab stop (K3).
///
/// * Tab enters the group once and lands on the item that last held focus,
///   or on the first item; Tab and Shift+Tab then leave it (WCAG 2.1.2).
/// * Arrows along the layout axis move to the next item on screen in the
///   pressed direction: Left and Right in a row, Up and Down in a column,
///   also under right-to-left text and [VerticalDirection.up]. In a wrap,
///   Left and Right move in reading order, and Up and Down move to the
///   nearest item of the adjacent run.
/// * Arrows across the axis keep Flutter's default.
/// * Home and End move to the first and last item in reading order.
/// * With [loop], moving past either end wraps around, including a wrap's
///   Up and Down past its first or last run. Without it, an arrow past
///   either end is swallowed when another item in the group still lies in
///   that direction on screen, so focus does not bounce to it; otherwise
///   it keeps Flutter's default: directional focus on desktop, scrolling
///   on web.
///
/// The group binds its own keys, so they work the same on web, and skips
/// them while focus is inside a text field. It covers built children only;
/// a lazy list uses Tab and its own keyboard scrolling instead.
@immutable
class StratumFocusGroup {
  const new({this.role, this.loop = false});

  /// The semantics role of the group node.
  ///
  /// Flutter's debug checks constrain the items, which take their role
  /// through their own `semantics:` (`SemanticsProperties(role: ...)`):
  /// `tabBar` needs at least one item and every item with role `tab`;
  /// `menu` and `menuBar` need at least one item, and a `menuItem` must sit
  /// under one of them; `radioGroup` allows at most one checked item;
  /// `list` has no check. Set `menu`, `menuBar`, or `tabBar` only when
  /// items exist.
  final SemanticsRole? role;

  /// Whether arrows wrap from the last item to the first and back.
  final bool loop;
}

/// How a [FocusGroupFrame] lays its items out on screen.
enum FocusGroupAxis { vertical, horizontal, wrap }

/// Builds a [StratumFocusGroup] around a layout's content.
///
/// Not exported: [ColumnLayout], [RowLayout], and [WrapLayout] build it
/// from their `focusGroup`.
class FocusGroupFrame extends StatefulWidget {
  const new({
    super.key,
    required this.group,
    required this.axis,
    this.textDirection,
    required this.child,
  });

  final StratumFocusGroup group;
  final FocusGroupAxis axis;

  /// The layout's own text direction; null reads the ambient
  /// [Directionality].
  final TextDirection? textDirection;
  final Widget child;

  @override
  State<FocusGroupFrame> createState() => _FocusGroupFrameState();
}

class _FocusGroupFrameState extends State<FocusGroupFrame> {
  /// The node inside the group that last held primary focus.
  FocusNode? _last;
  late final _policy = _FocusGroupPolicy(() => _last);
  final _keys = FocusNode(
    debugLabel: 'StratumFocusGroup',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_trackFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_trackFocus);
    _keys.dispose();
    super.dispose();
  }

  /// Remembers the node inside the group that last held primary focus.
  void _trackFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.ancestors.contains(_keys)) {
      _last = primary;
    }
  }

  bool get _rtl {
    final direction =
        widget.textDirection ??
        Directionality.maybeOf(context) ??
        TextDirection.ltr;
    return direction == TextDirection.rtl;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        primaryFocusInEditableText()) {
      return KeyEventResult.ignored;
    }
    final items = [
      for (final item in node.traversalDescendants)
        if (item.context != null) item,
    ];
    final current = _current(items);
    if (current == null) return KeyEventResult.ignored;
    final reading = _readingOrder(items, rtl: _rtl);
    final target = _target(event.logicalKey, current, items, reading);
    if (target == null) return KeyEventResult.ignored;
    if (target != current) {
      final forward = reading.indexOf(target) > reading.indexOf(current);
      target.requestFocus();
      final scope = node.nearestScope;
      if (scope != null) _policy.invalidateScopeData(scope);
      Scrollable.ensureVisible(
        target.context!,
        alignmentPolicy: forward
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
    return KeyEventResult.handled;
  }

  /// The item that holds primary focus or contains it.
  static FocusNode? _current(List<FocusNode> items) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return null;
    if (items.contains(primary)) return primary;
    for (final item in items) {
      if (item.hasFocus) return item;
    }
    return null;
  }

  /// The item [key] moves to, [current] when the key is handled without a
  /// move, or null when the group leaves [key] to Flutter.
  FocusNode? _target(
    LogicalKeyboardKey key,
    FocusNode current,
    List<FocusNode> items,
    List<FocusNode> reading,
  ) {
    if (key == LogicalKeyboardKey.home) return reading.first;
    if (key == LogicalKeyboardKey.end) return reading.last;
    final loop = widget.group.loop;
    switch (widget.axis) {
      case FocusGroupAxis.vertical:
        final step = _step(
          key,
          forward: LogicalKeyboardKey.arrowDown,
          back: LogicalKeyboardKey.arrowUp,
        );
        if (step == 0) return null;
        final direction = step > 0
            ? TraversalDirection.down
            : TraversalDirection.up;
        return _move(_onScreen(items, Axis.vertical), current, step, loop) ??
            _edge(items, current, direction);
      case FocusGroupAxis.horizontal:
        final step = _step(
          key,
          forward: LogicalKeyboardKey.arrowRight,
          back: LogicalKeyboardKey.arrowLeft,
        );
        if (step == 0) return null;
        final direction = step > 0
            ? TraversalDirection.right
            : TraversalDirection.left;
        return _move(_onScreen(items, Axis.horizontal), current, step, loop) ??
            _edge(items, current, direction);
      case FocusGroupAxis.wrap:
        final across = _step(
          key,
          forward: LogicalKeyboardKey.arrowRight,
          back: LogicalKeyboardKey.arrowLeft,
        );
        if (across != 0) {
          final direction = across > 0
              ? TraversalDirection.right
              : TraversalDirection.left;
          return _move(reading, current, _rtl ? -across : across, loop) ??
              _edge(items, current, direction);
        }
        final down = _step(
          key,
          forward: LogicalKeyboardKey.arrowDown,
          back: LogicalKeyboardKey.arrowUp,
        );
        if (down == 0) return null;
        final direction = down > 0
            ? TraversalDirection.down
            : TraversalDirection.up;
        return _adjacentRun(items, current, down, loop) ??
            _edge(items, current, direction);
    }
  }

  /// [current] again when another item in [items] lies in [direction] on
  /// screen, by the same filter Flutter's own directional traversal applies
  /// before it picks an out-of-band target
  /// (`widgets/focus_traversal.dart:1062-1116`); otherwise null, leaving
  /// [direction]'s key to Flutter.
  static FocusNode? _edge(
    List<FocusNode> items,
    FocusNode current,
    TraversalDirection direction,
  ) {
    final target = current.rect;
    bool inDirection(FocusNode node) {
      if (node == current) return false;
      final center = node.rect.center;
      return switch (direction) {
        TraversalDirection.left => center.dx <= target.left,
        TraversalDirection.right => center.dx >= target.right,
        TraversalDirection.up => center.dy <= target.top,
        TraversalDirection.down => center.dy >= target.bottom,
      };
    }

    return items.any(inDirection) ? current : null;
  }

  static int _step(
    LogicalKeyboardKey key, {
    required LogicalKeyboardKey forward,
    required LogicalKeyboardKey back,
  }) {
    if (key == forward) return 1;
    if (key == back) return -1;
    return 0;
  }

  /// The item [step] places after [current] in [order]; past either end it
  /// wraps with [loop] and is otherwise null, leaving the key to Flutter.
  static FocusNode? _move(
    List<FocusNode> order,
    FocusNode current,
    int step,
    bool loop,
  ) {
    final next = order.indexOf(current) + step;
    if (next >= 0 && next < order.length) return order[next];
    if (!loop) return null;
    return order[next < 0 ? order.length - 1 : 0];
  }

  /// [items] by the center of their rect along [axis], left to right or
  /// top to bottom.
  static List<FocusNode> _onScreen(List<FocusNode> items, Axis axis) {
    double center(FocusNode node) =>
        axis == Axis.horizontal ? node.rect.center.dx : node.rect.center.dy;
    return [...items]..sort((a, b) => center(a).compareTo(center(b)));
  }

  /// [items] grouped into runs: items whose rects overlap vertically.
  static List<List<FocusNode>> _runs(List<FocusNode> items) {
    final sorted = [...items]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    final runs = <List<FocusNode>>[];
    var bottom = double.negativeInfinity;
    for (final item in sorted) {
      if (runs.isEmpty || item.rect.top >= bottom) {
        runs.add([item]);
        bottom = item.rect.bottom;
      } else {
        runs.last.add(item);
        if (item.rect.bottom > bottom) bottom = item.rect.bottom;
      }
    }
    return runs;
  }

  /// [items] in reading order: runs from top to bottom, each from left to
  /// right, or from right to left under [rtl].
  static List<FocusNode> _readingOrder(
    List<FocusNode> items, {
    required bool rtl,
  }) {
    final order = <FocusNode>[];
    for (final run in _runs(items)) {
      final row = _onScreen(run, Axis.horizontal);
      order.addAll(rtl ? row.reversed : row);
    }
    return order;
  }

  /// The item of the run below ([down] 1) or above ([down] -1) the run of
  /// [current] whose center is nearest to [current]'s; past either end it
  /// wraps to the nearest item of the opposite run with [loop] and is
  /// otherwise null, leaving the key to Flutter.
  static FocusNode? _adjacentRun(
    List<FocusNode> items,
    FocusNode current,
    int down,
    bool loop,
  ) {
    final runs = _runs(items);
    final index = runs.indexWhere((run) => run.contains(current));
    if (index < 0) return null;
    var next = index + down;
    if (next < 0 || next >= runs.length) {
      if (!loop) return null;
      next = next < 0 ? runs.length - 1 : 0;
    }
    final x = current.rect.center.dx;
    return runs[next].reduce(
      (a, b) =>
          (a.rect.center.dx - x).abs() <= (b.rect.center.dx - x).abs() ? a : b,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget result = FocusTraversalGroup(
      policy: _policy,
      child: Focus(
        focusNode: _keys,
        includeSemantics: false,
        onKeyEvent: _handleKey,
        child: widget.child,
      ),
    );
    final role = widget.group.role;
    if (role != null) {
      result = Semantics(container: true, role: role, child: result);
    }
    return result;
  }
}

/// Sorts a group's members down to one: the member that holds the current
/// node, else the one that last held focus, else the first in reading
/// order. Tab then enters the group once and leaves it from any item.
class _FocusGroupPolicy extends ReadingOrderTraversalPolicy {
  new(this.lastFocused);

  /// The node inside the group that last held primary focus.
  final ValueGetter<FocusNode?> lastFocused;

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final members = descendants.toList();
    if (members.isEmpty) return members;
    FocusNode? holding(FocusNode? node) {
      if (node == null) return null;
      for (final member in members) {
        if (member == node || node.ancestors.contains(member)) return member;
      }
      return null;
    }

    final entry =
        holding(currentNode) ??
        holding(lastFocused()) ??
        super.sortDescendants(members, currentNode).first;
    return [entry];
  }
}
