// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file of the Flutter SDK
// (https://github.com/flutter/flutter/blob/master/LICENSE).
//
// Adapted from packages/flutter/lib/src/widgets/reorderable_list.dart of
// Flutter 3.47.7, lines 759-1229, 1231-1392, and 1496-1729: the reorder
// layer of SliverReorderableList, addressed by item key instead of index
// (R44), with a raster of the lifted item as its drag proxy (R49), and with
// each leaving item or closing gap in a sliver child of its own (R47).
part of '../reorderable_list_view_layout.dart';

/// The list's reorder sliver. It stays a [SliverReorderableList], so that
/// `SliverReorderableList.maybeOf` finds its State from an app's
/// `ReorderableDragStartListener` handle and from the long-press listener,
/// but its State is stratum's own reorder layer.
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

/// Stratum's reorder layer, under the SDK State type only for lookups:
/// it overrides every entry point and keeps none of the SDK's own drag
/// state. Items register by key ([_items]); the drag holds the lifted
/// item's key ([_dragKey]); every slot is still an index, since a gap is a
/// place in the list, not an item.
class _ReorderSliverState extends SliverReorderableListState {
  _ReorderableBodyState get _body => (widget as _ReorderSliver).body;

  /// The registered items, by item key.
  final _items = <Key, _ReorderItemState>{};

  OverlayEntry? _overlayEntry;

  /// The key of the item the drag holds, from the pointer down that arms
  /// it until the drag resets.
  Key? _dragKey;

  /// The index the drag started at, as `onReorderStart` reported it.
  int? _dragIndex;
  _Lift? _lift;
  int? _insertIndex;
  Offset? _finalDropPosition;

  /// The recognizers armed for [_recognizerPointer]: an item's handle
  /// listener and its long-press listener each arm one for the same
  /// pointer down, and the drag runs through whichever wins, so a reset
  /// disposes them all ([_disposeRecognizers]).
  final _recognizers = <MultiDragGestureRecognizer>[];
  int? _recognizerPointer;
  EdgeDraggingAutoScroller? _autoScroller;
  late ScrollableState _scrollable;

  /// Where the scroll sat when the last edge auto-scroll step was asked
  /// for, and whether the app's hold sprang that step back: once it did,
  /// the edge scroll stops stepping until the lifted item leaves the edge
  /// and comes back (FR-01 E11).
  double? _autoScrollStepFrom;
  bool _autoScrollGaveWay = false;

  /// Whether the app or the platform asked for less motion at the last
  /// build; a ticker callback runs outside the build, so it reads this.
  var _reducesMotion = false;

  /// The extents the list lays its slots out by under a fixed extent. The
  /// sliver compares builders by identity, so a new one, made whenever the
  /// app's `itemExtent` or `itemExtentBuilder` changes, lays it out again.
  late ItemExtentBuilder _extents = _newExtents();

  /// [_slotExtent] for the app's current `itemExtent` and
  /// `itemExtentBuilder`, which it holds.
  ItemExtentBuilder _newExtents() {
    final itemExtent = widget.itemExtent;
    final itemExtentBuilder = widget.itemExtentBuilder;
    return (slot, dimensions) => _slotExtent(
      slot,
      dimensions,
      itemExtent: itemExtent,
      itemExtentBuilder: itemExtentBuilder,
    );
  }

  Axis get _scrollDirection => axisDirectionToAxis(_scrollable.axisDirection);
  bool get _reverse => axisDirectionIsReversed(_scrollable.axisDirection);

  /// The theme's `normal` level duration: the drag's reflow and the drop's
  /// settle run over it, the motion of every other move of the list (D7).
  Duration get _settleDuration =>
      _body._motion.normal.duration ?? Duration.zero;

  /// The theme's `standard` curve token, the one that level runs on.
  Curve get _standardCurve =>
      _body._motion.normal.curve ?? Curves.easeInOutSine;

