import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:stratum_ui/src/src.dart';

/// Makes the focusable children of a [ColumnLayout], [RowLayout], or
/// [WrapLayout] one roving Tab stop (K3).
///
/// * Tab enters the group once and lands on the item that last held focus,
///   or on the first item; Tab and Shift+Tab then leave it (WCAG 2.1.2).
///   From a node inside an item, such as an item of a focusable scroller,
///   they first move among that item and the nodes inside it.
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
/// Not exported: [FlexLayout], and so [ColumnLayout] and [RowLayout], and
/// [WrapLayout] build it from their `focusGroup`.
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
      target.requestFocus();
      final scope = node.nearestScope;
      if (scope != null) _policy.invalidateScopeData(scope);
      revealInViewports(target);
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
///
/// When the current node lies inside a member, such as an item in a
/// focusable scroller, the member keeps the members inside it, after it
/// in reading order, so Tab moves among them before it leaves the group.
///
/// Tab, Shift+Tab, and Flutter's arrows from an item reveal the newly
/// focused node by [requestFocusInViewports].
class _FocusGroupPolicy extends ReadingOrderTraversalPolicy {
  new(this.lastFocused) : super(requestFocusCallback: requestFocusInViewports);

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

    final holder = holding(currentNode);
    if (holder != null && holder != currentNode) {
      final inside = [
        for (final member in members)
          if (member.ancestors.contains(holder)) member,
      ];
      return [holder, ...super.sortDescendants(inside, currentNode)];
    }
    final entry =
        holder ??
        holding(lastFocused()) ??
        super.sortDescendants(members, currentNode).first;
    return [entry];
  }
}

/// The first node inside [container] in Tab order, scrolled into view;
/// null when no node inside can take focus.
///
/// Sorts each traversal group inside by its own policy, as Tab does, so a
/// focusable scroll view's Tab stop precedes its items. Layouts that
/// switch their content focus this node after the switch.
FocusNode? firstTabStopIn(FocusNode container) {
  final first = _tabOrder.first(container);
  if (first == null) return null;
  revealInViewports(first);
  return first;
}

/// Focuses [node] and reveals it by [revealInViewports]: the
/// `requestFocusCallback` of stratum's traversal policies, in place of
/// Flutter's one-policy reveal.
void requestFocusInViewports(
  FocusNode node, {
  ScrollPositionAlignmentPolicy? alignmentPolicy,
  double? alignment,
  Duration? duration,
  Curve? curve,
}) {
  node.requestFocus();
  revealInViewports(node);
}

/// Scrolls each viewport around [target], from the nearest outwards, by
/// that viewport's own edge, so [target] shows whole with the least
/// scroll: a viewport whose start [target] lies before reveals it at the
/// start, one whose end it extends past reveals it at the end, and one
/// that holds it whole stays put. [ScrollPosition.ensureVisible] flips
/// start and end for a reversed axis, so right-to-left text and `reverse`
/// never decide it. A nested scroll view's body moves along the header's
/// range first ([moveNested]), so the header collapses only as far as
/// [target] needs.
///
/// [Scrollable.ensureVisible] applies one policy at every level, and
/// `keepVisibleAtEnd` never scrolls a viewport back, so a row that
/// scrolls to its end inside a page whose top the row extends past would
/// stay cut off. The group arrows, [firstTabStopIn], and the traversal of
/// a focus group or a scroller's content group reveal through this.
void revealInViewports(FocusNode target) {
  final context = target.context;
  final object = context?.findRenderObject();
  if (context == null || object == null || !object.attached) return;
  // What each level scrolls into view: the target, then the viewport that
  // holds it, as Scrollable.ensureVisible walks the chain.
  RenderObject? shown = object;
  for (
    var scrollable = Scrollable.maybeOf(context);
    scrollable != null && shown != null;
    scrollable = Scrollable.maybeOf(scrollable.context)
  ) {
    final position = scrollable.position;
    final overhang = _overhang(target.rect, scrollable);
    final nested = _nestedBodyOf(scrollable);
    if (nested != null) {
      // The body moves along the header's range first, as its keys do. The
      // overhang is on screen; a reversed axis scrolls the other way.
      final reversed = axisDirectionIsReversed(position.axisDirection);
      final delta = reversed ? -overhang : overhang;
      final header = nested.outerController.position;
      if (delta != 0) moveNested(header, position, delta, Duration.zero);
    } else if (overhang != 0) {
      // A two-dimensional view's vertical scrollable reveals the target
      // itself, as Flutter's horizontal one does for both axes.
      final reveal = _inViewportOf(shown, scrollable) ? shown : object;
      position.ensureVisible(
        reveal,
        alignmentPolicy: overhang < 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        targetRenderObject: reveal == object ? null : object,
      );
    }
    shown = scrollable.context.findRenderObject();
  }
}

