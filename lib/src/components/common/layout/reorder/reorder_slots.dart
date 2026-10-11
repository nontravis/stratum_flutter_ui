part of '../reorderable_list_view_layout.dart';

// The frame plan (D2, invariant 58): each build of the list lays its data
// items and each leaving item or closing gap out as sliver children of
// their own, so an item's subtree lives in one sliver child from its insert
// to the end of its exit (R47). Every index the list reports or gives
// semantics stays an index of the app's data; the slot render objects give
// a data item its data index, a leaving item no screen-reader node, a
// leaving item that takes no room its place over the item that took its
// own, and `prototypeItem` its measure, as the sliver's own child, with no
// paint, room, or focus.

/// Where a build lays each data item and each leaving item or closing gap
/// out, as sliver slots (R47): a slot holds a data item or one of [exits],
/// and every index the list reports or gives semantics stays an index of
/// the app's data (invariants 29 and 58).
class _FramePlan {
  const new({
    required this.dataCount,
    required this.exits,
    required this.noRoom,
  });

  /// The plan for [dataCount] items and [exits], in the list's order. A
  /// leaving item that takes room sits at its gap; one that takes none
  /// ([noRoom]) sits just after the item that takes its place and fades
  /// over it, or, past the last item, hangs past its far edge (E01, E11).
  factory of(
    List<_Exit> exits, {
    required int dataCount,
    required bool noRoom,
  }) {
    final planned = <_PlannedExit>[];
    for (final exit in exits) {
      final gap = exit.gap.value.clamp(0, dataCount);
      final past = gap >= dataCount;
      final entry = _PlannedExit(
        exit,
        after: noRoom && !past ? gap + 1 : gap,
        back: noRoom && !past,
      );
      // Stable by `after`: exits at one gap keep the list's order.
      var at = planned.length;
      while (at > 0 && planned[at - 1].after > entry.after) {
        at -= 1;
      }
      planned.insert(at, entry);
    }
    return _FramePlan(dataCount: dataCount, exits: planned, noRoom: noRoom);
  }

  /// The plan of a list with no items and no leaving ones.
  static const none = _FramePlan(dataCount: 0, exits: [], noRoom: false);

  final int dataCount;

  /// The leaving items and closing gaps, by slot.
  final List<_PlannedExit> exits;

  /// Whether a leaving item takes no room while it leaves.
  final bool noRoom;

  int get childCount => dataCount + exits.length;

  /// The data index, or the leaving item, at [slot].
  ({int? data, _PlannedExit? exit}) at(int slot) {
    var before = 0;
    for (final (index, entry) in exits.indexed) {
      final at = entry.after + index;
      if (at == slot) return (data: null, exit: entry);
      if (at > slot) break;
      before = index + 1;
    }
    return (data: slot - before, exit: null);
  }

  /// The slot of the data item at [index].
  int slotOfData(int index) {
    var slot = index;
    for (final entry in exits) {
      if (entry.after > index) break;
      slot += 1;
    }
    return slot;
  }

  /// The slot of the leaving item or closing gap whose frame key is [key];
  /// null for none.
  int? slotOfExit(Key key) {
    for (final (index, entry) in exits.indexed) {
      if (entry.exit.frameKey == key) return entry.after + index;
    }
    return null;
  }
}

/// A leaving item or closing gap in a [_FramePlan]: [after] data items sit
/// before it, and [back] hangs it back over the item before it.
class _PlannedExit {
  const new(this.exit, {required this.after, required this.back});

  final _Exit exit;
  final int after;
  final bool back;
}

/// The semantics of one slot: a data item's own node at its data index; a
/// leaving item, [index] null, none (invariant 58, E05).
class _SlotSemantics extends SingleChildRenderObjectWidget {
  const new({required this.index, required this.exit, super.child});

  final int? index;

  /// The leaving item or closing gap this slot shows; null for a data item.
  final _Exit? exit;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSlotSemantics(index)..exit = exit;

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSlotSemantics renderObject,
  ) {
    renderObject
      ..index = index
      ..exit = exit;
  }
}

class _RenderSlotSemantics extends RenderProxyBox {
  new(this._index);

  /// The leaving item or closing gap this slot shows, as the build that
  /// laid it out gave it; the body drops an ended one once it is laid out.
  _Exit? exit;

  /// The data index of the item in this slot, as the build that laid it
  /// out gave it; null for a leaving item or closing gap. The body reads
  /// the laid-out data range from it ([_ReorderableBodyState._laidOut]).
  int? get index => _index;
  int? _index;
  set index(int? value) {
    if (value == _index) return;
    _index = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final index = _index;
    if (index == null) return;
    config
      ..isSemanticBoundary = true
      ..indexInParent = index;
  }
}

