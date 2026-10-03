import 'package:flutter/rendering.dart'
    show ItemExtentBuilder, ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy list whose items the user reorders, inside a [WidgetStyle] box.
///
/// Built on the widgets-level [ReorderableList]. Every item that
/// [itemBuilder] returns carries a key. A long press anywhere on an item
/// starts a drag when [longPressDrag] is true, on every platform; a handle
/// that the item wraps in [ReorderableDragStartListener] starts one on
/// pointer down and wins over the long press. [dragStyle] styles the lifted
/// item.
///
/// While a node inside item `i` holds focus, Alt+Up and Alt+Down (Alt+Left
/// and Alt+Right in a horizontal list, by screen direction) call
/// [onReorderItem] with `i - 1` or `i + 1`, and Alt+Home and Alt+End move
/// it to the start and the end; a move past either end does nothing but is
/// still handled, so the key never reaches the browser. On macOS Alt is
/// the Option key. The keys do nothing while focus is inside a text
/// field. A moved item keeps its State and focus, after a key move, a
/// screen reader's move action, or a drop, and is revealed after the move.
/// A pointer path without dragging, such as "Move up" and "Move down" menu
/// entries, is the job of the components built on this layout.
///
/// The box, keyboard scrolling, and Tab stop work as on [ListViewLayout];
/// plain arrows still scroll the list or move focus.
class ReorderableListViewLayout extends StatelessWidget {
  const new builder({
    super.key,
    this.style,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorderItem,
    this.onReorderStart,
    this.onReorderEnd,
    this.dragStyle,
    this.longPressDrag = true,
    this.scrollCacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
    this.focusable,
    this.semanticsLabel,
  });

  final WidgetStyle? style;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final bool shrinkWrap;
  final double? itemExtent;
  final ItemExtentBuilder? itemExtentBuilder;
  final Widget? prototypeItem;
  final int itemCount;

  /// Builds item `index`; every item carries a key.
  final IndexedWidgetBuilder itemBuilder;

  /// Called with the item's old index and the index it ends at, as
  /// Flutter's `onReorderItem` reports it.
  final ReorderCallback onReorderItem;
  final void Function(int index)? onReorderStart;
  final void Function(int index)? onReorderEnd;

  /// The lifted item's style while it is dragged.
  ///
  /// The lifted item starts from `const WidgetStyle()` and animates to
  /// this style with its `animationStyle`, else over 100 ms. Null shows
  /// the item as built.
  final WidgetStyle? dragStyle;

  /// Whether a long press anywhere on an item starts a drag, on every
  /// platform.
  final bool longPressDrag;
  final ScrollCacheExtent? scrollCacheExtent;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final double? autoScrollerVelocityScalar;

  /// Whether the list is a Tab stop that scrolls by keyboard; null means
  /// on web, mobile web included, and on macOS, Windows, and Linux.
  final bool? focusable;

  /// Names the focusable list for a screen reader.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return ScrollViewBox(
      style: style,
      focusable: focusable,
      axis: scrollDirection,
      controller: controller,
      primary: primary,
      semanticsLabel: semanticsLabel,
      showScrollbar: showScrollbar,
      builder: (context, controller, padding) => _ReorderableBody(
        layout: this,
        controller: controller,
        padding: padding,
      ),
    );
  }
}

/// The [ReorderableList], with the per-item wrappers and the reorder keys.
class _ReorderableBody extends StatefulWidget {
  const new({
    required this.layout,
    required this.controller,
    required this.padding,
  });

  final ReorderableListViewLayout layout;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  State<_ReorderableBody> createState() => _ReorderableBodyState();
}

class _ReorderableBodyState extends State<_ReorderableBody> {
  /// The key node of each built item, by index.
  final _itemNodes = <int, FocusNode>{};

  ReorderableListViewLayout get _layout => widget.layout;

  /// Whether primary focus lies inside this list.
  bool get _holdsFocus {
    final primary = FocusManager.instance.primaryFocus;
    return primary?.context?.findAncestorStateOfType<_ReorderableBodyState>() ==
        this;
  }

  void _registerItem(int index, FocusNode node) => _itemNodes[index] = node;

  void _unregisterItem(int index, FocusNode node) {
    if (_itemNodes[index] == node) _itemNodes.remove(index);
  }

