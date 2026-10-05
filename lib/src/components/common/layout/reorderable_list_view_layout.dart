import 'package:flutter/rendering.dart'
    show ItemExtentBuilder, ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/components/common/style/reduced_motion.dart';
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
///
/// With an [itemsController], an item the app inserts into its data grows
/// along the main axis and fades in, and an item it removes shrinks and
/// fades out, over the theme's `normal` level on its `standard` curve. A
/// removed item keeps the look it had and is drawn in the slot of its
/// neighbor while it leaves, so every index the list reports is an index
/// of the app's data. Under reduced motion or a fixed item extent the size
/// changes at once and only the fade plays, a removed item fading over the
/// item that takes its place; under a fixed extent a removed last item
/// leaves at once. A leaving item takes no tap, drag, reorder key, or
/// focus, and focus inside it moves to the next item, else the one before,
/// else the list's own Tab stop when the list is focusable, unless the app
/// moves focus itself in the same turn. A reorder of the item a leaving
/// item is drawn beside ends that leaving item at once.
/// [itemTransitionBuilder] replaces the built-in transition.
///
/// An insert or remove during a drag, through [itemsController] or not,
/// ends the drag first: the dragged item goes back to its slot,
/// [onReorderEnd] reports the index the drag started at, and
/// [onReorderItem] does not fire. A drag that starts between an
/// `insertItem` or `removeItem` call and the next frame ends the same way
/// at once.
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
    this.itemsController,
    this.itemTransitionBuilder,
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
  /// this style with its `animationStyle`, else over the theme's `fast`
  /// level. Null shows the item as built.
  final WidgetStyle? dragStyle;

  /// Whether a long press anywhere on an item starts a drag, on every
  /// platform.
  final bool longPressDrag;

  /// Animates the items the app inserts into or removes from its data;
  /// separate from the scroll [controller]. Null shows every data change
  /// at once. One controller drives one list at a time: hand it to
  /// another list only after this one drops it, or in a later frame.
  final StratumReorderableItemsController? itemsController;

  /// Replaces the built-in grow-or-shrink and fade of an inserted or
  /// removed item, for both directions.
  ///
  /// `animation` runs from 0 to 1 on insert and from 1 to 0 on remove,
  /// over the theme's `normal` level on its `standard` curve. Reduced
  /// motion leaves it unchanged: the builder makes its own reduced-motion
  /// choice. Under a fixed item extent a removed item still takes no room.
  /// `child` is the item.
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  )?
  itemTransitionBuilder;
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

/// Animates the items an app inserts into or removes from a
/// [ReorderableListViewLayout], passed as its `itemsController`.
///
/// Call [insertItem] or [removeItem] in the same turn as the matching
/// change to the app's own data, outside a build and outside the list's
/// reorder callbacks; from those, call after the frame. Indices are data
/// indices: an item still growing in counts, and an item playing its
/// remove animation does not. One controller drives one list at a time;
/// it holds no resource, so it needs no `dispose`.
class StratumReorderableItemsController {
  _ReorderableBodyState? _body;

  /// Grows and fades in the item the app inserted at [index] of its data,
  /// over the theme's `normal` level.
  ///
  /// [index] runs from 0 to the item count before the insert.
  void insertItem(int index) {
    assert(
      _body != null,
      'insertItem on a StratumReorderableItemsController attached to no '
      'ReorderableListViewLayout',
    );
    _body?._insertItem(index);
  }

  /// Shrinks and fades out the item the app removed from [index] of its
  /// data, over the `normal` level's reverse duration.
  ///
  /// Without [builder], the leaving item keeps the look and State it had at
  /// this call, and ends at once if its key comes back. It still rebuilds
  /// when an inherited value it reads changes, so an item that reads its
  /// data through `context` needs a [builder] that captures that data.
  /// [builder] replaces the look, never the transition.
  void removeItem(int index, {WidgetBuilder? builder}) {
    assert(
      _body != null,
      'removeItem on a StratumReorderableItemsController attached to no '
      'ReorderableListViewLayout',
    );
    _body?._removeItem(index, builder);
  }

  void _attach(_ReorderableBodyState body) {
    assert(
      _body == null || _body == body,
      'One StratumReorderableItemsController is attached to two '
      'ReorderableListViewLayouts at once',
    );
    _body = body;
  }

