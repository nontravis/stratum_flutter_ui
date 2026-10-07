import 'package:flutter/rendering.dart'
    show
        CacheExtentStyle,
        ItemExtentBuilder,
        RenderAbstractViewport,
        RenderSliverMultiBoxAdaptor,
        ScrollCacheExtent,
        ViewportOffset;
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/components/common/style/reduced_motion.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy list whose items the user reorders, inside a [WidgetStyle] box.
///
/// Built on the widgets-level [SliverReorderableList]. Every item that
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
/// moves focus itself in the same turn. A focused item the app removes and
/// inserts back with its key in the same turn keeps focus, and the list
/// shows it at its new slot. A reorder of the item a leaving item is drawn
/// beside ends that leaving item at once.
/// [itemTransitionBuilder] replaces the built-in transition.
/// [StratumReorderableItemsController.moveItem] closes a moved item's old
/// slot while the item grows into its new one, and the item keeps its
/// State and focus.
///
/// An insert or remove during a drag, through [itemsController] or not,
/// and a `moveItem` call during one, end the drag first: the dragged item
/// goes back to its slot, [onReorderEnd] reports the index the drag
/// started at, and [onReorderItem] does not fire. A drag that starts
/// between an `insertItem`, `removeItem`, or `moveItem` call, or a move
/// the list reported through [onReorderItem], and the next frame ends the
/// same way at once. A reorder key or a screen reader's move during a
/// drag, or while a dropped item settles, ends it the same way before it
/// moves.
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
  /// A moved item's entry takes it too; the slot the item left never does.
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

