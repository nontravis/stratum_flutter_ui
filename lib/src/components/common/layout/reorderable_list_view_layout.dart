import 'dart:math' as math;
import 'dart:ui' as ui show Image;

import 'package:flutter/rendering.dart'
    show
        BoxHitTestResult,
        BoxParentData,
        ClipRectLayer,
        ItemExtentBuilder,
        LayerHandle,
        OffsetLayer,
        PaintingContext,
        PipelineOwner,
        RenderAbstractViewport,
        RenderAnimatedOpacity,
        RenderObjectVisitor,
        RenderProxyBox,
        RenderRepaintBoundary,
        RenderShiftedBox,
        RenderSliverList,
        RenderSliverMultiBoxAdaptor,
        RenderSliverVariedExtentList,
        ScrollCacheExtent,
        ScrollDirection,
        SliverConstraints,
        SliverLayoutDimensions,
        SliverMultiBoxAdaptorParentData,
        applyGrowthDirectionToAxisDirection;
import 'package:flutter/scheduler.dart' show Ticker, TickerCallback;
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

part 'reorder/reorder_sliver.dart';
part 'reorder/reorder_slots.dart';

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
/// [ReorderableItemsController.moveItem] closes a moved item's old
/// slot while the item grows into its new one, and the item keeps its
/// State and focus.
///
/// An insert or remove during a drag, through [itemsController] or not,
/// and a `moveItem` call during one, end the drag first: the dragged item
/// goes back to its slot, [onReorderEnd] reports the index the drag
/// started at, and [onReorderItem] does not fire. A drag that starts
/// between an `insertItem`, `removeItem`, or `moveItem` call, or a move
/// the list reported through [onReorderItem], and the next frame ends the
/// same way at once. A reorder key or a screen reader's move during a drag
/// ends it the same way before it moves; while a dropped item settles, it
/// completes the drop at once — one [onReorderItem], the item in its new
/// slot, no second [onReorderEnd] — then moves (R52).
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
    this.moveAnnouncement,
    this.atStartAnnouncement,
    this.atEndAnnouncement,
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
  final ReorderableItemsController? itemsController;

  /// Replaces the built-in grow-or-shrink and fade of an inserted or
  /// removed item, for both directions.
  ///
  /// `animation` runs from 0 to 1 on insert and from 1 to 0 on remove,
  /// over the theme's `normal` level on its `standard` curve. Reduced
  /// motion leaves it unchanged: the builder makes its own reduced-motion
  /// choice. Under a fixed item extent a removed item still takes no room.
  /// `child` is the item.
  /// A moved item's entry takes it too; the slot the item left never does.
  /// Return one widget shape for every animation value, or the item's State
  /// ends.
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
  /// [ReorderableItemsController.moveItem] call, as a live sync
  /// does: an item that holds focus then keeps its State and focus at every
  /// distance and the list scrolls to it, one frame after a `moveItem`
  /// would, and an item the app keeps alive follows the reorder. The list
  /// asks once per built, cached, or kept-alive item on each build of the
  /// list, plus once for the focused item, and never while it only
  /// scrolls, so read an O(1) key-to-index map the app keeps in sync with
  /// its data, never a search of the data.
  final ChildIndexGetter? findChildIndexCallback;

  /// What a screen reader hears after the EndUser moves an item with a
  /// reorder key, a screen-reader move action, or a drop: `position`
  /// counts from 1 and `count` is [itemCount]. Null reads the built-in
  /// "Moved to position {position} of {count}" in the locale's language;
  /// an empty text announces nothing.
  final String Function(int position, int count)? moveAnnouncement;

  /// What a screen reader hears when a reorder key would move the first
  /// item before the start; null reads the built-in "Already at the start
  /// of the list"; an empty text announces nothing.
  final String? atStartAnnouncement;

  /// What a screen reader hears when a reorder key would move the last
  /// item past the end; null reads the built-in "Already at the end of
  /// the list"; an empty text announces nothing.
  final String? atEndAnnouncement;

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
class ReorderableItemsController {
  _ReorderableBodyState? _body;

  /// Grows and fades in the item the app inserted at [index] of its data,
  /// over the theme's `normal` level.
  ///
  /// [index] runs from 0 to the item count before the insert.
  void insertItem(int index) {
    assert(
      _body != null,
      'insertItem on a ReorderableItemsController attached to no '
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
      'removeItem on a ReorderableItemsController attached to no '
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
      'moveItem on a ReorderableItemsController attached to no '
      'ReorderableListViewLayout',
    );
    _body?._moveItem(_DataIndex(from), _DataIndex(to));
  }

  void _attach(_ReorderableBodyState body) {
    assert(
      _body == null || _body == body,
      'One ReorderableItemsController is attached to two '
      'ReorderableListViewLayouts at once',
    );
    _body = body;
  }

  void _detach(_ReorderableBodyState body) {
    if (_body == body) _body = null;
  }
}