  void _detach(_ReorderableBodyState body) {
    if (_body == body) _body = null;
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

class _ReorderableBodyState extends State<_ReorderableBody>
    with TickerProviderStateMixin {
  /// The key node of each built item, by index.
  final _itemNodes = <int, FocusNode>{};

  /// The widget [ReorderableListViewLayout.itemBuilder] last built for each
  /// built item, by index: the look a removed item keeps (E03).
  final _itemLooks = <int, Widget>{};

  /// The theme's motion, read in [build]: the drag proxy mounts outside
  /// the themed subtree (spec section 9), so [_proxy] cannot read it from
  /// its own context, and `insertItem` and `removeItem` run outside a
  /// build.
  StratumAnimation _motion = StratumAnimation.packageDefault;

  /// The item count of the app's data: the count of the last build, moved
  /// by each `insertItem` and `removeItem` since.
  late int _dataCount;

  /// The `insertItem` and `removeItem` calls since the last build, in call
  /// order: they map an index of the app's current data to the index the
  /// item had at that build.
  final _pending = <({bool insert, int index})>[];

  /// The inserts since the last build, each at its index in the current
  /// data; the next build reads the inserted item's key.
  final _pendingInserts = <_PendingInsert>[];

  /// The inserted items still growing in, by item key.
  final _incoming = <Key, _ItemMotion>{};

  /// The removed items still shrinking out, in the list's order.
  final _exits = <_Exit>[];

  /// Where a removed item that held primary focus left, as an index of the
  /// current data, until the frame after the call hands focus on (E04).
  int? _handoffGap;

  /// The index the drag in progress started at, from `onReorderStart` to
  /// `onReorderEnd`; null with no drag.
  ///
  /// The SDK ends a drag without `onReorderEnd` on a canceled gesture and
  /// on a change of the item count it is given: the last pointer up clears
  /// it, and that change reports the end ([_reportCountEnd]).
  int? _dragIndex;

  /// The item count the last build gave [ReorderableList].
  int? _listCount;

  /// Whether `onReorderStart` is running: the SDK sets the drag up only
  /// after it returns, so a cancel waits for a microtask.
  var _inReorderStart = false;

  /// The key of the item whose State the drag proxy holds, from the frame
  /// the proxy takes the item until the frame it lets the item go.
  Key? _liftedKey;

  /// The lifted item whose slot keeps the drag's gap, from the build that
  /// ends its drag until the proxy lets it go.
  ///
  /// The SDK ends a drag inside the build that changes the item count, and
  /// the overlay drops the proxy only after that frame: the item's global
  /// keys would sit in the proxy and in the slot at once.
  Key? _standInKey;

  /// The size of the item the drag in progress lifted: the gap's size.
  Size? _liftedSize;

  /// The pointers down on the list; a drag needs one.
  var _pointersDown = 0;

  /// Reaches [ReorderableListState.cancelReorder].
  final _listKey = GlobalKey<ReorderableListState>();

  ReorderableListViewLayout get _layout => widget.layout;

  /// Whether primary focus lies inside this list.
  bool get _holdsFocus {
    final primary = FocusManager.instance.primaryFocus;
    return primary?.context?.findAncestorStateOfType<_ReorderableBodyState>() ==
        this;
  }

  @override
  void initState() {
    super.initState();
    _dataCount = _layout.itemCount;
    _layout.itemsController?._attach(this);
  }

  @override
  void didUpdateWidget(_ReorderableBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.layout.itemsController;
    final current = _layout.itemsController;
    if (old == current) return;
    old?._detach(this);
    current?._attach(this);
  }

  // The controller follows this State in and out of the tree, so a list
  // that a parent rebuilds in place detaches before its successor
  // attaches (D8's two-lists assert).
  @override
  void activate() {
    super.activate();
    _layout.itemsController?._attach(this);
  }

  @override
  void deactivate() {
    _layout.itemsController?._detach(this);
    super.deactivate();
  }

  @override
  void dispose() {
    _layout.itemsController?._detach(this);
    _resetMotion();
    super.dispose();
  }

  /// [StratumReorderableItemsController.insertItem]: the app inserted an
  /// item at [index] of its data in this turn.
  void _insertItem(int index) {
    assert(
      index >= 0 && index <= _dataCount,
      'insertItem($index) is out of range: the data holds $_dataCount '
      'items',
    );
    if (index < 0 || index > _dataCount) return;
    _cancelDrag();
    _shiftForInsert(index);
    _pending.add((insert: true, index: index));
    _dataCount += 1;
    final motion = _newMotion(value: 0);
    _pendingInserts.add(_PendingInsert(index, motion));
    unawaited(
      motion.controller.forward().then<void>((_) => _finishInsert(motion)),
    );
    setState(() {});
  }

  /// [StratumReorderableItemsController.removeItem]: the app removed the
  /// item at [index] of its data in this turn.
  void _removeItem(int index, WidgetBuilder? builder) {
    assert(
      index >= 0 && index < _dataCount,
      'removeItem($index) is out of range: the data holds $_dataCount '
      'items',
    );
    if (index < 0 || index >= _dataCount) return;
    _cancelDrag();
    final built = _builtIndexOf(index);
    final node = built == null ? null : _itemNodes[built];
    final look = built == null ? null : _itemLooks[built];
    final focused = node?.hasFocus ?? false;
    final around = _takeExitsAround(index, look?.key);
    _shiftForRemove(index);
    _pending.add((insert: false, index: index));
    _dataCount -= 1;
    if (focused && _handoffGap == null) {
      _handoffGap = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final gap = _handoffGap;
        _handoffGap = null;
        // Focus the app moved in the same turn stays where the app put it.
        final kept =
            FocusManager.instance.primaryFocus == null ||
            (node?.hasFocus ?? false);
        if (gap != null && kept) _handOffFocus(gap);
      });
    }
    // An item that is not built is off screen: nothing shows it leave.
    final exit = look != null && node?.context != null
        ? _startExit(index, look, builder)
        : null;
    final box = node?.context?.findRenderObject();
    if (box is RenderBox && box.hasSize) exit?.size = box.size;
    _joinGap(index, [...around.before, ?exit, ...around.after]);
    setState(() {});
  }