  // Every reorder controller ticks on this State: each item's reflow and
  // the drop's settle. Under reduced motion each reads a long elapsed time
  // and ends on its first tick (R38, invariant 59).
  @override
  Ticker createTicker(TickerCallback onTick) {
    return super.createTicker(
      (elapsed) => onTick(_reducesMotion ? _endAtOnce : elapsed),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollable = Scrollable.of(context);
    if (_autoScroller?.scrollable != _scrollable) {
      _autoScroller?.stopAutoScroll();
      _autoScroller = EdgeDraggingAutoScroller(
        _scrollable,
        onScrollViewScrolled: _handleScrollableAutoScrolled,
        velocityScalar: widget.autoScrollerVelocityScalar,
      );
    }
  }

  @override
  void didUpdateWidget(covariant SliverReorderableList oldWidget) {
    // The SDK's own State cancels on a count change through cancelReorder,
    // which this State overrides.
    super.didUpdateWidget(oldWidget);
    if (widget.itemExtent != oldWidget.itemExtent ||
        widget.itemExtentBuilder != oldWidget.itemExtentBuilder) {
      _extents = _newExtents();
    }
    if (widget.autoScrollerVelocityScalar !=
        oldWidget.autoScrollerVelocityScalar) {
      _autoScroller?.stopAutoScroll();
      _autoScroller = EdgeDraggingAutoScroller(
        _scrollable,
        onScrollViewScrolled: _handleScrollableAutoScrolled,
        velocityScalar: widget.autoScrollerVelocityScalar,
      );
    }
  }

  @override
  void dispose() {
    _dragReset();
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void startItemDragReorder({
    required int index,
    required PointerDownEvent event,
    required MultiDragGestureRecognizer recognizer,
  }) {
    assert(
      0 <= index && index < widget.itemCount,
      'startItemDragReorder($index) is out of range',
    );
    // A long press inside the item's own focused text field is the
    // field's, never a drag start; a handle's own listener still starts
    // one (D10 I01xT15, FR-01 E12). Only the item-wide long-press
    // listener offers this recognizer type.
    if (recognizer is DelayedMultiDragGestureRecognizer &&
        _pointerInFocusedField(index, event.position)) {
      return;
    }
    // Neither the recognizer bookkeeping below nor _dragKey (read only
    // once _lift exists, never by a build before then) shows on screen,
    // so it takes no setState of its own. The two branches that do change
    // what is on screen carry their own setState (cancelReorder,
    // _completeDropForStart's _dropCompleted).
    if (isSettlingDrop) {
      // A drag that starts while a drop settles completes it at once
      // (R52), so the drop's move reports and the new drag lifts.
      _completeDropForStart();
    } else if (_lift != null) {
      cancelReorder();
    } else if (_recognizerPointer != event.pointer) {
      _disposeRecognizers();
    }
    final item = _itemAt(index);
    if (item == null) {
      throw Exception('Attempting to start a drag on a non-visible item');
    }
    _dragKey = item.key;
    _recognizers.add(
      recognizer
        ..onStart = _dragStart
        ..addPointer(event),
    );
    _recognizerPointer = event.pointer;
  }

  /// Disposes every recognizer armed for [_recognizerPointer], which drops
  /// each one's route for it: a release or cancel of that pointer after
  /// the drag ended another way reaches no lift a reset disposed.
  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _recognizerPointer = null;
  }

  // Every reset reaches the body's one drag exit (FR-04 E06): the SDK's
  // own count-change cancel, a second pointer, and the body's own cancel.
  @override
  void cancelReorder() {
    setState(_dragReset);
    _body._handleListReset();
  }

  /// The registered item now at [index]; null when none is built there.
  _ReorderItemState? _itemAt(int index) {
    for (final item in _items.values) {
      if (item.index == index && item.mounted) return item;
    }
    return null;
  }

  /// Whether [position] lies inside the focused [EditableText] of the
  /// item at [index]: its own long press runs there, never a drag's
  /// (D10 I01xT15).
  bool _pointerInFocusedField(int index, Offset position) {
    if (!primaryFocusInEditableText()) return false;
    final focusContext = FocusManager.instance.primaryFocus!.context!;
    final item = _itemAt(index);
    if (item == null) return false;
    var underItem = false;
    focusContext.visitAncestorElements((ancestor) {
      if (!identical(ancestor, item.context)) return true;
      underItem = true;
      return false;
    });
    if (!underItem) return false;
    final editable = _editableTextContext(focusContext);
    final box = editable?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(position));
  }

  /// [context] itself when it is an [EditableText], else its nearest
  /// [EditableText] ancestor; null when there is none.
  BuildContext? _editableTextContext(BuildContext context) {
    if (context.widget is EditableText) return context;
    BuildContext? found;
    context.visitAncestorElements((ancestor) {
      if (ancestor.widget is EditableText) {
        found = ancestor;
        return false;
      }
      return true;
    });
    return found;
  }

  void _registerItem(_ReorderItemState item) {
    // A leaving item takes no part in a drag.
    if (item.widget.exiting) {
      _unregisterItem(item.key, item);
      return;
    }
    final lift = _lift;
    if (lift != null && _items[item.key] != item) {
      item.updateForGap(
        lift.index,
        lift.index,
        lift.itemExtent,
        false,
        _reverse,
      );
    }
    _items[item.key] = item;
    if (lift != null && item.key == _dragKey && !item._dragging) {
      item
        ..dragging = true
        ..rebuild();
    }
  }

  void _unregisterItem(Key key, _ReorderItemState item) {
    if (_items[key] == item) _items.remove(key);
  }