/// The nested scroll view whose inner controller holds [scrollable]'s
/// position, so the header and the body scroll as one range; else null.
NestedScrollViewState? _nestedBodyOf(ScrollableState scrollable) {
  final nested = scrollable.context
      .findAncestorStateOfType<NestedScrollViewState>();
  if (nested == null ||
      !nested.innerController.positions.contains(scrollable.position)) {
    return null;
  }
  return nested;
}

/// Moves a nested scroll view by [delta] along one range: [outer]'s
/// extent, over which the header collapses, then [inner]'s, the body's.
///
/// Moving [inner] by its own offset would collapse the header at once,
/// because the coordinator maps every inner offset to a collapsed header.
/// A target within the header's extent moves [outer], and the coordinator
/// returns the body to its start; a target past it moves [inner], and the
/// coordinator holds the header collapsed. The move takes [duration];
/// zero jumps. `ScrollFocus`'s keys and [revealInViewports] share it.
void moveNested(
  ScrollPosition outer,
  ScrollPosition inner,
  double delta,
  Duration duration,
) {
  final header = outer.maxScrollExtent - outer.minScrollExtent;
  final scrolled = inner.pixels - inner.minScrollExtent;
  final offset =
      outer.pixels - outer.minScrollExtent + (scrolled > 0 ? scrolled : 0);
  final end = header + inner.maxScrollExtent - inner.minScrollExtent;
  final target = clampDouble(offset + delta, 0, end);
  if (target <= header) {
    outer.moveTo(
      outer.minScrollExtent + target,
      duration: duration,
      curve: Curves.easeInOutSine,
    );
  } else {
    inner.moveTo(
      inner.minScrollExtent + target - header,
      duration: duration,
      curve: Curves.easeInOutSine,
    );
  }
}

/// Whether [object]'s nearest viewport lies below [scrollable].
///
/// False for the vertical scrollable of a two-dimensional view: its one
/// viewport lies below the horizontal scrollable, which sits inside the
/// vertical one, so the horizontal scrollable's render object is outside
/// that viewport.
bool _inViewportOf(RenderObject object, ScrollableState scrollable) {
  final top = scrollable.context.findRenderObject();
  for (
    RenderObject? node = RenderAbstractViewport.maybeOf(object);
    node != null;
    node = node.parent
  ) {
    if (node == top) return true;
  }
  return false;
}

/// How far [rect], a rect on screen, lies outside [scrollable]'s viewport
/// along its axis: negative by how far it starts before the viewport,
/// positive by how far it extends past it, and zero when the viewport
/// holds it whole.
double _overhang(Rect rect, ScrollableState scrollable) {
  final box = scrollable.context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return 0;
  final viewport = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  final horizontal = scrollable.position.axis == Axis.horizontal;
  final before = horizontal
      ? rect.left - viewport.left
      : rect.top - viewport.top;
  if (before < 0) return before;
  final past = horizontal
      ? rect.right - viewport.right
      : rect.bottom - viewport.bottom;
  return past > 0 ? past : 0;
}

/// Whether [node] is the node of a [FocusTraversalGroup], whose members are
/// the traversable nodes below it. Flutter's type for that node is
/// private, so this reads the widget that built the node's [Focus].
bool _isTraversalGroup(FocusNode node) {
  var group = false;
  node.context?.visitAncestorElements((element) {
    group = element.widget is FocusTraversalGroup;
    return false;
  });
  return group;
}

final _tabOrder = _TabOrder();

/// Tab order inside one node, as Flutter's traversal sorts a scope, and
/// the one place that asks other policies to sort:
/// [FocusTraversalPolicy.sortDescendants] is protected.
class _TabOrder extends ReadingOrderTraversalPolicy {
  /// The first node inside [container] in Tab order; null when none can
  /// take focus.
  FocusNode? first(FocusNode container) {
    // The members of each group by the group's node, in tree order, which
    // breaks ties in reading order; the null key holds the group around
    // [container]. A nested group is a member of the group around it.
    final members = <FocusNode?, List<FocusNode>>{null: []};
    void collect(FocusNode node, FocusNode? group) {
      for (final child in node.children) {
        final nested = _isTraversalGroup(child);
        if (nested) {
          members[group]!.add(child);
          members[child] = [];
        } else if (child.context != null &&
            child.canRequestFocus &&
            !child.skipTraversal) {
          members[group]!.add(child);
        }
        // Flutter's traversal sorts a nested scope's nodes on its own.
        if (child is! FocusScopeNode) collect(child, nested ? child : group);
      }
    }

    FocusNode? firstOf(FocusNode? group) {
      final candidates = members[group]!;
      if (candidates.isEmpty) return null;
      final policy = FocusTraversalGroup.maybeOfNode(group ?? container);
      for (final node in (policy ?? this).sortDescendants(
        candidates,
        container,
      )) {
        final first = members.containsKey(node) ? firstOf(node) : node;
        if (first != null) return first;
      }
      return null;
    }

    collect(container, null);
    return firstOf(null);
  }
}