  /// A motion at the theme's `normal` level: forward over its duration,
  /// reverse over its reverse duration, on its curves (D2).
  _ItemMotion _newMotion({required double value}) {
    final normal = _motion.normal;
    final duration = normal.duration ?? Duration.zero;
    final controller = AnimationController(
      vsync: this,
      value: value,
      duration: duration,
      reverseDuration: normal.reverseDuration ?? duration,
      // Reduced motion keeps the fade's full duration (E01); the platform
      // flag would otherwise run it at 5% speed.
      animationBehavior: AnimationBehavior.preserve,
    );
    final curve = normal.curve ?? Curves.easeInOutSine;
    return _ItemMotion(
      controller,
      CurvedAnimation(
        parent: controller,
        curve: curve,
        reverseCurve: normal.reverseCurve ?? curve,
      ),
    );
  }

  /// Starts the remove animation of the item that left at [gap], whose last
  /// look is [look]; the caller places the exit in [_exits].
  _Exit _startExit(int gap, Widget look, WidgetBuilder? builder) {
    final key = look.key!;
    // An item still growing in shrinks back from where it stands.
    final motion = _incoming.remove(key) ?? _newMotion(value: 1);
    final exit = _Exit(
      subKey: key,
      look: look,
      builder: builder,
      motion: motion,
      gap: gap,
    );
    unawaited(motion.controller.reverse().then<void>((_) => _finishExit(exit)));
    return exit;
  }

  /// Takes out of [_exits] the removed items drawn next to the item at
  /// [index] of the current data, whose key is [key]: those just before it
  /// and those just after it, each in the list's order.
  ({List<_Exit> before, List<_Exit> after}) _takeExitsAround(
    int index,
    Key? key,
  ) {
    final next = _builtKeyAt(index + 1);
    bool sitsBefore(_Exit exit) =>
        exit.gap == index ||
        (key != null && exit.hostKey == key && exit.before);
    bool sitsAfter(_Exit exit) =>
        exit.gap == index + 1 ||
        (key != null && exit.hostKey == key && !exit.before) ||
        (next != null && exit.hostKey == next && exit.before);
    final before = _exits.where(sitsBefore).toList();
    final after = _exits.where(sitsAfter).toList();
    _exits.removeWhere((exit) => sitsBefore(exit) || sitsAfter(exit));
    return (before: before, after: after);
  }

  /// Puts [exits], in the list's order, back in [_exits] at [gap] of the
  /// current data; the next build finds their host.
  void _joinGap(int gap, List<_Exit> exits) {
    for (final exit in exits) {
      exit
        ..hostKey = null
        ..gap = gap;
    }
    _exits.addAll(exits);
  }

  void _finishInsert(_ItemMotion motion) {
    if (!mounted) return;
    final held = _incoming.length + _pendingInserts.length;
    _incoming.removeWhere((_, other) => identical(other, motion));
    _pendingInserts.removeWhere((insert) => identical(insert.motion, motion));
    if (_incoming.length + _pendingInserts.length == held) return;
    motion.dispose();
    setState(() {});
  }

  void _finishExit(_Exit exit) {
    if (!mounted || !_exits.remove(exit)) return;
    exit.motion.dispose();
    setState(() {});
  }

  /// The index the item at [index] of the current data had at the last
  /// build; null for an item inserted since.
  int? _builtIndexOf(int index) {
    var i = index;
    for (final call in _pending.reversed) {
      if (call.insert) {
        if (i == call.index) return null;
        if (i > call.index) i -= 1;
      } else if (i >= call.index) {
        i += 1;
      }
    }
    return i;
  }