  Drag? _dragStart(Offset position) {
    assert(_lift == null, 'A drag started while another one is live');
    final key = _dragKey;
    final item = key == null ? null : _items[key];
    if (item == null || !item.mounted) return null;
    _dragIndex = item.index;
    item.dragging = true;
    widget.onReorderStart?.call(item.index);
    // The lift is a move of the item (D12): the body ends what runs
    // beside it, and the item's own grow-in, before the drag proxy takes
    // its raster ([_Lift.new]). That raster reads the snapshot boundary
    // below the grow-in ([_SnapshotBoundary], D5), the item as the last
    // frame already painted it, so this needs no flush of its own: a
    // flush run inside the grab's own pointer callback laid out and
    // painted whatever the tree held pending at that instant, never the
    // frame the EndUser touched, and could retire this item from the
    // built range before its own lift read it (R45). The next frame lays
    // the grow-in's now-dirty size out as any other build does.
    _body._liftedTook(item.key);
    item.rebuild();
    _insertIndex = item.index;
    final lift = _lift = _Lift(
      item: item,
      initialPosition: position,
      scrollDirection: _scrollDirection,
      onUpdate: _dragUpdate,
      onCancel: _dragCancel,
      onEnd: _dragEnd,
      onDropCompleted: _dropCompleted,
      proxyDecorator: widget.proxyDecorator,
      tickerProvider: this,
    )..startDrag();

    final overlay = Overlay.of(context, debugRequiredFor: widget);
    assert(_overlayEntry == null, 'A drag proxy is already in the overlay');
    _overlayEntry = OverlayEntry(builder: lift.createProxy);
    overlay.insert(_overlayEntry!);

    for (final other in _items.values) {
      if (other == item || !other.mounted) continue;
      other.updateForGap(
        _insertIndex!,
        _insertIndex!,
        lift.itemExtent,
        false,
        _reverse,
      );
    }
    return lift;
  }

  void _dragUpdate(_Lift lift, Offset position, Offset delta) {
    setState(() {
      _overlayEntry?.markNeedsBuild();
      _dragUpdateItems();
      _startAutoScrollIfNecessary();
    });
  }

  /// Starts the edge auto-scroll when the lifted item sits past an edge,
  /// yielding to the app's hold: a step whose scroll the position did not
  /// hold (it sprang back) stops the auto-scroller, which stays stopped
  /// until the lifted item leaves the edge and comes back (FR-01 E11).
  void _startAutoScrollIfNecessary() {
    final lift = _lift;
    if (lift == null) return;
    if (_autoScrollGaveWay) {
      // Back inside the viewport: the drag earns the edge scroll again.
      final view = _scrollable.context.findRenderObject();
      if (view is! RenderBox || !view.hasSize) return;
      final origin = view.localToGlobal(Offset.zero);
      final target = _dragTargetRect;
      final vertical = _scrollDirection == Axis.vertical;
      final start = vertical ? target.top : target.left;
      final end = vertical ? target.bottom : target.right;
      final viewStart = vertical ? origin.dy : origin.dx;
      final viewEnd =
          viewStart + (vertical ? view.size.height : view.size.width);
      if (start < viewStart || end > viewEnd) return;
      _autoScrollGaveWay = false;
    }
    // A step already runs: _dragUpdate calls this on every pointer move,
    // several of which can land inside one step's own animateTo (FR-01
    // E11); only a new step's own start stamps where it began, so the
    // spring-back check below compares against that step's true start,
    // never a value this mid-step call would overwrite it with.
    if (!(_autoScroller?.scrolling ?? false)) {
      _autoScrollStepFrom = _scrollable.position.pixels;
    }
    _autoScroller?.startAutoScrollIfNecessary(_dragTargetRect);
  }

  void _dragCancel(_Lift lift) {
    setState(_dragReset);
    _body._handleListReset();
  }

  // The drop settles on the slot by the item built beside it. The insert
  // index is an index of the data, so the past-the-end check reads the
  // item count, never the count of registered items; an item not built
  // there leaves no target, and the raster settles where it was let go.
  void _dragEnd(_Lift lift) {
    setState(() {
      final insert = _insertIndex!;
      if (insert - lift.index == 1) {
        _finalDropPosition = _itemOffsetAt(insert - 1);
      } else if (insert == lift.index) {
        _finalDropPosition = _itemOffsetAt(insert);
      } else if (_reverse) {
        if (insert >= widget.itemCount) {
          _finalDropPosition = _shifted(
            _itemOffsetAt(widget.itemCount - 1),
            -lift.itemExtent,
          );
        } else {
          _finalDropPosition = _shifted(
            _itemOffsetAt(insert),
            _itemExtentAt(insert),
          );
        }
      } else {
        if (insert == 0) {
          _finalDropPosition = _shifted(_itemOffsetAt(0), -lift.itemExtent);
        } else {
          final atIndex = insert - 1;
          _finalDropPosition = _shifted(
            _itemOffsetAt(atIndex),
            _itemExtentAt(atIndex),
          );
        }
      }
    });
    widget.onReorderEnd?.call(_insertIndex!);
  }

  void _dropCompleted() {
    final oldIndex = _dragIndex!;
    final newIndex = _insertIndex!;
    _reportingDrop = true;
    try {
      _handleReorderItem(oldIndex, newIndex);
    } finally {
      _reportingDrop = false;
    }
    setState(_dragReset);
  }

  var _reportingDrop = false;

  /// Whether this call to [_handleReorderItem] reports the drag's own
  /// drop, never a screen-reader move action (R4, invariant 28): the
  /// body reads this, never the last build's look, which a drop whose
  /// lifted item the build left out still reads as a screen-reader move
  /// (FR-04 E20), and a screen-reader move on the lifted item's own slot
  /// still reads as a drop (the mirror case).
  bool get isReportingDrop => _reportingDrop;

  /// Whether a dropped item still settles: its drag ended and the proxy's
  /// settle runs, so the drag's reset has not (R52).
  bool get isSettlingDrop => _lift != null && _finalDropPosition != null;