  /// The reorder keys of item [index], from the node of its [_ReorderKeys].
  KeyEventResult _handleKey(int index, FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isAltPressed ||
        keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        primaryFocusInEditableText()) {
      return KeyEventResult.ignored;
    }
    final count = _layout.itemCount;
    final item = node.context;
    final position = item == null ? null : Scrollable.maybeOf(item)?.position;
    if (count < 2 || item == null || position == null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final int target;
    if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = count - 1;
    } else {
      final direction = arrowAlong(key, position.axis);
      if (direction == null) return KeyEventResult.ignored;
      // The slot on that side of the screen.
      target = direction == position.axisDirection ? index + 1 : index - 1;
    }
    // A move past either end does nothing, but is handled: the browser
    // never sees the key.
    if (target < 0 || target >= count || target == index) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      _jumpTowards(target, item, position);
    }
    _layout.onReorderItem(index, target);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _afterMove(target, byKey: true),
    );
    return KeyEventResult.handled;
  }

  /// The list's own moves: a drop and a screen reader's move actions. A
  /// move to the first or last slot jumps there first when that slot is
  /// not built, so the moved item keeps its State.
  void _handleReorderItem(int from, int to) {
    final item = _itemNodes[from]?.context;
    final position = item == null ? null : Scrollable.maybeOf(item)?.position;
    final edge = to == 0 || to == _layout.itemCount - 1;
    if (item != null &&
        position != null &&
        edge &&
        !_itemNodes.containsKey(to)) {
      _jumpTowards(to, item, position);
    }
    _layout.onReorderItem(from, to);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _afterMove(to, byKey: false),
    );
  }

  /// Jumps to the start for a move to slot 0, else to the end. The target
  /// slot may not be built; the move needs it built in the frame that
  /// moves the item.
  void _jumpTowards(int target, BuildContext item, ScrollPosition position) {
    if (target == 0) {
      position.jumpTo(position.minScrollExtent);
    } else {
      jumpToEnd(
        position,
        attached: () =>
            mounted &&
            item.mounted &&
            Scrollable.maybeOf(item)?.position == position,
      );
    }
  }

  /// Reveals the item at [target] after a move, by the edge of each
  /// viewport around it ([revealInViewports]). After a key move, when
  /// focus has left the list, it moves to that item's first node in Tab
  /// order.
  void _afterMove(int target, {required bool byKey}) {
    if (!mounted) return;
    final node = _itemNodes[target];
    if (node == null || node.context == null) return;
    if (byKey && !_holdsFocus) firstTabStopIn(node)?.requestFocus();
    revealInViewports(node);
  }

  Widget _proxy(Widget child, int index, Animation<double> animation) {
    return _LiftedItem(style: _layout.dragStyle!, child: child);
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _layout.itemBuilder(context, index);
    final key = item.key;
    assert(key != null, 'Every item of ReorderableListViewLayout needs a key');
    var current = item;
    if (_layout.longPressDrag) {
      current = ReorderableDelayedDragStartListener(
        index: index,
        child: current,
      );
    }
    // The global key holds the item's key and this State, never the index,
    // so a moved item keeps its State and focus, as in Material's
    // ReorderableListView.
    return KeyedSubtree(
      key: _ReorderItemKey(key!, this),
      child: _ReorderKeys(index: index, body: this, child: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    return ReorderableList(
      itemBuilder: _buildItem,
      itemCount: layout.itemCount,
      onReorderItem: _handleReorderItem,
      onReorderStart: layout.onReorderStart,
      onReorderEnd: layout.onReorderEnd,
      itemExtent: layout.itemExtent,
      itemExtentBuilder: layout.itemExtentBuilder,
      prototypeItem: layout.prototypeItem,
      proxyDecorator: layout.dragStyle == null ? null : _proxy,
      padding: widget.padding,
      scrollDirection: layout.scrollDirection,
      reverse: layout.reverse,
      controller: widget.controller,
      primary: layout.primary,
      physics: layout.physics,
      shrinkWrap: layout.shrinkWrap,
      scrollCacheExtent: layout.scrollCacheExtent,
      dragStartBehavior: layout.dragStartBehavior,
      keyboardDismissBehavior: layout.keyboardDismissBehavior,
      restorationId: layout.restorationId,
      clipBehavior: layout.clipBehavior,
      autoScrollerVelocityScalar: layout.autoScrollerVelocityScalar,
    );
  }
}

/// The global key of an item: its own key and the list's State, equal by
/// both, never by the index.
@optionalTypeArgs
class _ReorderItemKey extends GlobalObjectKey {
  const new(this.subKey, this.state) : super(subKey);

  final Key subKey;
  final State state;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _ReorderItemKey &&
        other.subKey == subKey &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(subKey, state);
}

/// The reorder keys of item [index]: a node that takes no focus and hears
/// keys bubbling up from any node inside the item.
class _ReorderKeys extends StatefulWidget {
  const new({required this.index, required this.body, required this.child});

  final int index;
  final _ReorderableBodyState body;
  final Widget child;

  @override
  State<_ReorderKeys> createState() => _ReorderKeysState();
}

class _ReorderKeysState extends State<_ReorderKeys> {
  final _node = FocusNode(
    debugLabel: 'ReorderableListViewLayout item',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    widget.body._registerItem(widget.index, _node);
  }

  @override
  void didUpdateWidget(_ReorderKeys oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index && oldWidget.body == widget.body) {
      return;
    }
    oldWidget.body._unregisterItem(oldWidget.index, _node);
    widget.body._registerItem(widget.index, _node);
  }

  @override
  void dispose() {
    widget.body._unregisterItem(widget.index, _node);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      includeSemantics: false,
      onKeyEvent: (node, event) =>
          widget.body._handleKey(widget.index, node, event),
      child: widget.child,
    );
  }
}

/// The lifted item: starts from `const WidgetStyle()` and switches to
/// [style] on its first frame, so [AnimatedStyledBox] animates the lift.
class _LiftedItem extends StatefulWidget {
  const new({required this.style, required this.child});

  final WidgetStyle style;
  final Widget child;

  @override
  State<_LiftedItem> createState() => _LiftedItemState();
}

class _LiftedItemState extends State<_LiftedItem> {
  /// The lift's duration when [_LiftedItem.style] sets none: the
  /// interaction default of the layouts.
  static const _defaultAnimation = AnimationStyle(
    duration: Duration(milliseconds: 100),
  );

  var _lifted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lifted = true);
    });
  }

  WidgetStyle get _liftStyle {
    final style = widget.style;
    if (style.animationStyle != null) return style;
    return style.copyWith(animationStyle: _defaultAnimation);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedStyledBox(
      style: _lifted ? _liftStyle : const WidgetStyle(),
      child: widget.child,
    );
  }
}