  /// The key of the item at [index] of the current data as the last build
  /// drew it; null for an item inserted since, not built, or past the end.
  Key? _builtKeyAt(int index) {
    final built = _builtIndexOf(index);
    return built == null ? null : _itemLooks[built]?.key;
  }

  /// Moves the pending indices past an insert at [index]. An insert at a
  /// removed item's gap lands after it, as in `AnimatedList`, whether the
  /// item left in this turn or an earlier one.
  void _shiftForInsert(int index) {
    final host = _builtKeyAt(index);
    for (final exit in _exits) {
      final gap = exit.gap;
      if (gap != null && gap > index) exit.gap = gap + 1;
      // Drawn before the item now at [index]: it waits at the gap again.
      if (host != null && exit.hostKey == host && exit.before) {
        exit
          ..hostKey = null
          ..gap = index;
      }
    }
    for (final insert in _pendingInserts) {
      if (insert.index >= index) insert.index += 1;
    }
    final handoff = _handoffGap;
    if (handoff != null && handoff > index) _handoffGap = handoff + 1;
  }

  /// Moves the pending indices past a remove at [index]; an insert of this
  /// turn that the remove takes back is dropped, never shown.
  void _shiftForRemove(int index) {
    for (final exit in _exits) {
      final gap = exit.gap;
      if (gap != null && gap > index) exit.gap = gap - 1;
    }
    _pendingInserts.removeWhere((insert) {
      if (insert.index != index) return false;
      insert.motion.dispose();
      return true;
    });
    for (final insert in _pendingInserts) {
      if (insert.index > index) insert.index -= 1;
    }
    final handoff = _handoffGap;
    if (handoff != null && handoff > index) _handoffGap = handoff - 1;
  }

  /// Settles the calls since the last build against the app's new data:
  /// reads each inserted item's key and each new exit's host. An item
  /// count the calls do not explain ends every animation at once (E12).
  void _resolvePending(BuildContext context) {
    final layout = _layout;
    final count = layout.itemCount;
    if (count != _dataCount) _resetMotion();
    _dataCount = count;
    _pending.clear();
    Key? keyAt(int index) => layout.itemBuilder(context, index).key;
    final returning = <Key>{};
    for (final insert in _pendingInserts) {
      final key = keyAt(insert.index);
      if (key == null) {
        insert.motion.dispose();
        continue;
      }
      _incoming.remove(key)?.dispose();
      _incoming[key] = insert.motion;
      returning.add(key);
    }
    _pendingInserts.clear();
    // A move or replace with no call can put a leaving key back in view.
    if (_exits.any((exit) => exit.keepsState)) {
      returning.addAll(_keysInView(keyAt, count));
    }
    _yieldExitsTo(returning);
    if (_fixedExtent) _dropEndExits(count);
    if (count == 0) return;
    for (final exit in _exits) {
      final gap = exit.gap;
      if (gap == null) continue;
      exit
        ..gap = null
        ..hostKey = keyAt(gap < count ? gap : count - 1)
        ..before = gap < count;
    }
  }

  /// The items [keys] are in the data while their old copies still leave,
  /// so no key sits twice: a copy in its kept look ends at once, since that
  /// look may hold the app's own global keys; a `builder` copy gives up
  /// the item's State and keeps leaving.
  void _yieldExitsTo(Set<Key> keys) {
    if (keys.isEmpty) return;
    _exits.removeWhere((exit) {
      if (!keys.contains(exit.subKey)) return false;
      if (exit.builder != null) {
        exit.keepsState = false;
        return false;
      }
      exit.motion.dispose();
      return true;
    });
  }

  /// The keys of the data's items from the first index the last build drew
  /// to its last, plus one per leaving item: a closing gap shows one more.
  Set<Key> _keysInView(Key? Function(int index) keyAt, int count) {
    var first = count;
    var last = -1;
    for (final index in _itemLooks.keys) {
      if (index < first) first = index;
      if (index > last) last = index;
    }
    last += _exits.length;
    return {for (var i = first; i <= last && i < count; i++) ?keyAt(i)};
  }

  /// Ends at once each removed item past the last of the [count] items: a
  /// fixed extent gives it no room and no item to fade over (E11).
  void _dropEndExits(int count) {
    _exits.removeWhere((exit) {
      final gap = exit.gap;
      if (gap == null || gap < count) return false;
      exit.motion.dispose();
      return true;
    });
  }

  /// Ends every insert and remove animation at once.
  void _resetMotion() {
    for (final insert in _pendingInserts) {
      insert.motion.dispose();
    }
    for (final motion in _incoming.values) {
      motion.dispose();
    }
    for (final exit in _exits) {
      exit.motion.dispose();
    }
    _pendingInserts.clear();
    _incoming.clear();
    _exits.clear();
  }