  /// How many calls the body held when the drag start this State is arming
  /// completed its own settling drop, null when none did: that start skips
  /// the "between a move reported and its frame" cancel for the drop's own
  /// booking and nothing later added (R52, FR-04 E06).
  int? _completedDropForStart;

  /// Completes the settling drop at once (R52): the same path its settle's
  /// end runs — one `onReorderItem` with the drop's indices, the item in
  /// its new slot, no second `onReorderEnd`.
  void completeSettlingDrop() {
    if (!isSettlingDrop) return;
    _dropCompleted();
  }

  /// [completeSettlingDrop] for the drag this State is arming, marking the
  /// booking it leaves for that drag's own start (R52).
  void _completeDropForStart() {
    _completedDropForStart = _body._pending.length;
    _dropCompleted();
  }

  /// Whether the drag being started completes the settling drop its own
  /// start booked ([_completeDropForStart]), with no call added since, so
  /// its start skips the "between a move reported and its frame" cancel
  /// (FR-04 E06); takes the mark, so one start consumes it.
  bool completesOwnDrop() {
    final at = _completedDropForStart;
    if (at == null || at != _body._pending.length) {
      _completedDropForStart = null;
      return false;
    }
    _completedDropForStart = null;
    return true;
  }

  /// Ends the drag: the lifted item shows in its slot again, the proxy and
  /// its raster go, and the body hears that the item is let go.
  void _dragReset() {
    if (_lift == null) return;
    final key = _dragKey;
    final item = key == null ? null : _items[key];
    if (item != null && item.mounted) {
      item
        .._dragging = false
        ..rebuild();
    }
    _dragKey = null;
    _dragIndex = null;
    _lift?.dispose();
    _lift = null;
    _autoScroller?.stopAutoScroll();
    _autoScrollStepFrom = null;
    _autoScrollGaveWay = false;
    _resetItemGap();
    _disposeRecognizers();
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    _finalDropPosition = null;
    if (key != null) _body._liftedLetGo(key);
  }

  void _resetItemGap() {
    for (final item in _items.values) {
      item.resetGap();
    }
  }

  void _handleReorderItem(int oldIndex, int newIndex) {
    // Removing an item at the old index shortens the list by one.
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (oldIndex != to) widget.onReorderItem?.call(oldIndex, to);
  }

  void _handleScrollableAutoScrolled() {
    if (_lift == null) return;
    _dragUpdateItems();
    // The step the scroller just ran did not hold: the app's hold sprang
    // it back, so the edge scroll stops stepping (FR-01 E11).
    final from = _autoScrollStepFrom;
    final pixels = _scrollable.position.pixels;
    if (from != null && (pixels - from).abs() < 1.0) {
      _autoScroller?.stopAutoScroll();
      _autoScrollGaveWay = true;
      return;
    }
    _startAutoScrollIfNecessary();
  }

  void _dragUpdateItems() {
    final lift = _lift!;
    final gapExtent = lift.itemExtent;
    final proxyItemStart = _offsetExtent(
      lift.dragPosition - lift.dragOffset,
      _scrollDirection,
    );
    final proxyItemEnd = proxyItemStart + gapExtent;
    final dragIndex = lift.index;

    var newIndex = _insertIndex!;
    for (final item in _items.values) {
      if ((_reverse && item.key == _dragKey) || !item.mounted) continue;
      final geometry = item.targetGeometry();
      final itemStart = _scrollDirection == Axis.vertical
          ? geometry.top
          : geometry.left;
      final itemExtent = _scrollDirection == Axis.vertical
          ? geometry.height
          : geometry.width;
      final itemEnd = itemStart + itemExtent;
      final itemMiddle = itemStart + itemExtent / 2;

      if (_reverse) {
        if (itemEnd >= proxyItemEnd && proxyItemEnd >= itemMiddle) {
          newIndex = item.index;
          break;
        } else if (itemMiddle >= proxyItemStart &&
            proxyItemStart >= itemStart) {
          newIndex = item.index + 1;
          break;
        } else if (itemStart > proxyItemEnd && newIndex < (item.index + 1)) {
          newIndex = item.index + 1;
        } else if (proxyItemStart > itemEnd && newIndex > item.index) {
          newIndex = item.index;
        }
      } else {
        if (item.key == _dragKey) {
          if (itemMiddle <= proxyItemEnd && proxyItemEnd <= itemEnd) {
            newIndex = dragIndex;
          }
        } else if (itemStart <= proxyItemStart &&
            proxyItemStart <= itemMiddle) {
          newIndex = item.index;
          break;
        } else if (itemMiddle <= proxyItemEnd && proxyItemEnd <= itemEnd) {
          newIndex = item.index + 1;
          break;
        } else if (itemEnd < proxyItemStart && newIndex < (item.index + 1)) {
          newIndex = item.index + 1;
        } else if (proxyItemEnd < itemStart && newIndex > item.index) {
          newIndex = item.index;
        }
      }
    }

    if (newIndex != _insertIndex) {
      _insertIndex = newIndex;
      for (final item in _items.values) {
        if (item.key == _dragKey || !item.mounted) continue;
        item.updateForGap(dragIndex, newIndex, gapExtent, true, _reverse);
      }
    }
  }