/// Animates the items an app inserts into, removes from, or moves within a
/// [ReorderableListViewLayout], passed as its `itemsController`.
///
/// Call [insertItem], [removeItem], or [moveItem] in the same turn as the
/// matching change to the app's own data, outside a build and outside the
/// list's reorder callbacks; from those, call after the frame. Indices are
/// data indices: an item still growing in counts, and an item playing its
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
    _body?._insertItem(_DataIndex(index));
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
    _body?._removeItem(_DataIndex(index), builder);
  }

  /// Moves the item the app moved from [from] to [to] of its data: its old
  /// slot closes while it grows and fades into the new one, over the
  /// theme's `normal` level, and it keeps its State and focus.
  ///
  /// [to] is the index the item ends at, as `onReorderItem` reports it, so
  /// the app moves it with `insert(to, removeAt(from))`; the list does not
  /// call `onReorderItem`. Both run from 0 to the item count less one, and
  /// a move to the same index does nothing.
  void moveItem(int from, int to) {
    assert(
      _body != null,
      'moveItem on a StratumReorderableItemsController attached to no '
      'ReorderableListViewLayout',
    );
    _body?._moveItem(_DataIndex(from), _DataIndex(to));
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

/// The reorderable list, a [SliverReorderableList] in its own scroll view,
/// with the per-item wrappers and the reorder keys.
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
  final _itemNodes = <_FrameIndex, FocusNode>{};

  /// The widget [ReorderableListViewLayout.itemBuilder] last built for each
  /// built item, by index: the look a removed item keeps (E03).
  final _itemLooks = <_FrameIndex, Widget>{};

  /// The theme's motion, read in [build]: the drag proxy mounts outside
  /// the themed subtree (spec section 9), so [_proxy] cannot read it from
  /// its own context, and `insertItem` and `removeItem` run outside a
  /// build.
  StratumAnimation _motion = StratumAnimation.packageDefault;

  /// The item count of the app's data: the count of the last build, moved
  /// by each `insertItem` and `removeItem` since.
  late int _dataCount;

  /// The `insertItem`, `removeItem`, and `moveItem` calls since the last
  /// build, and the moves the list reported through `onReorderItem`, in
  /// call order: they map an index of the app's current data to the index
  /// the item had at that build, and back. An insert has no `from`, a
  /// remove no `to`, and a move both, in one entry, so both converters
  /// follow the moved item; a move the list reported is `reported` (R6).
  final _pending = <({_DataIndex? from, _DataIndex? to, bool reported})>[];

  /// The inserts since the last build, each at its index in the current
  /// data; the next build reads the inserted item's key.
  final _pendingInserts = <_PendingInsert>[];

  /// The inserted items still growing in, by item key.
  final _incoming = <Key, _ItemMotion>{};

  /// The removed items still shrinking out, in the list's order.
  final _exits = <_Exit>[];

  /// Where a removed item that held primary focus left, as an index of the
  /// current data, until the frame after the call hands focus on (E04).
  _DataIndex? _handoffGap;

  /// The key of the focused item a move's post-frame follow waits for; the
  /// build that settles the move records its slot in [_followAt] (FR-05
  /// E04).
  Key? _followKey;

  /// Where a focused moved item left, as an index of the current data, until
  /// the frame after the move follows the item (FR-05 E04). Each call in the
  /// move's own turn shifts it, as it shifts [_handoffGap].
  _DataIndex? _followGap;

  /// The slot the settling build gives [_followKey], re-derived by key, as
  /// [_returnAt] is for a returned item (FR-05 E04).
  _FrameIndex? _followAt;

  /// The key of the removed item [_handoffGap] marks: an insert of the
  /// same key in that turn keeps focus with the item (E16 to E18).
  Key? _handoffKey;

  /// Where an insert of this turn brought [_handoffKey] back, as an index
  /// of the current data, read by the build that settles the insert (E17).
  _FrameIndex? _returnAt;

  /// The index the drag in progress started at, from `onReorderStart` to
  /// `onReorderEnd`; null with no drag.
  ///
  /// The SDK ends a drag without `onReorderEnd` on a canceled gesture and
  /// on a change of the item count it is given: the last pointer up clears
  /// it, and that change reports the end ([_reportCountEnd]).
  _FrameIndex? _dragIndex;

  /// The item count the last build gave [SliverReorderableList].
  int? _listCount;

  /// Where each key move, screen-reader move, or drop of this frame put its
  /// item, as an index of the current data, until the frame after it
  /// reveals the item: each call moves them, as it moves [_handoffGap].
  final _moveTargets = <_MoveTarget>[];

  /// The near slots focused moves asked the next frame to build ahead to,
  /// each until that frame's post-frame callbacks have run (D1, D3); the
  /// list's viewport alone listens to them.
  final _aheadAsks = _AheadAsks();

  /// The far moves of this turn that jumped for a focused item, each with
  /// the item's key node and the offset before the jump, until the next
  /// frame starts and reads whether the item still holds focus (R13).
  final _farJumps =
      <({FocusNode node, ({ScrollPosition position, double pixels}) origin})>[];

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

  /// Reaches [SliverReorderableListState.cancelReorder] and the list's
  /// sliver ([_sliver]).
  final _listKey = GlobalKey<SliverReorderableListState>();

  ReorderableListViewLayout get _layout => widget.layout;

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
    _aheadAsks.dispose();
    super.dispose();
  }

  /// [StratumReorderableItemsController.insertItem]: the app inserted an
  /// item at [index] of its data in this turn.
  void _insertItem(_DataIndex index) {
    assert(
      index >= const _DataIndex(0) && index <= _dataEnd,
      'insertItem($index) is out of range: the data holds $_dataCount '
      'items',
    );
    if (index < const _DataIndex(0) || index > _dataEnd) return;
    _cancelDrag();
    _shiftForInsert(index);
    _pending.add((from: null, to: index, reported: false));
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
  void _removeItem(_DataIndex index, WidgetBuilder? builder) {
    assert(
      index >= const _DataIndex(0) && index < _dataEnd,
      'removeItem($index) is out of range: the data holds $_dataCount '
      'items',
    );
    if (index < const _DataIndex(0) || index >= _dataEnd) return;
    _cancelDrag();
    final built = _builtIndexOf(index, inPlace: true);
    final node = built == null ? null : _nodeAt(built);
    final look = built == null ? null : _lookAt(built);
    final focused = node?.hasFocus ?? false;
    final around = _takeExitsAround(index, look?.key);
    _shiftForRemove(index);
    _pending.add((from: index, to: null, reported: false));
    _dataCount -= 1;
    if (focused && _handoffGap == null) {
      _handoffGap = index;
      _handoffKey = look?.key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final gap = _handoffGap;
        final key = _handoffKey;
        final returnAt = _returnAt;
        _handoffGap = null;
        _handoffKey = null;
        _returnAt = null;
        if (!mounted || gap == null) return;
        final primary = FocusManager.instance.primaryFocus;
        // The key came back in this turn into a slot the frame built, with
        // its State: focus stays with the item, or, gone, goes to the
        // item's first node, and the list shows it (E16, E18).
        if (key != null &&
            node != null &&
            node.context != null &&
            _itemNodes.containsValue(node)) {
          if (node.hasFocus) {
            _revealReturned(node, key);
          } else if (primary == null) {
            firstTabStopIn(node)?.requestFocus();
            _revealReturned(node, key);
          }
          return;
        }
        // Focus the app moved in the same turn stays where the app put it.
        final kept = primary == null || (node?.hasFocus ?? false);
        if (!kept) return;
        // The key came back into a slot the frame did not build, so its
        // State is gone: reach the slot (E17).
        if (key != null && returnAt != null) {
          _startReach(returnAt, key, gap);
          return;
        }
        _handOffFocus(gap);
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

  /// [StratumReorderableItemsController.moveItem]: the app moved the item
  /// at [from] of its data to [to] in this turn (FR-05). Booked in
  /// [_pending] as one move entry, which both converters follow, and as an
  /// insert at [to] in [_pendingInserts], so the item's global key carries
  /// its State into the new slot when the frame builds it.
  void _moveItem(_DataIndex from, _DataIndex to) {
    const first = _DataIndex(0);
    assert(
      from >= first && from < _dataEnd && to >= first && to < _dataEnd,
      'moveItem($from, $to) is out of range: the data holds $_dataCount '
      'items',
    );
    if (from < first || from >= _dataEnd || to < first || to >= _dataEnd) {
      return;
    }
    if (from == to) return;
    _cancelDrag();
    final built = _builtIndexOf(from, inPlace: true);
    final node = built == null ? null : _nodeAt(built);
    final key = built == null ? null : _lookAt(built)?.key;
    final focused = node?.hasFocus ?? false;
    // A leaving item drawn beside the moved item would travel with it.
    if (built != null) _endExitsBeside(built);
    final box = node?.context?.findRenderObject();
    final size = box is RenderBox && box.hasSize ? box.size : null;
    _shiftForRemove(from);
    // A remove while the insert side below reads the data without the
    // item, then one move entry.
    _pending.add((from: from, to: null, reported: false));
    _dataCount -= 1;
    // The old slot closes as the item grows in; at once under reduced
    // motion or a fixed extent, where the item only fades in (E02).
    if (key != null &&
        size != null &&
        !_fixedExtent &&
        !reducesMotion(context)) {
      _joinGap(from, [_startClosingGap(from, key, size)]);
    }
    _shiftForInsert(to);
    _pending.last = (from: from, to: to, reported: false);
    _dataCount += 1;
    final motion = _newMotion(value: 0);
    _pendingInserts.add(_PendingInsert(to, motion));
    unawaited(
      motion.controller.forward().then<void>((_) => _finishInsert(motion)),
    );
    if (focused && node != null && key != null) {
      // The slot the item left, by the index of the item now after it; both
      // this gap and the item's slot live in fields each call in this turn
      // shifts, and the build that settles the move re-reads the slot by
      // key, so the post-frame follow follows the data, not frozen indices.
      // Set before the jump below: its scroll notifications may reach an
      // app listener that calls the controller at once.
      _followKey = key;
      _followGap = from < to ? from : from + 1;
      // A focused item whose new slot is not built has the next frame build
      // ahead to a near slot, or jumps toward a far one first, so the frame
      // that moves it builds the slot and keeps its State (E04). Asked after
      // the booking, which starts the boxes that slot counts.
      final origin = _buildAheadOrJump(to, node);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _followMoved(node, key, origin),
      );
    }
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
  _Exit _startExit(_DataIndex gap, Widget look, WidgetBuilder? builder) {
    final key = look.key!;
    // An item still growing in shrinks back from where it stands. Its
    // motion now runs in reverse, so the reveal that waited for its
    // completion comes off it.
    final reused = _incoming.remove(key);
    reused?.dropGrown();
    final motion = reused ?? _newMotion(value: 1);
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

  /// Starts the slot a moved item left at [gap]: an empty box of the
  /// item's [size] that closes over the `normal` level's forward duration,
  /// in step with the item growing into its new slot (FR-05).
  _Exit _startClosingGap(_DataIndex gap, Key key, Size size) {
    final motion = _newMotion(value: 0);
    final exit =
        _Exit(
            subKey: key,
            look: const SizedBox.shrink(),
            builder: null,
            motion: motion,
            gap: gap,
            closing: true,
          )
          ..keepsState = false
          ..size = size;
    unawaited(motion.controller.forward().then<void>((_) => _finishExit(exit)));
    return exit;
  }

  /// Takes out of [_exits] the removed items drawn next to the item at
  /// [index] of the current data, whose key is [key]: those just before it
  /// and those just after it, each in the list's order.
  ({List<_Exit> before, List<_Exit> after}) _takeExitsAround(
    _DataIndex index,
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
  void _joinGap(_DataIndex gap, List<_Exit> exits) {
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
  /// build: a backward replay of [_pending]; null for an item inserted
  /// since, and the index before the move for an item a move of this turn
  /// moved. One of the two converters between the index spaces, with
  /// [_dataIndexOf].
  ///
  /// With [inPlace], an item a `moveItem` call moved maps to null as an
  /// inserted one does: the frame drew it elsewhere, not at this place of
  /// the data. A call on it then starts no second exit, closing gap, or
  /// follow, since the move's own closing gap and follow hold its old slot
  /// and its focus (FR-05 E04), and the focus handoff passes over it. A
  /// move the list reported has neither, so [inPlace] follows it (R6).
  _FrameIndex? _builtIndexOf(_DataIndex index, {bool inPlace = false}) {
    var i = index.value;
    for (final call in _pending.reversed) {
      final from = call.from?.value;
      final to = call.to?.value;
      if (i == to) {
        if (from == null || (inPlace && !call.reported)) return null;
        i = from;
      } else {
        if (to != null && i > to) i -= 1;
        if (from != null && i >= from) i += 1;
      }
    }
    return _FrameIndex(i);
  }

  /// The index in the current data of the item the last build drew at
  /// [index]: a forward replay of [_pending]; null for an item a remove of
  /// this turn took out, and the new index for an item a move of this turn
  /// moved. One of the two converters, with [_builtIndexOf].
  _DataIndex? _dataIndexOf(_FrameIndex index) {
    var i = index.value;
    for (final call in _pending) {
      final from = call.from?.value;
      final to = call.to?.value;
      if (i == from) {
        if (to == null) return null;
        i = to;
      } else {
        if (from != null && i > from) i -= 1;
        if (to != null && i >= to) i += 1;
      }
    }
    return _DataIndex(i);
  }

  /// One past the last index of the app's data: the bound of every index
  /// of the current data.
  _DataIndex get _dataEnd => _DataIndex(_dataCount);

  /// The key node of the item the last build drew at [index].
  FocusNode? _nodeAt(_FrameIndex index) => _itemNodes[index];

  /// The look of the item the last build drew at [index].
  Widget? _lookAt(_FrameIndex index) => _itemLooks[index];

  /// The key of the item at [index] of the current data as the last build
  /// drew it; null for an item inserted since, not built, or past the end.
  Key? _builtKeyAt(_DataIndex index) {
    final built = _builtIndexOf(index);
    return built == null ? null : _lookAt(built)?.key;
  }

  /// Moves the pending indices past an insert at [index]. An insert at a
  /// removed item's gap lands after it, as in `AnimatedList`, whether the
  /// item left in this turn or an earlier one.
  void _shiftForInsert(_DataIndex index) {
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
    final reachGap = _reachGap;
    if (reachGap != null && reachGap > index) _reachGap = reachGap + 1;
    for (final held in _givenUpGaps) {
      if (held.index > index) held.index += 1;
    }
    final follow = _followGap;
    if (follow != null && follow > index) _followGap = follow + 1;
    for (final target in _moveTargets) {
      final at = target.index;
      if (at != null && at >= index) target.index = at + 1;
      final gap = target.gap;
      if (gap != null && gap > index) target.gap = gap + 1;
    }
  }

  /// Moves the pending indices past a remove at [index]; an insert of this
  /// turn that the remove takes back is dropped, never shown.
  void _shiftForRemove(_DataIndex index) {
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
    final reachGap = _reachGap;
    if (reachGap != null && reachGap > index) _reachGap = reachGap - 1;
    for (final held in _givenUpGaps) {
      if (held.index > index) held.index -= 1;
    }
    final follow = _followGap;
    if (follow != null && follow > index) _followGap = follow - 1;
    for (final target in _moveTargets) {
      final gap = target.gap;
      if (gap != null && gap > index) target.gap = gap - 1;
      final at = target.index;
      if (at == null || at < index) continue;
      // A call that takes the moved item out leaves nothing to reveal.
      target.index = at == index ? null : at - 1;
    }
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
    Key? keyAt(_DataIndex index) =>
        layout.itemBuilder(context, index.value).key;
    final returning = <Key>{};
    for (final insert in _pendingInserts) {
      final key = keyAt(insert.index);
      if (key == null) {
        insert.motion.dispose();
        continue;
      }
      // With [_pending] clear, the converter gives the index this build
      // draws the item at: the frame index the post-frame readers take.
      if (key == _handoffKey) _returnAt = _builtIndexOf(insert.index);
      // The follow's slot by the key the move's own insert carries, so a
      // second call in the move's turn cannot strand it on a stale index.
      if (key == _followKey) _followAt = _builtIndexOf(insert.index);
      _incoming.remove(key)?.dispose();
      _incoming[key] = insert.motion;
      returning.add(key);
    }
    _pendingInserts.clear();
    // A move or replace with no call can put a leaving key back in view.
    if (_exits.any((exit) => exit.keepsState)) {
      returning.addAll(_keysInView(keyAt));
    }
    _yieldExitsTo(returning);
    if (_fixedExtent) _dropEndExits();
    // This build draws every exit left, so none adds a box after it.
    for (final exit in _exits) {
      exit.fresh = false;
    }
    if (count == 0) return;
    for (final exit in _exits) {
      final gap = exit.gap;
      if (gap == null) continue;
      exit
        ..gap = null
        ..hostKey = keyAt(gap < _dataEnd ? gap : _dataEnd - 1)
        ..before = gap < _dataEnd;
    }
  }

  /// The items [keys] are in the data while their old copies still leave,
  /// so no key sits twice: a copy in its kept look ends at once, since that
  /// look may hold the app's own global keys; a `builder` copy gives up
  /// the item's State and keeps leaving.
  void _yieldExitsTo(Set<Key> keys) {
    if (keys.isEmpty) return;
    _exits.removeWhere((exit) {
      // A moved item's closing slot holds neither its look nor its State.
      if (exit.closing || !keys.contains(exit.subKey)) return false;
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
  /// The sliver rebuilds its children by index number, so with [_pending]
  /// clear the converter reads the last build's range in the new data.
  Set<Key> _keysInView(Key? Function(_DataIndex index) keyAt) {
    _FrameIndex? first;
    _FrameIndex? last;
    for (final index in _itemLooks.keys) {
      if (first == null || index < first) first = index;
      if (last == null || index > last) last = index;
    }
    final start = first == null ? null : _dataIndexOf(first);
    final end = last == null ? null : _dataIndexOf(last);
    if (start == null || end == null) return {};
    final stop = end + _exits.length;
    return {for (var i = start; i <= stop && i < _dataEnd; i += 1) ?keyAt(i)};
  }

  /// Ends at once each removed item past the last item of the data: a
  /// fixed extent gives it no room and no item to fade over (E11).
  void _dropEndExits() {
    _exits.removeWhere((exit) {
      final gap = exit.gap;
      if (gap == null || gap < _dataEnd) return false;
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

  void _registerItem(_FrameIndex index, FocusNode node, Widget look) {
    _itemNodes[index] = node;
    _itemLooks[index] = look;
  }

  void _unregisterItem(_FrameIndex index, FocusNode node) {
    if (_nodeAt(index) != node) return;
    _itemNodes.remove(index);
    _itemLooks.remove(index);
  }

  /// The reorder keys of item [index], from the node of its [_ReorderKeys].
  /// They act at once, also between a call and its frame, and report
  /// indices of the app's data (FR-02 E07); a move ends a drag or a
  /// settling drop first (FR-02 E08).
  KeyEventResult _handleKey(_FrameIndex index, FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isAltPressed ||
        keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        primaryFocusInEditableText()) {
      return KeyEventResult.ignored;
    }
    final item = node.context;
    final position = item == null ? null : Scrollable.maybeOf(item)?.position;
    if (item == null || position == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final _MoveIntent intent;
    if (key == LogicalKeyboardKey.home) {
      intent = _MoveIntent.start;
    } else if (key == LogicalKeyboardKey.end) {
      intent = _MoveIntent.end;
    } else {
      final direction = arrowAlong(key, position.axis);
      if (direction == null) return KeyEventResult.ignored;
      // The slot on that side of the screen.
      intent = direction == position.axisDirection
          ? _MoveIntent.next
          : _MoveIntent.previous;
    }
    final from = _dataIndexOf(index);
    // An item the app removed in this turn does not move (R2), even when
    // fewer than two items are left (R8), nor does a move past either end;
    // both are handled, so the browser never sees the key. Any other key
    // in a list of fewer than two items is not handled (E02).
    if (from == null) return KeyEventResult.handled;
    if (_dataCount < 2) return KeyEventResult.ignored;
    final target = _targetOf(from, intent);
    if (target == null) return KeyEventResult.handled;
    // A drag, or a drop still settling, ends first, as a call ends it
    // (invariant 28): the move changes the data under it.
    _cancelDrag();
    if (intent == _MoveIntent.start || intent == _MoveIntent.end) {
      _jumpTowards(item, position, toStart: intent == _MoveIntent.start);
    }
    _endExitsBeside(index);
    _bookReportedMove(from, target);
    final moved = _readyStep(intent, from, target, node, _lookAt(index)?.key);
    _moveTargets.add(moved);
    _layout.onReorderItem(from.value, target.value);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _afterMove(moved, byKey: true),
    );
    return KeyEventResult.handled;
  }

  /// The index of the app's data that [intent] moves the item at [from]
  /// to: the one target path of the reorder keys and of a screen reader's
  /// move actions (FR-02, FR-03 E07); null for a move past either end.
  _DataIndex? _targetOf(_DataIndex from, _MoveIntent intent) {
    const start = _DataIndex(0);
    final last = _dataEnd - 1;
    final target = switch (intent) {
      _MoveIntent.start => start,
      _MoveIntent.previous => from - 1,
      _MoveIntent.next => from + 1,
      _MoveIntent.end => last,
    };
    if (target < start || target > last || target == from) return null;
    return target;
  }

  /// The intent of a screen reader's move action, decoded from the frame
  /// indices the SDK reports: the start and the end first, so a move to the
  /// first or last slot reads as one even from the slot next to it (R4).
  _MoveIntent _intentOf(_FrameIndex from, _FrameIndex to) {
    if (to == const _FrameIndex(0)) return _MoveIntent.start;
    if (to == _FrameIndex((_listCount ?? 0) - 1)) return _MoveIntent.end;
    return to < from ? _MoveIntent.previous : _MoveIntent.next;
  }

  /// The list's own moves: a drop and a screen reader's move actions, told
  /// apart by drag state: the drag proxy holds the dropped item
  /// ([_liftedKey]) until after the SDK reports the drop, so a report of
  /// that item is the drop. A drop converts its frame indices, since a
  /// call during a drag ends it first (invariant 28); a screen-reader move
  /// is decoded into its intent and takes the reorder keys' target (R4),
  /// so it acts at once, also between a call and its frame (FR-03 E07),
  /// and ends a drag or a settling drop first, as a call does (FR-03 E08).
  /// The start and end actions jump there first when that slot is not
  /// built, so the moved item keeps its State; a step action that a
  /// same-turn call shifts onto the data's first or last slot takes D1's
  /// near and far paths instead (R12 inputs), not this exact jump.
  void _handleReorderItem(int fromIndex, int toIndex) {
    final index = _FrameIndex(fromIndex);
    final drop = _liftedKey != null && _lookAt(index)?.key == _liftedKey;
    final from = _dataIndexOf(index);
    // An item the app removed in this turn does not move (R2).
    if (from == null) return;
    final to = _FrameIndex(toIndex);
    final intent = drop ? null : _intentOf(index, to);
    final target = intent == null ? _dataIndexOf(to) : _targetOf(from, intent);
    if (target == null) return;
    if (!drop) _cancelDrag();
    final item = _nodeAt(index)?.context;
    final position = item == null ? null : Scrollable.maybeOf(item)?.position;
    const start = _DataIndex(0);
    final edgeAction = intent == _MoveIntent.start || intent == _MoveIntent.end;
    final edge = edgeAction && (target == start || target == _dataEnd - 1);
    if (item != null && position != null && edge && _nodeAt(to) == null) {
      _jumpTowards(item, position, toStart: target == start);
    }
    _endExitsBeside(index);
    _bookReportedMove(from, target);
    final moved = _readyStep(
      intent,
      from,
      target,
      _nodeAt(index),
      _lookAt(index)?.key,
    );
    _moveTargets.add(moved);
    _layout.onReorderItem(from.value, target.value);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _afterMove(moved, byKey: false),
    );
  }

  /// Books a move the list reports through `onReorderItem`, from [from] to
  /// [to] of the current data, in [_pending] as one move entry, as
  /// [_moveItem] books its own (R6): the inserts, leaving items, and gaps of
  /// this turn follow the moved item, so a grow-in plays on its own item.
  /// Bookkeeping only: the entry starts no grow-in and no closing gap. It
  /// holds because the app moves the item in its data before the list's
  /// next build, the contract of `onReorderItem`, and the build this asks
  /// for settles it.
  void _bookReportedMove(_DataIndex from, _DataIndex to) {
    // The moved item's own grow-in, from a `moveItem` call of this turn,
    // moves with it: the remove side would end it.
    final own = [
      for (final insert in _pendingInserts)
        if (insert.index == from) insert,
    ];
    _pendingInserts.removeWhere(own.contains);
    _shiftForRemove(from);
    // A remove while the insert side reads the data without the item, then
    // one move entry, as in [_moveItem].
    _pending.add((from: from, to: null, reported: true));
    _shiftForInsert(to);
    _pending.last = (from: from, to: to, reported: true);
    for (final insert in own) {
      _pendingInserts.add(insert..index = to);
    }
    setState(() {});
  }

  /// The record the frame after a key or screen-reader move reads, for a
  /// move booked from [from] to [to] of the current data. A one-slot move,
  /// [intent] previous or next, of an item that holds focus, whose key
  /// node is [node], readies its slot as a move call does
  /// ([_buildAheadOrJump], FR-03 E09), and keeps the item's [key], the gap
  /// it left, and the offset before any jump, for the reach should the
  /// frame still not build that slot ([_reachStep]).
  _MoveTarget _readyStep(
    _MoveIntent? intent,
    _DataIndex from,
    _DataIndex to,
    FocusNode? node,
    Key? key,
  ) {
    final step = intent == _MoveIntent.previous || intent == _MoveIntent.next;
    if (!step || node == null || key == null || !node.hasFocus) {
      return _MoveTarget(to);
    }
    final origin = _buildAheadOrJump(to, node);
    return _MoveTarget(
      to,
      key: key,
      // The slot the item left, by the index of the item now after it.
      gap: from < to ? from : from + 1,
      origin: origin,
    );
  }

  /// Ends at once the removed items drawn in the slot of the built item at
  /// [index], which a reorder moves: they would travel with it.
  void _endExitsBeside(_FrameIndex index) {
    final key = _lookAt(index)?.key;
    if (key == null) return;
    final count = _exits.length;
    _exits.removeWhere((exit) {
      if (exit.hostKey != key) return false;
      exit.motion.dispose();
      return true;
    });
    if (_exits.length != count) setState(() {});
  }

  /// Starts a drag, and ends it at once when it starts between a call, or a
  /// move the list reported (R6), and the frame that settles it: that frame
  /// would build a leaving copy, or the dragged item at another index,
  /// whose keys the drag proxy holds.
  void _handleReorderStart(int index) {
    final dragged = _FrameIndex(index);
    _dragIndex = dragged;
    final box = _nodeAt(dragged)?.context?.findRenderObject();
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

  /// Cancels a drag in progress before an insert, remove, or move, a key
  /// move or a screen-reader move among them, or one that starts before
  /// their frame (E06): the dragged item returns to its slot,
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
    if (index != null) _layout.onReorderEnd?.call(index.value);
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
      if (mounted) _layout.onReorderEnd?.call(index.value);
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

  /// Jumps to the start when [toStart], else to the end. The target slot
  /// may not be built; the move needs it built in the frame that moves the
  /// item.
  void _jumpTowards(
    BuildContext item,
    ScrollPosition position, {
    required bool toStart,
  }) {
    if (toStart) {
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

  /// Reveals the item at [moved]'s index after a move, by the edge of each
  /// viewport around it ([revealInViewports]). The index is one of the
  /// current data, converted when read, so a call made after the move, or
  /// one the app defers to run earlier in the post-frame batch (FR-04
  /// E15), cannot shift it (D7). After a key move, when no node, or only a
  /// scope, holds primary focus, it moves to that item's first node in Tab
  /// order; a focus the app moves to another node in the move's turn stays
  /// there instead (R13), the same distinction [_reach] and [_followMoved]
  /// make. An item still growing in before it pushes it past the edge it
  /// was revealed at, so it is revealed again as each such grow-in ends
  /// (R10).
  void _afterMove(_MoveTarget moved, {required bool byKey}) {
    _moveTargets.remove(moved);
    final index = moved.index;
    if (!mounted || index == null) return;
    final built = _builtIndexOf(index);
    if (built == null) return;
    final node = _nodeAt(built);
    if (node == null || node.context == null) {
      _reachStep(moved, built);
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    final noFocusOwnerElsewhere = primary == null || primary is FocusScopeNode;
    if (byKey && noFocusOwnerElsewhere) firstTabStopIn(node)?.requestFocus();
    revealInViewports(node);
    for (final MapEntry(key: at, value: look) in _itemLooks.entries) {
      final motion = at < built ? _incoming[look.key] : null;
      if (motion != null) _revealAfterGrowIn(node, motion, byKey: byKey);
    }
  }

  /// The frame did not build the slot a focused one-slot move readied
  /// ([_readyStep]), now [at]: the estimate missed, so the list reaches the
  /// slot as a move call's follow does, with the gap the item left (FR-03
  /// E09, FR-05 E04), unless a node holds primary focus, which the app
  /// moved there in the move's turn (R13).
  void _reachStep(_MoveTarget moved, _FrameIndex at) {
    final key = moved.key;
    final gap = moved.gap;
    if (key == null || gap == null) return;
    if (FocusManager.instance.primaryFocus != null) return;
    _startReach(at, key, gap, origin: moved.origin);
  }

  /// Reveals the moved item whose key node is [node] again in the frame
  /// [motion], the grow-in of an item before it, completes (R10): after a
  /// key move only while the item keeps focus, as E16's second reveal.
  /// Disposing [motion] before it completes drops the listener with it.
  void _revealAfterGrowIn(
    FocusNode node,
    _ItemMotion motion, {
    required bool byKey,
  }) {
    void grown(AnimationStatus status) {
      if (!status.isCompleted) return;
      motion.controller.removeStatusListener(grown);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A FocusNode keeps its context once disposed: the item is live
        // only while its node is registered.
        if (!mounted || !_itemNodes.containsValue(node)) return;
        if (!byKey || node.hasFocus) revealInViewports(node);
      });
    }

    motion.controller.addStatusListener(grown);
  }

  /// Hands focus from a removed item to the first node of the item now at
  /// [gap], else of the item before it, else to the list's own Tab stop
  /// (E04). [gap] is an index of the current data, converted when read, so
  /// a call that runs earlier in the post-frame batch cannot land focus one
  /// item off; an item at the gap that the frame has not built, inserted
  /// after the frame, is skipped (R3). Each target is revealed in every
  /// viewport around it, as invariant 21 reveals every focus move.
  void _handOffFocus(_DataIndex gap) {
    if (!mounted) return;
    final next = _builtNear(gap, 1);
    final previous = _builtNear(gap - 1, -1);
    final target =
        (next == null ? null : _firstStopOf(next)) ??
        (previous == null ? null : _firstStopOf(previous));
    if (target != null) {
      target.requestFocus();
      return;
    }
    final own = _ownTabStop();
    if (own != null) requestFocusInViewports(own);
  }

  /// The index in the last frame of the item nearest [index] of the
  /// current data, from [index] on in the direction of [step], that the
  /// frame drew at that place: an item inserted since the frame, or moved
  /// there since, is skipped (R3). Null past either end of the data.
  _FrameIndex? _builtNear(_DataIndex index, int step) {
    for (var i = index; i >= const _DataIndex(0) && i < _dataEnd; i += step) {
      final built = _builtIndexOf(i, inPlace: true);
      if (built != null) return built;
    }
    return null;
  }

  /// Reveals the item whose key node is [node] by [revealInViewports],
  /// now and again in the frame its grow-in motion under [key] completes:
  /// the item grows past the viewport's edge as it enters (E16).
  void _revealReturned(FocusNode node, Key key) {
    revealInViewports(node);
    final motion = _incoming[key];
    if (motion == null) return;
    void grown(AnimationStatus status) {
      if (!status.isCompleted) return;
      motion.dropGrown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _itemNodes.containsValue(node) && node.hasFocus) {
          revealInViewports(node);
        }
      });
    }

    // The motion leaves this reveal's hands when it is disposed or reused
    // before completing, so it drops any listener of an earlier one first.
    motion
      ..dropGrown()
      ..grown = grown;
    motion.controller.addStatusListener(grown);
  }

  /// How many frames the reach into a returned item's unbuilt slot jumps
  /// before it gives up (E17).
  static const _reachFrames = 4;

  /// The reach in progress; a newer reach replaces it (E17).
  Object? _reachToken;

  /// The gap of the reach in progress, as an index of the current data:
  /// each call moves it, as it moves [_handoffGap].
  _DataIndex? _reachGap;

  /// The gap of each reach given up away from where it started, as an
  /// index of the current data, until the frame after the list jumps back
  /// hands focus on from it: each call moves them, as it moves
  /// [_handoffGap] (D7).
  final _givenUpGaps = <_HeldGap>[];

  /// Starts [_reach] in a microtask after this frame's post-frame
  /// callbacks. Flutter moves focus off the item's disposed node in its own
  /// microtask, queued earlier in the frame, so the reach starts from the
  /// focus Flutter settled on, and only a later move ends it.
  /// [origin], when given, is the offset a failed reach returns to, in place
  /// of the one before its own first jump (R5 for moves).
  void _startReach(
    _FrameIndex index,
    Key key,
    _DataIndex gap, {
    ({ScrollPosition position, double pixels})? origin,
  }) {
    final token = Object();
    _reachToken = token;
    _reachGap = gap;
    scheduleMicrotask(() {
      final settled = FocusManager.instance.primaryFocus;
      _reach(token, index, key, settled, _reachFrames, origin);
    });
  }

  /// Ends the reach in progress.
  void _endReach() {
    _reachToken = null;
    _reachGap = null;
  }

  /// Reaches slot [index], where the item [key] came back after a frame
  /// that did not build it (E17): jumps toward it by [_estimateTowards]
  /// until a frame builds it, then focuses the item's first node and
  /// reveals it. A node other than [settled] that takes focus, and is not
  /// a scope, ends the reach and keeps that focus. A slot that holds
  /// another key, or a slot not built after [frames] jumps, gives the
  /// reach up through [_giveUpReach]; [origin] is the list's offset before
  /// the reach's first jump.
  void _reach(
    Object token,
    _FrameIndex index,
    Key key,
    FocusNode? settled,
    int frames,
    ({ScrollPosition position, double pixels})? origin,
  ) {
    if (!mounted || _reachToken != token) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary != settled && primary is! FocusScopeNode) {
      _endReach();
      return;
    }
    final node = _nodeAt(index);
    if (node != null && node.context != null) {
      if (_lookAt(index)?.key != key) {
        _giveUpReach(origin);
        return;
      }
      _endReach();
      firstTabStopIn(node)?.requestFocus();
      _revealReturned(node, key);
      return;
    }
    final estimate = frames == 0 ? null : _estimateTowards(index.slot);
    if (estimate == null) {
      _giveUpReach(origin);
      return;
    }
    final position = estimate.position;
    final start = origin ?? (position: position, pixels: position.pixels);
    // The estimate re-derives the position each frame, so this jump and the
    // origin record below stay positions the Scrollable held when read; a
    // later swap is sorted out where the record returns.
    position.jumpTo(estimate.offset);
    WidgetsBinding.instance
      ..addPostFrameCallback(
        (_) => _reach(token, index, key, settled, frames - 1, start),
      )
      ..scheduleFrame();
  }

  /// Gives up a reach that did not reach its slot (R5): the list returns
  /// to [origin], the offset it held before the reach's first jump, so the
  /// gap's neighbors are built again, and after that frame it hands focus
  /// on from the gap (E04), so focus is never lost. Until then the gap
  /// waits in [_givenUpGaps], where a call made during the jump back or
  /// earlier in the next post-frame batch moves it (D7). The offset
  /// returns on the list's live [ScrollPosition]: the Scrollable may have
  /// replaced and disposed [origin]'s position while the reach ran, a
  /// physics or controller swap, and R5 saves the offset, never the
  /// position object, so no position the Scrollable no longer holds takes
  /// a call.
  void _giveUpReach(({ScrollPosition position, double pixels})? origin) {
    final gap = _reachGap;
    _endReach();
    if (gap == null) return;
    if (origin != null) {
      final live = _livePositionOf(origin.position);
      if (live != null && live.pixels != origin.pixels) {
        // Held before the jump: its scroll notifications may reach an app
        // listener that calls the controller at once.
        final held = _HeldGap(gap);
        _givenUpGaps.add(held);
        live.jumpTo(
          origin.pixels.clamp(live.minScrollExtent, live.maxScrollExtent),
        );
        WidgetsBinding.instance
          ..addPostFrameCallback((_) {
            _givenUpGaps.remove(held);
            _handOffFocus(held.index);
          })
          ..scheduleFrame();
        return;
      }
    }
    _handOffFocus(gap);
  }

  /// The position the list's [Scrollable] holds now. [origin]'s own
  /// position may be gone: a physics or controller swap replaces and
  /// disposes it mid-flight, and a disposed position takes no call, so the
  /// return reads the Scrollable's current one.
  ScrollPosition? _livePositionOf(ScrollPosition origin) {
    if (!mounted) return null;
    final context = origin.context.notificationContext;
    final scrollable = context == null ? null : Scrollable.maybeOf(context);
    return scrollable?.position;
  }

  /// The scroll offset that puts [slot] at its viewport's leading edge,
  /// estimated by the average extent of the built items, with the position
  /// it applies to; null when no item is laid out. The offsets come from
  /// [RenderAbstractViewport.getOffsetToReveal], so the estimate follows a
  /// reversed, horizontal, or right-to-left axis. Slots are the only
  /// geometry: the sliver keeps each slot's offset by its number.
  ({ScrollPosition position, double offset})? _estimateTowards(int slot) {
    final boxes = <int, ({FocusNode node, RenderBox box})>{
      for (final MapEntry(key: index, value: node) in _itemNodes.entries)
        if (node.context?.findRenderObject() case final RenderBox box
            when box.attached && box.hasSize)
          index.slot: (node: node, box: box),
    };
    if (boxes.isEmpty) return null;
    final slots = boxes.keys.toList()..sort();
    final first = slots.first;
    final last = slots.last;
    final firstBox = boxes[first]!.box;
    final context = boxes[first]!.node.context;
    final position = context == null
        ? null
        : Scrollable.maybeOf(context)?.position;
    if (position == null) return null;
    final viewport = RenderAbstractViewport.of(firstBox);
    final from = viewport.getOffsetToReveal(firstBox, 0).offset;
    final to = viewport.getOffsetToReveal(boxes[last]!.box, 0).offset;
    final size = firstBox.size;
    final extent = last > first
        ? (to - from) / (last - first)
        : (_layout.scrollDirection == Axis.vertical ? size.height : size.width);
    final offset = (from + (slot - first) * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    return (position: position, offset: offset);
  }

  /// Readies the slot the focused item whose key node is [node] enters at
  /// [to] of the current data for the next frame, when the last frame did
  /// not lay that slot number out ([_enteredSlot], invariant 35): a near
  /// slot ([_nearExtra]) has the next frame build ahead to it, with no
  /// scroll in this turn ([_askAhead], D1); a farther one takes the jump of
  /// [_jumpForMove]. The item's key comes from its built slot, so the list
  /// never calls `itemBuilder` here. Returns the offset before the jump,
  /// where a failed reach returns (R5); null with no jump.
  ({ScrollPosition position, double pixels})? _buildAheadOrJump(
    _DataIndex to,
    FocusNode node,
  ) {
    final entered = _enteredSlot(to);
    if (_builtSlot(entered)) return null;
    final item = node.context;
    final position = item == null ? null : Scrollable.maybeOf(item)?.position;
    if (item == null || position == null) return null;
    final extra = _nearExtra(entered, position);
    if (extra != null) {
      _askAhead(node, _baseCacheExtent(position) + extra);
      return null;
    }
    final origin = _jumpForMove(to, item, position);
    if (origin != null) _watchFarJump(node, origin);
    return origin;
  }

  /// Has the next frame, at its start, read whether the item whose key node
  /// is [node] still holds focus after the turn of its far move's jump,
  /// whose offset before the jump is [origin] (R13).
  void _watchFarJump(
    FocusNode node,
    ({ScrollPosition position, double pixels}) origin,
  ) {
    if (_farJumps.isEmpty) {
      WidgetsBinding.instance.scheduleFrameCallback((_) => _readFarJumps());
    }
    _farJumps.add((node: node, origin: origin));
  }

  /// At the start of the frame after far moves, before its build and its
  /// layout: unwound newest first, an item that no longer holds focus
  /// returns the list to its own origin, since the app moved focus off it
  /// in the move's turn. The unwind stops at the first item that still
  /// holds focus (R13): that item's own jump already left the list where
  /// it belongs, and every older jump's origin is subsumed by it.
  void _readFarJumps() {
    final jumps = [..._farJumps];
    _farJumps.clear();
    if (!mounted) return;
    for (final jump in jumps.reversed) {
      if (jump.node.hasFocus) break;
      final live = _livePositionOf(jump.origin.position);
      live?.jumpTo(
        jump.origin.pixels.clamp(live.minScrollExtent, live.maxScrollExtent),
      );
    }
  }

  /// The cache extent past the layout's own that builds [slot] in the next
  /// frame, when [slot] is near: its distance in slots past the laid-out
  /// range, on either side, plus a 1-slot margin, times the laid-out
  /// children's average extent, fits within one viewport extent along the
  /// main axis (D1). Null for a farther slot, or with nothing laid out.
  double? _nearExtra(int slot, ScrollPosition position) {
    final laid = _laidOut();
    if (laid == null || !position.hasViewportDimension) return null;
    final distance = slot > laid.last ? slot - laid.last : laid.first - slot;
    final extra = (distance + 1) * laid.extent;
    return extra <= position.viewportDimension ? extra : null;
  }

  /// The layout's `scrollCacheExtent` in pixels for [position]: a value
  /// relative to the viewport converts first, so the build-ahead adds to
  /// pixels (D7); none is Flutter's default.
  double _baseCacheExtent(ScrollPosition position) {
    final extent = _layout.scrollCacheExtent;
    if (extent == null) return RenderAbstractViewport.defaultCacheExtent;
    return switch (extent.style) {
      CacheExtentStyle.pixel => extent.value,
      CacheExtentStyle.viewport => extent.value * position.viewportDimension,
    };
  }

  /// Has the next frame build with a cache extent of [cache] pixels on
  /// both sides of the viewport, for the focused item whose key node is
  /// [node] (D1), and returns to the layout's own extent once that frame's
  /// post-frame callbacks, the item's reveal among them, have run (D3).
  /// Each change rebuilds the viewport alone ([_ReorderScrollView]).
  void _askAhead(FocusNode node, double cache) {
    final ask = _AheadAsk(node, cache);
    _aheadAsks.add(ask);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scheduleMicrotask(() {
        if (mounted) _aheadAsks.remove(ask);
      }),
    );
  }

  /// Jumps in a move's turn toward the slot the focused item [item] enters
  /// at [to] of the current data, when that slot is not near: exactly to
  /// the start or end for an edge slot, as a key move to either end does,
  /// else by [_estimateTowards] at slot [to] (FR-05 E04). Returns the
  /// offset before the jump, where a failed reach returns (R5); null with
  /// no jump.
  ({ScrollPosition position, double pixels})? _jumpForMove(
    _DataIndex to,
    BuildContext item,
    ScrollPosition position,
  ) {
    final origin = (position: position, pixels: position.pixels);
    const start = _DataIndex(0);
    if (to == start || to == _dataEnd - 1) {
      _jumpTowards(item, position, toStart: to == start);
      return origin;
    }
    final estimate = _estimateTowards(to.nextSlot);
    if (estimate == null) return null;
    estimate.position.jumpTo(estimate.offset);
    return origin;
  }

  /// Whether the last frame laid out [slot]: a question of geometry, so
  /// it reads slot numbers, never an index converted between the spaces,
  /// and the sliver's laid-out children ([_laidOut]), never [_itemNodes],
  /// which keeps a kept-alive item's slot after it leaves (FR-05 E12).
  bool _builtSlot(int slot) {
    final laid = _laidOut();
    return laid != null && slot >= laid.first && slot <= laid.last;
  }

  /// The first and last slot the list's sliver laid out in the last frame,
  /// and their average extent along the main axis; null when it laid out
  /// none. The sliver's child list holds only laid-out children: Flutter
  /// moves a kept-alive child out of it into its keep-alive bucket
  /// (`_destroyOrCacheChild`), so an item kept alive off screen never
  /// counts (invariant 35).
  ({int first, int last, double extent})? _laidOut() {
    final sliver = _sliver();
    final firstChild = sliver?.firstChild;
    final lastChild = sliver?.lastChild;
    if (sliver == null || firstChild == null || lastChild == null) {
      return null;
    }
    final first = sliver.indexOf(firstChild);
    final last = sliver.indexOf(lastChild);
    final size = lastChild.size;
    final lastExtent = sliver.constraints.axis == Axis.vertical
        ? size.height
        : size.width;
    final start = sliver.childScrollOffset(firstChild) ?? 0;
    final end = (sliver.childScrollOffset(lastChild) ?? 0) + lastExtent;
    return (
      first: first,
      last: last,
      extent: (end - start) / (last - first + 1),
    );
  }

  /// The sliver that lays out this list's items: the render object of the
  /// [SliverReorderableList] the list's key holds, so no item and no drag
  /// proxy is asked.
  RenderSliverMultiBoxAdaptor? _sliver() {
    final sliver = _listKey.currentContext?.findRenderObject();
    return sliver is RenderSliverMultiBoxAdaptor ? sliver : null;
  }

  /// The slot the item at [to] of the current data enters in the next
  /// frame, for a move either way (invariant 35). The next frame anchors
  /// its layout at the first slot the last frame built, so the count
  /// starts there: that slot plus the boxes the next frame draws at full
  /// extent from it through [to]. Those are the items before [to], save
  /// an insert of this turn that grows in from 0 px, and each exit started
  /// since the last build, the slot a move left or the leaving copy of a
  /// built item, unless exits take no room. A box before that first slot
  /// counts nothing, and a target before it enters a slot the last frame
  /// did not build. Slots only, as [_builtSlot] reads them.
  int _enteredSlot(_DataIndex to) {
    final slot = to.nextSlot;
    final built = _laidOut()?.first;
    if (built == null || slot < built) return slot;
    final first = built;
    bool counts(int at) => at >= first && at <= slot;
    var entered = slot;
    // The built-in transition starts an insert at 0 px; a fixed extent,
    // reduced motion, or a caller transition gives it its room.
    if (_layout.itemTransitionBuilder == null &&
        !_fixedExtent &&
        !reducesMotion(context)) {
      entered -= _pendingInserts.where((insert) {
        final at = insert.index.nextSlot;
        return at < slot && counts(at);
      }).length;
    }
    if (!_exitsTakeNoExtent(context)) {
      entered += _exits.where((exit) {
        final gap = exit.gap;
        return exit.fresh && gap != null && counts(gap.nextSlot);
      }).length;
    }
    return entered;
  }

  /// After the frame that moved the focused item [key] (FR-05 E04): with
  /// its State kept, it keeps focus and is revealed twice; with its State
  /// gone after a missed estimate, the list reaches the item's slot, read
  /// by key from the settling build ([_followAt]), for another call in the
  /// move's own turn may have shifted the data under the move's own
  /// indices. With no settled slot for the key, a later call took the item
  /// or a count change reset the frame (E12), the follow runs the give-up
  /// path: it returns to [origin], the offset before the call-turn jump,
  /// else the one before the reach's own first jump, and hands focus on
  /// from the gap the frame left, the slot the item left (R5). The follow
  /// fields belong to the newest move: a follow whose key they no longer
  /// name waits for that move's own callback and does nothing here.
  void _followMoved(
    FocusNode node,
    Key key,
    ({ScrollPosition position, double pixels})? origin,
  ) {
    if (_followKey != key) return;
    final gap = _followGap;
    final at = _followAt;
    _followGap = null;
    _followKey = null;
    _followAt = null;
    if (!mounted) return;
    if (node.context != null && _itemNodes.containsValue(node)) {
      if (node.hasFocus) _revealReturned(node, key);
      return;
    }
    // Focus the app moved in the same turn stays where the app put it.
    if (FocusManager.instance.primaryFocus != null) return;
    if (gap == null) return;
    if (at != null) {
      _startReach(at, key, gap, origin: origin);
      return;
    }
    // The moved item's key never settled back into the data: the reach has
    // nothing to reach, so it gives up at once and hands focus on.
    _reachGap = gap;
    _giveUpReach(origin);
  }

  /// The first node in Tab order inside the built item at [index], revealed
  /// by [firstTabStopIn]; null when the item is not built or holds none.
  FocusNode? _firstStopOf(_FrameIndex index) {
    final node = _nodeAt(index);
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
      index: _FrameIndex(index),
      body: this,
      look: item,
      exiting: exiting,
      child: current,
    );
  }

  /// A removed item as it leaves: its kept look, or the look its
  /// `removeItem` builder makes, inside the remove transition.
  Widget _exitChild(BuildContext context, _Exit exit) {
    // The slot a moved item left: no look, no State, and no caller
    // transition; it shrinks by what the moved item grows (FR-05 E03).
    if (exit.closing) {
      final size = exit.size!;
      return KeyedSubtree(
        key: ObjectKey(exit),
        child: SizeTransition(
          axis: _layout.scrollDirection,
          sizeFactor: ReverseAnimation(exit.motion.curved),
          child: _layout.scrollDirection == Axis.vertical
              ? SizedBox(height: size.height)
              : SizedBox(width: size.width),
        ),
      );
    }
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
      // The widgets `ReorderableList`'s own tree, built here so the key
      // reaches the sliver (invariant 35) and the viewport alone follows
      // the build-ahead (D3).
      child: _ReorderScrollView(
        aheadAsks: _aheadAsks,
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
        slivers: [
          SliverPadding(
            padding: widget.padding ?? EdgeInsets.zero,
            sliver: SliverReorderableList(
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
              autoScrollerVelocityScalar: layout.autoScrollerVelocityScalar,
            ),
          ),
        ],
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

  final _FrameIndex index;
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

  /// The status listener of the reveal that waits for this motion to
  /// complete, so every path that ends the motion early can take it off.
  AnimationStatusListener? grown;

  /// Takes [grown] off this motion's controller, if one is still on.
  void dropGrown() {
    final listener = grown;
    if (listener == null) return;
    controller.removeStatusListener(listener);
    grown = null;
  }

  void dispose() {
    dropGrown();
    curved.dispose();
    controller.dispose();
  }
}

/// An insert the next build has not settled: the item's index in the
/// current data, and its motion.
class _PendingInsert {
  new(this.index, this.motion);

  _DataIndex index;
  final _ItemMotion motion;
}

/// A removed item that plays its remove animation.
class _Exit {
  new({
    required this.subKey,
    required this.look,
    required this.builder,
    required this.motion,
    required _DataIndex this.gap,
    this.closing = false,
  });

  /// The removed item's key.
  final Key subKey;

  /// The widget `itemBuilder` last built for the item.
  final Widget look;

  /// The `removeItem` builder that replaces [look], if any.
  final WidgetBuilder? builder;

  /// Whether this is the slot a moved item left: an empty box of [size],
  /// with no look and no State, that closes in step with the item's entry.
  final bool closing;
  final _ItemMotion motion;

  /// Where the item left, as an index of the current data: before the item
  /// at [gap]. Null once a build has found [hostKey].
  _DataIndex? gap;

  /// The key of the item whose slot shows this one, [before] it or after.
  Key? hostKey;
  bool before = true;

  /// Whether the exit holds the item's global key and State; false once
  /// the same key is back in the data under a `builder` look.
  bool keepsState = true;

  /// The item's laid-out size at `removeItem`, which a fixed extent keeps.
  Size? size;

  /// Whether the exit started after the last build, so the next frame
  /// draws a box the last one did not (invariant 35).
  bool fresh = true;
}

/// A position in the app's data after this turn's `insertItem`,
/// `removeItem`, and `moveItem` calls and the moves the list reported
/// through `onReorderItem`. It becomes a [_FrameIndex] only through
/// `_builtIndexOf`; its `value` leaves it only in `_builtIndexOf` (its
/// argument and the entries of `_pending`), in `_dataIndexOf` (the entries
/// of `_pending`), in [nextSlot], and at `onReorderItem` and
/// `itemBuilder`.
extension type const _DataIndex(int value) {
  /// The slot the item at this index takes in the next frame: the sliver
  /// keeps each slot's offset by its number across a rebuild.
  int get nextSlot => value;

  bool operator <(_DataIndex other) => value < other.value;

  bool operator <=(_DataIndex other) => value <= other.value;

  bool operator >(_DataIndex other) => value > other.value;

  bool operator >=(_DataIndex other) => value >= other.value;

  _DataIndex operator +(int offset) => _DataIndex(value + offset);

  _DataIndex operator -(int offset) => _DataIndex(value - offset);
}

/// A position in the frame the list last built: the keys of `_itemNodes`
/// and `_itemLooks`, and the index the SDK reports. It becomes a
/// [_DataIndex] only through `_dataIndexOf`; its `value` leaves it only
/// there (its argument), in [slot], and at `onReorderEnd` for the
/// `_dragIndex` of a drag the list ends (`_cancelDrag`,
/// `_reportCountEnd`).
extension type const _FrameIndex(int value) {
  /// The slot this index held in the last frame.
  int get slot => value;

  bool operator <(_FrameIndex other) => value < other.value;

  bool operator >(_FrameIndex other) => value > other.value;

  _FrameIndex operator +(int offset) => _FrameIndex(value + offset);

  _FrameIndex operator -(int offset) => _FrameIndex(value - offset);
}

/// What a reorder key or a screen reader's move action asks for: the four
/// moves of FR-02 and FR-03 E03.
enum _MoveIntent { start, previous, next, end }

/// The index of the app's data a key move, a screen-reader move, or a drop
/// put its item at, moved by each later call until the frame after the
/// move reads it; null once a call takes the item out.
class _MoveTarget {
  new(this.index, {this.key, this.gap, this.origin});

  _DataIndex? index;

  /// For a focused one-slot move (FR-03 E09): the item's key, which the
  /// reach looks for.
  final Key? key;

  /// For a focused one-slot move: the gap the item left, before the item at
  /// this index of the current data, moved by each later call as [index]
  /// is; the reach hands focus on from it when it gives up.
  _DataIndex? gap;

  /// For a focused one-slot move that jumped in its turn: the offset before
  /// the jump, where a reach that gives up returns (R5).
  final ({ScrollPosition position, double pixels})? origin;
}

/// The list's scroll view: a [CustomScrollView] whose viewport alone
/// listens to [aheadAsks]. A build-ahead widens and returns the cache
/// extent by rebuilding the viewport while the sliver widgets stay the
/// same instances, so no item rebuilds, and every build of the viewport,
/// a rebuild of the [Scrollable] alone among them, reads the asks as they
/// stand (D3).
class _ReorderScrollView extends CustomScrollView {
  const new({
    required this.aheadAsks,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.shrinkWrap,
    super.scrollCacheExtent,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.clipBehavior,
    super.slivers,
  });

  /// The near slots focused moves asked to build ahead to.
  final _AheadAsks aheadAsks;

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) {
    return ListenableBuilder(
      listenable: aheadAsks,
      builder: (context, _) {
        final cache = aheadAsks.cache;
        final extent = cache == null
            ? scrollCacheExtent
            : ScrollCacheExtent.pixels(cache);
        if (shrinkWrap) {
          return ShrinkWrappingViewport(
            axisDirection: axisDirection,
            offset: offset,
            slivers: slivers,
            paintOrder: paintOrder,
            clipBehavior: clipBehavior,
            scrollCacheExtent: extent,
          );
        }
        return Viewport(
          axisDirection: axisDirection,
          offset: offset,
          slivers: slivers,
          scrollCacheExtent: extent,
          center: center,
          anchor: anchor,
          clipBehavior: clipBehavior,
          paintOrder: paintOrder,
        );
      },
    );
  }
}

/// The near slots focused moves asked the next frame to build ahead to,
/// each until that frame's post-frame callbacks have run (D1, D3); each
/// change notifies the list's viewport.
class _AheadAsks extends ChangeNotifier {
  final _asks = <_AheadAsk>[];

  void add(_AheadAsk ask) {
    _asks.add(ask);
    notifyListeners();
  }

  void remove(_AheadAsk ask) {
    if (_asks.remove(ask)) notifyListeners();
  }

  /// The cache extent in pixels the viewport builds with: the largest one
  /// asked for whose item still holds focus, read as the viewport builds,
  /// so an item the app took focus from in the move's turn counts as
  /// unfocused and never builds ahead (R13); null keeps the layout's own
  /// (D1).
  double? get cache {
    double? cache;
    for (final ask in _asks) {
      if (!ask.node.hasFocus) continue;
      if (cache == null || ask.cache > cache) cache = ask.cache;
    }
    return cache;
  }
}

/// A focused move's request that the next frame build ahead to the near
/// slot it enters (D1).
class _AheadAsk {
  new(this.node, this.cache);

  /// The moved item's key node.
  final FocusNode node;

  /// The cache extent in pixels the frame builds with on both sides of the
  /// viewport: the layout's own plus the near slot's extra.
  final double cache;
}

/// A gap of the app's data, before the item at [index], that a reader
/// takes after a frame; moved by each later call until then.
class _HeldGap {
  new(this.index);

  _DataIndex index;
}