/// A leaving item that takes no room ([hang]): a slot of no extent whose
/// child paints from the leading edge of the item before it, [back], or
/// past that item's far edge, over it (E01, E11). [extent], when given,
/// is the child's own main-axis extent, and [clip] clips the child to the
/// item it fades over. Any other slot lays its child out as it is.
class _Hang extends SingleChildRenderObjectWidget {
  const new({
    required this.axis,
    required this.hang,
    required this.back,
    required this.clip,
    required this.extent,
    super.child,
  });

  final Axis axis;
  final bool hang;
  final bool back;
  final bool clip;
  final double? extent;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHang(
    axis: axis,
    hang: hang,
    back: back,
    clip: clip,
    extent: extent,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderHang renderObject) {
    renderObject
      ..axis = axis
      ..hang = hang
      ..back = back
      ..clip = clip
      ..extent = extent;
  }
}

class _RenderHang extends RenderProxyBox {
  new({
    required Axis axis,
    required bool hang,
    required bool back,
    required bool clip,
    required double? extent,
  }) : _axis = axis,
       _hang = hang,
       _back = back,
       _clip = clip,
       _extent = extent;

  Axis _axis;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  bool _hang;
  set hang(bool value) {
    if (value == _hang) return;
    _hang = value;
    markNeedsLayout();
  }

  bool _back;
  set back(bool value) {
    if (value == _back) return;
    _back = value;
    markNeedsPaint();
  }