  /// The lifted item's rect as the edge auto-scroll reads it, cut to the
  /// list's size on any axis the item is longer on, since the SDK's
  /// auto-scroller asserts its target fits (R49): an item that covers the
  /// list scrolls nothing, one whose edge shows scrolls as a shorter item.
  Rect get _dragTargetRect {
    final lift = _lift!;
    final item = (lift.dragPosition - lift.dragOffset) & lift.itemSize;
    final view = _scrollable.context.findRenderObject();
    if (view is! RenderBox || !view.hasSize) return item;
    final list = view.localToGlobal(Offset.zero) & view.size;
    final pointer = lift.dragPosition;
    final width = math.min(item.width, list.width);
    final height = math.min(item.height, list.height);
    return Rect.fromLTWH(
      _targetStart(item.left, item.right, pointer.dx, list.left, width),
      _targetStart(item.top, item.bottom, pointer.dy, list.top, height),
      width,
      height,
    );
  }

  /// The global top-left the item built at [index] moves to for the gap;
  /// null when no item is built there.
  Offset? _itemOffsetAt(int index) => _itemAt(index)?.targetGeometry().topLeft;

  /// [offset] moved [extent] along the scroll axis; null stays null.
  Offset? _shifted(Offset? offset, double extent) =>
      offset == null ? null : offset + _extentOffset(extent, _scrollDirection);

  double _itemExtentAt(int index) {
    final item = _itemAt(index);
    if (item == null) return 0;
    return _sizeExtent(item.targetGeometry().size, _scrollDirection);
  }

  /// The sliver child at [slot] of the body's frame plan: a data item, or
  /// a leaving item or closing gap, under the reorder item that moves it
  /// for the drag's gap and hides it while it is lifted, and under a frame
  /// keyed by the item's own key, so the sliver moves the item's element
  /// in place to its new slot (invariant 35). One widget shape serves every
  /// state, so an item's subtree never changes parent from its insert to
  /// the end of its exit (R47).
  Widget _itemBuilder(BuildContext context, int slot) {
    final body = _body;
    final plan = body._plan;
    final (:data, :exit) = plan.at(slot);
    final int index;
    final Widget child;
    final Key key;
    if (exit == null) {
      index = data!;
      body._builtKey = null;
      child = widget.itemBuilder(context, index);
      key = body._builtKey ?? child.key!;
    } else {
      index = -1;
      child = body._buildExit(context, exit.exit);
      key = exit.exit.frameKey;
    }
    // Under a fixed extent a leaving item keeps its own size, clipped to
    // the slot it fades over (E03, E11).
    final size = exit?.exit.size;
    final hangExtent = size != null && body._fixedExtent
        ? _sizeExtent(size, _scrollDirection)
        : null;
    final overlay = Overlay.of(context, debugRequiredFor: widget);
    return _ParkFrame(
      key: _IndexFreeKey(key),
      body: body,
      itemKey: key,
      child: _SlotSemantics(
        index: exit == null ? index : null,
        exit: exit?.exit,
        child: _Hang(
          axis: _scrollDirection,
          hang: exit != null && plan.noRoom,
          back: exit?.back ?? false,
          clip: exit != null && plan.noRoom && body._fixedExtent,
          extent: hangExtent,
          child: _ReorderItem(
            itemKey: key,
            index: index,
            exiting: exit != null,
            capturedThemes: InheritedTheme.capture(
              from: context,
              to: overlay.context,
            ),
            child: _wrapWithSemantics(child, index, exiting: exit != null),
          ),
        ),
      ),
    );
  }

  /// The body's frame plan as it stands at the sliver's layout.
  _FramePlan _plan() => _body._plan;

  /// The extent the plan gives [slot] under a fixed extent of
  /// [itemExtent], [itemExtentBuilder], or the measured prototype: none for
  /// a leaving item, which fades over the item that takes its place (E11);
  /// null past the last slot.
  double? _slotExtent(
    int slot,
    SliverLayoutDimensions dimensions, {
    required double? itemExtent,
    required ItemExtentBuilder? itemExtentBuilder,
  }) {
    final plan = _body._plan;
    if (slot < 0 || slot >= plan.childCount) return null;
    final (:data, :exit) = plan.at(slot);
    if (exit != null || data == null) return 0;
    return itemExtent ??
        itemExtentBuilder?.call(data, dimensions) ??
        _body._prototypeExtent ??
        0;
  }

