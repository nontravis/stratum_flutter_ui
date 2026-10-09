import 'package:flutter/rendering.dart'
    show
        ItemExtentBuilder,
        RenderAbstractViewport,
        RenderSliverMultiBoxAdaptor,
        ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
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
    this.findChildIndexCallback,
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

  /// Returns the index in the app's current data of the item whose key is
  /// [key], the key [itemBuilder] gave it; null when the app does not know
  /// it. An answer outside `0` to `itemCount - 1` counts as null.
  ///
  /// Give it when the app reorders its data with no
  /// [StratumReorderableItemsController.moveItem] call, as a live sync
  /// does: an item that holds focus then keeps its State and focus at every
  /// distance and the list scrolls to it, one frame after a `moveItem`
  /// would, and an item the app keeps alive follows the reorder. The list
  /// asks once per built, cached, or kept-alive item on each build of the
  /// list, plus once for the focused item, and never while it only
  /// scrolls, so read an O(1) key-to-index map the app keeps in sync with
  /// its data, never a search of the data.
  final ChildIndexGetter? findChildIndexCallback;

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
  final _pending = <_Call>[];

  /// The calls the last build settled out of [_pending], until the end of
  /// its frame: an item that frame drops last drew at an index of the data
  /// before them ([_focusedItemGone]).
  var _settledPending = const <_Call>[];

  /// The node the list focuses while a handoff reaches toward a gap with no
  /// laid-out neighbor (D10): it never scrolls away, takes no Tab stop, and
  /// a focus the app moves off it ends the reach (R13). It has no
  /// semantics, so it lets focus go when the reach finds no target
  /// ([_handOffFocus]).
  final _holdNode = FocusNode(
    debugLabel: 'ReorderableListViewLayout hold',
    skipTraversal: true,
  );

  /// Whether this State sits in the tree: false from [deactivate], so an
  /// item that leaves with the whole list hands no focus on.
  var _inTree = true;

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
  /// `onReorderEnd`; null with no drag. Only [_handleReorderStart] sets it
  /// and only [_endDrag], the drag's one exit, clears it.
  _FrameIndex? _dragIndex;

  /// Whether [_cancelDrag] is canceling the SDK's drag: it reports that end
  /// at once itself, so [_handleListReset] leaves it alone.
  var _cancelingByCall = false;

  /// The key of the item a drag lifted and the index its drag started at,
  /// from `onReorderStart` until the drag proxy lets the item go, or until
  /// the drag ends before the proxy took it: a build that finds another
  /// key at that index ends the drag (FR-01 E07).
  ({Key key, _FrameIndex start})? _dragged;

  /// The item count the last build gave [SliverReorderableList].
  int? _listCount;

  /// Where each key move, screen-reader move, or drop of this frame put its
  /// item, as an index of the current data, until the frame after it
  /// reveals the item: each call moves them, as it moves [_handoffGap].
  final _moveTargets = <_MoveTarget>[];

  /// The reveal jumps booked for the next frame's start, in booking order
  /// (invariant 35): a move's turn scrolls nothing.
  final _frameJumps = <_FrameJump>[];

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

  /// The follow of a raw move of the lifted item, with the item's key
  /// node, until the end of the frame the drag proxy lets the item go
  /// ([_liftedLetGo]): until then the proxy holds the item outside its
  /// slot (invariant 28), and until the build after that the item has no
  /// registration, so the watch reads it from here ([_watchedKeys]).
  ({_MoveTarget target, FocusNode node})? _liftedFollow;

  /// Reaches [SliverReorderableListState.cancelReorder] and the list's
  /// sliver ([_sliver]) through the list's own [_ReorderSliverState].
  final _listKey = GlobalKey<SliverReorderableListState>();

  /// The index each item a move the list knows put in a slot the last
  /// frame did not lay out takes in this build, by the item's key: the
  /// sliver's `findChildIndexCallback` moves the item's element there in
  /// place (invariant 35). Filled by [_resolvePending], emptied after the
  /// frame.
  final _movedTo = <Key, int>{};

  /// The item key [_buildItem] read last, for [_rewrapped].
  Key? _builtKey;

  /// The frame of each built item, by the item's key: the keep-alive client
  /// a park flags (invariant 35).
  final _frames = <Key, _ParkFrameState>{};

  /// The key of the focused moved item kept alive off screen until it is
  /// laid out and revealed (invariant 35); null with none. Only the item
  /// that holds focus parks, so at most one item is parked.
  Key? _parkedKey;

  /// The parked item's index in the current data, which every later
  /// `insertItem`, `removeItem`, and `moveItem` shifts until its release,
  /// so its element follows the data in place; null once a call takes the
  /// item out.
  _DataIndex? _parkedAt;

  /// The frame the park flagged: the client that existed when the item
  /// parked, since a client built later that asks for a keep-alive in its
  /// first build trips a framework assert when it is released first.
  _ParkFrameState? _parkedFrame;

  /// The parked item's key node, which the watch reads even when another
  /// item took its registration, as a lifted item's is (invariant 35).
  FocusNode? _parkedNode;

  /// The frame kept alive because a node inside its item holds primary
  /// focus (R29); at most one.
  _ParkFrameState? _focusFrame;

  /// Whether a [_holdFocusedFrame] waits for the end of the frame.
  var _focusFrameQueued = false;

  ReorderableListViewLayout get _layout => widget.layout;

  @override
  void initState() {
    super.initState();
    _dataCount = _layout.itemCount;
    _layout.itemsController?._attach(this);
    FocusManager.instance.addListener(_holdFocusedFrame);
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
    _inTree = true;
    _layout.itemsController?._attach(this);
  }

  @override
  void deactivate() {
    _inTree = false;
    _layout.itemsController?._detach(this);
    super.deactivate();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_holdFocusedFrame);
    _layout.itemsController?._detach(this);
    _resetMotion();
    _holdNode.dispose();
    super.dispose();
  }

  /// Keeps alive the frame of the item a node inside of which holds primary
  /// focus, and releases the frame kept before (R29): a focused item the
  /// user scrolls away keeps its State and focus off screen until focus
  /// leaves it.
  void _holdFocusedFrame() {
    if (!mounted) return;
    _ParkFrameState? frame;
    for (final MapEntry(key: index, value: node) in _itemNodes.entries) {
      if (!node.hasFocus) continue;
      final key = _lookAt(index)?.key;
      if (key != null) frame = _frames[key];
      break;
    }
    if (frame == _focusFrame) return;
    final old = _focusFrame;
    _focusFrame = frame;
    if (old != null && old.mounted) old.setHeld(held: false);
    frame?.setHeld(held: true);
  }

  /// Brings the item of [keys], kept alive off screen with focus inside,
  /// back into view, then runs [then]: jumps toward its slot by
  /// [_estimateTowards] each frame until a frame lays it out, for up to
  /// [frames] frames, then reveals it by its own box. Stops when focus left
  /// the item; after the last jump, runs [then] where the item stands.
  void _bringBack(
    _ReorderKeysState keys,
    VoidCallback then, {
    int frames = _reachFrames,
  }) {
    if (!mounted || !keys.mounted || !keys._node.hasFocus) return;
    final slot = keys.widget.index.slot;
    if (_builtSlot(slot)) {
      revealInViewports(keys._node);
      then();
      return;
    }
    final estimate = frames == 0 ? null : _estimateTowards(slot);
    if (estimate == null) {
      then();
      return;
    }
    estimate.position.jumpTo(estimate.offset);
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _bringBack(keys, then, frames: frames - 1))
      ..scheduleFrame();
  }

  /// Runs [_holdFocusedFrame] after this frame: a frame built for the item
  /// that holds focus, with no focus move, takes the hold over.
  void _queueFocusFrame() {
    if (_focusFrameQueued) return;
    _focusFrameQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusFrameQueued = false;
      _holdFocusedFrame();
    });
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
      // Once the call's frame is laid out, before its post-frame callbacks:
      // a focus request the app makes in any of them wins (R27, R13).
      _runAfterLayout(() {
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
          // Parked off screen: registered, but not laid out (E17).
          if (returnAt != null && !_builtSlot(returnAt.slot)) {
            if (node.hasFocus || primary == null) {
              _startReach(returnAt, key, gap);
            } else {
              _releasePark(key);
            }
            return;
          }
          _releasePark(key);
          if (!node.hasFocus && primary != null) return;
          if (!node.hasFocus) {
            firstTabStopIn(node, reveal: false)?.requestFocus();
          }
          // The reveal scrolls, so it waits for the post-frame callbacks.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _itemNodes.containsValue(node)) {
              _revealReturned(node, key);
            }
          });
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
        _requestHandOff(gap);
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
    // A move of the item a reach looks for re-aims it: the move's own
    // follow takes over, and the item stays parked (invariant 32).
    if (key != null && key == _reachKey) _stopReach();
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
        !context.reducesMotion) {
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
      _followKey = key;
      _followGap = from < to ? from : from + 1;
      // A focused item whose new slot the last frame did not lay out books
      // a jump toward it at the next frame's start, and the build that
      // moves it parks it until it is laid out (E04). Asked after the
      // booking, which starts the boxes that slot counts. The target lives
      // among [_moveTargets], so each later call shifts it until the jump
      // reads it.
      final target = _MoveTarget(to);
      _bookMoveJump(to, node, target, owned: true);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _followMoved(node, key, target.origin),
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
  ///
  /// [calls], when given, replaces [_pending], as the calls a build settled
  /// replay an index of the frame before that build.
  _DataIndex? _dataIndexOf(_FrameIndex index, {List<_Call>? calls}) {
    var i = index.value;
    for (final call in calls ?? _pending) {
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
    final parked = _parkedAt;
    if (parked != null && parked >= index) _parkedAt = parked + 1;
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
    final parked = _parkedAt;
    if (parked != null && parked >= index) {
      // A call that takes the parked item out releases it at the next build.
      _parkedAt = parked == index ? null : parked - 1;
    }
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
    final explained = count == _dataCount;
    // Read before the clear: where this turn's calls put each watched key.
    final watched = _watchedKeys();
    if (!explained) _resetMotion();
    _dataCount = count;
    if (_pending.isNotEmpty) {
      _settledPending = List.of(_pending);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _settledPending = const [],
      );
    }
    _pending.clear();
    Key? keyAt(_DataIndex index) =>
        layout.itemBuilder(context, index.value).key;
    // A count the calls do not explain moves nothing the list can follow,
    // and ends the park (E12), unless the app's callback follows each
    // watched key by its key (R25): then the booked targets, which no call
    // shifted across that count, give way to the app's answers.
    if (explained || _layout.findChildIndexCallback != null) {
      final dropped = explained ? const <Key>{} : _dropMoveTargets();
      _bookMovedKeys(keyAt, watched, dropped);
    } else {
      _movedTo.clear();
      _releasePark();
    }
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

  /// Maps each item a move the list knows put in a slot the last frame did
  /// not lay out to its index in this build ([_movedTo]): a key move, a
  /// screen-reader move, or a drop ([_moveTargets]), and a `moveItem` call
  /// or a same-turn `removeItem` and `insertItem` of one key
  /// ([_pendingInserts]), and a raw move of a [watched] key
  /// ([_bookRawMoves]), booked again for each key in [dropped]. Read before
  /// the build settles the inserts and the fresh exits, which
  /// [_enteredSlot] counts.
  void _bookMovedKeys(
    Key? Function(_DataIndex index) keyAt,
    List<_Watched> watched,
    Set<Key> dropped,
  ) {
    _movedTo.clear();
    final known = <Key>{};
    for (final target in _moveTargets) {
      final at = target.index;
      final key = at == null ? null : keyAt(at);
      if (at == null || key == null) continue;
      known.add(key);
      _bookMovedKey(key, at);
    }
    for (final insert in _pendingInserts) {
      final key = keyAt(insert.index);
      if (key == null) continue;
      known.add(key);
      _bookMovedKey(key, insert.index);
    }
    _bookRawMoves(watched, known, dropped);
    _bookParkedKey();
    if (_movedTo.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _movedTo.clear());
  }

  /// Maps the item [key], which a move put at [at] of the data, when the
  /// last frame did not lay out the slot it enters (invariant 35), and
  /// parks it when it holds focus; every other item takes the delegate's
  /// default path.
  void _bookMovedKey(Key key, _DataIndex at) {
    if (_builtSlot(_enteredSlot(at))) return;
    _movedTo[key] = at.value;
    final node = _registeredNodeOf(key);
    if (node != null && node.hasFocus) _park(key, at, node);
  }

  /// Maps the parked item to its index after this turn's calls, so its
  /// element follows an insert or remove in place; a parked item a call
  /// took out is released.
  void _bookParkedKey() {
    final key = _parkedKey;
    if (key == null) return;
    final at = _parkedAt;
    if (at == null) {
      _releasePark();
      return;
    }
    _movedTo.putIfAbsent(key, () => at.value);
  }

  /// The keys a build asks the app's `findChildIndexCallback` about, each
  /// with its key node and the index of the current data this turn's calls
  /// put it at: the parked item, by [_parkedAt]; the lifted item a raw move
  /// took, by its follow's target ([_liftedFollow]); and the item that
  /// holds primary focus, by [_dataIndexOf]. Read before the build clears
  /// [_pending]; empty with no callback (invariant 35).
  List<_Watched> _watchedKeys() {
    if (_layout.findChildIndexCallback == null) return const [];
    final parkedKey = _parkedKey;
    final parkedAt = _parkedAt;
    final parkedNode = _parkedNode;
    final watched = <_Watched>[
      if (parkedKey != null && parkedAt != null && parkedNode != null)
        (key: parkedKey, at: parkedAt, node: parkedNode),
    ];
    // Another item takes a lifted item's registration while the proxy
    // holds it, so the walk would miss the item a raw move took.
    Key? liftedKey;
    if (_liftedFollow case (:final target, :final node)) {
      final (key, at) = (target.key, target.index);
      if (key != null && at != null && key != parkedKey) {
        liftedKey = key;
        watched.add((key: key, at: at, node: node));
      }
    }
    for (final MapEntry(key: index, value: node) in _itemNodes.entries) {
      final key = _lookAt(index)?.key;
      if (key == null || key == parkedKey || !node.hasFocus) continue;
      if (key == liftedKey) continue;
      final at = _dataIndexOf(index);
      if (at != null) watched.add((key: key, at: at, node: node));
    }
    return watched;
  }

  /// Asks the app where each [watched] key sits in its data: an answer that
  /// differs from the index this turn's calls give the key, with no move of
  /// it the list knows ([known]), is a raw move ([_bookRawMove]), and so is
  /// any answer for a key whose move target the build dropped ([dropped]).
  /// A null answer, or one past the data, books none; for the parked key it
  /// means the key left the data ([_releaseGone]).
  void _bookRawMoves(List<_Watched> watched, Set<Key> known, Set<Key> dropped) {
    final app = _layout.findChildIndexCallback;
    if (app == null) return;
    for (final (:key, :at, :node) in watched) {
      if (known.contains(key)) continue;
      final answer = app(key);
      if (answer == null || answer < 0 || answer >= _dataCount) {
        if (key == _parkedKey) _releaseGone(key);
        continue;
      }
      final to = _DataIndex(answer);
      if (to != at || dropped.contains(key)) {
        _bookRawMove(key, node, from: at, to: to);
      }
    }
  }

  /// Drops every booked move target when an item count no call explains
  /// meets the app's callback: no call shifted them across that count, so
  /// each may name another key or an index past the data. Each one's jump
  /// and follow then do nothing; returns the keys of the focused moves among
  /// them, which the watch books again from the app's answers (R25).
  Set<Key> _dropMoveTargets() {
    final keys = <Key>{};
    for (final target in _moveTargets) {
      final key = target.key;
      if (key != null) keys.add(key);
      target.index = null;
    }
    _moveTargets.clear();
    return keys;
  }

  /// Books the raw move of the watched item [key], whose key node is
  /// [node], from [from] to [to] of the current data as a move the list
  /// knows: mapped and parked when the last frame did not lay out the slot
  /// it enters, then followed ([_followRawMove]); a lifted item's follow
  /// waits for the drag proxy to let it go ([_liftedFollow]). A shift that
  /// another item's raw move gives the item books the same way. The move
  /// re-aims a reach that looks for the item, as `moveItem` does, and an
  /// earlier move of the item reveals nothing (invariant 35).
  void _bookRawMove(
    Key key,
    FocusNode node, {
    required _DataIndex from,
    required _DataIndex to,
  }) {
    if (key == _reachKey) _stopReach();
    for (final target in _moveTargets) {
      if (target.key == key) target.index = null;
    }
    if (!_builtSlot(_enteredSlot(to))) {
      _movedTo[key] = to.value;
      _park(key, to, node);
    } else if (key == _parkedKey) {
      _parkedAt = to;
    }
    final target = _MoveTarget(to, key: key, gap: from < to ? from : from + 1);
    _moveTargets.add(target);
    if (key == _liftedKey) {
      _liftedFollow = (target: target, node: node);
      return;
    }
    _followRawMove(target, node);
  }

  /// Releases the parked item [key], whose key left the app's data; the
  /// item's reach and follow end with it (R25), and its disposal hands
  /// focus on ([_focusedItemGone]).
  void _releaseGone(Key key) {
    if (key == _reachKey) _stopReach();
    for (final target in _moveTargets) {
      if (target.key == key) target.index = null;
    }
    _releasePark(key);
  }

  /// Hands focus on from where the item [key] last drew, at [slot] of the
  /// frame before, once its node held focus when it left the tree for good:
  /// whatever data change, park release, or drag end took the item (R26,
  /// invariant 26). A focused item never leaves through a scroll, which
  /// keeps it alive (R29).
  ///
  /// Runs at the item's disposal, after the frame's layout and after
  /// Flutter marked its own fallback for the detached node, so the request
  /// replaces that fallback and any later request, the app's post-frame one
  /// included, replaces it ([_requestHandOff]). A path that already places
  /// the item's focus keeps it ([_focusOwned]); a list that leaves the tree
  /// hands nothing on.
  void _focusedItemGone(_FrameIndex slot, Key? key) {
    if (!_inTree || key == null || _focusOwned(key)) return;
    final gap = _dataIndexOf(slot, calls: _settledPending);
    if (gap != null) _requestHandOff(gap);
  }

  /// Requests focus now for the node [_handOffFocus] would pick from [gap]:
  /// the first node of the laid-out item at the gap, else of the one before
  /// it, else the list's own Tab stop; with no laid-out neighbor, the hold
  /// node, while [_handOffFocus] reaches toward the gap after the frame.
  ///
  /// Called once the frame's layout is done and before its post-frame
  /// callbacks, where the tree may be locked: it scrolls and reveals
  /// nothing until the focus move after the frame, and does neither when
  /// another request replaced its own (R13).
  void _requestHandOff(_DataIndex gap) {
    final next = _builtNear(gap, 1);
    final previous = _builtNear(gap - 1, -1);
    bool laidOut(_FrameIndex? index) => index != null && _builtSlot(index.slot);
    final reach = !laidOut(next) && !laidOut(previous) && _laidOut() != null;
    final target = reach
        ? _holdNode
        : (next == null ? null : _firstStopOf(next, reveal: false)) ??
              (previous == null
                  ? null
                  : _firstStopOf(previous, reveal: false)) ??
              _ownTabStop();
    if (target == null) return;
    target.requestFocus();
    final held = _HeldGap(gap);
    if (reach) _givenUpGaps.add(held);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scheduleMicrotask(() {
        _givenUpGaps.remove(held);
        if (!mounted || FocusManager.instance.primaryFocus != target) return;
        if (reach) {
          _handOffFocus(held.index, interim: target);
        } else {
          _revealHandOff(target);
        }
      }),
    );
  }

  /// Whether a path the list runs places the focus of the item [key] when
  /// the item cannot show: a `moveItem` follow (FR-05 E04), a move's reveal
  /// ([_moveTargets]), or a reach (invariant 32). A `removeItem` needs no
  /// entry: its handoff requests after the frame's layout, after this one
  /// (E04).
  bool _focusOwned(Key key) =>
      key == _followKey ||
      key == _reachKey ||
      _moveTargets.any((target) => target.key == key && target.index != null);

  /// Follows the raw move [target] of the item whose key node is [node]:
  /// when the last frame did not lay out the slot it enters, books its jump
  /// for the next frame's start ([_bookFrameJump]) and reveals it after
  /// that frame, else after this one ([_afterMove]), which reaches the slot
  /// when the jump misses it. The build that booked the move stands in for
  /// a move's call, so the item shows one frame after a `moveItem`'s would.
  void _followRawMove(_MoveTarget target, FocusNode node) {
    final at = target.index;
    if (at == null) return;
    final binding = WidgetsBinding.instance;
    void follow(Duration _) => _afterMove(target, byKey: false);
    if (_builtSlot(_enteredSlot(at))) {
      binding.addPostFrameCallback(follow);
      return;
    }
    _bookFrameJump(node, target);
    binding.addPostFrameCallback((_) => binding.addPostFrameCallback(follow));
  }

  /// The key node the last build registered for the item [key]; null when
  /// it registered none.
  FocusNode? _registeredNodeOf(Key key) {
    for (final MapEntry(key: index, value: look) in _itemLooks.entries) {
      if (look.key == key) return _nodeAt(index);
    }
    return null;
  }

  /// Keeps the existing element of item [key], at [at] of the data, whose
  /// key node is [node], alive until it is laid out and revealed, releasing
  /// any other parked item.
  void _park(Key key, _DataIndex at, FocusNode node) {
    if (_parkedKey != key) _releasePark();
    _parkedKey = key;
    _parkedAt = at;
    _parkedNode = node;
    _parkedFrame ??= _frames[key]?..setParked(parked: true);
  }

  /// Stops keeping the parked item alive: [key]'s, or any when null.
  void _releasePark([Key? key]) {
    if (key != null && key != _parkedKey) return;
    final frame = _parkedFrame;
    _parkedKey = null;
    _parkedAt = null;
    _parkedFrame = null;
    _parkedNode = null;
    if (frame != null && frame.mounted) frame.setParked(parked: false);
  }

  /// The SDK's item at [index], from [sdkBuilder], under a frame keyed by
  /// the item's own key, never its index, so the sliver moves a mapped
  /// item's element in place ([_movedTo]).
  Widget? _rewrapped(
    NullableIndexedWidgetBuilder sdkBuilder,
    BuildContext context,
    int index,
  ) {
    _builtKey = null;
    final item = sdkBuilder(context, index);
    final key = _builtKey;
    if (item == null || key == null) return item;
    return _ParkFrame(
      key: _IndexFreeKey(key),
      body: this,
      itemKey: key,
      child: item,
    );
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
    _reportMove(
      index,
      from,
      target,
      intent: intent,
      node: node,
      edgeJump: intent == _MoveIntent.start || intent == _MoveIntent.end,
      byKey: true,
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
  /// The start and end actions, once reported, book a jump there for the
  /// next frame's start when that slot is not laid out, so the moved item
  /// keeps its State; a step action that a same-turn call shifts onto the
  /// data's first or last slot takes a focused move's jump instead
  /// ([_bookMoveJump]), not this exact one.
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
    // A drop reports no intent at all (null) and keeps its own edge jump;
    // only a step intent (previous or next) takes a focused move's jump
    // instead.
    final edgeAction =
        intent != _MoveIntent.previous && intent != _MoveIntent.next;
    final edge =
        edgeAction && (target == const _DataIndex(0) || target == _dataEnd - 1);
    _reportMove(
      index,
      from,
      target,
      intent: intent,
      node: _nodeAt(index),
      edgeJump: edge && !_builtSlot(to.slot),
      byKey: false,
    );
  }

  /// Books the move of the item the last build drew at [index], whose key
  /// node is [node], from [from] to [to] of the current data, registers its
  /// target, reports it through `onReorderItem`, and only then books its
  /// jump for the next frame's start ([_readySlot]), so a call the app's
  /// report handler makes moves the target before the jump reads it. With
  /// [edgeJump] the jump goes to the edge [to] lies at.
  void _reportMove(
    _FrameIndex index,
    _DataIndex from,
    _DataIndex to, {
    required _MoveIntent? intent,
    required FocusNode? node,
    required bool edgeJump,
    required bool byKey,
  }) {
    final key = _lookAt(index)?.key;
    _endExitsBeside(index);
    _bookReportedMove(from, to);
    final moved = _targetFor(from, to, node, key);
    _moveTargets.add(moved);
    _layout.onReorderItem(from.value, to.value);
    final toStart = to == const _DataIndex(0);
    _readySlot(moved, node, edgeJump: edgeJump, toStart: toStart);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _afterMove(moved, byKey: byKey),
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
  /// move booked from [from] to [to] of the current data. A move of an item
  /// that holds focus, whose key node is [node], whatever its intent, keeps
  /// the item's [key] and the gap it left, for its jump ([_readySlot]) and
  /// for the reach should the frame not lay its slot out ([_reachStep]).
  _MoveTarget _targetFor(
    _DataIndex from,
    _DataIndex to,
    FocusNode? node,
    Key? key,
  ) {
    if (node == null || key == null || !node.hasFocus) return _MoveTarget(to);
    // The slot the item left, by the index of the item now after it.
    return _MoveTarget(to, key: key, gap: from < to ? from : from + 1);
  }

  /// Readies the slot of the reported move [moved], whose item's key node
  /// is [node], at the index the calls so far left its target at: a
  /// focused move books its jump as a move call does ([_bookMoveJump],
  /// FR-03 E09), with no input-specific rule; else, with [edgeJump], the
  /// list books a jump to the start when [toStart], else to the end, so the
  /// moved item keeps its State (FR-03 E02). Each jump runs at the next
  /// frame's start ([_runFrameJumps]). A target a call took out readies
  /// nothing.
  void _readySlot(
    _MoveTarget moved,
    FocusNode? node, {
    required bool edgeJump,
    required bool toStart,
  }) {
    final at = moved.index;
    final item = node?.context;
    if (at == null || node == null || item == null) return;
    if (moved.key != null) {
      _bookMoveJump(at, node, moved);
      return;
    }
    if (edgeJump) _bookFrameJump(node, moved, toStart: toStart);
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
    final key = _lookAt(dragged)?.key;
    _dragged = key == null ? null : (key: key, start: dragged);
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

  /// The SDK's delegate [sdk] with each item framed by its own key. Its
  /// `findChildIndexCallback` answers a move the list knows ([_movedTo]),
  /// else the app's answer for the item's own key ([_appIndexOf]), else
  /// null (invariant 35).
  SliverChildBuilderDelegate _rebuiltDelegate(SliverChildBuilderDelegate sdk) {
    return SliverChildBuilderDelegate(
      (context, index) => _rewrapped(sdk.builder, context, index),
      childCount: sdk.childCount,
      findChildIndexCallback: (key) => key is _IndexFreeKey
          ? _movedTo[key.value] ?? _appIndexOf(key.value)
          : null,
    );
  }

  /// The slot this build draws the item [key] at, by the app's
  /// `findChildIndexCallback`; null with no callback, or when the app does
  /// not know the key or answers past its data. Each leaving item and
  /// closing gap sits inside its host's slot, one child per data item, and
  /// the sliver builds after the body cleared [_pending], so the app's
  /// index is this build's slot; [_builtIndexOf] maps to the last frame.
  int? _appIndexOf(Key key) {
    final app = _layout.findChildIndexCallback;
    if (app == null) return null;
    assert(_pending.isEmpty, 'The list sliver built with calls pending');
    if (_pending.isNotEmpty) return null;
    final at = app(key);
    if (at == null || at < 0 || at >= _dataCount) return null;
    return at;
  }

  /// The SDK's own end of a drag, a drop: reported at once with the index
  /// the SDK gives the drop (FR-04 E06).
  void _handleReorderEnd(int index) => _endDrag(now: true, at: index);

  /// Cancels a drag in progress before an insert, remove, or move, a key
  /// move or a screen-reader move among them, or one that starts before
  /// their frame (E06): the dragged item returns to its slot,
  /// `onReorderEnd` fires at once with the index the drag started at, and
  /// `onReorderItem` does not fire. A dropped item still settling ends the
  /// same way, with no second `onReorderEnd`.
  void _cancelDrag() {
    if (_inReorderStart) {
      // The drag `onReorderStart` reports is set up after it returns.
      scheduleMicrotask(() {
        if (mounted) _listKey.currentState?.cancelReorder();
      });
    } else {
      _cancelingByCall = true;
      try {
        _listKey.currentState?.cancelReorder();
      } finally {
        _cancelingByCall = false;
      }
    }
    _endDrag(now: true);
  }

  /// The list's sliver reset its drag outside [_cancelDrag]: a second
  /// pointer that takes the drag over, a pointer cancel, or an item-count
  /// change. The SDK resets inside its own `setState` or a build, so the end
  /// waits for a microtask (FR-04 E06).
  void _handleListReset() {
    if (_cancelingByCall) return;
    _endDrag(now: false);
  }

  /// The one exit of a drag: reports `onReorderEnd` once per
  /// `onReorderStart`, with [at], else the index the drag started at.
  ///
  /// - [now]: at once; otherwise in a microtask, after the SDK's own
  ///   `setState` or the build that ended the drag.
  void _endDrag({required bool now, int? at}) {
    final start = _dragIndex;
    if (start == null) return;
    _dragIndex = null;
    // A drag the proxy never took has no lifted item to watch.
    if (_liftedKey == null) _dragged = null;
    final index = at ?? start.value;
    if (now) {
      _layout.onReorderEnd?.call(index);
      return;
    }
    scheduleMicrotask(() {
      if (mounted) _layout.onReorderEnd?.call(index);
    });
  }

  /// Whether the item a drag lifted no longer sits at the index its drag
  /// started at: the app moved or replaced it with no call, at the same
  /// item count (FR-01 E07). Reads the app's `itemBuilder` once.
  bool _draggedLeftStart() {
    final dragged = _dragged;
    if (dragged == null) return false;
    // Every call, key move, and screen-reader move ends the drag first, so
    // the start index reads as an index of the app's data.
    final start = _dataIndexOf(dragged.start);
    if (start == null || start >= _dataEnd) return true;
    return _layout.itemBuilder(context, start.value).key != dragged.key;
  }

  /// The drag proxy took the item [key], its State with it.
  void _liftedTook(Key key) => _liftedKey = key;

  /// The drag proxy let the item [key] go, and its State waits among the
  /// inactive elements until the end of the frame.
  void _liftedLetGo(Key key) {
    if (_liftedKey == key) _liftedKey = null;
    if (_standInKey == key) _standInKey = null;
    if (_dragged?.key == key) _dragged = null;
    // A raw move of the lifted item follows it only now, with the item back
    // in its slot (invariant 28). The watch reads the item from its follow
    // until the end of this frame: the item registers again in its build.
    final follow = _liftedFollow;
    if (follow == null || follow.target.key != key) return;
    _followRawMove(follow.target, follow.node);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_liftedFollow == follow) _liftedFollow = null;
    });
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
  /// E15), cannot shift it (D7). After a key move, when no node holds
  /// primary focus, it moves to that item's first node in Tab order, the
  /// same rule [_followMoved] applies at this post-frame timing; a focus
  /// the app moved to another node in the move's turn, a bare
  /// [FocusScopeNode] included, stays there instead (R13). An item still
  /// growing in before it pushes it past the edge it was revealed at, so
  /// it is revealed again as each such grow-in ends (R10).
  void _afterMove(_MoveTarget moved, {required bool byKey}) {
    _moveTargets.remove(moved);
    final index = moved.index;
    if (!mounted || index == null) return;
    final built = _builtIndexOf(index);
    if (built == null) return;
    final node = _nodeAt(built);
    // A parked item keeps its registered node off screen: built means laid
    // out (invariant 35).
    if (node == null || node.context == null || !_builtSlot(built.slot)) {
      _reachStep(moved, built, node);
      return;
    }
    final key = moved.key;
    if (key != null) _releasePark(key);
    final noFocusOwnerElsewhere = FocusManager.instance.primaryFocus == null;
    if (byKey && noFocusOwnerElsewhere) firstTabStopIn(node)?.requestFocus();
    revealInViewports(node);
    for (final MapEntry(key: at, value: look) in _itemLooks.entries) {
      final motion = at < built ? _incoming[look.key] : null;
      if (motion != null) _revealAfterGrowIn(node, motion, byKey: byKey);
    }
  }

  /// The frame did not lay out the slot of a focused move, now [at]: the
  /// list reaches the slot as a move call's follow does, with the gap the
  /// item left (FR-03 E09, FR-05 E04). The item is parked, its key node
  /// [node] still holding focus, or its State is gone and no node holds
  /// primary focus; a focus the app moved elsewhere in the move's turn
  /// stays, and the park ends (R13).
  void _reachStep(_MoveTarget moved, _FrameIndex at, FocusNode? node) {
    final key = moved.key;
    final gap = moved.gap;
    if (key == null || gap == null) return;
    final parked = node != null && node.context != null && node.hasFocus;
    if (!parked && FocusManager.instance.primaryFocus != null) {
      _releasePark(key);
      return;
    }
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
  /// viewport around it, as invariant 21 reveals every focus move. When the
  /// frame laid out no item beside the gap, as when the app takes a moved
  /// item out before the frame whose jump would reach its slot, the list
  /// first reaches toward the gap, as [_reach] reaches an unbuilt slot, for
  /// up to [frames] frames, and hands focus on over the items laid out
  /// there; when the reach gives up, focus goes to the laid-out item
  /// nearest the gap ([_nearestStopTo]), and only with none to the list's
  /// own Tab stop, so focus stays in the list while it can take it
  /// (invariant 26). With [interim], the node the list focused while it
  /// reaches, a focus the app moves off it ends the handoff (R13,
  /// invariant 32); when nothing in the list can take focus, [interim] lets
  /// it go and Flutter's own fallback applies, the scope's previous child or
  /// the scope itself, as when a focused node detaches (R33).
  void _handOffFocus(
    _DataIndex gap, {
    int frames = _reachFrames,
    FocusNode? interim,
  }) {
    if (!mounted) return;
    if (interim != null && FocusManager.instance.primaryFocus != interim) {
      return;
    }
    final next = _builtNear(gap, 1);
    final previous = _builtNear(gap - 1, -1);
    final target =
        (next == null ? null : _firstStopOf(next, reveal: false)) ??
        (previous == null ? null : _firstStopOf(previous, reveal: false));
    if (target != null) {
      target.requestFocus();
      _revealHandOff(target);
      return;
    }
    bool laidOut(_FrameIndex? index) => index != null && _builtSlot(index.slot);
    if (!laidOut(next) && !laidOut(previous)) {
      final estimate = frames == 0 ? null : _estimateTowards(gap.nextSlot);
      if (estimate != null) {
        // Held before the jump: its scroll notifications may reach an app
        // listener that calls the controller at once.
        final held = _HeldGap(gap);
        _givenUpGaps.add(held);
        estimate.position.jumpTo(estimate.offset);
        WidgetsBinding.instance
          ..addPostFrameCallback((_) {
            _givenUpGaps.remove(held);
            _handOffFocus(held.index, frames: frames - 1, interim: interim);
          })
          ..scheduleFrame();
        return;
      }
      final nearest = _nearestStopTo(gap);
      if (nearest != null) {
        nearest.requestFocus();
        _revealHandOff(nearest);
        return;
      }
    }
    final own = _ownTabStop();
    if (own != null) {
      requestFocusInViewports(own);
    } else {
      interim?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  /// Reveals [node], the node a handoff focuses, now and again after the
  /// frame in which each motion running now ends, an exit shrinking or an
  /// item growing in, while [node] keeps focus: either may shift it past
  /// the edge it was revealed at, as a returned item's own grow-in does
  /// (invariant 26). Under reduced motion no size animates, so the first
  /// reveal stands and each later one finds [node] whole.
  void _revealHandOff(FocusNode node) {
    revealInViewports(node);
    final motions = {
      for (final exit in _exits) exit.motion,
      ..._incoming.values,
    };
    for (final motion in motions) {
      final controller = motion.controller;
      void ended(AnimationStatus status) {
        if (status.isAnimating) return;
        controller.removeStatusListener(ended);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && node.hasFocus) revealInViewports(node);
        });
      }

      controller.addStatusListener(ended);
    }
  }

  /// The first node in Tab order of the laid-out item nearest [gap] of the
  /// current data by data index, the first one after the gap, else the
  /// last one before it, revealed by [firstTabStopIn]; null when the frame
  /// laid out no item that holds one. Only the item it returns is revealed.
  FocusNode? _nearestStopTo(_DataIndex gap) {
    final laid = _laidOut();
    if (laid == null) return null;
    final after = <(_DataIndex, _FrameIndex)>[];
    final before = <(_DataIndex, _FrameIndex)>[];
    for (var slot = laid.first; slot <= laid.last; slot += 1) {
      final index = _FrameIndex(slot);
      final at = _dataIndexOf(index);
      if (at != null) (at >= gap ? after : before).add((at, index));
    }
    int byIndex((_DataIndex, _FrameIndex) a, (_DataIndex, _FrameIndex) b) =>
        a.$1 < b.$1 ? -1 : (a.$1 > b.$1 ? 1 : 0);
    after.sort(byIndex);
    before.sort((a, b) => byIndex(b, a));
    for (final (_, index) in [...after, ...before]) {
      final stop = _firstStopOf(index);
      if (stop != null) return stop;
    }
    return null;
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

  /// The key of the item the reach in progress looks for: its end releases
  /// that item's park (invariant 35).
  Key? _reachKey;

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
    final previous = _reachKey;
    if (previous != null && previous != key) _releasePark(previous);
    _reachToken = token;
    _reachGap = gap;
    _reachKey = key;
    scheduleMicrotask(() {
      final settled = FocusManager.instance.primaryFocus;
      _reach(token, index, key, settled, _reachFrames, origin);
    });
  }

  /// Ends the reach in progress and the park of the item it looked for.
  void _endReach() {
    final key = _reachKey;
    _stopReach();
    if (key != null) _releasePark(key);
  }

  /// Ends the reach in progress and leaves its item parked.
  void _stopReach() {
    _reachToken = null;
    _reachGap = null;
    _reachKey = null;
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
    // A parked item is registered but not laid out (invariant 35).
    if (node != null && node.context != null && _builtSlot(index.slot)) {
      if (_lookAt(index)?.key != key) {
        _giveUpReach(origin);
        return;
      }
      _endReach();
      // A parked item kept its State and the node that holds focus.
      if (!node.hasFocus) firstTabStopIn(node)?.requestFocus();
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
    // A parked box keeps a stale slot and no layout offset: laid-out boxes
    // only (invariant 35).
    final boxes = <int, ({FocusNode node, RenderBox box})>{
      for (final MapEntry(key: index, value: node) in _itemNodes.entries)
        if (_builtSlot(index.slot))
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

  /// Books the jump of [_jumpForMove] toward [target] for the next frame's
  /// start, for the focused item whose key node is [node] and which enters
  /// at [to] of the current data, when the last frame did not lay that slot
  /// number out ([_enteredSlot], invariant 35), at every distance; with
  /// [owned], [target] sits among [_moveTargets] until then. The item's key
  /// comes from its built slot, so the list never calls `itemBuilder` here.
  void _bookMoveJump(
    _DataIndex to,
    FocusNode node,
    _MoveTarget target, {
    bool owned = false,
  }) {
    if (_builtSlot(_enteredSlot(to))) return;
    if (owned) _moveTargets.add(target);
    _bookFrameJump(node, target, owned: owned);
  }

  /// Books a reveal jump toward [target], the move of the item whose key
  /// node is [node], for the next frame's start ([_runFrameJumps]): exactly
  /// to the start when [toStart] is true, to the end when false, else
  /// through [_jumpForMove].
  void _bookFrameJump(
    FocusNode node,
    _MoveTarget target, {
    bool? toStart,
    bool owned = false,
  }) {
    if (_frameJumps.isEmpty) {
      WidgetsBinding.instance.scheduleFrameCallback((_) => _runFrameJumps());
    }
    _frameJumps.add(
      _FrameJump(
        node,
        target,
        toStart: toStart,
        owned: owned,
        focusAtCall: FocusManager.instance.primaryFocus,
      ),
    );
  }

  /// At the next frame's start, after the turn's focus settled and before
  /// the build and the layout: runs the booked jumps in booking order, each
  /// toward its target where the calls since its move left it, and records
  /// the offset before it on the target, where a reach that gives up
  /// returns. A jump is skipped when its target was taken out, or when a
  /// node outside the moved item took primary focus since the call: the
  /// app's focus wins. An item that never held focus, as under a screen
  /// reader's start or end action, still jumps (invariant 35).
  void _runFrameJumps() {
    final jumps = [..._frameJumps];
    _frameJumps.clear();
    for (final jump in jumps) {
      if (jump.owned) _moveTargets.remove(jump.target);
    }
    if (!mounted) return;
    for (final jump in jumps) {
      final at = jump.target.index;
      if (at == null) continue;
      final primary = FocusManager.instance.primaryFocus;
      final appFocused = primary != null && primary != jump.focusAtCall;
      if (appFocused && !jump.node.hasFocus) continue;
      final item = jump.node.context;
      final position = item == null ? null : Scrollable.maybeOf(item)?.position;
      if (item == null || position == null) continue;
      final toStart = jump.toStart;
      if (toStart == null) {
        jump.target.origin = _jumpForMove(at, item, position);
        continue;
      }
      jump.target.origin = (position: position, pixels: position.pixels);
      _jumpTowards(item, position, toStart: toStart);
    }
  }

  /// Jumps at the next frame's start toward the slot the focused item
  /// [item] enters at [to] of the current data: exactly to the start or end
  /// for an edge slot, as a key move to either end does, else by
  /// [_estimateTowards] at slot [to] (FR-05 E04). Returns the offset before
  /// the jump, where a failed reach returns (R5); null with no jump.
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
        !context.reducesMotion) {
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

  /// After the frame that moved the focused item [key] (FR-05 E04): laid
  /// out, it keeps focus and is revealed twice; parked off screen after a
  /// missed estimate, or with its State gone, the list reaches the item's
  /// slot, read by key from the settling build ([_followAt]), for another
  /// call in the move's own turn may have shifted the data under the move's
  /// own indices. With no settled slot for the key, a later call took the
  /// item or a count change reset the frame (E12), the follow runs the
  /// give-up path: it returns to [origin], the offset before the move's
  /// jump at the next frame's start, else the one before the reach's own
  /// first jump, and hands focus on from the gap the frame left, the slot
  /// the item left (R5). The follow fields belong to the newest move: a
  /// follow whose key they no longer name waits for that move's own
  /// callback and does nothing here.
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
      // Parked off screen: registered, but not laid out (invariant 35).
      if (at != null && !_builtSlot(at.slot)) {
        if (node.hasFocus && gap != null) {
          _startReach(at, key, gap, origin: origin);
        } else {
          _releasePark(key);
        }
        return;
      }
      _releasePark(key);
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
  /// by [firstTabStopIn]; null when the item is not laid out or holds none.
  /// A parked item, or one the app keeps alive, keeps its registered node
  /// off screen, so it is never a target (invariant 26).
  FocusNode? _firstStopOf(_FrameIndex index, {bool reveal = true}) {
    final node = _nodeAt(index);
    if (node == null || node.context == null || !_builtSlot(index.slot)) {
      return null;
    }
    return firstTabStopIn(node, reveal: reveal);
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
    _builtKey = key;
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
    if (_fixedExtent || context.reducesMotion) return fade;
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
      (_layout.itemTransitionBuilder == null && context.reducesMotion);

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
    // A count change, or the lifted item away from its start at the same
    // count (FR-01 E07), ends the drag in this build, before the sliver
    // builds the item's key elsewhere; the end reaches _endDrag through
    // _ReorderSliverState.cancelReorder (E06).
    if (listCount != _listCount || _draggedLeftStart()) {
      _listKey.currentState?.cancelReorder();
      _dragged = null;
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
    // The widgets `ReorderableList`'s own tree, built here so the list
    // builds its own sliver subclass (invariant 28) and the key reaches it
    // (invariant 35); `scrollCacheExtent` reaches the viewport unchanged.
    return Focus(
      focusNode: _holdNode,
      includeSemantics: false,
      child: _scrollView(layout, listCount),
    );
  }

  Widget _scrollView(ReorderableListViewLayout layout, int listCount) {
    return _ReorderScrollView(
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
          sliver: _ReorderSliver(
            key: _listKey,
            body: this,
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
    );
  }
}

/// The widgets [SliverReorderableList] whose State routes every drag end
/// the SDK causes to [body]'s one exit, `_endDrag` (FR-04 E06). Private,
/// so a test finds it by a `SliverReorderableList` subtype predicate.
class _ReorderSliver extends SliverReorderableList {
  const new({
    required GlobalKey<SliverReorderableListState> super.key,
    required this.body,
    required super.itemBuilder,
    required super.itemCount,
    required ReorderCallback super.onReorderItem,
    required void Function(int index) super.onReorderStart,
    required void Function(int index) super.onReorderEnd,
    super.itemExtent,
    super.itemExtentBuilder,
    super.prototypeItem,
    super.proxyDecorator,
    super.autoScrollerVelocityScalar,
  });

  final _ReorderableBodyState body;

  @override
  SliverReorderableListState createState() => _ReorderSliverState();
}

/// Reports to the body each reset the SDK makes through [cancelReorder],
/// and each canceled gesture through a [_WatchedDrag]; the SDK reports a
/// drop itself through `onReorderEnd`. Every drag passes through
/// [startItemDragReorder], from the long-press listener or an app's
/// `ReorderableDragStartListener` handle alike.
class _ReorderSliverState extends SliverReorderableListState {
  _ReorderableBodyState get _body => (widget as _ReorderSliver).body;

  // Wraps after super: the recognizer reads onStart only when the arena
  // accepts, after the pointer-down dispatch (multidrag.dart, _startDrag).
  @override
  void startItemDragReorder({
    required int index,
    required PointerDownEvent event,
    required MultiDragGestureRecognizer recognizer,
  }) {
    super.startItemDragReorder(
      index: index,
      event: event,
      recognizer: recognizer,
    );
    final start = recognizer.onStart;
    if (start == null) return;
    final body = _body;
    recognizer.onStart = (position) {
      final drag = start(position);
      return drag == null ? null : _WatchedDrag(drag, body._handleListReset);
    };
  }

  // The SDK calls this on an item-count change (didUpdateWidget) and on a
  // second pointer (startItemDragReorder); the body calls it too.
  @override
  void cancelReorder() {
    super.cancelReorder();
    _body._handleListReset();
  }

  // The SDK keys each item with its index (`_ReorderableItemGlobalKey`), so
  // its sliver replaces a moved item's element. The same sliver over a
  // delegate that frames each item by its own key, with
  // `findChildIndexCallback`, moves that element in place (invariant 35).
  @override
  Widget build(BuildContext context) {
    final sliver = super.build(context);
    final body = _body;
    final sdk = sliver is SliverMultiBoxAdaptorWidget ? sliver.delegate : null;
    final rebuilt = sdk is SliverChildBuilderDelegate
        ? _rebuilt(sliver, body._rebuiltDelegate(sdk))
        : null;
    assert(
      rebuilt != null,
      'SliverReorderableListState.build changed shape: '
      'ReorderableListViewLayout cannot frame its items by key',
    );
    return rebuilt ?? sliver;
  }

  /// [sliver], one of the four slivers the SDK builds, over [delegate];
  /// null for any other.
  static Widget? _rebuilt(Widget sliver, SliverChildBuilderDelegate delegate) {
    return switch (sliver) {
      SliverFixedExtentList(:final itemExtent) => SliverFixedExtentList(
        delegate: delegate,
        itemExtent: itemExtent,
      ),
      SliverVariedExtentList(:final itemExtentBuilder) =>
        SliverVariedExtentList(
          delegate: delegate,
          itemExtentBuilder: itemExtentBuilder,
        ),
      SliverPrototypeExtentList(:final prototypeItem) =>
        SliverPrototypeExtentList(
          delegate: delegate,
          prototypeItem: prototypeItem,
        ),
      SliverList() => SliverList(delegate: delegate),
      _ => null,
    };
  }
}

/// Forwards a drag to the SDK's own and reports its cancel, which the SDK
/// resets with neither `onReorderEnd` nor `cancelReorder`.
class _WatchedDrag extends Drag {
  new(this._drag, this._onCancel);

  final Drag _drag;
  final VoidCallback _onCancel;

  @override
  void update(DragUpdateDetails details) => _drag.update(details);

  @override
  void end(DragEndDetails details) => _drag.end(details);

  @override
  void cancel() {
    _drag.cancel();
    _onCancel();
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

  /// Whether the item's node held focus when the item last left the tree:
  /// a disposal that follows hands focus on (R26).
  var _leftFocused = false;

  /// The traversal actions every item runs a Tab, Shift+Tab, or arrow
  /// through ([_OffScreenTraversal]).
  late final _traversals = <Type, Action<Intent>>{
    NextFocusIntent: _OffScreenTraversal<NextFocusIntent>(this),
    PreviousFocusIntent: _OffScreenTraversal<PreviousFocusIntent>(this),
    DirectionalFocusIntent: _OffScreenTraversal<DirectionalFocusIntent>(this),
  };

  /// Whether focus sits inside this item while the list keeps it alive off
  /// screen, its slot not laid out (R29).
  bool get _focusedOffScreen =>
      !widget.exiting &&
      _node.hasFocus &&
      !widget.body._builtSlot(widget.index.slot);

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
    _leftFocused = false;
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
    // Read before the item's own nodes leave the tree, which they do only
    // at its disposal.
    _leftFocused = !widget.exiting && _node.hasFocus;
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
    if (_leftFocused) {
      widget.body._focusedItemGone(widget.index, widget.look.key);
    }
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
    return Actions(
      actions: _traversals,
      child: Focus(
        focusNode: _node,
        includeSemantics: false,
        onKeyEvent: widget.exiting
            ? null
            : (node, event) =>
                  widget.body._handleKey(widget.index, node, event),
        child: widget.child,
      ),
    );
  }
}

/// Runs a focus traversal [T], a Tab, Shift+Tab, or arrow, that starts
/// inside an item: through the next action up the tree, and, for an item
/// the list keeps alive off screen, only once the list brought the item
/// back into view ([_ReorderableBodyState._bringBack]).
///
/// The sliver gives a kept-alive box a zero paint transform, so a policy
/// that reads the focused node's geometry would start from no place at
/// all; back in view, the traversal starts from the item's own slot and the
/// policy reveals its target (R29, invariant 21).
class _OffScreenTraversal<T extends Intent> extends ContextAction<T> {
  new(this.keys);

  final _ReorderKeysState keys;

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    if (!keys._focusedOffScreen) return _runAbove(intent);
    keys.widget.body._bringBack(keys, () => _runAbove(intent));
    return const _HeldTraversal();
  }

  /// Runs [intent] through the action above the item, as with no list.
  _AboveResult? _runAbove(T intent) {
    if (!keys.mounted) return null;
    final context = keys.context;
    final above = Actions.maybeFind<Intent>(context, intent: intent);
    if (above == null) return null;
    final (enabled, result) = Actions.of(context)
        .invokeActionIfEnabled(above, intent, context);
    return enabled ? (action: above, result: result) : null;
  }

  @override
  KeyEventResult toKeyEventResult(T intent, Object? invokeResult) {
    return switch (invokeResult) {
      _HeldTraversal() => KeyEventResult.handled,
      (:final Action<Intent> action, :final Object? result) =>
        action.toKeyEventResult(intent, result),
      _ => KeyEventResult.ignored,
    };
  }
}

/// The action above an item that ran a traversal, with its result.
typedef _AboveResult = ({Action<Intent> action, Object? result});

/// A traversal [_OffScreenTraversal] holds until the item is back in view.
class _HeldTraversal {
  const new();
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

/// The key of the frame around an SDK item, equal by the item's own key,
/// never its index: the sliver moves a mapped item's element in place.
class _IndexFreeKey extends ValueKey<Key> {
  const new(super.value);
}

/// The frame around an SDK item, keyed by the item's own key: it moves in
/// place across indices, and keeps the item alive while the body parks it
/// (invariant 35).
class _ParkFrame extends StatefulWidget {
  const new({
    required _IndexFreeKey super.key,
    required this.body,
    required this.itemKey,
    required this.child,
  });

  final _ReorderableBodyState body;
  final Key itemKey;
  final Widget child;

  @override
  State<_ParkFrame> createState() => _ParkFrameState();
}

class _ParkFrameState extends State<_ParkFrame>
    with AutomaticKeepAliveClientMixin {
  /// Whether the body parked this very State; a frame built later starts
  /// unparked.
  var _parked = false;

  /// Whether a node inside this item holds primary focus (R29).
  var _held = false;

  @override
  bool get wantKeepAlive => _parked || _held;

  @override
  void initState() {
    super.initState();
    widget.body
      .._frames[widget.itemKey] = this
      .._queueFocusFrame();
  }

  @override
  void didUpdateWidget(_ParkFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.body._frames[widget.itemKey] = this;
  }

  @override
  void dispose() {
    final body = widget.body;
    final frames = body._frames;
    if (frames[widget.itemKey] == this) frames.remove(widget.itemKey);
    if (body._focusFrame == this) body._focusFrame = null;
    super.dispose();
  }

  /// Parks or releases this State now.
  void setParked({required bool parked}) {
    if (_parked == parked) return;
    _parked = parked;
    updateKeepAlive();
  }

  /// Keeps this State alive while focus sits inside its item, or lets it
  /// go, now (R29).
  void setHeld({required bool held}) {
    if (_held == held) return;
    _held = held;
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
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
/// `_dragIndex` of a drag the list ends (`_endDrag`).
extension type const _FrameIndex(int value) {
  /// The slot this index held in the last frame.
  int get slot => value;

  bool operator <(_FrameIndex other) => value < other.value;

  bool operator >(_FrameIndex other) => value > other.value;

  _FrameIndex operator +(int offset) => _FrameIndex(value + offset);

  _FrameIndex operator -(int offset) => _FrameIndex(value - offset);
}

/// A key a build asks the app's `findChildIndexCallback` about, with its
/// key node and the index of the current data the calls of the turn put it
/// at (invariant 35).
typedef _Watched = ({Key key, _DataIndex at, FocusNode node});

/// The work each list queued for the end of the next frame's layout, before
/// that frame's post-frame callbacks ([_runAfterLayout]).
final _afterLayout = <VoidCallback>[];

/// Whether the persistent frame callback that drains [_afterLayout] exists.
var _afterLayoutAdded = false;

/// Runs [work] once the next frame's layout is done and before its
/// post-frame callbacks: a focus request [work] makes there replaces
/// Flutter's own fallback, and a request any post-frame callback makes
/// replaces it (R13). The tree may be locked: [work] neither builds nor
/// scrolls.
void _runAfterLayout(VoidCallback work) {
  if (!_afterLayoutAdded) {
    _afterLayoutAdded = true;
    // Persistent callbacks run in order: this one follows the binding's
    // own drawFrame, which lays out and finalizes the tree.
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (_afterLayout.isEmpty) return;
      final queued = List.of(_afterLayout);
      _afterLayout.clear();
      for (final run in queued) {
        run();
      }
    });
  }
  _afterLayout.add(work);
}

/// An `insertItem`, `removeItem`, or `moveItem` call, or a move the list
/// reported, as [_ReorderableBodyState]'s converters replay it.
typedef _Call = ({_DataIndex? from, _DataIndex? to, bool reported});

/// What a reorder key or a screen reader's move action asks for: the four
/// moves of FR-02 and FR-03 E03.
enum _MoveIntent { start, previous, next, end }

/// The index of the app's data a key move, a screen-reader move, or a drop
/// put its item at, moved by each later call until the frame after the
/// move reads it; null once a call takes the item out.
class _MoveTarget {
  new(this.index, {this.key, this.gap});

  _DataIndex? index;

  /// For a move of an item that holds focus: the item's key, which the
  /// reach looks for.
  final Key? key;

  /// For a move of an item that holds focus: the gap the item left, before
  /// the item at this index of the current data, moved by each later call
  /// as [index] is; the reach hands focus on from it when it gives up.
  _DataIndex? gap;

  /// The offset before the move's jump, where a reach that gives up
  /// returns (R5). Set by the jump at the next frame's start.
  ({ScrollPosition position, double pixels})? origin;
}

/// The list's own scroll view: the body builds the widgets
/// `ReorderableList`'s tree itself, so its own [SliverReorderableList]
/// subclass sits in it (invariant 28); an item finds the list through
/// `SliverReorderableList.maybeOf`, not `ReorderableList.maybeOf`.
class _ReorderScrollView extends CustomScrollView {
  const new({
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
}

/// A reveal jump a move booked for the next frame's start (invariant 35).
class _FrameJump {
  new(
    this.node,
    this.target, {
    required this.toStart,
    required this.owned,
    required this.focusAtCall,
  });

  /// The moved item's key node.
  final FocusNode node;

  /// Where the move put the item, shifted by each later call until the jump
  /// reads it; the jump records the offset before it there.
  final _MoveTarget target;

  /// True or false for an exact jump to the start or the end; null for
  /// [_ReorderableBodyState._jumpForMove].
  final bool? toStart;

  /// Whether [target] sits among the moves' targets only for this jump.
  final bool owned;

  /// The node that held primary focus at the move's call.
  final FocusNode? focusAtCall;
}

/// A gap of the app's data, before the item at [index], that a reader
/// takes after a frame; moved by each later call until then.
class _HeldGap {
  new(this.index);

  _DataIndex index;
}