  bool _clip;
  set clip(bool value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  double? _extent;
  set extent(double? value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  final _clipHandle = LayerHandle<ClipRectLayer>();

  double _main(Size size) => _axis == Axis.vertical ? size.height : size.width;

  Size _zeroExtent(BoxConstraints constraints) => constraints.constrain(
    _axis == Axis.vertical
        ? Size(constraints.maxWidth, 0)
        : Size(0, constraints.maxHeight),
  );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (!_hang) return super.computeDryLayout(constraints);
    return _zeroExtent(constraints);
  }

  @override
  void performLayout() {
    if (!_hang) {
      super.performLayout();
      return;
    }
    final c = constraints;
    final extent = _extent;
    child?.layout(
      _axis == Axis.vertical
          ? BoxConstraints(
              minWidth: c.minWidth,
              maxWidth: c.maxWidth,
              minHeight: extent ?? 0,
              maxHeight: extent ?? double.infinity,
            )
          : BoxConstraints(
              minHeight: c.minHeight,
              maxHeight: c.maxHeight,
              minWidth: extent ?? 0,
              maxWidth: extent ?? double.infinity,
            ),
      parentUsesSize: true,
    );
    size = _zeroExtent(c);
  }

  /// The child's paint offset and, with [clip], the rect of the item it
  /// fades over, both in this box's coordinates; read at paint, once the
  /// sliver laid every slot out.
  ({Offset shift, Rect? clip}) _placement() {
    final child = this.child;
    RenderObject slot = this;
    while (slot.parent is! RenderSliverMultiBoxAdaptor) {
      final parent = slot.parent;
      if (parent == null || child == null) {
        return (shift: Offset.zero, clip: null);
      }
      slot = parent;
    }
    final sliver = slot.parent! as RenderSliverMultiBoxAdaptor;
    var back = 0.0;
    if (_back) {
      for (
        var before = sliver.childBefore(slot as RenderBox);
        before != null;
        before = sliver.childBefore(before)
      ) {
        final extent = _main(before.size);
        if (extent > 0) {
          back = extent;
          break;
        }
      }
    }
    final direction = applyGrowthDirectionToAxisDirection(
      sliver.constraints.axisDirection,
      sliver.constraints.growthDirection,
    );
    final reversed = axisDirectionIsReversed(direction);
    final along = reversed ? back - _main(child!.size) : -back;
    final shift = _axis == Axis.vertical ? Offset(0, along) : Offset(along, 0);
    if (!_clip) return (shift: shift, clip: null);
    final start = reversed ? 0.0 : -back;
    return (
      shift: shift,
      clip: _axis == Axis.vertical
          ? Rect.fromLTWH(0, start, size.width, back)
          : Rect.fromLTWH(start, 0, back, size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (!_hang || child == null) {
      _clipHandle.layer = null;
      super.paint(context, offset);
      return;
    }
    final (:shift, :clip) = _placement();
    if (clip == null) {
      _clipHandle.layer = null;
      context.paintChild(child, offset + shift);
      return;
    }
    _clipHandle.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clip,
      (context, offset) => context.paintChild(child, offset + shift),
      oldLayer: _clipHandle.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (!_hang) return;
    final (:shift, clip: _) = _placement();
    transform.translateByDouble(shift.dx, shift.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_hang) return false;
    return super.hitTestChildren(result, position: position);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    if (!_hang) return null;
    return _placement().clip;
  }

  @override
  void dispose() {
    _clipHandle.layer = null;
    super.dispose();
  }
}

/// The list's sliver under every fixed extent: a varied-extent list whose
/// slots take the plan's extents ([_ReorderSliverState._slotExtent]), and
/// which measures [prototypeItem], when given, as a child of its own before
/// it lays its slots out, so a new size of the prototype lays the list out
/// again, as `SliverPrototypeExtentList` does. The prototype has no paint,
/// no hit test, and no semantics, and hands its main-axis extent to
/// [onExtent].
class _PrototypeExtent extends SliverVariedExtentList {
  const new({
    required super.delegate,
    required super.itemExtentBuilder,
    required this.prototypeItem,
    required this.onExtent,
  });

  final Widget? prototypeItem;
  final ValueSetter<double> onExtent;

  @override
  SliverMultiBoxAdaptorElement createElement() => _PrototypeExtentElement(this);

  @override
  _RenderPrototypeExtent createRenderObject(BuildContext context) =>
      _RenderPrototypeExtent(
        childManager: context as _PrototypeExtentElement,
        itemExtentBuilder: itemExtentBuilder,
        onExtent: onExtent,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderPrototypeExtent renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.onExtent = onExtent;
  }
}

/// The SDK's `_SliverPrototypeExtentListElement`, with an optional
/// prototype: it holds the prototype's element in a slot of its own beside
/// the list's children.
class _PrototypeExtentElement extends SliverMultiBoxAdaptorElement {
  new(_PrototypeExtent super.widget);

  @override
  _RenderPrototypeExtent get renderObject =>
      super.renderObject as _RenderPrototypeExtent;

  Element? _prototype;
  static final Object _prototypeSlot = Object();

  @override
  void insertRenderObjectChild(
    covariant RenderObject child,
    covariant Object slot,
  ) {
    if (slot == _prototypeSlot) {
      renderObject.child = child as RenderBox;
    } else {
      super.insertRenderObjectChild(child, slot as int);
    }
  }

  @override
  void didAdoptChild(RenderBox child) {
    if (child != renderObject.child) super.didAdoptChild(child);
  }

  @override
  void moveRenderObjectChild(RenderBox child, Object oldSlot, Object newSlot) {
    assert(newSlot != _prototypeSlot, 'The prototype never moves');
    super.moveRenderObjectChild(child, oldSlot as int, newSlot as int);
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object slot) {
    if (renderObject.child == child) {
      renderObject.child = null;
    } else {
      super.removeRenderObjectChild(child, slot as int);
    }
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_prototype case final prototype?) visitor(prototype);
    super.visitChildren(visitor);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _prototype = updateChild(
      _prototype,
      (widget as _PrototypeExtent).prototypeItem,
      _prototypeSlot,
    );
  }

  @override
  void update(covariant _PrototypeExtent newWidget) {
    super.update(newWidget);
    _prototype = updateChild(
      _prototype,
      newWidget.prototypeItem,
      _prototypeSlot,
    );
  }
}

class _RenderPrototypeExtent extends RenderSliverVariedExtentList {
  new({
    required _PrototypeExtentElement super.childManager,
    required super.itemExtentBuilder,
    required this.onExtent,
  });

  ValueSetter<double> onExtent;

  /// The prototype, laid out with its size used: a new size of it lays
  /// this sliver out again.
  RenderBox? get child => _child;
  RenderBox? _child;
  set child(RenderBox? value) {
    if (_child case final old?) dropChild(old);
    _child = value;
    if (value != null) adoptChild(value);
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (_child case final child?) {
      child.layout(constraints.asBoxConstraints(), parentUsesSize: true);
      onExtent(
        constraints.axis == Axis.vertical
            ? child.size.height
            : child.size.width,
      );
    }
    super.performLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _child?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _child?.detach();
  }

  @override
  void redepthChildren() {
    if (_child case final child?) redepthChild(child);
    super.redepthChildren();
  }

  // The prototype takes no part in paint, hit testing, or semantics: the
  // sliver's own paint, hit test, and semantics walk read only its slots.
  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_child case final child?) visitor(child);
    super.visitChildren(visitor);
  }
}