  Widget _wrapWithSemantics(Widget child, int index, {required bool exiting}) {
    // A leaving item has no screen-reader node (E05).
    if (exiting) return Semantics(child: child);
    final semanticsActions = <CustomSemanticsAction, VoidCallback>{};

    void moveToStart() => _handleReorderItem(index, 0);
    void moveToEnd() => _handleReorderItem(index, widget.itemCount);
    void moveBefore() => _handleReorderItem(index, index - 1);
    // To move after, go to index+2: the space before index+2 is after
    // index+1.
    void moveAfter() => _handleReorderItem(index, index + 2);

    final localizations = WidgetsLocalizations.of(context);
    final isHorizontal = _scrollDirection == Axis.horizontal;
    if (index > 0) {
      semanticsActions[CustomSemanticsAction(
            label: localizations.reorderItemToStart,
          )] =
          moveToStart;
      var reorderItemBefore = localizations.reorderItemUp;
      if (isHorizontal) {
        reorderItemBefore = Directionality.of(context) == TextDirection.ltr
            ? localizations.reorderItemLeft
            : localizations.reorderItemRight;
      }
      semanticsActions[CustomSemanticsAction(label: reorderItemBefore)] =
          moveBefore;
    }
    if (index < widget.itemCount - 1) {
      var reorderItemAfter = localizations.reorderItemDown;
      if (isHorizontal) {
        reorderItemAfter = Directionality.of(context) == TextDirection.ltr
            ? localizations.reorderItemRight
            : localizations.reorderItemLeft;
      }
      semanticsActions[CustomSemanticsAction(label: reorderItemAfter)] =
          moveAfter;
      semanticsActions[CustomSemanticsAction(
            label: localizations.reorderItemToEnd,
          )] =
          moveToEnd;
    }
    return Semantics(
      container: true,
      customSemanticsActions: semanticsActions,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      debugCheckHasOverlay(context),
      'ReorderableListViewLayout needs an Overlay',
    );
    _reducesMotion = context.reducesMotion;
    // Taken at every build, so one turn's count reaches one rebuild alone.
    final slotsBefore = _body._takeSlotsBefore();
    final delegate = SliverChildBuilderDelegate(
      _itemBuilder,
      childCount: _body._plan.childCount,
      findChildIndexCallback: _body._findIndex,
      // The reorder item holds the item's own boundary, which it rasters
      // for the drag proxy; the slot frame gives each data item its
      // semantic index and a leaving item none (invariant 58).
      addRepaintBoundaries: false,
      addSemanticIndexes: false,
    );
    // Under a fixed extent a leaving item takes a slot of no extent, so
    // every fixed kind lays out through the plan's extents. The prototype
    // takes no Tab stop and no screen-reader node (invariant 58).
    if (_body._fixedExtent) {
      final prototype = widget.prototypeItem;
      return _PrototypeExtent(
        delegate: delegate,
        itemExtentBuilder: _extents,
        uniformPlan: widget.itemExtentBuilder == null ? _plan : null,
        prototypeItem: prototype == null
            ? null
            : ExcludeFocus(child: ExcludeSemantics(child: prototype)),
        onExtent: (extent) => _body._prototypeExtent = extent,
      );
    }
    return _SlotList(delegate: delegate, slotsBefore: slotsBefore);
  }
}

/// One item of the reorder layer, keyed by nothing: the frame above it
/// carries the item's key, so this State lives as long as the item's
/// element. Its widget shape never changes, lifted or not, so nothing under
/// it ever moves to another parent.
class _ReorderItem extends StatefulWidget {
  const new({
    required this.itemKey,
    required this.index,
    required this.exiting,
    required this.capturedThemes,
    required this.child,
  });

  final Key itemKey;
  final int index;

  /// Whether this is a leaving item, which takes no part in a drag.
  final bool exiting;
  final CapturedThemes capturedThemes;
  final Widget child;

  @override
  State<_ReorderItem> createState() => _ReorderItemState();
}

class _ReorderItemState extends State<_ReorderItem> {
  late _ReorderSliverState _list;

  Offset _startOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  AnimationController? _offsetAnimation;

  Key get key => widget.itemKey;
  int get index => widget.index;

  bool get dragging => _dragging;
  set dragging(bool dragging) {
    if (mounted) setState(() => _dragging = dragging);
  }

  var _dragging = false;

  @override
  void initState() {
    _list = context.findAncestorStateOfType<_ReorderSliverState>()!;
    _list._registerItem(this);
    super.initState();
  }

  @override
  void dispose() {
    _offsetAnimation?.dispose();
    _list._unregisterItem(key, this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReorderItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemKey != widget.itemKey) {
      _list._unregisterItem(oldWidget.itemKey, this);
    }
    _list._registerItem(this);
  }

  @override
  void deactivate() {
    _list._unregisterItem(key, this);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _list._registerItem(this);
  }

  /// A raster of the item as it painted last, at [pixelRatio]; null when
  /// it never painted.
  ui.Image? snapshot(double pixelRatio) =>
      snapshotBoundary?.snapshot(pixelRatio);