/// [ReorderableItemsController]'s name before naming rule R2, kept one
/// minor version.
@Deprecated(
  'Use ReorderableItemsController instead. '
  'StratumReorderableItemsController will be removed after one minor '
  'version.',
)
typedef StratumReorderableItemsController = ReorderableItemsController;

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

  /// The key of the item a drag holds, from its drag start until the drag
  /// resets; the item stays in its own slot throughout.
  Key? _liftedKey;

  /// The follow of a raw move of the lifted item, with the item's key
  /// node, until the end of the frame the drag lets the item go
  /// ([_liftedLetGo]), which runs the follow (invariant 28); until then
  /// the watch reads the item from here ([_watchedKeys]).
  ({_MoveTarget target, FocusNode node})? _liftedFollow;

  /// Reaches [SliverReorderableListState.cancelReorder] and the list's
  /// sliver ([_sliver]) through the list's own [_ReorderSliverState].
  final _listKey = GlobalKey<SliverReorderableListState>();

  /// The index each item a move the list knows put in a slot the last
  /// frame did not lay out takes in this build, the parked item's, and each
  /// key a call of this turn inserted ([_bookInsertedKeys]), by the item's
  /// key: the first answer [_resolveIndices] takes, so the sliver moves the
  /// item's element there in place (invariant 35). Filled by each
  /// [_resolvePending].
  final _movedTo = <Key, int>{};

  /// The app's `findChildIndexCallback` answer for each key this build
  /// asked about, null for no answer: asked once per key per build
  /// ([_appAnswer]), the second answer [_resolveIndices] takes (D3).
  final _appAt = <Key, int?>{};

  /// The index each key the last build registered takes in this build
  /// when neither [_movedTo] nor the app's answer places it: where the last
  /// frame's laid-out range of the new data shows it, else where this
  /// turn's calls put it ([_knowBuiltKeys]); the last answer
  /// [_resolveIndices] takes (D3).
  final _knownAt = <Key, int>{};

  /// Whether the app gave the list a new widget since the last build: only
  /// then can its data have changed with no call ([_knowBuiltKeys]).
  var _appRebuilt = true;

  /// The widget `itemBuilder` returned for each data index the laid-out
  /// read of this build asked for ([_readLaidOut]), until [_buildItem]
  /// takes it for the sliver in the same frame, so the read costs no call
  /// beyond the sliver's own (D9).
  final _readLooks = <int, Widget>{};

  /// The index of the app's data each key the last frame built takes in
  /// this build, one key per index ([_resolveIndices]); the sliver's
  /// `findChildIndexCallback` turns it into the key's slot ([_findIndex]).
  /// Kept until the next build resolves the keys again.
  final _resolvedAt = <Key, int>{};

  /// The item key [_buildItem] read last, for the reorder sliver's frame.
  Key? _builtKey;

  /// Where this build lays each data item and each leaving item or closing
  /// gap out (R47).
  _FramePlan _plan = _FramePlan.none;

  /// The slots this turn's `moveItem` calls added, less those they dropped,
  /// before the item the last frame laid out first ([_countSlotsBefore]);
  /// the next build's sliver takes it once ([_takeSlotsBefore]), so they
  /// never move the screen (D9 item 4).
  var _slotsBefore = 0;

  /// The index, in the data after this turn's calls so far, of the item the
  /// last frame laid out first; null before the turn's first call counts.
  _DataIndex? _firstLaidOut;

  /// The main-axis extent of `prototypeItem`, which the list's sliver
  /// measures in each layout before it lays its slots out.
  double? _prototypeExtent;

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

  /// The text of the live-region node, where the platform reports no
  /// announce support; null before the first announcement and once
  /// [_liveHold] has passed after the last one.
  String? _liveText;

  /// Takes the live-region node out of the tree [_liveHold] after the last
  /// announcement.
  Timer? _liveTimer;

  /// How long the live-region node stays in the semantics tree after its
  /// announcement (invariant 60). TalkBack reads the node after the bridge's
  /// content-change event, asynchronously and possibly throttled, so the
  /// node must outlive that read; a node kept longer, a labeled node, is a
  /// stop of TalkBack's swipe that reads a stale move. No focus move marks
  /// the read, and TalkBack's swipe moves no input focus, so a time bounds
  /// it: Material's default snack bar stays for the same 4 s.
  static const _liveHold = Duration(seconds: 4);

  /// Counts the live-region announcements, so each one builds a new node
  /// that the platform reads even when its text repeats (invariant 60).
  var _liveCount = 0;

  /// The reorder keys, by their place on the keyboard, whose press moved
  /// the item and is not yet up (R42).
  final _pressedKeys = <PhysicalKeyboardKey>{};

  /// The last key move, not yet announced: it speaks once, where the item
  /// sits then, when the frame after it has run and every key in
  /// [_pressedKeys] is up, so a held key, or keys held over each other,
  /// speak once (R42). Each later call shifts it ([_shiftedTargets]).
  _MoveTarget? _keyMove;

  /// Whether the frame after [_keyMove] has run.
  var _keyMoveLanded = false;

  /// Whether [_handleKeyUp] listens to [HardwareKeyboard].
  var _hearsKeyUp = false;

  /// The last move [_reportMove] reported, until the frame after it: moves
  /// that land in one frame paint once, so only this one speaks, on every
  /// path (R42).
  _MoveTarget? _lastReported;

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
    _appRebuilt = true;
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
    if (_hearsKeyUp) HardwareKeyboard.instance.removeHandler(_handleKeyUp);
    _liveTimer?.cancel();
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
  /// back into view, then runs [then]: the shared scroll content policy
  /// calls it through [_bringBackNode] before a traversal moves from the
  /// item. Jumps toward its slot by [_estimateTowards] each frame, moving
  /// to the plain edge each time so a new layout pass measures it, until a
  /// frame lays it out, for up to [frames] frames, then reveals it, from
  /// [origin], the offset this call started at, read once and carried
  /// through its retries, by its own box. Stops when focus left the item;
  /// after the last jump, runs [then] where the item stands.
  void _bringBack(
    _ReorderKeysState keys,
    VoidCallback then, {
    int frames = _reachFrames,
    ({ScrollPosition position, double pixels})? origin,
  }) {
    if (!mounted || !keys.mounted || !keys._node.hasFocus) return;
    final start = origin ?? _currentOrigin;
    final slot = keys.widget.index.slot;
    if (_builtSlot(slot)) {
      _revealOwn(keys._node, origin: start);
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
      ..addPostFrameCallback(
        (_) => _bringBack(keys, then, frames: frames - 1, origin: start),
      )
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

  /// [ReorderableItemsController.insertItem]: the app inserted an
  /// item at [index] of its data in this turn.
  void _insertItem(_DataIndex index) {
    assert(
      index >= const _DataIndex(0) && index <= _dataEnd,
      'insertItem($index) is out of range: the data holds $_dataCount '
      'items',
    );
    if (index < const _DataIndex(0) || index > _dataEnd) return;
    _cancelDrag();
    _countSlotsBefore(to: index);
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

  /// [ReorderableItemsController.removeItem]: the app removed the
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
    final around = _takeExitsAround(index);
    _countSlotsBefore(from: index);
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

  /// [ReorderableItemsController.moveItem]: the app moved the item
  /// at [from] of its data to [to] in this turn (FR-05). Booked in
  /// [_pending] as one move entry, which both converters follow, and as an
  /// insert at [to] in [_pendingInserts], so the frame moves the item's
  /// element, with its State, into the new slot in place
  /// ([_bookInsertedKeys]).
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
    // A leaving item beside the moved item ends at once (FR-05 E09).
    if (built != null) _endExitsBeside(built);
    final box = node?.context?.findRenderObject();
    final size = box is RenderBox && box.hasSize ? box.size : null;
    // A key an earlier call this turn already booked a jump for sits among
    // [_moveTargets] at [from]: this call moves it again, so its target
    // follows it to [to] (D8), instead of `_shiftForRemove`'s ordinary
    // "taken out" null below.
    final reaimed = _moveTargets
        .where((target) => target.index == from)
        .toList(growable: false);
    // The old slot closes as the item grows in; at once under reduced
    // motion or a fixed extent, where the item only fades in (E02).
    final gap =
        key != null && size != null && !_fixedExtent && !context.reducesMotion
        ? _startClosingGap(from, key, size)
        : null;
    _countSlotsBefore(from: from, to: to, exit: gap != null, moved: true);
    _shiftForRemove(from);
    // A remove while the insert side below reads the data without the
    // item, then one move entry.
    _pending.add((from: from, to: null, reported: false));
    _dataCount -= 1;
    if (gap != null) _joinGap(from, [gap]);
    _shiftForInsert(to);
    // `_shiftForRemove` above left each reaimed target's index null, the
    // "taken out" case; this call re-inserts the same key at [to], so the
    // target follows it there instead (D8).
    for (final target in reaimed) {
      target.index = to;
    }
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

  /// Takes out of [_exits] the removed items next to the item at [index]
  /// of the current data: those just before it and those just after it,
  /// each in the list's order.
  ({List<_Exit> before, List<_Exit> after}) _takeExitsAround(_DataIndex index) {
    bool sitsBefore(_Exit exit) => exit.gap == index;
    bool sitsAfter(_Exit exit) => exit.gap == index + 1;
    final before = _exits.where(sitsBefore).toList();
    final after = _exits.where(sitsAfter).toList();
    _exits.removeWhere((exit) => sitsBefore(exit) || sitsAfter(exit));
    return (before: before, after: after);
  }

  /// Puts [exits], in the list's order, back in [_exits] at [gap] of the
  /// current data.
  void _joinGap(_DataIndex gap, List<_Exit> exits) {
    for (final exit in exits) {
      exit.gap = gap;
    }
    _exits.addAll(exits);
  }

  void _finishInsert(_ItemMotion motion) {
    if (!mounted || !_endInsert(motion)) return;
    setState(() {});
  }

  /// The bookkeeping [_finishInsert] ends an insert's motion with: takes
  /// [motion] out of [_incoming] and [_pendingInserts] and disposes it.
  /// Answers whether it found and removed one, so a caller that already
  /// has its own rebuild arranged (a lift, [_liftedTook]) can skip a
  /// second, unsafe one of its own: a lift ends this motion from inside
  /// the drag's own gesture callback, where [setState] can land mid an
  /// unrelated build already in progress.
  bool _endInsert(_ItemMotion motion) {
    final held = _incoming.length + _pendingInserts.length;
    _incoming.removeWhere((_, other) => identical(other, motion));
    _pendingInserts.removeWhere((insert) => identical(insert.motion, motion));
    if (_incoming.length + _pendingInserts.length == held) return false;
    motion.dispose();
    return true;
  }

  /// The end of [exit]'s own animation.
  void _finishExit(_Exit exit) {
    if (!mounted || exit.ended || !_exits.contains(exit)) return;
    _endExit(exit);
    setState(() {});
  }

  /// Ends [exit]'s animation at once. Every path that ends an exit comes
  /// here, and none takes it out of [_exits]: its slot stays, empty and of
  /// no extent, until [_dropEndedExits] can drop it with no item on screen
  /// moving, for the sliver keeps each slot's offset by its number (R47).
  void _endExit(_Exit exit) {
    if (exit.ended) return;
    exit
      ..ended = true
      ..motion.dispose();
  }

  /// Drops each ended exit the last frame laid out or that sits past the
  /// first laid-out item, by its index after [calls]: its slot then moves
  /// no item on screen. With that item taken out by a call, an exit not
  /// laid out waits for a later build.
  void _dropEndedExits(List<_Call> calls) {
    if (!_exits.any((exit) => exit.ended)) return;
    final laid = _laidOut();
    final first = laid == null
        ? null
        : _dataIndexOf(_FrameIndex(laid.first), calls: calls);
    final laidOut = <_Exit>{};
    final sliver = _sliver();
    for (
      var child = sliver?.firstChild;
      child != null;
      child = sliver?.childAfter(child)
    ) {
      if (child case _RenderSlotSemantics(:final exit?)) laidOut.add(exit);
    }
    _exits.removeWhere(
      (exit) =>
          exit.ended &&
          (laid == null ||
              laidOut.contains(exit) ||
              (first != null && exit.gap > first)),
    );
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

  /// Moves the pending indices past an insert at [index]. An insert at a
  /// removed item's gap lands after it, as in `AnimatedList`, whether the
  /// item left in this turn or an earlier one.
  void _shiftForInsert(_DataIndex index) {
    for (final exit in _exits) {
      if (exit.gap > index) exit.gap += 1;
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
    for (final target in _shiftedTargets) {
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
      if (exit.gap > index) exit.gap -= 1;
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
    for (final target in _shiftedTargets) {
      final gap = target.gap;
      if (gap != null && gap > index) target.gap = gap - 1;
      final at = target.index;
      if (at == null || at < index) continue;
      // A call that takes the moved item out leaves nothing to reveal.
      target.index = at == index ? null : at - 1;
    }
  }

  /// Follows the item the last frame laid out first through a call's remove
  /// at [from] and insert at [to] ([_firstLaidOut]), read before the call
  /// shifts the data; an insert at that item's own index lands in the
  /// laid-out range. For a `moveItem` call, [moved], counts the slots they
  /// add or drop before that item ([_slotsBefore]): the remove drops one,
  /// unless its item leaves through an [exit], which takes room and so keeps
  /// its slot, and the insert adds one. Under a fixed extent the sliver
  /// places each slot by the extents before it, so nothing counts.
  void _countSlotsBefore({
    _DataIndex? from,
    _DataIndex? to,
    bool exit = false,
    bool moved = false,
  }) {
    if (_fixedExtent) return;
    // A no-room exit sits after the item that takes its place, which this
    // count does not follow: only a closing gap, which takes room, comes here.
    assert(
      !exit || !_exitsTakeNoExtent(context),
      'an exit counted before the laid-out range takes room',
    );
    var first = _firstLaidOut;
    if (first == null) {
      final laid = _laidOut();
      if (laid == null) return;
      first = _dataIndexOf(_FrameIndex(laid.first));
      if (first == null) return;
    }
    if (from != null && from < first) {
      first -= 1;
      if (moved && !exit) _slotsBefore -= 1;
    }
    if (to != null && to < first) {
      first += 1;
      if (moved) _slotsBefore += 1;
    }
    _firstLaidOut = first;
  }

  /// [_slotsBefore], for the sliver's rebuild in this build alone: the
  /// count, and the index it counts from, start over for the next turn.
  int _takeSlotsBefore() {
    final slots = _slotsBefore;
    _slotsBefore = 0;
    _firstLaidOut = null;
    return slots;
  }

  /// Settles the calls since the last build against the app's new data:
  /// reads each inserted item's key. An item count the calls do not
  /// explain ends every animation at once (E12).
  void _resolvePending(BuildContext context) {
    final layout = _layout;
    final count = layout.itemCount;
    final explained = count == _dataCount;
    // Read before the clear: where this turn's calls put each watched key.
    final watched = _watchedKeys();
    if (!explained) {
      _resetMotion();
      // The data shifted where no call says: the sliver keeps each slot's
      // offset by its number, and the index the count follows is stale.
      _slotsBefore = 0;
      _firstLaidOut = null;
    }
    _dataCount = count;
    final calls = List.of(_pending);
    if (_pending.isNotEmpty) {
      _settledPending = calls;
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
    // A move the list reported holds only once the app applies it, so its
    // keys are read where the app's data shows them, as after an app
    // rebuild.
    final read = _appRebuilt || calls.any((call) => call.reported);
    _appRebuilt = false;
    _knowBuiltKeys(
      calls: explained ? calls : const [],
      read: read,
      // A count the calls do not explain: the last frame's own count.
      changedFrom: explained ? null : _listCount,
    );
    _resolveIndices();
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
    if (_exits.any((exit) => exit.keepsState && !exit.ended)) {
      returning.addAll(_keysInView(keyAt));
    }
    _yieldExitsTo(returning);
    if (_fixedExtent) _endExitsPastEnd();
    _dropEndedExits(calls);
    // This build draws every exit left, so none adds a box after it.
    for (final exit in _exits) {
      exit.fresh = false;
    }
  }

  /// Maps each item a move the list knows put in a slot the last frame did
  /// not lay out to its index in this build ([_movedTo]): a key move, a
  /// screen-reader move, or a drop ([_moveTargets]), each key a call of
  /// this turn inserted ([_bookInsertedKeys]), and a raw move of a
  /// [watched] key ([_bookRawMoves]), booked again for each key in
  /// [dropped], and a call's shift of the item that holds focus
  /// ([_bookFocusedKey]). Read before the build settles the inserts and the
  /// fresh exits, which [_enteredSlot] counts.
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
      // A screen reader's move parks as a focused one does (R46).
      final node = _registeredNodeOf(key);
      _bookMovedKey(
        key,
        at,
        park: node != null && target.key == key && target.countsFocused(node),
      );
    }
    _bookInsertedKeys(keyAt, known);
    _bookRawMoves(watched, known, dropped);
    _bookParkedKey();
    _bookFocusedKey(watched);
  }

  /// Maps each key a call of this turn inserted to where the insert put it
  /// ([_movedTo]), laid out or not, and adds it to [known]: a `moveItem`
  /// call or a same-turn `removeItem` and `insertItem` of one key moves the
  /// element the list still holds for it, built or leaving, there in place,
  /// since no global key carries it (R47). A key whose slot the last frame
  /// did not lay out parks as [_bookMovedKey] parks it.
  void _bookInsertedKeys(
    Key? Function(_DataIndex index) keyAt,
    Set<Key> known,
  ) {
    for (final insert in _pendingInserts) {
      final key = keyAt(insert.index);
      if (key == null) continue;
      known.add(key);
      _bookMovedKey(key, insert.index);
      _movedTo.putIfAbsent(key, () => insert.index.value);
    }
  }

  /// Finds where each key the last build registered sits in the app's new
  /// data, since no global key carries an item's element there (R47): asks
  /// the app for each ([_appAnswer]); reads the last frame's laid-out range
  /// of the new data ([_readLaidOut]) when [read] holds and some key has no
  /// answer; else takes where [calls] put the key ([_knownAt]), never for a
  /// key the app answered null, which left its data. A key that moved past
  /// that range with no call and no answer still loses its State (L2, L3).
  /// [changedFrom] is the last frame's item count when no call explains the
  /// new one.
  void _knowBuiltKeys({
    required List<_Call> calls,
    required bool read,
    required int? changedFrom,
  }) {
    _appAt.clear();
    _knownAt.clear();
    _readLooks.clear();
    final built = <Key, _FrameIndex>{
      for (final MapEntry(key: index, value: look) in _itemLooks.entries)
        ?look.key: index,
    };
    final app = _layout.findChildIndexCallback != null;
    var unanswered = !app;
    if (app) {
      for (final key in built.keys) {
        if (_appAnswer(key) == null) unanswered = true;
      }
    }
    if (read && unanswered) _readLaidOut(built, changedFrom: changedFrom);
    for (final MapEntry(:key, value: index) in built.entries) {
      if (_knownAt.containsKey(key) || (app && _appAnswer(key) == null)) {
        continue;
      }
      final at = _dataIndexOf(index, calls: calls);
      if (at != null) _knownAt[key] = at.value;
    }
  }

  /// Reads the app's new data over the last frame's laid-out range through
  /// `itemBuilder`, once per index, and maps each key of [built], the keys
  /// the last build registered with the index each drew at, that it shows
  /// there ([_knownAt]). Keeps each widget it reads for [_buildItem], which
  /// the sliver builds that index with in this frame, so the read costs no
  /// call beyond the sliver's own (D9). Reads with the sliver's context,
  /// below the list's [Scrollable], where those widgets show.
  ///
  /// When the last frame laid the data out to its end and a count no call
  /// explains grew it from [changedFrom], the next frame lays out new slots
  /// past that end with no scroll (D9: L2 does not widen). The read goes on
  /// into those slots alone, as [_nextLayoutLast] counts them, so the
  /// sliver takes each widget it reads there, and stops once it finds every
  /// key the last frame laid out that the app's answer does not place.
  void _readLaidOut(Map<Key, _FrameIndex> built, {required int? changedFrom}) {
    final laid = _laidOut();
    final context = _listKey.currentContext;
    if (laid == null || context == null || _dataCount == 0) return;
    final unfound = {
      for (final MapEntry(:key, value: index) in built.entries)
        if (index.value >= laid.first &&
            index.value <= laid.last &&
            _appAt[key] == null)
          key,
    };
    void readAt(int i) {
      final look = _layout.itemBuilder(context, i);
      _readLooks[i] = look;
      final key = look.key;
      if (key == null || !built.containsKey(key)) return;
      _knownAt[key] = i;
      unfound.remove(key);
    }

    final end = _dataCount - 1;
    final last = laid.last.clamp(0, end);
    for (var i = laid.first.clamp(0, end); i <= last; i += 1) {
      readAt(i);
    }
    if (changedFrom != null && laid.last == changedFrom - 1) {
      final stop = _nextLayoutLast(laid, last: last, end: end);
      for (
        var i = last + 1;
        i <= stop && i <= end && unfound.isNotEmpty;
        i += 1
      ) {
        readAt(i);
      }
    }
    // A widget the sliver did not take never shows in a later frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _readLooks.clear());
  }

  /// The last index, at most [end], that the next layout lays out with no
  /// scroll after the last frame [laid] the data out to its end at [last].
  ///
  /// - Exact under `itemExtentBuilder`: it lays the new data out as the
  ///   sliver does, at the builder's extents, to the last frame's cache end.
  /// - Else an estimate, the room at the laid-out average, exact under one
  ///   extent: items shorter than that average lay out more slots, and a
  ///   laid-out key pushed past the estimate loses its State (L14, R54).
  /// - Laid-out items all of 0 extent give no average, so it reads on to
  ///   [end], past the slots new items with an extent take.
  int _nextLayoutLast(
    ({int first, int last, double extent, double room}) laid, {
    required int last,
    required int end,
  }) {
    final extentOf = _layout.itemExtentBuilder;
    final sliver = _sliver();
    if (extentOf != null && sliver is RenderSliverVariedExtentList) {
      final constraints = sliver.constraints;
      final cacheEnd =
          constraints.scrollOffset +
          constraints.cacheOrigin +
          constraints.remainingCacheExtent;
      final dimensions = sliver.layoutDimensions;
      // The sliver lays out every item that starts before the cache end.
      var offset = 0.0;
      var index = 0;
      while (index <= end && offset < cacheEnd) {
        final extent = extentOf(index, dimensions);
        if (extent == null) break;
        offset += extent;
        index += 1;
      }
      return index - 1;
    }
    final slots = laid.room / laid.extent;
    // A room with no bound lays the data out to its end.
    return slots.isFinite ? last + slots.ceil() : (slots > 0 ? end : last);
  }

  /// The app's `findChildIndexCallback` answer for [key] in this build
  /// ([_appIndexOf]), asked once per key per build ([_appAt]).
  int? _appAnswer(Key key) => _appAt.putIfAbsent(key, () => _appIndexOf(key));

  /// Resolves, once per build, the index each key the last frame built
  /// takes in this build ([_resolvedAt]), in D3's order: a move the list
  /// knows ([_movedTo]), the app's answer ([_appAt]), then the laid-out
  /// read or where this turn's calls put it ([_knownAt]). An answer never
  /// takes an index an earlier one holds, and a key the app answers null
  /// for has left its data, so the calls never place it: two keys never
  /// take one slot, which the sliver would resolve by dropping one element
  /// unseen.
  void _resolveIndices() {
    _resolvedAt.clear();
    final taken = <int>{};
    void take(Key key, int at) {
      if (!_resolvedAt.containsKey(key) && taken.add(at)) {
        _resolvedAt[key] = at;
      }
    }

    for (final MapEntry(:key, value: at) in _movedTo.entries) {
      take(key, at);
    }
    for (final MapEntry(:key, value: at) in _appAt.entries) {
      if (at != null) take(key, at);
    }
    for (final MapEntry(:key, value: at) in _knownAt.entries) {
      take(key, at);
    }
  }

  /// Maps the item [key], which a move put at [at] of the data, when the
  /// last frame did not lay out the slot it enters (invariant 35), and
  /// parks it when it holds focus or [park] asks; every other item takes
  /// the app's answer or the calls' shift ([_findIndex]).
  void _bookMovedKey(Key key, _DataIndex at, {bool park = false}) {
    if (_builtSlot(_enteredSlot(at))) return;
    _movedTo[key] = at.value;
    final node = _registeredNodeOf(key);
    if (node != null && (park || node.hasFocus)) _park(key, at, node);
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

  /// Books a call's shift of the item that holds focus, among [watched],
  /// with no app `findChildIndexCallback`: shown in the last frame
  /// ([_shownLastFrame]), the list follows and reveals it
  /// ([_followShiftOutOfView]), whether or not the slot it enters is laid
  /// out; not shown, kept alive off screen (R29), its element follows the
  /// call in place when the slot it enters is laid out, else is mapped to
  /// its index after this turn's calls, so its State and focus stay, with
  /// no jump and no reach (R35). With the callback, [_bookRawMoves] books
  /// the first, and the sliver's own answer for the key follows the second
  /// ([_appIndexOf]).
  void _bookFocusedKey(List<_Watched> watched) {
    if (_layout.findChildIndexCallback != null) return;
    for (final focused in watched) {
      final (:key, :at, :frame, :shown, node: _) = focused;
      if (frame == null || at.value == frame.value) continue;
      if (shown) {
        _followShiftOutOfView(focused);
        continue;
      }
      if (_builtSlot(_enteredSlot(at))) continue;
      _movedTo.putIfAbsent(key, () => at.value);
    }
  }

  /// Follows the shift this turn's calls gave the item that holds focus,
  /// [watched], that showed in the last frame ([_shownLastFrame]): booked
  /// as a raw move to the item's new index (D17), so the list keeps the
  /// item, jumps toward it at the next frame's start when its new slot is
  /// not laid out, and reveals it, as it reveals a moved item (FR-05 E04),
  /// in each viewport that showed it in the last frame and no other
  /// ([_viewportsShowing]): a viewport around the list that did not show
  /// it is the app's to scroll (D28).
  /// An item with a move of its own running ([_focusOwned]), or one that
  /// did not show when the data changed (R36), books nothing. Returns
  /// whether it booked the follow.
  bool _followShiftOutOfView(_Watched watched) {
    final (:key, :at, :node, :frame, :shown) = watched;
    if (frame == null || at.value == frame.value || _focusOwned(key)) {
      return false;
    }
    if (!shown) return false;
    _bookRawMove(
      key,
      node,
      from: at,
      to: at,
      revealIn: _viewportsShowing(node),
    );
    return true;
  }

  /// The keys a build follows by key, each with its key node, the index of
  /// the current data this turn's calls put it at, and, for the item that
  /// holds primary focus, the frame index it drew at and whether its box
  /// showed in the viewport then ([_shownLastFrame], read before this
  /// frame's layout): the parked item, by [_parkedAt]; the lifted item a
  /// raw move took, by its follow's target ([_liftedFollow]); and the item
  /// that holds primary focus, by [_dataIndexOf]. The app's
  /// `findChildIndexCallback` answers for each of them ([_bookRawMoves]);
  /// with no callback, only a call can shift the focused item
  /// ([_bookFocusedKey]), so a turn with none watches nothing. Read before
  /// the build clears [_pending] (invariant 35).
  List<_Watched> _watchedKeys() {
    if (_layout.findChildIndexCallback == null && _pending.isEmpty) {
      return const [];
    }
    final parkedKey = _parkedKey;
    final parkedAt = _parkedAt;
    final parkedNode = _parkedNode;
    final watched = <_Watched>[
      if (parkedKey != null && parkedAt != null && parkedNode != null)
        (
          key: parkedKey,
          at: parkedAt,
          node: parkedNode,
          frame: null,
          shown: false,
        ),
    ];
    // The lifted item a raw move took is watched by its follow's target
    // until the drag lets it go ([_liftedLetGo]); the walk below skips it,
    // so it is watched once.
    Key? liftedKey;
    if (_liftedFollow case (:final target, :final node)) {
      final (key, at) = (target.key, target.index);
      if (key != null && at != null && key != parkedKey) {
        liftedKey = key;
        watched.add((key: key, at: at, node: node, frame: null, shown: false));
      }
    }
    for (final MapEntry(key: index, value: node) in _itemNodes.entries) {
      final key = _lookAt(index)?.key;
      if (key == null || key == parkedKey || !node.hasFocus) continue;
      if (key == liftedKey) continue;
      final at = _dataIndexOf(index);
      if (at != null) {
        // A lifted item reads as shown even when its slot scrolled away:
        // the EndUser's drag owns the scroll, and the list never reveals
        // against it (R45).
        final shown = key == _liftedKey || _shownLastFrame(node);
        watched.add((key: key, at: at, node: node, frame: index, shown: shown));
      }
    }
    return watched;
  }

  /// Whether the box of the item whose key node is [node] showed inside
  /// the list's own viewport in the last frame, by more than 0 px along
  /// its axis (D28, invariant 35); see [_viewportsShowing].
  bool _shownLastFrame(FocusNode node) =>
      _viewportsShowing(node, outward: false).isNotEmpty;

  /// The viewports, from the list's own outward while each shows it, that
  /// showed the box of the item whose key node is [node] in the last frame:
  /// by more than 0 px along each viewport's own axis, of the part every
  /// nearer viewport showed (D28, invariant 35); the list's own alone
  /// unless [outward]. A kept-alive box, one not yet laid out, and a null
  /// context show in none; nor does one whose element left the tree in this
  /// frame and is not yet unmounted: [Element.renderObject] (unlike
  /// [BuildContext.findRenderObject], which asserts the element active)
  /// only stops at a defunct one, so it reads that inactive element's
  /// detached render object with no throw.
  Set<ScrollableState> _viewportsShowing(
    FocusNode node, {
    bool outward = true,
  }) {
    final showing = <ScrollableState>{};
    final context = node.context;
    if (context == null || !context.mounted) return showing;
    final object = (context as Element).renderObject;
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return showing;
    }
    var shown = MatrixUtils.transformRect(
      object.getTransformTo(null),
      object.semanticBounds,
    );
    for (
      var scrollable = Scrollable.maybeOf(context);
      scrollable != null;
      scrollable = outward ? Scrollable.maybeOf(scrollable.context) : null
    ) {
      final view = (scrollable.context as Element).renderObject;
      if (view is! RenderBox || !view.attached || !view.hasSize) break;
      final viewport = MatrixUtils.transformRect(
        view.getTransformTo(null),
        Offset.zero & view.size,
      );
      final vertical =
          axisDirectionToAxis(scrollable.axisDirection) == Axis.vertical;
      final shows = vertical
          ? shown.top < viewport.bottom && shown.bottom > viewport.top
          : shown.left < viewport.right && shown.right > viewport.left;
      if (!shows) break;
      showing.add(scrollable);
      shown = shown.intersect(viewport);
    }
    return showing;
  }

  /// Asks the app where each [watched] key sits in its data: an answer that
  /// differs from the index this turn's calls give the key, with no move of
  /// it the list knows ([known]), is a raw move ([_bookRawMove]), and so is
  /// any answer for a key whose move target the build dropped ([dropped]).
  /// A null answer, or one past the data, books none; for the parked key it
  /// means the key left the data ([_releaseGone]).
  ///
  /// The item that holds focus, that did not show when the data changed
  /// ([_shownLastFrame]), kept alive off screen (R29), with no move of its
  /// own running ([_focusOwned]), books no raw move: the sliver's own
  /// answer for its key follows its shift or raw move in place, silently,
  /// with no park, jump, or reach, and the next focus move or reorder key
  /// reveals it (R36). An answer that confirms a call's shift of a shown
  /// item out of view follows it ([_followShiftOutOfView]).
  void _bookRawMoves(List<_Watched> watched, Set<Key> known, Set<Key> dropped) {
    final app = _layout.findChildIndexCallback;
    if (app == null) return;
    for (final entry in watched) {
      final (:key, :at, :node, :frame, :shown) = entry;
      if (known.contains(key)) continue;
      final answer = app(key);
      if (answer == null || answer < 0 || answer >= _dataCount) {
        if (key == _parkedKey) _releaseGone(key);
        continue;
      }
      final to = _DataIndex(answer);
      final rebooked = dropped.contains(key);
      if (to == at && !rebooked) {
        _followShiftOutOfView(entry);
        continue;
      }
      final offScreen = frame != null && !shown;
      if (offScreen && !rebooked && !_focusOwned(key)) continue;
      _bookRawMove(key, node, from: at, to: to);
    }
  }

  /// Drops every booked move target when an item count no call explains
  /// meets the app's callback: no call shifted them across that count, so
  /// each may name another key or an index past the data. Each one's jump
  /// and follow then do nothing, and the key move that waits to speak stays
  /// silent; returns the keys of the focused moves among them, which the
  /// watch books again from the app's answers (R25).
  Set<Key> _dropMoveTargets() {
    final keys = <Key>{};
    for (final target in _moveTargets) {
      final key = target.key;
      if (key != null) keys.add(key);
      target.index = null;
    }
    _moveTargets.clear();
    // The key move waiting to speak has nothing true to say either.
    _keyMove?.index = null;
    return keys;
  }

  /// The move targets each call shifts: every booked move's, and the key
  /// move that waits to speak after its frame dropped it from
  /// [_moveTargets], so it speaks where the item sits then (R42).
  List<_MoveTarget> get _shiftedTargets {
    final speaking = _keyMove;
    if (speaking == null || _moveTargets.contains(speaking)) {
      return _moveTargets;
    }
    return [..._moveTargets, speaking];
  }

  /// Books the raw move of the watched item [key], whose key node is
  /// [node], from [from] to [to] of the current data as a move the list
  /// knows: mapped and parked when the last frame did not lay out the slot
  /// it enters, then followed ([_followRawMove]); a lifted item's follow
  /// waits for the drag proxy to let it go ([_liftedFollow]). A shift that
  /// another item's raw move gives the item books the same way, and so does
  /// a call's shift of the focused item out of view, from [to] to [to]
  /// ([_followShiftOutOfView]), which reveals it in [revealIn]. The move
  /// re-aims a reach that looks for the item, as `moveItem` does, and an
  /// earlier move of the item reveals nothing (invariant 35).
  void _bookRawMove(
    Key key,
    FocusNode node, {
    required _DataIndex from,
    required _DataIndex to,
    Set<ScrollableState>? revealIn,
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
    final target = _MoveTarget(
      to,
      key: key,
      gap: from < to ? from : from + 1,
      revealIn: revealIn,
    );
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
  /// it, else of the laid-out item nearest the gap that holds one
  /// ([_nearestStopTo], R37), else the list's own Tab stop; with no laid-out
  /// neighbor, the hold node, while [_handOffFocus] reaches toward the gap
  /// after the frame.
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
              _nearestStopTo(gap, reveal: false) ??
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

  /// The index the last build registered the key node [node] at, the slot
  /// the sliver gave the node's item by its key; null when it registered
  /// none.
  _FrameIndex? _registeredIndexOf(FocusNode node) {
    for (final MapEntry(key: index, value: registered) in _itemNodes.entries) {
      if (registered == node) return index;
    }
    return null;
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

  /// The items [keys] are in the data while their old copies still leave,
  /// so no key sits twice: a copy in its kept look ends at once, since that
  /// look may hold the app's own global keys; a `builder` copy gives up
  /// the item's State and keeps leaving.
  void _yieldExitsTo(Set<Key> keys) {
    if (keys.isEmpty) return;
    for (final exit in _exits) {
      // A moved item's closing slot holds neither its look nor its State,
      // nor does an ended exit's empty slot.
      if (exit.closing || exit.ended || !keys.contains(exit.subKey)) continue;
      if (exit.builder != null) {
        exit.keepsState = false;
      } else {
        _endExit(exit);
      }
    }
  }

  /// The keys of the data's items from the first index the last build drew
  /// to its last, plus one per running leaving item: a closing gap shows
  /// one more, and an ended one shows none.
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
    final stop = end + _exits.where((exit) => !exit.ended).length;
    return {for (var i = start; i <= stop && i < _dataEnd; i += 1) ?keyAt(i)};
  }

  /// Ends at once each removed item past the last item of the data: a
  /// fixed extent gives it no room and no item to fade over (E11).
  void _endExitsPastEnd() {
    for (final exit in _exits) {
      if (exit.gap >= _dataEnd) _endExit(exit);
    }
  }

  /// Ends every insert and remove animation at once.
  void _resetMotion() {
    for (final insert in _pendingInserts) {
      insert.motion.dispose();
    }
    for (final motion in _incoming.values) {
      motion.dispose();
    }
    _exits.forEach(_endExit);
    _pendingInserts.clear();
    _incoming.clear();
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
    if (target == null) {
      // A repeat of a held key is the same blocked attempt (R42).
      if (event is KeyDownEvent) _announceBlocked(intent);
      return KeyEventResult.handled;
    }
    // A drag ends first, as a call ends it (invariant 28): the move changes
    // the data under it. A settling drop completes at once instead, its move
    // reported, then this move runs (R52).
    _endDragForInput();
    final moved = _reportMove(
      index,
      from,
      target,
      intent: intent,
      node: node,
      edgeJump: intent == _MoveIntent.start || intent == _MoveIntent.end,
      byKey: true,
    );
    _pressMoved(event, moved);
    return KeyEventResult.handled;
  }

  /// Books [moved], the move of the key [event] presses, as the key move
  /// that speaks once every pressed key is up (R42); any earlier one it
  /// replaces never speaks.
  void _pressMoved(KeyEvent event, _MoveTarget moved) {
    _pressedKeys.add(event.physicalKey);
    _keyMove = moved;
    _keyMoveLanded = false;
    if (_hearsKeyUp) return;
    _hearsKeyUp = true;
    HardwareKeyboard.instance.addHandler(_handleKeyUp);
  }

  /// Marks the key move [moved] as landed once the frame after it has run,
  /// and speaks it when ready; one a later move in the same frame outdid,
  /// [silent], never speaks. An earlier key move a later one replaced
  /// lands with no effect.
  void _landKeyMove(_MoveTarget moved, {required bool silent}) {
    if (moved != _keyMove) return;
    if (silent) {
      _keyMove = null;
    } else {
      _keyMoveLanded = true;
    }
    _speakKeyMove();
  }

  /// Lets go of the key [event] lets go, wherever focus is, and speaks the
  /// key move when ready. Handles nothing.
  bool _handleKeyUp(KeyEvent event) {
    if (event is KeyUpEvent) {
      _pressedKeys.remove(event.physicalKey);
      _speakKeyMove();
    }
    return false;
  }

  /// Announces the key move, where its item sits now, once its frame has
  /// run and every pressed key is up, and stops listening for key-ups once
  /// no key is pressed.
  void _speakKeyMove() {
    if (_pressedKeys.isNotEmpty) return;
    if (_hearsKeyUp) {
      _hearsKeyUp = false;
      HardwareKeyboard.instance.removeHandler(_handleKeyUp);
    }
    final moved = _keyMove;
    if (moved == null || !_keyMoveLanded) return;
    _keyMove = null;
    _announceMove(moved);
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
  /// and ends a drag first, as a call does (FR-03 E08); a settling drop it
  /// completes at once instead (R52).
  /// Every screen-reader action, once reported, books a focused move's jump
  /// for the next frame's start when its slot is not laid out
  /// ([_bookMoveJump], R46), which [_jumpForMove] makes exact at the data's
  /// first or last slot, so the moved item keeps its State; only an
  /// unfocused drop to either end keeps the exact edge jump
  /// ([_bookFrameJump]).
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
    if (!drop) _endDragForInput();
    // A screen-reader move takes a focused move's jump (R46); only a drop
    // keeps its own edge jump.
    final edge =
        drop && (target == const _DataIndex(0) || target == _dataEnd - 1);
    _reportMove(
      index,
      from,
      target,
      intent: intent,
      node: _nodeAt(index),
      edgeJump: edge && !_builtSlot(to.slot),
      byKey: false,
      screenReader: !drop,
    );
  }

  /// Books the move of the item the last build drew at [index], whose key
  /// node is [node], from [from] to [to] of the current data, registers its
  /// target, reports it through `onReorderItem`, and only then books its
  /// jump for the next frame's start ([_readySlot]), so a call the app's
  /// report handler makes moves the target before the jump reads it. With
  /// [edgeJump] the jump goes to the edge [to] lies at. A screen-reader
  /// move or a drop is announced after that frame; a key move, [byKey],
  /// once its press ends ([_pressMoved]); of the moves that land in one
  /// frame, only the last ([_lastReported]). Returns the move's target.
  _MoveTarget _reportMove(
    _FrameIndex index,
    _DataIndex from,
    _DataIndex to, {
    required _MoveIntent? intent,
    required FocusNode? node,
    required bool edgeJump,
    required bool byKey,
    bool screenReader = false,
  }) {
    final key = _lookAt(index)?.key;
    _endExitsBeside(index);
    _bookReportedMove(from, to);
    // R46: an item a screen-reader action moves counts as the focused moved
    // item at every distance.
    final moved = _targetFor(from, to, node, key, asFocused: screenReader);
    _moveTargets.add(moved);
    _lastReported = moved;
    _layout.onReorderItem(from.value, to.value);
    final toStart = to == const _DataIndex(0);
    _readySlot(moved, node, edgeJump: edgeJump, toStart: toStart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _afterMove(moved, byKey: byKey);
      final last = moved == _lastReported;
      if (last) _lastReported = null;
      if (byKey) {
        _landKeyMove(moved, silent: !last);
      } else if (last) {
        _announceMove(moved);
      }
    });
    return moved;
  }

  /// Announces where [moved] put its item, in the frame after the move,
  /// with the data count then; silent once a call took the item out.
  void _announceMove(_MoveTarget moved) {
    final index = moved.index;
    if (!mounted || index == null) return;
    final position = index.value + 1;
    _announce(
      _layout.moveAnnouncement?.call(position, _dataCount) ??
          builtInLabelsOf(context)
              .reorderMoveAnnouncement(position, _dataCount),
    );
  }

  /// Announces that a reorder key with [intent] meets an end of the list:
  /// the start for `start` and `previous`, the end for `next` and `end`.
  void _announceBlocked(_MoveIntent intent) {
    _announce(switch (intent) {
      _MoveIntent.start || _MoveIntent.previous =>
        _layout.atStartAnnouncement ??
            builtInLabelsOf(context).reorderAtStartAnnouncement,
      _MoveIntent.next || _MoveIntent.end =>
        _layout.atEndAnnouncement ??
            builtInLabelsOf(context).reorderAtEndAnnouncement,
    });
  }

  /// Sends [text] to the screen reader: as an announcement where the
  /// platform supports one, else through the live-region node, which
  /// leaves the tree [_liveHold] later. An empty text, an app override's
  /// way to word its own, sends nothing.
  void _announce(String text) {
    if (text.isEmpty || !mounted) return;
    if (MediaQuery.maybeSupportsAnnounceOf(context) ?? false) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          text,
          Directionality.of(context),
        ),
      );
      return;
    }
    setState(() {
      _liveText = text;
      _liveCount += 1;
    });
    _liveTimer?.cancel();
    _liveTimer = Timer(_liveHold, () {
      if (mounted) setState(() => _liveText = null);
    });
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
    _countSlotsBefore(from: from, to: to);
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
  /// that holds focus, whose key node is [node], whatever its intent, or of
  /// any item a screen-reader action moves, [asFocused] (R46), keeps the
  /// item's [key] and the gap it left, for its jump ([_readySlot]) and for
  /// the reach should the frame not lay its slot out ([_reachStep]). A
  /// screen-reader move of an item whose node does not hold focus is marked
  /// [_MoveTarget.screenReader]: the list never places or hands on input
  /// focus for it.
  _MoveTarget _targetFor(
    _DataIndex from,
    _DataIndex to,
    FocusNode? node,
    Key? key, {
    bool asFocused = false,
  }) {
    if (node == null || key == null || !(asFocused || node.hasFocus)) {
      return _MoveTarget(to);
    }
    // The slot the item left, by the index of the item now after it.
    return _MoveTarget(
      to,
      key: key,
      gap: from < to ? from : from + 1,
      screenReader: !node.hasFocus,
    );
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

  /// Ends at once the leaving items beside the built item at [index], which
  /// a reorder moves (FR-04 E14): those just before it, and, past the last
  /// item, those after it. A closing gap stays: it closes in step with its
  /// own moved item, so the items past both slots hold still (FR-05), and
  /// in a sliver child of its own it never travels with another item
  /// (R47). An exit already ended stays as it is ([_endExit]).
  void _endExitsBeside(_FrameIndex index) {
    final at = _dataIndexOf(index);
    if (at == null) return;
    final last = at == _dataEnd - 1;
    var ended = false;
    for (final exit in _exits) {
      if (exit.closing || exit.ended) continue;
      if (exit.gap != at && !(last && exit.gap >= _dataEnd)) continue;
      _endExit(exit);
      ended = true;
    }
    if (ended) setState(() {});
  }

  /// Starts a drag, and ends it at once when it starts between a call, or a
  /// move the list reported (R6), and the frame that settles it: that frame
  /// would build a leaving copy, or the dragged item at another index,
  /// whose keys the drag proxy holds. A start that completed the settling
  /// drop of its own pointer down (R52) skips that end for the drop's own
  /// booking.
  void _handleReorderStart(int index) {
    final dragged = _FrameIndex(index);
    _dragIndex = dragged;
    final key = _lookAt(dragged)?.key;
    _dragged = key == null ? null : (key: key, start: dragged);
    _inReorderStart = true;
    try {
      _layout.onReorderStart?.call(index);
      final state = _listKey.currentState;
      final ownDrop = state is _ReorderSliverState && state.completesOwnDrop();
      if (_pending.isNotEmpty && !ownDrop) _cancelDrag();
    } finally {
      _inReorderStart = false;
    }
  }

  /// The sliver's `findChildIndexCallback`: a leaving item's or closing
  /// gap's own slot in the frame plan, else the data index this build
  /// resolved for the key ([_resolveIndices], D3), which the plan turns
  /// into its slot; else null (invariant 35). No item has a global key, so
  /// this answer alone moves an item's element, and its State, to its new
  /// slot (R47).
  int? _findIndex(Key key) {
    if (key is! _IndexFreeKey) return null;
    final itemKey = key.value;
    // A slot the list owns answers from the plan alone, so its key never
    // reaches the app (the callback gets only keys `itemBuilder` gave).
    if (itemKey is _ExitKey) return _plan.slotOfExit(itemKey);
    final leaving = _plan.slotOfExit(itemKey);
    if (leaving != null) return leaving;
    final at = _resolvedAt[itemKey];
    return at == null ? null : _plan.slotOfData(at);
  }

  /// The index of the app's data this build draws the item [key] at, by
  /// the app's `findChildIndexCallback`; null with no callback, or when the
  /// app does not know the key or answers past its data. Asked once
  /// [_pending] is clear, so the app's index is this build's;
  /// [_builtIndexOf] maps to the last frame.
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

  /// Ends the drag or settling drop an EndUser input this body is about to
  /// run would land in: a settling drop completes at once, its move
  /// reported (R52); a live drag ends as a call ends it (E06).
  void _endDragForInput() {
    final state = _listKey.currentState;
    if (state is _ReorderSliverState && state.isSettlingDrop) {
      state.completeSettlingDrop();
      return;
    }
    _cancelDrag();
  }

  /// Cancels a drag in progress before an insert, remove, or move, or one
  /// that starts before their frame (E06): the dragged item returns to its
  /// slot, `onReorderEnd` fires at once with the index the drag started at,
  /// and `onReorderItem` does not fire. A dropped item still settling ends
  /// the same way, with no second `onReorderEnd`. A key move or a
  /// screen-reader move takes [_endDragForInput] instead, which completes
  /// a settling drop (R52).
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

  /// The reorder sliver lifted the item [key]; it stays in its own slot,
  /// hidden, while the drag proxy shows a raster of it (R49). The lift is
  /// a move of the item (D12): it ends, at once, each leaving item drawn
  /// beside it, as a key move does ([_endExitsBeside]), and the item's own
  /// grow-in, before the drag proxy's raster is taken, so it shows the
  /// item at full size with no leaving item riding it (FR-04 E14,
  /// invariant 30). The grow-in ends through [_endInsert], [_finishInsert]'s
  /// own bookkeeping, so its entry leaves [_incoming] and its motion
  /// disposes, as every other ended motion does; freezing the value alone
  /// would strand the entry and its `AnimationController` undisposed,
  /// since a direct value write cancels the `forward()` that was to call
  /// [_finishInsert] itself. This runs inside the drag's own gesture
  /// callback, so it skips [_finishInsert]'s own [setState]: the drag
  /// that follows rebuilds the list on its own.
  void _liftedTook(Key key) {
    _liftedKey = key;
    // The EndUser's newest input wins: a drag that starts while a reach
    // runs ends it at once, on its stale token, and the item it looked
    // for stays parked off screen with its State and focus (R29, FR-04
    // E20). Nothing scrolls back: the reach commits its jump outside the
    // frame pipeline (R45), so a jump the last laid-out frame has not
    // shown yet is reverted first, before the sliver's own flushLayout,
    // right after this, reads a render tree that jump never let a frame
    // lay out.
    _revertUncommittedReachJump();
    _stopReach();
    final index = _dragIndex;
    if (index != null) _endExitsBeside(index);
    final motion = _incoming[key];
    if (motion != null) {
      motion.controller.value = 1;
      _endInsert(motion);
    }
  }

  /// The reorder sliver let the item [key] go: its drag reset, often
  /// inside the build that ends the drag.
  void _liftedLetGo(Key key) {
    if (_liftedKey == key) _liftedKey = null;
    if (_dragged?.key == key) _dragged = null;
    // A raw move of the lifted item follows it only now (invariant 28).
    final follow = _liftedFollow;
    if (follow == null || follow.target.key != key) return;
    // The drag can end inside a build, so the follow runs after that
    // frame and keeps the frame the drag's end took: a count change in the
    // next turn still re-aims it (R25). The watch reads the item from its
    // follow until then.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (_liftedFollow != follow) return;
        _liftedFollow = null;
        if (mounted) _followRawMove(follow.target, follow.node);
      })
      ..scheduleFrame();
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
  /// it is revealed again as each such grow-in ends (R10). A move with
  /// [_MoveTarget.revealIn] reveals in those viewports only, through the
  /// reach too.
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
    final levels = moved.revealIn;
    _revealOwn(node, origin: moved.origin, levels: levels);
    for (final MapEntry(key: at, value: look) in _itemLooks.entries) {
      final motion = at < built ? _incoming[look.key] : null;
      if (motion == null) continue;
      _revealAfterGrowIn(node, motion, byKey: byKey, levels: levels);
    }
  }

  /// The frame did not lay out the slot of a focused move, now [at]: the
  /// list reaches the slot as a move call's follow does, with the gap the
  /// item left (FR-03 E09, FR-05 E04). The item is parked, its key node
  /// [node] still counting as focused ([_MoveTarget.countsFocused], R46),
  /// or its State is gone and no node holds primary focus; a focus the app
  /// moved elsewhere in the move's turn stays, and the park ends (R13). The
  /// reach places and hands on input focus only for an item whose node held
  /// focus at the action: an unfocused screen-reader move's item is reached
  /// and revealed, and primary focus stays where it is (R46, R13).
  void _reachStep(_MoveTarget moved, _FrameIndex at, FocusNode? node) {
    final key = moved.key;
    final gap = moved.gap;
    if (key == null || gap == null) return;
    // A screen reader's move parks an unfocused item too (R46).
    final parked =
        node != null && node.context != null && moved.countsFocused(node);
    if (!parked && FocusManager.instance.primaryFocus != null) {
      _releasePark(key);
      return;
    }
    _startReach(
      at,
      key,
      gap,
      origin: moved.origin,
      levels: moved.revealIn,
      placesFocus: !moved.screenReader,
    );
  }

  /// Reveals the moved item whose key node is [node] again in the frame
  /// [motion], the grow-in of an item before it, completes (R10): after a
  /// key move only while the item keeps focus, as E16's second reveal;
  /// with [levels], in those viewports only.
  /// Disposing [motion] before it completes drops the listener with it.
  void _revealAfterGrowIn(
    FocusNode node,
    _ItemMotion motion, {
    required bool byKey,
    Set<ScrollableState>? levels,
  }) {
    final generation = _scrollGeneration;
    void grown(AnimationStatus status) {
      if (!status.isCompleted) return;
      motion.controller.removeStatusListener(grown);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A FocusNode keeps its context once disposed: the item is live
        // only while its node is registered.
        if (!mounted || !_itemNodes.containsValue(node)) return;
        // A scroll that took the item out of view since the move leaves
        // it there (invariant 26).
        if (_scrollTookOffScreen(node, generation)) return;
        if (!byKey || node.hasFocus) {
          _revealOwn(node, levels: levels);
        }
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
  /// there; when the reach gives up, or when neither laid-out neighbor holds
  /// a node that takes focus, focus goes to the laid-out item nearest the
  /// gap that holds one ([_nearestStopTo], R37), and only with none to the
  /// list's own Tab stop, so focus stays in the list while it can take it
  /// (invariant 26). With [interim], the node the list focused while it
  /// reaches, a focus the app moves off it ends the handoff (R13,
  /// invariant 32); when nothing in the list can take focus, [interim] lets
  /// it go and Flutter's own fallback applies, the scope's previous child or
  /// the scope itself, as when a focused node detaches (R33). [origin] is
  /// the offset this handoff started at, read once and carried through its
  /// retries unchanged; each probe jump still moves to the plain edge
  /// ([_estimateTowards]), and only the landing reveal ([_revealHandOff])
  /// clamps to the least scroll from [origin] (D29, G5).
  void _handOffFocus(
    _DataIndex gap, {
    int frames = _reachFrames,
    FocusNode? interim,
    ({ScrollPosition position, double pixels})? origin,
  }) {
    if (!mounted) return;
    if (interim != null && FocusManager.instance.primaryFocus != interim) {
      return;
    }
    final start = origin ?? _currentOrigin;
    final next = _builtNear(gap, 1);
    final previous = _builtNear(gap - 1, -1);
    final target =
        (next == null ? null : _firstStopOf(next, reveal: false)) ??
        (previous == null ? null : _firstStopOf(previous, reveal: false));
    if (target != null) {
      target.requestFocus();
      _revealHandOff(target, origin: start);
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
            _handOffFocus(
              held.index,
              frames: frames - 1,
              interim: interim,
              origin: start,
            );
          })
          ..scheduleFrame();
        return;
      }
    }
    final nearest = _nearestStopTo(gap);
    if (nearest != null) {
      nearest.requestFocus();
      _revealHandOff(nearest, origin: start);
      return;
    }
    final own = _ownTabStop();
    if (own != null) {
      requestFocusInViewports(own);
    } else {
      interim?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  /// Reveals [node], the node a handoff focuses, from [origin] when a
  /// reach gave it, now and again after the frame in which each motion
  /// running now ends, an exit shrinking or an item growing in, by the
  /// plain edge rule, while [node] keeps focus: either may shift it past
  /// the edge it was revealed at, as a returned item's own grow-in does
  /// (invariant 26). Under reduced motion no size animates, so the first
  /// reveal stands and each later one finds [node] whole.
  void _revealHandOff(
    FocusNode node, {
    ({ScrollPosition position, double pixels})? origin,
  }) {
    _revealOwn(node, origin: origin);
    final motions = {
      for (final exit in _exits) exit.motion,
      ..._incoming.values,
    };
    final generation = _scrollGeneration;
    for (final motion in motions) {
      final controller = motion.controller;
      void ended(AnimationStatus status) {
        if (status.isAnimating) return;
        controller.removeStatusListener(ended);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // A scroll that took the item out of view since the handoff
          // leaves it there (invariant 26).
          if (mounted &&
              node.hasFocus &&
              !_scrollTookOffScreen(node, generation)) {
            _revealOwn(node);
          }
        });
      }

      controller.addStatusListener(ended);
    }
  }

  /// The first node in Tab order of the laid-out item nearest [gap] of the
  /// current data by data index, the first one after the gap, else the
  /// last one before it, revealed by [firstTabStopIn] when [reveal] is
  /// true; null when the frame laid out no item that holds one. Only the
  /// item it returns is revealed.
  FocusNode? _nearestStopTo(_DataIndex gap, {bool reveal = true}) {
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
      final stop = _firstStopOf(index, reveal: reveal);
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

  /// Reveals the item whose key node is [node] by [revealInViewports], from
  /// [origin] when a reach gave it, now and again in the frame its grow-in
  /// motion under [key] completes, by the plain edge rule: the item grows
  /// past the viewport's edge as it enters (E16). With [levels], only in
  /// those viewports.
  void _revealReturned(
    FocusNode node,
    Key key, {
    ({ScrollPosition position, double pixels})? origin,
    Set<ScrollableState>? levels,
  }) {
    _revealOwn(node, origin: origin, levels: levels);
    final motion = _incoming[key];
    if (motion == null) return;
    final generation = _scrollGeneration;
    void grown(AnimationStatus status) {
      if (!status.isCompleted) return;
      motion.dropGrown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A scroll that took the item out of view since the return leaves
        // it there (invariant 26).
        if (mounted &&
            _itemNodes.containsValue(node) &&
            node.hasFocus &&
            !_scrollTookOffScreen(node, generation)) {
          _revealOwn(node, levels: levels);
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

  /// The offset the last laid-out frame showed, before the reach's own
  /// jump that frame has not laid out yet, if one is still pending; null
  /// once that jump's own frame confirms it (read at [_reach]'s own
  /// entry). The reach commits each jump outside the frame pipeline
  /// (R45), so a newer input meeting it before that frame runs
  /// ([_stopReach]) restores this instead of leaving the screen at an
  /// offset no frame has shown.
  ({ScrollPosition position, double pixels})? _reachUncommittedJump;

  /// The key of the item the reach in progress looks for: its end releases
  /// that item's park (invariant 35).
  Key? _reachKey;

  /// The gap of each reach given up away from where it started, as an
  /// index of the current data, until the frame after the list jumps back
  /// hands focus on from it: each call moves them, as it moves
  /// [_handoffGap] (D7).
  final _givenUpGaps = <_HeldGap>[];

  /// How many scroll notifications from this list's own Scrollable
  /// arrived since the list last mounted, outside a reveal of its own:
  /// a re-reveal that waits for a motion to end reads it to learn whether
  /// a scroll took its item out of view since the move or handoff that
  /// first revealed it (invariant 26).
  int _scrollGeneration = 0;

  /// How many of the list's own reveals ([revealInViewports] calls this
  /// State makes) are running: while one is, its jumps are the list's own
  /// scroll and count for no re-reveal's skip (invariant 26).
  int _revealDepth = 0;

  /// Whether a scroll since [generation] took the item whose key node is
  /// [node] out of view: a scroll the EndUser or the app made after the
  /// move or handoff that first revealed it, which leaves the item off
  /// screen (invariant 26, FR-03 E11).
  bool _scrollTookOffScreen(FocusNode node, int generation) =>
      _scrollGeneration != generation && !_shownLastFrame(node);

  /// Reveals [node] through [revealInViewports] with [_revealDepth] held,
  /// so the jumps the reveal makes leave [_scrollGeneration] alone
  /// (invariant 26).
  void _revealOwn(
    FocusNode node, {
    ({ScrollPosition position, double pixels})? origin,
    Set<ScrollableState>? levels,
  }) {
    _revealDepth += 1;
    try {
      revealInViewports(node, origin: origin, levels: levels);
    } finally {
      _revealDepth -= 1;
    }
  }

  /// Starts [_reach] in a microtask after this frame's post-frame
  /// callbacks. Flutter moves focus off the item's disposed node in its own
  /// microtask, queued earlier in the frame, so the reach starts from the
  /// focus Flutter settled on, and only a later move ends it.
  /// [origin], when given, is the offset a failed reach returns to, in place
  /// of the one before its own first jump (R5 for moves); [levels] limits
  /// the viewports that reveal the reached item. Without [placesFocus] the
  /// reach neither focuses the item nor hands focus on from its gap (R46).
  void _startReach(
    _FrameIndex index,
    Key key,
    _DataIndex gap, {
    ({ScrollPosition position, double pixels})? origin,
    Set<ScrollableState>? levels,
    bool placesFocus = true,
  }) {
    final token = Object();
    final previous = _reachKey;
    if (previous != null && previous != key) _releasePark(previous);
    _reachToken = token;
    _reachGap = gap;
    _reachKey = key;
    scheduleMicrotask(() {
      final settled = FocusManager.instance.primaryFocus;
      _reach(
        token,
        index,
        key,
        settled,
        _reachFrames,
        origin,
        levels: levels,
        placesFocus: placesFocus,
      );
    });
  }

  /// Ends the reach in progress and the park of the item it looked for.
  void _endReach() {
    final key = _reachKey;
    _stopReach();
    if (key != null) _releasePark(key);
  }

  /// Ends the reach in progress and leaves its item parked. Drops
  /// [_reachUncommittedJump] with no jump of its own: a scroll
  /// notification mid its own activity calls this too ([_endsReachOn]),
  /// where a nested jumpTo would corrupt that activity's own state; only
  /// [_revertUncommittedReachJump] (a drag's own lift, never a scroll)
  /// acts on it, and does so first.
  void _stopReach() {
    _reachUncommittedJump = null;
    _reachToken = null;
    _reachGap = null;
    _reachKey = null;
  }

  /// Reverts the reach's own jump the last laid-out frame has not shown
  /// yet, if one is pending, to the offset that frame did show (R45): a
  /// drag's own lift runs its layout flush synchronously right after, and
  /// with nothing left uncommitted that flush finds nothing new to lay
  /// out, so it never retires the item under the drag's own touch (FR-04
  /// E20). Call before [_stopReach] drops the record with no jump.
  void _revertUncommittedReachJump() {
    final uncommitted = _reachUncommittedJump;
    if (uncommitted == null) return;
    final live = _livePositionOf(uncommitted.position) ?? uncommitted.position;
    if (live.pixels != uncommitted.pixels) live.jumpTo(uncommitted.pixels);
  }

  /// Reaches slot [index], where the item [key] came back after a frame
  /// that did not build it (E17): jumps toward it by [_estimateTowards]
  /// until a frame builds it, then focuses the item's first node, with
  /// [placesFocus], and reveals it. A node other than [settled] that takes
  /// focus, and is not a scope, ends the reach and keeps that focus. A slot
  /// that holds another key, or a slot not built after [frames] jumps,
  /// gives the reach up through [_giveUpReach]; [origin] is the list's
  /// offset before the reach's first jump. [levels] limits the viewports
  /// that reveal the item.
  void _reach(
    Object token,
    _FrameIndex index,
    Key key,
    FocusNode? settled,
    int frames,
    ({ScrollPosition position, double pixels})? origin, {
    Set<ScrollableState>? levels,
    required bool placesFocus,
  }) {
    if (!mounted || _reachToken != token) return;
    _reachUncommittedJump = null;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary != settled && primary is! FocusScopeNode) {
      _endReach();
      return;
    }
    final node = _nodeAt(index);
    // A parked item is registered but not laid out (invariant 35).
    if (node != null && node.context != null && _builtSlot(index.slot)) {
      if (_lookAt(index)?.key != key) {
        _giveUpReach(origin, placesFocus: placesFocus);
        return;
      }
      _endReach();
      // A parked item kept its State and the node that holds focus; an
      // item whose node held no focus at the action never takes it (R46).
      if (placesFocus && !node.hasFocus) {
        firstTabStopIn(node)?.requestFocus();
      }
      _revealReturned(node, key, origin: origin, levels: levels);
      return;
    }
    final estimate = frames == 0 ? null : _estimateTowards(index.slot);
    if (estimate == null) {
      _giveUpReach(origin, placesFocus: placesFocus);
      return;
    }
    final position = estimate.position;
    final start = origin ?? (position: position, pixels: position.pixels);
    // The estimate re-derives the position each frame, so this jump and the
    // origin record below stay positions the Scrollable held when read; a
    // later swap is sorted out where the record returns.
    _reachUncommittedJump = (position: position, pixels: position.pixels);
    position.jumpTo(estimate.offset);
    WidgetsBinding.instance
      ..addPostFrameCallback(
        (_) => _reach(
          token,
          index,
          key,
          settled,
          frames - 1,
          start,
          levels: levels,
          placesFocus: placesFocus,
        ),
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
  /// a call. Without [placesFocus] the list returns to [origin] and hands
  /// no focus on: the item's node held no focus at the action (R46).
  void _giveUpReach(
    ({ScrollPosition position, double pixels})? origin, {
    bool placesFocus = true,
  }) {
    final gap = _reachGap;
    _endReach();
    if (gap == null) return;
    if (origin != null) {
      final live = _livePositionOf(origin.position);
      if (live != null && live.pixels != origin.pixels) {
        final pixels = origin.pixels.clamp(
          live.minScrollExtent,
          live.maxScrollExtent,
        );
        if (!placesFocus) {
          live.jumpTo(pixels);
          return;
        }
        // Held before the jump: its scroll notifications may reach an app
        // listener that calls the controller at once.
        final held = _HeldGap(gap);
        _givenUpGaps.add(held);
        live.jumpTo(pixels);
        WidgetsBinding.instance
          ..addPostFrameCallback((_) {
            _givenUpGaps.remove(held);
            _handOffFocus(held.index);
          })
          ..scheduleFrame();
        return;
      }
    }
    if (placesFocus) _handOffFocus(gap);
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
  ///
  /// This is a probe, never a landing: it always moves to the edge, so
  /// each retry forces a new layout pass that measures an unbuilt item's
  /// real extent; [revealInViewports]'s own `origin` clamp does the least
  /// scroll once a slot is actually built (D29, G5).
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

  /// The position of this list's own [Scrollable], from the sliver's own
  /// context ([_listKey]), live with no item built (invariant 35), never
  /// an item's: an item's context is gone exactly when this is needed.
  ScrollPosition? get _scrollPosition {
    final context = _listKey.currentContext;
    return context == null ? null : Scrollable.maybeOf(context)?.position;
  }

  /// [_scrollPosition] as an origin record, read now; null with no
  /// position (invariant 35).
  ({ScrollPosition position, double pixels})? get _currentOrigin {
    final position = _scrollPosition;
    return position == null
        ? null
        : (position: position, pixels: position.pixels);
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
    _frameJumps.add(_FrameJump(node, target, toStart: toStart, owned: owned));
  }

  /// At the next frame's start, after the turn's focus settled and before
  /// the build and the layout: runs the booked jumps in booking order, each
  /// toward its target where the calls since its move left it, and records
  /// the offset before it on the target, where a reach that gives up
  /// returns. A jump is skipped when its target was taken out, or when a
  /// node outside the moved item took primary focus since the call
  /// ([_MoveTarget.focusAtCall]): the app's focus wins. An item that never
  /// held focus still jumps under a screen reader's action (invariant 35).
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
      final appFocused = primary != null && primary != jump.target.focusAtCall;
      if (appFocused && !jump.node.hasFocus) continue;
      final item = jump.node.context;
      final position = item == null ? null : Scrollable.maybeOf(item)?.position;
      if (item == null || position == null) continue;
      // The jump moves the screen by design, and its estimate reads each
      // slot at the offset its number held: so does the next layout.
      _slotsBefore = 0;
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
  /// as the data indices their slot frames hold, their average extent
  /// along the main axis, and the room that layout left past its last
  /// child: the viewport plus cache extent its constraints reached past
  /// that child's end, where it would have laid out more; null when it laid
  /// out none. The sliver's child list holds only laid-out children:
  /// Flutter moves a kept-alive child out of it into its keep-alive bucket
  /// (`_destroyOrCacheChild`), so an item kept alive off screen never
  /// counts (invariant 35).
  ({int first, int last, double extent, double room})? _laidOut() {
    final sliver = _sliver();
    if (sliver == null) return null;
    // Data items only: a leaving item or closing gap has no data index
    // (R47), and its slot frame says so.
    RenderBox? firstChild;
    RenderBox? lastChild;
    int? first;
    int? last;
    for (
      var child = sliver.firstChild;
      child != null;
      child = sliver.childAfter(child)
    ) {
      if (child is! _RenderSlotSemantics) continue;
      final index = child.index;
      if (index == null) continue;
      if (first == null) {
        first = index;
        firstChild = child;
      }
      last = index;
      lastChild = child;
    }
    if (first == null ||
        last == null ||
        firstChild == null ||
        lastChild == null) {
      return null;
    }
    final constraints = sliver.constraints;
    double endOf(RenderBox child) =>
        (sliver.childScrollOffset(child) ?? 0) +
        (constraints.axis == Axis.vertical
            ? child.size.height
            : child.size.width);
    final start = sliver.childScrollOffset(firstChild) ?? 0;
    final end = endOf(lastChild);
    // A leaving item or closing gap after the last data item takes room too.
    final tail = sliver.lastChild;
    final childrenEnd = tail != null && tail.hasSize ? endOf(tail) : end;
    return (
      first: first,
      last: last,
      extent: (end - start) / (last - first + 1),
      room:
          constraints.scrollOffset +
          constraints.cacheOrigin +
          constraints.remainingCacheExtent -
          childrenEnd,
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
  /// frame, for a move either way (invariant 35), numbered as the last
  /// frame's slots. The next frame anchors its layout where the last frame
  /// laid out its first slot, at the slot that item takes past the slots
  /// this turn added before it ([_slotsBefore]), so the count starts there:
  /// that slot plus the boxes the next frame draws at full extent from it
  /// through [to]. Those are the items before [to], save an insert of this
  /// turn that grows in from 0 px, and each exit started since the last
  /// build, the slot a move left or the leaving copy of a built item,
  /// unless exits take no room. A box before that first slot counts
  /// nothing, and a target before it enters a slot the last frame did not
  /// build. Slots only, as [_builtSlot] reads them.
  int _enteredSlot(_DataIndex to) {
    final shift = _slotsBefore;
    final slot = to.nextSlot - shift;
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
        final at = insert.index.nextSlot - shift;
        return at < slot && counts(at);
      }).length;
    }
    if (!_exitsTakeNoExtent(context)) {
      entered += _exits
          .where(
            (exit) =>
                exit.fresh && !exit.ended && counts(exit.gap.nextSlot - shift),
          )
          .length;
    }
    return entered;
  }

  /// After the frame that moved the focused item [key] (FR-05 E04): laid
  /// out, it keeps focus and is revealed twice; parked off screen after a
  /// missed estimate, or with its State gone, the list reaches the item's
  /// slot, read by key from the settling build ([_followAt]), for another
  /// call in the move's own turn may have shifted the data under the move's
  /// own indices. An item that kept its State with no settled slot, since a
  /// count change reset the frame (E12) while the app's
  /// `findChildIndexCallback` moved it by its key (R25), is reached at the
  /// slot it registered at, where that build put it. With no settled slot
  /// and its State gone, a later call took the item or a count change reset
  /// the frame, the follow runs the give-up path: it returns to [origin],
  /// the offset before the move's jump at the next frame's start, else the
  /// one before the reach's own first jump, and hands focus on from the gap
  /// the frame left, the slot the item left (R5). The follow fields belong
  /// to the newest move: a follow whose key they no longer name waits for
  /// that move's own callback and does nothing here.
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
    final registered = _registeredIndexOf(node);
    if (node.context != null && registered != null) {
      final slot = at ?? registered;
      // Parked off screen: registered, but not laid out (invariant 35).
      if (!_builtSlot(slot.slot)) {
        if (node.hasFocus && gap != null) {
          _startReach(slot, key, gap, origin: origin);
        } else {
          _releasePark(key);
        }
        return;
      }
      _releasePark(key);
      if (node.hasFocus) _revealReturned(node, key, origin: origin);
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
    // The laid-out read of this build already asked for this index.
    final item =
        _readLooks.remove(index) ?? _layout.itemBuilder(context, index);
    final key = item.key;
    assert(key != null, 'Every item of ReorderableListViewLayout needs a key');
    _builtKey = key;
    assert(
      !_exits.any(
        (exit) => exit.keepsState && !exit.ended && exit.subKey == key,
      ),
      'ReorderableListViewLayout builds item $key while its removed copy '
      'still leaves: a leaving key returns to the data only through '
      'insertItem on its itemsController',
    );
    // The sliver child's key is the item's own, never the index, and the
    // sliver moves the child's element to the item's slot by it
    // ([_findIndex]), so a moved item keeps its State and focus with no
    // global key (R47). Every item builds inside one chain, at rest a
    // completed one, and leaves in the same shape ([_buildExit]): a grow-in,
    // a change of reduced motion, or a remove alters only the values the
    // chain reads, never its shape, so none moves the item's subtree to
    // another parent (R47, R48, D4).
    return _itemChain(
      context,
      look: item,
      index: index,
      exiting: false,
      animation: _incoming[key]?.curved ?? kAlwaysCompleteAnimation,
    );
  }

  /// One shape for an item in the data and the same item leaving: a leaving
  /// item takes no pointer, drag, focus, reorder key, or screen-reader node
  /// (E05), nor does a caller transition around it.
  Widget _itemChain(
    BuildContext context, {
    required Widget look,
    required int index,
    required bool exiting,
    required Animation<double> animation,
  }) {
    return IgnorePointer(
      ignoring: exiting,
      child: ExcludeFocus(
        excluding: exiting,
        child: ExcludeSemantics(
          excluding: exiting,
          child: _transition(
            context,
            animation,
            _wrapItem(look, index: index, exiting: exiting),
          ),
        ),
      ),
    );
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

  /// A removed item as it leaves, in its own sliver child: its kept look,
  /// or the look its `removeItem` builder makes, inside the remove
  /// transition, in the shape it had in the data ([_itemChain]). While the
  /// exit keeps the item's State, that child is keyed by the item's own key
  /// ([_Exit.frameKey]), so the item's element leaves in place. An ended
  /// exit is an empty slot.
  Widget _buildExit(BuildContext context, _Exit exit) {
    if (exit.ended) return const SizedBox.shrink();
    // The slot a moved item left: no look, no State, and no caller
    // transition; it shrinks by what the moved item grows (FR-05 E03).
    if (exit.closing) {
      final size = exit.size!;
      return SizeTransition(
        axis: _layout.scrollDirection,
        sizeFactor: ReverseAnimation(exit.motion.curved),
        child: _layout.scrollDirection == Axis.vertical
            ? SizedBox(height: size.height)
            : SizedBox(width: size.width),
      );
    }
    return _itemChain(
      context,
      look: exit.builder?.call(context) ?? exit.look,
      index: -1,
      exiting: true,
      animation: exit.motion.curved,
    );
  }

  /// The transition of every item: at rest, inserted or moved in, or
  /// removed.
  ///
  /// Built in, the item grows or shrinks along the main axis and fades as
  /// [animation] runs; under reduced motion or a fixed extent the size
  /// jumps and the fade keeps its full duration (E01, E11). A caller
  /// `itemTransitionBuilder` replaces all of it and gets [animation]
  /// unchanged, `kAlwaysCompleteAnimation` for an item at rest (E02).
  ///
  /// The built-in fade keeps the item in semantics at any opacity (FR-05);
  /// a caller transition keeps its own semantics choice.
  Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    final builder = _layout.itemTransitionBuilder;
    if (builder != null) return builder(context, animation, child);
    // One shape under every flag: reduced motion or a fixed extent only
    // holds the size whole, so it jumps while the fade keeps its duration.
    final jumps = _fixedExtent || context.reducesMotion;
    return _ItemSize(
      axis: _layout.scrollDirection,
      factor: jumps ? kAlwaysCompleteAnimation : animation,
      child: _ItemFade(
        opacity: animation,
        alwaysIncludeSemantics: true,
        child: _stretched(child),
      ),
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

  /// [child] at the full cross-axis extent: a transition loosens the
  /// constraints the list sets on an item.
  Widget _stretched(Widget child) => _layout.scrollDirection == Axis.vertical
      ? SizedBox(width: double.infinity, child: child)
      : SizedBox(height: double.infinity, child: child);

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    _motion =
        StratumThemeApplication.maybeOf(context)?.animation ??
        StratumAnimation.packageDefault;
    _resolvePending(context);
    // Every leaving item and closing gap takes a sliver child of its own
    // (R47); the count the sliver reports stays the data's. With no item
    // left, a leaving item keeps its room, since it has no item to fade
    // over (E01); a fixed extent ends it at once (E11).
    _plan = _FramePlan.of(
      _exits,
      dataCount: layout.itemCount,
      noRoom: layout.itemCount > 0 && _exitsTakeNoExtent(context),
    );
    final listCount = layout.itemCount;
    // A count change, or the lifted item away from its start at the same
    // count (FR-01 E07), ends the drag in this build, before the sliver
    // builds the item's key elsewhere; the end reaches _endDrag through
    // _ReorderSliverState.cancelReorder (E06).
    if (listCount != _listCount || _draggedLeftStart()) {
      _listKey.currentState?.cancelReorder();
      _dragged = null;
    }
    _listCount = listCount;
    // The widgets `ReorderableList`'s own tree, built here so the list
    // builds its own sliver subclass (invariant 28) and the key reaches it
    // (invariant 35); `scrollCacheExtent` reaches the viewport unchanged.
    return Focus(
      focusNode: _holdNode,
      includeSemantics: false,
      child: ScrollContentBringBack(
        bringBack: _bringBackNode,
        // The scroll view stays the first child, so the live-region leaf's
        // arrival never remounts it.
        child: StackLayout(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            _scrollView(layout, listCount),
            if (_liveText case final text?)
              // One px: an empty node drops out of the semantics tree, and a
              // larger one can take touch exploration over the items.
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: Semantics(
                  key: ValueKey(_liveCount),
                  container: true,
                  liveRegion: true,
                  label: text,
                  child: const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The shared policy's bring-back for a node inside this list: D24's
  /// [_bringBack] for an item it keeps alive off screen, else one jump.
  /// A node of a scroll view inside the item, which that view may keep
  /// alive off screen too, is then revealed in its own viewport while it
  /// still reads NaN; when this list lays the item out, only that view
  /// keeps the node, so the item takes no bring-back of its own, which
  /// would jump an item taller than the list to its leading edge. Either
  /// way [then] runs after the next frame, whose layout holds the last
  /// jump, so the move reveals its target from the new offset.
  void _bringBackNode(FocusNode node, VoidCallback then) {
    void afterFrame() {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => then())
        ..scheduleFrame();
    }

    final context = node.context;
    final keys = context?.findAncestorStateOfType<_ReorderKeysState>();
    if (context == null || keys == null || keys.widget.body != this) {
      _revealOwn(node);
      afterFrame();
      return;
    }
    if (Scrollable.maybeOf(context) == Scrollable.maybeOf(keys.context)) {
      _bringBack(keys, afterFrame);
      return;
    }
    if (keys._node.rect.isFinite) {
      _revealOwn(node);
      afterFrame();
      return;
    }
    _bringBack(keys, () {
      if (!node.rect.isFinite) _revealOwn(node);
      afterFrame();
    });
  }

  /// Ends a running reach when the EndUser's own scroll starts: a
  /// [ScrollStartNotification] or [ScrollUpdateNotification] with drag
  /// details, or a [UserScrollNotification] off idle, from this list's
  /// own Scrollable (depth 0). The list's own jumps fire the start
  /// notification with no drag details, so they leave the reach running
  /// (FR-04 E20): the EndUser's newest input wins, the reach ends on its
  /// stale token, nothing scrolls back, and the item stays parked off
  /// screen with its State and focus (R29).
  bool _endsReachOn(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    switch (notification) {
      case ScrollStartNotification() ||
          ScrollUpdateNotification() ||
          UserScrollNotification():
        if (_revealDepth == 0) _scrollGeneration += 1;
      default:
        return false;
    }
    final userDriven = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails != null,
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      UserScrollNotification(:final direction) =>
        direction != ScrollDirection.idle,
      _ => false,
    };
    if (userDriven) _stopReach();
    return false;
  }

  Widget _scrollView(ReorderableListViewLayout layout, int listCount) {
    return NotificationListener<ScrollNotification>(
      onNotification: _endsReachOn,
      child: _ReorderScrollView(
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
        // A leaving item or closing gap has no semantic index, so the count
        // and every semantic index stay indices of the app's data
        // (invariant 58).
        semanticChildCount: layout.itemCount,
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
      ),
    );
  }
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

  /// Whether the item's node held focus when the item last left the tree:
  /// a disposal that follows hands focus on (R26).
  var _leftFocused = false;

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

  // The item came back into the tree in the same frame, moved with the
  // whole list by a global key above it.
  @override
  void activate() {
    super.activate();
    _leftFocused = false;
  }

  @override
  void deactivate() {
    // Read before the item's own nodes leave the tree, which they do only
    // at its disposal.
    _leftFocused = !widget.exiting && _node.hasFocus;
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

/// The built-in size of an item along [axis]: the item's own extent times
/// [factor], aligned as `SizeTransition` aligns it and clipped to that box
/// while [factor] is below 1.
///
/// At 1 it passes the slot's constraints through and clips nothing, so an
/// item fills a fixed-extent slot and a focus ring or a shadow it paints
/// outside its box shows (NFR-U02). A new factor changes a value, never the
/// widget shape, so no flag moves the item's subtree to another parent
/// (D4).
class _ItemSize extends SingleChildRenderObjectWidget {
  const new({required this.axis, required this.factor, super.child});

  /// The list's main axis, the one the item grows and shrinks along.
  final Axis axis;

  /// The share of the item's extent the slot shows.
  final Animation<double> factor;

  @override
  _RenderItemSize createRenderObject(BuildContext context) => _RenderItemSize(
    axis: axis,
    factor: factor,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, _RenderItemSize renderObject) {
    renderObject
      ..axis = axis
      ..factor = factor
      ..textDirection = Directionality.maybeOf(context);
  }
}

class _RenderItemSize extends RenderShiftedBox {
  new({
    required Axis axis,
    required Animation<double> factor,
    TextDirection? textDirection,
  }) : _axis = axis,
       _factor = factor,
       _textDirection = textDirection,
       super(null);

  final _clip = LayerHandle<ClipRectLayer>();

  Axis get axis => _axis;
  Axis _axis;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  Animation<double> get factor => _factor;
  Animation<double> _factor;
  set factor(Animation<double> value) {
    if (identical(value, _factor)) return;
    if (attached) {
      _factor.removeListener(markNeedsLayout);
      value.addListener(markNeedsLayout);
    }
    _factor = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// The share of the item's extent shown, never below 0.
  double get _shown => math.max(_factor.value, 0);

  /// Whether the item shows whole: it takes the slot's constraints as they
  /// are and nothing clips it.
  bool get _whole => _shown >= 1;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _factor.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _factor.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _along(Axis.horizontal, super.computeMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _along(Axis.horizontal, super.computeMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _along(Axis.vertical, super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _along(Axis.vertical, super.computeMaxIntrinsicHeight(width));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    if (_whole) return child.getDryLayout(constraints);
    return _sizeAround(child.getDryLayout(constraints.loosen()), constraints);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final parentData = child.parentData! as BoxParentData;
    if (_whole) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
      parentData.offset = Offset.zero;
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    size = _sizeAround(child.size, constraints);
    final alignment = switch (_axis) {
      Axis.vertical => AlignmentDirectional.centerStart,
      Axis.horizontal => AlignmentDirectional.topCenter,
    };
    parentData.offset = alignment
        .resolve(_textDirection)
        .alongOffset(size - child.size as Offset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _whole) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clip.layer,
    );
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _whole ? null : Offset.zero & size;

  /// [extent] of the child along [axis], scaled by the shown share when
  /// [axis] is the one the item grows along.
  double _along(Axis axis, double extent) =>
      axis == _axis && !_whole ? extent * _shown : extent;

  /// The box `Align` gives a child of [childSize]: the shown share of its
  /// extent along [axis], and the full cross extent [constraints] allow.
  Size _sizeAround(Size childSize, BoxConstraints constraints) {
    final vertical = _axis == Axis.vertical;
    return constraints.constrain(
      Size(
        vertical
            ? (constraints.hasBoundedWidth ? double.infinity : childSize.width)
            : childSize.width * _shown,
        vertical
            ? childSize.height * _shown
            : (constraints.hasBoundedHeight
                  ? double.infinity
                  : childSize.height),
      ),
    );
  }
}

/// The built-in fade of an item, which takes a layer of its own only while
/// it shows the item part-way: an item at rest paints into its one boundary
/// (D15).
class _ItemFade extends FadeTransition {
  const new({
    required super.opacity,
    super.alwaysIncludeSemantics,
    super.child,
  });

  @override
  RenderAnimatedOpacity createRenderObject(BuildContext context) =>
      _RenderItemFade(
        opacity: opacity,
        alwaysIncludeSemantics: alwaysIncludeSemantics,
      );
}

/// The SDK's [RenderAnimatedOpacity], a repaint boundary only while its
/// alpha lies between 0 and 255; the SDK's is one at any alpha above 0.
class _RenderItemFade extends RenderAnimatedOpacity {
  new({required super.opacity, required super.alwaysIncludeSemantics});

  /// Whether the fade shows the item part-way, the only time it composites.
  var _fading = false;

  @override
  bool get isRepaintBoundary => child != null && _fading;

  @override
  set opacity(Animation<double> value) {
    if (!attached) {
      super.opacity = value;
      _updateFading();
      return;
    }
    if (value == opacity) return;
    opacity.removeListener(_updateFading);
    super.opacity = value;
    value.addListener(_updateFading);
    _updateFading();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    opacity.addListener(_updateFading);
    _updateFading();
  }

  @override
  void detach() {
    opacity.removeListener(_updateFading);
    super.detach();
  }

  void _updateFading() {
    final alpha = Color.getAlphaFromOpacity(opacity.value);
    final fading = alpha > 0 && alpha < 255;
    if (fading == _fading) return;
    _fading = fading;
    // The SDK marks the compositing bits only when the alpha crosses 0.
    if (child != null) markNeedsCompositingBitsUpdate();
  }
}

/// The key of the frame around an SDK item, equal by the item's own key,
/// never its index: the sliver moves a mapped item's element in place.
class _IndexFreeKey extends ValueKey<Key> {
  const new(super.value);
}

/// The key of a slot the list owns: a closing gap, a leaving copy that gave
/// its State up, or an ended exit. Only the frame plan answers for it, so
/// the app's `findChildIndexCallback` never gets it ([_ReorderableBodyState
/// ._findIndex]).
class _ExitKey extends ValueKey<_Exit> {
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
    required this.gap,
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
  /// at [gap]. Each call moves it; the plan lays the exit out from it
  /// ([_FramePlan]).
  _DataIndex gap;

  /// Whether the exit keeps the item's own sliver child and State; false
  /// once the same key is back in the data under a `builder` look.
  bool keepsState = true;

  /// The key of the exit's sliver child: the item's own key while it keeps
  /// the item's State, so the item's element leaves in place (R47), else
  /// this exit's own, which only the list reads.
  Key get frameKey => keepsState && !ended ? subKey : _ExitKey(this);

  /// Whether the exit's animation ended: an empty slot of no extent that
  /// waits until dropping it moves no item on screen (R47).
  bool ended = false;

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
/// of `_pending`), in [nextSlot], and at `onReorderItem`, `itemBuilder`,
/// and the move announcement.
extension type const _DataIndex(int value) {
  /// The slot the item at this index takes in the next frame: the sliver
  /// keeps each slot's offset by its number across a rebuild, shifted by
  /// the slots a `moveItem` adds or drops before the first laid-out slot
  /// ([_SlotListElement]).
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

/// A key a build follows by key, with its key node, the index of the
/// current data the calls of the turn put it at, and, for the item that
/// holds focus, the frame index the last build drew it at and whether its
/// box showed in the list's viewport in the last frame (invariant 35). The
/// parked and lifted entries carry no frame and read as not shown: every
/// reader of `shown` asks only an entry with a frame, so they skip the
/// geometry read.
typedef _Watched = ({
  Key key,
  _DataIndex at,
  FocusNode node,
  _FrameIndex? frame,
  bool shown,
});

/// An elapsed time past the end of every SDK reorder controller (250 ms):
/// under reduced motion each one ends on its first tick.
const _endAtOnce = Duration(hours: 1);

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
  new(
    this.index, {
    this.key,
    this.gap,
    this.revealIn,
    this.screenReader = false,
  }) : focusAtCall = FocusManager.instance.primaryFocus;

  _DataIndex? index;

  /// For a move of an item that holds focus, or of any item a screen reader
  /// moves (R46): the item's key, which the reach looks for.
  final Key? key;

  /// For a move of an item that holds focus, or of any item a screen reader
  /// moves (R46): the gap the item left, before the item at this index of
  /// the current data, moved by each later call as [index] is; the reach
  /// hands focus on from it when it gives up.
  _DataIndex? gap;

  /// The offset before the move's jump, where a reach that gives up
  /// returns (R5). Set by the jump at the next frame's start.
  ({ScrollPosition position, double pixels})? origin;

  /// For a call's shift of a focused item that showed (D28): the viewports
  /// that showed it in the last frame, the only ones its reveal scrolls; a
  /// viewport around the list that did not show it is the app's. Null
  /// reveals in every viewport.
  final Set<ScrollableState>? revealIn;

  /// Whether a screen reader's move action booked this target for an item
  /// whose key node did not hold focus at the action: the item counts as
  /// the focused moved item while primary focus has not moved from the node
  /// that held it at the action ([focusAtCall], R46), and the list never
  /// places or hands on input focus for it (R13).
  final bool screenReader;

  /// The node that held primary focus at the move's call.
  final FocusNode? focusAtCall;

  /// Whether the moved item counts as focused now: its key node [node]
  /// holds focus, or a screen reader moved it and primary focus stayed on
  /// [focusAtCall] (R46); a focus the app moves in the turn wins (R13).
  bool countsFocused(FocusNode node) =>
      node.hasFocus ||
      (screenReader && FocusManager.instance.primaryFocus == focusAtCall);
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
    super.semanticChildCount,
  });
}

/// A reveal jump a move booked for the next frame's start (invariant 35).
class _FrameJump {
  new(this.node, this.target, {required this.toStart, required this.owned});

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
}

/// A gap of the app's data, before the item at [index], that a reader
/// takes after a frame; moved by each later call until then.
class _HeldGap {
  new(this.index);

  _DataIndex index;
}