  void _registerItem(int index, FocusNode node, Widget look) {
    _itemNodes[index] = node;
    _itemLooks[index] = look;
  }

  void _unregisterItem(int index, FocusNode node) {
    if (_itemNodes[index] != node) return;
    _itemNodes.remove(index);
    _itemLooks.remove(index);
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
    _endExitsBeside(index);
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
    _endExitsBeside(from);
    _layout.onReorderItem(from, to);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _afterMove(to, byKey: false),
    );
  }

  /// Ends at once the removed items drawn in the slot of the built item at
  /// [index], which a reorder moves: they would travel with it.
  void _endExitsBeside(int index) {
    final key = _itemLooks[index]?.key;
    if (key == null) return;
    final count = _exits.length;
    _exits.removeWhere((exit) {
      if (exit.hostKey != key) return false;
      exit.motion.dispose();
      return true;
    });
    if (_exits.length != count) setState(() {});
  }

  /// Starts a drag, and ends it at once when it starts between a call and
  /// the frame that settles the call: that frame would build a leaving
  /// copy whose keys the drag proxy holds.
  void _handleReorderStart(int index) {
    _dragIndex = index;
    final box = _itemNodes[index]?.context?.findRenderObject();
    _liftedSize = box is RenderBox && box.hasSize ? box.size : null;
    _inReorderStart = true;
    try {
      _layout.onReorderStart?.call(index);
      if (_pending.isNotEmpty) _cancelDrag();
    } finally {
      _inReorderStart = false;
    }
  }

  void _handleReorderEnd(int index) {
    _dragIndex = null;
    _layout.onReorderEnd?.call(index);
  }

  /// Cancels a drag in progress before an insert or remove, or one that
  /// starts before their frame (E06): the dragged item returns to its slot,
  /// `onReorderEnd` fires with the index the drag started at, and
  /// `onReorderItem` does not fire. A dropped item still settling ends the
  /// same way, with no second `onReorderEnd`.
  void _cancelDrag() {
    final index = _dragIndex;
    _dragIndex = null;
    if (_inReorderStart) {
      // The drag `onReorderStart` reports is set up after it returns.
      scheduleMicrotask(() {
        if (mounted) _listKey.currentState?.cancelReorder();
      });
    } else {
      _listKey.currentState?.cancelReorder();
    }
    if (index != null) _layout.onReorderEnd?.call(index);
  }

  /// Reports the end of the drag that the SDK cancels, with no
  /// `onReorderEnd`, in the build that changes its item count: once, after
  /// that frame, with the index the drag started at (E06).
  void _reportCountEnd() {
    final index = _dragIndex;
    if (index == null) return;
    _dragIndex = null;
    // After the frame: the app may set state in onReorderEnd.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _layout.onReorderEnd?.call(index);
    });
  }

  /// The drag proxy took the item [key], its State with it.
  void _liftedTook(Key key) => _liftedKey = key;

  /// The drag proxy let the item [key] go, and its State waits among the
  /// inactive elements until the end of the frame.
  void _liftedLetGo(Key key) {
    if (_liftedKey == key) _liftedKey = null;
    if (_standInKey == key) _standInKey = null;
  }

  /// A pointer left the list, lifted or canceled. With none left, no drag
  /// is in progress, whatever [_dragIndex] says after a gesture the SDK
  /// canceled without `onReorderEnd`.
  void _handlePointerGone() {
    _pointersDown -= 1;
    if (_pointersDown == 0) _dragIndex = null;
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

  /// Hands focus from a removed item to the first node of the item now at
  /// [gap], else of the item before it, else to the list's own Tab stop
  /// (E04). Each target is revealed in every viewport around it, as
  /// invariant 21 reveals every focus move.
  void _handOffFocus(int gap) {
    if (!mounted) return;
    final target =
        (gap < _layout.itemCount ? _firstStopOf(gap) : null) ??
        (gap > 0 ? _firstStopOf(gap - 1) : null);
    if (target != null) {
      target.requestFocus();
      return;
    }
    final own = _ownTabStop();
    if (own != null) requestFocusInViewports(own);
  }

  /// The first node in Tab order inside the built item at [index], revealed
  /// by [firstTabStopIn]; null when the item is not built or holds none.
  FocusNode? _firstStopOf(int index) {
    final node = _itemNodes[index];
    if (node == null || node.context == null) return null;
    return firstTabStopIn(node);
  }

  /// The list's own Tab stop when the list is focusable: the first node
  /// above its content group that takes focus and traversal, the node of
  /// `ScrollFocus`.
  FocusNode? _ownTabStop() {
    final focusable =
        _layout.focusable ??
        defaultScrollFocusable(isWeb: kIsWeb, platform: defaultTargetPlatform);
    if (!focusable) return null;
    // Read once after the frame: no rebuild each time focus moves.
    for (
      var node = Focus.maybeOf(context, createDependency: false);
      node != null;
      node = node.parent
    ) {
      if (node.canRequestFocus && !node.skipTraversal) return node;
    }
    return null;
  }

  Widget _proxy(Widget child, int index, Animation<double> animation) {
    return _LiftedItem(
      style: _layout.dragStyle!,
      fast: _motion.fast,
      child: child,
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    // A list whose last items all left still shows them leaving, in one
    // slot of their own, at their size: a slot of no extent never paints.
    if (_layout.itemCount == 0) {
      return _slotFrame(const ValueKey<String>('exits'), [
        for (final exit in _exits) _exitChild(context, exit),
      ]);
    }
    final item = _layout.itemBuilder(context, index);
    final key = item.key;
    assert(key != null, 'Every item of ReorderableListViewLayout needs a key');
    // The global key holds the item's key and this State, never the index,
    // so a moved item keeps its State and focus, as in Material's
    // ReorderableListView. While the drag proxy still holds the item, its
    // slot keeps the gap instead ([_standInKey]).
    var body = key == _standInKey
        ? SizedBox.fromSize(key: _StandInKey(key!), size: _liftedSize)
        : KeyedSubtree(
            key: _ReorderItemKey(key!, this),
            child: _wrapItem(item, index: index, exiting: false),
          );
    // With no motion around it, an item builds as it did before
    // itemsController existed (D7): no lookup, no list.
    if (_exits.isEmpty && _incoming.isEmpty) return body;
    assert(
      !_exits.any((exit) => exit.keepsState && exit.subKey == key),
      'ReorderableListViewLayout builds item $key while its removed copy '
      'still leaves: a leaving key returns to the data only through '
      'insertItem on its itemsController',
    );
    final incoming = _incoming[key];
    final before = <_Exit>[];
    final after = <_Exit>[];
    for (final exit in _exits) {
      if (exit.hostKey == key) (exit.before ? before : after).add(exit);
    }
    if (incoming == null && before.isEmpty && after.isEmpty) return body;
    if (incoming != null) {
      body = _transition(context, incoming.curved, body);
    }
    final slotted = KeyedSubtree(
      key: const ValueKey<String>('item'),
      child: body,
    );
    if (_exitsTakeNoExtent(context)) {
      return _overlayFrame(_SlotKey(key), slotted, [
        for (final exit in before)
          _noExtent(_exitChild(context, exit), past: false),
        for (final exit in after)
          _noExtent(_exitChild(context, exit), past: true),
      ]);
    }
    return _slotFrame(_SlotKey(key), [
      for (final exit in before) _exitChild(context, exit),
      slotted,
      for (final exit in after) _exitChild(context, exit),
    ]);
  }

  /// [item] with its long-press listener and its reorder keys. A leaving
  /// item keeps the same widgets, so its State stays, but takes no
  /// long-press drag and registers no node.
  Widget _wrapItem(Widget item, {required int index, required bool exiting}) {
    var current = item;
    if (_layout.longPressDrag) {
      current = ReorderableDelayedDragStartListener(
        index: index,
        enabled: !exiting,
        child: current,
      );
    }
    return _ReorderKeys(
      index: index,
      body: this,
      look: item,
      exiting: exiting,
      child: current,
    );
  }

  /// A removed item as it leaves: its kept look, or the look its
  /// `removeItem` builder makes, inside the remove transition.
  Widget _exitChild(BuildContext context, _Exit exit) {
    final look = exit.builder?.call(context) ?? exit.look;
    Widget item = KeyedSubtree(
      key: exit.keepsState
          ? _ReorderItemKey(exit.subKey, this)
          : ObjectKey(exit),
      child: _wrapItem(look, index: -1, exiting: true),
    );
    final size = exit.size;
    // A slot's fixed extent need not be the item's own (itemExtentBuilder):
    // it keeps its size, clipped to the slot it fades over (E03, E11).
    if (_fixedExtent && size != null) {
      item = UnconstrainedBox(
        alignment: _startEdge,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(size: size, child: item),
      );
    }
    return KeyedSubtree(
      key: ObjectKey(exit),
      // A leaving item takes no pointer, drag, focus, reorder key, or
      // screen-reader node (E05), nor does a caller transition around it.
      child: IgnorePointer(
        child: ExcludeFocus(
          child: ExcludeSemantics(
            child: _transition(context, exit.motion.curved, item),
          ),
        ),
      ),
    );
  }

  /// The transition of an inserted or removed item.
  ///
  /// Built in, the item grows or shrinks along the main axis and fades as
  /// [animation] runs; under reduced motion or a fixed extent the size
  /// jumps and the fade keeps its full duration (E01, E11). A caller
  /// `itemTransitionBuilder` replaces all of it and gets [animation]
  /// unchanged (E02).
  Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    final builder = _layout.itemTransitionBuilder;
    if (builder != null) return builder(context, animation, child);
    final fade = FadeTransition(opacity: animation, child: _stretched(child));
    if (_fixedExtent || reducesMotion(context)) return fade;
    return SizeTransition(
      axis: _layout.scrollDirection,
      sizeFactor: animation,
      child: fade,
    );
  }

  /// Whether the list lays every slot out at one extent, so no item can
  /// grow or shrink (E11).
  bool get _fixedExtent =>
      _layout.itemExtent != null ||
      _layout.itemExtentBuilder != null ||
      _layout.prototypeItem != null;

  /// Whether a removed item takes no room while it leaves: under a fixed
  /// extent, and under reduced motion unless a caller transition owns
  /// that choice (E01, E02, E11).
  bool _exitsTakeNoExtent(BuildContext context) =>
      _fixedExtent ||
      (_layout.itemTransitionBuilder == null && reducesMotion(context));

  /// [exit] over the item of its slot, taking no room: filling the slot
  /// under a fixed extent, else from the item's edge nearest index 0, or
  /// just past its far edge when [past].
  Widget _noExtent(Widget exit, {required bool past}) {
    // No exit sits past a fixed-extent slot, since a removed end item
    // leaves at once.
    if (_fixedExtent) return Positioned.fill(child: exit);
    final vertical = _layout.scrollDirection == Axis.vertical;
    // The item's top or start edge; its bottom or end edge otherwise.
    final atStart = past == _layout.reverse;
    // A box of no extent on that edge, the exit hanging toward the end of
    // the list from it.
    final hung = Align(
      alignment: _startEdge,
      heightFactor: vertical ? 0 : null,
      widthFactor: vertical ? null : 0,
      child: _stretched(exit),
    );
    if (vertical) {
      return PositionedDirectional(
        start: 0,
        end: 0,
        top: atStart ? 0 : null,
        bottom: atStart ? null : 0,
        child: hung,
      );
    }
    return PositionedDirectional(
      top: 0,
      bottom: 0,
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      child: hung,
    );
  }

  /// A corner on the side nearest index 0, whichever the list's axis.
  AlignmentDirectional get _startEdge => _layout.reverse
      ? AlignmentDirectional.bottomEnd
      : AlignmentDirectional.topStart;

  /// [child] at the full cross-axis extent: a transition loosens the
  /// constraints the list sets on an item.
  Widget _stretched(Widget child) => _layout.scrollDirection == Axis.vertical
      ? SizedBox(width: double.infinity, child: child)
      : SizedBox(height: double.infinity, child: child);

  /// One slot holding an item and the removed items around it, in the
  /// list's order.
  Widget _slotFrame(Key key, List<Widget> children) {
    return FlexLayout(
      key: key,
      direction: _layout.scrollDirection,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _layout.reverse ? children.reversed.toList() : children,
    );
  }

  /// One slot whose [item] fills it and whose removed items take no room,
  /// each painted after the item, over it or past its far edge (E01, E11).
  Widget _overlayFrame(Key key, Widget item, List<Widget> exits) {
    return StackLayout(
      key: key,
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [item, ...exits],
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    _motion =
        StratumThemeApplication.maybeOf(context)?.animation ??
        StratumAnimation.packageDefault;
    _resolvePending(context);
    // A fixed extent leaves no room for a removed last item (E11).
    final hostless =
        layout.itemCount == 0 && _exits.isNotEmpty && !_fixedExtent;
    final listCount = hostless ? 1 : layout.itemCount;
    // The SDK cancels a drag with no onReorderEnd when this count changes.
    if (listCount != _listCount) {
      _reportCountEnd();
      final lifted = _liftedKey;
      if (lifted != null) {
        _standInKey = lifted;
        // The overlay drops the proxy in the next frame, before this State
        // builds again, so the slot then takes the item's State back.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
    _listCount = listCount;
    // Counts the pointers down on the list: the last one gone ends a drag.
    return Listener(
      onPointerDown: (_) => _pointersDown += 1,
      onPointerUp: (_) => _handlePointerGone(),
      onPointerCancel: (_) => _handlePointerGone(),
      child: ReorderableList(
        key: _listKey,
        itemBuilder: _buildItem,
        itemCount: listCount,
        onReorderItem: _handleReorderItem,
        onReorderStart: _handleReorderStart,
        onReorderEnd: _handleReorderEnd,
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
      ),
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
/// keys bubbling up from any node inside the item. A leaving item
/// ([exiting]) keeps the node, so its State stays, but registers nothing
/// and hears no key.
class _ReorderKeys extends StatefulWidget {
  const new({
    required this.index,
    required this.body,
    required this.look,
    required this.exiting,
    required this.child,
  });

  final int index;
  final _ReorderableBodyState body;

  /// The item as `itemBuilder` built it: the look it keeps when removed.
  final Widget look;
  final bool exiting;
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

  /// The item's key while the drag proxy holds the item, outside its list.
  Key? _lifted;

  @override
  void initState() {
    super.initState();
    _register(widget);
  }

  @override
  void didUpdateWidget(_ReorderKeys oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregister(oldWidget);
    _register(widget);
  }

  // The item moved by its global key: into the drag proxy at a drag
  // start, back into a slot at its end, or from one slot to another.
  @override
  void activate() {
    super.activate();
    final body = widget.body;
    if (widget.exiting ||
        context.findAncestorStateOfType<_ReorderableBodyState>() == body) {
      return;
    }
    final key = widget.look.key!;
    _lifted = key;
    body._liftedTook(key);
  }

  @override
  void deactivate() {
    final lifted = _lifted;
    if (lifted != null) {
      _lifted = null;
      widget.body._liftedLetGo(lifted);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _unregister(widget);
    _node.dispose();
    super.dispose();
  }

  void _register(_ReorderKeys keys) {
    if (!keys.exiting) keys.body._registerItem(keys.index, _node, keys.look);
  }

  void _unregister(_ReorderKeys keys) {
    if (!keys.exiting) keys.body._unregisterItem(keys.index, _node);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      includeSemantics: false,
      onKeyEvent: widget.exiting
          ? null
          : (node, event) => widget.body._handleKey(widget.index, node, event),
      child: widget.child,
    );
  }
}

/// The lifted item: starts from `const WidgetStyle()` and switches to
/// [style] on its first frame, so [AnimatedStyledBox] animates the lift.
///
/// [fast] comes from the caller, not this widget's own context: the drag
/// proxy mounts into the nearest [Overlay], a sibling of the themed
/// subtree rather than a descendant, so a lookup from here never finds the
/// [StratumThemeApplication] above the list (spec section 9).
class _LiftedItem extends StatefulWidget {
  const new({required this.style, required this.fast, required this.child});

  final WidgetStyle style;
  final AnimationStyle fast;
  final Widget child;

  @override
  State<_LiftedItem> createState() => _LiftedItemState();
}

class _LiftedItemState extends State<_LiftedItem> {
  var _lifted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lifted = true);
    });
  }

  /// [_LiftedItem.style], with [_LiftedItem.fast] when it sets no timing:
  /// the interaction default of the layouts (spec section 9).
  WidgetStyle get _liftStyle {
    final style = widget.style;
    if (style.animationStyle != null) return style;
    return style.copyWith(animationStyle: widget.fast);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedStyledBox(
      style: _lifted ? _liftStyle : const WidgetStyle(),
      child: widget.child,
    );
  }
}

/// The key of a slot that shows removed items around an item, equal by the
/// item's key.
class _SlotKey extends ValueKey<Key> {
  const new(super.value);
}

/// The key of the gap a lifted item keeps in its slot, equal by the item's
/// key.
class _StandInKey extends ValueKey<Key> {
  const new(super.value);
}

/// An insert or remove animation: its controller and the curved view of it
/// that the transition reads.
class _ItemMotion {
  new(this.controller, this.curved);

  final AnimationController controller;
  final CurvedAnimation curved;

  void dispose() {
    curved.dispose();
    controller.dispose();
  }
}

/// An insert the next build has not settled: the item's index in the
/// current data, and its motion.
class _PendingInsert {
  new(this.index, this.motion);

  int index;
  final _ItemMotion motion;
}

/// A removed item that plays its remove animation.
class _Exit {
  new({
    required this.subKey,
    required this.look,
    required this.builder,
    required this.motion,
    required int this.gap,
  });

  /// The removed item's key.
  final Key subKey;

  /// The widget `itemBuilder` last built for the item.
  final Widget look;

  /// The `removeItem` builder that replaces [look], if any.
  final WidgetBuilder? builder;
  final _ItemMotion motion;

  /// Where the item left, as an index of the current data: before the item
  /// at [gap]. Null once a build has found [hostKey].
  int? gap;

  /// The key of the item whose slot shows this one, [before] it or after.
  Key? hostKey;
  bool before = true;

  /// Whether the exit holds the item's global key and State; false once
  /// the same key is back in the data under a `builder` look.
  bool keepsState = true;

  /// The item's laid-out size at `removeItem`, which a fixed extent keeps.
  Size? size;
}