  /// The boundary below the item's grow-in transition
  /// ([_SnapshotBoundary], D5), as the last frame laid it out and
  /// painted it.
  _RenderSnapshotBoundary? get snapshotBoundary {
    final boundary = context.findRenderObject();
    _RenderSnapshotBoundary? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is _RenderSnapshotBoundary) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    if (boundary != null) visit(boundary);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    _list._registerItem(this);
    return IgnorePointer(
      ignoring: _dragging,
      child: _LiftHide(
        hidden: _dragging,
        child: Transform.translate(offset: offset, child: widget.child),
      ),
    );
  }

  Offset get offset {
    final animation = _offsetAnimation;
    if (animation != null) {
      final value = _list._standardCurve.transform(animation.value);
      return Offset.lerp(_startOffset, _targetOffset, value)!;
    }
    return _targetOffset;
  }

  void updateForGap(
    int dragIndex,
    int gapIndex,
    double gapExtent,
    bool animate,
    bool reverse,
  ) {
    final Offset newTargetOffset;
    if (gapIndex < dragIndex && index < dragIndex && index >= gapIndex) {
      newTargetOffset = _extentOffset(
        reverse ? -gapExtent : gapExtent,
        _list._scrollDirection,
      );
    } else if (gapIndex > dragIndex && index > dragIndex && index < gapIndex) {
      newTargetOffset = _extentOffset(
        reverse ? gapExtent : -gapExtent,
        _list._scrollDirection,
      );
    } else {
      newTargetOffset = Offset.zero;
    }
    if (newTargetOffset == _targetOffset) return;
    final previousTarget = _targetOffset;
    _targetOffset = newTargetOffset;
    if (animate) {
      final animation = _offsetAnimation;
      if (animation == null) {
        _offsetAnimation =
            AnimationController(vsync: _list, duration: _list._settleDuration)
              ..addListener(rebuild)
              ..addStatusListener((status) {
                if (status.isCompleted) {
                  _startOffset = _targetOffset;
                  _offsetAnimation!.dispose();
                  _offsetAnimation = null;
                }
              })
              ..forward();
      } else {
        final value = _list._standardCurve.transform(animation.value);
        _startOffset = Offset.lerp(_startOffset, previousTarget, value)!;
        animation.forward(from: 0);
      }
    } else {
      _offsetAnimation?.dispose();
      _offsetAnimation = null;
      _startOffset = _targetOffset;
    }
    rebuild();
  }

  void resetGap() {
    _offsetAnimation?.dispose();
    _offsetAnimation = null;
    _startOffset = Offset.zero;
    _targetOffset = Offset.zero;
    rebuild();
  }

  Rect targetGeometry() {
    final box = context.findRenderObject()! as RenderBox;
    final position = box.localToGlobal(Offset.zero) + _targetOffset;
    return position & box.size;
  }

  void rebuild() {
    if (mounted) setState(() {});
  }
}

/// Hides a lifted item where it lay: paints nothing while [hidden], and
/// keeps the item's semantics. Unlike an `Opacity`, it never composites,
/// so an item at rest keeps its one layer (D15).
class _LiftHide extends SingleChildRenderObjectWidget {
  const new({required this.hidden, super.child});

  final bool hidden;

  @override
  _RenderLiftHide createRenderObject(BuildContext context) =>
      _RenderLiftHide(hidden: hidden);

  @override
  void updateRenderObject(BuildContext context, _RenderLiftHide renderObject) {
    renderObject.hidden = hidden;
  }
}

class _RenderLiftHide extends RenderProxyBox {
  new({required bool hidden}) : _hidden = hidden;

  bool _hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
  }

  @override
  bool paintsChild(RenderBox child) => !_hidden;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_hidden) return;
    super.paint(context, offset);
  }
}

/// The one layer of an item at rest: a repaint boundary that rasters what
/// it painted last, for the drag proxy.
class _SnapshotBoundary extends SingleChildRenderObjectWidget {
  const new({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSnapshotBoundary();
}

class _RenderSnapshotBoundary extends RenderRepaintBoundary {
  /// What this boundary painted last, at [pixelRatio]; null before its
  /// first paint. Reads the retained layer, so a paint the lift itself
  /// queued does not block it.
  ui.Image? snapshot(double pixelRatio) {
    final layer = this.layer;
    if (layer is! OffsetLayer || !hasSize) return null;
    return layer.toImageSync(Offset.zero & size, pixelRatio: pixelRatio);
  }
}

typedef _LiftUpdate = void Function(_Lift lift, Offset position, Offset delta);
typedef _LiftCallback = void Function(_Lift lift);

/// The drag of one item: the SDK's `_DragInfo`, whose proxy shows a raster
/// of the item instead of the item itself.
class _Lift extends Drag {
  new({
    required _ReorderItemState item,
    Offset initialPosition = Offset.zero,
    this.scrollDirection = Axis.vertical,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
    this.onDropCompleted,
    this.proxyDecorator,
    required this.tickerProvider,
  }) {
    final itemRenderBox =
        item.snapshotBoundary ?? item.context.findRenderObject()! as RenderBox;
    listState = item._list;
    index = item.index;
    capturedThemes = item.widget.capturedThemes;
    dragOffset = itemRenderBox.globalToLocal(initialPosition);
    itemSize = itemRenderBox.size;
    _rawDragPosition = initialPosition;
    boundary = DragBoundary.forRectMaybeOf(listState.context);
    dragPosition = _adjustedDragOffset(initialPosition);
    itemExtent = _sizeExtent(itemSize, scrollDirection);
    itemLayoutConstraints = itemRenderBox.constraints;
    image = item.snapshot(View.maybeOf(item.context)?.devicePixelRatio ?? 1);
  }

  final Axis scrollDirection;
  final _LiftUpdate? onUpdate;
  final _LiftCallback? onEnd;
  final _LiftCallback? onCancel;
  final VoidCallback? onDropCompleted;
  final ReorderItemProxyDecorator? proxyDecorator;
  final TickerProvider tickerProvider;

  late DragBoundaryDelegate<Rect>? boundary;
  late _ReorderSliverState listState;
  late int index;
  late Offset dragPosition;
  late Offset dragOffset;
  late Size itemSize;
  late BoxConstraints itemLayoutConstraints;
  late double itemExtent;
  late CapturedThemes capturedThemes;

  /// The raster the proxy shows; null when the item never painted.
  ui.Image? image;
  AnimationController? _proxyAnimation;
  late Offset _rawDragPosition;

  void dispose() {
    _proxyAnimation?.dispose();
    image?.dispose();
    image = null;
  }

  void startDrag() {
    _proxyAnimation =
        AnimationController(
            vsync: tickerProvider,
            duration: listState._settleDuration,
          )
          ..addStatusListener((status) {
            if (status.isDismissed) _dropCompleted();
          })
          ..forward();
  }

  @override
  void update(DragUpdateDetails details) {
    final delta = _restrictAxis(details.delta, scrollDirection);
    _rawDragPosition += delta;
    dragPosition = _adjustedDragOffset(_rawDragPosition);
    onUpdate?.call(this, dragPosition, details.delta);
  }

  @override
  void end(DragEndDetails details) {
    _proxyAnimation!.reverse();
    onEnd?.call(this);
  }

  @override
  void cancel() {
    _proxyAnimation?.dispose();
    _proxyAnimation = null;
    onCancel?.call(this);
  }

  Offset _adjustedDragOffset(Offset offset) {
    final boundary = this.boundary;
    if (boundary == null) return offset;
    return boundary
        .nearestPositionWithinBoundary((offset - dragOffset) & itemSize)
        .shift(dragOffset)
        .topLeft;
  }

  void _dropCompleted() {
    _proxyAnimation?.dispose();
    _proxyAnimation = null;
    onDropCompleted?.call();
  }

  Widget createProxy(BuildContext context) {
    final image = this.image;
    return capturedThemes.wrap(
      _LiftProxy(
        listState: listState,
        index: index,
        size: itemSize,
        constraints: itemLayoutConstraints,
        animation: _proxyAnimation!,
        position: dragPosition - dragOffset - _overlayOrigin(context),
        proxyDecorator: proxyDecorator,
        child: image == null
            ? SizedBox.fromSize(size: itemSize)
            : RawImage(
                image: image,
                width: itemSize.width,
                height: itemSize.height,
                fit: BoxFit.fill,
              ),
      ),
    );
  }
}

Offset _overlayOrigin(BuildContext context) {
  final overlay = Overlay.of(context, debugRequiredFor: context.widget);
  final overlayBox = overlay.context.findRenderObject()! as RenderBox;
  return overlayBox.localToGlobal(Offset.zero);
}

/// The SDK's `_DragItemProxy` over a raster.
class _LiftProxy extends StatelessWidget {
  const new({
    required this.listState,
    required this.index,
    required this.child,
    required this.position,
    required this.size,
    required this.constraints,
    required this.animation,
    required this.proxyDecorator,
  });

  final _ReorderSliverState listState;
  final int index;
  final Widget child;
  final Offset position;
  final Size size;
  final BoxConstraints constraints;
  final AnimationController animation;
  final ReorderItemProxyDecorator? proxyDecorator;

  @override
  Widget build(BuildContext context) {
    final proxyChild =
        proxyDecorator?.call(child, index, animation.view) ?? child;
    final overlayOrigin = _overlayOrigin(context);
    return MediaQuery(
      data: MediaQuery.of(context).removePadding(removeTop: true),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          var effectivePosition = position;
          final dropPosition = listState._finalDropPosition;
          if (dropPosition != null) {
            effectivePosition = Offset.lerp(
              dropPosition - overlayOrigin,
              effectivePosition,
              listState._standardCurve.transform(animation.value),
            )!;
          }
          return Positioned(
            left: effectivePosition.dx,
            top: effectivePosition.dy,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: OverflowBox(
                minWidth: constraints.minWidth,
                minHeight: constraints.minHeight,
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
                alignment: listState._scrollDirection == Axis.horizontal
                    ? Alignment.centerLeft
                    : Alignment.topCenter,
                child: child,
              ),
            ),
          );
        },
        child: proxyChild,
      ),
    );
  }
}

/// Where an auto-scroll target [length] long starts on one axis, for an
/// item from [start] to [end] held at [pointer]: the item's start when it
/// fits, else the place nearest [listStart] that keeps the pointer inside
/// the target and the target inside the item.
double _targetStart(
  double start,
  double end,
  double pointer,
  double listStart,
  double length,
) {
  if (end - start <= length) return start;
  final lowest = math.max(start, pointer - length);
  final highest = math.min(end - length, pointer);
  return math.min(math.max(listStart, lowest), highest);
}

double _sizeExtent(Size size, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => size.width,
    Axis.vertical => size.height,
  };
}

double _offsetExtent(Offset offset, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => offset.dx,
    Axis.vertical => offset.dy,
  };
}

Offset _extentOffset(double extent, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => Offset(extent, 0),
    Axis.vertical => Offset(0, extent),
  };
}

Offset _restrictAxis(Offset offset, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => Offset(offset.dx, 0),
    Axis.vertical => Offset(0, offset.dy),
  };
}
