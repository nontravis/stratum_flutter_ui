import 'dart:math' as math;

import 'package:flutter/rendering.dart'
    show
        ContainerLayer,
        ItemExtentBuilder,
        Layer,
        RenderRepaintBoundary,
        RenderSliverMultiBoxAdaptor,
        ScrollCacheExtent,
        SliverLayoutDimensions;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _red = Color(0xFFFF0000);

/// Whether every [_Harness] gives its list `findChildIndexCallback`, for the
/// groups that rerun with an app index (D19).
var _appIndex = false;

/// [child], 200 by 300, in an app with an overlay, localizations, and the
/// default keys, under the Stratum theme.
Widget _app(
  Widget child, {
  TextDirection textDirection = TextDirection.ltr,
  StratumThemeData? theme,
}) {
  return MaterialApp(
    home: Material(
      child: themedHost(
        SizedBox(width: 200, height: 300, child: child),
        textDirection: textDirection,
        theme: theme,
      ),
    ),
  );
}

/// A reorderable list of [count] [_Item]s whose ids start in order; it
/// applies every move to its ids.
class _Harness extends StatefulWidget {
  const new({
    super.key,
    required this.count,
    this.axis = Axis.vertical,
    this.dragStyle,
    this.longPressDrag = true,
    this.handles = false,
    this.fieldAt,
    this.innerAt,
    this.itemsController,
    this.focusable,
    this.semanticsLabel,
    this.physics,
    this.itemExtent,
    this.itemTransitionBuilder,
    this.reverse = false,
    this.paintLog,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.fillItems = false,
    this.onItemBuild,
    this.heights,
    this.widths,
    this.keepAliveIds,
    this.plainIds,
    this.scrollCacheExtent,
    this.appIndex = false,
    this.shrinkWrap = false,
    this.moveAnnouncement,
    this.atStartAnnouncement,
    this.atEndAnnouncement,
    this.boundaryAt,
    this.boundary,
  });

  final int count;
  final Axis axis;
  final WidgetStyle? dragStyle;
  final bool longPressDrag;

  /// Whether each item has a drag handle at its start.
  final bool handles;

  /// The id of the item that holds a text field.
  final int? fieldAt;

  /// The id of the item that holds a second focus node after its own.
  final int? innerAt;

  /// The controller the list animates inserts and removes through.
  final ReorderableItemsController? itemsController;

  /// The list's `focusable`; null keeps the platform default.
  final bool? focusable;

  /// The list's `semanticsLabel`; null keeps the list unlabeled.
  final String? semanticsLabel;

  /// The list's scroll physics, if any.
  final ScrollPhysics? physics;

  /// The list's fixed item extent, if any.
  final double? itemExtent;

  /// The list's caller transition for inserted and removed items.
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  )?
  itemTransitionBuilder;

  /// Whether index 0 sits at the list's bottom.
  final bool reverse;

  /// Logs each item's id as it paints, in paint order.
  final List<int>? paintLog;

  /// The list's per-index item extent, if any.
  final ItemExtentBuilder? itemExtentBuilder;

  /// The item whose extent every slot takes, if any.
  final Widget? prototypeItem;

  /// Whether each item fills its slot around its 40 px box.
  final bool fillItems;

  /// Runs each time the list calls `itemBuilder`, with the context it gets.
  final void Function(BuildContext context)? onItemBuild;

  /// The height of an item by id, where it is not 40.
  final Map<int, double>? heights;

  /// The width of an item by id, where it is not 40.
  final Map<int, double>? widths;

  /// The ids of the items that keep themselves alive off screen.
  final Set<int>? keepAliveIds;

  /// The ids of the items that hold no focus node, as header rows do.
  final Set<int>? plainIds;

  /// The list's `scrollCacheExtent`; null keeps the default 250 px.
  final ScrollCacheExtent? scrollCacheExtent;

  /// Whether the list gets `findChildIndexCallback`, as under [_appIndex].
  final bool appIndex;

  /// The list's `shrinkWrap`.
  final bool shrinkWrap;

  /// The list's `moveAnnouncement`; null keeps the built-in text.
  final String Function(int position, int count)? moveAnnouncement;

  /// The list's `atStartAnnouncement`; null keeps the built-in text.
  final String? atStartAnnouncement;

  /// The list's `atEndAnnouncement`; null keeps the built-in text.
  final String? atEndAnnouncement;

  /// The id of the item whose focusable content [boundary] wraps, so the
  /// moved or removed subtree holds its own semantics boundary (FR-05 E04,
  /// FR-04 E05).
  final int? boundaryAt;

  /// Wraps item [boundaryAt]'s focusable content in a nested semantics
  /// boundary; null keeps the plain content.
  final Widget Function(Widget child)? boundary;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final List<int> ids = [for (var i = 0; i < widget.count; i++) i];
  final moves = <(int, int)>[];
  final starts = <int>[];
  final ends = <int>[];

  /// Each `onReorderStart` and `onReorderEnd`, as `start <index>` or
  /// `end <index>`, in call order.
  final events = <String>[];

  /// Runs inside `onReorderStart`, after the start is logged.
  void Function(int index)? onStart;

  /// Runs inside `onReorderEnd`, after the end is logged.
  void Function(int index)? onEnd;

  /// Runs inside `onReorderItem`, after the move is applied.
  void Function(int from, int to)? onMove;

  /// Whether the item [_Harness.innerAt] names still builds its inner node.
  bool innerShown = true;

  /// Stops building the inner node of item [_Harness.innerAt], so that node
  /// leaves the tree while the item keeps its State.
  void hideInner() => setState(() => innerShown = false);

  /// Inserts [id] at [index] of the ids and animates it in.
  void insert(int index, int id) {
    setState(() => ids.insert(index, id));
    widget.itemsController!.insertItem(index);
  }

  /// Removes the id at [index] and animates it out, in the look [builder]
  /// makes when one is given.
  void remove(int index, {WidgetBuilder? builder}) {
    setState(() => ids.removeAt(index));
    widget.itemsController!.removeItem(index, builder: builder);
  }

  /// Moves the id at [from] to [to] of the ids and animates the move.
  void move(int from, int to) {
    setState(() => ids.insert(to, ids.removeAt(from)));
    widget.itemsController!.moveItem(from, to);
  }

  /// Inserts [id] at [index] of the ids with no controller call.
  void insertData(int index, int id) => setState(() => ids.insert(index, id));

  /// Removes the id at [index] with no controller call.
  void removeData(int index) => setState(() => ids.removeAt(index));

  /// Moves the id at [from] to [to] with no controller call.
  void moveData(int from, int to) =>
      setState(() => ids.insert(to, ids.removeAt(from)));

  /// Puts [id] in place of the id at [index] with no controller call.
  void replaceData(int index, int id) => setState(() => ids[index] = id);

  /// How many times the list called `findChildIndexCallback`.
  int indexCalls = 0;

  /// Replaces the index [indexOf] answers, when set.
  int? Function(Key key)? answer;

  /// The list's `findChildIndexCallback`: the key's index in [ids].
  int? indexOf(Key key) {
    indexCalls += 1;
    final answer = this.answer;
    if (answer != null) return answer(key);
    if (key is! ValueKey<int>) return null;
    final index = ids.indexOf(key.value);
    return index < 0 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListViewLayout.builder(
      scrollDirection: widget.axis,
      itemCount: ids.length,
      dragStyle: widget.dragStyle,
      longPressDrag: widget.longPressDrag,
      itemsController: widget.itemsController,
      focusable: widget.focusable,
      semanticsLabel: widget.semanticsLabel,
      physics: widget.physics,
      itemExtent: widget.itemExtent,
      itemTransitionBuilder: widget.itemTransitionBuilder,
      reverse: widget.reverse,
      itemExtentBuilder: widget.itemExtentBuilder,
      prototypeItem: widget.prototypeItem,
      scrollCacheExtent: widget.scrollCacheExtent,
      findChildIndexCallback: widget.appIndex || _appIndex ? indexOf : null,
      shrinkWrap: widget.shrinkWrap,
      moveAnnouncement: widget.moveAnnouncement,
      atStartAnnouncement: widget.atStartAnnouncement,
      atEndAnnouncement: widget.atEndAnnouncement,
      onReorderStart: (index) {
        starts.add(index);
        events.add('start $index');
        onStart?.call(index);
      },
      onReorderEnd: (index) {
        ends.add(index);
        events.add('end $index');
        onEnd?.call(index);
      },
      onReorderItem: (from, to) {
        setState(() {
          moves.add((from, to));
          ids.insert(to, ids.removeAt(from));
        });
        onMove?.call(from, to);
      },
      itemBuilder: (context, index) {
        widget.onItemBuild?.call(context);
        return _Item(
          key: ValueKey(ids[index]),
          id: ids[index],
          index: index,
          handle: widget.handles,
          field: widget.fieldAt == ids[index],
          inner: innerShown && widget.innerAt == ids[index],
          paintLog: widget.paintLog,
          fill: widget.fillItems,
          height: widget.heights?[ids[index]] ?? 40,
          width: widget.widths?[ids[index]] ?? 40,
          keepAlive: widget.keepAliveIds?.contains(ids[index]) ?? false,
          plain: widget.plainIds?.contains(ids[index]) ?? false,
          boundary: widget.boundaryAt == ids[index] ? widget.boundary : null,
        );
      },
    );
  }
}

/// A 40 px item, or one [height] px tall, with a focus node labeled
/// `item <id>` and an `expanded` flag that lives in its State.
class _Item extends StatefulWidget {
  const new({
    super.key,
    required this.id,
    required this.index,
    this.handle = false,
    this.field = false,
    this.inner = false,
    this.paintLog,
    this.fill = false,
    this.height = 40,
    this.width = 40,
    this.keepAlive = false,
    this.plain = false,
    this.boundary,
  });

  final int id;
  final int index;
  final bool handle;
  final bool field;

  /// Whether a second node, labeled `inner <id>`, follows the item's own
  /// node in Tab order, inside it.
  final bool inner;

  /// Logs [id] each time the item paints.
  final List<int>? paintLog;

  /// Whether the item stretches its box across the slot, so it needs a
  /// bounded main axis.
  final bool fill;

  /// The item's height, its main-axis extent in a vertical list.
  final double height;

  /// The item's width, its main-axis extent in a horizontal list and its
  /// cross-axis extent in a vertical one.
  final double width;

  /// Whether the item keeps itself alive when it leaves the built range.
  final bool keepAlive;

  /// Whether the item holds no focus node, only its label.
  final bool plain;

  /// Wraps the item's focusable content in a nested semantics boundary, for
  /// FR-05 E04 and FR-04 E05 pins; null keeps the plain content.
  final Widget Function(Widget child)? boundary;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> with AutomaticKeepAliveClientMixin {
  late final node = FocusNode(debugLabel: 'item ${widget.id}');
  late final inner = FocusNode(debugLabel: 'inner ${widget.id}');
  bool expanded = false;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void dispose() {
    node.dispose();
    inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.field) {
      return SizedBox(width: 40, height: 40, child: TextField(focusNode: node));
    }
    final label = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Text('${widget.id}'),
    );
    if (widget.plain) return label;
    Widget item = Focus(
      focusNode: node,
      child: widget.inner
          ? Row(
              children: [
                label,
                Focus(
                  focusNode: inner,
                  child: const SizedBox(width: 40, height: 40),
                ),
              ],
            )
          : label,
    );
    final boundary = widget.boundary;
    // A plain RenderObject between the moved subtree's reparenting key and
    // its semantics boundary, as the RCA probe's own SizedBox(key: id) ...
    // boundary wrapper sits: `Semantics(container: true)` and
    // `_innerInkWellBoundary`'s surface repro R1's bug only with one above
    // them (fr05/e04, fr04/e05); a nested ListView's own RenderObjects
    // stand in for it.
    if (boundary != null) {
      item = SizedBox(height: widget.height, child: boundary(item));
    }
    if (widget.handle) {
      item = Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: SizedBox(
              key: ValueKey('handle ${widget.id}'),
              width: 20,
              height: 40,
              child: const ColoredBox(color: _red),
            ),
          ),
          item,
        ],
      );
    }
    if (widget.fill) {
      item = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [item],
      );
    }
    final paintLog = widget.paintLog;
    if (paintLog != null) {
      item = CustomPaint(
        painter: _PaintLogger(widget.id, paintLog),
        child: item,
      );
    }
    return item;
  }
}

/// Adds [id] to [log] each time it paints, so a test reads paint order.
class _PaintLogger extends CustomPainter {
  new(this.id, this.log);

  final int id;
  final List<int> log;

  @override
  void paint(Canvas canvas, Size size) => log.add(id);

  @override
  bool shouldRepaint(_PaintLogger oldDelegate) => false;
}

_HarnessState _harness(WidgetTester tester) =>
    tester.state<_HarnessState>(find.byType(_Harness));

/// The text of each announcement the app sends from now on.
List<String> _announcements(WidgetTester tester) {
  final log = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger
    ..setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
      message,
    ) async {
      final event = message as Map<Object?, Object?>;
      if (event['type'] == 'announce') {
        final data = event['data']! as Map<Object?, Object?>;
        log.add(data['message']! as String);
      }
      return null;
    });
  addTearDown(
    () => messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    ),
  );
  return log;
}

/// The first [_Harness] in the tree, for a tree that holds more than one.
_HarnessState _harnessA(WidgetTester tester) =>
    tester.state<_HarnessState>(find.byType(_Harness).first);

_ItemState _itemState(WidgetTester tester, int id) =>
    tester.state<_ItemState>(find.byKey(ValueKey(id), skipOffstage: false));

/// Focuses item [id] and returns its node.
Future<FocusNode> _focusItem(WidgetTester tester, int id) async {
  final node = _itemState(tester, id).node..requestFocus();
  await tester.pump();
  return node;
}

/// Performs the move action labeled [label] on item [id], as a screen
/// reader does.
Future<void> _moveAction(WidgetTester tester, int id, String label) async {
  final node = tester.getSemantics(find.byKey(ValueKey(id)));
  node.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
  );
  await tester.pumpAndSettle();
}

/// Whether item [id] lies wholly inside the list's viewport.
bool _itemInView(WidgetTester tester, int id) {
  final view = tester.getRect(find.byType(Scrollable));
  final item = tester.getRect(find.byKey(ValueKey(id)));
  return view.intersect(item) == item;
}

/// Pumps [harness], scrolls its list to [offset], focuses item [id], and in
/// one turn removes it and inserts it back at [slot] of the data.
Future<void> _returnFocused(
  WidgetTester tester,
  _Harness harness, {
  required double offset,
  required int id,
  required int slot,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(_app(harness, textDirection: textDirection));
  tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position
      .jumpTo(offset);
  await tester.pump();
  await _focusItem(tester, id);
  _harness(tester)
    ..remove(id)
    ..insert(slot, id);
}

/// Holds the list at [pixels]: each jump away springs back at once, and
/// [onSpringBack] counts it.
void _pinScroll(
  WidgetTester tester,
  double pixels, {
  VoidCallback? onSpringBack,
}) {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position;
  position.addListener(() {
    if (position.pixels == pixels) return;
    onSpringBack?.call();
    position.jumpTo(pixels);
  });
}

/// Presses [key] with Alt held and returns whether it was handled.
Future<bool> _alt(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  final handled = await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
  return handled;
}

/// The main-axis distance from item [from]'s top to item [to]'s top.
double _offsetBetween(WidgetTester tester, int from, int to) =>
    tester.getTopLeft(find.byKey(ValueKey(to))).dy -
    tester.getTopLeft(find.byKey(ValueKey(from))).dy;

/// The main-axis distance from the list's top to item [id]'s top. An item
/// inside a running size transition sits centered in its clip, so read
/// only items that are not growing.
double _top(WidgetTester tester, int id) =>
    tester.getTopLeft(find.byKey(ValueKey(id))).dy -
    tester.getTopLeft(find.byType(Scrollable)).dy;

/// The opacity of the nearest [FadeTransition] around item [id], or of a
/// subtype of it, as the built-in fade is.
double _opacity(WidgetTester tester, int id) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(ValueKey(id)),
            matching: find.byWidgetPredicate(
              (widget) => widget is FadeTransition,
            ),
          )
          .first,
    )
    .opacity
    .value;

/// The opacity of the nearest [FadeTransition] around item [id], reached
/// even offstage: a zero-extent child at offset 0, as an item entering
/// slot 0 is, is offstage to the default finders.
double _enteringOpacity(WidgetTester tester, int id) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(ValueKey(id), skipOffstage: false),
            matching: find.byWidgetPredicate(
              (widget) => widget is FadeTransition,
              skipOffstage: false,
            ),
          )
          .first,
    )
    .opacity
    .value;

/// The box item [id] grows or shrinks in: the parent of its built-in fade,
/// reached even offstage.
RenderBox _sizeBox(WidgetTester tester, int id) =>
    tester
            .renderObject(
              find
                  .ancestor(
                    of: find.byKey(ValueKey(id), skipOffstage: false),
                    matching: find.byWidgetPredicate(
                      (widget) => widget is FadeTransition,
                      skipOffstage: false,
                    ),
                  )
                  .first,
            )
            .parent!
        as RenderBox;

/// [fakeTheme] with its `normal` level at [normal]; the reverse duration
/// keeps the package default's 64%, so 250 ms reverses in 160 ms.
StratumThemeData _normalTheme(Duration normal) {
  final config = defaultThemeConfig.animation;
  return fakeTheme.copyWith(
    animation: StratumAnimation.fromConfig(
      StratumAnimationConfig(
        durations: {...config.durations, 'normal': normal},
        defaultLevel: config.defaultLevel,
        reverseRatio: config.reverseRatio,
        curves: config.curves,
      ),
    ),
  );
}

/// Half the forward duration of [theme]'s `normal` level: an insert's
/// midpoint.
Duration _halfForward(StratumThemeData theme) =>
    (theme.animation.normal.duration ?? Duration.zero) ~/ 2;

/// Half the reverse duration of [theme]'s `normal` level, as the list
/// reads it: a remove's midpoint.
Duration _halfReverse(StratumThemeData theme) {
  final normal = theme.animation.normal;
  return (normal.reverseDuration ?? normal.duration ?? Duration.zero) ~/ 2;
}

/// The first and last slot the list's sliver laid out in the last frame,
/// and how many it laid out; a kept-alive item sits outside that list.
({int first, int last, int count}) _laidOut(WidgetTester tester) {
  final sliver = tester.renderObject<RenderSliverMultiBoxAdaptor>(
    find.byWidgetPredicate(
      (widget) => widget is SliverMultiBoxAdaptorWidget,
      skipOffstage: false,
    ),
  );
  var first = -1;
  var last = -1;
  var count = 0;
  for (
    var child = sliver.firstChild;
    child != null;
    child = sliver.childAfter(child)
  ) {
    final index = sliver.indexOf(child);
    if (count == 0) first = index;
    last = index;
    count += 1;
  }
  return (first: first, last: last, count: count);
}

/// The States of item [id] the list holds, laid out or kept alive.
List<_ItemState> _statesOf(WidgetTester tester, int id) => tester
    .stateList<_ItemState>(find.byKey(ValueKey(id), skipOffstage: false))
    .toList();

/// Whether item [id] is built and lies wholly inside the list's viewport.
bool _builtInView(WidgetTester tester, int id) =>
    find.byKey(ValueKey(id)).evaluate().isNotEmpty && _itemInView(tester, id);

/// The [IgnorePointer] ancestors of [element] that ignore pointers, nearest
/// first: empty when no ancestor keeps a pointer from reaching it.
List<IgnorePointer> _ignoringAncestors(Element element) {
  final ignoring = <IgnorePointer>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is IgnorePointer && widget.ignoring) ignoring.add(widget);
    return true;
  });
  return ignoring;
}

/// Pumps [harness] in [_app] and scrolls its list to [offset].
Future<ScrollPosition> _pumpScrolled(
  WidgetTester tester,
  _Harness harness, {
  double offset = 4000,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(_app(harness, textDirection: textDirection));
  final position =
      tester.state<ScrollableState>(find.byType(Scrollable)).position
        ..jumpTo(offset);
  await tester.pump();
  return position;
}

/// Presses [key] with Alt held and pumps no frame, so the move lands
/// before the next frame.
Future<void> _altNow(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
}

/// The list's sliver: the widgets `SliverReorderableList` or a subtype of
/// it. `find.byType` matches the exact runtime type, so it would miss a
/// subtype (D11).
Finder _reorderSliver() =>
    find.byWidgetPredicate((widget) => widget is SliverReorderableList);

/// The size and fade transitions inside the list that are not at rest: at
/// rest every item sits inside a completed transition (R48).
List<Widget> _runningTransitions(WidgetTester tester) => [
  for (final widget in tester.widgetList(
    find.descendant(
      of: _reorderSliver(),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizeTransition || widget is FadeTransition,
        skipOffstage: false,
      ),
      skipOffstage: false,
    ),
  ))
    if (switch (widget) {
      SizeTransition(:final sizeFactor) => sizeFactor.value != 1,
      FadeTransition(:final opacity) => opacity.value != 1,
      _ => false,
    })
      widget,
];

/// The ids among [ids] in the order the list composites them, back to
/// front: each item paints into its own repaint boundary (R49), so the
/// order of those layers is its paint order.
List<int> _compositeOrder(WidgetTester tester, List<int> ids) {
  final byLayer = <Layer, int>{};
  for (final id in ids) {
    RenderObject? node = tester.renderObject(
      find.byKey(ValueKey(id), skipOffstage: false),
    );
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    final layer = node?.debugLayer;
    if (layer != null) byLayer[layer] = id;
  }
  final order = <int>[];
  void visit(Layer layer) {
    final id = byLayer[layer];
    if (id != null) order.add(id);
    if (layer is ContainerLayer) {
      for (
        var child = layer.firstChild;
        child != null;
        child = child.nextSibling
      ) {
        visit(child);
      }
    }
  }

  visit(tester.binding.renderViews.first.debugLayer!);
  return order;
}

/// Long-presses item [id] past the long-press delay and moves it [by] px
/// down: a drag of the item in progress.
Future<TestGesture> _liftItem(
  WidgetTester tester,
  int id, {
  double by = 10,
}) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text('$id')));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.moveBy(Offset(0, by));
  await tester.pump();
  return gesture;
}

/// Steps a lifted item 0 down 10 px at a time, each step pumped over 16 ms
/// of real time, until item 1's top leaves 40: the SDK's own gap trigger is
/// a dead zone past a single big jump (it compares against each item's own
/// *current* target, not its original slot), so a slow drag finds the
/// crossing the way an EndUser's drag would. The step that crosses it also
/// delivers that gap controller's first real tick: reduced motion's seam
/// ends it there at once; plain motion leaves it partway, still sliding.
/// Fails, naming the cause, when 10 steps never cross.
Future<void> _dragPastNeighbor(WidgetTester tester, TestGesture gesture) async {
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 16));
    if (_top(tester, 1) != 40) return;
  }
  fail(
    '_dragPastNeighbor: item 1 stayed at 40 px over 10 steps of 10 px; the '
    "SDK's gap trigger never fired, so the drag crossed no neighbor",
  );
}

/// Drags item [id] by its handle past the touch slop, on [pointer] when
/// given.
Future<TestGesture> _grabHandle(
  WidgetTester tester,
  int id, {
  int? pointer,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(ValueKey('handle $id'))),
    pointer: pointer,
  );
  await tester.pump();
  await gesture.moveBy(const Offset(0, 20));
  await tester.pump();
  await gesture.moveBy(const Offset(0, 10));
  await tester.pump();
  return gesture;
}

/// A pointer id for a raw [TestPointer] that no other gesture of the run
/// takes: every gesture takes its id from one counter that runs across the
/// tests, so a fixed id meets a test's own gesture once a run brings the
/// counter to it. Creating a gesture that never goes down takes this id.
Future<int> _nextPointerId(WidgetTester tester) async {
  final pointer = tester.nextPointer;
  await tester.createGesture();
  return pointer;
}

/// Dispatches [event] as the test's own pointer source, with no frame.
void _sendPointer(WidgetTester tester, PointerEvent event) {
  tester.binding.handlePointerEventForSource(
    event,
    source: TestBindingEventSource.test,
  );
}

/// Whether a node labeled [label] sits in the live semantics tree, walked
/// from the root. `find.bySemanticsLabel` reads `RenderObject.debugSemantics`
/// instead, which keeps a stale node once its subtree stops rebuilding
/// (`ExcludeSemantics`), so it answers the landing frame only (FR-04 E05).
bool _liveSemanticsLabel(WidgetTester tester, String label) {
  var found = false;
  bool visit(SemanticsNode node) {
    if (node.label == label) found = true;
    node.visitChildren(visit);
    return true;
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return found;
}

/// Wraps [child] in a nested horizontal [ListView], one child wide, so the
/// moved or removed subtree holds its own semantics boundary (R1's base
/// case: a `RenderViewportBase` sets `isSemanticBoundary`).
Widget _nestedListBoundary(Widget child) => SizedBox(
  width: 40,
  height: 40,
  child: ListView(scrollDirection: Axis.horizontal, children: [child]),
);

/// Wraps [child] in its own semantics boundary with no nested scrollable.
Widget _semanticsContainerBoundary(Widget child) =>
    Semantics(container: true, child: child);

/// Wraps [child] in a tappable [StratumInkWell] that holds the whole item,
/// so the surface is item 100's root and joins the item's node, not its
/// own (s03 invariant 81).
Widget _inkWellBoundary(Widget child) =>
    StratumInkWell(onTap: () {}, child: child);

/// Wraps [child] in a tappable [StratumInkWell] beside a spacer, so the
/// surface does not hold the whole item and keeps its own container node
/// (s03 invariant 81).
Widget _innerInkWellBoundary(Widget child) => RowLayout(
  children: [
    const SizedBox(width: 4, height: 4),
    StratumInkWell(onTap: () {}, child: child),
  ],
);

/// The move labels the item-root pins count, in either axis.
const _moveLabels = {
  'Move to the start',
  'Move up',
  'Move down',
  'Move left',
  'Move right',
  'Move to the end',
};

/// What the item-root pins' row and delete taps ran, in order.
final _rootLog = <String>[];

/// Records a tap on the item-root pins' delete button.
void _tapDelete() => _rootLog.add('delete');

/// Whether R11's item 2 is disabled.
final _tileDisabled = ValueNotifier<bool>(true);

/// Whether a flip pin's sibling shows; reset in the item-root group's
/// `tearDown`.
final _extra = ValueNotifier<bool>(false);

/// Records a tap on the item-root flip pins' sibling.
void _tapExtra() => _rootLog.add('extra');

/// A `const` tap surface, the same instance across rebuilds, for a flip
/// pin's sibling test (R6c, R6c2).
Widget _constSurface() =>
    const StratumInkWell(onTap: _tapRow, child: Text('Item 2'));

/// A sibling beside [surface] that shows [extra] while [_extra] is true,
/// so a flip pin can join and split the item's root on the same item
/// (layout s03 invariant 81's one-frame window).
class _Sibling extends StatelessWidget {
  const new({required this.surface, this.extra = const Text('Extra')});

  /// Builds the item's root surface; a closure, not a widget, so a
  /// non-`const` caller (R6f) builds a fresh one on each rebuild.
  final Widget Function() surface;

  /// The sibling [surface] joins or splits from on each [_extra] flip.
  final Widget extra;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _extra,
    builder: (context, show, _) => ColumnLayout(
      mainAxisSize: MainAxisSize.min,
      children: [surface(), if (show) extra],
    ),
  );
}

/// [child], 300 by 600, in an app with an overlay, under the Stratum theme.
Widget _rootApp(Widget child) => MaterialApp(
  home: Material(
    child: themedHost(SizedBox(width: 300, height: 600, child: child)),
  ),
);

/// The move labels on [data], in [_moveLabels]'s words.
List<String> _rootMoves(SemanticsData data) => [
  for (final id in data.customSemanticsActionIds ?? const <int>[])
    if (_moveLabels.contains(CustomSemanticsAction.getAction(id)!.label))
      CustomSemanticsAction.getAction(id)!.label!,
];

/// [node] as one line, the spike's vocabulary.
String _shape(SemanticsNode node) {
  final data = node.getSemanticsData();
  return 'label=${data.label.replaceAll('\n', '|')} '
      'tap=${data.hasAction(SemanticsAction.tap)} '
      'button=${data.flagsCollection.isButton} '
      'enabled=${data.flagsCollection.isEnabled.name} '
      'moves=${_rootMoves(data).length}';
}

/// [text]'s own semantics node, the item-root pins' vocabulary.
SemanticsNode _rootNode(WidgetTester tester, String text) =>
    tester.getSemantics(find.text(text));

/// [text]'s own semantics node, walked from the live tree's root, the way
/// [_liveSemanticsLabel] does: [WidgetTester.getSemantics] climbs
/// `RenderObject.debugSemantics` instead, which still names a node a
/// config-only merge conflict (I1, `ui/semantics.dart:1633@3.47.7`) split
/// off a frame or more after the conflict clears and the live tree has
/// merged it back (final review M2's re-flag pin).
SemanticsNode _liveRootNode(WidgetTester tester, String text) {
  SemanticsNode? found;
  bool visit(SemanticsNode node) {
    if (node.label == text) found = node;
    node.visitChildren(visit);
    return true;
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return found ?? (throw StateError('No semantics node labeled "$text".'));
}

/// Runs the move action [label] names on [node].
void _rootMove(SemanticsNode node, String label) => node.owner!.performAction(
  node.id,
  SemanticsAction.customAction,
  CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
);

/// The item-root pins' list ids, in their current order.
List<int> _rootIds(WidgetTester tester) => _RootListState.ids;

/// R4's row for item [id]: its label and a delete button beside it.
Widget _row(int id) => RowLayout(
  children: [
    Text('Item $id'),
    StratumInkWell(onTap: _tapDelete, child: Text('Delete $id')),
  ],
);

/// Records a tap on the item-root pins' root row.
void _tapRow() => _rootLog.add('row');

/// What a joined root row's node reads: label, tap, button, enabled, and
/// the item's 4 move actions (s03/inv81).
const String _joined =
    'label=Item 2 tap=true button=true enabled=isTrue moves=4';

/// What a root row's own, still-split node reads, with none of the item's
/// moves: the target every D6 limit keeps split.
const String _own = 'label=Item 2 tap=true button=true enabled=isTrue moves=0';

/// Whether the run-time disable pin's root is disabled; reset in the
/// item-root group's `tearDown`.
final ValueNotifier<bool> _rowDisabled = ValueNotifier(false);

/// The label the run-time relabel pin sets; reset in the item-root
/// group's `tearDown`.
final ValueNotifier<String> _rowLabel = ValueNotifier('Item 2');

/// Pumps a five-item [_RootList] of [item], expects item 2's node to read
/// [expected] in the mount frame, and, when that node holds 4 moves,
/// "Move up" on it, settled, gives `_rootIds` `[0, 2, 1, 3, 4]`; when the
/// node, read again, holds a tap action, a tap on it, after clearing
/// `_rootLog`, leaves it `['row']`.
Future<void> _expectJoined(
  WidgetTester tester,
  Widget Function(int id) item, {
  String expected = _joined,
}) async {
  await tester.pumpWidget(_rootApp(_RootList(item: item)));
  expect(_shape(_rootNode(tester, 'Item 2')), expected);
  if (_rootMoves(_rootNode(tester, 'Item 2').getSemanticsData()).length == 4) {
    _rootMove(_rootNode(tester, 'Item 2'), 'Move up');
    await tester.pumpAndSettle();
    expect(_rootIds(tester), [0, 2, 1, 3, 4]);
  }
  final node = _rootNode(tester, 'Item 2');
  if (node.getSemanticsData().hasAction(SemanticsAction.tap)) {
    _rootLog.clear();
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(_rootLog, ['row']);
  }
}

/// Pumps a five-item [_RootList] of [item], then checks item 2's shape
/// [frames] after the frame of each change, past the one-frame window
/// (D6(e), Ruling 7): joined at mount, its own node once a sibling joins
/// (with the sibling's own node holding the item's moves), joined again
/// once the sibling leaves, then that "Move up" settles and its tap still
/// runs the row (the item-root flip pins, M1-T3).
Future<void> expectFlips(
  WidgetTester tester,
  Widget Function(int id) item, {
  int frames = 1,
}) async {
  Future<void> settle() async {
    for (var i = 0; i < frames; i += 1) {
      await tester.pump();
    }
  }

  await tester.pumpWidget(_rootApp(_RootList(item: item)));
  await settle();
  expect(_shape(_rootNode(tester, 'Item 2')), _joined, reason: 'mount');
  _extra.value = true;
  await tester.pump();
  await settle();
  expect(_shape(_rootNode(tester, 'Item 2')), _own, reason: 'sibling added');
  expect(
    _rootMoves(_rootNode(tester, 'Extra').getSemanticsData()),
    hasLength(4),
  );
  _extra.value = false;
  await tester.pump();
  await settle();
  expect(
    _shape(_rootNode(tester, 'Item 2')),
    _joined,
    reason: 'sibling removed',
  );
  _rootMove(_rootNode(tester, 'Item 2'), 'Move up');
  await tester.pumpAndSettle();
  expect(_rootIds(tester), [0, 2, 1, 3, 4]);
  final moved = _rootNode(tester, 'Item 2');
  _rootLog.clear();
  moved.owner!.performAction(moved.id, SemanticsAction.tap);
  expect(_rootLog, ['row']);
}

/// A reorderable list of five items the item-root pins reorder, each item
/// built by [item].
class _RootList extends StatefulWidget {
  const new({
    required this.item,
    this.scrollDirection = Axis.vertical,
    this.itemsController,
  });

  final Widget Function(int id) item;

  /// The list's scroll axis; horizontal names its moves left and right.
  final Axis scrollDirection;

  /// Drives the removal pin's `remove`; null for every other pin.
  final ReorderableItemsController? itemsController;

  @override
  State<_RootList> createState() => _RootListState();
}

class _RootListState extends State<_RootList> {
  /// The list's ids, in their current order; the item-root group's
  /// `tearDown` resets this to `[0, 1, 2, 3, 4]` after every test.
  static List<int> ids = [0, 1, 2, 3, 4];

  /// Removes `ids[index]` and tells [_RootList.itemsController] in the
  /// same turn (the removal pin, the leaving item's inactive marker).
  void remove(int index) {
    setState(() => ids.removeAt(index));
    widget.itemsController!.removeItem(index);
  }

  @override
  Widget build(BuildContext context) => ReorderableListViewLayout.builder(
    scrollDirection: widget.scrollDirection,
    itemCount: ids.length,
    itemsController: widget.itemsController,
    onReorderItem: (from, to) =>
        setState(() => ids.insert(to, ids.removeAt(from))),
    itemBuilder: (context, index) =>
        KeyedSubtree(key: ValueKey(ids[index]), child: widget.item(ids[index])),
  );
}

/// A test-only component on the FO-08 base, so a toggle on it pins R11b.
class _Tile extends StratumStatelessWidget {
  const new({required this.child, super.disabled});

  /// What the base wraps in its disabled look.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Records a tap on the I1 nested-list pin's inner row.
void _tapInner() => _rootLog.add('inner');

/// Which widget the M3 type-swap pin builds for item 2's root: 0 and 2 a
/// `StratumInkWell`, 1 a bare `Text`, so the swap forces an attach and
/// detach cycle rather than `updateRenderObject`; reset in the item-root
/// group's `tearDown`.
final ValueNotifier<int> _rootShape = ValueNotifier<int>(0);

void main() {
  void pointerTests() {
    testWidgets(
      'fo06/us11/fr01: every item finds one and the same list through '
      'SliverReorderableList.maybeOf, as an app drag handle does',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 3)));

        final lists = {
          for (final id in const [0, 1, 2])
            SliverReorderableList.maybeOf(
              tester.element(find.byKey(ValueKey(id))),
            ),
        };
        expect(lists, hasLength(1));
        expect(lists.single, isNotNull);
      },
    );

    testWidgets('a drag on a handle reorders', (tester) async {
      await tester.pumpWidget(
        _app(const _Harness(count: 5, handles: true, longPressDrag: false)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('handle 0'))),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).moves, [(0, 3)]);
      expect(_harness(tester).ids, [1, 2, 3, 0, 4]);
    });

    testWidgets('a long press anywhere on an item starts a drag', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Harness(count: 5)));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).moves, [(0, 3)]);
    });

    testWidgets('longPressDrag: false builds no delayed listener', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const _Harness(count: 3, longPressDrag: false)),
      );

      expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
    });

    testWidgets(
      "dragStyle reaches the lifted item and animates over the theme's "
      'fast level',
      (tester) async {
        const dragStyle = WidgetStyle(backgroundColor: _red);
        await tester.pumpWidget(
          _app(const _Harness(count: 5, dragStyle: dragStyle)),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await tester.pump();

        final lifted = tester.widget<AnimatedStyledBox>(
          find.byType(AnimatedStyledBox),
        );
        expect(lifted.style!.backgroundColor, _red);
        expect(
          lifted.style!.animationStyle?.duration,
          const Duration(milliseconds: 125),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final fill = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(AnimatedStyledBox),
            matching: find.byType(DecoratedBox),
          ),
        );
        final color = (fill.decoration as StyleDecoration).color!;
        expect(color.a, greaterThan(0));
        expect(color.a, lessThan(1));

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets("fo06/us11/fr01: the lift takes the theme's fast level", (
      tester,
    ) async {
      const dragStyle = WidgetStyle(backgroundColor: _red);
      await tester.pumpWidget(
        _app(
          const _Harness(count: 5, dragStyle: dragStyle),
          theme: motionTheme(),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox))
            .style!
            .animationStyle
            ?.duration,
        const Duration(milliseconds: 77),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('NFR-U03 and C1: under reduced motion the lift still fades '
        "over the theme's duration", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      const dragStyle = WidgetStyle(backgroundColor: _red);
      await tester.pumpWidget(
        _app(
          const _Harness(count: 5, dragStyle: dragStyle),
          theme: motionTheme(),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 38));

      final fill = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AnimatedStyledBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final color = (fill.decoration as StyleDecoration).color!;
      expect(color.a, greaterThan(0));
      expect(color.a, lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("dragStyle's own animationStyle times the lift", (
      tester,
    ) async {
      const dragStyle = WidgetStyle(
        backgroundColor: _red,
        animationStyle: AnimationStyle(duration: Duration(milliseconds: 300)),
      );
      await tester.pumpWidget(
        _app(const _Harness(count: 5, dragStyle: dragStyle)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await tester.pump();

      final lifted = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(
        lifted.style!.animationStyle?.duration,
        const Duration(milliseconds: 300),
      );
      // Past the fast level's 125 ms default, the 300 ms lift is still
      // under way.
      await tester.pump(const Duration(milliseconds: 150));
      final fill = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AnimatedStyledBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final color = (fill.decoration as StyleDecoration).color!;
      expect(color.a, greaterThan(0));
      expect(color.a, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('without dragStyle the lifted item is built as is', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Harness(count: 5)));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      expect(find.byType(AnimatedStyledBox), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a dragged item keeps its State through the drop', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Harness(count: 5)));
      final state = _itemState(tester, 0)..expanded = true;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).ids, [1, 2, 3, 0, 4]);
      expect(identical(_itemState(tester, 0), state), isTrue);
      expect(state.expanded, isTrue);
    });

    testWidgets('fo06/us11/fr03: a count change with no call during a drag ends the drag, '
        'the dragged item back in its slot with its State', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 5)));
      final state = _itemState(tester, 0)..expanded = true;
      final top = tester.getTopLeft(find.byKey(const ValueKey(0))).dy;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      // The dragged item stays in the data, so the frame that ends the
      // drag builds its key again while the lifted copy still holds it.
      _harness(tester).insertData(1, 9);
      await tester.pump();
      // The lifted copy still shows; the slot keeps the gap, not a copy.
      expect(find.text('0'), findsOneWidget);
      expect(_harness(tester).ends, [0]);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).starts, [0]);
      expect(_harness(tester).ends, [0]);
      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ids, [0, 9, 1, 2, 3, 4]);
      expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dy, top);
      expect(identical(_itemState(tester, 0), state), isTrue);
      expect(state.expanded, isTrue);
    });

    // Item 3 of the view, lifted by its center and held 10 px inside the
    // bottom edge at 0 px, or the top edge after a scroll to 800 px.
    final viewportEdges = ValueVariant<String>({'bottom edge', 'top edge'});
    testWidgets(
      'fo06/us11/fr01/e08: a drag held near a viewport edge scrolls the list '
      'toward that edge, farther under a larger autoScrollerVelocityScalar',
      (tester) async {
        final bottom = viewportEdges.currentValue == 'bottom edge';
        final start = bottom ? 0.0 : 800.0;

        // Pumps a fresh list at [start], holds the drag for 500 ms, and
        // returns how far the list scrolled toward the edge.
        Future<double> scrolledToward(double? scalar) async {
          final ids = [for (var i = 0; i < 50; i++) i];
          await tester.pumpWidget(
            _app(
              StatefulBuilder(
                builder: (context, setState) =>
                    ReorderableListViewLayout.builder(
                      key: ValueKey(scalar),
                      itemCount: ids.length,
                      autoScrollerVelocityScalar: scalar,
                      onReorderItem: (from, to) =>
                          setState(() => ids.insert(to, ids.removeAt(from))),
                      itemBuilder: (context, index) => _Item(
                        key: ValueKey(ids[index]),
                        id: ids[index],
                        index: index,
                      ),
                    ),
              ),
            ),
          );
          final position =
              tester.state<ScrollableState>(find.byType(Scrollable)).position
                ..jumpTo(start);
          await tester.pump();
          final view = tester.getRect(find.byType(Scrollable));
          final from = tester.getCenter(find.byKey(ValueKey(start ~/ 40 + 3)));
          final gesture = await tester.startGesture(from);
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 50),
          );
          // The lifted item, 40 px tall, passes the edge by 10 px.
          await gesture.moveTo(
            Offset(from.dx, bottom ? view.bottom - 10 : view.top + 10),
          );
          for (var i = 0; i < 50; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          final scrolled = bottom
              ? position.pixels - start
              : start - position.pixels;
          await gesture.up();
          await tester.pumpAndSettle();
          return scrolled;
        }

        // Flutter's default scalar, 50, then twice it.
        final base = await scrolledToward(null);
        final doubled = await scrolledToward(100);
        expect(base, greaterThan(0));
        expect(doubled, greaterThan(base));
      },
      variant: viewportEdges,
    );

    testWidgets('fo06/us11/fr01 and fo06/us11/fr04/e02 (R48): under a caller transition that pads '
        'each item, the drag gap takes the slot the lifted item fills, and the '
        'drop settles its image where the item lands', (tester) async {
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 5,
            handles: true,
            itemTransitionBuilder: (context, animation, child) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: child,
            ),
          ),
        ),
      );
      // Each slot is 60 px: the item's 40 px and the caller's padding.
      expect(_offsetBetween(tester, 0, 1), 60);
      final rest = _top(tester, 1);
      final gesture = await _grabHandle(tester, 0);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(_top(tester, 1), rest - 60);

      await gesture.up();
      await tester.pump();
      // The settle's last frame, over the theme's 200 ms normal level.
      await tester.pump(const Duration(milliseconds: 199));
      final image = tester.getTopLeft(find.byType(RawImage)).dy;
      await tester.pumpAndSettle();
      expect(
        image,
        moreOrLessEquals(tester.getTopLeft(find.text('0')).dy, epsilon: 1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('ReorderableListViewLayout pointer', pointerTests);

  group('ReorderableListViewLayout keys', () {
    for (final (axis, back, forth) in const [
      (Axis.vertical, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown),
      (
        Axis.horizontal,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ),
    ]) {
      testWidgets(
        'NFR-U09: $axis: Alt and the axis arrows, Home, and End move the '
        'focused item',
        (tester) async {
          await tester.pumpWidget(_app(_Harness(count: 4, axis: axis)));
          await _focusItem(tester, 1);

          expect(await _alt(tester, forth), isTrue);
          expect(_harness(tester).ids, [0, 2, 1, 3]);
          expect(await _alt(tester, back), isTrue);
          expect(_harness(tester).ids, [0, 1, 2, 3]);
          expect(await _alt(tester, LogicalKeyboardKey.end), isTrue);
          expect(_harness(tester).ids, [0, 2, 3, 1]);
          expect(await _alt(tester, LogicalKeyboardKey.home), isTrue);
          expect(_harness(tester).ids, [1, 0, 2, 3]);
          expect(_harness(tester).moves, [(1, 2), (2, 1), (1, 3), (3, 0)]);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }

    testWidgets('Alt+Left moves an item forward under right-to-left text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const _Harness(count: 3, axis: Axis.horizontal),
          textDirection: TextDirection.rtl,
        ),
      );
      await _focusItem(tester, 0);

      expect(await _alt(tester, LogicalKeyboardKey.arrowLeft), isTrue);
      expect(_harness(tester).ids, [1, 0, 2]);
      expect(await _alt(tester, LogicalKeyboardKey.arrowRight), isTrue);
      expect(_harness(tester).ids, [0, 1, 2]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'an arrow across the axis, and a list of one item, are not handled',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 3)));
        await _focusItem(tester, 0);

        expect(await _alt(tester, LogicalKeyboardKey.arrowLeft), isFalse);
        expect(_harness(tester).moves, isEmpty);

        await tester.pumpWidget(
          _app(const _Harness(key: Key('one'), count: 1)),
        );
        await _focusItem(tester, 0);
        expect(await _alt(tester, LogicalKeyboardKey.arrowDown), isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Alt+Left on the first item and Alt+Right on the last item of a '
      'horizontal list are handled and move nothing',
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 3, axis: Axis.horizontal)),
        );
        await _focusItem(tester, 0);
        expect(await _alt(tester, LogicalKeyboardKey.arrowLeft), isTrue);
        await _focusItem(tester, 2);
        expect(await _alt(tester, LogicalKeyboardKey.arrowRight), isTrue);

        expect(_harness(tester).moves, isEmpty);
      },
      variant: TargetPlatformVariant.all(),
    );

    testWidgets('Alt+Up on the first item and Alt+Down on the last item of a '
        'vertical list are handled and move nothing', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 3)));
      await _focusItem(tester, 0);
      expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isTrue);
      await _focusItem(tester, 2);
      expect(await _alt(tester, LogicalKeyboardKey.arrowDown), isTrue);

      expect(_harness(tester).moves, isEmpty);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Alt+Home on the first item and Alt+End on the last item are '
        'handled and move nothing', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 3)));
      await _focusItem(tester, 0);
      expect(await _alt(tester, LogicalKeyboardKey.home), isTrue);
      await _focusItem(tester, 2);
      expect(await _alt(tester, LogicalKeyboardKey.end), isTrue);

      expect(_harness(tester).moves, isEmpty);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Alt+Left in a horizontal list is handled, so a browser '
        'does not go back', (tester) async {
      await tester.pumpWidget(
        _app(const _Harness(count: 3, axis: Axis.horizontal)),
      );
      await _focusItem(tester, 1);

      // Flutter on the web calls preventDefault for a handled key.
      expect(await _alt(tester, LogicalKeyboardKey.arrowLeft), isTrue);
      expect(_harness(tester).ids, [1, 0, 2]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('reorder keys do nothing inside a TextField item', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Harness(count: 3, fieldAt: 1)));
      final field = await _focusItem(tester, 1);

      await _alt(tester, LogicalKeyboardKey.arrowUp);
      await _alt(tester, LogicalKeyboardKey.arrowDown);

      expect(_harness(tester).moves, isEmpty);
      expect(field.hasPrimaryFocus, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'after Alt+Up the moved item keeps its State and focus stays on the '
      'same node',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 4)));
        final state = _itemState(tester, 2)..expanded = true;
        final node = await _focusItem(tester, 2);

        await _alt(tester, LogicalKeyboardKey.arrowUp);

        expect(_harness(tester).ids, [0, 2, 1, 3]);
        expect(identical(_itemState(tester, 2), state), isTrue);
        expect(state.expanded, isTrue);
        expect(node.hasPrimaryFocus, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'NFR-U09: a "Move up" semantics action keeps the moved item\'s State',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(const _Harness(count: 4)));
        final state = _itemState(tester, 2)..expanded = true;

        final node = tester.getSemantics(find.byKey(const ValueKey(2)));
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            const CustomSemanticsAction(label: 'Move up'),
          ),
        );
        await tester.pumpAndSettle();

        expect(_harness(tester).ids, [0, 2, 1, 3]);
        expect(identical(_itemState(tester, 2), state), isTrue);
        expect(state.expanded, isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'a "Move to the end" semantics action in a lazy list of 200 keeps '
      "the moved item's State and shows it",
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(const _Harness(count: 200)));
        final state = _itemState(tester, 0)..expanded = true;

        await _moveAction(tester, 0, 'Move to the end');

        expect(_harness(tester).ids.last, 0);
        expect(identical(_itemState(tester, 0), state), isTrue);
        expect(state.expanded, isTrue);
        expect(_itemInView(tester, 0), isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'a "Move to the start" semantics action in a lazy list of 200 keeps '
      "the moved item's State and shows it",
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(const _Harness(count: 200)));
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final state = _itemState(tester, 199)..expanded = true;

        await _moveAction(tester, 199, 'Move to the start');

        expect(_harness(tester).ids.first, 199);
        expect(identical(_itemState(tester, 199), state), isTrue);
        expect(state.expanded, isTrue);
        expect(_itemInView(tester, 199), isTrue);
        handle.dispose();
      },
    );

    testWidgets('a "Move down" semantics action reveals the moved item', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _Harness(count: 20)));
      // Item 6 fills 240 to 280 of the 300 px viewport; slot 7 runs past it.
      expect(_itemInView(tester, 6), isTrue);

      await _moveAction(tester, 6, 'Move down');

      expect(_harness(tester).ids.indexOf(6), 7);
      expect(_itemInView(tester, 6), isTrue);
      handle.dispose();
    });

    testWidgets(
      'Alt+Right reveals the moved item by the edge of each viewport: the '
      'end of the list and the start of the page',
      (tester) async {
        final page = ScrollController();
        addTearDown(page.dispose);
        // Ten 40 px items in a 200 px horizontal list at 300 to 340 of a
        // vertical page, between two 300 px fillers.
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              controller: page,
              child: const Column(
                children: [
                  SizedBox(height: 300),
                  SizedBox(
                    width: 200,
                    height: 40,
                    child: _Harness(count: 10, axis: Axis.horizontal),
                  ),
                  SizedBox(height: 300),
                ],
              ),
            ),
          ),
        );
        // Item 4 fills the list's last 40 px; the page shows 320 to 620,
        // so the list extends past the page's top.
        page.jumpTo(320);
        await tester.pump();
        await _focusItem(tester, 4);

        await _alt(tester, LogicalKeyboardKey.arrowRight);

        expect(_harness(tester).ids.indexOf(4), 5);
        final list = tester.getRect(
          find.descendant(
            of: find.byType(ReorderableListViewLayout),
            matching: find.byType(Scrollable),
          ),
        );
        final item = tester.getRect(find.byKey(const ValueKey(4)));
        expect(list.intersect(item), item);
        expect(page.offset, 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Alt+End moves an item to the end of a lazy list of 200 and keeps its '
      'focus in view',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 200)));
        final state = _itemState(tester, 0);
        final node = await _focusItem(tester, 0);

        await _alt(tester, LogicalKeyboardKey.end);

        expect(_harness(tester).ids.last, 0);
        expect(identical(_itemState(tester, 0), state), isTrue);
        expect(node.hasPrimaryFocus, isTrue);
        expect(find.text('0'), findsOneWidget);
        await _alt(tester, LogicalKeyboardKey.home);
        expect(_harness(tester).ids.first, 0);
        expect(node.hasPrimaryFocus, isTrue);
        expect(find.text('0'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('(pin) every item carries the four move actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _Harness(count: 3)));

      expect(
        tester.getSemantics(find.byKey(const ValueKey(1))),
        isSemantics(
          customActions: const [
            CustomSemanticsAction(label: 'Move to the start'),
            CustomSemanticsAction(label: 'Move up'),
            CustomSemanticsAction(label: 'Move down'),
            CustomSemanticsAction(label: 'Move to the end'),
          ],
        ),
      );
      handle.dispose();
    });

    testWidgets('the list is a Tab stop whose arrows scroll it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Harness(count: 50)));
      await _focusItem(tester, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ScrollFocus');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, 50);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  void insertAndRemoveTests() {
    testWidgets(
      'fo06/us11/fr04/e07: an out-of-range index fails a debug assert',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 3, itemsController: controller)),
        );

        expect(() => controller.insertItem(4), throwsAssertionError);
        expect(() => controller.insertItem(-1), throwsAssertionError);
        expect(() => controller.removeItem(3), throwsAssertionError);
        expect(() => controller.removeItem(-1), throwsAssertionError);
        await tester.pump();
        expect(_harness(tester).ids, [0, 1, 2]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e08: one controller on two lists at once fails a debug '
      'assert',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                Expanded(
                  child: _Harness(count: 2, itemsController: controller),
                ),
                Expanded(
                  child: _Harness(count: 2, itemsController: controller),
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isAssertionError);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e09: a call on a controller attached to no list fails a '
      'debug assert',
      (tester) async {
        final controller = ReorderableItemsController();
        expect(() => controller.insertItem(0), throwsAssertionError);
        expect(() => controller.removeItem(0), throwsAssertionError);

        await tester.pumpWidget(
          _app(_Harness(count: 2, itemsController: controller)),
        );
        await tester.pumpWidget(_app(const SizedBox()));

        expect(() => controller.insertItem(0), throwsAssertionError);
      },
    );

    testWidgets('fo06/us11/fr04/e09: a controller handed to another list detaches from the '
        'first', (tester) async {
      final first = ReorderableItemsController();
      final second = ReorderableItemsController();
      await tester.pumpWidget(_app(_Harness(count: 3, itemsController: first)));
      await tester.pumpWidget(
        _app(_Harness(count: 3, itemsController: second)),
      );

      expect(() => first.insertItem(0), throwsAssertionError);
      _harness(tester).insert(0, 9);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids, [9, 0, 1, 2]);
    });

    testWidgets(
      'fo06/us11/fr04/e10: without an itemsController an added item shows at once',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 3)));

        _harness(tester).insertData(1, 9);
        await tester.pump();

        expect(_offsetBetween(tester, 0, 1), 80);
        // R48: at rest every item sits inside a completed transition.
        expect(_runningTransitions(tester), isEmpty);
      },
    );

    testWidgets(
      'fo06/us11/s8: an added item grows into its slot and fades in over the '
      'normal level',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(count: 3, itemsController: controller),
            theme: _normalTheme(const Duration(milliseconds: 250)),
          ),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).insert(1, 9);
        await tester.pump();
        expect(_offsetBetween(tester, 0, 1), 40);
        expect(_opacity(tester, 9), 0);

        await tester.pump(const Duration(milliseconds: 125));
        expect(_offsetBetween(tester, 0, 1), moreOrLessEquals(40 + 40 * mid));
        expect(_opacity(tester, 9), moreOrLessEquals(mid));

        await tester.pump(const Duration(milliseconds: 125));
        expect(_offsetBetween(tester, 0, 1), 80);
        await tester.pumpAndSettle();
        // R48: at rest every item sits inside a completed transition.
        expect(_runningTransitions(tester), isEmpty);
      },
    );

    testWidgets(
      'fo06/us11/s9: a removed item shrinks and fades out while its gap closes',
      (tester) async {
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller), theme: theme),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).remove(2);
        await tester.pump();
        expect(_offsetBetween(tester, 1, 3), 80);
        expect(_opacity(tester, 2), 1);

        await tester.pump(_halfReverse(theme));
        expect(_offsetBetween(tester, 1, 3), moreOrLessEquals(40 + 40 * mid));
        expect(_opacity(tester, 2), moreOrLessEquals(mid));

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey(2)), findsNothing);
        expect(_offsetBetween(tester, 1, 3), 40);
        expect(_harness(tester).ids, [0, 1, 3, 4]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e15: an insert or a remove the app defers from inside a '
      'build to after the frame animates as calls made outside',
      (tester) async {
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        final mid = Curves.easeInOutSine.transform(0.5);
        // Which deferred call the next build schedules: the insert from the
        // first build, the remove once the test asks for it after the
        // insert has settled (E15).
        var deferredInsert = false;
        var deferredRemove = false;
        Widget buildApp() => _app(
          _Harness(
            count: 3,
            itemsController: controller,
            onItemBuild: (context) {
              if (!deferredInsert) {
                deferredInsert = true;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _harness(tester).insert(1, 9),
                );
              } else if (deferredRemove) {
                deferredRemove = false;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _harness(tester).remove(2),
                );
              }
            },
          ),
          theme: theme,
        );
        await tester.pumpWidget(buildApp());

        // The deferred insert ran after the first frame, with its data
        // change, and then grew and faded in as an outside call does.
        await tester.pump();
        expect(_offsetBetween(tester, 0, 1), 40);
        expect(_opacity(tester, 9), 0);

        await tester.pump(const Duration(milliseconds: 125));
        expect(_offsetBetween(tester, 0, 1), moreOrLessEquals(40 + 40 * mid));
        expect(_opacity(tester, 9), moreOrLessEquals(mid));

        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [0, 9, 1, 2]);

        // A later build defers a remove the same way; ids now hold
        // [0, 9, 1, 2], so index 2 is item 1, between items 9 and 2.
        deferredRemove = true;
        await tester.pumpWidget(buildApp());
        await tester.pump();
        expect(_offsetBetween(tester, 9, 2), 80);
        expect(_opacity(tester, 1), 1);

        await tester.pump(_halfReverse(theme));
        expect(_offsetBetween(tester, 9, 2), moreOrLessEquals(40 + 40 * mid));
        expect(_opacity(tester, 1), moreOrLessEquals(mid));

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey(1)), findsNothing);
        expect(_offsetBetween(tester, 9, 2), 40);
        expect(_harness(tester).ids, [0, 9, 2]);
      },
    );

    testWidgets(
      "fo06/us11/fr04: insert and remove take the theme's normal level",
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 3, itemsController: controller)),
        );

        _harness(tester).insert(1, 9);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 199));
        expect(_opacity(tester, 9), lessThan(1));
        await tester.pump(const Duration(milliseconds: 1));
        expect(_opacity(tester, 9), 1);
        await tester.pumpAndSettle();

        _harness(tester).remove(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 127));
        expect(_opacity(tester, 9), greaterThan(0));
        await tester.pump(const Duration(milliseconds: 1));
        expect(_opacity(tester, 9), 0);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'fo06/us11/fr04/e03: a removed item keeps the look and State it had at '
      'removeItem',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final state = _itemState(tester, 2)..expanded = true;

        _harness(tester).remove(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('2'), findsOneWidget);
        expect(identical(_itemState(tester, 2), state), isTrue);
        expect(state.expanded, isTrue);
        await tester.pumpAndSettle();
        expect(find.text('2'), findsNothing);
      },
    );

    testWidgets('fo06/us11/fr04/e03: a removeItem builder replaces the look', (
      tester,
    ) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );

      _harness(tester).remove(
        2,
        builder: (context) => const SizedBox(
          key: ValueKey('gone'),
          height: 40,
          child: Text('gone'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('gone'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('gone'), findsNothing);
    });

    testWidgets('fo06/us11/fr04: adding back the key of a leaving item ends its old copy at '
        'once, and the new item takes the State', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final state = _itemState(tester, 2);

      _harness(tester).remove(2);
      await tester.pump();
      _harness(tester).insert(0, 2);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('2', skipOffstage: false), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(_harness(tester).ids, [2, 0, 1, 3, 4]);
      expect(identical(_itemState(tester, 2), state), isTrue);
    });

    testWidgets(
      'fo06/us11/fr04: a list unmounted mid-animation leaves no running ticker',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester)
          ..insert(0, 9)
          ..remove(3);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(_app(const SizedBox()));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e12: a count change with no call ends the running '
      'animations and shows the data at once',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester).remove(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('2'), findsOneWidget);

        _harness(tester).insertData(0, 9);
        await tester.pump();
        expect(find.text('2'), findsNothing);
        expect(_offsetBetween(tester, 9, 0), 40);
        // R48: at rest every item sits inside a completed transition.
        expect(_runningTransitions(tester), isEmpty);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('fo06/us11/fr04/e05: calls in one turn take indices of the data the calls '
        'before them left', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );

      _harness(tester)
        ..remove(1)
        ..remove(2)
        ..insert(0, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(_harness(tester).ids, [9, 0, 2, 4]);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('fo06/us11/fr04: removing an item still growing in shrinks it from where it '
        'stands', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(_Harness(count: 3, itemsController: controller), theme: theme),
      );
      final mid = Curves.easeInOutSine.transform(0.5);

      _harness(tester).insert(1, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      final grown = _offsetBetween(tester, 0, 1) - 40;
      expect(grown, moreOrLessEquals(40 * mid));

      _harness(tester).remove(1);
      await tester.pump();
      expect(_offsetBetween(tester, 0, 1) - 40, moreOrLessEquals(grown));
      await tester.pump(_halfReverse(theme));
      expect(_offsetBetween(tester, 0, 1), 40);
      await tester.pumpAndSettle();
      expect(find.text('9'), findsNothing);
    });

    testWidgets(
      'fo06/us11/fr04: the last item left in a list shrinks out too',
      (tester) async {
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(_Harness(count: 1, itemsController: controller), theme: theme),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).remove(0);
        await tester.pump();
        expect(_sizeBox(tester, 0).size.height, 40);
        await tester.pump(_halfReverse(theme));
        expect(find.text('0'), findsOneWidget);
        expect(_sizeBox(tester, 0).size.height, moreOrLessEquals(40 * mid));

        await tester.pumpAndSettle();
        expect(find.text('0'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'fo06/us11/fr04: a horizontal list shrinks a removed item along its width',
      (tester) async {
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 4,
              axis: Axis.horizontal,
              itemsController: controller,
            ),
            theme: theme,
          ),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).remove(1);
        await tester.pump();
        await tester.pump(_halfReverse(theme));

        final left = tester.getTopLeft(find.byKey(const ValueKey(0))).dx;
        final right = tester.getTopLeft(find.byKey(const ValueKey(2))).dx;
        expect(right - left, moreOrLessEquals(40 + 40 * mid));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'fo06/us11/fr04: items removed bottom-up in two turns leave in list order',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester).remove(2);
        await tester.pump();
        _harness(tester).remove(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(_offsetBetween(tester, 1, 2), greaterThan(0));
        expect(_offsetBetween(tester, 2, 3), greaterThan(0));
        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [0, 3, 4]);
      },
    );

    testWidgets(
      'fo06/us11/fr04: items removed bottom-up in one turn leave in list order',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester)
          ..remove(2)
          ..remove(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(_offsetBetween(tester, 1, 2), greaterThan(0));
        expect(_offsetBetween(tester, 2, 3), greaterThan(0));
        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [0, 3, 4]);
      },
    );

    testWidgets(
      "fo06/us11/fr04: an item added at a leaving item's gap in a later turn "
      'lands after it',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester).remove(2);
        await tester.pump();
        _harness(tester).insert(2, 9);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(_offsetBetween(tester, 2, 9), greaterThan(0));
        expect(_offsetBetween(tester, 9, 3), greaterThan(0));
        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [0, 1, 9, 3, 4]);
      },
    );

    testWidgets(
      'fo06/us11/fr04: adding back a GlobalKey item while its old copy leaves '
      'raises no duplicate key',
      (tester) async {
        final controller = ReorderableItemsController();
        final keys = [
          for (var id = 0; id < 3; id++) GlobalKey(debugLabel: 'item $id'),
        ];
        final ids = [0, 1, 2];
        late StateSetter setIds;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                setIds = setState;
                return ReorderableListViewLayout.builder(
                  itemCount: ids.length,
                  itemsController: controller,
                  onReorderItem: (from, to) {},
                  itemBuilder: (context, index) => SizedBox(
                    key: keys[ids[index]],
                    height: 40,
                    child: Text('${ids[index]}'),
                  ),
                );
              },
            ),
          ),
        );

        setIds(() => ids.removeAt(1));
        controller.removeItem(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        setIds(() => ids.insert(0, 1));
        controller.insertItem(0);
        await tester.pump();

        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets("NFR-U03 and fo06/us11/s10: under the app's reduced motion the gap closes "
        'at once and the removed item fades out', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: _Harness(count: 5, itemsController: controller),
            ),
          ),
          theme: theme,
        ),
      );
      final mid = Curves.easeInOutSine.transform(0.5);

      _harness(tester).remove(2);
      await tester.pump();
      expect(_offsetBetween(tester, 1, 3), 40);
      await tester.pump(_halfReverse(theme));
      expect(_offsetBetween(tester, 1, 3), 40);
      expect(_opacity(tester, 2), moreOrLessEquals(mid));

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(2)), findsNothing);
    });

    testWidgets(
      "NFR-U03 and fo06/us11/fr04/e01: under the platform's reduced motion an "
      'added item takes its size at once and fades in',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(count: 3, itemsController: controller),
            theme: _normalTheme(const Duration(milliseconds: 250)),
          ),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).insert(1, 9);
        await tester.pump();
        expect(_offsetBetween(tester, 0, 1), 80);
        expect(_opacity(tester, 9), 0);
        await tester.pump(const Duration(milliseconds: 125));
        expect(_opacity(tester, 9), moreOrLessEquals(mid));

        await tester.pumpAndSettle();
      },
    );

    testWidgets('fo06/us11/fr04/e02: an itemTransitionBuilder replaces the size and fade on '
        'insert and remove', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      Animation<double>? received;
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 3,
            itemsController: controller,
            itemTransitionBuilder: (context, animation, child) {
              // R48: the builder wraps every item, at rest with a
              // completed animation; the entering or leaving one runs.
              if (animation != kAlwaysCompleteAnimation) received = animation;
              return ScaleTransition(scale: animation, child: child);
            },
          ),
          theme: theme,
        ),
      );
      final mid = Curves.easeInOutSine.transform(0.5);
      // A subtype counts: the built-in fade is one of FadeTransition.
      Finder inList<T extends Widget>() => find.descendant(
        of: _reorderSliver(),
        matching: find.byWidgetPredicate((widget) => widget is T),
      );
      // The caller's own transition around the item that moves (R48).
      final running = find.descendant(
        of: _reorderSliver(),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ScaleTransition &&
              widget.scale != kAlwaysCompleteAnimation,
        ),
      );
      // The extent of the box around the caller's transition: no size of
      // the list's own grows or shrinks the item inside it.
      double callerBox() =>
          (tester.renderObject(running).parent! as RenderBox).size.height;

      _harness(tester).insert(1, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      expect(running, findsOneWidget);
      expect(inList<FadeTransition>(), findsNothing);
      expect(callerBox(), 40);
      expect(_offsetBetween(tester, 0, 1), 80);
      expect(received!.value, moreOrLessEquals(mid));
      await tester.pumpAndSettle();

      _harness(tester).remove(1);
      await tester.pump();
      expect(received!.value, 1);
      await tester.pump(_halfReverse(theme));
      expect(running, findsOneWidget);
      expect(callerBox(), 40);
      expect(received!.value, moreOrLessEquals(mid));
      await tester.pumpAndSettle();
    });

    testWidgets('fo06/us11/fr04/e02: under reduced motion an itemTransitionBuilder gets the '
        'animation unchanged', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final controller = ReorderableItemsController();
      Animation<double>? received;
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 3,
            itemsController: controller,
            itemTransitionBuilder: (context, animation, child) {
              // R48: the builder wraps every item, at rest with a
              // completed animation; the entering or leaving one runs.
              if (animation != kAlwaysCompleteAnimation) received = animation;
              return SizeTransition(sizeFactor: animation, child: child);
            },
          ),
          theme: _normalTheme(const Duration(milliseconds: 250)),
        ),
      );
      final mid = Curves.easeInOutSine.transform(0.5);

      _harness(tester).insert(1, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      expect(received!.value, moreOrLessEquals(mid));
      expect(_offsetBetween(tester, 0, 1), moreOrLessEquals(40 + 40 * mid));
      await tester.pumpAndSettle();
    });

    testWidgets('fo06/us11/fr04/e11: with a fixed item extent the size jumps and the fade '
        'plays', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(
          _Harness(count: 5, itemsController: controller, itemExtent: 40),
          theme: theme,
        ),
      );
      final mid = Curves.easeInOutSine.transform(0.5);

      _harness(tester).remove(2);
      await tester.pump();
      await tester.pump(_halfReverse(theme));
      expect(tester.takeException(), isNull);
      expect(_offsetBetween(tester, 1, 3), 40);
      expect(_opacity(tester, 2), moreOrLessEquals(mid));
      await tester.pumpAndSettle();

      _harness(tester).insert(1, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      expect(_offsetBetween(tester, 0, 1), 80);
      expect(_opacity(tester, 9), moreOrLessEquals(mid));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'fo06/us11/fr04/e01: under reduced motion a removed item paints over the '
      'item that takes its place, and a removed last item just past it',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        final painted = <int>[];
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: controller, paintLog: painted),
          ),
        );

        _harness(tester)
          ..remove(2)
          ..remove(3);
        painted.clear();
        await tester.pump();

        // Each item composites in its own repaint boundary (R49), so the
        // order of their layers is the paint order.
        expect(_compositeOrder(tester, [2, 3, 4]), [3, 2, 4]);
        final host = tester.getRect(find.byKey(const ValueKey(3)));
        expect(tester.getRect(find.byKey(const ValueKey(2))), host);
        expect(
          tester.getRect(find.byKey(const ValueKey(4))),
          host.translate(0, 40),
        );
        expect(_offsetBetween(tester, 1, 3), 40);
        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [0, 1, 3]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e01: in a reversed list under reduced motion a removed item '
      "lies over its host from the host's edge nearest index 0",
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller, reverse: true)),
        );

        _harness(tester).remove(
          2,
          builder: (context) => const SizedBox(
            key: ValueKey('gone'),
            height: 20,
            child: Text('gone'),
          ),
        );
        await tester.pump();

        final host = tester.getRect(find.byKey(const ValueKey(3)));
        final gone = tester.getRect(find.byKey(const ValueKey('gone')));
        expect(gone.bottom, host.bottom);
        expect(gone.height, 20);
        expect(_offsetBetween(tester, 3, 1), 40);
        await tester.pumpAndSettle();
        expect(find.text('gone'), findsNothing);
      },
    );

    testWidgets('fo06/us11/fr04/e11: with a fixed item extent a removed last item leaves at '
        'once and a quick insert never shows it again', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(
          _Harness(count: 5, itemsController: controller, itemExtent: 40),
          theme: _normalTheme(const Duration(milliseconds: 250)),
        ),
      );
      final four = find.byKey(const ValueKey(4), skipOffstage: false);

      _harness(tester).remove(4);
      await tester.pump();
      expect(four, findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      _harness(tester).insert(4, 9);
      await tester.pump();
      expect(four, findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      expect(four, findsNothing);

      await tester.pumpAndSettle();
      expect(four, findsNothing);
      expect(_harness(tester).ids, [0, 1, 2, 3, 9]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'fo06/us11/fr04/e11: with a fixed item extent a removed item takes no room '
      'under a caller transition, along a horizontal list too',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 4,
              axis: Axis.horizontal,
              itemsController: controller,
              itemExtent: 40,
              itemTransitionBuilder: (context, animation, child) =>
                  ScaleTransition(scale: animation, child: child),
            ),
          ),
        );

        _harness(tester).remove(1);
        await tester.pump();

        final host = tester.getRect(find.byKey(const ValueKey(2)));
        final left = tester.getTopLeft(find.byKey(const ValueKey(0))).dx;
        expect(host.left - left, 40);
        expect(tester.getRect(find.byKey(const ValueKey(1))), host);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey(1)), findsNothing);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e11: with a fixed item extent a removed item lays out at '
      'the extent of the slot it fills',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              itemsController: controller,
              itemExtent: 56,
              fillItems: true,
            ),
          ),
        );

        _harness(tester).remove(2);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final host = tester.getRect(find.byKey(const ValueKey(3)));
        expect(host.height, 56);
        expect(tester.getRect(find.byKey(const ValueKey(2))), host);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey(2)), findsNothing);
      },
    );

    final fixedBy = ValueVariant<String>({
      'itemExtentBuilder',
      'prototypeItem',
    });
    testWidgets('fo06/us11/fr04/e11: itemExtentBuilder and prototypeItem fix the extent as '
        'itemExtent does', (tester) async {
      final byBuilder = fixedBy.currentValue == 'itemExtentBuilder';
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 5,
            itemsController: controller,
            itemExtentBuilder: byBuilder ? (index, dimensions) => 56 : null,
            prototypeItem: byBuilder ? null : const SizedBox(height: 56),
            fillItems: true,
          ),
          theme: theme,
        ),
      );
      final mid = Curves.easeInOutSine.transform(0.5);

      _harness(tester).remove(2);
      await tester.pump();
      await tester.pump(_halfReverse(theme));

      expect(tester.takeException(), isNull);
      expect(_offsetBetween(tester, 1, 3), 56);
      expect(
        tester.getRect(find.byKey(const ValueKey(2))),
        tester.getRect(find.byKey(const ValueKey(3))),
      );
      expect(_opacity(tester, 2), moreOrLessEquals(mid));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(2)), findsNothing);
    }, variant: fixedBy);

    testWidgets(
      'fo06/us11/fr04/e02: under reduced motion a removed item keeps its room '
      'under a caller transition, which gets the animation unchanged',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        Animation<double>? received;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 3,
              itemsController: controller,
              itemTransitionBuilder: (context, animation, child) {
                // R48: the builder wraps every item, at rest with a
                // completed animation; the entering or leaving one runs.
                if (animation != kAlwaysCompleteAnimation) received = animation;
                return SizeTransition(sizeFactor: animation, child: child);
              },
            ),
            theme: theme,
          ),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).remove(1);
        await tester.pump();
        expect(received!.value, 1);
        expect(_offsetBetween(tester, 0, 2), 80);
        await tester.pump(_halfReverse(theme));

        expect(received!.value, moreOrLessEquals(mid));
        expect(_offsetBetween(tester, 0, 2), moreOrLessEquals(40 + 40 * mid));
        await tester.pumpAndSettle();
        expect(_offsetBetween(tester, 0, 2), 40);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e05: a leaving item takes no pointer and starts no drag',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              handles: true,
              longPressDrag: false,
              itemsController: controller,
            ),
            theme: _normalTheme(const Duration(seconds: 2)),
          ),
        );

        _harness(tester).remove(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(const ValueKey('handle 2')).hitTestable(),
          findsNothing,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('handle 2'))),
        );
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_harness(tester).starts, isEmpty);
        expect(_harness(tester).moves, isEmpty);
      },
    );

    testWidgets('fo06/us11/fr04/e05: a leaving item takes no focus and has no screen-reader '
        'node from its first frame', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(
          _Harness(count: 5, itemsController: controller),
          theme: _normalTheme(const Duration(seconds: 2)),
        ),
      );
      expect(find.bySemanticsLabel('2'), findsOneWidget);

      _harness(tester).remove(2);
      await tester.pump();
      // The removeItem frame: the leaving item keeps its own sliver child
      // (R47), so no subtree moves and no landing frame is needed.
      expect(_liveSemanticsLabel(tester, '2'), isFalse);
      await tester.pump(const Duration(milliseconds: 16));
      // `find.bySemanticsLabel` would still match here: it reads a
      // RenderObject's own cached node, which a subtree that stops
      // rebuilding never refreshes. The live tree is the live answer.
      expect(_liveSemanticsLabel(tester, '2'), isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      final node = _itemState(tester, 2).node..requestFocus();
      await tester.pump();

      expect(node.hasFocus, isFalse);
      expect(find.text('2'), findsOneWidget);
      expect(_liveSemanticsLabel(tester, '2'), isFalse);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr04/e05: removeItem and a reorder key skip a leaving item',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: controller),
            theme: _normalTheme(const Duration(seconds: 2)),
          ),
        );

        _harness(tester).remove(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        _harness(tester).remove(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(_harness(tester).ids, [0, 3, 4]);

        await _focusItem(tester, 0);
        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(_harness(tester).moves, [(0, 1)]);
        expect(_harness(tester).ids, [3, 0, 4]);
      },
    );

    testWidgets('fo06/us11/s11: focus on a removed item moves to the first control of the '
        'item after it', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      await _focusItem(tester, 2);

      _harness(tester).remove(2);
      await tester.pumpAndSettle();

      expect(_itemState(tester, 3).node.hasPrimaryFocus, isTrue);
    });

    testWidgets(
      'fo06/us11/fr04/e04: with no item after it, focus moves to the item before',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        await _focusItem(tester, 4);

        _harness(tester).remove(4);
        await tester.pumpAndSettle();

        expect(_itemState(tester, 3).node.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets("fo06/us11/fr04/e04: with no other item, focus moves to the list's own Tab "
        'stop', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 1, itemsController: controller, focusable: true)),
      );
      await _focusItem(tester, 0);

      _harness(tester).remove(0);
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ScrollFocus');
    });

    testWidgets('fo06/us11/fr04/e04: the item that takes focus from a removed item shows on '
        'screen', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller)),
      );
      // Item 7 runs from 280 to 320 of the 300 px viewport; item 8 lies
      // below it, off screen but built in the cache extent.
      await _focusItem(tester, 7);
      expect(find.byKey(const ValueKey(8)), findsNothing);

      _harness(tester).remove(7);
      await tester.pumpAndSettle();

      expect(_itemState(tester, 8).node.hasPrimaryFocus, isTrue);
      expect(_itemInView(tester, 8), isTrue);
    });

    testWidgets('fo06/us11/fr04/e05: a tap on a fixed-extent slot reaches the item under a '
        'leaving item, past the caller transition', (tester) async {
      final controller = ReorderableItemsController();
      var transitionTaps = 0;
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 5,
            itemsController: controller,
            itemExtent: 40,
            itemTransitionBuilder: (context, animation, child) =>
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // R48: the caller wraps the host too; count the leaving
                  // item's wrapper only.
                  onTap: () {
                    if (animation != kAlwaysCompleteAnimation) {
                      transitionTaps += 1;
                    }
                  },
                  child: FadeTransition(opacity: animation, child: child),
                ),
          ),
          theme: _normalTheme(const Duration(seconds: 2)),
        ),
      );
      final host = find.byKey(const ValueKey(3));

      _harness(tester).remove(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey(2))),
        tester.getRect(host),
      );
      await tester.tapAt(tester.getCenter(host));
      await tester.pump();

      expect(transitionTaps, 0);
      expect(host.hitTestable(), findsOneWidget);
      await tester.pumpAndSettle();
    });

    // A second call in the turn that removes focused item 3, and the id of
    // the item that takes focus after it.
    const takesFocus = {
      'remove before': 4,
      'insert before': 4,
      'remove at the gap': 5,
      'insert at the gap': 9,
    };
    final secondCall = ValueVariant<String>(takesFocus.keys.toSet());
    testWidgets(
      'fo06/us11/fr04/e04: focus goes to the item after a removed one as the '
      'later calls of the same turn leave it',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 6, itemsController: controller)),
        );
        await _focusItem(tester, 3);

        _harness(tester).remove(3);
        switch (secondCall.currentValue) {
          case 'remove before':
            _harness(tester).remove(0);
          case 'insert before':
            _harness(tester).insert(0, 9);
          case 'remove at the gap':
            _harness(tester).remove(3);
          case 'insert at the gap':
            _harness(tester).insert(3, 9);
        }
        await tester.pumpAndSettle();

        final id = takesFocus[secondCall.currentValue]!;
        expect(_itemState(tester, id).node.hasPrimaryFocus, isTrue);
      },
      variant: secondCall,
    );

    testWidgets('fo06/us11/s12: a removal during a drag ends the drag with the dragged item '
        'back in its slot', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final top = tester.getTopLeft(find.byKey(const ValueKey(0))).dy;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(_harness(tester).starts, [0]);

      _harness(tester).remove(3);
      expect(_harness(tester).ends, [0]);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ends, [0]);
      expect(_harness(tester).ids, [0, 1, 2, 4]);
      expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dy, top);
    });

    testWidgets(
      'fo06/us11/fr04/e06: an insert during a drag ends the drag first',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();

        _harness(tester).insert(1, 9);
        expect(_harness(tester).ends, [0]);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ends, [0]);
        expect(_harness(tester).ids, [0, 9, 1, 2, 3, 4]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e06: a drag its gesture canceled fires one onReorderEnd, '
      'and none at a later removal',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(_harness(tester).starts, [0]);
        expect(_harness(tester).ends, [0]);

        _harness(tester).remove(3);
        await tester.pumpAndSettle();

        expect(_harness(tester).ends, [0]);
        expect(_harness(tester).ids, [0, 1, 2, 4]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e06: a count change with no call ends a drag with one '
      'onReorderEnd, and a removal while the pointer stays down fires none',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        // The app drops the dragged item with no call: the SDK cancels the
        // drag on the count change, and the list reports its end.
        _harness(tester).removeData(0);
        await tester.pump();
        expect(_harness(tester).starts, [0]);
        expect(_harness(tester).ends, [0]);

        _harness(tester).remove(2);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_harness(tester).ends, [0]);
        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ids, [1, 2, 4]);
      },
    );

    testWidgets('fo06/us11/fr04/e06: a removal while a dropped item settles ends the drop '
        'with no onReorderItem and no second onReorderEnd', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 100));
      // The lift and the drop's settle each run over the theme's 200 ms
      // normal level.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      final ends = [..._harness(tester).ends];
      expect(ends, hasLength(1));
      // 50 ms of the settle left: less than the next frame's step.
      await tester.pump(const Duration(milliseconds: 150));

      _harness(tester).remove(3);
      await tester.pumpAndSettle();

      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ends, ends);
      expect(_harness(tester).ids, [0, 1, 2, 4]);
    });

    testWidgets(
      'fo06/us11/fr04/e06: a count change with no call while a dropped item '
      'settles fires no second onReorderEnd',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pump();
        final ends = [..._harness(tester).ends];
        expect(ends, hasLength(1));
        await tester.pump(const Duration(milliseconds: 100));

        // With no call, the build of the next frame ends the drop: that frame
        // must come before the settle does.
        _harness(tester).removeData(3);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ends, ends);
        expect(_harness(tester).ids, [0, 1, 2, 4]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e06: drag chrome that the app hides in onReorderEnd goes '
      'after a count change with no call',
      (tester) async {
        final ids = [0, 1, 2, 3, 4];
        final ends = <int>[];
        var dragging = false;
        late StateSetter setApp;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                setApp = setState;
                return Column(
                  children: [
                    if (dragging) const Text('dragging'),
                    Expanded(
                      child: ReorderableListViewLayout.builder(
                        itemCount: ids.length,
                        onReorderItem: (from, to) {},
                        onReorderStart: (_) => setState(() => dragging = true),
                        onReorderEnd: (index) => setState(() {
                          dragging = false;
                          ends.add(index);
                        }),
                        itemBuilder: (context, index) => SizedBox(
                          key: ValueKey(ids[index]),
                          height: 40,
                          child: Text('${ids[index]}'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('1')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        expect(find.text('dragging'), findsOneWidget);

        setApp(() => ids.insert(0, 9));
        await tester.pump();
        expect(ends, [1]);
        await tester.pump();

        expect(find.text('dragging'), findsNothing);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(ends, [1]);
      },
    );

    testWidgets('fo06/us11/fr04/e06: removing the dragged item ends the drag, then the item '
        'leaves from its slot', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final slot = tester.getTopLeft(find.byKey(const ValueKey(0)));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      _harness(tester).remove(0);
      expect(_harness(tester).ends, [0]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('0'), findsOneWidget);
      // The box it shrinks in; the item itself stays centered in it.
      expect(_sizeBox(tester, 0).localToGlobal(Offset.zero), slot);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('0'), findsNothing);
      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ends, [0]);
      expect(_harness(tester).ids, [1, 2, 3, 4]);
    });

    testWidgets(
      "NFR-U03 and fo06/us11/fr04/e01: under the platform's disableAnimations "
      "flag an insert and a remove still fade over the theme's durations",
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(_Harness(count: 3, itemsController: controller), theme: theme),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).insert(1, 9);
        await tester.pump();
        await tester.pump(_halfForward(theme));
        expect(_opacity(tester, 9), moreOrLessEquals(mid));
        await tester.pumpAndSettle();

        _harness(tester).remove(1);
        await tester.pump();
        await tester.pump(_halfReverse(theme));
        expect(_opacity(tester, 9), moreOrLessEquals(mid));
        await tester.pumpAndSettle();
        expect(find.text('9'), findsNothing);
      },
    );

    testWidgets(
      'fo06/us11/fr04: a removal in the turn of a move with no call ends the '
      'leaving copy of an item the data still holds',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 4, itemsController: controller)),
        );

        // The move gives index 2 to item 1, which the app removes; the last
        // build drew item 2 there, so its copy is the one that leaves.
        _harness(tester)
          ..moveData(3, 0)
          ..remove(2);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('2'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('1'), findsNothing);
        expect(_harness(tester).ids, [3, 0, 2]);
      },
    );

    testWidgets('fo06/us11/fr04: adding back an item whose look holds an app GlobalKey ends '
        'its leaving copy at once', (tester) async {
      final controller = ReorderableItemsController();
      final rows = [
        for (var id = 0; id < 3; id++) GlobalKey(debugLabel: 'row $id'),
      ];
      final ids = [0, 1, 2];
      late StateSetter setIds;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setIds = setState;
              return ReorderableListViewLayout.builder(
                itemCount: ids.length,
                itemsController: controller,
                onReorderItem: (from, to) {},
                itemBuilder: (context, index) => KeyedSubtree(
                  key: ValueKey(ids[index]),
                  child: SizedBox(
                    key: rows[ids[index]],
                    height: 40,
                    child: Text('${ids[index]}'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      setIds(() => ids.removeAt(1));
      controller.removeItem(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      setIds(() => ids.insert(0, 1));
      controller.insertItem(0);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('1', skipOffstage: false), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
      'fo06/us11/fr04/e03: adding back the key of an item that leaves in a '
      'builder look keeps that look leaving',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester).remove(
          2,
          builder: (context) => const SizedBox(
            key: ValueKey('gone'),
            height: 40,
            child: Text('gone'),
          ),
        );
        await tester.pump();
        _harness(tester).insert(0, 2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        expect(find.text('gone'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('gone'), findsNothing);
      },
    );

    testWidgets('fo06/us11/fr04/e13: a leaving key the data holds again with no insertItem '
        'fails a debug assert when its item builds', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(
          _Harness(count: 30, itemsController: controller),
          theme: _normalTheme(const Duration(seconds: 2)),
        ),
      );

      _harness(tester).remove(2);
      await tester.pump();
      // Index 28 lies far past the items the last build drew.
      _harness(tester).replaceData(28, 2);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets(
      'fo06/us11/fr04/e04: focus the app moves in the turn of a removal stays '
      'where the app put it',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller, fieldAt: 4)),
        );
        await _focusItem(tester, 2);
        final field = _itemState(tester, 4).node;

        _harness(tester).remove(2);
        field.requestFocus();
        await tester.pumpAndSettle();

        expect(field.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets('fo06/us11/fr04/e16: a focused item removed and inserted back at its index '
        'with its key in one turn keeps its State and focus', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final state = _itemState(tester, 2);
      final focused = await _focusItem(tester, 2);

      _harness(tester)
        ..remove(2)
        ..insert(2, 2);
      await tester.pumpAndSettle();

      expect(_itemState(tester, 2), same(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
    });

    testWidgets(
      'fo06/us11/fr04/e16: a focused item removed in a builder look and inserted '
      'back at its index with its key in one turn keeps its State and focus',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final state = _itemState(tester, 2);
        final focused = await _focusItem(tester, 2);

        _harness(tester)
          ..remove(
            2,
            builder: (context) => const SizedBox(
              key: ValueKey('gone'),
              height: 40,
              child: Text('gone'),
            ),
          )
          ..insert(2, 2);
        await tester.pumpAndSettle();

        expect(_itemState(tester, 2), same(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    // Where focused item 2 of five goes back, after its removal leaves four.
    final returnsAt = ValueVariant<int>({0, 4});
    testWidgets(
      'fo06/us11/fr04/e16: a focused item removed and inserted back at another '
      'index with its key in one turn keeps its State and focus',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final state = _itemState(tester, 2);
        final focused = await _focusItem(tester, 2);

        _harness(tester)
          ..remove(2)
          ..insert(returnsAt.currentValue!, 2);
        await tester.pumpAndSettle();

        expect(_itemState(tester, 2), same(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
      variant: returnsAt,
    );

    testWidgets(
      'fo06/us11/fr04/e16: a focused node inside an item removed and inserted '
      'back at its index with its key in one turn keeps focus',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller, innerAt: 2)),
        );
        final state = _itemState(tester, 2);
        final focused = state.inner..requestFocus();
        await tester.pump();
        expect(focused.hasPrimaryFocus, isTrue);

        _harness(tester)
          ..remove(2)
          ..insert(2, 2);
        await tester.pumpAndSettle();

        expect(_itemState(tester, 2), same(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    // Where focused item 100 of 200 goes back once the list shows it at its
    // top: slot 0 and slot 40 lie far before the viewport and its cache
    // extent, so the list has not built them.
    final returnsUnbuilt = ValueVariant<int>({0, 40});
    testWidgets('fo06/us11/fr04/e17: a focused item removed and inserted back with its key '
        'in one turn at a slot the list has not built takes focus on its first '
        'control and shows on screen', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 200, itemsController: controller)),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(4000);
      await tester.pump();
      await _focusItem(tester, 100);

      _harness(tester)
        ..remove(100)
        ..insert(returnsUnbuilt.currentValue!, 100);
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
      expect(_itemInView(tester, 100), isTrue);
    }, variant: returnsUnbuilt);

    testWidgets('fo06/us11/fr04/e16: a focused item removed and inserted back with its key '
        'in one turn at a slot built past the viewport keeps its State and '
        'focus and shows on screen', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller)),
      );
      final state = _itemState(tester, 2);
      final focused = await _focusItem(tester, 2);

      // Slot 10 runs from 400 to 440: past the 300 px viewport, inside
      // its cache extent.
      _harness(tester)
        ..remove(2)
        ..insert(10, 2);
      await tester.pumpAndSettle();

      expect(_itemState(tester, 2), same(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_itemInView(tester, 2), isTrue);
    });

    testWidgets(
      'fo06/us11/fr04/e18: a focused node inside an item removed and inserted '
      'back with its key in one turn, gone while the item keeps its State, '
      "hands focus to the item's first node",
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller, innerAt: 2)),
        );
        final state = _itemState(tester, 2);
        state.inner.requestFocus();
        await tester.pump();
        expect(state.inner.hasPrimaryFocus, isTrue);

        _harness(tester)
          ..remove(2)
          ..insert(4, 2)
          ..hideInner();
        await tester.pumpAndSettle();

        expect(_itemState(tester, 2), same(state));
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_itemInView(tester, 2), isTrue);
      },
    );

    testWidgets('fo06/us11/fr04/e16: focus the app moves in the turn it removes a focused '
        'item and inserts it back stays where the app put it', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller, fieldAt: 4)),
      );
      await _focusItem(tester, 2);
      final field = _itemState(tester, 4).node;

      _harness(tester)
        ..remove(2)
        ..insert(0, 2);
      field.requestFocus();
      await tester.pumpAndSettle();

      expect(field.hasPrimaryFocus, isTrue);
    });

    testWidgets('fo06/us11/s13: a button inside an item the app takes out and puts back at '
        'the fifth slot keeps focus, and the item shows there', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller, innerAt: 2)),
      );
      final button = _itemState(tester, 2).inner..requestFocus();
      await tester.pump();

      _harness(tester)
        ..remove(2)
        ..insert(4, 2);
      await tester.pumpAndSettle();

      expect(_harness(tester).ids, [0, 1, 3, 4, 2]);
      expect(FocusManager.instance.primaryFocus, same(button));
      expect(_offsetBetween(tester, 0, 2), 160);
      expect(_itemInView(tester, 2), isTrue);
    });

    testWidgets(
      'fo06/us11/fr04/e17: in a reversed list a focused item inserted back at a '
      'slot the list has not built takes focus and shows on screen',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            reverse: true,
          ),
          offset: 4000,
          id: 100,
          slot: returnsUnbuilt.currentValue!,
        );
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
        expect(_itemInView(tester, 100), isTrue);
      },
      variant: returnsUnbuilt,
    );

    testWidgets(
      'fo06/us11/fr04/e17: in a horizontal list a focused item inserted back at '
      'a slot the list has not built takes focus and shows on screen',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            axis: Axis.horizontal,
          ),
          offset: 4000,
          id: 100,
          slot: returnsUnbuilt.currentValue!,
        );
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
        expect(_itemInView(tester, 100), isTrue);
      },
      variant: returnsUnbuilt,
    );

    testWidgets(
      'fo06/us11/fr04/e17: in a horizontal list under right-to-left text a '
      'focused item inserted back at an unbuilt slot takes focus and shows '
      'on screen',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            axis: Axis.horizontal,
          ),
          offset: 4000,
          id: 100,
          slot: 40,
          textDirection: TextDirection.rtl,
        );
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
        expect(_itemInView(tester, 100), isTrue);
      },
    );

    testWidgets('fo06/us11/fr04/e17: in a list of varied item extents the list jumps again '
        'after a missed estimate and reaches the slot', (tester) async {
      // Slots before index 100 are 80 px and the rest 40 px, so the items
      // built around index 100 put slot 40 too far down; the items built
      // after that first jump are all 80 px and land it.
      await _returnFocused(
        tester,
        _Harness(
          count: 200,
          itemsController: ReorderableItemsController(),
          itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
        ),
        offset: 8000,
        id: 100,
        slot: 40,
      );
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
      expect(_itemInView(tester, 100), isTrue);
    });

    testWidgets('fo06/us11/fr04/e17: the list calls itemBuilder only inside a build while '
        'it reaches an unbuilt slot', (tester) async {
      var outside = 0;
      await _returnFocused(
        tester,
        _Harness(
          count: 200,
          itemsController: ReorderableItemsController(),
          onItemBuild: (context) {
            if (!context.owner!.debugBuilding) outside += 1;
          },
        ),
        offset: 4000,
        id: 100,
        slot: 0,
      );
      await tester.pumpAndSettle();

      expect(outside, 0);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
    });

    testWidgets('fo06/us11/fr04/e17: a node that takes focus while the list reaches a slot '
        'ends the reach and keeps that focus', (tester) async {
      await _returnFocused(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
        offset: 4000,
        id: 100,
        slot: 0,
      );
      _pinScroll(tester, 4000);
      await tester.pump();
      final other = _itemState(tester, 105).node..requestFocus();
      await tester.pumpAndSettle();

      expect(other.hasPrimaryFocus, isTrue);
    });

    testWidgets('fo06/us11/fr04/e17: an insert while the list reaches a slot puts another '
        'key there, so the list returns to its offset and hands focus to the '
        'item after the gap', (tester) async {
      await _returnFocused(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
        offset: 4000,
        id: 100,
        slot: 0,
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      var lowest = position.pixels;
      position.addListener(() {
        if (position.pixels < lowest) lowest = position.pixels;
      });
      await tester.pump();
      _harness(tester).insert(0, 500);
      await tester.pumpAndSettle();

      // The reach jumped to slot 0, found item 500 there, and returned to
      // 4000 (R5). The insert at index 0 moved the gap from index 101 to
      // 102, where item 101 still follows it.
      expect(lowest, 0);
      expect(position.pixels, 4000);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
    });

    testWidgets('fo06/us11/fr04/e17: a slot the list does not reach in 4 frames hands focus '
        'on from the gap', (tester) async {
      var jumps = 0;
      await _returnFocused(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
        offset: 4000,
        id: 100,
        slot: 0,
      );
      // Every jump of the reach springs back, so slot 0 is never built.
      _pinScroll(tester, 4000, onSpringBack: () => jumps += 1);
      await tester.pumpAndSettle();

      expect(jumps, 4);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
    });

    testWidgets(
      'fo06/us11/fr04/e17: focus Flutter hands back to an item focused earlier '
      'does not end the reach',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller)),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .jumpTo(4000);
        await tester.pump();
        // Item 99 sits in the cache extent just above the viewport.
        await _focusItem(tester, 99);
        await _focusItem(tester, 100);

        _harness(tester)
          ..remove(100)
          ..insert(0, 100);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
        expect(_itemInView(tester, 100), isTrue);
      },
    );

    testWidgets('fo06/us11/fr04/e17: a list taken out of the tree while it reaches a slot '
        'stops reaching', (tester) async {
      await _returnFocused(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
        offset: 4000,
        id: 100,
        slot: 0,
      );
      await tester.pump();
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // A physics the list can tell apart from the platform default by type, so
    // a rebuild that swaps it in makes the Scrollable replace and dispose the
    // position the reach in flight still holds.
    const swapPhysics = NeverScrollableScrollPhysics();

    testWidgets("fo06/us11/fr04/e17: a reach that gives up after the app swaps the list's "
        'scroll physics returns on the live position and hands focus off with '
        'no exception', (tester) async {
      // Slots before index 100 are 80 px and the rest 40 px, so the jump in
      // the call turn misses slot 40 and the State is lost.
      final controller = ReorderableItemsController();
      double? extents(int index, SliverLayoutDimensions dimensions) =>
          index < 100 ? 80 : 40;
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 200,
            itemsController: controller,
            itemExtentBuilder: extents,
          ),
        ),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(8000);
      await tester.pump();
      await _focusItem(tester, 100);

      _harness(tester).move(100, 40);
      final landing = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      // The frame that builds the move also swaps the physics, which
      // replaces and disposes the position the reach's return still holds.
      // This frame's post-frame callbacks pin the new position: each jump
      // of the reach springs back to the landing, so it gives up after its
      // 4 jumps, and the return jump, the fifth, passes through.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        var springs = 0;
        position.addListener(() {
          if (springs == 4 || position.pixels == landing) return;
          springs += 1;
          position.jumpTo(landing);
        });
      });
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 200,
            itemsController: controller,
            physics: swapPhysics,
            itemExtentBuilder: extents,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The list returned to its offset from before the move on the live
      // position (R5 for moves) and handed focus on from the gap.
      expect(tester.takeException(), isNull);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, 8000);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
    });

    testWidgets(
      'fo06/us11/s14: a button inside the first item of a long list the app '
      'takes out and puts back at the last slot: the list scrolls there, the '
      'button keeps focus, and the item shows on screen',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller, innerAt: 0)),
        );
        final state = _itemState(tester, 0);
        state.inner.requestFocus();
        await tester.pump();

        _harness(tester)
          ..remove(0)
          ..insert(199, 0);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'inner 0');
        expect(_statesOf(tester, 0), [same(state)]);
        expect(_itemInView(tester, 0), isTrue);
      },
    );

    testWidgets('fo06/us11/fr04/e14: a reorder key on the item a leaving item is drawn beside '
        'ends that leaving item at once', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(
          _Harness(count: 5, itemsController: controller),
          theme: _normalTheme(const Duration(seconds: 2)),
        ),
      );
      _harness(tester).remove(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('2'), findsOneWidget);
      await _focusItem(tester, 3);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(_harness(tester).ids, [0, 1, 4, 3]);
      expect(find.text('2'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'fo06/us11/fr04/e11: under an itemExtentBuilder a removed item keeps its '
      'own extent, clipped to the slot it fades over',
      (tester) async {
        final controller = ReorderableItemsController();
        final ids = [0, 1, 2, 3];
        late StateSetter setIds;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                setIds = setState;
                return ReorderableListViewLayout.builder(
                  itemCount: ids.length,
                  itemsController: controller,
                  // Item 1 is a header twice the height of a row.
                  itemExtentBuilder: (index, dimensions) =>
                      index < ids.length && ids[index] == 1 ? 80 : 40,
                  onReorderItem: (from, to) {},
                  itemBuilder: (context, index) => SizedBox(
                    key: ValueKey(ids[index]),
                    child: Text('${ids[index]}'),
                  ),
                );
              },
            ),
          ),
        );

        setIds(() => ids.removeAt(1));
        controller.removeItem(1);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final host = tester.getRect(find.byKey(const ValueKey(2)));
        expect(host.height, 40);
        expect(
          tester.getRect(find.byKey(const ValueKey(1))),
          Rect.fromLTWH(host.left, host.top, host.width, 80),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey(1)), findsNothing);
      },
    );

    testWidgets(
      'fo06/us11/fr04: in a reversed list a removed item shrinks out below the '
      'item after it',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller, reverse: true)),
        );

        _harness(tester).remove(2);
        await tester.pump();

        final host = tester.getRect(find.byKey(const ValueKey(3)));
        final exit = tester.getRect(find.byKey(const ValueKey(2)));
        expect(exit.top, host.bottom);
        expect(tester.getRect(find.byKey(const ValueKey(1))).top, exit.bottom);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey(2)), findsNothing);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e01: in a horizontal right-to-left list under reduced '
      "motion a removed item lies from its host's right edge, and a removed "
      'last item just left of it',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              axis: Axis.horizontal,
              itemsController: controller,
            ),
            textDirection: TextDirection.rtl,
          ),
        );

        _harness(tester)
          ..remove(
            2,
            builder: (context) => const SizedBox(
              key: ValueKey('gone'),
              width: 20,
              child: Text('gone'),
            ),
          )
          ..remove(3);
        await tester.pump();

        final host = tester.getRect(find.byKey(const ValueKey(3)));
        final gone = tester.getRect(find.byKey(const ValueKey('gone')));
        expect(tester.getRect(find.byKey(const ValueKey(1))).left, host.right);
        expect(gone.right, host.right);
        expect(gone.width, 20);
        expect(tester.getRect(find.byKey(const ValueKey(4))).right, host.left);
        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [0, 1, 3]);
      },
    );

    testWidgets('fo06/us11/fr04/e06: an insert from onReorderStart ends the drag it starts, '
        'the dragged item keeping its State', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final state = _itemState(tester, 0)..expanded = true;
      _harness(tester).onStart = (_) => _harness(tester).insert(0, 9);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).starts, [0]);
      expect(_harness(tester).ends, [0]);
      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ids, [9, 0, 1, 2, 3, 4]);
      expect(identical(_itemState(tester, 0), state), isTrue);
      expect(state.expanded, isTrue);
    });

    testWidgets('fo06/us11/fr04/e06: a remove and an insert from onReorderStart end the drag '
        'they start, so the drop moves nothing', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      // The item count stays the same, so only the calls end the drag.
      _harness(tester).onStart = (_) => _harness(tester)
        ..remove(4)
        ..insert(4, 9);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).starts, [0]);
      expect(_harness(tester).ends, [0]);
      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ids, [0, 1, 2, 3, 9]);
    });

    testWidgets(
      'fo06/us11/fr04/e06: a drag that starts between a call and its frame ends '
      'at once, and a later removal fires no second onReorderEnd',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout - const Duration(milliseconds: 50));
        // The long press starts a drag after the call and before the frame.
        _harness(tester).insert(4, 9);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_harness(tester).starts, [0]);
        expect(_harness(tester).ends, [0]);

        _harness(tester).remove(2);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_harness(tester).ends, [0]);
        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ids, [0, 1, 3, 9, 4]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e06: a drag that starts between the removal of its item and '
      'the frame ends at once, the item leaving from its slot',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('2')),
        );
        await tester.pump(kLongPressTimeout - const Duration(milliseconds: 50));
        // The long press lifts item 2 after its removal and before the frame
        // that builds its leaving copy.
        _harness(tester).remove(2);
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(_harness(tester).starts, [2]);
        expect(_harness(tester).ends, [2]);
        expect(find.text('2'), findsOneWidget);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('2'), findsNothing);
        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ends, [2]);
        expect(_harness(tester).ids, [0, 1, 3, 4]);
      },
    );

    testWidgets('fo06/us11/fr04/e06: a drag that starts between an insert and the frame ends '
        'at once when its slot holds a leaving item', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(
          _Harness(count: 5, itemsController: controller),
          theme: _normalTheme(const Duration(seconds: 2)),
        ),
      );
      final state = _itemState(tester, 2)..expanded = true;
      // Item 1 leaves inside the slot of item 2, which a lift takes whole.
      _harness(tester).remove(1);
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('2')),
      );
      await tester.pump(kLongPressTimeout - const Duration(milliseconds: 50));
      _harness(tester).insert(4, 9);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(_harness(tester).starts, [1]);
      expect(_harness(tester).ends, [1]);
      expect(find.text('1'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ids, [0, 2, 3, 4, 9]);
      expect(identical(_itemState(tester, 2), state), isTrue);
      expect(state.expanded, isTrue);
    });
  }

  group('ReorderableListViewLayout insert and remove', insertAndRemoveTests);

  void moveItemTests() {
    testWidgets(
      'fo06/us11/s15: the app moves the third item to the first slot: the third '
      'slot closes, the item grows and fades in, and its button keeps focus',
      (tester) async {
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: controller, innerAt: 2),
            theme: theme,
          ),
        );
        final state = _itemState(tester, 2);
        final button = state.inner..requestFocus();
        await tester.pump();
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).move(2, 0);
        await tester.pump();
        // Item 2 enters slot 0 at no size; its old slot is still 40 px.
        expect(_top(tester, 0), 0);
        expect(_top(tester, 3), 120);
        expect(_enteringOpacity(tester, 2), 0);

        await tester.pump(_halfForward(theme));
        expect(_top(tester, 0), moreOrLessEquals(40 * mid));
        expect(_top(tester, 3), moreOrLessEquals(120));
        expect(_enteringOpacity(tester, 2), moreOrLessEquals(mid));

        await tester.pumpAndSettle();
        expect(_top(tester, 2), 0);
        expect(_top(tester, 0), 40);
        expect(_top(tester, 3), 120);
        expect(_harness(tester).ids, [2, 0, 1, 3, 4]);
        expect(_harness(tester).moves, isEmpty);
        expect(_itemState(tester, 2), same(state));
        expect(FocusManager.instance.primaryFocus, same(button));
      },
    );

    testWidgets(
      'fo06/us11/fr05: a move down closes the old slot as the item grows into '
      'its new one, and the items past both slots hold still',
      (tester) async {
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller), theme: theme),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).move(0, 3);
        await tester.pump();
        expect(_top(tester, 1), 40);
        expect(_top(tester, 4), 160);

        await tester.pump(_halfForward(theme));
        expect(_top(tester, 1), moreOrLessEquals(40 * (1 - mid)));
        expect(_top(tester, 4), moreOrLessEquals(160));

        await tester.pumpAndSettle();
        expect(_top(tester, 0), 120);
        expect(_top(tester, 4), 160);
        expect(_harness(tester).ids, [1, 2, 3, 0, 4]);
      },
    );

    testWidgets('fo06/us11/fr05: in a reversed list a move to an earlier index closes the '
        "old slot at the data's last slot as the item grows into its new one, "
        'and the items past both slots hold still', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(
          _Harness(count: 5, itemsController: controller, reverse: true),
          theme: theme,
        ),
      );
      final mid = Curves.easeInOutSine.transform(0.5);

      _harness(tester).move(4, 1);
      await tester.pump();
      expect(_top(tester, 3), 140);
      expect(_top(tester, 0), 260);

      await tester.pump(_halfForward(theme));
      expect(_top(tester, 3), moreOrLessEquals(100 + 40 * (1 - mid)));
      expect(_top(tester, 0), moreOrLessEquals(260));

      await tester.pumpAndSettle();
      expect(_top(tester, 3), 100);
      expect(_top(tester, 0), 260);
      expect(_harness(tester).ids, [0, 4, 1, 2, 3]);
    });

    testWidgets('fo06/us11/fr05/e01: a move to the same index does nothing', (
      tester,
    ) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final state = _itemState(tester, 2);

      _harness(tester).move(2, 2);
      await tester.pump();

      // R48: at rest every item sits inside a completed transition.
      expect(_runningTransitions(tester), isEmpty);
      expect(_itemState(tester, 2), same(state));
      expect(_harness(tester).ids, [0, 1, 2, 3, 4]);
    });

    testWidgets(
      'NFR-U03 and fo06/us11/fr05/e02: under reduced motion the old slot closes '
      'at once and the moved item fades in over the full forward duration',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller), theme: theme),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).move(2, 0);
        await tester.pump();
        expect(_top(tester, 0), 40);
        expect(_top(tester, 3), 120);
        expect(_opacity(tester, 2), 0);

        await tester.pump(_halfForward(theme));
        expect(_opacity(tester, 2), moreOrLessEquals(mid));
        await tester.pumpAndSettle();
        expect(_top(tester, 3), 120);
      },
    );

    testWidgets(
      "NFR-U03 and fo06/us11/fr05/e02: under the platform's disableAnimations "
      'flag the old slot closes at once and the moved item fades in over '
      'the full forward duration',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller), theme: theme),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        _harness(tester).move(2, 0);
        await tester.pump();
        expect(_top(tester, 0), 40);
        expect(_top(tester, 3), 120);
        expect(_opacity(tester, 2), 0);

        await tester.pump(_halfForward(theme));
        expect(_opacity(tester, 2), moreOrLessEquals(mid));
        await tester.pumpAndSettle();
        expect(_top(tester, 3), 120);
      },
    );

    testWidgets('fo06/us11/fr05/e02: reduced motion switched on mid-move leaves the running '
        'fade to finish and settles the list right', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller), theme: theme),
      );
      final mid = Curves.easeInOutSine.transform(0.5);

      // Motion on at the call, so the move books its closing gap (E02
      // fixes the state at the call): the items past both slots hold
      // still while the item grows in and the gap closes.
      _harness(tester).move(2, 0);
      await tester.pump();
      expect(_top(tester, 0), 0);
      expect(_top(tester, 3), 120);
      expect(_top(tester, 4), 160);

      await tester.pump(_halfForward(theme));
      expect(_top(tester, 0), moreOrLessEquals(40 * mid));

      // Halfway through, the platform flag turns on. No frame even
      // rebuilds for a bare reduce-motion toggle (MediaQueryData carries
      // no such field), so the running motion keeps its own timeline:
      // the gap still closes and the item still fades, with no exception
      // and no snap.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_top(tester, 0), moreOrLessEquals(40 * mid));
      expect(_top(tester, 3), 120);
      expect(_enteringOpacity(tester, 2), moreOrLessEquals(mid));

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids, [2, 0, 1, 3, 4]);
      expect(_top(tester, 2), 0);
      expect(_top(tester, 3), 120);

      // A move called under the flag the frame reads: E02 applies, so the
      // old slot is already closed, with no closing gap's size transition,
      // and the moved item takes its full extent at once, only fading in.
      _harness(tester).move(0, 3);
      await tester.pump();
      expect(
        find.descendant(
          of: _reorderSliver(),
          matching: find.byType(SizeTransition),
        ),
        findsNothing,
      );
      expect(_sizeBox(tester, 2).size.height, 40);
      expect(_opacity(tester, 2), 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids, [0, 1, 3, 2, 4]);
      expect(_top(tester, 2), 120);
      expect(_top(tester, 4), 160);
    });

    testWidgets('fo06/us11/fr05/e02: with a fixed item extent the old slot closes at once '
        'and the moved item fades in', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller, itemExtent: 40)),
      );

      _harness(tester).move(2, 0);
      await tester.pump();

      expect(_top(tester, 0), 40);
      expect(_top(tester, 3), 120);
      expect(_opacity(tester, 2), 0);
      // No closing gap's size transition, and the moved item takes the
      // slot's full extent at once.
      expect(
        find.descendant(
          of: _reorderSliver(),
          matching: find.byType(SizeTransition),
        ),
        findsNothing,
      );
      expect(_sizeBox(tester, 2).size.height, 40);
    });

    testWidgets(
      'fo06/us11/fr05/e03: a caller itemTransitionBuilder wraps the entering '
      'item and never the slot it left',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              itemsController: controller,
              itemTransitionBuilder: (context, animation, child) =>
                  KeyedSubtree(
                    key: const ValueKey('caller'),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
            ),
          ),
        );

        _harness(tester).move(2, 0);
        await tester.pump();

        // R48: the caller wraps every item; only the entering one runs.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is KeyedSubtree &&
                widget.key == const ValueKey('caller') &&
                (widget.child as FadeTransition).opacity !=
                    kAlwaysCompleteAnimation,
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey(2)),
            matching: find.byKey(const ValueKey('caller')),
          ),
          findsOneWidget,
        );
        // Item 1's top to item 3's top: item 1, then the 40 px old slot.
        expect(_offsetBetween(tester, 1, 3), 80);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e06: a move during a drag ends the drag first',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();

        _harness(tester).move(3, 1);
        expect(_harness(tester).ends, [0]);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ends, [0]);
        expect(_harness(tester).ids, [0, 3, 1, 2, 4]);
      },
    );

    testWidgets('fo06/us11/fr05/e07: an out-of-range index or a controller attached to no '
        'list fails a debug assert', (tester) async {
      final controller = ReorderableItemsController();
      expect(() => controller.moveItem(0, 1), throwsAssertionError);

      await tester.pumpWidget(
        _app(_Harness(count: 3, itemsController: controller)),
      );

      expect(() => controller.moveItem(3, 0), throwsAssertionError);
      expect(() => controller.moveItem(0, 3), throwsAssertionError);
      expect(() => controller.moveItem(-1, 0), throwsAssertionError);
      expect(() => controller.moveItem(0, -1), throwsAssertionError);
      await tester.pump();
      expect(_harness(tester).ids, [0, 1, 2]);
    });

    testWidgets('fo06/us11/fr05/e08: a move the app defers to after the frame animates as '
        'a move made outside a build', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _harness(tester).move(2, 0),
      );
      await tester.pump();
      await tester.pump();

      expect(_top(tester, 3), 120);
      expect(_enteringOpacity(tester, 2), 0);
      await tester.pumpAndSettle();
      expect(_harness(tester).ids, [2, 0, 1, 3, 4]);
    });

    testWidgets(
      'fo06/us11/fr05/e08: a moveItem the app defers from inside a build to '
      'after the frame animates as a call made outside',
      (tester) async {
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        var armed = false;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              itemsController: controller,
              onItemBuild: (context) {
                if (armed) return;
                armed = true;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _harness(tester).move(2, 0),
                );
              },
            ),
            theme: theme,
          ),
        );
        final mid = Curves.easeInOutSine.transform(0.5);

        // The deferred move ran after the frame that armed it, with its
        // data change, and then closed the old slot as the item grew in.
        await tester.pump();
        expect(_top(tester, 0), 0);
        expect(_top(tester, 3), 120);
        expect(_enteringOpacity(tester, 2), 0);

        await tester.pump(_halfForward(theme));
        expect(_top(tester, 0), moreOrLessEquals(40 * mid));
        expect(_top(tester, 3), moreOrLessEquals(120));
        expect(_enteringOpacity(tester, 2), moreOrLessEquals(mid));

        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [2, 0, 1, 3, 4]);
        expect(_top(tester, 2), 0);
        expect(_top(tester, 0), 40);
        expect(_top(tester, 3), 120);
      },
    );

    testWidgets('fo06/us11/fr05/e09: a move ends at once the leaving item drawn beside the '
        'moved item', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );

      _harness(tester).remove(3);
      await tester.pump();
      expect(find.byKey(const ValueKey(3)), findsOneWidget);

      _harness(tester).move(3, 0);
      await tester.pump();

      expect(find.byKey(const ValueKey(3)), findsNothing);
      expect(_harness(tester).ids, [4, 0, 1, 2]);
    });

    testWidgets('fo06/us11/fr05/e10: a moved item still growing in starts its entry again '
        'at its new slot', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(_Harness(count: 3, itemsController: controller), theme: theme),
      );

      _harness(tester).insert(1, 9);
      await tester.pump();
      await tester.pump(_halfForward(theme));
      expect(_opacity(tester, 9), greaterThan(0));

      _harness(tester).move(1, 3);
      await tester.pump();

      expect(_opacity(tester, 9), 0);
      await tester.pumpAndSettle();
      expect(_harness(tester).ids, [0, 1, 2, 9]);
      expect(_top(tester, 9), 120);
    });

    testWidgets(
      'fo06/us11/fr04/e05: an item playing its remove animation counts in no '
      'index of moveItem',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester).remove(1);
        await tester.pump();
        _harness(tester).move(2, 0);
        await tester.pumpAndSettle();

        expect(_harness(tester).ids, [3, 0, 2, 4]);
        expect(_top(tester, 3), 0);
        expect(find.byKey(const ValueKey(1)), findsNothing);
      },
    );

    testWidgets('fo06/us11/fr05: a remove and a move in one turn read the move against the '
        'data after the remove', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );

      _harness(tester)
        ..remove(0)
        ..move(2, 0);
      await tester.pumpAndSettle();

      expect(_harness(tester).ids, [3, 1, 2, 4]);
      expect(_top(tester, 3), 0);
      expect(_top(tester, 4), 120);
      expect(find.byKey(const ValueKey(0)), findsNothing);
    });

    testWidgets('fo06/us11/fr05: an item moved from beyond the built slots grows in at its '
        'new slot with no closing slot and no scroll', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 200, itemsController: controller)),
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;

      _harness(tester).move(150, 2);
      await tester.pump();

      expect(_opacity(tester, 150), 0);
      expect(_top(tester, 2), 80);
      await tester.pumpAndSettle();
      expect(_top(tester, 150), 80);
      expect(_top(tester, 2), 120);
      expect(position.pixels, 0);
    });

    testWidgets(
      'fo06/us11/fr05/e04: a focused item moved to the unbuilt last slot keeps '
      'its State and focus, and shows on screen',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller)),
        );
        final state = _itemState(tester, 0);
        final focused = await _focusItem(tester, 0);

        _harness(tester).move(0, 199);
        await tester.pumpAndSettle();

        expect(_itemState(tester, 0), same(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_itemInView(tester, 0), isTrue);
      },
    );

    testWidgets('fo06/us11/fr05/e04: a focused item moved to the unbuilt first slot keeps '
        'its State and focus, and shows on screen', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 200, itemsController: controller)),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(4000);
      await tester.pump();
      final state = _itemState(tester, 100);
      final focused = await _focusItem(tester, 100);

      _harness(tester).move(100, 0);
      await tester.pumpAndSettle();

      expect(_itemState(tester, 100), same(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_itemInView(tester, 100), isTrue);
    });

    // The axis of a list whose focused item moves to an unbuilt middle slot.
    final moveAxes = ValueVariant<Axis>({Axis.vertical, Axis.horizontal});
    testWidgets('fo06/us11/fr05/e04: a focused item moved to an unbuilt middle slot keeps '
        'its State and focus, and the list calls itemBuilder only inside a '
        'build', (tester) async {
      var outside = 0;
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 200,
            itemsController: controller,
            axis: moveAxes.currentValue!,
            onItemBuild: (context) {
              if (!context.owner!.debugBuilding) outside += 1;
            },
          ),
        ),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(4000);
      await tester.pump();
      final state = _itemState(tester, 100);
      final focused = await _focusItem(tester, 100);

      _harness(tester).move(100, 40);
      await tester.pumpAndSettle();

      expect(outside, 0);
      expect(_itemState(tester, 100), same(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_itemInView(tester, 100), isTrue);
    }, variant: moveAxes);

    testWidgets(
      'fo06/us11/fr05/e04: after a missed estimate the list reaches the moved '
      "item's slot and focuses its first node",
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump
        // in the call turn lands short of slot 40 and the State is lost.
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 200,
              itemsController: controller,
              itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
            ),
          ),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .jumpTo(8000);
        await tester.pump();
        await _focusItem(tester, 100);

        _harness(tester).move(100, 40);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
        expect(_itemInView(tester, 100), isTrue);
      },
    );

    testWidgets('fo06/us11/fr05/e04: when the reach after a move fails, the list returns to '
        'its offset from before the move and hands focus on from the slot the '
        'item left', (tester) async {
      // As above, the jump at the next frame's start lands short of slot
      // 40. Each jump of the reach then springs back to that landing, so
      // the reach fails; the list's return to 8000 is the first move let
      // through.
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 200,
            itemsController: controller,
            itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
          ),
        ),
      );
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position
            ..jumpTo(8000);
      await tester.pump();
      await _focusItem(tester, 100);

      _harness(tester).move(100, 40);
      expect(position.pixels, 8000);
      double? landing;
      var springs = 0;
      position.addListener(() {
        final at = landing;
        // The first move is the move's own jump at the frame's start.
        if (at == null) {
          landing = position.pixels;
          return;
        }
        if (springs == 4 || position.pixels == at) return;
        springs += 1;
        position.jumpTo(at);
      });
      await tester.pumpAndSettle();

      // Item 100 left index 100, so index 101 holds item 101, the item
      // after the slot it left, at 8040.
      expect(landing, lessThan(8000));
      expect(springs, 4);
      expect(position.pixels, 8000);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
    });

    testWidgets('fo06/us11/fr05/e04: a focused item moved to a slot built past the viewport '
        'shows on screen once it has grown in', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller)),
      );
      final state = _itemState(tester, 2);
      final focused = await _focusItem(tester, 2);

      // Slot 10 runs from 400 to 440: past the 300 px viewport, inside its
      // cache extent.
      _harness(tester).move(2, 10);
      await tester.pumpAndSettle();

      expect(_itemState(tester, 2), same(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_itemInView(tester, 2), isTrue);
    });

    testWidgets(
      'fo06/us11/fr05/e04: an insert in the same turn as a focused move whose '
      'estimate misses hands focus off from the shifted gap',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump in
        // the call turn lands short of slot 40 and the State is lost.
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 200,
              itemsController: controller,
              itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
            ),
          ),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .jumpTo(8000);
        await tester.pump();
        await _focusItem(tester, 100);

        _harness(tester)
          ..move(100, 40)
          ..insert(0, 500);
        // Each jump of the reach springs back to where the move's jump at
        // the next frame's start landed, so the reach gives up and the E04
        // handoff runs.
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        expect(position.pixels, 8000);
        double? landing;
        var springs = 0;
        position.addListener(() {
          final at = landing;
          if (at == null) {
            landing = position.pixels;
            return;
          }
          if (springs == 4 || position.pixels == at) return;
          springs += 1;
          position.jumpTo(at);
        });
        await tester.pumpAndSettle();

        // The reach never reaches the moved item, so the list returns to the
        // offset from before the move and hands focus on from the gap the
        // insert shifted, the item after it (E04): the data now holds item
        // 101 right after the gap.
        expect(springs, 4);
        expect(position.pixels, 8000);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: a focused item moved and then removed in one turn '
      'hands focus off, never to the scope',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        await _focusItem(tester, 3);

        // The remove takes the moved item back out in the same turn; the
        // follow finds no settled slot for it, so the list returns and hands
        // focus on from the gap.
        _harness(tester)
          ..move(3, 1)
          ..remove(1);
        await tester.pumpAndSettle();
        final primary = FocusManager.instance.primaryFocus;

        expect(tester.takeException(), isNull);
        expect(primary, isA<FocusNode>());
        expect(primary, isNot(isA<FocusScopeNode>()));
        expect(primary?.debugLabel, 'item 4');
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: a focused move with a missed estimate and an '
      'unexplained count change in one turn hands focus off, never to the '
      'scope',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump
        // in the call turn lands short of slot 40 and the State is lost.
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 200,
              itemsController: controller,
              itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
            ),
          ),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .jumpTo(8000);
        await tester.pump();
        await _focusItem(tester, 100);

        // The count change no call explains resets the motion (E12), so the
        // settling build records no slot for the moved item; the list still
        // returns and hands focus on from the gap.
        _harness(tester)
          ..move(100, 40)
          ..insertData(0, 500);
        await tester.pumpAndSettle();
        final primary = FocusManager.instance.primaryFocus;

        expect(tester.takeException(), isNull);
        expect(primary, isA<FocusNode>());
        expect(primary, isNot(isA<FocusScopeNode>()));
        expect(primary?.debugLabel, startsWith('item'));
      },
    );

    testWidgets('fo06/us11/fr05/e05: the list never scrolls for a moved item that does not '
        'hold focus', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 200, itemsController: controller)),
      );
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position
            ..jumpTo(4000);
      await tester.pump();
      final other = await _focusItem(tester, 105);

      _harness(tester).move(100, 0);
      await tester.pumpAndSettle();

      expect(position.pixels, 4000);
      expect(other.hasPrimaryFocus, isTrue);
      expect(find.byKey(const ValueKey(100)), findsNothing);
    });

    testWidgets(
      'fo06/us11/fr05/e04: handing the controller to a second list in the turn '
      'of a focused move to an unbuilt slot keeps focus on a live item of '
      'the first list, never on the second list',
      (tester) async {
        final controller = ReorderableItemsController();
        // List A of 200 above list B of three items; the rebuild that builds
        // A's move also takes the controller off A and gives it to B.
        late StateSetter setHandOff;
        var onB = false;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                setHandOff = setState;
                return Column(
                  children: [
                    Expanded(
                      child: _Harness(
                        count: 200,
                        itemsController: onB ? null : controller,
                        // Slots before index 100 are 80 px and the rest
                        // 40 px, so the jump in the call turn lands short
                        // of slot 40 and the reach runs.
                        itemExtentBuilder: (index, dimensions) =>
                            index < 100 ? 80 : 40,
                      ),
                    ),
                    Expanded(
                      child: _Harness(
                        count: 3,
                        itemsController: onB ? controller : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(8000);
        await tester.pump();
        await _focusItem(tester, 100);

        // The move and the hand-off in one turn: the frame that builds the
        // move also re-attaches the controller to B, and A's post-frame
        // follow and its reach then run while B holds the controller.
        setHandOff(() => onB = true);
        _harnessA(tester).move(100, 40);
        await tester.pumpAndSettle();
        final primary = FocusManager.instance.primaryFocus;

        expect(tester.takeException(), isNull);
        expect(primary, isA<FocusNode>());
        expect(primary, isNot(isA<FocusScopeNode>()));
        expect(primary?.debugLabel, 'item 100');
        // The node lives in list A, the list that owns the moved item, and
        // never in B, which now holds the controller.
        expect(
          primary?.context?.findAncestorStateOfType<_HarnessState>(),
          same(_harnessA(tester)),
        );
      },
    );
  }

  group('ReorderableListViewLayout moveItem', moveItemTests);

  group('ReorderableListViewLayout data and frame indices', () {
    // 200 items of 40 px in a 300 px viewport scrolled to 4000, with the
    // default 250 px cache extent: the frame builds slots 93 to 113, also
    // under a fixed [itemExtent] of 40.
    Future<ScrollPosition> pumpAt4000(
      WidgetTester tester, {
      double? itemExtent,
    }) async {
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            itemExtent: itemExtent,
          ),
        ),
      );
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position
            ..jumpTo(4000);
      await tester.pump();
      expect(find.byKey(const ValueKey(113), skipOffstage: false), findsOne);
      expect(
        find.byKey(const ValueKey(114), skipOffstage: false),
        findsNothing,
      );
      return position;
    }

    List<_ItemState> statesOf(WidgetTester tester, int id) => tester
        .stateList<_ItemState>(find.byKey(ValueKey(id), skipOffstage: false))
        .toList();

    // Presses Alt+Up with no pump, so the key lands before the next frame.
    Future<void> altUpNow(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    }

    testWidgets(
      'fo06/us11/fr05/e04: a focused move down past the built slots after an '
      'insertItem in the same turn scrolls nothing in the call turn and '
      'keeps its State',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // After three inserts item 100 sits at index 103; slot 116, the slot
        // it enters, is 3 slots past the built 93 to 113: near.
        _harness(tester)
          ..insert(0, 1000)
          ..insert(0, 1001)
          ..insert(0, 1002)
          ..move(103, 115);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: a focused move up into a built slot after an '
      'insertItem in the same turn does not scroll in the call turn',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // Slot 95, the slot item 100 enters, is built.
        _harness(tester)
          ..insert(0, 1000)
          ..insert(0, 1001)
          ..insert(0, 1002)
          ..move(103, 95);
        expect(position.pixels, 4000);
        await tester.pumpAndSettle();

        expect(statesOf(tester, 100), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: a focused move down to the last built slot scrolls '
      'nothing in the call turn, since the item enters the slot after it, '
      'and keeps its State',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // A move down to 113 enters slot 114, which the frame did not build.
        _harness(tester).move(100, 113);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    // The reorder key pressed between an insertItem call and its frame.
    final windowKeys = ValueVariant<LogicalKeyboardKey>({
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.end,
    });
    testWidgets('fo06/us11/fr02/e07: a reorder key between an insertItem call and its frame '
        "moves the focused item by indices of the app's data", (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller)),
      );
      await _focusItem(tester, 5);

      // The insert puts item 5 at index 6 of 21 before the frame.
      final harness = _harness(tester)..insert(0, 500);
      final key = windowKeys.currentValue!;
      expect(await _alt(tester, key), isTrue);

      final up = key == LogicalKeyboardKey.arrowUp;
      expect(harness.moves, [if (up) (6, 5) else (6, 20)]);
      expect(harness.ids.indexOf(5), up ? 5 : 20);
    }, variant: windowKeys);

    // A screen-reader move made after an insertItem call and before its
    // frame: the action, the insert index, and the move it reports.
    const windowActions = {
      'Move up after an insert at 0': ('Move up', 0, (6, 5)),
      'Move to the start after an insert at 0': (
        'Move to the start',
        0,
        (6, 0),
      ),
      'Move to the end after an insert at 0': ('Move to the end', 0, (6, 20)),
      'Move to the end after an insert at the end': (
        'Move to the end',
        20,
        (5, 20),
      ),
    };
    final windowAction = ValueVariant<String>(windowActions.keys.toSet());
    testWidgets(
      'fo06/us11/fr03/e07: a screen-reader move between an insertItem call and '
      "its frame moves the item it names by indices of the app's data",
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );

        final (label, insertAt, move) =
            windowActions[windowAction.currentValue]!;
        final harness = _harness(tester)..insert(insertAt, 500);
        await _moveAction(tester, 5, label);

        expect(harness.moves, [move]);
        handle.dispose();
      },
      variant: windowAction,
    );

    // The input that tries to move an item the app removed in that turn.
    final removedInput = ValueVariant<String>({'Alt+Up', 'Move up'});
    testWidgets(
      'fo06/us11/fr03/e07: a key or screen-reader move on an item the app '
      'removed in the same turn moves nothing',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        final harness = _harness(tester)..remove(5);
        if (removedInput.currentValue == 'Alt+Up') {
          expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isTrue);
        } else {
          await _moveAction(tester, 5, 'Move up');
        }

        expect(harness.moves, isEmpty);
        expect(harness.ids, [
          for (var id = 0; id < 20; id++)
            if (id != 5) id,
        ]);
        handle.dispose();
      },
      variant: removedInput,
    );

    // The input that moves an item the app moved in that turn.
    final movedInput = ValueVariant<String>({'Alt+Up', 'Move up'});
    testWidgets(
      'fo06/us11/fr03/e07: a key or screen-reader move on an item the app '
      'moved in the same turn moves it from its new index',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        // The app's move puts item 5 at index 10 of its data before the frame.
        final harness = _harness(tester)..move(5, 10);
        if (movedInput.currentValue == 'Alt+Up') {
          expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isTrue);
        } else {
          await _moveAction(tester, 5, 'Move up');
        }

        expect(harness.moves, [(10, 9)]);
        expect(harness.ids.indexOf(5), 9);
        handle.dispose();
      },
      variant: movedInput,
    );

    // An app call, then an input on item 5 before the call's frame: whether
    // the call is a move of item 5 (else an insert of item 500 at 5), the
    // input, the item that grows in, and the item that does not.
    const growIns = {
      'Alt+Up across an insert': (false, 'Alt+Up', 500, 5),
      'Move up across an insert': (false, 'Move up', 500, 5),
      'Alt+Up on an item the app moved': (true, 'Alt+Up', 5, 10),
    };
    final growIn = ValueVariant<String>(growIns.keys.toSet());
    testWidgets(
      's03/inv29: a key or screen-reader move between a call and its frame '
      'leaves each grow-in on its own item',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        final (moved, input, grows, still) = growIns[growIn.currentValue]!;
        final harness = _harness(tester);
        if (moved) {
          harness.move(5, 10);
        } else {
          harness.insert(5, 500);
        }
        if (input == 'Alt+Up') {
          await altUpNow(tester);
        } else {
          final node = tester.getSemantics(find.byKey(const ValueKey(5)));
          node.owner!.performAction(
            node.id,
            SemanticsAction.customAction,
            CustomSemanticsAction.getIdentifier(
              const CustomSemanticsAction(label: 'Move up'),
            ),
          );
        }
        await tester.pump();

        expect(_enteringOpacity(tester, grows), 0);
        expect(_enteringOpacity(tester, still), 1);
        await tester.pumpAndSettle();
        expect(harness.ids.indexOf(5), moved ? 9 : 5);
        handle.dispose();
      },
      variant: growIn,
    );

    testWidgets('fo06/us11/fr04/e06: a drag that starts between a reorder key and its frame '
        'ends at once, and the key move stands', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      await _focusItem(tester, 3);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('2')),
      );
      await tester.pump(kLongPressTimeout - const Duration(milliseconds: 50));
      // Alt+Up moves item 3 above item 2; the long press then lifts item
      // 2 before the key's frame, which moves it to index 3.
      await altUpNow(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(_harness(tester).starts, [2]);
      expect(_harness(tester).ends, [2]);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_harness(tester).moves, [(3, 2)]);
      expect(_harness(tester).ids, [0, 1, 3, 2, 4]);
    });

    testWidgets(
      'fo06/us11/fr04/e04: a focused item a reorder key moved and the app then '
      'removed in the same turn leaves from there and hands focus on',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        // Alt+Up puts item 5 at index 4; the app removes it from there
        // before the key's frame.
        await altUpNow(tester);
        _harness(tester).remove(4);
        await tester.pump();

        expect(find.byKey(const ValueKey(5), skipOffstage: false), findsOne);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey(5), skipOffstage: false),
          findsNothing,
        );
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 4');
      },
    );

    testWidgets('fo06/us11/fr05: a moveItem of an item a reorder key moved in the same turn '
        'closes the slot the key moved it to, and the items past both slots '
        'hold still', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller), theme: theme),
      );
      final state = _itemState(tester, 5);
      await _focusItem(tester, 5);

      // Alt+Up puts item 5 at index 4; the app moves it on to index 2
      // before the key's frame.
      await altUpNow(tester);
      _harness(tester).move(4, 2);
      await tester.pump();
      expect(_top(tester, 6), 240);
      await tester.pump(_halfForward(theme));
      expect(_top(tester, 4), moreOrLessEquals(200));
      expect(_top(tester, 6), moreOrLessEquals(240));

      await tester.pumpAndSettle();
      expect(_harness(tester).ids.sublist(0, 7), [0, 1, 5, 2, 3, 4, 6]);
      expect(_itemState(tester, 5), same(state));
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 5');
    });

    testWidgets('fo06/us11/fr02: a reorder key the app does not apply leaves the next key '
        'on the indices the frame shows', (tester) async {
      final moves = <(int, int)>[];
      await tester.pumpWidget(
        _app(
          ReorderableListViewLayout.builder(
            itemCount: 5,
            // The app turns every move down: its data never changes.
            onReorderItem: (from, to) => moves.add((from, to)),
            itemBuilder: (context, index) =>
                _Item(key: ValueKey(index), id: index, index: index),
          ),
        ),
      );
      await _focusItem(tester, 3);

      expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isTrue);
      expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isTrue);

      expect(moves, [(3, 2), (3, 2)]);
    });

    testWidgets(
      'fo06/us11/fr04/e04: an app call earlier in the same post-frame batch '
      'leaves focus on the item after a removed one',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        // The app's own post-frame insert runs before the handoff.
        final harness = _harness(tester);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => harness.insert(0, 500),
        );
        harness.remove(5);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 6');
      },
    );

    testWidgets(
      'fo06/us11/fr04/e04: the handoff skips an item an insertItem call after '
      'the frame adds at the gap and goes to the next item the frame shows',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        // The app's own post-frame calls run before the handoff: the insert
        // at the start moves the gap to 6, and the insert at 6 puts an item
        // the frame has not built at the gap.
        final harness = _harness(tester);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          harness
            ..insert(0, 500)
            ..insert(6, 501);
        });
        harness.remove(5);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 6');
      },
    );

    testWidgets(
      'fo06/us11/fr04/e04: the handoff skips an item a moveItem call after the '
      'frame brings to the gap and goes to the next item the frame shows',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        // The app's own post-frame move runs before the handoff and puts
        // item 8, which the frame drew two slots past the gap, at the gap.
        final harness = _harness(tester);
        WidgetsBinding.instance.addPostFrameCallback((_) => harness.move(7, 5));
        harness.remove(5);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 6');
      },
    );

    testWidgets(
      'fo06/us11/fr05: an item moved and then removed in one turn shows no '
      'leaving copy at its new index',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );

        _harness(tester)
          ..move(3, 1)
          ..remove(1);
        await tester.pump();

        expect(
          find.byKey(const ValueKey(3), skipOffstage: false),
          findsNothing,
        );
        await tester.pumpAndSettle();
        expect(_harness(tester).ids, [0, 1, 2, 4]);
        expect(_top(tester, 4), 120);
      },
    );

    testWidgets('fo06/us11/fr05: a second moveItem of an item in the same turn closes only '
        'the slot the frame drew it in, and the items past both slots hold '
        'still', (tester) async {
      final controller = ReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller), theme: theme),
      );
      final state = _itemState(tester, 0);

      _harness(tester)
        ..move(0, 2)
        ..move(2, 3);
      await tester.pump();
      expect(_top(tester, 4), 160);
      await tester.pump(_halfForward(theme));
      expect(_top(tester, 4), moreOrLessEquals(160));

      await tester.pumpAndSettle();
      expect(_harness(tester).ids, [1, 2, 3, 0, 4]);
      expect(_top(tester, 0), 120);
      expect(_itemState(tester, 0), same(state));
    });

    testWidgets('fo06/us11/fr04/e17: a reach that gives up where it started hands focus on '
        'from the gap an app call in its last frame moved', (tester) async {
      final controller = ReorderableItemsController();
      await _returnFocused(
        tester,
        _Harness(count: 200, itemsController: controller),
        offset: 0,
        id: 5,
        slot: 150,
      );
      final harness = _harness(tester);
      // Every jump of the reach springs back to 0, so after its fourth
      // jump the reach gives up with the list where it started and hands
      // focus on at once; the app's post-frame insert, registered on that
      // jump, runs first in the reach's last frame.
      var springs = 0;
      _pinScroll(
        tester,
        0,
        onSpringBack: () {
          springs += 1;
          if (springs != 4) return;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => harness.insert(0, 900),
          );
        },
      );
      await tester.pumpAndSettle();

      expect(springs, 4);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 6');
    });

    testWidgets(
      'fo06/us11/fr03: an insert the app defers from onReorderItem leaves the '
      'reveal on the moved item',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        // The app defers its insert from inside onReorderItem (FR-04 E15),
        // so it runs before the move's reveal, in the same post-frame batch.
        final harness = _harness(tester)
          ..onMove = (from, to) => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _harness(tester).insert(0, 500),
          );
        // Item 6 fills 240 to 280 of the 300 px viewport; slot 7 ends 20 px
        // past it.
        final node = tester.getSemantics(find.byKey(const ValueKey(6)));
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            const CustomSemanticsAction(label: 'Move down'),
          ),
        );
        await tester.pump();

        expect(harness.ids.indexOf(6), 8);
        // R56: the list commits its scroll at the next frame's start
        // (D13 frame shift).
        await tester.pump();
        expect(position.pixels, 20);
        await tester.pumpAndSettle();
        handle.dispose();
      },
    );

    // An app call that lands after a reach gave up away from where it
    // started: while the list jumps back, or after the frame that jump asks
    // for, before the handoff that waits for it.
    final lateCall = ValueVariant<String>({
      'while the list jumps back',
      'after the jump back frame',
    });
    testWidgets(
      'fo06/us11/fr05/e04: a reach that gives up away from where it started hands '
      'focus on from the gap an app call before the handoff moved',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump in
        // the call turn lands short of slot 40 and the State is lost.
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 200,
              itemsController: controller,
              itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
            ),
          ),
        );
        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position
              ..jumpTo(8000);
        await tester.pump();
        await _focusItem(tester, 100);

        final harness = _harness(tester)
          ..move(100, 40)
          ..insert(0, 500);
        // Each jump of the reach springs back to where the move's jump at
        // the next frame's start landed, so after four the reach gives up
        // and the list jumps back to 8000, the offset before the move; the
        // app then inserts again.
        expect(position.pixels, 8000);
        double? landing;
        var springs = 0;
        var called = false;
        position.addListener(() {
          final at = landing;
          if (at == null) {
            landing = position.pixels;
            return;
          }
          if (springs < 4) {
            if (position.pixels == at) return;
            springs += 1;
            position.jumpTo(at);
            return;
          }
          if (called || position.pixels != 8000) return;
          called = true;
          if (lateCall.currentValue == 'while the list jumps back') {
            harness.insert(0, 900);
          } else {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => harness.insert(0, 900),
            );
          }
        });
        await tester.pumpAndSettle();

        // The data holds item 101 right after the gap item 100 left.
        expect(springs, 4);
        expect(called, isTrue);
        expect(harness.ids[harness.ids.indexOf(99) + 1], 101);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
      },
      variant: lateCall,
    );

    // The item a call removes before item 100 moves down to 112: one the
    // frame built, whose leaving copy keeps its size, or one it did not.
    final removedAbove = ValueVariant<String>({
      'a built item',
      'an item the frame did not build',
    });
    testWidgets(
      's03/inv35: a focused move down past the leaving copy of a built item '
      'removed in the same turn scrolls nothing in the call turn and keeps '
      'its State',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // Either remove puts item 100 at index 99. The leaving copy of item
        // 95 and the closing slot both sit before index 112, so item 100
        // enters slot 114, past the built 93 to 113; with item 10 gone, only
        // the closing slot does, and the item enters the built slot 113.
        final built = removedAbove.currentValue == 'a built item';
        _harness(tester)
          ..remove(built ? 95 : 10)
          ..move(99, 112);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
      variant: removedAbove,
    );

    // A move down that draws no closing slot: under a fixed item extent or
    // reduced motion the slot the item left closes at once.
    final noClosingSlot = ValueVariant<String>({
      'a fixed item extent',
      'reduced motion',
    });
    testWidgets(
      's03/inv35: a focused move down to the last built slot with no closing '
      'slot keeps the list still and the item its State',
      (tester) async {
        final fixed = noClosingSlot.currentValue == 'a fixed item extent';
        if (!fixed) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final position = await pumpAt4000(
          tester,
          itemExtent: fixed ? 40 : null,
        );
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // With nothing drawn before it, item 100 enters slot 113 itself,
        // which the frame built.
        _harness(tester).move(100, 113);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
      variant: noClosingSlot,
    );

    testWidgets(
      's03/inv35: a focused move up past the leaving copy of a built item '
      'removed in the same turn scrolls nothing in the call turn and keeps '
      'its State',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 106);
        final focused = await _focusItem(tester, 106);

        // The remove and nine inserts at the start, which the frame did not
        // build, put item 106 at index 114. Its move up to 113 enters slot
        // 114, past the built 93 to 113, since the leaving copy of item 95
        // sits before it.
        final harness = _harness(tester)..remove(95);
        for (var id = 1000; id < 1009; id++) {
          harness.insert(0, id);
        }
        harness.move(114, 113);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(statesOf(tester, 106), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets(
      's03/inv35: a focused move up to a slot before the first one the frame '
      'built scrolls nothing in the call turn and keeps its State, '
      'though a leaving copy sits before the target',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // The removes of item 93, the first built, and item 10 put item 100
        // at index 98 and item 93's leaving copy at 92. The move up to 92
        // enters before slot 93, where the next frame anchors its layout,
        // so the box before it does not carry it into the built slots.
        _harness(tester)
          ..remove(93)
          ..remove(10)
          ..move(98, 92);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets(
      's03/inv35: a focused move down past an item inserted in view in the '
      'same turn keeps the list still when the slot it enters is built',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // The insert at 95 puts item 100 at index 101 and grows in from
        // 0 px, so it counts nothing, while the closing slot counts one:
        // item 100 enters slot 113, which the frame built.
        _harness(tester)
          ..insert(95, 900)
          ..move(101, 113);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    // Alt+Up on item 1 of a list of two, before the frame of the app's
    // remove: on the item removed, or on the item left.
    final removedOfTwo = ValueVariant<String>({
      'the item removed',
      'the item left',
    });
    testWidgets('fo06/us11/fr02/e02: a reorder key on an item the app removed in the same '
        'turn is handled with no move even with one item left, and a key on '
        'that item left is not handled', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 2, itemsController: controller)),
      );
      await _focusItem(tester, 1);

      final removed = removedOfTwo.currentValue == 'the item removed';
      final harness = _harness(tester)..remove(removed ? 1 : 0);
      final handled = await _alt(tester, LogicalKeyboardKey.arrowUp);

      expect(handled, removed);
      expect(harness.moves, isEmpty);
      expect(harness.ids, [if (removed) 0 else 1]);
    }, variant: removedOfTwo);

    testWidgets('fo06/us11/fr03/e07: a screen-reader move on an item the app removed in the '
        'same turn moves nothing even with one item left', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 2, itemsController: controller)),
      );

      final harness = _harness(tester)..remove(1);
      await _moveAction(tester, 1, 'Move up');

      expect(harness.moves, isEmpty);
      expect(harness.ids, [0]);
      handle.dispose();
    });

    // Where the input lands: while a long press holds item 3 of 5 lifted,
    // or while the drop that carried it past item 4 still settles.
    final dragPhase = ValueVariant<String>({
      'during a drag',
      'while a drop settles',
    });

    // Lifts item 3 of 5, with item 2 focused, and for a settling drop drops
    // it past item 4 with 50 ms of its settle left. Returns the gesture
    // still down, null once it is up, and the onReorderEnd calls so far.
    Future<(TestGesture?, List<int>)> holdThree(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: ReorderableItemsController())),
      );
      await _focusItem(tester, 2);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('3')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      if (dragPhase.currentValue == 'during a drag') {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
        expect(_harness(tester).starts, [3]);
        return (gesture, <int>[]);
      }
      // Left alone, the drop reports the move (3, 4) once it settles.
      await gesture.moveBy(const Offset(0, 100));
      // The lift and the drop's settle each run over the theme's 200 ms
      // normal level.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_harness(tester).starts, [3]);
      expect(_harness(tester).ends, hasLength(1));
      return (null, [..._harness(tester).ends]);
    }

    // After the input moved item 2: a drag ended as a call ends it, or a
    // settling drop completed first (R52).
    void expectDragEndedFirst(
      WidgetTester tester,
      List<int> ends,
      _ItemState state,
    ) {
      final harness = _harness(tester);
      if (ends.isEmpty) {
        // During a drag: the input ends it as a call does, with no move of
        // its own, then moves item 2.
        expect(harness.moves, [(2, 3)]);
        expect(harness.ends, [3]);
        expect(harness.ids, [0, 1, 3, 2, 4]);
      } else {
        // While a drop settles: the input completes the drop at once (R52),
        // then moves item 2.
        expect(harness.moves, [(3, 4), (2, 3)]);
        expect(harness.ends, ends);
        expect(harness.ids, [0, 1, 4, 2, 3]);
      }
      expect(_itemState(tester, 2), same(state));
    }

    testWidgets(
      'fo06/us11/fr02/e08 (R52): a reorder key during a pointer drag ends it first, '
      'or while a drop settles completes it first, and then moves the focused '
      'item',
      (tester) async {
        final (gesture, ends) = await holdThree(tester);
        final state = _itemState(tester, 2);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        expect(tester.takeException(), isNull);
        await gesture?.up();
        await tester.pumpAndSettle();
        expect(handled, isTrue);
        expectDragEndedFirst(tester, ends, state);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 2');
      },
      variant: dragPhase,
    );

    testWidgets('fo06/us11/fr03/e08 (R52): a screen-reader move during a pointer drag ends it '
        'first, or while a drop settles completes it first, and then moves the '
        'item', (tester) async {
      final handle = tester.ensureSemantics();
      final (gesture, ends) = await holdThree(tester);
      final state = _itemState(tester, 2);

      final node = tester.getSemantics(find.byKey(const ValueKey(2)));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move down'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      await gesture?.up();
      await tester.pumpAndSettle();
      expectDragEndedFirst(tester, ends, state);
      handle.dispose();
    }, variant: dragPhase);

    // The input that moves the focused item 4 up while the drop that
    // carried item 3 past it still settles.
    final crossedInput = ValueVariant<String>({'Alt+Up', 'Move up'});
    testWidgets(
      'fo06/us11/fr02/e08 and fo06/us11/fr03/e08 (R52): a key or screen-reader move of '
      'the focused item a settling drop carried an item past reads the data '
      "after the drop's move, so the item moves up from its new slot",
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: ReorderableItemsController()),
          ),
        );
        await _focusItem(tester, 4);
        final state = _itemState(tester, 4);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('3')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        // Left alone, the drop reports the move (3, 4) once it settles.
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final harness = _harness(tester);
        expect(harness.moves, isEmpty);
        expect(harness.ends, hasLength(1));

        if (crossedInput.currentValue == 'Alt+Up') {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp), isTrue);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        } else {
          final node = tester.getSemantics(find.byKey(const ValueKey(4)));
          node.owner!.performAction(
            node.id,
            SemanticsAction.customAction,
            CustomSemanticsAction.getIdentifier(
              const CustomSemanticsAction(label: 'Move up'),
            ),
          );
        }
        await tester.pumpAndSettle();

        // The drop completes first, item 4 then sits at 3, and the input
        // moves it from there.
        expect(tester.takeException(), isNull);
        expect(harness.moves, [(3, 4), (3, 2)]);
        expect(harness.ids, [0, 1, 4, 2, 3]);
        expect(harness.ends, hasLength(1));
        expect(_itemState(tester, 4), same(state));
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 4');
        handle.dispose();
      },
      variant: crossedInput,
    );

    // The input that moves item 5 to the end right after the app inserts
    // an item at the end of its data.
    final endInput = ValueVariant<String>({'Alt+End', 'Move to the end'});
    testWidgets(
      'fo06/us11/fr03/e07: a key or screen-reader move to the end past an item a '
      'call of its turn grows in shows the moved item once that grow-in ends',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller)),
        );
        await _focusItem(tester, 5);

        // The inserted item grows in just before item 5's new slot, the last.
        final harness = _harness(tester)..insert(200, 900);
        if (endInput.currentValue == 'Alt+End') {
          expect(await _alt(tester, LogicalKeyboardKey.end), isTrue);
        } else {
          await _moveAction(tester, 5, 'Move to the end');
        }

        expect(harness.moves, [(5, 200)]);
        expect(harness.ids.sublist(199), [900, 5]);
        expect(find.byKey(const ValueKey(5)), findsOne);
        expect(_itemInView(tester, 5), isTrue);
        handle.dispose();
      },
      variant: endInput,
    );

    testWidgets(
      's03/inv29: a moved item the app removes before a grow-in before it '
      'ends takes no second reveal',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );

        // A screen-reader move of item 5 in the turn of an insert at the
        // start, which grows in before the item's new place.
        final harness = _harness(tester)..insert(0, 500);
        final node = tester.getSemantics(find.byKey(const ValueKey(5)));
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            const CustomSemanticsAction(label: 'Move down'),
          ),
        );
        await tester.pump();
        expect(harness.ids.indexOf(5), 7);
        // The app removes the moved item; its exit ends before the grow-in.
        harness.remove(7);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        await tester.pump();
        expect(
          find.byKey(const ValueKey(5), skipOffstage: false),
          findsNothing,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: an app insert from the scroll listener of a focused '
      "move's jump at the next frame's start leaves the give-up handoff on "
      'the item after the gap',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump at
        // the next frame's start lands short of slot 40.
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 200,
              itemsController: controller,
              itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
            ),
          ),
        );
        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position
              ..jumpTo(8000);
        await tester.pump();
        await _focusItem(tester, 100);

        // The app inserts at the start from inside the scroll notification
        // of the move's jump at the next frame's start; each jump of the
        // reach then springs back to where that jump landed, so the reach
        // gives up and hands focus on.
        final harness = _harness(tester);
        double? landing;
        var springs = 0;
        position.addListener(() {
          if (landing == null) {
            landing = position.pixels;
            harness.insert(0, 900);
            return;
          }
          if (springs == 4 || position.pixels == landing) return;
          springs += 1;
          position.jumpTo(landing!);
        });
        harness.move(100, 40);
        await tester.pumpAndSettle();

        // The data holds item 101 right after the gap item 100 left.
        expect(springs, 4);
        expect(harness.ids[harness.ids.indexOf(99) + 1], 101);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
      },
    );
  });

  group('ReorderableListViewLayout unbuilt slots of moveItem', () {
    // 200 items of 40 px in a 300 px viewport at 4000 px, with the default
    // 250 px cache extent: the sliver lays out slots 93 to 113. A move down
    // enters the slot after its target, since its closing slot counts one.
    _Harness list({
      Map<int, double>? heights,
      double? itemExtent,
      ScrollCacheExtent? scrollCacheExtent,
      Axis axis = Axis.vertical,
      bool reverse = false,
    }) => _Harness(
      count: 200,
      itemsController: ReorderableItemsController(),
      heights: heights,
      itemExtent: itemExtent,
      scrollCacheExtent: scrollCacheExtent,
      axis: axis,
      reverse: reverse,
    );

    // Slots past the last laid-out one that item 100 enters.
    final pastLast = ValueVariant<int>({1, 2, 5});
    testWidgets(
      'fo06/us11/fr05/e04: a focused move to a near slot past the last laid-out '
      'one scrolls nothing in the call turn and keeps State and focus',
      (tester) async {
        final position = await _pumpScrolled(tester, list());
        expect(_laidOut(tester), (first: 93, last: 113, count: 21));
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);
        final k = pastLast.currentValue!;

        _harness(tester).move(100, 112 + k);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(_laidOut(tester).last, greaterThanOrEqualTo(113 + k));
        expect(_statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(_statesOf(tester, 100), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 100), isTrue);
      },
      variant: pastLast,
    );

    // Slots before the first laid-out one that item 100 enters.
    final beforeFirst = ValueVariant<int>({1, 2});
    testWidgets(
      'fo06/us11/fr05/e04: a focused move to a near slot before the first '
      'laid-out one scrolls nothing in the call turn and keeps State '
      'and focus',
      (tester) async {
        final position = await _pumpScrolled(tester, list());
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);
        final d = beforeFirst.currentValue!;

        _harness(tester).move(100, 93 - d);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(_laidOut(tester).first, lessThanOrEqualTo(93 - d));
        expect(_statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(_statesOf(tester, 100), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 100), isTrue);
      },
      variant: beforeFirst,
    );

    // (k + 1) x 40 px past one 300 px viewport: k = 7 is the first far one.
    final farPast = ValueVariant<int>({7, 10, 30});
    testWidgets('fo06/us11/fr05/e04: a focused move to a slot whose distance plus one slot '
        'exceeds one viewport scrolls nothing in the call turn, jumps at the '
        "next frame's start, and keeps State and focus", (tester) async {
      final position = await _pumpScrolled(tester, list());
      final state = _itemState(tester, 100);
      final focused = await _focusItem(tester, 100);

      _harness(tester).move(100, 112 + farPast.currentValue!);
      expect(position.pixels, 4000);
      await tester.pump();
      expect(position.pixels, isNot(4000));

      expect(_statesOf(tester, 100), contains(state));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_builtInView(tester, 100), isTrue);
    }, variant: farPast);

    testWidgets(
      'fo06/us11/fr05/e04: a near move whose unbuilt items run taller than the '
      'laid-out average falls back to the reach, and the item keeps its '
      'State and focus off screen and shows on screen',
      (tester) async {
        // Items 114 and 115 are 200 px, so slot 117, which item 100 enters,
        // lies past the frame that the 40 px average lays out.
        final position = await _pumpScrolled(
          tester,
          list(heights: const {114: 200, 115: 200}),
        );
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        _harness(tester).move(100, 116);
        expect(position.pixels, 4000);
        await tester.pumpAndSettle();

        expect(_statesOf(tester, 100), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: under a fixed item extent the estimate is exact, so '
      'the same tall items never make the move miss',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          list(heights: const {114: 200, 115: 200}, itemExtent: 40),
        );
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // No closing slot under a fixed extent: item 100 enters slot 116.
        _harness(tester).move(100, 116);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(_statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets(
      's03/inv35: a same-turn removeItem and insertItem of one key before a '
      "focused near move books one unneeded jump at the next frame's start, "
      'with State and focus kept',
      (tester) async {
        final position = await _pumpScrolled(tester, list());
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // The leaving copy of item 95 over-counts one box: the entered-slot
        // count reads 114 where the frame puts item 100 at 113.
        _harness(tester)
          ..remove(95)
          ..insert(95, 95)
          ..move(100, 113);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(position.pixels, isNot(4000));
        expect(_statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets(
      's03/inv35: when two average extents exceed one viewport, the same-turn '
      'remove and insert over-count can still book one jump for the '
      "next frame's start, with State and focus kept",
      (tester) async {
        // 200 px items: the sliver lays out 18 to 22 at 4000 px, and one slot
        // plus the margin, 400 px, exceeds the 300 px viewport.
        final position = await _pumpScrolled(
          tester,
          list(heights: {for (var id = 0; id < 200; id++) id: 200}),
        );
        expect(_laidOut(tester), (first: 18, last: 22, count: 5));
        final state = _itemState(tester, 20);
        final focused = await _focusItem(tester, 20);

        // Item 20 enters slot 22, which the frame laid out, but the leaving
        // copy of item 19 over-counts one box and reads slot 23.
        _harness(tester)
          ..remove(19)
          ..insert(19, 19)
          ..move(20, 22);
        expect(position.pixels, 4000);
        await tester.pump();
        expect(position.pixels, isNot(4000));

        expect(_statesOf(tester, 20), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: a viewport-relative scrollCacheExtent reaches the '
      'viewport unchanged: a focused move just past the laid-out slots lays '
      'out no more slots and keeps State and focus',
      (tester) async {
        // Half a 300 px viewport, 150 px: the sliver lays out 96 to 111.
        final position = await _pumpScrolled(
          tester,
          list(scrollCacheExtent: const ScrollCacheExtent.viewport(0.5)),
        );
        expect(_laidOut(tester), (first: 96, last: 111, count: 16));
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // Item 100 enters slot 113, 2 slots past 111.
        _harness(tester).move(100, 112);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(_laidOut(tester).count, lessThanOrEqualTo(17));
        expect(_statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    final axes = ValueVariant<String>({
      'horizontal',
      'reversed',
      'right-to-left',
    });
    testWidgets(
      'fo06/us11/fr05/e04: a focused move past the last laid-out slot scrolls '
      'nothing in the call turn and keeps State and focus on a horizontal, '
      'reversed, or right-to-left list',
      (tester) async {
        final variant = axes.currentValue!;
        final position = await _pumpScrolled(
          tester,
          list(
            axis: variant == 'reversed' ? Axis.vertical : Axis.horizontal,
            reverse: variant == 'reversed',
          ),
          textDirection: variant == 'right-to-left'
              ? TextDirection.rtl
              : TextDirection.ltr,
        );
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // Item 100 enters the slot after the last laid-out one.
        _harness(tester).move(100, _laidOut(tester).last);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(_statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 100), isTrue);
      },
      variant: axes,
    );

    final motion = ValueVariant<String>({'motion', 'reduced motion'});
    testWidgets(
      's03/inv35: a focused move to a near unbuilt slot lays out the base '
      "cache extent in the move's frame and after it, never a wider one",
      (tester) async {
        if (motion.currentValue == 'reduced motion') {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        expect(_laidOut(tester).count, 21);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        _harness(tester).move(100, 114);
        expect(position.pixels, 4000);
        await tester.pump();
        expect(_laidOut(tester).count, lessThanOrEqualTo(22));
        expect(_statesOf(tester, 100), contains(state));

        await tester.pump();
        expect(_laidOut(tester).count, lessThanOrEqualTo(22));
        await tester.pumpAndSettle();
        expect(_laidOut(tester).count, 21);
        expect(_statesOf(tester, 100), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
      variant: motion,
    );

    testWidgets(
      'fo06/us11/fr05/e08: a second focused move the app defers into the first '
      "move's post-frame batch keeps its own State, as the first move kept "
      'its own',
      (tester) async {
        await _pumpScrolled(tester, list());
        final stateA = _itemState(tester, 100);
        await _focusItem(tester, 100);

        // The first move books its jump for the frame this pump builds.
        _harness(tester).move(100, 114);
        // The app's own deferred call (FR-05 E08): item 120, a different
        // item that frame 1 lays out, takes focus and moves far, but only
        // once frame 1's post-frame batch runs, so its jump is booked for
        // frame 2.
        late _ItemState stateB;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          stateB = _itemState(tester, 120);
          stateB.node.requestFocus();
          FocusManager.instance.applyFocusChangesIfNeeded();
          _harness(tester).move(_harness(tester).ids.indexOf(120), 170);
        });
        await tester.pump();

        // Frame 1 ran the first jump alone: item 100 kept its State.
        expect(_statesOf(tester, 100), contains(stateA));
        await tester.pump();

        // Frame 2 runs the second jump: item 120 keeps its State too.
        expect(_statesOf(tester, 120), contains(stateB));
        await tester.pumpAndSettle();
        expect(_statesOf(tester, 120), contains(stateB));
        expect(FocusManager.instance.primaryFocus, same(stateB.node));
        expect(_builtInView(tester, 120), isTrue);
      },
    );
  });

  group('ReorderableListViewLayout unbuilt slots by key and screen reader', () {
    // Alt+Up from the first laid-out item, 93, or Alt+Down from the last,
    // 113, at 4000 px.
    final edges = ValueVariant<String>({'Alt+Up from 93', 'Alt+Down from 113'});
    testWidgets(
      'fo06/us11/fr03/e09: Alt and an arrow to a near unbuilt slot scrolls '
      'nothing in the turn of the key and keeps State and focus',
      (tester) async {
        final up = edges.currentValue == 'Alt+Up from 93';
        final id = up ? 93 : 113;
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        final state = _itemState(tester, id);
        final focused = await _focusItem(tester, id);

        await _altNow(
          tester,
          up ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowDown,
        );
        expect(position.pixels, 4000);
        await tester.pump();

        expect(_statesOf(tester, id), contains(state));
        await tester.pump();
        // The list lays out the base extent: it never widens it.
        expect(_laidOut(tester).count, lessThanOrEqualTo(22));
        await tester.pumpAndSettle();
        expect(_statesOf(tester, id), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, id), isTrue);
      },
      variant: edges,
    );

    // With no cache extent the sliver lays out 100 to 107 at 4020 px.
    final actions = ValueVariant<String>({'Move up', 'Move down'});
    testWidgets(
      'fo06/us11/fr03/e09: a screen-reader move of one slot to a near unbuilt '
      'slot scrolls nothing in the turn of the action and keeps State and '
      'focus',
      (tester) async {
        final handle = tester.ensureSemantics();
        final up = actions.currentValue == 'Move up';
        final id = up ? 100 : 107;
        final position = await _pumpScrolled(
          tester,
          const _Harness(
            count: 200,
            scrollCacheExtent: ScrollCacheExtent.pixels(0),
          ),
          offset: 4020,
        );
        expect(_laidOut(tester), (first: 100, last: 107, count: 8));
        final state = _itemState(tester, id);
        final focused = await _focusItem(tester, id);

        final node = tester.getSemantics(find.byKey(ValueKey(id)));
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            CustomSemanticsAction(label: actions.currentValue!),
          ),
        );
        expect(position.pixels, 4020);
        await tester.pump();

        expect(_statesOf(tester, id), contains(state));
        await tester.pumpAndSettle();
        expect(_statesOf(tester, id), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, id), isTrue);
        handle.dispose();
      },
      variant: actions,
    );

    testWidgets('fo06/us11/fr03/e09: Alt and an arrow to a far unbuilt slot scrolls nothing '
        "in the turn of the key, jumps at the next frame's start, and keeps "
        'State and focus', (tester) async {
      // 200 px items: one slot plus the margin, 400 px, exceeds the 300 px
      // viewport. The sliver lays out 18 to 22 at 4000 px.
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          heights: {for (var id = 0; id < 200; id++) id: 200},
        ),
      );
      expect(_laidOut(tester), (first: 18, last: 22, count: 5));
      final state = _itemState(tester, 22);
      final focused = await _focusItem(tester, 22);

      await _altNow(tester, LogicalKeyboardKey.arrowDown);
      expect(position.pixels, 4000);
      await tester.pump();
      expect(position.pixels, isNot(4000));

      expect(_statesOf(tester, 22), contains(state));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_builtInView(tester, 22), isTrue);
    });

    testWidgets('fo06/us11/fr03/e09: Alt and an arrow past an unbuilt item taller than the '
        'laid-out average falls back to the reach, and the item keeps its '
        'State and focus off screen and shows on screen', (tester) async {
      // Item 114 is 400 px, so after Alt+Down item 113 sits past the frame
      // the 40 px average lays out.
      final position = await _pumpScrolled(
        tester,
        const _Harness(count: 200, heights: {114: 400}),
      );
      final state = _itemState(tester, 113);
      final focused = await _focusItem(tester, 113);

      await _altNow(tester, LogicalKeyboardKey.arrowDown);
      expect(position.pixels, 4000);
      await tester.pumpAndSettle();

      expect(_statesOf(tester, 113), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_builtInView(tester, 113), isTrue);
    });

    testWidgets(
      'fo06/us11/fr03/e09: Alt and an arrow to an unbuilt edge slot far off '
      "jumps exactly to that edge at the next frame's start and keeps State "
      'and focus',
      (tester) async {
        // Item 0 is 2000 px and the rest 200 px. At 2300 px the sliver lays
        // out from slot 1, whose 200 px average puts slot 0 at 1800 px, short
        // of the start, where the exact jump lands.
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: {
              for (var id = 0; id < 200; id++) id: id == 0 ? 2000 : 200,
            },
          ),
          offset: 2300,
        );
        expect(_laidOut(tester).first, 1);
        final state = _itemState(tester, 1);
        final focused = await _focusItem(tester, 1);

        await _altNow(tester, LogicalKeyboardKey.arrowUp);
        expect(position.pixels, 2300);
        await tester.pump();
        expect(position.pixels, 0);

        expect(_statesOf(tester, 1), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 1), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr03/e09: a screen-reader step action a same-turn removeItem '
      'shifts to data slot 0 does not edge-jump in the turn of the action',
      (tester) async {
        final handle = tester.ensureSemantics();
        // With no cache extent the built range is the viewport exactly, so
        // scrolling to item 2's own top excludes slots 0 and 1 from it.
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            itemsController: ReorderableItemsController(),
          ),
          offset: 90,
        );
        expect(_laidOut(tester).first, 2);

        // Same turn: removing data slot 0 shifts item 2 to data slot 1, so
        // its "Move up" (a step, not a start action by D2's own reading of
        // the frame indices) targets data slot 0.
        _harness(tester).remove(0);
        final node = tester.getSemantics(find.byKey(const ValueKey(2)));
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            const CustomSemanticsAction(label: 'Move up'),
          ),
        );

        expect(position.pixels, 90);
        handle.dispose();
      },
    );

    testWidgets('fo06/us11/fr03/e09: when the reach after a far key move gives up, the list '
        "returns to the offset before the jump at the next frame's start and "
        'hands focus on from the slot the item left', (tester) async {
      // 200 px items and item 23 at 1200 px: the sliver lays out 18 to 22
      // at 4000 px. Alt+Down on item 22 enters slot 23, so the next
      // frame's start jumps by the 200 px average to 4600, where item 23,
      // now in slot 22, leaves slot 23 at 5600, past the frame.
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          heights: {for (var id = 0; id < 200; id++) id: id == 23 ? 1200 : 200},
        ),
      );
      expect(_laidOut(tester), (first: 18, last: 22, count: 5));
      await _focusItem(tester, 22);

      await _altNow(tester, LogicalKeyboardKey.arrowDown);
      expect(position.pixels, 4000);
      final moves = <double>[];
      position.addListener(() => moves.add(position.pixels));
      await tester.pumpAndSettle();

      // The 200 px average still puts slot 23 at 4600, so each jump of the
      // reach, a probe that always moves to the plain edge, lands where
      // the key's jump did and the reach gives up: the list's next move
      // is back to 4000, and item 23, now in the slot item 22 left,
      // takes focus.
      expect(moves.take(2), [4600, 4000]);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 23');
    });

    // A later call of the key's turn: none, or an insert at index 0, before
    // the slot the item leaves, which that slot follows.
    final laterCall = ValueVariant<String>({'none', 'an insert before'});
    testWidgets(
      'fo06/us11/fr03/e09: when the reach after a key move gives up, focus goes on '
      'from the slot the item left, as a later call of the turn moved it',
      (tester) async {
        // Item 112 is 400 px, laid out at 4000 px: after Alt+Down on item
        // 111 it fills slot 111, so the moved item's slot, laid out before
        // the move, lies past the frame. With the list held at 4000, each
        // jump of the reach springs back and the reach gives up.
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            heights: const {112: 400},
          ),
        );
        await _focusItem(tester, 111);

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        if (laterCall.currentValue != 'none') _harness(tester).insert(0, 500);
        var springs = 0;
        _pinScroll(tester, 4000, onSpringBack: () => springs += 1);
        await tester.pumpAndSettle();

        // Four jumps of the reach and the handoff's reveal sprang back. The
        // item after the slot item 111 left is item 112, at index 111, or at
        // 112 after the insert.
        expect(position.pixels, 4000);
        expect(springs, 5);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 112');
      },
      variant: laterCall,
    );

    testWidgets(
      'fo06/us11/fr03/e09 and s03/inv32: Alt+Down from item 113 at 4000 lands '
      'item 114 at the bottom edge',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 1000),
        );
        await _focusItem(tester, 113);

        await _alt(tester, LogicalKeyboardKey.arrowDown);

        // Slot 114's 40 px average puts its leading edge at 4560; the
        // least scroll landing from below stops at the trailing edge.
        expect(position.pixels, 4300);
        expect(_builtInView(tester, 113), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04 and s03/inv32: a moveItem far down lands the item at '
      'the bottom edge',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(count: 1000, itemsController: ReorderableItemsController()),
        );
        await _focusItem(tester, 100);

        _harness(tester).move(100, 150);
        await tester.pumpAndSettle();

        // Slot 150's 40 px average puts its leading edge at 6000, the
        // probe's landing; the landing reveal clamps it to the least
        // scroll from 4000, its trailing edge, and the item's own
        // grow-in reveal, once settled, corrects that estimate to its
        // real bottom edge.
        final bottom = tester.getBottomLeft(find.byKey(const ValueKey(100))).dy;
        final viewBottom = tester.getBottomLeft(find.byType(Scrollable)).dy;
        expect(bottom, viewBottom);
        expect(_itemInView(tester, 100), isTrue);
      },
    );

    // The same three landings, run over a list whose items from id 110 on
    // are 60 px: Alt+Down from item 113, a far moveItem of item 100, and
    // an insertItem that shifts item 107 past the laid-out slots (D29, G5).
    final tallerScenes = ValueVariant<String>({
      'Alt+Down',
      'moveItem',
      'insertItem',
    });
    testWidgets('fo06/us11/fr05/e04 and s03/inv32: with taller items past the built ones, '
        'the landing still ends at the bottom edge', (tester) async {
      final heights = {for (var id = 110; id < 1000; id++) id: 60.0};
      late int id;
      switch (tallerScenes.currentValue) {
        case 'Alt+Down':
          id = 113;
          // Item 113's own top, 4580, sits just inside the cache past
          // the taller items from 110 on; item 114's, 4640, sits just
          // past it, unbuilt.
          await _pumpScrolled(
            tester,
            _Harness(count: 1000, heights: heights),
            offset: 4070,
          );
          await _focusItem(tester, id);
          await _alt(tester, LogicalKeyboardKey.arrowDown);
        case 'moveItem':
          id = 100;
          await _pumpScrolled(
            tester,
            _Harness(
              count: 1000,
              heights: heights,
              itemsController: ReorderableItemsController(),
            ),
          );
          await _focusItem(tester, id);
          _harness(tester).move(100, 150);
          await tester.pumpAndSettle();
        default:
          id = 107;
          await _pumpScrolled(
            tester,
            _Harness(
              count: 1000,
              heights: heights,
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              itemsController: ReorderableItemsController(),
            ),
            offset: 4020,
          );
          await _focusItem(tester, id);
          _harness(tester).insert(0, 5000);
          await tester.pumpAndSettle();
      }

      final bottom = tester.getBottomLeft(find.byKey(ValueKey(id))).dy;
      final viewBottom = tester.getBottomLeft(find.byType(Scrollable)).dy;
      expect(bottom, viewBottom);
      expect(_itemInView(tester, id), isTrue);
    }, variant: tallerScenes);
  });

  group('ReorderableListViewLayout key and screen-reader moves and an app '
      'scroll listener', () {
    // The app's listener on the list's scroll position inserts item 900 at
    // index 0, through the controller and its data, on the first
    // notification it gets: the one the move's jump at the next frame's
    // start sends.
    void insertOnFirstScroll(WidgetTester tester, ScrollPosition position) {
      final harness = _harness(tester);
      var inserted = false;
      position.addListener(() {
        if (inserted) return;
        inserted = true;
        harness.insert(0, 900);
      });
    }

    // 200 px items with no cache extent: the sliver lays out 19 to 21 at
    // 4000 px, and one slot plus the margin, 400 px, exceeds the 300 px
    // viewport, so a one-slot move of item 21 down jumps in its turn.
    Future<ScrollPosition> pumpTall(WidgetTester tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          itemsController: ReorderableItemsController(),
          scrollCacheExtent: const ScrollCacheExtent.pixels(0),
          heights: {for (var id = 0; id < 200; id++) id: 200},
        ),
      );
      expect(_laidOut(tester), (first: 19, last: 21, count: 3));
      return position;
    }

    testWidgets('fo06/us11/fr03/e10: an app insert from the scroll listener of the jump of '
        'Alt+Home lands the moved item right after the inserted one, with its '
        'State and focus', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
      );
      final state = _itemState(tester, 100);
      final focused = await _focusItem(tester, 100);
      insertOnFirstScroll(tester, position);

      await _altNow(tester, LogicalKeyboardKey.home);
      await tester.pumpAndSettle();

      expect(_harness(tester).ids.take(3), [900, 100, 0]);
      expect(_statesOf(tester, 100), contains(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_builtInView(tester, 100), isTrue);
    });

    testWidgets('fo06/us11/fr03/e10: an app insert from the scroll listener of the jump of '
        'a "Move to the start" action lands the moved item right after the '
        'inserted one, with its State and focus', (tester) async {
      final handle = tester.ensureSemantics();
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
      );
      final state = _itemState(tester, 100);
      final focused = await _focusItem(tester, 100);
      insertOnFirstScroll(tester, position);

      await _moveAction(tester, 100, 'Move to the start');

      expect(_harness(tester).ids.take(3), [900, 100, 0]);
      expect(_statesOf(tester, 100), contains(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_builtInView(tester, 100), isTrue);
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr03/e10: an app insert from the scroll listener of the far '
      'jump of Alt+Down lands the moved item right after the item it '
      'passed, with its State and focus',
      (tester) async {
        final position = await pumpTall(tester);
        final state = _itemState(tester, 21);
        final focused = await _focusItem(tester, 21);
        insertOnFirstScroll(tester, position);

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        final ids = _harness(tester).ids;
        expect(ids.first, 900);
        expect(ids.sublist(22, 25), [22, 21, 23]);
        expect(_statesOf(tester, 21), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 21), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr03/e10: an app insert from the scroll listener of the far '
      'jump of a "Move down" action lands the moved item right after '
      'the item it passed, with its State and focus',
      (tester) async {
        final handle = tester.ensureSemantics();
        final position = await pumpTall(tester);
        final state = _itemState(tester, 21);
        final focused = await _focusItem(tester, 21);
        insertOnFirstScroll(tester, position);

        await _moveAction(tester, 21, 'Move down');

        final ids = _harness(tester).ids;
        expect(ids.first, 900);
        expect(ids.sublist(22, 25), [22, 21, 23]);
        expect(_statesOf(tester, 21), contains(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 21), isTrue);
        handle.dispose();
      },
    );

    testWidgets('fo06/us11/fr03/e02: an app that takes the moved item out of the data and '
        'the controller from onReorderItem of Alt+End leaves no jump and '
        'throws nothing after the frame', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
      );
      await _focusItem(tester, 100);
      final harness = _harness(tester)
        ..onMove = (_, to) => _harness(tester).remove(to);

      await _altNow(tester, LogicalKeyboardKey.end);

      expect(position.pixels, 4000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(harness.ids.contains(100), isFalse);
    });
  });

  void keptAliveSlotsTests() {
    // Item 50 keeps itself alive: shown once at 2000 px, it stays mounted
    // after the list scrolls to 4000 px, outside the sliver's child list.
    Future<ScrollPosition> pumpKeptAlive(WidgetTester tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          itemsController: ReorderableItemsController(),
          keepAliveIds: const {50},
        ),
        offset: 2000,
      );
      position.jumpTo(4000);
      await tester.pump();
      expect(_statesOf(tester, 50), hasLength(1));
      expect(_laidOut(tester), (first: 93, last: 113, count: 21));
      return position;
    }

    testWidgets(
      'fo06/us11/fr05/e12: a kept-alive item never counts as built, so a far move '
      "into its slot jumps at the next frame's start and keeps its State",
      (tester) async {
        final position = await pumpKeptAlive(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        _harness(tester).move(100, 50);
        expect(position.pixels, 4000);
        await tester.pump();
        expect(position.pixels, isNot(4000));

        expect(_statesOf(tester, 100), contains(state));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets('fo06/us11/fr05/e12: a kept-alive item never counts as built, so it never '
        "stops a near move's jump at the next frame's start", (tester) async {
      final position = await pumpKeptAlive(tester);
      final state = _itemState(tester, 100);
      final focused = await _focusItem(tester, 100);

      // After the insert item 100 sits at index 101 and enters slot 114.
      _harness(tester)
        ..insert(70, 9000)
        ..move(101, 113);
      expect(position.pixels, 4000);
      await tester.pump();

      expect(_statesOf(tester, 100), contains(state));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focused));
    });
  }

  group(
    'ReorderableListViewLayout unbuilt slots and kept-alive items',
    keptAliveSlotsTests,
  );

  group('ReorderableListViewLayout unbuilt slot and a focus the app moves', () {
    testWidgets(
      'fo06/us11/fr05/e11: a focus the app moves in the turn of a near move '
      "stays, the list skips the move's jump, and the moved item is not kept "
      'alive',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 100);
        await _focusItem(tester, 100);
        final other = _itemState(tester, 101).node;

        _harness(tester).move(100, 114);
        other.requestFocus();
        expect(position.pixels, 4000);
        await tester.pump();

        // Counted as unfocused, item 100 keeps no State in slot 115.
        expect(_laidOut(tester).last, lessThanOrEqualTo(113));
        expect(_statesOf(tester, 100), isNot(contains(state)));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(_builtInView(tester, 101), isTrue);
        expect(position.pixels, 4000);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e11: a focus the app moves in the turn of a far move stays, '
      "and the list skips the move's jump at the next frame's start",
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        await _focusItem(tester, 100);
        final other = _itemState(tester, 101).node;
        final moves = <double>[];
        position.addListener(() => moves.add(position.pixels));

        _harness(tester).move(100, 150);
        other.requestFocus();
        expect(position.pixels, 4000);
        await tester.pump();

        expect(moves, isEmpty);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(_builtInView(tester, 101), isTrue);
        expect(position.pixels, 4000);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e11: a far move of a second item the app focuses in the '
      "same turn as a first item's far move keeps the second item's own "
      "jump, not the first's offset",
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        await _focusItem(tester, 100);
        final otherState = _itemState(tester, 101);
        final other = otherState.node;

        // Both far moves run before any frame: the first (item 100) queues
        // its own origin, 4000; the app then focuses item 101 and moves it
        // far too, queuing an origin that is already item 100's jumped
        // offset, not 4000.
        _harness(tester).move(100, 150);
        other.requestFocus();
        // The app's own focus change lands in the focus tree before the
        // next moveItem call reads hasFocus, as it would after a real
        // frame's focus-change pass.
        FocusManager.instance.applyFocusChangesIfNeeded();
        _harness(tester).move(_harness(tester).ids.indexOf(101), 160);
        await tester.pump();

        // Item 101's own jump stays, at its own estimate: the frame never
        // reverts to item 100's origin of 4000, which would scroll item
        // 101 back off screen. The landing reveal that follows the jump
        // commits at the next frame's start and clamps the estimate to the
        // least scroll from item 101's own origin, 20 px short of it.
        // R56: the list commits its scroll at the next frame's start
        // (D13 frame shift).
        await tester.pump();
        expect(position.pixels, 6160.0);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(_statesOf(tester, 101), contains(otherState));
        expect(_builtInView(tester, 101), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e11: a far move of a first item the app refocuses after a '
      "second item's far move in the same turn runs only the first item's "
      "jump at the next frame's start, toward its slot after both calls",
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final aState = _itemState(tester, 100);
        final a = await _focusItem(tester, 100);
        final b = _itemState(tester, 101).node;

        // Both far moves run before any frame and each books a jump; the
        // app then puts focus back on item 100 before the frame runs.
        _harness(tester).move(100, 150);
        b.requestFocus();
        FocusManager.instance.applyFocusChangesIfNeeded();
        _harness(tester).move(_harness(tester).ids.indexOf(101), 160);
        a.requestFocus();
        FocusManager.instance.applyFocusChangesIfNeeded();
        expect(position.pixels, 4000);
        await tester.pump();

        // Item 101's jump is skipped, since the app took its focus; item
        // 100's probe runs toward index 149, where item 101's move from
        // before it left it, by the 40 px average.
        expect(position.pixels, 149 * 40.0);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(a));
        expect(_statesOf(tester, 100), contains(aState));
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets('fo06/us11/fr05/e11: three far moves in one turn, with the app refocusing '
        "the middle item, run only the middle item's jump at the next frame's "
        'start', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
      );
      final bState = _itemState(tester, 101);
      await _focusItem(tester, 100);
      final b = bState.node;
      final c = _itemState(tester, 102).node;

      // Three far moves run before any frame, each booking a jump. The
      // app then puts focus back on item 101, the middle move, before the
      // frame runs.
      _harness(tester).move(100, 150);
      b.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      _harness(tester).move(_harness(tester).ids.indexOf(101), 160);
      c.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      _harness(tester).move(_harness(tester).ids.indexOf(102), 170);
      b.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      expect(position.pixels, 4000);
      await tester.pump();

      // Only item 101's probe jump runs, toward index 159, where item
      // 102's move from before it left it, by the 40 px average.
      expect(position.pixels, 159 * 40.0);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(b));
      expect(_statesOf(tester, 101), contains(bState));
      expect(_builtInView(tester, 101), isTrue);
    });

    testWidgets(
      'fo06/us11/fr03/e09: a focus the app moves in the turn of Alt+Down to a '
      "near unbuilt slot stays, the list skips the move's jump, and the "
      'moved item is not kept alive',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        final state = _itemState(tester, 113);
        await _focusItem(tester, 113);
        final other = _itemState(tester, 101).node;
        _harness(tester).onMove = (_, _) => other.requestFocus();

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(_statesOf(tester, 113), isNot(contains(state)));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(_builtInView(tester, 101), isTrue);
        expect(position.pixels, 4000);
      },
    );

    testWidgets(
      'fo06/us11/fr03/e09: a focus the app moves in the turn of a far Alt+Down '
      "stays, and the list skips the move's jump at the next frame's start",
      (tester) async {
        // 200 px items: the sliver lays out 18 to 22 at 4000 px, and one slot
        // plus the margin exceeds the viewport, so Alt+Down on 22 jumps.
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: {for (var id = 0; id < 200; id++) id: 200},
          ),
        );
        await _focusItem(tester, 22);
        final other = _itemState(tester, 20).node;
        _harness(tester).onMove = (_, _) => other.requestFocus();

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        expect(position.pixels, 4000);
        await tester.pump();

        expect(position.pixels, 4000);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(_builtInView(tester, 20), isTrue);
        expect(position.pixels, 4000);
      },
    );

    testWidgets('fo06/us11/fr03/e09: a focus the app moves in the turn of a screen-reader '
        "move to a near unbuilt slot stays, the list skips the move's jump, "
        'and the moved item is not kept alive', (tester) async {
      final handle = tester.ensureSemantics();
      // With no cache extent the sliver lays out 100 to 107 at 4020 px.
      final position = await _pumpScrolled(
        tester,
        const _Harness(
          count: 200,
          scrollCacheExtent: ScrollCacheExtent.pixels(0),
        ),
        offset: 4020,
      );
      final state = _itemState(tester, 107);
      await _focusItem(tester, 107);
      final other = _itemState(tester, 101).node;
      _harness(tester).onMove = (_, _) => other.requestFocus();

      final node = tester.getSemantics(find.byKey(const ValueKey(107)));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move down'),
        ),
      );
      expect(position.pixels, 4020);
      await tester.pump();

      expect(_statesOf(tester, 107), isNot(contains(state)));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(other));
      expect(_builtInView(tester, 101), isTrue);
      expect(position.pixels, 4020);
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr03/e09: a focus the app moves in the turn of a far '
      "screen-reader move stays, and the list skips the move's jump at the "
      "next frame's start",
      (tester) async {
        final handle = tester.ensureSemantics();
        // 200 px items with no cache extent: the sliver lays out 20 and 21
        // at 4050 px, the built range the viewport itself, so the first
        // built item has a semantics node, and one slot plus the margin
        // past it exceeds the viewport, the far path the Alt+Down case
        // above proves (D2).
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: {for (var id = 0; id < 200; id++) id: 200},
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
          ),
          offset: 4050,
        );
        await _focusItem(tester, 20);
        final other = _itemState(tester, 21).node;
        _harness(tester).onMove = (_, _) => other.requestFocus();

        final node = tester.getSemantics(find.byKey(const ValueKey(20)));
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            const CustomSemanticsAction(label: 'Move up'),
          ),
        );
        expect(position.pixels, 4050);
        await tester.pump();

        expect(position.pixels, 4050);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(position.pixels, 4050);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr03/e09: a focus the app moves outside the list in the turn of '
      'Alt+Down to a built slot stays, and the list never pulls it back',
      (tester) async {
        final outside = FocusNode(debugLabel: 'outside');
        addTearDown(outside.dispose);
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                Focus(focusNode: outside, child: const SizedBox()),
                const Expanded(child: _Harness(count: 5)),
              ],
            ),
          ),
        );
        await _focusItem(tester, 2);
        _harnessA(tester).onMove = (_, _) => outside.requestFocus();

        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(FocusManager.instance.primaryFocus, same(outside));
      },
    );

    testWidgets(
      'fo06/us11/fr03/e09: the app focuses a bare FocusScopeNode outside the '
      'list in the turn of Alt+Down to a built slot, and that focus stays',
      (tester) async {
        final outsideScope = FocusScopeNode(debugLabel: 'outside scope');
        addTearDown(outsideScope.dispose);
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                FocusScope(node: outsideScope, child: const SizedBox()),
                const Expanded(child: _Harness(count: 5)),
              ],
            ),
          ),
        );
        await _focusItem(tester, 2);
        _harnessA(tester).onMove = (_, _) => outsideScope.requestFocus();

        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(FocusManager.instance.primaryFocus, same(outsideScope));
      },
    );

    testWidgets('fo06/us11/fr03/e09: a focus the app moves outside the list in the turn of '
        'Alt+Down to a near unbuilt slot stays, and the list never pulls it '
        'back', (tester) async {
      final outside = FocusNode(debugLabel: 'outside');
      addTearDown(outside.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Focus(focusNode: outside, child: const SizedBox()),
              const Expanded(child: _Harness(count: 200)),
            ],
          ),
        ),
      );
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position
            ..jumpTo(4000);
      await tester.pump();
      final state = _itemState(tester, 113);
      await _focusItem(tester, 113);
      _harnessA(tester).onMove = (_, _) => outside.requestFocus();

      await _altNow(tester, LogicalKeyboardKey.arrowDown);
      expect(position.pixels, 4000);
      await tester.pump();

      expect(_statesOf(tester, 113), isNot(contains(state)));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(outside));
      expect(position.pixels, 4000);
    });
  });

  group('ReorderableListViewLayout two or more moveItem calls on one focused '
      "key in one turn re-aim the move's jump (R4)", () {
    testWidgets(
      'fo06/us11/fr05/e04: a second moveItem call on the key the first call '
      "moved re-aims the frame-start jump to the second call's slot, "
      "laid out in the move's own frame, with no reach a later frame "
      'corrects',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        await _focusItem(tester, 100);

        _harness(tester)
          ..move(100, 150)
          ..move(150, 160);
        expect(position.pixels, 4000);
        await tester.pump();

        // The second call's own slot by the built items' average extent,
        // not the first call's 150, and not left at 4000 for a later
        // frame's reach to correct: a later move re-aims the booked
        // target (D8), so the one frame-start jump already lands the
        // item in view.
        // R56: the list commits its scroll at the next frame's start
        // (D13 frame shift).
        await tester.pump();
        expect(position.pixels, 6160.0);
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: a third moveItem call on the same key re-aims the '
      "frame-start jump again, to the third call's slot, in the move's "
      'own frame',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        await _focusItem(tester, 100);

        _harness(tester)
          ..move(100, 150)
          ..move(150, 160)
          ..move(160, 170);
        expect(position.pixels, 4000);
        await tester.pump();

        // R56: the list commits its scroll at the next frame's start
        // (D13 frame shift).
        await tester.pump();
        expect(position.pixels, 6560.0);
        expect(_builtInView(tester, 100), isTrue);
      },
    );
  });

  void dragEndsTests() {
    testWidgets(
      'fo06/us11/fr04/e06: a second pointer that takes a long-press drag over '
      'ends it with one onReorderEnd, in the microtask after its down',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        final gesture = await _liftItem(tester, 2);
        final harness = _harness(tester);
        final second = TestPointer(await _nextPointerId(tester));

        _sendPointer(tester, second.down(tester.getCenter(find.text('5'))));
        expect(harness.ends, isEmpty);
        await tester.idle();
        expect(harness.ends, [2]);
        _sendPointer(tester, second.up());
        await tester.pump();
        harness.insert(0, 100);
        expect(harness.ends, [2]);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [2]);
        expect(harness.moves, isEmpty);
        expect(harness.starts, [2]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e06: a second long press that starts a second drag ends '
      'the first drag before the second one starts',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final gesture = await _liftItem(tester, 2);
        final harness = _harness(tester);

        final second = await _liftItem(tester, 5, by: 50);
        await tester.pump();
        await second.up();
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.starts, [2, 5]);
        expect(harness.events.first, 'start 2');
        expect(harness.events[1], 'end 2');
        expect(harness.events[2], 'start 5');
        expect(harness.events.where((event) => event.startsWith('end')), [
          'end 2',
          isA<String>(),
        ]);
      },
    );

    testWidgets('fo06/us11/fr04/e06: a pointer cancel ends the drag with one onReorderEnd, '
        'and a later insertItem reports none', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller)),
      );
      final gesture = await _liftItem(tester, 2);
      final harness = _harness(tester);

      await gesture.cancel();
      await tester.pump();
      expect(harness.ends, [2]);
      harness.insert(0, 100);
      expect(harness.ends, [2]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, [2]);
      expect(harness.starts, [2]);
    });

    testWidgets('fo06/us11/fr04/e06: a pointer cancel reports onReorderEnd in a microtask '
        'after the cancel, not inside its dispatch', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 20)));
      final harness = _harness(tester);
      final first = TestPointer(8);
      _sendPointer(tester, first.down(tester.getCenter(find.text('2'))));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      _sendPointer(tester, first.move(first.location! + const Offset(0, 10)));
      await tester.pump();
      expect(harness.starts, [2]);

      _sendPointer(tester, first.cancel());
      expect(harness.ends, isEmpty);
      await tester.idle();
      expect(harness.ends, [2]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, [2]);
    });

    testWidgets('fo06/us11/fr04/e06: a drop reports onReorderEnd once, at the pointer up, '
        "with the index Flutter's list gives the drop", (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 20)));
      final gesture = await _liftItem(tester, 2, by: 100);
      final harness = _harness(tester);

      await gesture.up();
      expect(harness.ends, [4]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, [4]);
      expect(harness.moves, [(2, 3)]);
    });

    testWidgets(
      'fo06/us11/fr04/e06: disposing the list during a drag reports no '
      'onReorderEnd',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final gesture = await _liftItem(tester, 2);
        final harness = _harness(tester);

        await tester.pumpWidget(_app(const SizedBox()));
        await tester.idle();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.starts, [2]);
        expect(harness.ends, isEmpty);
      },
    );

    testWidgets(
      'fo06/us11/fr01/e01: a second pointer on a handle takes the handle drag '
      'over and ends it with one onReorderEnd, in the microtask after its '
      'down',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 20,
              handles: true,
              longPressDrag: false,
              itemsController: controller,
            ),
          ),
        );
        final gesture = await _grabHandle(tester, 2);
        final harness = _harness(tester);
        expect(harness.starts, [2]);
        final second = TestPointer(await _nextPointerId(tester));

        _sendPointer(
          tester,
          second.down(tester.getCenter(find.byKey(const ValueKey('handle 5')))),
        );
        expect(harness.ends, isEmpty);
        await tester.idle();
        expect(harness.ends, [2]);
        _sendPointer(tester, second.up());
        await tester.pump();
        harness.insert(0, 100);
        expect(harness.ends, [2]);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [2]);
      },
    );

    final firstReleases = ValueVariant<String>({'up', 'cancel'});
    testWidgets(
      'fo06/us11/fr01/e01: with long-press dragging too, a second pointer on a '
      'handle takes the first one over, and releasing the first pointer '
      'afterward raises no exception, with one onReorderEnd',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20, handles: true)));
        final gesture = await _grabHandle(tester, 2);
        final harness = _harness(tester);
        expect(harness.starts, [2]);
        final second = TestPointer(await _nextPointerId(tester));

        _sendPointer(
          tester,
          second.down(tester.getCenter(find.byKey(const ValueKey('handle 5')))),
        );
        expect(harness.ends, isEmpty);
        await tester.idle();
        expect(harness.ends, [2]);

        if (firstReleases.currentValue == 'up') {
          await gesture.up();
        } else {
          await gesture.cancel();
        }
        _sendPointer(tester, second.up());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [2]);
      },
      variant: firstReleases,
    );

    testWidgets(
      'fo06/us11/fr01/e01: a second handle drag ends the first one before it '
      'starts',
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 20, handles: true, longPressDrag: false)),
        );
        final gesture = await _grabHandle(tester, 2);
        final harness = _harness(tester);

        final second = await _grabHandle(tester, 5);
        await second.up();
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.starts, [2, 5]);
        expect(harness.events.take(3), ['start 2', 'end 2', 'start 5']);
        expect(harness.ends, hasLength(2));
      },
    );

    testWidgets(
      'fo06/us11/fr01/e01: a pointer cancel on a handle drag ends it with one '
      'onReorderEnd',
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 20, handles: true, longPressDrag: false)),
        );
        final gesture = await _grabHandle(tester, 2);

        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ends, [2]);
      },
    );

    testWidgets('fo06/us11/fr04/e06: an app that calls removeItem from the onReorderEnd of '
        "a second pointer's takeover fails no assert", (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller)),
      );
      final gesture = await _liftItem(tester, 2);
      final harness = _harness(tester);
      harness.onEnd = (_) => harness.remove(0);
      final second = TestPointer(await _nextPointerId(tester));

      _sendPointer(tester, second.down(tester.getCenter(find.text('5'))));
      await tester.idle();
      _sendPointer(tester, second.up());
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, [2]);
      expect(harness.ids.take(3), [1, 2, 3]);
    });

    testWidgets('fo06/us11/fr04/e06: an app that calls removeItem from the onReorderEnd of '
        'a pointer cancel fails no assert', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 20, itemsController: controller)),
      );
      final gesture = await _liftItem(tester, 2);
      final harness = _harness(tester);
      harness.onEnd = (_) => harness.remove(0);

      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, [2]);
      expect(harness.ids.take(3), [1, 2, 3]);
    });

    // How a drop's settle ends inside its own pointer-up: a theme whose
    // normal level takes no time, or a release before the lift's proxy
    // ticked past 0, which leaves no settle to run.
    final quickDrops = ValueVariant<String>({
      'zero settle duration',
      'release before the second tick',
    });
    testWidgets('fo06/us11/fr04/e06 (R52): a drop whose settle ends inside its pointer-up '
        'reports onReorderEnd before onReorderItem, and the next drag still '
        'ends with its own onReorderEnd', (tester) async {
      final zero = quickDrops.currentValue == 'zero settle duration';
      await tester.pumpWidget(
        _app(
          const _Harness(count: 5, handles: true, longPressDrag: false),
          theme: zero ? _normalTheme(Duration.zero) : null,
        ),
      );
      final harness = _harness(tester);
      harness.onMove = (from, to) => harness.events.add('move $from $to');
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('handle 0'))),
      );
      if (zero) await tester.pump();
      await gesture.moveBy(const Offset(0, 230));
      if (zero) await tester.pump();
      await gesture.up();

      expect(harness.events, ['start 0', 'end 5', 'move 0 4']);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(harness.ids, [1, 2, 3, 4, 0]);

      // A key during the next drag ends it as a call ends it: the drop
      // left nothing that reads as a settle.
      await _focusItem(tester, 2);
      final next = await _grabHandle(tester, 3);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      await next.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.events.skip(3), ['start 2', 'end 2', 'move 1 2']);
    }, variant: quickDrops);

    testWidgets(
      'fo06/us11/fr01 (D7): under a zero settle duration a drag reflows its '
      'neighbors at once and reports no error',
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 5), theme: _normalTheme(Duration.zero)),
        );
        final gesture = await _liftItem(tester, 0);
        await _dragPastNeighbor(tester, gesture);

        expect(tester.takeException(), isNull);
        expect(_top(tester, 1), 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_harness(tester).moves, [(0, 1)]);
      },
    );

    testWidgets(
      'matrix I01xT03 (R52): a mouse drag whose down and slop land before '
      'the next frame, while a drop settles, completes the drop and lifts '
      'the new item',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 5, handles: true)));
        final harness = _harness(tester);
        final first = await _grabHandle(tester, 0);
        await _dragPastNeighbor(tester, first);
        await tester.pumpAndSettle();
        await first.up();
        await tester.pump();
        expect(harness.moves, isEmpty);
        expect(harness.ends, hasLength(1));

        // No frame runs between the down, which completes the drop, and
        // the move past the mouse's 1 px slop.
        final second = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('handle 3'))),
          kind: PointerDeviceKind.mouse,
        );
        await second.moveBy(const Offset(0, 20));

        expect(harness.moves, [(0, 1)]);
        expect(harness.starts, [0, 3]);
        expect(harness.ends, hasLength(1));
        await tester.pump();
        expect(harness.ends, hasLength(1));
        await second.up();
        await tester.pumpAndSettle();
        expect(harness.ends, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('ReorderableListViewLayout drag ends', dragEndsTests);

  void sameCountDragTests() {
    testWidgets(
      'fo06/us11/fr03/e06: a same-count change that moves the dragged item to a '
      'built slot cancels the drag after the frame, with one onReorderEnd '
      'at its start index, no onReorderItem, and its State kept',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final gesture = await _liftItem(tester, 3);
        final harness = _harness(tester);
        final state = _itemState(tester, 3);

        harness.moveData(3, 7);
        expect(harness.ends, isEmpty);
        await tester.pump();
        expect(harness.ends, [3]);
        await tester.pump();
        expect(_itemState(tester, 3), same(state));
        expect(state.widget.index, 7);
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [3]);
        expect(harness.moves, isEmpty);
        expect(harness.ids.take(8), [0, 1, 2, 4, 5, 6, 7, 3]);
      },
    );

    testWidgets(
      'fo06/us11/fr01/e07: a same-count change that moves the unfocused dragged '
      'item to a slot the frame does not build cancels the drag with no '
      'error, and the item loses its State, never kept alive',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 400)));
        final gesture = await _liftItem(tester, 3);
        final harness = _harness(tester);
        final state = _itemState(tester, 3);

        harness.moveData(3, 300);
        await tester.pump();
        expect(harness.ends, [3]);
        await tester.pump();
        expect(state.mounted, isFalse);
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [3]);
        expect(harness.moves, isEmpty);
        expect(harness.ids[300], 3);
      },
    );

    testWidgets('fo06/us11/fr04/e06: a same-count change that moves a dropped item while it '
        'settles ends the drop with no onReorderItem and no second '
        'onReorderEnd, and the item keeps its State', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 20)));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('3')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 100));
      // The lift and the drop's settle each run over the theme's 200 ms
      // normal level.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      final harness = _harness(tester);
      final ends = [...harness.ends];
      expect(ends, hasLength(1));
      final moves = [...harness.moves];
      await tester.pump(const Duration(milliseconds: 100));
      final state = _itemState(tester, 3);
      final at = harness.ids.indexOf(3);

      harness.moveData(at, 7);
      await tester.pump();
      await tester.pump();
      expect(_itemState(tester, 3), same(state));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, ends);
      expect(harness.moves, moves);
      expect(harness.ids[7], 3);
    });

    testWidgets(
      "fo06/us11/fr04/e12: a same-count change that replaces the dragged item's "
      'key cancels the drag after the frame, and the item leaves',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final gesture = await _liftItem(tester, 3);
        final harness = _harness(tester);
        final state = _itemState(tester, 3);

        harness.replaceData(3, 99);
        await tester.pump();
        expect(harness.ends, [3]);
        await tester.pump();
        expect(state.mounted, isFalse);
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [3]);
        expect(harness.moves, isEmpty);
        expect(harness.ids.take(5), [0, 1, 2, 99, 4]);
      },
    );

    testWidgets('fo06/us11/fr01/e07: a same-count change that moves only other items keeps '
        'the drag', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 20)));
      final gesture = await _liftItem(tester, 3);
      final harness = _harness(tester)..moveData(5, 6);
      await tester.pump();
      await tester.pump();
      expect(harness.ends, isEmpty);
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, hasLength(1));
      expect(harness.moves, hasLength(1));
      expect(harness.ids[harness.moves.single.$2], 3);
    });

    testWidgets(
      'fo06/us11/fr01/e07: the dragged-key check costs one itemBuilder call per '
      'build while an item is lifted, and none on an idle frame',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          _app(_Harness(count: 20, onItemBuild: (_) => builds += 1)),
        );
        final gesture = await _liftItem(tester, 3);

        builds = 0;
        await tester.pump(const Duration(milliseconds: 16));
        expect(builds, 0);
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
        final update = builds;
        builds = 0;
        _harness(tester).moveData(15, 16);
        await tester.pump();
        expect(builds - update, 1);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }

  group(
    'ReorderableListViewLayout same-count change during a drag',
    sameCountDragTests,
  );

  group('ReorderableListViewLayout items framed by key', () {
    testWidgets('fo06/us11/fr05/e12: two items moved in one turn to slots the frame does not '
        'build, a focused one and one the app keeps alive, both keep their '
        'State', (tester) async {
      final controller = ReorderableItemsController();
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 1000,
          itemsController: controller,
          keepAliveIds: const {21},
        ),
        offset: 600,
      );
      final focusedState = _itemState(tester, 20)..expanded = true;
      final keptState = _itemState(tester, 21)..expanded = true;
      await _focusItem(tester, 20);

      _harness(tester)
        ..move(20, 500)
        ..move(20, 600);
      await tester.pumpAndSettle();
      expect(_statesOf(tester, 20), [same(focusedState)]);
      position.jumpTo(600 * 40.0 - 100);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_itemState(tester, 21), same(keptState));
      expect(keptState.expanded, isTrue);
      expect(focusedState.expanded, isTrue);
    });

    testWidgets(
      's03/inv35: under each extent, none, itemExtent, itemExtentBuilder, and '
      'prototypeItem, the list lays every slot out at that extent and a '
      'focused item a raw move takes far keeps its State',
      (tester) async {
        final harnesses = [
          const _Harness(key: ValueKey('none'), count: 200, appIndex: true),
          const _Harness(
            key: ValueKey('itemExtent'),
            count: 200,
            itemExtent: 40,
            appIndex: true,
          ),
          _Harness(
            key: const ValueKey('itemExtentBuilder'),
            count: 200,
            itemExtentBuilder: (index, dimensions) => 40,
            appIndex: true,
          ),
          const _Harness(
            key: ValueKey('prototypeItem'),
            count: 200,
            prototypeItem: SizedBox(width: 40, height: 40),
            appIndex: true,
          ),
        ];
        for (final harness in harnesses) {
          await tester.pumpWidget(_app(harness));
          final state = _itemState(tester, 1);
          await _focusItem(tester, 1);
          expect(_offsetBetween(tester, 2, 3), 40);

          _harness(tester).moveData(1, 150);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(_statesOf(tester, 1), [same(state)]);
          expect(FocusManager.instance.primaryFocus, same(state.node));
        }
      },
    );

    testWidgets('fo06/us11/fr05/e05: an unfocused item the app keeps alive keeps its State '
        'through a moveItem to a slot the frame does not build: its keep-alive '
        'follows it to its new slot', (tester) async {
      final controller = ReorderableItemsController();
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 1000,
          itemsController: controller,
          keepAliveIds: const {20},
        ),
        offset: 600,
      );
      final state = _itemState(tester, 20)..expanded = true;

      _harness(tester).move(20, 500);
      await tester.pumpAndSettle();
      expect(state.mounted, isTrue);
      position.jumpTo(500 * 40.0 - 100);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_itemState(tester, 20), same(state));
      expect(state.expanded, isTrue);
      expect(state.widget.index, 500);
    });
  });

  void parkedItemTests() {
    testWidgets('fo06/us11/fr04/e17: a node that takes focus while a focused item waits off '
        'screen ends its park, so the item, never laid out, leaves with its '
        'State', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 200, itemsController: controller)),
      );
      final state = _itemState(tester, 0);
      final other = _itemState(tester, 2).node;
      await _focusItem(tester, 0);
      // Held at 0, the list never lays the new slot out, so the item stays
      // parked off screen while the reach runs.
      _pinScroll(tester, 0);
      _harness(tester)
        ..remove(0)
        ..insert(199, 0);
      await tester.pump();
      expect(_statesOf(tester, 0), [same(state)]);

      other.requestFocus();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(FocusManager.instance.primaryFocus, same(other));
      expect(state.mounted, isFalse);
    });

    // A list shape the parked item's element follows its key in.
    final shapes = ValueVariant<String>({
      'itemExtent',
      'itemExtentBuilder',
      'prototypeItem',
      'reversed',
      'horizontal',
      'right-to-left',
    });
    testWidgets('fo06/us11/fr04/e17: a focused item the app takes out and puts back far down '
        'keeps its State and focus off screen under a fixed, built, or '
        'prototype extent, and on a reversed, horizontal, or right-to-left '
        'list', (tester) async {
      final shape = shapes.currentValue!;
      final horizontal = shape == 'horizontal' || shape == 'right-to-left';
      await _returnFocused(
        tester,
        _Harness(
          count: 200,
          itemsController: ReorderableItemsController(),
          axis: horizontal ? Axis.horizontal : Axis.vertical,
          reverse: shape == 'reversed',
          itemExtent: shape == 'itemExtent' ? 40 : null,
          itemExtentBuilder: shape == 'itemExtentBuilder'
              ? (index, dimensions) => 40
              : null,
          prototypeItem: shape == 'prototypeItem'
              ? const SizedBox(width: 40, height: 40)
              : null,
        ),
        offset: 0,
        id: 0,
        slot: 199,
        textDirection: shape == 'right-to-left'
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
      final state = _statesOf(tester, 0).single;
      final focused = FocusManager.instance.primaryFocus;
      await tester.pump();
      expect(_statesOf(tester, 0), [same(state)]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, 0), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_builtInView(tester, 0), isTrue);
    }, variant: shapes);

    testWidgets(
      'fo06/us11/fr04/e17: an insertItem before an item that waits off screen '
      'carries its kept-alive State to its new index, until the reach gives '
      'up and hands focus on',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller)),
        );
        final state = _itemState(tester, 0);
        await _focusItem(tester, 0);
        // Held at 0, the list never lays the new slot out, so the item stays
        // parked off screen until the reach gives up.
        _pinScroll(tester, 0);
        _harness(tester)
          ..remove(0)
          ..insert(199, 0);
        await tester.pump();
        expect(_statesOf(tester, 0), [same(state)]);

        _harness(tester).insert(0, 900);
        await tester.pump();
        expect(_statesOf(tester, 0), [same(state)]);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids[200], 0);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 900');
      },
    );

    testWidgets(
      'fo06/us11/fr04/e17: a focused item the app takes out and puts back far '
      'down waits off screen with its State and the node that holds focus, '
      'then shows on screen',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller)),
        );
        final state = _itemState(tester, 0)..expanded = true;
        final focused = await _focusItem(tester, 0);

        _harness(tester)
          ..remove(0)
          ..insert(199, 0);
        await tester.pump();
        expect(_laidOut(tester).last, lessThan(199));
        expect(_statesOf(tester, 0), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(focused));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 0), [same(state)]);
        expect(state.expanded, isTrue);
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 0), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/s04: on a lazy list whose unbuilt items run taller than the '
      'built ones, Alt+End moves the focused item to the last slot with its '
      'State and focus, and shows it',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: {for (var id = 150; id < 200; id += 1) id: 120},
          ),
          offset: 4200,
        );
        final state = _itemState(tester, 105)..expanded = true;
        final focused = await _focusItem(tester, 105);

        await _alt(tester, LogicalKeyboardKey.end);

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids.last, 105);
        expect(_statesOf(tester, 105), [same(state)]);
        expect(state.expanded, isTrue);
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(position.pixels, position.maxScrollExtent);
        expect(_builtInView(tester, 105), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e12: an item-count change with no call while a focused '
      'item waits off screen for its slot ends its State and hands focus '
      'on, and with the app index follows the item by its key',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller)),
        );
        final state = _itemState(tester, 0);
        await _focusItem(tester, 0);
        _harness(tester)
          ..remove(0)
          ..insert(199, 0);
        await tester.pump();
        expect(_statesOf(tester, 0), [same(state)]);

        _harness(tester).removeData(5);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        if (_appIndex) {
          // Rerun with the app's index: the count change ends no follow
          // (R25), so the item shows at its slot with its State and focus.
          expect(_statesOf(tester, 0), [same(state)]);
          expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 0');
          expect(_builtInView(tester, 0), isTrue);
          return;
        }
        expect(state.mounted, isFalse);
        final primary = FocusManager.instance.primaryFocus;
        expect(primary?.debugLabel, startsWith('item '));
        expect(primary?.debugLabel, isNot('item 0'));
      },
    );

    testWidgets(
      'fo06/us11/fr04/e17: a moveItem of the item that waits off screen keeps it '
      'alive for its new slot, with its State and focus, and shows it there',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller)),
        );
        final state = _itemState(tester, 0)..expanded = true;
        final focused = await _focusItem(tester, 0);
        _harness(tester)
          ..remove(0)
          ..insert(199, 0);
        await tester.pump();
        expect(_statesOf(tester, 0), [same(state)]);

        _harness(tester).move(199, 150);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids[150], 0);
        expect(_statesOf(tester, 0), [same(state)]);
        expect(state.expanded, isTrue);
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 0), isTrue);
      },
    );
  }

  group('ReorderableListViewLayout parked moved item', parkedItemTests);

  group("ReorderableListViewLayout jumps at the next frame's start", () {
    /// Pumps 200 items scrolled to 4200 px, items 105 to 112 in view, with
    /// item 105 focused; [moves] records each scroll offset from then on.
    Future<ScrollPosition> pumpFocused(
      WidgetTester tester,
      List<double> moves,
    ) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
        offset: 4200,
      );
      await _focusItem(tester, 105);
      position.addListener(() => moves.add(position.pixels));
      return position;
    }

    // A move to the end: by Alt+End, or by the "Move to the end" action.
    final endMove = ValueVariant<String>({'Alt+End', 'Move to the end'});
    testWidgets('fo06/us11/fr03/e01: a focus the app moves to another item in '
        'onReorderItem of a move to the end stays where the app put it, in '
        'view, and the list never scrolls', (tester) async {
      final handle = tester.ensureSemantics();
      final moves = <double>[];
      await pumpFocused(tester, moves);
      final other = _itemState(tester, 110).node;
      _harness(tester).onMove = (_, _) => other.requestFocus();

      if (endMove.currentValue == 'Alt+End') {
        await _alt(tester, LogicalKeyboardKey.end);
      } else {
        await _moveAction(tester, 105, 'Move to the end');
      }

      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids.last, 105);
      expect(FocusManager.instance.primaryFocus, same(other));
      expect(_builtInView(tester, 110), isTrue);
      expect(moves, isEmpty);
      handle.dispose();
    }, variant: endMove);

    testWidgets('fo06/us11/fr03/e01: a focus the app moves to another item in '
        'onReorderItem of Alt+Home stays where the app put it, in view, and '
        'the list never scrolls', (tester) async {
      final moves = <double>[];
      await pumpFocused(tester, moves);
      final other = _itemState(tester, 110).node;
      _harness(tester).onMove = (_, _) => other.requestFocus();

      await _alt(tester, LogicalKeyboardKey.home);

      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids.first, 105);
      expect(FocusManager.instance.primaryFocus, same(other));
      expect(_builtInView(tester, 110), isTrue);
      expect(moves, isEmpty);
    });

    testWidgets('fo06/us11/fr03/e02: the scroll offset read in onReorderItem of Alt+End has '
        "not moved; the list jumps to the end at the next frame's start and "
        'keeps the item State and focus', (tester) async {
      final moves = <double>[];
      final position = await pumpFocused(tester, moves);
      final state = _itemState(tester, 105);
      final focused = FocusManager.instance.primaryFocus;
      double? read;
      _harness(tester).onMove = (_, _) => read = position.pixels;

      await _altNow(tester, LogicalKeyboardKey.end);
      expect(read, 4200);
      expect(position.pixels, 4200);
      await tester.pump();
      expect(moves.first, position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, 105), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_builtInView(tester, 105), isTrue);
    });

    testWidgets(
      'fo06/us11/fr05/e04 and s03/inv32: the scroll offset read right after a '
      "far moveItem has not moved; the probe moves it at the next frame's "
      'start, before that frame builds, and the landing reveal then '
      "corrects it to the least scroll at the following frame's start",
      (tester) async {
        double? atBuild;
        var armed = false;
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            // The first build of an item inside the list, past the body's
            // own reads of the data.
            onItemBuild: (context) {
              final pixels = Scrollable.maybeOf(context)?.position.pixels;
              if (armed && pixels != null) atBuild ??= pixels;
            },
          ),
        );
        await _focusItem(tester, 100);
        armed = true;

        _harness(tester).move(100, 150);
        expect(position.pixels, 4000);
        await tester.pump();

        // The probe's plain-edge jump moves the list before the frame
        // builds slot 150, landing at its leading edge, 6000 (D29, G5): the
        // build sees it there, not at 4000. The landing reveal then commits
        // at the following frame's start, clamping to the least scroll
        // from 4000, the trailing edge, so the offset read after that frame
        // has moved again, past where the build saw it.
        expect(atBuild, 6000.0);
        // R56: the list commits its scroll at the next frame's start
        // (D13 frame shift).
        await tester.pump();
        expect(position.pixels, 5760.0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_builtInView(tester, 100), isTrue);
      },
    );
  });

  group('ReorderableListViewLayout handoff away from the laid-out items', () {
    testWidgets(
      'fo06/us11/fr04/e04: when the app takes a moved item out before the frame '
      'whose jump would reach its slot, the list reaches toward the gap and '
      'hands focus to an item laid out there, so focus is never lost',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
          offset: 4200,
        );
        await _focusItem(tester, 105);

        await _altNow(tester, LogicalKeyboardKey.end);
        _harness(tester).remove(199);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids.contains(105), isFalse);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 199');
        expect(_builtInView(tester, 199), isTrue);
        expect(position.pixels, greaterThan(4200));
      },
    );

    testWidgets(
      'fo06/us11/fr04/e04: an item the app keeps alive off screen beside the gap '
      'of a removed focused item is never the handoff target: the list '
      'reaches the gap and focus goes to an item laid out there',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            keepAliveIds: const {30, 31},
          ),
          offset: 1100,
        );
        await _focusItem(tester, 31);
        position.jumpTo(4000);
        await tester.pump();
        expect(_laidOut(tester).first, greaterThan(31));
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 31');

        _harness(tester).remove(31);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 32');
        final laid = _laidOut(tester);
        expect(laid.first, lessThanOrEqualTo(31));
        expect(laid.last, greaterThanOrEqualTo(31));
      },
    );

    testWidgets('fo06/us11/fr04/e04: when the reach toward the gap gives up, focus goes to '
        'the laid-out item nearest the gap, on a list with no Tab stop of its '
        'own', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          itemsController: ReorderableItemsController(),
          focusable: false,
        ),
        offset: 4200,
      );
      await _focusItem(tester, 105);
      // Held at 4200, the list never lays out the gap at the end, so the
      // reach gives up after its frames.
      _pinScroll(tester, 4200);

      await _altNow(tester, LogicalKeyboardKey.end);
      _harness(tester).remove(199);
      await tester.pumpAndSettle();

      final harness = _harness(tester);
      final laid = _laidOut(tester);
      expect(tester.takeException(), isNull);
      expect(position.pixels, 4200);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'item ${harness.ids[laid.last]}',
      );
    });
  });

  group('ReorderableListViewLayout reorders the app makes alone', () {
    testWidgets('fo06/us11/fr05/e13: an item the app keeps alive follows a reorder of its '
        'data with no call to a slot the frame does not build', (tester) async {
      final position = await _pumpScrolled(
        tester,
        const _Harness(count: 1000, appIndex: true, keepAliveIds: {103}),
      );
      final state = _itemState(tester, 103);

      _harness(tester).moveData(103, 600);
      await tester.pumpAndSettle();
      expect(_statesOf(tester, 103), [same(state)]);
      position.jumpTo(600 * 40.0 - 100);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(_builtInView(tester, 103), isTrue);
    });

    testWidgets(
      'fo06/us11/fr01/input-output: an app index past the data counts as no '
      'answer, with no error',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 1000, appIndex: true),
        );
        final harness = _harness(tester)..answer = (key) => 1000;
        final state = _itemState(tester, 104);

        harness.moveData(103, 600);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 104), [same(state)]);
        expect(_statesOf(tester, 103), isEmpty);
        expect(position.pixels, 4000);
      },
    );

    testWidgets(
      's03/inv35: an item the app keeps alive off screen, shifted by an '
      'insertItem, moves in place by the app index and keeps its State',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            itemsController: ReorderableItemsController(),
            keepAliveIds: const {5},
          ),
        );
        final state = _itemState(tester, 5);

        _harness(tester).insert(0, 5000);
        await tester.pumpAndSettle();
        position.jumpTo(0);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids[6], 5);
        expect(_statesOf(tester, 5), [same(state)]);
      },
    );

    /// Pumps [harness] scrolled to [offset], focuses item [id] unless
    /// [focus] is false, and returns its State and the list's position.
    Future<(_ItemState, ScrollPosition)> pumpItem(
      WidgetTester tester,
      _Harness harness, {
      int id = 103,
      double offset = 4000,
      bool focus = true,
    }) async {
      final position = await _pumpScrolled(tester, harness, offset: offset);
      final state = _itemState(tester, id);
      if (focus) await _focusItem(tester, id);
      return (state, position);
    }

    // Unbuilt items from id 300 on run taller, so a jump into them misses
    // and the list reaches the slot over several frames.
    final taller = {for (var id = 300; id < 1000; id += 1) id: 120.0};

    testWidgets('fo06/us11/fr05/e13 and fo06/us11/fr04/e19: with no callback, a focused item the '
        'app moves in its data with no call to a slot the frame does not build '
        'loses its State, and focus moves to the next item', (tester) async {
      final (state, position) = await pumpItem(
        tester,
        const _Harness(count: 1000),
      );

      _harness(tester).moveData(103, 600);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 104');
      expect(position.pixels, 4000);
    });

    final farTargets = ValueVariant<int>({600, 5, 999});
    testWidgets('fo06/us11/fr05/e13 and fo06/us11/fr03/e11: a focused item the app moves in its '
        'data with no call to a slot the frame does not build keeps its State '
        'and focus, shows one frame after the build that learns of it, and '
        'stays alive once scrolled out of view', (tester) async {
      final to = farTargets.currentValue!;
      final (state, position) = await pumpItem(
        tester,
        const _Harness(count: 1000, appIndex: true),
      );

      _harness(tester).moveData(103, to);
      await tester.pump();
      expect(_statesOf(tester, 103), [same(state)]);
      expect(_builtInView(tester, 103), isFalse);
      await tester.pump();
      expect(_builtInView(tester, 103), isTrue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_harness(tester).moves, isEmpty);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isTrue);
      position.jumpTo(to > 50 ? 0 : 20000);
      await tester.pump();
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isFalse);
    }, variant: farTargets);

    testWidgets(
      'fo06/us11/fr05/e13: a focused item the app moves to a laid-out slot out of '
      'view keeps its State and focus, and the list reveals it',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          const _Harness(count: 1000, appIndex: true),
        );

        _harness(tester).moveData(103, 111);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).moves, isEmpty);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
        expect(position.pixels, 4180);
      },
    );

    testWidgets('fo06/us11/fr05/e13: a focused item the app moves within the viewport keeps '
        'its State and focus, and the list does not scroll', (tester) async {
      final (state, position) = await pumpItem(
        tester,
        const _Harness(count: 1000, appIndex: true),
      );

      _harness(tester).moveData(103, 105);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(position.pixels, 4000);
    });

    testWidgets(
      'fo06/us11/fr05/e13: an item that does not hold focus, moved by the app to '
      'a slot the frame does not build, is never kept alive or followed',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          const _Harness(count: 1000, appIndex: true),
          focus: false,
        );

        _harness(tester).moveData(103, 600);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        expect(position.pixels, 4000);
      },
    );

    // The dragged item: focused or not, to a slot the frame does not build
    // or to a laid-out one out of view; unfocused, and kept alive by the app.
    final dragged = ValueVariant<(bool, int, bool)>({
      (true, 600, false),
      (true, 111, false),
      (false, 600, false),
      (false, 600, true),
    });
    testWidgets(
      'fo06/us11/fr01/e07 and fo06/us11/fr03/e06: the app moves the dragged item in its '
      'data with no call: the drag ends with one onReorderEnd, and a focused '
      'item keeps its State and focus and shows once the proxy lets it go',
      (tester) async {
        final (focused, to, keptAlive) = dragged.currentValue!;
        final (state, position) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            keepAliveIds: keptAlive ? const {103} : null,
          ),
          focus: focused,
        );
        final gesture = await _liftItem(tester, 103);
        final harness = _harness(tester)..moveData(103, to);
        await tester.pump();
        expect(harness.ends, [103]);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [103]);
        expect(harness.moves, isEmpty);
        if (!focused) {
          // Never parked or followed. The lifted item stays in its slot
          // (R49), so the app's own keep-alive keeps it (L4 closed).
          expect(state.mounted, keptAlive);
          expect(position.pixels, 4000);
          return;
        }
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
      },
      variant: dragged,
    );

    testWidgets(
      'fo06/us11/fr05/e13: a focus the app moves to another item in the turn of '
      'its reorder stays, and the moved item is neither kept nor followed',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          const _Harness(count: 1000, appIndex: true),
        );
        final other = _itemState(tester, 105).node;

        _harness(tester).moveData(103, 600);
        other.requestFocus();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(position.pixels, 4000);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e13: a focus the app moves to another item after the build '
      "that books the jump, before the next frame's start, skips the jump",
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          const _Harness(count: 1000, appIndex: true),
        );
        final other = _itemState(tester, 105).node;

        _harness(tester).moveData(103, 600);
        await tester.pump();
        expect(_statesOf(tester, 103), [same(state)]);
        other.requestFocus();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(position.pixels, 4000);
      },
    );

    final answers = ValueVariant<int?>({null, 1000, -1});
    testWidgets('fo06/us11/fr05/e13: a null app answer for the focused item, or one outside '
        'the data, counts as no move, as with no callback', (tester) async {
      final answer = answers.currentValue;
      final (state, position) = await pumpItem(
        tester,
        const _Harness(count: 1000, appIndex: true),
      );
      final harness = _harness(tester);
      harness.answer = (key) => key == const ValueKey(103)
          ? answer
          : harness.ids.indexOf((key as ValueKey<int>).value);

      harness.moveData(103, 600);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
      expect(position.pixels, 4000);
    }, variant: answers);

    // A reorder with an insertItem in the same turn: before the target,
    // between it and the item, and near.
    final withInsert = ValueVariant<(int, int)>({
      (600, 0),
      (600, 300),
      (105, 101),
    });
    testWidgets(
      's03/inv35: a reorder with an insertItem in the same turn reads where '
      'the calls put the focused item, which keeps its State and shows',
      (tester) async {
        final (to, insertAt) = withInsert.currentValue!;
        final (state, _) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            itemsController: ReorderableItemsController(),
          ),
        );

        _harness(tester)
          ..moveData(103, to)
          ..insert(insertAt, 5000);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
      },
      variant: withInsert,
    );

    testWidgets(
      'fo06/us11/fr05/e13: on a lazy extent whose unbuilt items run taller, a '
      'focused item moved to a middle slot keeps its State and shows',
      (tester) async {
        final (state, _) = await pumpItem(
          tester,
          _Harness(count: 1000, appIndex: true, heights: taller),
        );

        _harness(tester).moveData(103, 800);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e13: on a lazy extent whose unbuilt items run taller, a '
      'focused item moved to the last slot is reached by an exact jump to '
      'the end and settles within 20 frames',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            heights: {for (var id = 150; id < 1000; id += 1) id: 400},
          ),
        );

        _harness(tester).moveData(103, 999);
        for (var frame = 0; frame < 20; frame += 1) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final settled = position.pixels;
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(position.pixels, settled);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
      },
    );

    // The first reorder's slot lies where the jump lands; the later one is
    // far, past the taller items, or near.
    final again = ValueVariant<int>({800, 105});
    testWidgets(
      'fo06/us11/fr05/e13: a later reorder of the item kept alive off screen aims '
      'the follow at its newest slot, with its State and focus',
      (tester) async {
        final to = again.currentValue!;
        final (state, _) = await pumpItem(
          tester,
          _Harness(count: 1000, appIndex: true, heights: taller),
        );

        _harness(tester).moveData(103, 200);
        await tester.pump();
        expect(_statesOf(tester, 103), [same(state)]);
        _harness(tester).moveData(200, to);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids[to], 103);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
      },
      variant: again,
    );

    testWidgets(
      's03/inv32: a reorder of the item the list reaches for re-aims the '
      'reach, and the item keeps its State and focus',
      (tester) async {
        final (state, _) = await pumpItem(
          tester,
          _Harness(count: 1000, appIndex: true, heights: taller),
        );

        // The jump at the next frame's start misses the taller items, so
        // after that frame the list reaches the slot.
        _harness(tester).moveData(103, 800);
        await tester.pump();
        await tester.pump();
        expect(_builtInView(tester, 103), isFalse);
        _harness(tester).moveData(800, 400);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids[400], 103);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
      },
    );

    testWidgets(
      's03/inv35 and fo06/us11/fr05/e13: an insertItem that shifts the shown '
      'focused item into the cache band reveals it whole',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            itemsController: ReorderableItemsController(),
          ),
          id: 107,
        );
        expect(_itemInView(tester, 107), isFalse);

        _harness(tester).insert(101, 5000);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 107), [same(state)]);
        expect(position.pixels, 4060);
        expect(_itemInView(tester, 107), isTrue);
      },
    );

    testWidgets(
      's03/inv35: with no app index, two inserts that shift a fully shown '
      'focused item into the cache band reveal it',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          _Harness(count: 1000, itemsController: ReorderableItemsController()),
          id: 106,
        );
        final focused = FocusManager.instance.primaryFocus;
        expect(_itemInView(tester, 106), isTrue);

        _harness(tester)
          ..insert(101, 5000)
          ..insert(101, 5001);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 106), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(position.pixels, 4060);
      },
    );

    // Whether the list gets the app index, and the call that shifts.
    final outerShifts = ValueVariant<({bool appIndex, String call})>({
      for (final appIndex in [false, true])
        for (final call in ['insertItem', 'removeItem'])
          (appIndex: appIndex, call: call),
    });
    testWidgets('s03/inv35 and fo06/us11/fr03/e11: a call that shifts a shown focused item '
        'that stays whole scrolls neither the list nor the page the app '
        'scrolled the list out of', (tester) async {
      final (:appIndex, :call) = outerShifts.currentValue!;
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: _Harness(
                    count: 20,
                    appIndex: appIndex,
                    itemsController: ReorderableItemsController(),
                  ),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      final state = _itemState(tester, 3);
      await _focusItem(tester, 3);
      final scrollables = find.byType(Scrollable);
      final page = tester.state<ScrollableState>(scrollables.first).position
        ..jumpTo(800);
      await tester.pump();
      final list = tester
          .state<ScrollableState>(
            find.byType(Scrollable, skipOffstage: false).at(1),
          )
          .position;
      final pages = <double>[];
      page.addListener(() => pages.add(page.pixels));

      if (call == 'insertItem') {
        _harness(tester).insert(0, 99);
      } else {
        _harness(tester).remove(0);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, 3), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(pages, isEmpty);
      expect(page.pixels, 800);
      expect(list.pixels, 0);
    }, variant: outerShifts);

    // Whether the list gets the app index.
    final foldShifts = ValueVariant<bool>({false, true});
    testWidgets(
      's03/inv35 and fo06/us11/fr03/e11: calls that push a shown focused item '
      "past the fold of the app's page scroll the page to keep it shown",
      (tester) async {
        final appIndex = foldShifts.currentValue!;
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: _Harness(
                count: 20,
                shrinkWrap: true,
                appIndex: appIndex,
                itemsController: ReorderableItemsController(),
              ),
            ),
          ),
        );
        final state = _itemState(tester, 6);
        await _focusItem(tester, 6);
        final pageView = find.byType(Scrollable).first;
        final page = tester.state<ScrollableState>(pageView).position;

        // Item 6 runs from 240 to 280, whole above the page's 300 px fold.
        _harness(tester)
          ..insert(0, 97)
          ..insert(0, 98)
          ..insert(0, 99);
        await tester.pumpAndSettle();

        final view = tester.getRect(pageView);
        final item = tester.getRect(find.byKey(const ValueKey(6)));
        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 6), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(view.intersect(item), item);
        expect(page.pixels, 100);
      },
      variant: foldShifts,
    );

    testWidgets(
      's03/inv35 and fo06/us11/fr05/e13: with the app index, a data move of a '
      'focused item laid out but not shown follows it silently',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          const _Harness(count: 1000, appIndex: true),
        );
        final focused = FocusManager.instance.primaryFocus;
        position.jumpTo(4200);
        await tester.pump();

        _harness(tester).moveData(103, 100);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(position.pixels, 4200);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_builtInView(tester, 103), isFalse);
      },
    );

    testWidgets(
      's03/inv35: with no app index, a moveItem of another item past a '
      'focused item laid out but not shown scrolls nothing',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          _Harness(count: 1000, itemsController: ReorderableItemsController()),
        );
        final focused = FocusManager.instance.primaryFocus;
        position.jumpTo(4200);
        await tester.pump();

        _harness(tester).move(90, 120);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(position.pixels, 4200);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(focused));
      },
    );

    testWidgets('fo06/us11/fr01/input-output: the list asks the app once per built item on '
        'each build, plus once for the focused item, and never while it only '
        'scrolls', (tester) async {
      final (_, position) = await pumpItem(
        tester,
        const _Harness(count: 1000, appIndex: true),
      );
      final harness = _harness(tester);
      expect(_laidOut(tester).count, 21);

      harness
        ..indexCalls = 0
        ..replaceData(0, 0);
      await tester.pump();
      expect(harness.indexCalls, 21 + 1);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      harness
        ..indexCalls = 0
        ..replaceData(0, 0);
      await tester.pump();
      expect(harness.indexCalls, 21);
      harness.indexCalls = 0;
      for (var frame = 0; frame < 10; frame += 1) {
        position.jumpTo(position.pixels + 15);
        await tester.pump();
      }
      expect(harness.indexCalls, 0);
      await _focusItem(tester, 103);
      harness.moveData(103, 800);
      await tester.pump();
      harness.indexCalls = 0;
      for (var frame = 0; frame < 40; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(harness.indexCalls, 0);
    });

    final shapes = ValueVariant<(String, int)>({
      ('reversed', 600),
      ('reversed', 5),
      ('horizontal', 600),
      ('horizontal', 5),
    });
    testWidgets('fo06/us11/fr05/e13: on a reversed or horizontal list, a focused item the '
        'app moves far keeps its State and focus and shows', (tester) async {
      final (shape, to) = shapes.currentValue!;
      final (state, _) = await pumpItem(
        tester,
        _Harness(
          count: 1000,
          appIndex: true,
          reverse: shape == 'reversed',
          axis: shape == 'horizontal' ? Axis.horizontal : Axis.vertical,
        ),
      );

      _harness(tester).moveData(103, to);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isTrue);
    }, variant: shapes);

    // Another item's reorder shifts the focused item one slot: a fully
    // visible item scrolls nothing, a partly hidden one shows whole.
    final shifted = ValueVariant<(int, double, double)>({
      (103, 4000, 4000),
      (100, 4020, 3960),
    });
    testWidgets('fo06/us11/fr05/e13: a shift of the focused item, when the app moves another '
        'item past it, counts as its move', (tester) async {
      final (id, offset, revealed) = shifted.currentValue!;
      final (state, position) = await pumpItem(
        tester,
        const _Harness(count: 1000, appIndex: true),
        id: id,
        offset: offset,
      );

      _harness(tester).moveData(50, 600);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, id), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, id), isTrue);
      expect(position.pixels, revealed);
    }, variant: shifted);

    // An item-count change with no call, with the app's index: in the
    // reorder's own turn, in the turn after the build that parks the item,
    // and while the item is dragged. The list keeps following the item by
    // its key (R25).
    final countChange = ValueVariant<String>({
      'in the same turn',
      'after the build',
      'while dragged',
    });
    testWidgets('fo06/us11/fr04/e12: with the app index, an item-count change with no call '
        'keeps following the focused item by its key: State and focus stay, '
        'and the list shows the item at its slot', (tester) async {
      final timing = countChange.currentValue!;
      final (state, _) = await pumpItem(
        tester,
        const _Harness(count: 1000, appIndex: true),
      );
      final harness = _harness(tester);
      final gesture = timing == 'while dragged'
          ? await _liftItem(tester, 103)
          : null;

      harness.moveData(103, 600);
      if (timing != 'in the same turn') {
        await tester.pump();
        expect(_statesOf(tester, 103), [same(state)]);
      }
      harness.removeData(5);
      await gesture?.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids[599], 103);
      expect(harness.moves, isEmpty);
      expect(harness.ends, gesture == null ? isEmpty : [103]);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isTrue);
    }, variant: countChange);

    // An item-count change with no call in the turn of a moveItem that
    // leaves the moved item's index as the call put it (F2).
    final unshifting = ValueVariant<String>({'an append', 'a remove past it'});
    testWidgets(
      'fo06/us11/fr05/e04 and fo06/us11/fr04/e12: with the app index, a moveItem of '
      'the focused item far into taller items and an item-count change with '
      'no call that leaves its index in one turn still reach and show it',
      (tester) async {
        final (state, _) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            heights: taller,
            itemsController: ReorderableItemsController(),
          ),
        );
        final harness = _harness(tester)..move(103, 800);
        if (unshifting.currentValue == 'an append') {
          harness.insertData(harness.ids.length, 5000);
        } else {
          harness.removeData(900);
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ids[800], 103);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
      },
      variant: unshifting,
    );

    testWidgets(
      'fo06/us11/fr01/e07 and s03/inv28 (L4 closed, R49): an unfocused dragged '
      'item the app keeps alive keeps its State when an item-count change '
      'ends the drag and its new slot is not laid out',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          const _Harness(count: 1000, appIndex: true, keepAliveIds: {103}),
          focus: false,
        );
        final gesture = await _liftItem(tester, 103);

        _harness(tester)
          ..moveData(103, 600)
          ..removeData(5);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ends, [103]);
        expect(state.mounted, isTrue);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(position.pixels, 4000);
      },
    );

    // The park the count change meets: a moveItem's, or a raw move's, while
    // the reach runs into taller unbuilt items.
    final parkedBy = ValueVariant<String>({'moveItem', 'a raw move'});
    testWidgets('fo06/us11/fr04/e17 and s03/inv32: with the app index, an item-count change '
        'during the retry frames re-aims the reach, and the parked item keeps '
        'its State and focus and shows', (tester) async {
      final (state, _) = await pumpItem(
        tester,
        _Harness(
          count: 1000,
          appIndex: true,
          heights: taller,
          itemsController: ReorderableItemsController(),
        ),
      );
      final harness = _harness(tester);

      if (parkedBy.currentValue == 'moveItem') {
        harness.move(103, 800);
        await tester.pump();
      } else {
        harness.moveData(103, 800);
        await tester.pump();
        await tester.pump();
      }
      expect(_statesOf(tester, 103), [same(state)]);
      expect(_builtInView(tester, 103), isFalse);
      harness.removeData(5);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids[799], 103);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isTrue);
    }, variant: parkedBy);

    // The key leaves the data with no call while its item waits off screen:
    // parked by a raw move before its follow runs, or by a same-turn remove
    // and insert while its reach runs; removed, or replaced by another key
    // at the same item count. Focus goes to the item next to the last slot.
    final gone = ValueVariant<(String, String)>({
      ('a raw move', 'removed'),
      ('a raw move', 'replaced'),
      ('remove and insert', 'removed'),
    });
    testWidgets(
      'fo06/us11/fr04/e12 and s03/inv35: with the app index, a null answer for the '
      'item kept alive off screen, its key gone from the data at any item '
      'count, ends its State and hands focus to a neighbor from its last slot',
      (tester) async {
        final (parkedBy, how) = gone.currentValue!;
        final raw = parkedBy == 'a raw move';
        final (state, _) = await pumpItem(
          tester,
          _Harness(
            count: raw ? 1000 : 200,
            appIndex: true,
            itemsController: ReorderableItemsController(),
          ),
          id: raw ? 103 : 0,
          offset: raw ? 4000 : 0,
        );
        final harness = _harness(tester);
        if (raw) {
          harness.moveData(103, 600);
        } else {
          harness
            ..remove(0)
            ..insert(199, 0);
        }
        await tester.pump();
        expect(_statesOf(tester, raw ? 103 : 0), [same(state)]);

        final last = raw ? 600 : 199;
        if (how == 'replaced') {
          harness.replaceData(last, 5000);
        } else {
          harness.removeData(last);
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        final neighbor = how == 'replaced' ? 5000 : (raw ? 601 : 199);
        final primary = FocusManager.instance.primaryFocus;
        expect(primary?.debugLabel, 'item $neighbor');
      },
      variant: gone,
    );

    final countDrag = ValueVariant<bool>({false, true});
    testWidgets('fo06/us11/fr01/e07, fo06/us11/fr03/e06, fo06/us11/fr04/e06, and s03/inv28: an '
        'item-count change during a drag that shifts the focused dragged item '
        'to a slot the frame does not lay out ends the drag; with no callback '
        'the item loses its State and focus moves to the item at the stand-in '
        'slot of the drag, and with the app index it keeps its State and focus '
        'and shows', (tester) async {
      final appIndex = countDrag.currentValue!;
      final (state, position) = await pumpItem(
        tester,
        _Harness(count: 1000, appIndex: appIndex),
      );
      final harness = _harness(tester);
      final gesture = await _liftItem(tester, 103);

      for (var id = 2000; id < 2020; id += 1) {
        harness.insertData(0, id);
      }
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids[123], 103);
      expect(harness.ends, [103]);
      if (appIndex) {
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
        return;
      }
      expect(state.mounted, isFalse);
      // After the twenty inserts, item 83 sits at slot 103.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 83');
      expect(position.pixels, 4000);
    }, variant: countDrag);

    // A focused dragged item a raw move took to a laid-out slot, then shifted
    // by an item-count change with no call before the drag proxy lets it go:
    // by one slot, still laid out, or by twenty, past the laid-out slots.
    final liftedShift = ValueVariant<int>({1, 20});
    testWidgets('fo06/us11/fr04/e06 and s03/inv35: with the app index, an item-count change '
        'before the drag proxy lets go of a focused item a raw move took to a '
        'laid-out slot keeps following the item by its key', (tester) async {
      final shift = liftedShift.currentValue!;
      final (state, _) = await pumpItem(
        tester,
        const _Harness(count: 1000, appIndex: true),
      );
      final harness = _harness(tester);
      final gesture = await _liftItem(tester, 103);

      harness.moveData(103, 111);
      await tester.pump();
      expect(harness.ends, [103]);
      for (var id = 2000; id < 2000 + shift; id += 1) {
        harness.insertData(0, id);
      }
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids[111 + shift], 103);
      expect(harness.ends, [103]);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isTrue);
    }, variant: liftedShift);

    // A focused item Alt+End sent to a slot the frame does not build, past
    // taller unbuilt items, its reveal still booked, then an item-count
    // change with no call in the same turn: an insert before it leaves
    // another key at the old target index, a remove before it leaves that
    // index past the data, and an insert after it leaves the item where it
    // was.
    final staleTarget = ValueVariant<(String, int)>({
      ('an insert before', 1000),
      ('a remove before', 998),
      ('an insert after', 999),
    });
    testWidgets('fo06/us11/fr04/e12 and s03/inv35: with the app index, an item-count change '
        'with no call in the turn of a key move drops the booked target, and '
        'the list follows the focused item by its key', (tester) async {
      final (change, at) = staleTarget.currentValue!;
      final (state, _) = await pumpItem(
        tester,
        _Harness(
          count: 1000,
          appIndex: true,
          heights: taller,
          itemsController: ReorderableItemsController(),
        ),
      );
      final harness = _harness(tester);

      await _altNow(tester, LogicalKeyboardKey.end);
      expect(harness.moves, [(103, 999)]);
      switch (change) {
        case 'an insert before':
          harness.insertData(0, 2000);
        case 'a remove before':
          harness.removeData(0);
        default:
          harness.insertData(1000, 2000);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids[at], 103);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isTrue);
    }, variant: staleTarget);

    // Kept alive by the app or not, with no callback or with the app index.
    final keptAliveDragged = ValueVariant<(bool, bool)>({
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    });
    testWidgets(
      'fo06/us11/fr05/e05 and s03/inv28: a moveItem that ends a drag moves the '
      'unfocused dragged item to a slot the frame does not lay out, and the '
      'item keeps its State only when the app keeps it alive, with or '
      'without the app index',
      (tester) async {
        final (keptAlive, appIndex) = keptAliveDragged.currentValue!;
        final (state, position) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: appIndex,
            itemsController: ReorderableItemsController(),
            keepAliveIds: keptAlive ? const {103} : null,
          ),
          focus: false,
        );
        final harness = _harness(tester);
        final gesture = await _liftItem(tester, 103);

        harness.move(103, 600);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        position.jumpTo(600 * 40.0 - 100);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [103]);
        expect(harness.moves, isEmpty);
        expect(state.mounted, keptAlive);
        expect(_statesOf(tester, 103), [
          if (keptAlive) same(state) else isNot(same(state)),
        ]);
      },
      variant: keptAliveDragged,
    );
  });

  group('ReorderableListViewLayout reparents an item holding its own semantics '
      'boundary into a hidden branch (R1)', () {
    /// Pumps a 200-item [_Harness] whose item [boundaryAt] wraps in
    /// [boundary], scrolled to 4000 px, with item 100 focused unless [focus]
    /// is false.
    Future<void> pumpBoundary(
      WidgetTester tester, {
      required Widget Function(Widget child) boundary,
      int boundaryAt = 100,
      bool focus = true,
      Widget Function(BuildContext, Animation<double>, Widget)?
      itemTransitionBuilder,
      Map<int, double>? heights,
    }) async {
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 200,
            itemsController: ReorderableItemsController(),
            boundaryAt: boundaryAt,
            boundary: boundary,
            itemTransitionBuilder: itemTransitionBuilder,
            heights: heights,
          ),
        ),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(4000);
      await tester.pump();
      if (focus) await _focusItem(tester, 100);
    }

    testWidgets(
      'fo06/us11/fr05/e04: a far move of an item whose first Tab stop sits in '
      'a nested horizontal ListView lands in semantics with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(tester, boundary: _nestedListBoundary);

        _harness(tester).move(100, 150);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04: a near move of an item whose first Tab stop sits in '
      'a nested horizontal ListView lands in semantics with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(tester, boundary: _nestedListBoundary);

        _harness(tester).move(100, 103);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets('fo06/us11/fr05/e04: a far move of an item under a nested '
        'Semantics(container: true) lands in semantics with no assert', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBoundary(tester, boundary: _semanticsContainerBoundary);

      _harness(tester).move(100, 150);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr05/e04, fo06/us04/fr02/e11: a far move of an item under '
      'a root StratumInkWell lands in semantics with no assert, split by '
      "the item's own Focus",
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(tester, boundary: _inkWellBoundary);

        _harness(tester).move(100, 150);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // s03/inv81: the root StratumInkWell joins at its new slot, but
        // `_Item`'s own per-item Focus and the surface's Focus both set the
        // focused tristate, which Flutter refuses to merge
        // (hasConflictingFlags, ui/semantics.dart:1630-1633@3.47.7): the row
        // still reads split, label and tap below the conflict, button and
        // the moves above it on the node's parent.
        final node = tester.getSemantics(find.text('100'));
        final data = node.getSemanticsData();
        expect(data.label, '100');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(_rootMoves(node.parent!.getSemanticsData()), hasLength(4));
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr04/e05, fo06/us04/fr02/e11: removeItem of an item under '
      'a root StratumInkWell exits with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(tester, boundary: _inkWellBoundary, focus: false);

        _harness(tester).remove(100);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr05/e04, fo06/us04/fr02/e11: a far move of an item whose '
      'StratumInkWell sits inside the row lands in semantics with no '
      "assert, on the surface's own node",
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(tester, boundary: _innerInkWellBoundary);

        _harness(tester).move(100, 150);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final node = tester.getSemantics(find.text('100'));
        final data = node.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(_rootMoves(data), isEmpty);
        // `_Item`'s own per-item Focus and the surface's Focus both set the
        // focused tristate, which Flutter refuses to merge
        // (hasConflictingFlags, ui/semantics.dart:1630-1633@3.47.7), so the
        // moves land two ancestors up, not on the surface's own parent.
        expect(
          _rootMoves(node.parent!.parent!.getSemanticsData()),
          hasLength(4),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr04/e05, fo06/us04/fr02/e11: removeItem of an item whose '
      'StratumInkWell sits inside the row exits with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(
          tester,
          boundary: _innerInkWellBoundary,
          focus: false,
        );

        _harness(tester).remove(100);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets('fo06/us11/fr04/e05: removeItem then insertItem of the same id, around an '
        'item whose first Tab stop sits in a nested horizontal ListView, '
        'exits with no assert', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBoundary(tester, boundary: _nestedListBoundary, focus: false);

      _harness(tester).remove(100);
      await tester.pump();
      _harness(tester).insert(100, 100);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('fo06/us11/fr05/e04: two moveItem calls on one key in one turn, around an '
        'item whose first Tab stop sits in a nested horizontal ListView, land '
        'it in semantics with no assert', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBoundary(tester, boundary: _nestedListBoundary);

      _harness(tester)
        ..move(100, 150)
        ..move(150, 160);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids[160], 100);
      handle.dispose();
    });

    // L6 closed (R44, R47): the identity sliver lands a parked item with no
    // global-key retake.
    testWidgets('fo06/us11/fr05/e04 (L6 closed): a far move whose jump misses the new slot, '
        'past taller items, of an item whose first Tab stop sits in a nested '
        'horizontal ListView lands with no assert', (tester) async {
      final handle = tester.ensureSemantics();
      // Items past 100 are three times as tall as the ones the list laid
      // out, so the frame-start jump estimate falls short of slot 150 and
      // the move's frame parks the item (D7).
      await pumpBoundary(
        tester,
        boundary: _nestedListBoundary,
        heights: {for (var id = 101; id < 200; id++) id: 120},
      );

      _harness(tester).move(100, 150);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    // L6 closed (R44, R47): the identity sliver lands a parked item with no
    // global-key retake.
    testWidgets('fo06/us11/fr05/e04 (L6 closed): a far move while the app holds the scroll, '
        'of an item whose first Tab stop sits in a nested horizontal ListView, '
        'lands with no assert', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBoundary(tester, boundary: _nestedListBoundary);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.addListener(() {
        if (position.pixels != 4000) position.jumpTo(4000);
      });

      _harness(tester).move(100, 150);
      await tester.pump();

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr05/e04 and fr04/e05: moveItem then removeItem of one key in '
      'one turn, around an item whose first Tab stop sits in a nested '
      'horizontal ListView, leaves with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(tester, boundary: _nestedListBoundary);

        _harness(tester)
          ..move(100, 103)
          ..remove(103);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids.contains(100), isFalse);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr04/e05 and fr05/e04: removeItem of an item whose first Tab '
      'stop sits in a nested horizontal ListView, then a far moveItem of '
      'the neighbor it leaves beside, in one turn, settles with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(tester, boundary: _nestedListBoundary, focus: false);

        // Item 100 leaves before item 101, which hosts its exit; the move
        // of 101 ends the exits beside it (`_endExitsBeside`).
        _harness(tester)
          ..remove(100)
          ..move(100, 150);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids[150], 101);
        handle.dispose();
      },
    );

    final reducedOps = ValueVariant<String>({'far move', 'removeItem'});
    testWidgets(
      "NFR-U03, fo06/us11/fr05/e04 and fr04/e05: under the platform's "
      'disableAnimations flag, an item whose first Tab stop sits in a '
      'nested horizontal ListView lands in semantics with no assert',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final handle = tester.ensureSemantics();
        final move = reducedOps.currentValue == 'far move';
        await pumpBoundary(tester, boundary: _nestedListBoundary, focus: move);

        if (move) {
          _harness(tester).move(100, 150);
        } else {
          _harness(tester).remove(100);
        }
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
      variant: reducedOps,
    );

    final midOps = ValueVariant<String>({'far move', 'removeItem'});
    testWidgets(
      'fo06/us11/fr05/e04 and fr04/e05: semantics that turns on after the '
      'landing frame, mid-animation, finds an item whose first Tab stop '
      'sits in a nested horizontal ListView with no assert',
      semanticsEnabled: false,
      (tester) async {
        final move = midOps.currentValue == 'far move';
        await pumpBoundary(tester, boundary: _nestedListBoundary, focus: move);

        if (move) {
          _harness(tester).move(100, 150);
        } else {
          _harness(tester).remove(100);
        }
        await tester.pump();
        expect(tester.binding.renderViews.first.owner!.semanticsOwner, isNull);
        final handle = tester.ensureSemantics();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
      variant: midOps,
    );

    // L5 closed (R48): the chain never re-parents the item, so a caller fade
    // through 0 asserts nothing.
    testWidgets('fo06/us11/fr04 and fr05 (L5 closed): a caller '
        'itemTransitionBuilder that fades through 0, around an item holding '
        'its own semantics boundary, lands with no assert', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBoundary(
        tester,
        boundary: _nestedListBoundary,
        itemTransitionBuilder: (context, animation, child) =>
            FadeTransition(opacity: animation, child: child),
      );

      _harness(tester).move(100, 150);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr04/e02 (R48): an insertItem grow-in under a caller '
      'itemTransitionBuilder that fades through 0, of an item holding its '
      'own semantics boundary, lands with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBoundary(
          tester,
          boundary: _nestedListBoundary,
          boundaryAt: 1000,
          focus: false,
          itemTransitionBuilder: (context, animation, child) =>
              FadeTransition(opacity: animation, child: child),
        );

        _harness(tester).insert(102, 1000);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  });

  group('ReorderableListViewLayout given findChildIndexCallback', () {
    setUp(() => _appIndex = true);
    tearDown(() => _appIndex = false);
    group('pointer', pointerTests);
    group('insert and remove', insertAndRemoveTests);
    group('moveItem', moveItemTests);
    group('drag ends', dragEndsTests);
    group('same-count change during a drag', sameCountDragTests);
    group('unbuilt slots and kept-alive items', keptAliveSlotsTests);
    group('parked moved item', parkedItemTests);
  });

  group('ReorderableListViewLayout focused item gone or scrolled away', () {
    /// Pumps [harness] scrolled to [offset], focuses item [id], and returns
    /// its State and the list's position.
    Future<(_ItemState, ScrollPosition)> pumpFocused(
      WidgetTester tester,
      _Harness harness, {
      int id = 103,
      double offset = 4000,
    }) async {
      final position = await _pumpScrolled(tester, harness, offset: offset);
      final state = _itemState(tester, id);
      await _focusItem(tester, id);
      return (state, position);
    }

    /// The label of the node that holds primary focus.
    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

    /// Each primary focus from now on, by label, every change once.
    List<String?> focusLog() {
      final log = <String?>[];
      void record() {
        final label = focused();
        if (log.isEmpty || log.last != label) log.add(label);
      }

      FocusManager.instance.addListener(record);
      addTearDown(() => FocusManager.instance.removeListener(record));
      return log;
    }

    /// A node labeled `outside`, disposed after the test.
    FocusNode outsideNode() {
      final node = FocusNode(debugLabel: 'outside');
      addTearDown(node.dispose);
      return node;
    }

    /// Pumps [harness] below [outside], a focusable box 20 px tall, and
    /// scrolls the list to [offset].
    Future<ScrollPosition> pumpOutside(
      WidgetTester tester,
      _Harness harness,
      FocusNode outside, {
      double offset = 4000,
    }) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Focus(
                focusNode: outside,
                child: const SizedBox(width: 40, height: 20),
              ),
              Expanded(child: harness),
            ],
          ),
        ),
      );
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position
            ..jumpTo(offset);
      await tester.pump();
      return position;
    }

    // The label of the list's own node that holds focus while a handoff
    // reaches toward a gap with no laid-out neighbor.
    const hold = 'ReorderableListViewLayout hold';

    // Ids from 100 on run 120 px, so a jump into them misses.
    final tall = {for (var id = 100; id < 200; id += 1) id: 120.0};

    /// Focuses item 0 of 200 tall-tailed items, [before] first when given
    /// and [outside] first when [outsideFirst], and in one turn removes it
    /// and inserts it back at slot 199 with the app index, then pumps one
    /// frame: the item waits off screen while the list reaches toward a
    /// slot past its first jump (FR-04 E17).
    Future<_ItemState> parkMidReach(
      WidgetTester tester, {
      FocusNode? outside,
      int? before,
      bool outsideFirst = false,
    }) async {
      final harness = _Harness(
        count: 200,
        appIndex: true,
        heights: tall,
        itemsController: ReorderableItemsController(),
      );
      if (outside == null) {
        await _pumpScrolled(tester, harness, offset: 0);
      } else {
        await pumpOutside(tester, harness, outside, offset: 0);
      }
      if (before != null) await _focusItem(tester, before);
      if (outsideFirst) {
        outside!.requestFocus();
        await tester.pump();
      }
      final state = _itemState(tester, 0);
      await _focusItem(tester, 0);
      _harness(tester)
        ..remove(0)
        ..insert(199, 0);
      await tester.pump();
      return state;
    }

    final appIndex = ValueVariant<bool>({false, true});
    testWidgets('fo06/us11/fr04/e19 and s03/inv26: a focused item the app removes from its '
        'data with no call hands focus to the next item, with or without the '
        'app index', (tester) async {
      final (state, position) = await pumpFocused(
        tester,
        _Harness(count: 1000, appIndex: appIndex.currentValue!),
      );
      final log = focusLog();

      _harness(tester).removeData(103);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
      expect(log, ['item 104']);
      expect(_builtInView(tester, 104), isTrue);
      expect(position.pixels, 4000);
    }, variant: appIndex);

    testWidgets('fo06/us11/fr04/e19: a focused item the app replaces at the same count with '
        'no call hands focus to the item now at its slot', (tester) async {
      final (state, _) = await pumpFocused(
        tester,
        _Harness(count: 1000, appIndex: appIndex.currentValue!),
      );

      _harness(tester).replaceData(103, 5000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
      expect(focused(), 'item 5000');
    }, variant: appIndex);

    final earlier = ValueVariant<String>({'item 102', 'outside'});
    testWidgets('fo06/us11/fr04/e19: the handoff wins over the node that held focus before '
        'the removed item', (tester) async {
      final outside = outsideNode();
      await pumpOutside(tester, const _Harness(count: 1000), outside);
      (earlier.currentValue == 'outside'
              ? outside
              : _itemState(tester, 102).node)
          .requestFocus();
      await tester.pump();
      await _focusItem(tester, 103);

      _harness(tester).removeData(103);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(focused(), 'item 104');
    }, variant: earlier);

    testWidgets(
      'fo06/us11/fr04/e19: the only item, focused and removed with no call, hands '
      "focus to the list's own Tab stop when the list is focusable",
      (tester) async {
        final (state, _) = await pumpFocused(
          tester,
          const _Harness(count: 1, focusable: true),
          id: 0,
          offset: 0,
        );

        _harness(tester).removeData(0);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        expect(focused(), 'ScrollFocus');
      },
    );

    testWidgets('fo06/us11/fr04/e19: the last item, focused and removed with no call, hands '
        'focus to the item before it', (tester) async {
      await pumpFocused(tester, const _Harness(count: 20), id: 19, offset: 500);

      _harness(tester).removeData(19);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(focused(), 'item 18');
      expect(_builtInView(tester, 18), isTrue);
    });

    // How the focused item leaves, and where it was then (R37).
    final plainNeighbors = ValueVariant<(String, String)>({
      ('a raw remove', 'in view'),
      ('a raw remove', 'kept alive off screen'),
      ('removeItem', 'in view'),
      ('removeItem', 'kept alive off screen'),
    });
    testWidgets('fo06/us11/fr04/e19, fo06/us11/fr04/e04, and s03/inv26: a focused item that leaves '
        'between neighbors with no focusable node hands focus to the nearest '
        "item that has one, before the list's own Tab stop and Flutter's "
        'fallback', (tester) async {
      final (change, place) = plainNeighbors.currentValue!;
      final (state, position) = await pumpFocused(
        tester,
        _Harness(
          count: 1000,
          plainIds: const {101, 102, 104},
          itemsController: ReorderableItemsController(),
        ),
      );
      if (place == 'kept alive off screen') {
        position.jumpTo(20000);
        await tester.pump();
      }

      final harness = _harness(tester);
      if (change == 'removeItem') {
        harness.remove(103);
      } else {
        harness.removeData(103);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
      expect(focused(), 'item 105');
      expect(_builtInView(tester, 105), isTrue);
    }, variant: plainNeighbors);

    final resized = ValueVariant<bool>({false, true});
    testWidgets('fo06/us11/fr04/e19 and s03/inv26: the slot counts the calls of the turn: an '
        'insertItem before the focused item and its raw remove hand focus to '
        'the item after it, also when a LayoutBuilder above resizes in that '
        'turn', (tester) async {
      final harness = _Harness(
        count: 1000,
        itemsController: ReorderableItemsController(),
      );
      final height = ValueNotifier<double>(300);
      addTearDown(height.dispose);
      if (resized.currentValue!) {
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (context, value, child) => SizedBox(
                height: value,
                child: LayoutBuilder(
                  builder: (context, constraints) => harness,
                ),
              ),
            ),
          ),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .jumpTo(4000);
        await tester.pump();
      } else {
        await _pumpScrolled(tester, harness);
      }
      await _focusItem(tester, 103);

      _harness(tester)
        ..insert(0, 5000)
        ..removeData(104);
      if (resized.currentValue!) height.value = 290;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids.contains(103), isFalse);
      expect(focused(), 'item 104');
    }, variant: resized);

    final appFocus = ValueVariant<String>({'unfocus', 'item 105'});
    testWidgets(
      'fo06/us11/fr04/e19 and s03/inv26: a focus the app drops or moves in the '
      'turn of the raw remove stays where the app put it',
      (tester) async {
        final (state, _) = await pumpFocused(
          tester,
          const _Harness(count: 1000),
        );
        if (appFocus.currentValue == 'unfocus') {
          state.node.unfocus();
        } else {
          _itemState(tester, 105).node.requestFocus();
        }

        _harness(tester).removeData(103);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final primary = FocusManager.instance.primaryFocus;
        if (appFocus.currentValue == 'unfocus') {
          expect(primary, isA<FocusScopeNode>());
        } else {
          expect(primary?.debugLabel, 'item 105');
        }
      },
      variant: appFocus,
    );

    testWidgets(
      's03/inv26: a list that leaves the tree with focus inside hands no '
      'focus on and throws nothing',
      (tester) async {
        await pumpFocused(tester, const _Harness(count: 1000));

        await tester.pumpWidget(_app(const SizedBox()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      },
    );

    testWidgets('fo06/us11/fr04/e17 and s03/inv32: a parked item whose key the app removes '
        'during the reach is left to the reach, which returns to its origin '
        'and hands focus on from the gap', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          heights: tall,
          itemsController: ReorderableItemsController(),
        ),
        offset: 0,
      );
      final state = _itemState(tester, 0);
      await _focusItem(tester, 0);
      _harness(tester)
        ..remove(0)
        ..insert(199, 0);
      await tester.pump();
      await tester.pump();

      _harness(tester).removeData(199);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
      expect(focused(), 'item 1');
      expect(position.pixels, 0);
    });

    testWidgets('fo06/us11/fr04/e17, fo06/us11/fr03/e11, and s03/inv32: Tab from a parked item '
        'during the retry frames brings it back, then moves focus from its '
        'slot, and that focus move ends the reach', (tester) async {
      await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          heights: tall,
          itemsController: ReorderableItemsController(),
        ),
        offset: 0,
      );
      final state = _itemState(tester, 0);
      await _focusItem(tester, 0);
      _harness(tester)
        ..remove(0)
        ..insert(150, 0);
      await tester.pump();
      expect(_statesOf(tester, 0), [same(state)]);
      expect(_builtInView(tester, 0), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(focused(), 'item 151');
      expect(_builtInView(tester, 151), isTrue);
      expect(_statesOf(tester, 0), [same(state)]);
    });

    testWidgets(
      'fo06/us11/fr05/e04 and s03/inv26: a moveItem whose item the app removes in '
      'the same turn with no call hands focus on once, through the follow',
      (tester) async {
        await pumpFocused(
          tester,
          _Harness(count: 1000, itemsController: ReorderableItemsController()),
        );
        final log = focusLog();

        _harness(tester)
          ..move(103, 600)
          ..removeData(600);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(focused(), 'item 104');
        expect(
          [
            for (final label in log)
              if (label != null && label.startsWith('item ')) label,
          ],
          ['item 104'],
        );
      },
    );

    final before = ValueVariant<int?>({null, 3});
    testWidgets('fo06/us11/fr04/e19 and s03/inv26: a parked item whose key the app replaces '
        'short of the reach hands focus to the hold node, and the reach then '
        'to the item at the slot', (tester) async {
      final state = await parkMidReach(tester, before: before.currentValue);
      final log = focusLog();

      _harness(tester).replaceData(199, 5000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
      expect(log, [hold, 'item 5000']);
      expect(_builtInView(tester, 5000), isTrue);
    }, variant: before);

    testWidgets('fo06/us11/fr04/e19 and s03/inv26: a focus the app requests after the frame '
        'stays while the list would reach toward the gap', (tester) async {
      final outside = outsideNode();
      await parkMidReach(tester, outside: outside);

      _harness(tester).replaceData(199, 5000);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => outside.requestFocus(),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(focused(), 'outside');
    });

    testWidgets(
      's03/inv26: a focus the app moves off the hold node during the reach '
      'ends the reach',
      (tester) async {
        final outside = outsideNode();
        await parkMidReach(tester, outside: outside);
        final log = focusLog();

        _harness(tester).replaceData(199, 5000);
        await tester.pump();
        expect(focused(), hold);
        outside.requestFocus();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(focused(), 'outside');
        expect(log, [hold, 'outside']);
      },
    );

    final appTarget = ValueVariant<String>({'item 105', 'outside'});
    testWidgets('fo06/us11/fr04/e19 and s03/inv26: a focus the app requests after the frame '
        'of a raw remove stays', (tester) async {
      final outside = outsideNode();
      await pumpOutside(tester, const _Harness(count: 1000), outside);
      await _focusItem(tester, 103);
      final target = appTarget.currentValue == 'outside'
          ? outside
          : _itemState(tester, 105).node;

      _harness(tester).removeData(103);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => target.requestFocus(),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(focused(), appTarget.currentValue);
    }, variant: appTarget);

    testWidgets('fo06/us11/fr04/e19 and s03/inv26: the list reveals a handoff target only '
        'while that target holds focus', (tester) async {
      final (_, position) = await pumpFocused(
        tester,
        const _Harness(count: 1000),
        id: 107,
      );
      final other = _itemState(tester, 101).node;

      _harness(tester).removeData(107);
      WidgetsBinding.instance.addPostFrameCallback((_) => other.requestFocus());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(focused(), 'item 101');
      expect(position.pixels, 4000);
    });

    final requests = ValueVariant<String>({
      'item 105 before the call',
      'item 105 after the call',
      'outside before the call',
      'outside after the call',
    });
    testWidgets(
      'fo06/us11/fr04/e04 and s03/inv26: a focus the app requests after the frame '
      'of a removeItem stays, registered before the call or after it',
      (tester) async {
        final request = requests.currentValue!;
        final outside = outsideNode();
        await pumpOutside(
          tester,
          _Harness(count: 1000, itemsController: ReorderableItemsController()),
          outside,
        );
        await _focusItem(tester, 103);
        final target = request.startsWith('outside')
            ? outside
            : _itemState(tester, 105).node;
        void requestAfterFrame() => WidgetsBinding.instance
            .addPostFrameCallback((_) => target.requestFocus());

        if (request.endsWith('before the call')) requestAfterFrame();
        _harness(tester).remove(103);
        if (request.endsWith('after the call')) requestAfterFrame();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(focused(), target.debugLabel);
      },
      variant: requests,
    );

    testWidgets('fo06/us11/fr03/e11 and s03/inv35: a focused item scrolled out of view stays '
        'alive off screen with its State and focus, and the list scrolls '
        'nothing for it', (tester) async {
      final (state, position) = await pumpFocused(
        tester,
        const _Harness(count: 1000),
      );

      position.jumpTo(20000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isFalse);
      expect(position.pixels, 20000);
    });

    // A call of the app's controller that shifts the item kept alive off
    // screen, with no app index, and the item's index after it (R35).
    final shiftingCalls = ValueVariant<(String, int)>({
      ('insertItem', 104),
      ('removeItem', 102),
      ('moveItem of another item', 104),
    });
    testWidgets('fo06/us11/fr03/e11 and s03/inv35: with no app index, a call that shifts the '
        'focused item kept alive off screen keeps its State and focus, and the '
        'list scrolls nothing for it', (tester) async {
      final (call, shiftedTo) = shiftingCalls.currentValue!;
      final (state, position) = await pumpFocused(
        tester,
        _Harness(count: 1000, itemsController: ReorderableItemsController()),
      );
      position.jumpTo(20000);
      await tester.pump();
      final log = focusLog();

      final harness = _harness(tester);
      switch (call) {
        case 'insertItem':
          harness.insert(0, 5000);
        case 'removeItem':
          harness.remove(0);
        default:
          harness.move(900, 0);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids.indexOf(103), shiftedTo);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(log, isEmpty);
      expect(_builtInView(tester, 103), isFalse);
      expect(position.pixels, 20000);
    }, variant: shiftingCalls);

    // Calls that shift the focused item, shown whole at an edge of a list
    // with no cache extent, past the slots the frame laid out, with or
    // without the app index: the item focused, the offset, and the calls.
    // The sliver keeps the slot that ends at the list's top edge, so a
    // shift up leaves the laid-out slots only past it.
    final shiftedOut = ValueVariant<(int, double, String, bool)>({
      for (final withIndex in [false, true]) ...{
        (107, 4020, 'insertItem', withIndex),
        (100, 4000, 'removeItem twice', withIndex),
      },
    });
    testWidgets('fo06/us11/fr05/e04 and s03/inv35: a call that shifts the focused item from '
        'a laid-out slot to one the frame does not lay out keeps its State and '
        'focus, and the list reveals it at its new slot', (tester) async {
      final (id, offset, call, withIndex) = shiftedOut.currentValue!;
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 1000,
          appIndex: withIndex,
          scrollCacheExtent: const ScrollCacheExtent.pixels(0),
          itemsController: ReorderableItemsController(),
        ),
        offset: offset,
      );
      final state = _itemState(tester, id);
      await _focusItem(tester, id);
      expect(_builtInView(tester, id), isTrue);
      expect(position.pixels, offset);

      final harness = _harness(tester);
      if (call == 'insertItem') {
        harness.insert(0, 5000);
      } else {
        harness
          ..remove(0)
          ..remove(0);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids.indexOf(id), call == 'insertItem' ? 108 : 98);
      expect(_statesOf(tester, id), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, id), isTrue);
      // Slot 108's 40 px average puts its leading edge at 4320; the least
      // scroll landing from below stops at the trailing edge instead.
      if (call == 'insertItem') expect(position.pixels, 4060);
    }, variant: shiftedOut);

    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv35: a focused item the frame builds anew, '
      'with no focus move, stays alive when scrolled out of view',
      (tester) async {
        final (state, position) = await pumpFocused(
          tester,
          const _Harness(count: 1000),
        );
        _harness(tester).moveData(103, 105);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(state.node));

        position.jumpTo(20000);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(position.pixels, 20000);
      },
    );

    testWidgets('fo06/us11/fr03/e11: Alt with an arrow moves the focused item kept alive off '
        'screen and reveals it', (tester) async {
      final (state, position) = await pumpFocused(
        tester,
        const _Harness(count: 1000),
      );
      position.jumpTo(20000);
      await tester.pump();

      await _alt(tester, LogicalKeyboardKey.arrowDown);

      expect(tester.takeException(), isNull);
      expect(_harness(tester).ids.indexOf(103), 104);
      expect(_statesOf(tester, 103), [same(state)]);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isTrue);
      expect(position.pixels, 4160);
    });

    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv35: a focus the app moves to another item '
      'lets the item kept alive off screen go, with no handoff',
      (tester) async {
        final (state, position) = await pumpFocused(
          tester,
          const _Harness(count: 1000),
        );
        position.jumpTo(20000);
        await tester.pump();
        final log = focusLog();

        _itemState(tester, 500).node.requestFocus();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        expect(log, ['item 500']);
      },
    );

    final letGo = ValueVariant<String>({'canceled', 'dropped'});
    final traversals = ValueVariant<String>({
      'Tab',
      'Shift+Tab',
      'Tab at the list end',
    });
    testWidgets('fo06/us11/fr03/e11 and s03/inv21: Tab or Shift+Tab from the focused item '
        'kept alive off screen brings it back, then moves focus from its place '
        'and reveals the target', (tester) async {
      final traversal = traversals.currentValue!;
      final (state, position) = await pumpFocused(
        tester,
        const _Harness(count: 1000),
      );
      position.jumpTo(traversal == 'Tab at the list end' ? 39700 : 20000);
      await tester.pump();

      if (traversal == 'Shift+Tab') {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pumpAndSettle();

      final target = traversal == 'Shift+Tab' ? 102 : 104;
      expect(tester.takeException(), isNull);
      expect(focused(), 'item $target');
      expect(_builtInView(tester, target), isTrue);
      expect(_statesOf(tester, 103), [same(state)]);
    }, variant: traversals);

    for (final (name, key, target) in [
      ('Up', LogicalKeyboardKey.arrowUp, 102),
      ('Down', LogicalKeyboardKey.arrowDown, 104),
    ]) {
      testWidgets(
        'fo06/us11/fr03/e11 and s03/inv21: $name from the focused item kept alive '
        'off screen brings it back, then moves focus to item $target',
        (tester) async {
          final (state, position) = await pumpFocused(
            tester,
            const _Harness(count: 1000),
          );
          position.jumpTo(20000);
          await tester.pump();

          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(focused(), 'item $target');
          expect(_builtInView(tester, target), isTrue);
          expect(_statesOf(tester, 103), [same(state)]);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }

    /// Pumps 1000 items on a list of [shape], `reversed`, `horizontal`, or
    /// `right-to-left`, scrolled to px 4000, focuses item 103, and returns
    /// its State and the list's position.
    Future<(_ItemState, ScrollPosition)> pumpShaped(
      WidgetTester tester,
      String shape,
    ) async {
      final horizontal = shape != 'reversed';
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 1000,
          axis: horizontal ? Axis.horizontal : Axis.vertical,
          reverse: shape == 'reversed',
          itemsController: ReorderableItemsController(),
        ),
        textDirection: shape == 'right-to-left'
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
      final state = _itemState(tester, 103);
      await _focusItem(tester, 103);
      return (state, position);
    }

    // A list shape other than a plain vertical one (D21 to D24).
    final listShapes = ValueVariant<String>({
      'reversed',
      'horizontal',
      'right-to-left',
    });
    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv35: a focused item on a reversed, horizontal, '
      'or right-to-left list scrolled out of view stays alive off screen with '
      'its State and focus, and the list scrolls nothing',
      (tester) async {
        final shape = listShapes.currentValue!;
        final (state, position) = await pumpShaped(tester, shape);

        position.jumpTo(20000);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isFalse);
        expect(position.pixels, 20000);
      },
      variant: listShapes,
    );

    // Where the focused item was when the app dropped it, on each shape.
    final shapedDrops = ValueVariant<(String, String)>({
      for (final shape in ['reversed', 'horizontal', 'right-to-left'])
        for (final place in ['in view', 'kept alive off screen'])
          (shape, place),
    });
    testWidgets(
      'fo06/us11/fr04/e19 and s03/inv26: a focused item on a reversed, horizontal, '
      'or right-to-left list that the app drops with no call hands focus to '
      'the next item, which the list reaches back to and shows',
      (tester) async {
        final (shape, place) = shapedDrops.currentValue!;
        final (state, position) = await pumpShaped(tester, shape);
        if (place == 'kept alive off screen') {
          position.jumpTo(20000);
          await tester.pump();
        }

        _harness(tester).removeData(103);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        expect(focused(), 'item 104');
        expect(_builtInView(tester, 104), isTrue);
      },
      variant: shapedDrops,
    );

    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv21: Tab from the focused item kept alive off '
      'screen on a reversed, horizontal, or right-to-left list brings it back, '
      'then moves focus as Tab from the item in view does and shows the target',
      (tester) async {
        final shape = listShapes.currentValue!;
        final (state, position) = await pumpShaped(tester, shape);
        position.jumpTo(20000);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        // Reading order follows the screen: on a reversed list item 102
        // sits below item 103, so Tab from 103 in view reaches it too.
        final target = shape == 'reversed' ? 102 : 104;
        expect(tester.takeException(), isNull);
        expect(focused(), 'item $target');
        expect(_builtInView(tester, target), isTrue);
        expect(_statesOf(tester, 103), [same(state)]);
      },
      variant: listShapes,
    );

    // The arrow that points from item 103 toward item 104 on each shape.
    for (final (shape, name, key) in [
      ('reversed', 'Up', LogicalKeyboardKey.arrowUp),
      ('horizontal', 'Right', LogicalKeyboardKey.arrowRight),
      ('right-to-left', 'Left', LogicalKeyboardKey.arrowLeft),
    ]) {
      testWidgets(
        'fo06/us11/fr03/e11 and s03/inv21: on a $shape list, $name from the '
        'focused item kept alive off screen brings it back, then moves focus '
        'to item 104',
        (tester) async {
          final (state, position) = await pumpShaped(tester, shape);
          position.jumpTo(20000);
          await tester.pump();

          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(focused(), 'item 104');
          expect(_builtInView(tester, 104), isTrue);
          expect(_statesOf(tester, 103), [same(state)]);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }

    final removals = ValueVariant<String>({
      'item 103',
      'item 103 under reduced motion',
      'the last item',
    });
    testWidgets('fo06/us11/fr04/e04 and s03/inv26: removeItem of the focused item kept alive '
        'off screen hands focus to its neighbor, which the list reaches and '
        'shows whole once the remove motion ends', (tester) async {
      final removal = removals.currentValue!;
      final reduced = removal.endsWith('reduced motion');
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final last = removal == 'the last item';
      final id = last ? 999 : 103;
      final (state, position) = await pumpFocused(
        tester,
        _Harness(count: 1000, itemsController: ReorderableItemsController()),
        id: id,
        offset: last ? 39700 : 4000,
      );
      position.jumpTo(20000);
      await tester.pump();
      expect(_statesOf(tester, id), [same(state)]);

      _harness(tester).remove(id);
      await tester.pumpAndSettle();

      final target = last ? 998 : 104;
      expect(tester.takeException(), isNull);
      expect(focused(), 'item $target');
      expect(_builtInView(tester, target), isTrue);
      expect(
        position.pixels,
        closeTo(last ? 39660 : (reduced ? 4120 : 4156), 0.5),
      );
    }, variant: removals);

    final scrollTurn = ValueVariant<String>({
      'a turn after the scroll',
      'in the turn of the scroll',
    });
    testWidgets(
      'fo06/us11/fr04/e19 and s03/inv26: a raw remove of the focused item kept '
      'alive off screen hands focus to the next item, which the list reaches '
      'back to',
      (tester) async {
        final (state, position) = await pumpFocused(
          tester,
          const _Harness(count: 1000),
        );
        position.jumpTo(20000);
        if (scrollTurn.currentValue == 'a turn after the scroll') {
          await tester.pump();
        }

        _harness(tester).removeData(103);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        expect(focused(), 'item 104');
        expect(position.pixels, 4120);
      },
      variant: scrollTurn,
    );

    testWidgets('fo06/us11/fr05/e13 and fo06/us11/fr04/e19: a raw move of the focused item kept '
        'alive off screen follows it in place with the app index, scrolling '
        'nothing, and with none hands focus to the next item, which the list '
        'reaches back to', (tester) async {
      final withIndex = appIndex.currentValue!;
      final (state, position) = await pumpFocused(
        tester,
        _Harness(count: 1000, appIndex: withIndex),
      );
      position.jumpTo(20000);
      await tester.pump();

      _harness(tester).moveData(103, 800);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (withIndex) {
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isFalse);
        expect(position.pixels, 20000);

        // The next focus move brings it back from its new slot (D24).
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(focused(), 'item 801');
        expect(_builtInView(tester, 801), isTrue);
        return;
      }
      expect(state.mounted, isFalse);
      expect(focused(), 'item 104');
      expect(position.pixels, 4120);
    }, variant: appIndex);

    // A data change with no call that shifts the item kept alive off
    // screen, and the item's index after it (R36).
    final rawShifts = ValueVariant<(String, int)>({
      ('an insert before it', 104),
      ('a remove before it', 102),
      ('a move of another item past it', 104),
    });
    testWidgets(
      'fo06/us11/fr05/e13 and fo06/us11/fr03/e11: with the app index, a raw shift of '
      'the focused item kept alive off screen follows it in place, keeping '
      'its State and focus, and the list scrolls nothing for it',
      (tester) async {
        final (change, shiftedTo) = rawShifts.currentValue!;
        final (state, position) = await pumpFocused(
          tester,
          const _Harness(count: 1000, appIndex: true),
        );
        position.jumpTo(20000);
        await tester.pump();
        final log = focusLog();

        final harness = _harness(tester);
        switch (change) {
          case 'an insert before it':
            harness.insertData(0, 5000);
          case 'a remove before it':
            harness.removeData(0);
          default:
            harness.moveData(900, 0);
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ids.indexOf(103), shiftedTo);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(log, isEmpty);
        expect(_builtInView(tester, 103), isFalse);
        expect(position.pixels, 20000);
      },
      variant: rawShifts,
    );

    final ownMoves = ValueVariant<String>({'moveItem', 'Alt+Down'});
    testWidgets(
      'fo06/us11/fr05/e04 and fo06/us11/fr03/e11: with the app index, a moveItem or a '
      'reorder key of the focused item kept alive off screen still reveals it',
      (tester) async {
        final (state, position) = await pumpFocused(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            itemsController: ReorderableItemsController(),
          ),
        );
        position.jumpTo(20000);
        await tester.pump();

        if (ownMoves.currentValue == 'moveItem') {
          _harness(tester).move(103, 800);
          await tester.pumpAndSettle();
        } else {
          await _alt(tester, LogicalKeyboardKey.arrowDown);
        }

        final to = ownMoves.currentValue == 'moveItem' ? 800 : 104;
        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids.indexOf(103), to);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isTrue);
        expect(position.pixels, isNot(20000));
      },
      variant: ownMoves,
    );

    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv35: a focused item lifted, scrolled out of '
      'view, and let go stays alive off screen with its State and focus',
      (tester) async {
        final (state, position) = await pumpFocused(
          tester,
          const _Harness(count: 1000),
        );
        final gesture = await _liftItem(tester, 103);
        position.jumpTo(20000);
        await tester.pump();

        if (letGo.currentValue == 'canceled') {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();

        final harness = _harness(tester);
        expect(tester.takeException(), isNull);
        expect(harness.ends, [103]);
        expect(harness.moves, isEmpty);
        expect(_statesOf(tester, 103), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        expect(_builtInView(tester, 103), isFalse);
        expect(position.pixels, 20000);
      },
      variant: letGo,
    );

    testWidgets('fo06/us11/fr03/e11 and s03/inv21: when a list the app holds in place never '
        'lays out the focused item kept alive off screen, Tab lands on the '
        'first item that shows', (tester) async {
      final (state, position) = await pumpFocused(
        tester,
        const _Harness(count: 1000),
      );
      position.jumpTo(20000);
      await tester.pump();
      _pinScroll(tester, 20000);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(focused(), 'item 500');
      expect(_builtInView(tester, 500), isTrue);
      expect(position.pixels, 20000);
      expect(state.mounted, isFalse);
    });

    testWidgets('fo06/us11/fr03/e11 and s03/inv21: a nextFocus the app calls on the focused '
        'item kept alive off screen brings it back first and lands on the next '
        'item', (tester) async {
      final (state, position) = await pumpFocused(
        tester,
        const _Harness(count: 1000),
      );
      position.jumpTo(20000);
      await tester.pump();

      final moved = state.node.nextFocus();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(moved, isTrue);
      expect(focused(), 'item 104');
      expect(_builtInView(tester, 104), isTrue);
      expect(position.pixels, 4120);
    });

    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv21: a previousFocus the app calls on the '
      'focused item kept alive off screen lands on the item before it',
      (tester) async {
        final (state, position) = await pumpFocused(
          tester,
          const _Harness(count: 1000),
        );
        position.jumpTo(20000);
        await tester.pump();

        final moved = state.node.previousFocus();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(moved, isTrue);
        expect(focused(), 'item 102');
        expect(_builtInView(tester, 102), isTrue);
        expect(position.pixels, 4080);
      },
    );

    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv21: a focus the app moves while the list '
      'brings the item back stays where the app put it',
      (tester) async {
        final (state, position) = await pumpFocused(
          tester,
          const _Harness(count: 1000),
        );
        position.jumpTo(20000);
        await tester.pump();

        state.node.nextFocus();
        _itemState(tester, 500).node.requestFocus();
        final log = focusLog();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(focused(), 'item 500');
        expect(log, ['item 500']);
      },
    );

    testWidgets('fo06/us11/fr03/e11 and s03/inv21: when a list the app holds in place never '
        'lays out the focused item kept alive off screen, Shift+Tab lands on '
        'the last item that shows', (tester) async {
      final (state, position) = await pumpFocused(
        tester,
        const _Harness(count: 1000),
      );
      position.jumpTo(20000);
      await tester.pump();
      _pinScroll(tester, 20000);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // The viewport shows items 500 to 507; item 507 shows in part.
      final view = tester.getRect(find.byType(Scrollable));
      final item = tester.getRect(find.byKey(const ValueKey(507)));
      expect(tester.takeException(), isNull);
      expect(focused(), 'item 507');
      expect(view.overlaps(item), isTrue);
      expect(position.pixels, 20000);
      expect(state.mounted, isFalse);
    });

    // Whether the list is a Tab stop, and the key that moves focus.
    final leaves = ValueVariant<({bool focusable, String key})>({
      for (final focusable in [false, true])
        for (final key in ['Tab', 'Shift+Tab'])
          (focusable: focusable, key: key),
    });
    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv21: when a list the app holds in place never '
      'lays out the focused text field kept alive off screen and no other '
      'node in it shows, Tab or Shift+Tab leaves the list in its direction',
      (tester) async {
        final (:focusable, :key) = leaves.currentValue!;
        final before = FocusNode(debugLabel: 'before');
        final after = FocusNode(debugLabel: 'after');
        addTearDown(before.dispose);
        addTearDown(after.dispose);
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                Focus(
                  focusNode: before,
                  child: const SizedBox(width: 40, height: 20),
                ),
                Expanded(
                  child: _Harness(
                    count: 1000,
                    fieldAt: 103,
                    plainIds: {for (var id = 0; id < 1000; id += 1) id},
                    focusable: focusable,
                  ),
                ),
                Focus(
                  focusNode: after,
                  child: const SizedBox(width: 40, height: 20),
                ),
              ],
            ),
          ),
        );
        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position
              ..jumpTo(4000);
        await tester.pump();
        final state = _itemState(tester, 103);
        await _focusItem(tester, 103);
        position.jumpTo(20000);
        await tester.pump();
        _pinScroll(tester, 20000);

        final back = key == 'Shift+Tab';
        if (back) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        if (back) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        // Backward, the list's own Tab stop comes before its content.
        final target = !back
            ? 'after'
            : focusable
            ? 'ScrollFocus'
            : 'before';
        expect(tester.takeException(), isNull);
        expect(focused(), target);
        expect(position.pixels, 20000);
        expect(state.mounted, isFalse);
      },
      variant: leaves,
    );

    testWidgets('fo06/us11/fr03/e11 and s03/inv21: an action the app binds to Tab inside the '
        'focused item kept alive off screen runs in place of the move, and the '
        'list scrolls nothing', (tester) async {
      var runs = 0;
      await tester.pumpWidget(
        _app(
          ReorderableListViewLayout.builder(
            itemCount: 1000,
            onReorderItem: (from, to) {},
            itemBuilder: (context, index) => Actions(
              key: ValueKey('actions $index'),
              actions: {
                NextFocusIntent: CallbackAction<NextFocusIntent>(
                  onInvoke: (intent) => runs += 1,
                ),
              },
              child: _Item(key: ValueKey(index), id: index, index: index),
            ),
          ),
        ),
      );
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position
            ..jumpTo(4000);
      await tester.pump();
      final state = _itemState(tester, 103);
      await _focusItem(tester, 103);
      position.jumpTo(20000);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(runs, 1);
      expect(FocusManager.instance.primaryFocus, same(state.node));
      expect(_builtInView(tester, 103), isFalse);
      expect(position.pixels, 20000);
    });

    final groupMoves = ValueVariant<String>({'Tab', 'Shift+Tab'});
    testWidgets(
      'fo06/us11/fr03/e11 and s03/inv21: Tab or Shift+Tab from a focus group '
      'inside the focused item kept alive off screen brings the item back, '
      'then leaves the group for the item next in order and shows it',
      (tester) async {
        final nodes = <String, FocusNode>{};
        addTearDown(() {
          for (final node in nodes.values) {
            node.dispose();
          }
        });
        FocusNode node(String label) =>
            nodes.putIfAbsent(label, () => FocusNode(debugLabel: label));
        await tester.pumpWidget(
          _app(
            ReorderableListViewLayout.builder(
              itemCount: 1000,
              onReorderItem: (from, to) {},
              itemBuilder: (context, index) => SizedBox(
                key: ValueKey(index),
                height: 40,
                child: RowLayout(
                  focusGroup: const FocusGroup(),
                  children: [
                    for (final side in ['a', 'b'])
                      Focus(
                        focusNode: node('$side $index'),
                        child: const SizedBox(width: 40, height: 40),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position
              ..jumpTo(4000);
        await tester.pump();
        node('a 103').requestFocus();
        await tester.pump();
        position.jumpTo(20000);
        await tester.pump();

        final back = groupMoves.currentValue == 'Shift+Tab';
        if (back) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        if (back) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        final target = back ? 102 : 104;
        expect(tester.takeException(), isNull);
        expect(focused(), 'a $target');
        expect(_builtInView(tester, target), isTrue);
      },
      variant: groupMoves,
    );

    // Where the item that holds the row stands when Tab is pressed.
    final rowPlaces = ValueVariant<String>({
      'in view',
      'kept alive off screen',
    });
    testWidgets('fo06/us11/fr03/e11 and s03/inv21: Tab from a text field that a row inside '
        'an item scrolled out of view brings the item and then the field back, '
        'then moves to the next field and shows it', (tester) async {
      final fields = [
        for (var index = 0; index < 100; index++)
          FocusNode(debugLabel: 'field $index'),
      ];
      addTearDown(() {
        for (final field in fields) {
          field.dispose();
        }
      });
      const rowKey = Key('row');
      await tester.pumpWidget(
        _app(
          ReorderableListViewLayout.builder(
            itemCount: 1000,
            onReorderItem: (from, to) {},
            itemBuilder: (context, index) => SizedBox(
              key: ValueKey(index),
              height: 40,
              child: index == 103
                  ? ListViewLayout.builder(
                      key: rowKey,
                      scrollDirection: Axis.horizontal,
                      itemCount: fields.length,
                      itemBuilder: (context, field) => SizedBox(
                        width: 40,
                        child: TextField(focusNode: fields[field]),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      );
      // The row's own Scrollable, above the one each text field holds.
      final rowView = find
          .descendant(of: find.byKey(rowKey), matching: find.byType(Scrollable))
          .first;
      final listView = find.byType(Scrollable).first;
      final list = tester.state<ScrollableState>(listView).position
        ..jumpTo(4000);
      await tester.pump();
      final row = tester.state<ScrollableState>(rowView).position..jumpTo(1100);
      await tester.pump();
      fields[30].requestFocus();
      await tester.pump();
      row.jumpTo(3000);
      await tester.pump();
      if (rowPlaces.currentValue == 'kept alive off screen') {
        list.jumpTo(20000);
        await tester.pump();
      }
      expect(fields[30].rect.isFinite, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'field 31');
      final field = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.focusNode == fields[31],
        ),
      );
      expect(tester.getRect(rowView).intersect(field), field);
      expect(tester.getRect(listView).intersect(field), field);
    }, variant: rowPlaces);

    testWidgets(
      's03/inv21: Tab from a text field that a row scrolled out of view, at '
      'the bottom of a laid-out item taller than the list, brings only the '
      'field back and scrolls the list nothing',
      (tester) async {
        final fields = [
          for (var index = 0; index < 100; index++)
            FocusNode(debugLabel: 'field $index'),
        ];
        addTearDown(() {
          for (final field in fields) {
            field.dispose();
          }
        });
        const rowKey = Key('row');
        await tester.pumpWidget(
          _app(
            ReorderableListViewLayout.builder(
              itemCount: 1000,
              onReorderItem: (from, to) {},
              itemBuilder: (context, index) => SizedBox(
                key: ValueKey(index),
                // Item 103 runs 600 px in a 300 px list, its row at the
                // bottom.
                height: index == 103 ? 600 : 40,
                child: index == 103
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: 40,
                          child: ListViewLayout.builder(
                            key: rowKey,
                            scrollDirection: Axis.horizontal,
                            itemCount: fields.length,
                            itemBuilder: (context, field) => SizedBox(
                              width: 40,
                              child: TextField(focusNode: fields[field]),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
        // The row's own Scrollable, above the one each text field holds.
        final rowView = find
            .descendant(
              of: find.byKey(rowKey),
              matching: find.byType(Scrollable),
            )
            .first;
        final listView = find.byType(Scrollable).first;
        // Item 103 runs from 4120 to 4720: the list shows its bottom 220 px,
        // so a focused field's own caret reveal stays inside the list.
        final list = tester.state<ScrollableState>(listView).position
          ..jumpTo(4500);
        await tester.pump();
        final row = tester.state<ScrollableState>(rowView).position
          ..jumpTo(1100);
        await tester.pump();
        fields[30].requestFocus();
        await tester.pump();
        row.jumpTo(3000);
        await tester.pump();
        expect(fields[30].rect.isFinite, isFalse);
        final jumps = <double>[];
        list.addListener(() => jumps.add(list.pixels));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'field 31');
        final field = tester.getRect(
          find.byWidgetPredicate(
            (widget) => widget is TextField && widget.focusNode == fields[31],
          ),
        );
        expect(tester.getRect(rowView).intersect(field), field);
        expect(tester.getRect(listView).intersect(field), field);
        expect(jumps, isEmpty);
        expect(list.pixels, 4500);
      },
    );

    final fallback = ValueVariant<String>({'route scope', 'outside'});
    testWidgets('fo06/us11/fr04/e19 and s03/inv26: when the reach toward the gap finds no '
        'target, the list emptied and no Tab stop of its own, the hold node '
        'lets go and focus falls back as Flutter does: to the node focused '
        'before, else to the route scope', (tester) async {
      final outside = outsideNode();
      await parkMidReach(
        tester,
        outside: outside,
        outsideFirst: fallback.currentValue == 'outside',
      );
      _harness(tester).replaceData(199, 5000);
      await tester.pump();
      expect(focused(), hold);

      final harness = _harness(tester);
      for (var index = harness.ids.length - 1; index >= 0; index -= 1) {
        harness.removeData(index);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ids, isEmpty);
      if (fallback.currentValue == 'outside') {
        expect(FocusManager.instance.primaryFocus, same(outside));
      } else {
        final routeScope = FocusScope.of(harness.context);
        expect(routeScope.debugLabel, contains('_ModalScopeState'));
        expect(FocusManager.instance.primaryFocus, same(routeScope));
      }
    }, variant: fallback);
  });

  group('ReorderableListViewLayout screen reader', () {
    testWidgets('fo06/us11/fr06 and s03/inv58: a screen reader reads the item count, also '
        'after an insert and a remove', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: ReorderableItemsController())),
      );

      SemanticsNode scrollNode() => find.semantics
          .byFlag(SemanticsFlag.hasImplicitScrolling)
          .evaluate()
          .single;

      expect(scrollNode().scrollChildCount, 5);

      _harness(tester).insert(0, 9);
      await tester.pumpAndSettle();
      expect(scrollNode().scrollChildCount, 6);

      _harness(tester).remove(0);
      await tester.pump();
      // A leaving item counts no more: `itemCount` drops to the new data
      // count before the item's own removal animation ends.
      expect(scrollNode().scrollChildCount, 5);
      await tester.pumpAndSettle();
      expect(scrollNode().scrollChildCount, 5);

      handle.dispose();
    });

    final moveWays = ValueVariant<String>({'key', 'action', 'drop'});
    testWidgets('fo06/us11/fr06/e01 and s03/inv60: a reorder key, a screen-reader action, '
        'and a drop each announce the new position', (tester) async {
      final handle = moveWays.currentValue == 'action'
          ? tester.ensureSemantics()
          : null;
      await tester.pumpWidget(_app(const _Harness(count: 5)));
      final log = _announcements(tester);

      switch (moveWays.currentValue) {
        case 'key':
          await _focusItem(tester, 2);
          await _altNow(tester, LogicalKeyboardKey.arrowDown);
          // The move lands in this turn and is heard after its frame.
          expect(log, isEmpty);
          await tester.pump();
          expect(log, ['Moved to position 4 of 5']);
        case 'action':
          await _moveAction(tester, 2, 'Move down');
          expect(log, ['Moved to position 4 of 5']);
        case 'drop':
          final gesture = await _liftItem(tester, 0);
          await _dragPastNeighbor(tester, gesture);
          await tester.pumpAndSettle();
          await gesture.up();
          await tester.pumpAndSettle();
          expect(log, ['Moved to position 2 of 5']);
      }
      handle?.dispose();
    }, variant: moveWays);

    final layouts = ValueVariant<String>({'vertical', 'horizontal rtl'});
    testWidgets('fo06/us11/fr06/e02 and fo06/us11/fr02/e01: a reorder key past either end '
        'announces the end the item holds', (tester) async {
      final horizontal = layouts.currentValue == 'horizontal rtl';
      await tester.pumpWidget(
        horizontal
            ? _app(
                const _Harness(count: 3, axis: Axis.horizontal),
                textDirection: TextDirection.rtl,
              )
            : _app(const _Harness(count: 5)),
      );
      final log = _announcements(tester);

      await _focusItem(tester, 0);
      // Toward the item's start on screen: right in a right-to-left row.
      await _alt(
        tester,
        horizontal ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowUp,
      );
      await _focusItem(tester, horizontal ? 2 : 4);
      await _alt(
        tester,
        horizontal ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.end,
      );

      expect(log, [
        'Already at the start of the list',
        'Already at the end of the list',
      ]);
      expect(_harness(tester).moves, isEmpty);
    }, variant: layouts);

    testWidgets(
      'fo06/us11/fr06/e08 and s03/inv60: a reorder key held past an end '
      'announces once, on its key-down',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 5)));
        final log = _announcements(tester);
        await _focusItem(tester, 0);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
        for (var repeat = 0; repeat < 3; repeat += 1) {
          await tester.pump(const Duration(milliseconds: 33));
          await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        expect(log, ['Already at the start of the list']);
        expect(_harness(tester).moves, isEmpty);
      },
    );

    testWidgets('fo06/us11/fr06/e08 and s03/inv60: a reorder key held down announces once, '
        'where the item ends, when the key is let go', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 10)));
      final log = _announcements(tester);
      await _focusItem(tester, 2);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      for (var repeat = 0; repeat < 3; repeat += 1) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      // Each repeat moved the item, and the key is still down.
      expect(_harness(tester).moves, [(2, 3), (3, 4), (4, 5), (5, 6)]);
      expect(log, isEmpty);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(log, ['Moved to position 7 of 10']);
    });

    // Where the text goes, and the two moves that land in one frame.
    final frameMoves = ValueVariant<({bool live, String moves})>({
      for (final live in [false, true])
        for (final moves in ['two actions', 'a key and an action', 'two items'])
          (live: live, moves: moves),
    });
    testWidgets(
      'fo06/us11/fr06/e09 and s03/inv60: two moves that land in one frame '
      'announce once, where the last one put its item',
      (tester) async {
        final (:live, :moves) = frameMoves.currentValue!;
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(supportsAnnounce: !live),
                child: const _Harness(count: 10),
              ),
            ),
          ),
        );
        final log = _announcements(tester);

        /// Performs the move action [label] on item [id] with no frame.
        void act(int id, String label) {
          final node = tester.getSemantics(find.byKey(ValueKey(id)));
          node.owner!.performAction(
            node.id,
            SemanticsAction.customAction,
            CustomSemanticsAction.getIdentifier(
              CustomSemanticsAction(label: label),
            ),
          );
        }

        switch (moves) {
          case 'two actions':
            act(2, 'Move down');
            act(2, 'Move down');
          case 'a key and an action':
            await _focusItem(tester, 2);
            await _altNow(tester, LogicalKeyboardKey.arrowDown);
            act(2, 'Move down');
          default:
            act(2, 'Move down');
            act(6, 'Move down');
        }
        await tester.pumpAndSettle();

        final last = moves == 'two items'
            ? 'Moved to position 8 of 10'
            : 'Moved to position 5 of 10';
        final spoken = find.semantics.byLabel(RegExp('^Moved to position'));
        if (live) {
          expect(log, isEmpty);
          expect(spoken, findsOne);
          expect(spoken.evaluate().single.label, last);
        } else {
          expect(log, [last]);
          expect(spoken, findsNothing);
        }
        handle.dispose();
      },
      variant: frameMoves,
    );

    // How the hold ends: which key is let go first, or an app insert while
    // the key is still down.
    final overlaps = ValueVariant<String>({
      'Up let go first',
      'Down let go first',
      'insert while held',
    });
    testWidgets(
      'fo06/us11/fr06/e08 and s03/inv60: reorder keys held over each other, or a '
      'call during a hold, announce once where the item ends',
      (tester) async {
        final overlap = overlaps.currentValue!;
        await tester.pumpWidget(
          _app(
            _Harness(count: 10, itemsController: ReorderableItemsController()),
          ),
        );
        final log = _announcements(tester);
        await _focusItem(tester, 3);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        if (overlap == 'insert while held') {
          _harness(tester).insert(0, 99);
          await tester.pump();
          await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        } else {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
          await tester.pump();
          final (first, second) = overlap == 'Up let go first'
              ? (LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown)
              : (LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp);
          await tester.sendKeyUpEvent(first);
          await tester.pump();
          await tester.sendKeyUpEvent(second);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        if (overlap == 'insert while held') {
          expect(_harness(tester).moves, [(3, 4)]);
          expect(log, ['Moved to position 6 of 11']);
        } else {
          expect(_harness(tester).moves, [(3, 4), (4, 3)]);
          expect(log, ['Moved to position 4 of 10']);
        }
      },
      variant: overlaps,
    );

    final appMoves = ValueVariant<String>({
      'moveItem',
      'data move',
      'drag ended',
    });
    testWidgets('fo06/us11/fr06/e03: a moveItem, a data move the app index reports, and a '
        'drag a data change ends announce nothing', (tester) async {
      final controller = ReorderableItemsController();
      await tester.pumpWidget(
        _app(switch (appMoves.currentValue) {
          'moveItem' => _Harness(count: 5, itemsController: controller),
          'data move' => const _Harness(count: 5, appIndex: true),
          _ => const _Harness(count: 5),
        }),
      );
      final log = _announcements(tester);

      TestGesture? gesture;
      switch (appMoves.currentValue) {
        case 'moveItem':
          _harness(tester).move(1, 3);
        case 'data move':
          await _focusItem(tester, 1);
          _harness(tester).moveData(1, 3);
        case 'drag ended':
          gesture = await _liftItem(tester, 0);
          _harness(tester).insertData(0, 9);
      }
      await tester.pumpAndSettle();

      expect(log, isEmpty);
      await gesture?.up();
    }, variant: appMoves);

    testWidgets(
      'fo06/us11/fr06/e04: a drop that leaves the item at its slot announces '
      'nothing',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 5)));
        final log = _announcements(tester);

        final gesture = await _liftItem(tester, 0);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(log, isEmpty);
        expect(_harness(tester).moves, isEmpty);
      },
    );

    testWidgets(
      'fo06/us11/fr06/e05 and NFR-L01: each override replaces its text, and an '
      'empty one announces nothing',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              moveAnnouncement: (position, count) => 'Row $position of $count',
              atStartAnnouncement: 'Top',
              atEndAnnouncement: '',
            ),
          ),
        );
        final log = _announcements(tester);

        await _focusItem(tester, 0);
        await _alt(tester, LogicalKeyboardKey.arrowUp);
        await _focusItem(tester, 4);
        await _alt(tester, LogicalKeyboardKey.arrowDown);
        await _focusItem(tester, 0);
        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(log, ['Top', 'Row 2 of 5']);
      },
    );

    testWidgets('fo06/us11/fr06/e06: where the platform discourages announcements, each one '
        'is a new live-region node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(supportsAnnounce: false),
              child: const _Harness(count: 5),
            ),
          ),
        ),
      );
      final log = _announcements(tester);
      const atStart = 'Already at the start of the list';

      await _focusItem(tester, 0);
      await _alt(tester, LogicalKeyboardKey.arrowUp);
      expect(log, isEmpty);
      // The semantics tree, not a render object's node: an empty node
      // drops out of the tree the platform reads.
      final first = find.semantics.byLabel(atStart).evaluate().single;
      expect(first, isSemantics(isLiveRegion: true));

      await _alt(tester, LogicalKeyboardKey.arrowUp);
      final again = find.semantics.byLabel(atStart).evaluate().single;
      expect(again, isSemantics(isLiveRegion: true));
      expect(again.id, isNot(first.id));

      await _alt(tester, LogicalKeyboardKey.arrowDown);
      expect(
        find.semantics.byLabel('Moved to position 2 of 5').evaluate().single,
        isSemantics(isLiveRegion: true),
      );
      expect(find.semantics.byLabel(atStart), findsNothing);
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr06/e06 and s03/inv60: the live-region node leaves the tree '
      '4 s after its announcement, so a later swipe never reads it',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(supportsAnnounce: false),
                child: const _Harness(count: 5),
              ),
            ),
          ),
        );
        const atStart = 'Already at the start of the list';
        final state = _itemState(tester, 0);
        await _focusItem(tester, 0);

        await _alt(tester, LogicalKeyboardKey.arrowUp);
        await tester.pump(const Duration(seconds: 3));
        expect(find.semantics.byLabel(atStart), findsOne);

        await tester.pump(const Duration(seconds: 1));
        expect(find.semantics.byLabel(atStart), findsNothing);
        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 0), [same(state)]);
        expect(FocusManager.instance.primaryFocus, same(state.node));
        handle.dispose();
      },
    );

    testWidgets(
      "fo06/us11/fr06/e06: under the platform's reduced motion, which reports no "
      'announce support, a key move speaks through one live node',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(const _Harness(count: 5)));
        final log = _announcements(tester);

        await _focusItem(tester, 1);
        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(log, isEmpty);
        expect(find.semantics.byLabel(RegExp('^Moved to position')), findsOne);
        handle.dispose();
      },
    );

    testWidgets('fo06/us11/fr06/e07 and NFR-L01: under th the announcement reads the Thai '
        'entry', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('th'),
              child: const _Harness(count: 5),
            ),
          ),
        ),
      );
      final log = _announcements(tester);

      await _focusItem(tester, 2);
      await _alt(tester, LogicalKeyboardKey.arrowDown);

      expect(log, ['ย้ายไปลำดับที่ 4 จาก 5']);
    });
  });

  group('ReorderableListViewLayout acceptance matrix (R45, D13)', () {
    /// The list's own position: the first [Scrollable], even when an item
    /// nests a ListView of its own.
    ScrollPosition positionOf(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    /// The last slot the list's own sliver laid out in the last frame.
    int lastLaidOut(WidgetTester tester) {
      final sliver = tester.renderObject<RenderSliverMultiBoxAdaptor>(
        find
            .byWidgetPredicate(
              (widget) => widget is SliverMultiBoxAdaptorWidget,
              skipOffstage: false,
            )
            .first,
      );
      return sliver.indexOf(sliver.lastChild!);
    }

    /// Whether item [id] is built and lies wholly inside the list's own
    /// viewport.
    bool shown(WidgetTester tester, int id) {
      final item = find.byKey(ValueKey(id));
      if (item.evaluate().isEmpty) return false;
      final view = tester.getRect(find.byType(Scrollable).first);
      final rect = tester.getRect(item);
      return view.intersect(rect) == rect;
    }

    /// The scroll offset the last frame laid the list's own sliver out at.
    double laidOffset(WidgetTester tester) {
      final sliver = tester.renderObject<RenderSliverMultiBoxAdaptor>(
        find
            .byWidgetPredicate(
              (widget) => widget is SliverMultiBoxAdaptorWidget,
              skipOffstage: false,
            )
            .first,
      );
      return sliver.constraints.scrollOffset +
          sliver.constraints.precedingScrollExtent;
    }

    /// Pumps [harness] scrolled so item [id] sits at the trailing laid-out
    /// edge, or at the last slot wholly in view when [visible]; marks its
    /// State expanded, focuses it unless [focus] is false, and returns it.
    Future<_ItemState> pumpAt(
      WidgetTester tester,
      _Harness harness, {
      required int id,
      bool visible = false,
      bool focus = true,
    }) async {
      await _pumpScrolled(
        tester,
        harness,
        offset: math.max(0.0, (id + 1) * 40.0 - (visible ? 300 : 550)),
      );
      if (!visible) expect(lastLaidOut(tester), id);
      final state = _itemState(tester, id)..expanded = true;
      if (focus) await _focusItem(tester, id);
      return state;
    }

    /// Item [id] kept [state], its expanded flag, and, when [node] is
    /// given, primary focus on it.
    void expectKept(
      WidgetTester tester,
      int id,
      _ItemState state, {
      FocusNode? node,
    }) {
      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, id), [same(state)]);
      expect(state.expanded, isTrue);
      if (node != null) {
        expect(FocusManager.instance.primaryFocus, same(node));
      }
    }

    /// Performs the move action labeled [label] on item [id] with no
    /// frame, reaching an item the cache band holds past the viewport.
    void moveActionNow(WidgetTester tester, int id, String label) {
      final node = tester.getSemantics(
        find
            .ancestor(
              of: find.byKey(ValueKey(id), skipOffstage: false),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.customSemanticsActions != null,
                skipOffstage: false,
              ),
            )
            .first,
      );
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction(label: label),
        ),
      );
    }

    /// Holds the grabbed item past the viewport's bottom edge until the
    /// list scrolled [slots] slots from [start], then moves it back inside,
    /// so the edge scroll stops.
    Future<void> edgeScroll(
      WidgetTester tester,
      TestGesture gesture, {
      required double start,
      required int slots,
    }) async {
      final view = tester.getRect(find.byType(Scrollable).first);
      final position = positionOf(tester);
      await gesture.moveTo(Offset(view.center.dx, view.bottom + 20));
      await tester.pump();
      var frames = 0;
      while (position.pixels < start + slots * 40 && frames < 5000) {
        await tester.pump(const Duration(milliseconds: 16));
        frames += 1;
      }
      await gesture.moveTo(Offset(view.center.dx, view.bottom - 30));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // d: slots from the item's slot to its target; with the app index or
    // not (probe group A, matrix section 8).
    final distances = ValueVariant<(int, bool)>({
      (1, false),
      (10, false),
      (100, false),
      (1, true),
      (10, true),
      (100, true),
    });

    testWidgets(
      'matrix I13xT09/T10: a focused far moveItem keeps the item at d = 1, '
      '10, and 100 slots',
      (tester) async {
        final (d, appIndex) = distances.currentValue!;
        final state = await pumpAt(
          tester,
          _Harness(
            count: 1000,
            appIndex: appIndex,
            itemsController: ReorderableItemsController(),
          ),
          id: 500,
        );
        final position = positionOf(tester);
        final from = position.pixels;

        _harness(tester).move(500, 500 + d);
        expect(position.pixels, from);
        await tester.pumpAndSettle();

        expectKept(tester, 500, state, node: state.node);
        expect(shown(tester, 500), isTrue);
        expect(_harness(tester).moves, isEmpty);
      },
      variant: distances,
    );

    testWidgets(
      'matrix I07xT09: Alt+End keeps the item at d = 1, 10, and 100 slots',
      (tester) async {
        final (d, appIndex) = distances.currentValue!;
        final id = 999 - d;
        final state = await pumpAt(
          tester,
          _Harness(count: 1000, appIndex: appIndex),
          id: id,
        );
        final position = positionOf(tester);
        final from = position.pixels;

        await _altNow(tester, LogicalKeyboardKey.end);
        expect(position.pixels, from);
        await tester.pumpAndSettle();

        expectKept(tester, id, state, node: state.node);
        expect(shown(tester, id), isTrue);
        expect(_harness(tester).moves, [(id, 999)]);
      },
      variant: distances,
    );

    final edgeActions = ValueVariant<(int, bool, bool)>({
      for (final d in const [1, 10, 100])
        for (final appIndex in const [false, true])
          for (final focused in const [true, false]) (d, appIndex, focused),
    });
    testWidgets(
      'matrix I09xT09 and I09.M1: "Move to the end" keeps a focused or an '
      'unfocused item at d = 1, 10, and 100 slots',
      (tester) async {
        final (d, appIndex, focused) = edgeActions.currentValue!;
        final handle = tester.ensureSemantics();
        final id = 999 - d;
        final state = await pumpAt(
          tester,
          _Harness(count: 1000, appIndex: appIndex),
          id: id,
          focus: focused,
        );
        final position = positionOf(tester);
        final from = position.pixels;

        moveActionNow(tester, id, 'Move to the end');
        expect(position.pixels, from);
        await tester.pumpAndSettle();

        expectKept(tester, id, state, node: focused ? state.node : null);
        expect(shown(tester, id), isTrue);
        expect(_harness(tester).moves, [(id, 999)]);
        handle.dispose();
      },
      variant: edgeActions,
    );

    testWidgets(
      'matrix I03xT01, I02xT02, and I01xT12: a lift, an edge scroll of d = '
      '1, 10, and 100 slots, and a drop keep the item',
      (tester) async {
        final (d, appIndex) = distances.currentValue!;
        final state = await pumpAt(
          tester,
          _Harness(count: 1000, appIndex: appIndex, handles: true),
          id: 500,
          visible: true,
        );
        final start = positionOf(tester).pixels;

        final gesture = await _grabHandle(tester, 500);
        if (d == 1) {
          for (var i = 0; i < 3; i++) {
            await gesture.moveBy(const Offset(0, 10));
            await tester.pump(const Duration(milliseconds: 16));
          }
        } else {
          await edgeScroll(tester, gesture, start: start, slots: d);
        }
        await gesture.up();
        await tester.pumpAndSettle();

        final harness = _harness(tester);
        expect(harness.moves, hasLength(1));
        final (moved, to) = harness.moves.single;
        expect(moved, 500);
        expect((to - (500 + d)).abs(), lessThanOrEqualTo(1));
        expect(harness.ends, hasLength(1));
        expectKept(tester, 500, state, node: state.node);
        expect(shown(tester, 500), isTrue);
      },
      variant: distances,
    );

    final rawRuns = ValueVariant<(int, bool)>({
      (1, true),
      (10, true),
      (100, true),
      (100, false),
    });
    testWidgets(
      'matrix I14cxT09/T10 and I14nxT09 (L2): a raw reorder of a shown, '
      'focused item d slots on keeps it with the app index and loses it with '
      'none',
      (tester) async {
        final (d, appIndex) = rawRuns.currentValue!;
        final state = await pumpAt(
          tester,
          _Harness(count: 1000, appIndex: appIndex),
          id: 500,
          visible: true,
        );
        final position = positionOf(tester);
        final from = position.pixels;

        _harness(tester).moveData(500, 500 + d);
        expect(position.pixels, from);
        await tester.pumpAndSettle();

        expect(_harness(tester).moves, isEmpty);
        if (!appIndex) {
          expect(tester.takeException(), isNull);
          expect(state.mounted, isFalse);
          return;
        }
        expectKept(tester, 500, state, node: state.node);
        expect(shown(tester, 500), isTrue);
      },
      variant: rawRuns,
    );

    testWidgets(
      'matrix I07.M3: Alt+End of an item whose first Tab stop sits in a '
      'nested horizontal ListView lands 100 slots on with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        final state = await pumpAt(
          tester,
          const _Harness(
            count: 1000,
            boundaryAt: 899,
            boundary: _nestedListBoundary,
          ),
          id: 899,
        );

        await _altNow(tester, LogicalKeyboardKey.end);
        await tester.pumpAndSettle();

        expectKept(tester, 899, state, node: state.node);
        handle.dispose();
      },
    );

    testWidgets(
      'matrix I09.M3: "Move to the end" of an item whose first Tab stop sits '
      'in a nested horizontal ListView lands 100 slots on with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        final state = await pumpAt(
          tester,
          const _Harness(
            count: 1000,
            boundaryAt: 899,
            boundary: _nestedListBoundary,
          ),
          id: 899,
        );

        moveActionNow(tester, 899, 'Move to the end');
        await tester.pumpAndSettle();

        expectKept(tester, 899, state, node: state.node);
        handle.dispose();
      },
    );

    final boundarySteps = ValueVariant<(String, bool)>({
      ('Alt+Down', false),
      ('Alt+Down', true),
      ('Move down', false),
      ('Move down', true),
    });
    testWidgets(
      'matrix I06.M3 and I08.M3: a one-slot <Alt+Down, "Move down"> of a '
      'focused item whose first Tab stop sits in a nested horizontal '
      'ListView, to a slot <laid out, past the laid-out edge>, lands with no '
      'assert',
      (tester) async {
        final (input, past) = boundarySteps.currentValue!;
        final handle = tester.ensureSemantics();
        // At 4000 px the list lays out items 93 to 113 (test:4985).
        final id = past ? 113 : 103;
        await _pumpScrolled(
          tester,
          _Harness(count: 200, boundaryAt: id, boundary: _nestedListBoundary),
        );
        final state = _itemState(tester, id)..expanded = true;
        final node = await _focusItem(tester, id);

        if (input == 'Alt+Down') {
          await _altNow(tester, LogicalKeyboardKey.arrowDown);
        } else {
          moveActionNow(tester, id, 'Move down');
        }
        await tester.pumpAndSettle();

        expectKept(tester, id, state, node: node);
        expect(shown(tester, id), isTrue);
        expect(_harness(tester).moves, [(id, id + 1)]);
        handle.dispose();
      },
      variant: boundarySteps,
    );

    final boundaryDrags = ValueVariant<String>({'drop', 'cancel', 'far drop'});
    testWidgets(
      'matrix I01.M3 (D13): a <drop, cancel, far drop> of an item whose '
      'first Tab stop sits in a nested horizontal ListView raises no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        final state = await pumpAt(
          tester,
          const _Harness(
            count: 1000,
            handles: true,
            boundaryAt: 500,
            boundary: _nestedListBoundary,
          ),
          id: 500,
          visible: true,
        );
        final drag = boundaryDrags.currentValue!;

        final gesture = await _grabHandle(tester, 500);
        if (drag == 'far drop') {
          await edgeScroll(
            tester,
            gesture,
            start: positionOf(tester).pixels,
            slots: 100,
          );
        } else {
          await gesture.moveBy(const Offset(0, -40));
          await tester.pump(const Duration(milliseconds: 16));
        }
        if (drag == 'cancel') {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();

        expectKept(tester, 500, state, node: state.node);
        expect(_harness(tester).ends, hasLength(1));
        handle.dispose();
      },
      variant: boundaryDrags,
    );

    testWidgets(
      'matrix I14c.M3: a raw reorder with the app index, 100 slots on, of an '
      'item whose first Tab stop sits in a nested horizontal ListView lands '
      'with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        final state = await pumpAt(
          tester,
          const _Harness(
            count: 1000,
            appIndex: true,
            boundaryAt: 500,
            boundary: _nestedListBoundary,
          ),
          id: 500,
        );

        _harness(tester).moveData(500, 600);
        await tester.pumpAndSettle();

        expectKept(tester, 500, state, node: state.node);
        handle.dispose();
      },
    );

    testWidgets(
      'matrix I17.M3 and I18.M3: an item whose first Tab stop sits in a '
      'nested horizontal ListView, scrolled away and held, comes back on Tab '
      'with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        final state = await pumpAt(
          tester,
          const _Harness(
            count: 1000,
            boundaryAt: 500,
            boundary: _nestedListBoundary,
          ),
          id: 500,
        );

        positionOf(tester).jumpTo(600 * 40.0);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 500), [same(state)]);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 500), [same(state)]);
        expect(shown(tester, 500), isTrue);
        handle.dispose();
      },
    );

    final parkedKeys = ValueVariant<LogicalKeyboardKey>({
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.end,
    });
    testWidgets(
      'matrix I06xT11 and I07xT11: a reorder key on a parked item while its '
      'reach runs parks it again at the new slot and re-aims the reach',
      (tester) async {
        // Item 114 is 400 px, so after Alt+Down item 113 sits past the frame
        // the 40 px average lays out, and the reach runs (test:6486).
        await _pumpScrolled(
          tester,
          const _Harness(count: 200, heights: {114: 400}),
        );
        final state = _itemState(tester, 113)..expanded = true;
        final node = await _focusItem(tester, 113);
        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(_builtInView(tester, 113), isFalse);

        final key = parkedKeys.currentValue!;
        await _altNow(tester, key);
        await tester.pumpAndSettle();

        final last = key == LogicalKeyboardKey.end ? 199 : 115;
        expectKept(tester, 113, state, node: node);
        expect(_builtInView(tester, 113), isTrue);
        expect(_harness(tester).moves, [(113, 114), (114, last)]);
      },
      variant: parkedKeys,
    );

    testWidgets('matrix I11xT11 and fo06/us11/fr04/e17: a removeItem call during the retry '
        'frames leaves another key in the target slot, so the list returns to '
        'its offset and hands focus on from the gap', (tester) async {
      await _returnFocused(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
        offset: 4000,
        id: 100,
        slot: 5,
      );
      final position = positionOf(tester);
      await tester.pump();
      _harness(tester).remove(2);
      await tester.pumpAndSettle();

      // The reach aimed at slot 5, where item 5 now sits, and returned to
      // 4000. The removal moved the gap from index 101 to 100, where item
      // 101 still follows it (as test:3554 reads it for an insert).
      expect(tester.takeException(), isNull);
      expect(position.pixels, 4000);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
      expect(_statesOf(tester, 100), isEmpty);
    });

    testWidgets(
      'matrix I12xT12: a held item the app removes and inserts back in one '
      'turn at a slot the frame does not build keeps its State and focus '
      'and shows there',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 103)..expanded = true;
        final node = await _focusItem(tester, 103);
        position.jumpTo(0);
        await tester.pump();
        expect(_statesOf(tester, 103), [same(state)]);

        _harness(tester)
          ..remove(103)
          ..insert(150, 103);
        await tester.pumpAndSettle();

        expectKept(tester, 103, state, node: node);
        expect(_builtInView(tester, 103), isTrue);
        expect(_harness(tester).ids[150], 103);
      },
    );

    testWidgets(
      'matrix I14nxT01 (D9): with no callback a focused item a raw move takes '
      'to a laid-out slot keeps its State and focus',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final state = _itemState(tester, 2)..expanded = true;
        final node = await _focusItem(tester, 2);

        _harness(tester).moveData(2, 4);
        await tester.pumpAndSettle();

        expectKept(tester, 2, state, node: node);
        expect(_harness(tester).ids.sublist(0, 5), [0, 1, 3, 4, 2]);
      },
    );

    testWidgets(
      'matrix I03xT06 and fo06/us11/fr04/e15: an insert the app defers from a '
      "drop's onReorderItem grows in as a call from outside does",
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: ReorderableItemsController()),
          ),
        );
        final harness = _harness(tester)
          ..onMove = (_, _) => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _harness(tester).insert(0, 9),
          );
        final gesture = await _liftItem(tester, 0);
        await _dragPastNeighbor(tester, gesture);
        await gesture.up();
        var frames = 0;
        while (harness.moves.isEmpty && frames < 100) {
          await tester.pump(const Duration(milliseconds: 16));
          frames += 1;
        }
        expect(harness.moves, [(0, 1)]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(_enteringOpacity(tester, 9), allOf(greaterThan(0), lessThan(1)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(harness.ids, [9, 1, 0, 2, 3, 4]);
      },
    );

    testWidgets('matrix I03xT07 and fo06/us11/fr03/e07: a drop past an item a call grows in '
        'shows the dropped item again once that grow-in ends', (tester) async {
      await tester.pumpWidget(
        _app(
          _Harness(count: 20, itemsController: ReorderableItemsController()),
          theme: _normalTheme(const Duration(seconds: 2)),
        ),
      );
      final harness = _harness(tester)..insert(0, 900);
      await tester.pump();

      final gesture = await _liftItem(tester, 5);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.moves, hasLength(1));
      expect(harness.ids.indexOf(5), greaterThan(6));
      expect(_itemInView(tester, 5), isTrue);
    });

    testWidgets(
      'matrix I03xT19: disposing the list while a drop settles reports no '
      'second onReorderEnd and leaves no ticker running',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 5)));
        final harness = _harness(tester);
        final gesture = await _liftItem(tester, 0);
        await _dragPastNeighbor(tester, gesture);
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 50));
        expect(harness.ends, hasLength(1));

        await tester.pumpWidget(_app(const SizedBox()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, hasLength(1));
      },
    );

    testWidgets(
      'matrix I03xT18 and fo06/us11/fr01/e13: a drop whose onReorderItem the app '
      "does not apply leaves the list showing the app's data",
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 5)));
        final harness = _harness(tester)
          ..onMove = (from, to) {
            final ids = _harness(tester).ids;
            ids.insert(from, ids.removeAt(to));
          };
        final gesture = await _liftItem(tester, 0);
        await _dragPastNeighbor(tester, gesture);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.moves, [(0, 1)]);
        expect(harness.ids, [0, 1, 2, 3, 4]);
        expect(_offsetBetween(tester, 0, 1), 40);
      },
    );

    testWidgets("matrix I06xT15 and fo06/us11/fr02/e04: the item's own shortcut on the same "
        'Alt key wins over the reorder key', (tester) async {
      var hits = 0;
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 5,
            boundaryAt: 2,
            boundary: (child) => CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.arrowDown,
                  alt: true,
                ): () =>
                    hits += 1,
              },
              child: child,
            ),
          ),
        ),
      );
      await _focusItem(tester, 2);

      expect(await _alt(tester, LogicalKeyboardKey.arrowDown), isTrue);

      expect(hits, 1);
      expect(_harness(tester).moves, isEmpty);
      expect(_harness(tester).ids, [0, 1, 2, 3, 4]);
    });

    testWidgets(
      'matrix I06.M5 and fo06/us11/fr02: in a reversed list Alt+Up moves the '
      'focused item up on screen, to the next index',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 5, reverse: true)));
        await _focusItem(tester, 2);

        expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isTrue);

        expect(_harness(tester).moves, [(2, 3)]);
      },
    );

    // (text direction, reverse).
    final directions = ValueVariant<(TextDirection, bool)>({
      (TextDirection.ltr, false),
      (TextDirection.rtl, false),
      (TextDirection.ltr, true),
      (TextDirection.rtl, true),
    });
    testWidgets('matrix I08.M5 and fo06/us11/fr03/e03: in a horizontal list "Move left" and '
        '"Move right" move the item by screen direction', (tester) async {
      final handle = tester.ensureSemantics();
      final (direction, reverse) = directions.currentValue!;
      await tester.pumpWidget(
        _app(
          _Harness(count: 5, axis: Axis.horizontal, reverse: reverse),
          textDirection: direction,
        ),
      );
      double left() => tester.getTopLeft(find.byKey(const ValueKey(2))).dx;
      final start = left();

      await _moveAction(tester, 2, 'Move left');
      expect(left(), start - 40);
      await _moveAction(tester, 2, 'Move right');
      expect(left(), start);

      // Index 0 sits at the left when the axis runs to the right.
      final runsRight = (direction == TextDirection.ltr) != reverse;
      expect(
        _harness(tester).moves,
        runsRight ? [(2, 1), (1, 2)] : [(2, 3), (3, 2)],
      );
      handle.dispose();
    }, variant: directions);

    testWidgets(
      'matrix I08.M5 and fo06/us11/fr03/e03: in a reversed list "Move up" and '
      '"Move down" move the item by screen direction',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(const _Harness(count: 5, reverse: true)));
        double top() => tester.getTopLeft(find.byKey(const ValueKey(2))).dy;
        final start = top();

        await _moveAction(tester, 2, 'Move up');
        expect(top(), start - 40);
        await _moveAction(tester, 2, 'Move down');
        expect(top(), start);

        expect(_harness(tester).moves, [(2, 3), (3, 2)]);
        handle.dispose();
      },
    );

    testWidgets(
      'matrix I09xT14: a focus the app moves in the turn of "Move to the end" '
      "stays, and the list skips the move's jump",
      (tester) async {
        final handle = tester.ensureSemantics();
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        await _focusItem(tester, 103);
        final other = _itemState(tester, 104).node;
        final harness = _harness(tester)
          ..onMove = (_, _) => other.requestFocus();

        moveActionNow(tester, 103, 'Move to the end');
        expect(position.pixels, 4000);
        await tester.pump();
        expect(position.pixels, 4000);
        await tester.pumpAndSettle();

        expect(harness.moves, [(103, 199)]);
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(position.pixels, 4000);
        handle.dispose();
      },
    );

    final heldKeys = ValueVariant<LogicalKeyboardKey>({
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.end,
    });
    testWidgets(
      'matrix I06xT16 and I07xT16: a reorder key while the app holds the '
      'scroll gives the reach up, returns, and hands focus on from the slot '
      'the item left',
      (tester) async {
        final key = heldKeys.currentValue!;
        final down = key == LogicalKeyboardKey.arrowDown;
        // Alt+Down from the trailing laid-out item 113 past a 400 px item
        // (test:6486); Alt+End from item 103.
        final id = down ? 113 : 103;
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200, heights: {114: 400}),
        );
        await _focusItem(tester, id);
        _pinScroll(tester, 4000);

        await _altNow(tester, key);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(position.pixels, 4000);
        expect(_statesOf(tester, id), isEmpty);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'item ${id + 1}',
        );
        expect(_harness(tester).moves, [(id, down ? 114 : 199)]);
      },
      variant: heldKeys,
    );

    // Whether the app lets the move's jump through and holds the offset it
    // reached, so the reach gives up away from where it started.
    final jumpThrough = ValueVariant<bool>({false, true});
    testWidgets('matrix I08xT16 and fo06/us11/fr03/e12 (R46, R13): an unfocused "Move down" '
        'while the app holds the scroll gives the reach up and hands no focus '
        'on: the text field outside the list keeps it', (tester) async {
      final handle = tester.ensureSemantics();
      final outside = FocusNode(debugLabel: 'outside');
      addTearDown(outside.dispose);
      // "Move down" from the trailing laid-out item 113 past a 400 px item
      // (test:6486), in a list 260 px tall above the text field and with no
      // cache extent, so the move's jump misses the item's slot.
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              const Expanded(
                child: _Harness(
                  count: 200,
                  heights: {114: 400},
                  scrollCacheExtent: ScrollCacheExtent.pixels(0),
                ),
              ),
              SizedBox(height: 40, child: TextField(focusNode: outside)),
            ],
          ),
        ),
      );
      final position = positionOf(tester)..jumpTo(4300);
      await tester.pump();
      expect(lastLaidOut(tester), 113);
      outside.requestFocus();
      await tester.pump();
      expect(outside.hasPrimaryFocus, isTrue);
      // The app holds the scroll, as _pinScroll does for the list alone.
      var held = jumpThrough.currentValue! ? null : 4300.0;
      position.addListener(() {
        final pixels = held ??= position.pixels;
        if (position.pixels != pixels) position.jumpTo(pixels);
      });

      moveActionNow(tester, 113, 'Move down');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (jumpThrough.currentValue!) expect(held, isNot(4300));
      expect(position.pixels, held);
      expect(_statesOf(tester, 113), isEmpty);
      expect(FocusManager.instance.primaryFocus, same(outside));
      expect(_harness(tester).moves, [(113, 114)]);
      handle.dispose();
    }, variant: jumpThrough);

    testWidgets('matrix I12xT16 and fo06/us11/fr04/e17: a focused item removed and inserted '
        'back far off while the app holds the scroll gives the reach up and '
        'hands focus on from the gap', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
      );
      await _focusItem(tester, 100);
      _pinScroll(tester, 4000);

      _harness(tester)
        ..remove(100)
        ..insert(0, 100);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(position.pixels, 4000);
      expect(_statesOf(tester, 100), isEmpty);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
    });

    testWidgets(
      'matrix I13xT16 and fo06/us11/fr05/e04: a focused far moveItem while the '
      'app holds the scroll gives the reach up and hands focus on from the '
      'slot the item left',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        await _focusItem(tester, 100);
        _pinScroll(tester, 4000);

        _harness(tester).move(100, 150);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(position.pixels, 4000);
        expect(_statesOf(tester, 100), isEmpty);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
      },
    );

    testWidgets('matrix I14cxT16 and fo06/us11/fr05/e13: a raw move the app index follows, '
        'while the app holds the scroll, gives the reach up and hands focus on '
        'from the slot the item left', (tester) async {
      final position = await _pumpScrolled(
        tester,
        const _Harness(count: 200, appIndex: true),
      );
      await _focusItem(tester, 103);
      _pinScroll(tester, 4000);

      _harness(tester).moveData(103, 150);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(position.pixels, 4000);
      expect(_statesOf(tester, 103), isEmpty);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 104');
    });

    testWidgets(
      'matrix I10xT07: an insert beside an item still growing in counts the '
      'growing item in its index',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: ReorderableItemsController()),
          ),
        );
        final harness = _harness(tester)..insert(1, 9);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        harness.insert(2, 10);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ids, [0, 9, 10, 1, 2, 3, 4]);
        expect(_offsetBetween(tester, 0, 9), 40);
        expect(_offsetBetween(tester, 9, 10), 40);
        expect(_offsetBetween(tester, 10, 1), 40);
      },
    );

    testWidgets(
      'matrix I14nxT05 and s03/inv35: with no callback, a raw reorder of '
      "other items in the turn of a call keeps the held item's State and "
      'focus through the call',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 1000, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 103)..expanded = true;
        final node = await _focusItem(tester, 103);
        position.jumpTo(20000);
        await tester.pump();

        _harness(tester)
          ..insert(0, 2000)
          ..moveData(500, 501);
        await tester.pumpAndSettle();

        expectKept(tester, 103, state, node: node);
        expect(_builtInView(tester, 103), isFalse);
        expect(_harness(tester).ids[104], 103);
      },
    );

    final appFocus = ValueVariant<String>({'moves', 'clears'});
    testWidgets(
      'matrix I14nxT14 and fo06/us11/fr04/e19: with no callback, a focus the app '
      '<moves, clears> in the turn of a raw move keeps that outcome',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 1000),
        );
        await _focusItem(tester, 103);
        final other = _itemState(tester, 105).node;
        final moves = appFocus.currentValue == 'moves';

        _harness(tester).moveData(103, 600);
        if (moves) {
          other.requestFocus();
        } else {
          FocusManager.instance.primaryFocus!.unfocus();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 103), isEmpty);
        expect(position.pixels, 4000);
        if (moves) {
          expect(FocusManager.instance.primaryFocus, same(other));
        } else {
          final label = FocusManager.instance.primaryFocus?.debugLabel;
          expect(label ?? '', isNot(startsWith('item ')));
        }
      },
      variant: appFocus,
    );

    testWidgets(
      'matrix I16xT09 and fo06/us11/fr04/e19 (L2): with no callback, an undragged '
      'focused item a count change shifts to an unbuilt slot loses its State, '
      'and focus moves to an item the list shows',
      (tester) async {
        await _pumpScrolled(tester, const _Harness(count: 200));
        final state = _itemState(tester, 113);
        await _focusItem(tester, 113);

        _harness(tester).insertData(0, 900);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        final focused = FocusManager.instance.primaryFocus!.debugLabel!;
        expect(focused, startsWith('item '));
        expect(focused, isNot('item 113'));
        expect(_builtInView(tester, int.parse(focused.substring(5))), isTrue);
      },
    );

    final appGroupMoves = ValueVariant<String>({'Tab', 'nextFocus'});
    testWidgets(
      'matrix I18xT15 (L7, R43): from an item held off screen inside an app '
      'FocusTraversalGroup with its own policy, Tab brings the item back, '
      "and the app's own nextFocus is the app's to reveal",
      (tester) async {
        final second = FocusNode(debugLabel: 'second 103');
        addTearDown(second.dispose);
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 1000,
            boundaryAt: 103,
            boundary: (child) => FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Row(
                children: [
                  child,
                  Focus(
                    focusNode: second,
                    child: const SizedBox(width: 40, height: 40),
                  ),
                ],
              ),
            ),
          ),
        );
        final node = await _focusItem(tester, 103);
        position.jumpTo(20000);
        await tester.pump();

        final tab = appGroupMoves.currentValue == 'Tab';
        if (tab) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        } else {
          node.nextFocus();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(FocusManager.instance.primaryFocus, same(second));
        // Keys bring the item back first; the app's own focus move inside its
        // own policy stays the app's to reveal, the stated limit L7.
        expect(_builtInView(tester, 103), tab);
        if (!tab) expect(position.pixels, 20000);
      },
      variant: appGroupMoves,
    );

    final stops = ValueVariant<String>({'back inside', 'drag ends'});
    testWidgets(
      'matrix I02xT02 and fo06/us11/fr01/e08: the edge scroll steps at most 20 px '
      'a step and stops when <the item is back inside, the drag ends>',
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 1000, handles: true)),
        );
        final position = positionOf(tester);
        final view = tester.getRect(find.byType(Scrollable));
        final gesture = await _grabHandle(tester, 3);

        await gesture.moveTo(Offset(view.center.dx, view.bottom - 5));
        final start = position.pixels;
        var last = start;
        var step = 0.0;
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          step = math.max(step, position.pixels - last);
          last = position.pixels;
        }
        expect(position.pixels, greaterThan(start));
        expect(step, lessThanOrEqualTo(20));

        if (stops.currentValue == 'back inside') {
          await gesture.moveTo(view.center);
        } else {
          await gesture.up();
        }
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final stopped = position.pixels;
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(position.pixels, stopped);
        if (stops.currentValue == 'back inside') await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: stops,
    );

    testWidgets(
      'matrix I02.M4 (L1): under reduced motion the edge scroll keeps its '
      'steps',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(
          _app(const _Harness(count: 1000, handles: true)),
        );
        final position = positionOf(tester);
        final view = tester.getRect(find.byType(Scrollable));
        final gesture = await _grabHandle(tester, 3);

        await gesture.moveTo(Offset(view.center.dx, view.bottom - 5));
        final start = position.pixels;
        var last = start;
        var step = 0.0;
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          step = math.max(step, position.pixels - last);
          last = position.pixels;
        }
        final half = position.pixels;
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          step = math.max(step, position.pixels - last);
          last = position.pixels;
        }

        expect(half, greaterThan(start));
        expect(position.pixels, greaterThan(half));
        expect(step, lessThanOrEqualTo(20));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('fo06/us11/fr01 and s03/inv28 (R49): a lifted item keeps its screen-reader '
        'node in the list, at its slot, for the whole drag', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _Harness(count: 5)));
      final scroll = find.semantics
          .byFlag(SemanticsFlag.hasImplicitScrolling)
          .evaluate()
          .single;
      final slot = tester.getRect(find.byKey(const ValueKey(1)));

      final gesture = await _liftItem(tester, 1, by: 30);
      await tester.pump();

      final node = tester.getSemantics(find.byKey(const ValueKey(1)));
      var inList = false;
      for (var up = node.parent; up != null; up = up.parent) {
        if (identical(up, scroll)) inList = true;
      }
      expect(inList, isTrue);
      expect(tester.getRect(find.byKey(const ValueKey(1))), slot);
      await gesture.up();
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets(
      'fo06/us11/fr01/e14 (R49): an item holding a text field drags with no '
      'Material of its own, as a still image under the pointer',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              handles: true,
              boundaryAt: 1,
              boundary: (child) => Row(
                children: [
                  child,
                  const SizedBox(width: 100, height: 40, child: TextField()),
                ],
              ),
            ),
          ),
        );

        final gesture = await _grabHandle(tester, 1);
        final image = tester.widget<RawImage>(find.byType(RawImage)).image;
        for (var i = 0; i < 3; i++) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<RawImage>(find.byType(RawImage)).image,
          same(image),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    final liftEnds = ValueVariant<String>({'drop', 'cancel'});
    testWidgets('fo06/us11/fr01 (R49): after a <drop, cancel> the lifted item paints in its '
        'slot again and lifts again', (tester) async {
      final painted = <int>[];
      await tester.pumpWidget(_app(_Harness(count: 5, paintLog: painted)));

      var gesture = await _liftItem(tester, 1);
      if (liftEnds.currentValue == 'drop') {
        await gesture.up();
      } else {
        await gesture.cancel();
      }
      await tester.pumpAndSettle();
      painted.clear();
      tester.renderObject(find.byKey(const ValueKey(1))).markNeedsPaint();
      await tester.pump();

      expect(find.byType(RawImage), findsNothing);
      expect(painted, contains(1));
      gesture = await _liftItem(tester, 1);
      expect(find.byType(RawImage), findsOne);
      expect(_harness(tester).starts, hasLength(2));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, variant: liftEnds);

    final placements = ValueVariant<String>({'offset page', 'horizontal RTL'});
    testWidgets(
      'fo06/us11/fr01 (R49): the image under the pointer sits where the item sat, '
      'plus the drag, in a list <offset in the page, horizontal under RTL>',
      (tester) async {
        final horizontal = placements.currentValue == 'horizontal RTL';
        await tester.pumpWidget(
          _app(
            horizontal
                ? const _Harness(count: 5, axis: Axis.horizontal)
                : const Padding(
                    padding: EdgeInsets.only(top: 50, left: 30),
                    child: _Harness(count: 5),
                  ),
            textDirection: horizontal ? TextDirection.rtl : TextDirection.ltr,
          ),
        );
        final topLeft = tester.getTopLeft(find.byKey(const ValueKey(1)));
        final delta = horizontal ? const Offset(-30, 0) : const Offset(0, 30);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('1')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(delta);
        await tester.pump();
        await tester.pump();

        expect(tester.getTopLeft(find.byType(RawImage)), topLeft + delta);
        await gesture.up();
        await tester.pumpAndSettle();
      },
      variant: placements,
    );

    final turnAppIndex = ValueVariant<bool>({false, true});
    testWidgets(
      's03/inv35 (D3): a raw move and an insert call in one turn keep every '
      "item's State, the app's index answering before the calls",
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 11,
              appIndex: turnAppIndex.currentValue!,
              itemsController: ReorderableItemsController(),
            ),
          ),
        );
        final zero = _itemState(tester, 0)..expanded = true;
        final three = _itemState(tester, 3)..expanded = true;

        _harness(tester)
          ..moveData(0, 3)
          ..insert(2, 99);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expectKept(tester, 0, zero);
        expectKept(tester, 3, three);
      },
      variant: turnAppIndex,
    );

    testWidgets(
      'fo06/us11/fr01 (R44): a drop in a reversed list scrolled far from its '
      'start settles the image on the slot it drops into',
      (tester) async {
        await _pumpScrolled(
          tester,
          const _Harness(count: 100, reverse: true),
          offset: 1870,
        );
        final slot = tester.getTopLeft(find.byKey(const ValueKey(48)));

        final gesture = await _liftItem(tester, 50);
        for (var i = 0; i < 7; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // The lift's own animation ends first, so the settle runs whole.
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 125));

        final image = tester.getTopLeft(find.byType(RawImage));
        expect(image.dx, slot.dx);
        expect(image.dy, moreOrLessEquals(slot.dy, epsilon: 1));
        await tester.pumpAndSettle();
        expect(_harness(tester).moves, [(50, 48)]);
      },
    );

    testWidgets(
      'matrix I06.M3 (L6 closed): Alt+Down past an unbuilt item taller than '
      'the laid-out average, of an item whose first Tab stop sits in a '
      'nested horizontal ListView, lands with no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        final position = await _pumpScrolled(
          tester,
          const _Harness(
            count: 200,
            heights: {114: 400},
            boundaryAt: 113,
            boundary: _nestedListBoundary,
          ),
        );
        final state = _itemState(tester, 113)..expanded = true;
        final node = await _focusItem(tester, 113);

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        expect(position.pixels, 4000);
        await tester.pumpAndSettle();

        expectKept(tester, 113, state, node: node);
        expect(shown(tester, 113), isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr05/e03 and s03/inv24 (R48): a moved item grows in with its '
      'render object under the same parent as at rest',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: ReorderableItemsController()),
          ),
        );
        final box = tester.renderObject(find.byKey(const ValueKey(2)));
        final parent = box.parent;

        _harness(tester).move(2, 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.renderObject(find.byKey(const ValueKey(2))), same(box));
        expect(box.parent, same(parent));
        await tester.pumpAndSettle();
        expect(box.parent, same(parent));
      },
    );

    testWidgets('fo06/us11/fr04/e02 (R48): a caller itemTransitionBuilder wraps every item, '
        'an item at rest with a completed animation', (tester) async {
      final received = <Animation<double>>[];
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 3,
            itemsController: ReorderableItemsController(),
            itemTransitionBuilder: (context, animation, child) {
              received.add(animation);
              return child;
            },
          ),
        ),
      );

      expect(received, hasLength(greaterThanOrEqualTo(3)));
      expect(
        received.every(
          (animation) => animation.isCompleted && animation.value == 1,
        ),
        isTrue,
      );
    });

    testWidgets(
      'fo06/us11/fr05 (R48): under a fixed extent, a moved item sits in the live '
      'screen-reader tree from the frame it lands, while its fade starts at 0',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              itemExtent: 40,
              itemsController: ReorderableItemsController(),
            ),
          ),
        );

        _harness(tester).move(3, 1);
        await tester.pump();

        expect(_enteringOpacity(tester, 3), lessThan(0.5));
        expect(_liveSemanticsLabel(tester, '3'), isTrue);
        await tester.pumpAndSettle();
        expect(_liveSemanticsLabel(tester, '3'), isTrue);
        handle.dispose();
      },
    );

    final unfocusedStep = ValueVariant<bool>({false, true});
    testWidgets('matrix I08.M1 and fo06/us11/fr03/e12 (R46): an unfocused "Move down" to the '
        'unbuilt slot past the trailing laid-out edge keeps the item and shows '
        'it', (tester) async {
      final handle = tester.ensureSemantics();
      final state = await pumpAt(
        tester,
        _Harness(count: 1000, appIndex: unfocusedStep.currentValue!),
        id: 500,
        focus: false,
      );
      final position = positionOf(tester);
      final from = position.pixels;

      moveActionNow(tester, 500, 'Move down');
      expect(position.pixels, from);
      await tester.pumpAndSettle();

      expectKept(tester, 500, state);
      expect(shown(tester, 500), isTrue);
      expect(_harness(tester).moves, [(500, 501)]);
      handle.dispose();
    }, variant: unfocusedStep);

    // (app index, a text field outside the list holds primary focus).
    final unfocusedReach = ValueVariant<(bool, bool)>({
      (false, true),
      (true, true),
      (false, false),
      (true, false),
    });
    testWidgets(
      'matrix I08.M1 and fo06/us11/fr03/e12 (R46, R13): an unfocused "Move down" '
      'past an unbuilt item taller than the laid-out average reaches the '
      'item and shows it, and primary focus stays where it was',
      (tester) async {
        final (appIndex, outsideHolds) = unfocusedReach.currentValue!;
        final handle = tester.ensureSemantics();
        final outside = FocusNode(debugLabel: 'outside');
        addTearDown(outside.dispose);
        // Item 108 is 400 px and the list has no cache extent: after the
        // move, item 107 sits past the frame the 40 px average lays out,
        // so the jump misses and the reach runs.
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                Expanded(
                  child: _Harness(
                    count: 200,
                    heights: const {108: 400},
                    scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                    appIndex: appIndex,
                  ),
                ),
                SizedBox(height: 40, child: TextField(focusNode: outside)),
              ],
            ),
          ),
        );
        final position = positionOf(tester)..jumpTo(4060);
        await tester.pump();
        expect(lastLaidOut(tester), 107);
        final state = _itemState(tester, 107)..expanded = true;
        if (outsideHolds) {
          outside.requestFocus();
          await tester.pump();
          expect(outside.hasPrimaryFocus, isTrue);
        }
        final focus = FocusManager.instance.primaryFocus;

        moveActionNow(tester, 107, 'Move down');
        expect(position.pixels, 4060);
        await tester.pump();
        expect(lastLaidOut(tester), lessThan(108));
        await tester.pumpAndSettle();

        expectKept(tester, 107, state);
        expect(shown(tester, 107), isTrue);
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(_harness(tester).moves, [(107, 108)]);
        handle.dispose();
      },
      variant: unfocusedReach,
    );

    // How the app moves the parked item again: a moveItem call, or a raw
    // reorder its findChildIndexCallback answers.
    final parkedMoves = ValueVariant<String>({
      'moveItem',
      'raw move with the callback',
    });
    testWidgets(
      'matrix I13xT11 and I14cxT11 (R46): an item a screen reader moved, '
      'parked off screen once the EndUser stopped its reach, keeps its State '
      "through the app's next move, which reaches and shows it, and primary "
      'focus stays where it was',
      (tester) async {
        final call = parkedMoves.currentValue == 'moveItem';
        final handle = tester.ensureSemantics();
        final outside = FocusNode(debugLabel: 'outside');
        addTearDown(outside.dispose);
        // Item 108 is 400 px and the list has no cache extent: the move's
        // jump misses and the reach runs, as in I08.M1.
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                Expanded(
                  child: _Harness(
                    count: 200,
                    heights: const {108: 400},
                    scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                    appIndex: !call,
                    itemsController: ReorderableItemsController(),
                  ),
                ),
                SizedBox(height: 40, child: TextField(focusNode: outside)),
              ],
            ),
          ),
        );
        positionOf(tester).jumpTo(4060);
        await tester.pump();
        expect(lastLaidOut(tester), 107);
        final state = _itemState(tester, 107)..expanded = true;
        outside.requestFocus();
        await tester.pump();

        moveActionNow(tester, 107, 'Move down');
        await tester.pump();
        // The EndUser drags the list while the reach runs: the reach stops,
        // and the item stays parked (R29, R45).
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(Scrollable).first),
        );
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expectKept(tester, 107, state);
        expect(shown(tester, 107), isFalse);

        final harness = _harness(tester);
        final at = harness.ids.indexOf(107);
        if (call) {
          harness.move(at, 150);
        } else {
          harness.moveData(at, 150);
        }
        await tester.pumpAndSettle();

        expect(harness.ids[150], 107);
        expectKept(tester, 107, state);
        expect(shown(tester, 107), isTrue);
        expect(outside.hasPrimaryFocus, isTrue);
        handle.dispose();
      },
      variant: parkedMoves,
    );

    testWidgets(
      'fo06/us11/fr04/e05 and s03/inv58 (R47): a removed item exits in a sliver '
      'child of its own, its render object under the same sliver child',
      (tester) async {
        // The sliver child that holds [box]: its ancestor whose parent is
        // the list's sliver.
        RenderObject sliverChildOf(RenderObject box) {
          var node = box;
          for (
            var parent = node.parent;
            parent != null && parent is! RenderSliverMultiBoxAdaptor;
            parent = node.parent
          ) {
            node = parent;
          }
          return node;
        }

        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: ReorderableItemsController()),
          ),
        );
        final box = tester.renderObject(find.byKey(const ValueKey(2)));
        final child = sliverChildOf(box);

        _harness(tester).remove(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          tester.renderObject(
            find.byKey(const ValueKey(2), skipOffstage: false),
          ),
          same(box),
        );
        expect(sliverChildOf(box), same(child));
      },
    );

    testWidgets('fo06/us11/fr04/e11 and s03/inv58: the sliver that measures prototypeItem '
        'adds no Tab stop and no screen-reader node', (tester) async {
      final handle = tester.ensureSemantics();
      final prototype = FocusNode(debugLabel: 'prototype');
      addTearDown(prototype.dispose);
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 3,
            prototypeItem: Focus(
              focusNode: prototype,
              child: const SizedBox(width: 40, height: 40, child: Text('P')),
            ),
          ),
        ),
      );

      expect(_liveSemanticsLabel(tester, 'P'), isFalse);
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(prototype.hasFocus, isFalse);
      }
      handle.dispose();
    });

    final lastExits = ValueVariant<String>({'itemExtent', 'reduced motion'});
    testWidgets(
      'fo06/us11/fr04/e01 and e11: the only item removed <under itemExtent leaves '
      'at once, under reduced motion keeps its size while it fades>',
      (tester) async {
        final fixed = lastExits.currentValue == 'itemExtent';
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: !fixed),
                child: _Harness(
                  count: 1,
                  itemExtent: fixed ? 40 : null,
                  itemsController: ReorderableItemsController(),
                ),
              ),
            ),
          ),
        );

        _harness(tester).remove(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final sliver = tester.renderObject<RenderSliverMultiBoxAdaptor>(
          find.byWidgetPredicate(
            (widget) => widget is SliverMultiBoxAdaptorWidget,
            skipOffstage: false,
          ),
        );
        if (fixed) {
          expect(
            find.byKey(const ValueKey(0), skipOffstage: false),
            findsNothing,
          );
        } else {
          expect(sliver.geometry!.scrollExtent, 40);
          expect(
            _enteringOpacity(tester, 0),
            allOf(greaterThan(0), lessThan(1)),
          );
          // The exit keeps its room and paints: its layer is in the tree.
          expect(_compositeOrder(tester, [0]), [0]);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: lastExits,
    );

    testWidgets(
      'fo06/us11/fr01/input-output and s03/inv29 (R47): findChildIndexCallback '
      'gets only the keys itemBuilder gave, across a settled moveItem and a '
      'remove whose exit ends off screen',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 30,
              appIndex: true,
              itemsController: ReorderableItemsController(),
            ),
          ),
        );
        final harness = _harness(tester);
        // Casts the key as Flutter's own sample does: any other key throws.
        harness.answer = (key) {
          final index = harness.ids.indexOf((key as ValueKey<int>).value);
          return index < 0 ? null : index;
        };

        harness.move(0, 3);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        harness.remove(1);
        await tester.pump();
        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position
              ..jumpTo(600);
        await tester.pump();
        // The exit ends off screen, so its empty slot stays until it is laid
        // out again and a build drops it.
        await tester.pumpAndSettle();
        position.jumpTo(0);
        await tester.pump();
        harness.replaceData(0, harness.ids[0]);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(harness.ids.take(4), [1, 3, 0, 4]);
      },
    );

    final extentKinds = ValueVariant<String>({
      'itemExtent',
      'itemExtentBuilder',
    });
    testWidgets(
      'fo06/us11/fr04/e11 (R47): a new fixed extent lays the list out again in '
      'its own frame',
      (tester) async {
        final byBuilder = extentKinds.currentValue == 'itemExtentBuilder';
        Widget list(double extent) => _app(
          _Harness(
            count: 5,
            itemExtent: byBuilder ? null : extent,
            itemExtentBuilder: byBuilder ? (index, dimensions) => extent : null,
          ),
        );
        await tester.pumpWidget(list(40));
        expect(_offsetBetween(tester, 0, 1), 40);

        await tester.pumpWidget(list(56));

        expect(_offsetBetween(tester, 0, 1), 56);
      },
      variant: extentKinds,
    );

    testWidgets(
      'fo06/us11/fr04/e11 and NFR-U04 (R47): a prototypeItem measured again at a '
      'text scale of 2 lays the list out again in its own frame',
      (tester) async {
        Widget list(double scale) => _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: const _Harness(
                count: 5,
                prototypeItem: Text(
                  'P',
                  style: TextStyle(fontSize: 20, height: 1),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(list(1));
        expect(_offsetBetween(tester, 0, 1), 20);

        await tester.pumpWidget(list(2));

        expect(_offsetBetween(tester, 0, 1), 40);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e14 and D9 (R47): a move of the first laid-out item ends the '
      'leaving item above the cache origin with no item on screen moving',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(count: 200, itemsController: ReorderableItemsController()),
            theme: _normalTheme(const Duration(seconds: 2)),
          ),
        );
        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position
              ..jumpTo(4000);
        await tester.pump();
        // Item 93 sits at the cache origin, 3750; its exit shrinks there.
        _harness(tester).remove(93);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // The exit now lies wholly above the cache origin, 3790, and item
        // 94 is the first laid-out item.
        position.jumpTo(4040);
        await tester.pump();
        expect(_laidOut(tester).first, 94);
        final top = _top(tester, 102);

        _harness(tester).move(93, 143);
        await tester.pump();

        expect(_top(tester, 102), top);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e13 and s03/inv35 (R47): a raw change the app answers for, '
      'in the frame a leaving item ends, puts each key in one slot',
      (tester) async {
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 20,
              appIndex: true,
              itemsController: ReorderableItemsController(),
            ),
            theme: theme,
          ),
        );
        final harness = _harness(tester)..remove(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // In the frame the exit at gap 2 ends and drops: item 10 moves from
        // index 9 into index 5, item 6 at 5 leaves, and item 99 fills 9.
        harness
          ..replaceData(5, 10)
          ..replaceData(9, 99);
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey(6), skipOffstage: false),
          findsNothing,
        );
        for (final id in [10, 99]) {
          expect(find.byKey(ValueKey(id), skipOffstage: false), findsOneWidget);
        }
        expect(_offsetBetween(tester, 5, 10), 40);
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        position.jumpTo(0);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('fo06/us11/fr03 and s03/inv15 (R47): no item carries a global key, at rest, '
        'while one grows in, or while one leaves', (tester) async {
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: ReorderableItemsController())),
      );
      List<GlobalKey> globalKeys() {
        final keys = <GlobalKey>[];
        void visit(Element element) {
          final key = element.widget.key;
          if (key is GlobalKey) keys.add(key);
          element.visitChildren(visit);
        }

        tester.element(_reorderSliver()).visitChildren(visit);
        return keys;
      }

      expect(globalKeys(), isEmpty);
      _harness(tester)
        ..move(3, 0)
        ..remove(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Item 3 grows in at index 0, and item 1, now at index 2, leaves.
      expect(_runningTransitions(tester), isNotEmpty);
      expect(find.text('1'), findsOneWidget);
      expect(globalKeys(), isEmpty);
    });

    /// Items past 100 three times the 40 px the list lays out around index
    /// 100, so a far jump's estimate falls short and the reach runs.
    final tall = {for (var id = 101; id < 200; id++) id: 120.0};

    testWidgets(
      'matrix I14nxT11 and fo06/us11/fr05/e15 (L2): with no callback, a raw move of '
      'the item parked for its slot ends its State and hands focus to an item '
      'the list shows',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: tall,
            itemsController: ReorderableItemsController(),
          ),
        );
        final state = _itemState(tester, 100);
        await _focusItem(tester, 100);
        _harness(tester).move(100, 150);
        await tester.pump();
        expect(_statesOf(tester, 100), [same(state)]);
        expect(_builtInView(tester, 100), isFalse);

        _harness(tester).moveData(150, 160);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        final focused = FocusManager.instance.primaryFocus!.debugLabel!;
        expect(focused, startsWith('item '));
        expect(focused, isNot('item 100'));
        expect(_builtInView(tester, int.parse(focused.substring(5))), isTrue);
      },
    );

    testWidgets(
      'fo06/us11/fr05/e13: the list asks findChildIndexCallback at most once per '
      'registered key in a body build, and never on a scroll with no build',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200, appIndex: true),
        );
        final harness = _harness(tester)..indexCalls = 0;

        position.jumpTo(4400);
        await tester.pump();
        expect(harness.indexCalls, 0);

        final registered = _laidOut(tester).count;
        harness.moveData(110, 111);
        await tester.pump();
        expect(harness.indexCalls, lessThanOrEqualTo(registered));
      },
    );

    /// An insert with no controller at or before the last item a list laid
    /// out to its data's end: the scene, and the item it pushes past the
    /// last frame's laid-out range into a slot the next frame lays out.
    final pushedPastEnd = ValueVariant<({int count, int at, int id})>({
      (count: 5, at: 0, id: 4),
      (count: 3, at: 1, id: 2),
    });

    testWidgets('fo06/us11/fr04/e10 and D9 (L2): with no controller, an insert that pushes '
        'the last laid-out item into a slot the next frame lays out keeps its '
        'State', (tester) async {
      final (:count, :at, :id) = pushedPastEnd.currentValue!;
      await tester.pumpWidget(_app(_Harness(count: count)));
      final state = _itemState(tester, id);

      _harness(tester).insertData(at, 9);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_statesOf(tester, id), [same(state)]);
    }, variant: pushedPastEnd);

    testWidgets(
      'D9: with no controller and no callback, a short list the app swaps '
      'for a long one costs no itemBuilder call past the slots the next '
      'frame lays out',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          _app(_Harness(count: 5, onItemBuild: (_) => builds += 1)),
        );
        expect(_laidOut(tester).count, 5);

        builds = 0;
        final harness = _harness(tester);
        for (var i = 0; i < 5; i++) {
          harness.removeData(0);
        }
        for (var i = 0; i < 500; i++) {
          harness.insertData(i, 1000 + i);
        }
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(builds, lessThanOrEqualTo(_laidOut(tester).count));
      },
    );

    /// Items 0 to 3 at 60 px and 9 to 15 at 10 px: seven short items put
    /// before the four tall ones push the last tall one past the slots the
    /// room after them holds at the 60 px laid-out average (R54).
    final shortBeforeTall = {
      for (var id = 0; id < 4; id++) id: 60.0,
      for (var id = 9; id < 16; id++) id: 10.0,
    };

    testWidgets(
      'fo06/us11/fr04/e10 and D9 (L14, R54): with no controller and no callback, '
      'inserts of items shorter than the laid-out average that push the last '
      'item of a list laid out to its end past the slots the room holds end '
      "that item's State, though the next frame lays it out on screen",
      (tester) async {
        await tester.pumpWidget(
          _app(_Harness(count: 4, heights: shortBeforeTall)),
        );
        final state = _itemState(tester, 3);

        final harness = _harness(tester);
        for (var i = 0; i < 7; i++) {
          harness.insertData(0, 9 + i);
        }
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(_top(tester, 3), 250);
        expect(state.mounted, isFalse);
        expect(_statesOf(tester, 3), [isNot(same(state))]);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e10 and D9 (R54): under itemExtentBuilder, with no '
      'controller and no callback, the same inserts keep the pushed last '
      "item's State: the read counts the next layout at the builder's extents",
      (tester) async {
        _HarnessState? holder;
        double extentOf(int index, SliverLayoutDimensions dimensions) =>
            shortBeforeTall[holder?.ids[index] ?? index]!;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 4,
              heights: shortBeforeTall,
              itemExtentBuilder: extentOf,
            ),
          ),
        );
        final state = _itemState(tester, 3);

        final harness = holder = _harness(tester);
        for (var i = 0; i < 7; i++) {
          harness.insertData(0, 9 + i);
        }
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(_top(tester, 3), 250);
        expect(_statesOf(tester, 3), [same(state)]);
      },
    );

    // from, to, and an item on screen that neither slot's motion moves.
    final earlyMoves = ValueVariant<(int, int, int)>({
      (10, 20, 103),
      (10, 100, 95),
      (100, 10, 95),
    });
    testWidgets(
      'fo06/us11/fr05 and s03/inv58 (D9): a moveItem whose closing gap or target '
      'lies before the laid-out range moves no item on screen',
      (tester) async {
        final (from, to, still) = earlyMoves.currentValue!;
        // The still item sits fourth on screen.
        await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
          offset: (still - 3) * 40.0,
        );
        final top = _top(tester, still);

        _harness(tester).move(from, to);
        await tester.pump();
        expect(_top(tester, still), top);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_top(tester, still), top);
        await tester.pumpAndSettle();
        expect(_top(tester, still), top);
      },
      variant: earlyMoves,
    );

    testWidgets(
      'fo06/us11/fr05/e04 and s03/inv58 (D9): a focused item moved past the '
      'laid-out range in a turn whose moveItem drops a slot before that range '
      'shows on screen in the next frame',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // The frame laid out slots 93 to 113, and its cache ends at 4550.
        // Item 10's move drops a slot before them and item 100's closing gap
        // adds one among them, so index 112 starts at 4560: only the jump
        // at the next frame's start lays it out.
        _harness(tester)
          ..move(10, 150)
          ..move(99, 112);
        await tester.pump();
        expect(_builtInView(tester, 100), isTrue);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_itemState(tester, 100), same(state));
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(_itemInView(tester, 100), isTrue);
      },
    );

    testWidgets('fo06/us11/fr05/e04 and s03/inv58 (D9): a focused item moved to an unbuilt '
        'slot in a turn whose later moveItem calls add slots before the '
        'laid-out range shows on screen in the next frame', (tester) async {
      await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
      );
      final state = _itemState(tester, 100);
      final focused = await _focusItem(tester, 100);

      // The jump at the next frame's start lands by slot numbers, so that
      // frame keeps each slot at the offset its number held: the two slots
      // the later calls add before the laid-out range would put the item
      // two slots off where the jump put it, out of view.
      _harness(tester)
        ..move(100, 150)
        ..move(190, 10)
        ..move(191, 11);
      await tester.pump();
      expect(_builtInView(tester, 100), isTrue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_itemState(tester, 100), same(state));
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(_itemInView(tester, 100), isTrue);
    });

    testWidgets('fo06/us11/fr05 and s03/inv58 (D9): a moveItem past the laid-out range, in a '
        'turn after one that moved an item before another range, moves no item '
        'on screen', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
        offset: 3680,
      );
      _harness(tester).move(10, 100);
      await tester.pumpAndSettle();
      position.jumpTo(2000);
      await tester.pump();
      final top = _top(tester, 53);

      // The last turn counted from slot 85; this turn counts from the
      // first slot its own last frame laid out, so index 70 lies past the
      // range and drops no slot before it.
      _harness(tester).move(70, 150);
      await tester.pump();
      expect(_top(tester, 53), top);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_top(tester, 53), top);
      await tester.pumpAndSettle();
      expect(_top(tester, 53), top);
    });

    // Whether reduced motion is on: a leaving item then takes no room and
    // sits after the item that takes its place.
    final earlyRemoves = ValueVariant<bool>({false, true});
    testWidgets(
      'fo06/us11/fr04 and s03/inv58 (D9): many removeItem calls on kept-alive '
      'items before the laid-out range leave no ended exit behind, and move '
      'no laid-out item on screen',
      (tester) async {
        if (earlyRemoves.currentValue!) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        // Items 0 to 13, all the frame at offset 0 builds, keep themselves
        // alive once the list scrolls away, so each one a call takes out
        // leaves, and a kept-alive item still follows the last one taken.
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            keepAliveIds: {for (var id = 0; id < 14; id++) id},
            itemsController: ReorderableItemsController(),
          ),
        );
        final harness = _harness(tester);
        final top = _top(tester, 100);
        // The slots the sliver holds past the data's items: its exits.
        int exitSlots() {
          final sliver = tester.widget<SliverMultiBoxAdaptorWidget>(
            find.byWidgetPredicate(
              (widget) => widget is SliverMultiBoxAdaptorWidget,
              skipOffstage: false,
            ),
          );
          final delegate = sliver.delegate as SliverChildBuilderDelegate;
          return delegate.childCount! - harness.ids.length;
        }

        for (var i = 0; i < 10; i++) {
          harness.remove(0);
          await tester.pumpAndSettle();
          expect(exitSlots(), 0);
          expect(_top(tester, 100), top);
        }
        expect(tester.takeException(), isNull);
      },
      variant: earlyRemoves,
    );

    testWidgets(
      'fo06/us11/fr05 and s03/inv58 (D9): after moveItem calls that drop slots '
      'before the laid-out range, moving the kept-alive item at slot 0 away '
      'moves no laid-out item on screen',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            keepAliveIds: const {0},
            itemsController: ReorderableItemsController(),
          ),
        );
        final harness = _harness(tester);
        final top = _top(tester, 100);

        // Each move drops a slot before the laid-out range, so the frame
        // keeps the laid-out items where they stand (D9 item 4).
        for (var i = 0; i < 5; i++) {
          harness.move(50, 150);
          await tester.pumpAndSettle();
          expect(_top(tester, 100), top);
        }
        // Item 0 leaves slot 0, which the frame builds afresh.
        harness.move(0, 150);
        await tester.pump();
        expect(_top(tester, 100), top);
        await tester.pumpAndSettle();
        expect(_top(tester, 100), top);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('fo06/us11/fr04/e01 and s03/inv58 (D9): under reduced motion, removing the '
        'last kept-alive item before the laid-out range moves no laid-out item '
        'on screen', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      // Items 0 to 9 keep themselves alive once the list scrolls away.
      await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          keepAliveIds: {for (var id = 0; id < 10; id++) id},
          itemsController: ReorderableItemsController(),
        ),
      );
      final harness = _harness(tester);
      final top = _top(tester, 100);

      // The last removal leaves its slot to item 10, which the frame
      // builds afresh at slot 0.
      for (var i = 0; i < 10; i++) {
        harness.remove(0);
        await tester.pump();
        expect(_top(tester, 100), top);
        await tester.pumpAndSettle();
        expect(_top(tester, 100), top);
      }
      expect(tester.takeException(), isNull);
    });

    // A no-room exit whose host the trailing edge cuts, and one that hangs
    // past the last item: the item count, the removed id, and the item it
    // paints over or past.
    final edgeExits = ValueVariant<(String, int, int, int)>({
      ('trailing edge', 20, 7, 8),
      ('last item', 5, 4, 3),
    });
    testWidgets(
      'fo06/us11/fr04/e01 and s03/inv58 (D9): under reduced motion a removed item '
      'still paints at <the trailing edge, past the last item>',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final (_, count, id, host) = edgeExits.currentValue!;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: count,
              itemsController: ReorderableItemsController(),
            ),
          ),
        );

        _harness(tester).remove(id);
        await tester.pump();

        // Each item composites in its own repaint boundary, so an exit the
        // sliver paints has its layer in the tree, after its host's
        // (`_compositeOrder`, as pin 2240 reads it since Task 8). A paint log
        // cannot tell: an exit that moves in place keeps its clean layer.
        expect(_compositeOrder(tester, [host, id]), [host, id]);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: edgeExits,
    );

    testWidgets(
      'fo06/us11/fr04/e02 and s03/inv24 (D15): an item at rest costs one layer, '
      'and the element and render-object counts the chain lands at',
      (tester) async {
        tester.view
          ..physicalSize = const Size(200, 2000)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: themedHost(
                SizedBox(
                  width: 200,
                  height: 2000,
                  child: ReorderableListViewLayout.builder(
                    itemCount: 50,
                    onReorderItem: (from, to) {},
                    itemBuilder: (context, index) =>
                        SizedBox(key: ValueKey(index), height: 40),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sliver = tester.element(
          find
              .byWidgetPredicate(
                (widget) => widget is SliverMultiBoxAdaptorWidget,
              )
              .first,
        );
        var children = 0;
        var elements = 0;
        var renders = 0;
        var layers = 0;
        void count(Element element) {
          elements += 1;
          if (element is RenderObjectElement) {
            renders += 1;
            if (element.renderObject.debugLayer != null) layers += 1;
          }
          element.visitChildren(count);
        }

        sliver.visitChildren((child) {
          children += 1;
          count(child);
        });
        debugPrint(
          'COST per item: elements ${elements / children}, render objects '
          '${renders / children}, layers ${layers / children}',
        );
        expect(children, 50);
        expect(layers / children, 1);
        // The item root marker (layout s03 invariant 81) adds three
        // elements and one render object, no layer.
        expect(elements / children, 31);
        expect(renders / children, 15);
      },
    );

    testWidgets(
      'fix for task 11 review Important 1: with an itemExtent list, a '
      'scroll that, with the cache extent, lands on an exact extent '
      "multiple keeps the same first laid-out index as master's own "
      'fixed-extent list',
      (tester) async {
        const itemExtent = 50.0;
        const count = 200;
        const offset = 2000.0;

        Future<int> firstIndexAt(Widget app) async {
          await tester.pumpWidget(app);
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .jumpTo(offset);
          await tester.pump();
          return _laidOut(tester).first;
        }

        final master = await firstIndexAt(
          MaterialApp(
            home: Material(
              child: SizedBox(
                width: 200,
                height: 300,
                child: ListView.builder(
                  itemExtent: itemExtent,
                  itemCount: count,
                  itemBuilder: (context, index) =>
                      SizedBox(key: ValueKey('master $index')),
                ),
              ),
            ),
          ),
        );

        final reorder = await firstIndexAt(
          _app(const _Harness(count: count, itemExtent: itemExtent)),
        );

        expect(reorder, master);
      },
    );

    testWidgets('fo06/us11/fr01 and s03/inv59 (D7): a neighbor a drag passes slides over the '
        "theme's normal level", (tester) async {
      await tester.pumpWidget(
        _app(
          const _Harness(count: 5),
          theme: _normalTheme(const Duration(milliseconds: 400)),
        ),
      );
      final gesture = await _liftItem(tester, 0);
      await _dragPastNeighbor(tester, gesture);

      // 300 ms after the crossing: the SDK's 250 ms reflow has ended, the
      // theme's 400 ms one has not.
      await tester.pump(const Duration(milliseconds: 284));
      expect(_top(tester, 1), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_top(tester, 1), 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("fo06/us11/fr01 and s03/inv59 (D7): a dropped item settles over the theme's "
        'normal level', (tester) async {
      await tester.pumpWidget(
        _app(
          const _Harness(count: 5),
          theme: _normalTheme(const Duration(milliseconds: 400)),
        ),
      );
      final gesture = await _liftItem(tester, 0);
      await _dragPastNeighbor(tester, gesture);
      await tester.pumpAndSettle();

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The drop reports its move once its settle ends (pin 12116).
      expect(_harness(tester).moves, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_harness(tester).moves, [(0, 1)]);
    });

    // Pinning the scroll keeps the reach's own jump from ever landing: a
    // spring-back the reach does not watch for, so it retries all four
    // frames and gives up, with the EndUser's input landing anywhere in
    // that run, never racing the jump's own gap (FR-04 E20).
    final wall = {for (var id = 100; id < 150; id += 1) id: 250.0};
    testWidgets(
      'matrix I01xT11 and fo06/us11/fr04/e20: an immediate handle drag the '
      'EndUser starts while the list reaches for a parked item ends the '
      'reach at once with no exception, and the item stays alive off '
      'screen with its State and focus',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: wall,
            handles: true,
            itemsController: ReorderableItemsController(),
          ),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);
        _harness(tester).move(100, 150);
        await tester.pump();
        expect(_builtInView(tester, 100), isFalse);

        // A handle of an item wholly inside the viewport (never one the
        // cache alone built: its coordinate would read from a cache-only
        // box, off screen), grabbed with no long-press timer: the lift
        // lands in the same microtask-to-frame gap every reach jump
        // opens, with no frame between the pointer down and this move.
        final view = tester.getRect(find.byType(Scrollable));
        final built = [
          for (var id = 0; id < 200; id++)
            if (find.byKey(ValueKey('handle $id')).evaluate().isNotEmpty &&
                view.intersect(
                      tester.getRect(find.byKey(ValueKey('handle $id'))),
                    ) ==
                    tester.getRect(find.byKey(ValueKey('handle $id'))))
              id,
        ];
        expect(built, isNotEmpty);
        final dragged = built.first;
        final harness = _harness(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey('handle $dragged'))),
        );
        await gesture.moveBy(const Offset(0, 20));
        expect(tester.takeException(), isNull);
        // The touched item lifted: one onReorderStart, no onReorderEnd
        // before the drop.
        expect(harness.starts, hasLength(1));
        expect(harness.ends, isEmpty);
        // The touched item may have shifted index since the handle grab
        // (a concurrent park reflow), so its id comes from the start the
        // list itself reported, never the id this scene guessed first.
        final liftedId = harness.ids[harness.starts.single];
        await tester.pump();
        // Its proxy shows, drawn over the list (R49).
        expect(find.byType(RawImage), findsOne);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The drop lands: visible and taking pointer input in its slot,
        // with exactly the one onReorderEnd the drop itself reports. The
        // old abort path's own defect (Critical 1, fix round 2) left
        // `item.dragging` true forever, wrapping the item in a permanent
        // `IgnorePointer(ignoring: true)`; this proves neither that nor
        // a lingering drag proxy survives the drop.
        expect(harness.ends, hasLength(1));
        expect(find.byType(RawImage), findsNothing);
        final liftedElement = find
            .byKey(ValueKey(liftedId), skipOffstage: false)
            .evaluate()
            .single;
        final liftedBox = liftedElement.renderObject! as RenderBox;
        expect(liftedBox.attached, isTrue);
        expect(liftedBox.hasSize, isTrue);
        expect(_ignoringAncestors(liftedElement), isEmpty);

        expectKept(tester, 100, state, node: node);
      },
    );

    testWidgets('matrix I17xT10 and fo06/us11/fr04/e20: a scroll the EndUser starts while '
        'the list reaches for a parked item ends the reach at once, and the '
        'item stays alive off screen with its State and focus', (tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          heights: wall,
          handles: true,
          itemsController: ReorderableItemsController(),
        ),
      );
      final state = _itemState(tester, 100)..expanded = true;
      final node = await _focusItem(tester, 100);
      _harness(tester).move(100, 150);
      await tester.pump();
      expect(_builtInView(tester, 100), isFalse);

      final view = tester.getRect(find.byType(Scrollable));
      final gesture = await tester.startGesture(view.center);
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      final held = position.pixels;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position.pixels, held);
      await gesture.up();
      await tester.pumpAndSettle();

      expectKept(tester, 100, state, node: node);
    });

    testWidgets(
      'matrix I17xT07 and s03/inv26 (R45): a moved item a scroll takes out of '
      'view during its grow-in is not revealed again when the grow-in ends',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 103)..expanded = true;
        final node = await _focusItem(tester, 103);

        _harness(tester).move(103, 106);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        position.jumpTo(0);
        await tester.pumpAndSettle();

        expect(position.pixels, 0);
        expectKept(tester, 103, state, node: node);
        expect(_builtInView(tester, 103), isFalse);
      },
    );

    testWidgets(
      'matrix I02xT16 and fo06/us11/fr01/e11: the edge scroll does not scroll '
      "against the app's hold",
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 1000, handles: true)),
        );
        var springs = 0;
        _pinScroll(tester, 0, onSpringBack: () => springs += 1);
        final view = tester.getRect(find.byType(Scrollable));
        final gesture = await _grabHandle(tester, 3);

        await gesture.moveTo(Offset(view.center.dx, view.bottom - 5));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(springs, lessThanOrEqualTo(1));
        expect(positionOf(tester).pixels, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'fo06/us11/fr01/e11: the edge scroll keeps stepping through a continuous '
      'drag near the edge, with no app hold on the scroll',
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 1000, handles: true)),
        );
        final view = tester.getRect(find.byType(Scrollable));
        final gesture = await _grabHandle(tester, 3);
        await gesture.moveTo(Offset(view.center.dx, view.bottom - 5));
        // A short time slice, then a pointer move, repeated: each slice
        // lets the running step's own animateTo tick forward some, so the
        // move that follows re-stamps mid-step, as a continuously moving
        // finger does, were the stamp not guarded to a new step alone
        // (FR-01 E11).
        for (var i = 0; i < 150; i++) {
          await tester.pump(const Duration(milliseconds: 2));
          await gesture.moveTo(
            Offset(view.center.dx, view.bottom - 5 + i * 0.1),
          );
        }

        expect(positionOf(tester).pixels, greaterThan(100));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'R45: an app jumpTo with no reach, then an immediate handle grab '
      'before the next frame, lifts and drops the touched item with no '
      'exception',
      (tester) async {
        final painted = <int>[];
        await tester.pumpWidget(
          _app(_Harness(count: 200, handles: true, paintLog: painted)),
        );
        final harness = _harness(tester);
        final position = positionOf(tester);
        final at = tester.getCenter(find.byKey(const ValueKey('handle 2')));
        position.jumpTo(4000);

        final gesture = await tester.startGesture(at);
        await gesture.moveBy(const Offset(0, 20));
        expect(tester.takeException(), isNull);
        expect(harness.starts, hasLength(1));
        expect(harness.ends, isEmpty);
        final liftedId = harness.ids[harness.starts.single];
        await tester.pump();
        expect(find.byType(RawImage), findsOne);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, hasLength(1));
        expect(harness.moves, hasLength(1));
        expect(find.byType(RawImage), findsNothing);
        // The grab read the frame before the jump, so the drop lands the
        // item near the list's start, out of view at 4000. Scrolled back,
        // it builds in its slot painted and taking pointer input: no lift
        // outlives the drop to hide it again as it registers.
        position.jumpTo(0);
        await tester.pump();
        expect(_builtInView(tester, liftedId), isTrue);
        painted.clear();
        tester.renderObject(find.byKey(ValueKey(liftedId))).markNeedsPaint();
        await tester.pump();
        expect(painted, contains(liftedId));
        expect(find.byKey(ValueKey(liftedId)).hitTestable(), findsOne);
        expect(
          _ignoringAncestors(find.byKey(ValueKey(liftedId)).evaluate().single),
          isEmpty,
        );
      },
    );

    testWidgets(
      "R45: the EndUser's own scroll ends a reach for a parked item, then "
      'an immediate handle grab before the next frame, lifts and drops '
      'the touched item with no exception',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: wall,
            handles: true,
            itemsController: ReorderableItemsController(),
          ),
        );
        final harness = _harness(tester);
        _itemState(tester, 100).expanded = true;
        await _focusItem(tester, 100);
        harness.move(100, 150);
        await tester.pump();

        final view = tester.getRect(find.byType(Scrollable));
        final built = [
          for (var id = 0; id < 200; id++)
            if (find.byKey(ValueKey('handle $id')).evaluate().isNotEmpty &&
                view.intersect(
                      tester.getRect(find.byKey(ValueKey('handle $id'))),
                    ) ==
                    tester.getRect(find.byKey(ValueKey('handle $id'))))
              id,
        ];
        expect(built, isNotEmpty);
        final at = tester.getCenter(
          find.byKey(ValueKey('handle ${built.first}')),
        );

        final scroll = await tester.startGesture(view.center, pointer: 22);
        await scroll.moveBy(const Offset(0, -60));
        await scroll.up();

        final gesture = await tester.startGesture(at, pointer: 21);
        await gesture.moveBy(const Offset(0, 20));
        expect(tester.takeException(), isNull);
        expect(harness.starts, hasLength(1));
        expect(harness.ends, isEmpty);
        final liftedId = harness.ids[harness.starts.single];
        await tester.pump();
        expect(find.byType(RawImage), findsOne);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, hasLength(1));
        expect(find.byType(RawImage), findsNothing);
        final liftedElement = find
            .byKey(ValueKey(liftedId), skipOffstage: false)
            .evaluate()
            .single;
        final liftedBox = liftedElement.renderObject! as RenderBox;
        expect(liftedBox.attached, isTrue);
        expect(liftedBox.hasSize, isTrue);
        expect(_ignoringAncestors(liftedElement), isEmpty);
      },
    );

    testWidgets('R45: a drop of a lifted item the edge scroll carried past the '
        'built range reports its move and one end, with no exception', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Harness(count: 200, handles: true)));
      final harness = _harness(tester);
      final view = tester.getRect(find.byType(Scrollable));
      final gesture = await _grabHandle(tester, 2);
      await gesture.moveTo(Offset(view.center.dx, view.bottom - 2));
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The lifted item is no longer built where it drops, yet the drop
      // still reports its one move and its one end.
      expect(harness.moves, hasLength(1));
      expect(harness.ends, hasLength(1));
    });

    testWidgets(
      'R4, invariant 28, FR-03 E08: a screen-reader move action on the '
      'lifted item during its own drag reports the move and ends the '
      'drag at once, synchronously, never reading as the drop',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(const _Harness(count: 5, handles: true)));
        final harness = _harness(tester);
        await _grabHandle(tester, 2);
        expect(harness.starts, hasLength(1));
        expect(find.byType(RawImage), findsOne);

        // A buggy read of the drop by the last build's look, never the
        // sliver's own report, only tears the drag down later, in a
        // frame the SDK's own count-change cancel runs, by which time a
        // second report on the same stale index would recurse (the drop
        // this read starves, T15 RCA P5); the fix ends the drag inside
        // this very call, with no frame between the action and the end
        // (R4, invariant 28, FR-03 E08). Read with no pump between: a
        // pump would run that same count-change cancel regardless of
        // which read this proves, and mask the difference. The pointer
        // this grab started stays down: the drag already ended through
        // this action, never through that pointer's own up or cancel.
        moveActionNow(tester, 2, 'Move down');

        expect(harness.ends, hasLength(1));
        expect(harness.moves, [(2, 3)]);
        handle.dispose();
      },
    );

    // The handle's own listener and the item's long-press listener both
    // arm a recognizer for the one pointer down. A drag ended by a
    // non-pointer path leaves that pointer down, and its later release or
    // cancel must reach no lift the end already disposed.
    final releases = ValueVariant<String>({'up', 'cancel'});
    testWidgets(
      'FR-03 E08: after a screen-reader move action ends a handle drag, the '
      "release of the drag's own pointer raises no exception",
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(const _Harness(count: 5, handles: true)));
        final harness = _harness(tester);
        final gesture = await _grabHandle(tester, 2);
        moveActionNow(tester, 2, 'Move down');
        await tester.pump();
        expect(harness.ends, hasLength(1));
        expect(harness.moves, [(2, 3)]);

        if (releases.currentValue == 'up') {
          await gesture.up();
        } else {
          await gesture.cancel();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, hasLength(1));
        expect(harness.moves, [(2, 3)]);
        expect(find.byType(RawImage), findsNothing);
        handle.dispose();
      },
      variant: releases,
    );

    testWidgets('FR-04 E06: after an item-count change ends a handle drag, the '
        "release of the drag's own pointer raises no exception", (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Harness(count: 5, handles: true)));
      final harness = _harness(tester);
      final gesture = await _grabHandle(tester, 2);
      harness.insertData(0, 9);
      await tester.pump();
      expect(harness.ends, hasLength(1));

      if (releases.currentValue == 'up') {
        await gesture.up();
      } else {
        await gesture.cancel();
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.ends, hasLength(1));
      expect(harness.moves, isEmpty);
      expect(find.byType(RawImage), findsNothing);
    }, variant: releases);

    final rawIndexed = ValueVariant<bool>({false, true});
    testWidgets(
      'matrix I14nxT07 and I14cxT07, fo06/us11/fr05/e14: a raw move of an item '
      'still growing in ends its grow-in at once, and the item keeps its '
      'State and focus',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              appIndex: rawIndexed.currentValue!,
              itemsController: ReorderableItemsController(),
            ),
          ),
        );
        final harness = _harness(tester)..insert(1, 9);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final state = _itemState(tester, 9)..expanded = true;
        final node = await _focusItem(tester, 9);

        harness.moveData(1, 3);
        await tester.pump();

        expect(_runningTransitions(tester), isEmpty);
        expectKept(tester, 9, state, node: node);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: rawIndexed,
    );

    testWidgets('matrix I03xT14 and fo06/us11/fr03/e13: a focus the app moves from inside a '
        "drop's onReorderItem stays, and the list scrolls nothing for the "
        'dropped item', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 20)));
      final position = positionOf(tester);
      await _focusItem(tester, 2);
      final other = _itemState(tester, 0).node;
      final harness = _harness(tester)..onMove = (_, _) => other.requestFocus();

      // Slot 7 runs from 280 to 320: past the 300 px viewport by 20 px,
      // inside its cache extent, so the reveal the app's focus redirect
      // skips would otherwise scroll that 20 px to show it whole.
      final gesture = await _liftItem(tester, 2);
      for (var i = 0; i < 17; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.moves, [(2, 7)]);
      expect(FocusManager.instance.primaryFocus, same(other));
      expect(position.pixels, 0);
      expect(_itemInView(tester, 2), isFalse);
    });

    testWidgets(
      "fo06/us11/fr03/e13: a focus the app moves from inside a key move's "
      'onReorderItem stays, and the list scrolls nothing for the moved '
      'item, as a drop extends R13',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final position = positionOf(tester);
        await _focusItem(tester, 2);
        final other = _itemState(tester, 0).node;
        final harness = _harness(tester);
        for (var i = 0; i < 4; i++) {
          await _alt(tester, LogicalKeyboardKey.arrowDown);
        }
        expect(position.pixels, 0);

        // Slot 7 runs from 280 to 320: past the 300 px viewport by 20 px,
        // inside its cache extent, as the drop pin above uses.
        harness.onMove = (_, _) => other.requestFocus();
        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(harness.ids.indexOf(2), 7);
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(position.pixels, 0);
        expect(_itemInView(tester, 2), isFalse);
      },
    );

    testWidgets('fo06/us11/fr01 (R49): an item taller than the viewport lifts at a device '
        'pixel ratio of 3 as one still image', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const _Harness(count: 5, heights: {1: 1000})),
      );

      // The text's center sits 690 px down, past the list's 450 px end,
      // so the press lands near its top-left, inside the list.
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.text('1')) + const Offset(20, 20),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(RawImage), findsOne);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fo06/us11/fr01/e08 (R49): an item taller than the viewport scrolls nothing '
        'while it covers the list, and scrolls the list once its top edge '
        'shows inside it', (tester) async {
      await tester.pumpWidget(
        _app(const _Harness(count: 5, heights: {1: 1000})),
      );
      final position = positionOf(tester)..jumpTo(100);
      await tester.pump();

      // Item 1 runs from 90 to 1090 on screen, past both ends of the list
      // at 150 to 450; the press lands inside both.
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.text('1')) + const Offset(20, 70),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 10));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position.pixels, 100);

      await gesture.moveBy(const Offset(0, 60));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position.pixels, greaterThan(100));
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'fo06/us11/fr05 (R53): under a size grow-in, a moved item sits in the live '
      'screen-reader tree from the first frame it has a size, the frame after '
      'it lands, while its fade still runs',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: ReorderableItemsController()),
          ),
        );

        _harness(tester).move(3, 1);
        await tester.pump();
        expect(_sizeBox(tester, 3).size.height, 0);
        await tester.pump(const Duration(milliseconds: 16));

        expect(_sizeBox(tester, 3).size.height, greaterThan(0));
        expect(_enteringOpacity(tester, 3), lessThan(0.5));
        expect(_liveSemanticsLabel(tester, '3'), isTrue);
        await tester.pumpAndSettle();
        expect(_liveSemanticsLabel(tester, '3'), isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us11/fr01 (R57/R58): an item taller than an app DragBoundary lifts '
      'and drags past the boundary edge with no exception, its pointer '
      'kept inside the boundary, then drops with one onReorderEnd',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const DragBoundary(child: _Harness(count: 5, heights: {1: 1000})),
          ),
        );

        // Item 1 runs from 40 to 1040 on screen; the press lands near its
        // top-left, inside both the item and the list.
        final gesture = await tester.startGesture(
          tester.getTopLeft(find.text('1')) + const Offset(20, 20),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(find.byType(RawImage), findsOne);

        await gesture.moveBy(const Offset(0, 500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final pinned = tester.getTopLeft(find.byType(RawImage));

        // A second move further past the same edge lands the pointer at
        // the same clamped point, so the proxy sits exactly where it did.
        await gesture.moveBy(const Offset(0, 500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getTopLeft(find.byType(RawImage)), pinned);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_harness(tester).ends.length, 1);
      },
    );

    testWidgets(
      'fo06/us11/fr01 (R57/R58): an item wider than an app DragBoundary lifts '
      'and drags past the boundary edge with no exception, its pointer '
      'kept inside the boundary, then drops with one onReorderEnd',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const DragBoundary(
              child: _Harness(
                count: 5,
                axis: Axis.horizontal,
                widths: {1: 1000},
              ),
            ),
          ),
        );

        // Item 1 runs from 40 to 1040 on screen; the press lands near its
        // top-left, inside both the item and the list.
        final gesture = await tester.startGesture(
          tester.getTopLeft(find.text('1')) + const Offset(20, 20),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(find.byType(RawImage), findsOne);

        await gesture.moveBy(const Offset(500, 0));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final pinned = tester.getTopLeft(find.byType(RawImage));

        // A second move further past the same edge lands the pointer at
        // the same clamped point, so the proxy sits exactly where it did.
        await gesture.moveBy(const Offset(500, 0));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getTopLeft(find.byType(RawImage)), pinned);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_harness(tester).ends.length, 1);
      },
    );

    testWidgets('R56: an EndUser scroll that ends a reach shows no jump', (
      tester,
    ) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          heights: wall,
          handles: true,
          itemsController: ReorderableItemsController(),
        ),
      );
      _itemState(tester, 100).expanded = true;
      await _focusItem(tester, 100);
      _harness(tester).move(100, 150);
      await tester.pump();
      expect(_builtInView(tester, 100), isFalse);

      final shownOffset = laidOffset(tester);
      final before = position.pixels;
      final view = tester.getRect(find.byType(Scrollable));
      final gesture = await tester.startGesture(view.center);
      await gesture.moveBy(const Offset(0, -60));
      final userDelta = position.pixels - before;
      expect(userDelta, isNot(0.0));
      await tester.pump();
      // The frame after the EndUser's scroll shows the offset the last
      // frame showed, moved by that scroll alone: no jump the reach
      // issued lands.
      expect(laidOffset(tester), shownOffset + userDelta);

      // The EndUser's drag still follows the finger: no list jump
      // ended it.
      final held = position.pixels;
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(position.pixels - held, 40.0);
      expect(laidOffset(tester), position.pixels);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'R56: a grab during a reach lifts the touched item and the list '
      'stays where the EndUser grabbed it',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: wall,
            handles: true,
            itemsController: ReorderableItemsController(),
          ),
        );
        _itemState(tester, 100).expanded = true;
        await _focusItem(tester, 100);
        _harness(tester).move(100, 150);
        await tester.pump();
        expect(_builtInView(tester, 100), isFalse);

        final shownOffset = laidOffset(tester);
        final view = tester.getRect(find.byType(Scrollable));
        final built = [
          for (var id = 0; id < 200; id++)
            if (find.byKey(ValueKey('handle $id')).evaluate().isNotEmpty &&
                view.intersect(
                      tester.getRect(find.byKey(ValueKey('handle $id'))),
                    ) ==
                    tester.getRect(find.byKey(ValueKey('handle $id'))))
              id,
        ];
        expect(built, isNotEmpty);
        final dragged = built.first;
        final harness = _harness(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey('handle $dragged'))),
        );
        await gesture.moveBy(const Offset(0, 20));
        expect(tester.takeException(), isNull);
        expect(harness.starts, hasLength(1));
        expect(harness.ends, isEmpty);
        final liftedId = harness.ids[harness.starts.single];
        await tester.pump();
        expect(liftedId, dragged);
        // The reach's own jump, booked before the grab, drops: it never
        // lands under the lifted proxy (R45).
        expect(laidOffset(tester), shownOffset);
        expect(find.byType(RawImage), findsOne);
        // The lifted wall item runs past the viewport's bottom edge, so only
        // the lift's own edge scroll moves the list while it holds: each
        // frame moves by at most one 20 px edge step, never by a jump the
        // reach booked.
        var heldOffset = shownOffset;
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(laidOffset(tester) - heldOffset, inInclusiveRange(0, 20));
          heldOffset = laidOffset(tester);
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(harness.ends, hasLength(1));
        expect(find.byType(RawImage), findsNothing);
      },
    );

    testWidgets('R56: a grab right after a screen-reader move lifts with no '
        'reveal landing under it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 20,
            handles: true,
            itemsController: ReorderableItemsController(),
          ),
        ),
      );
      moveActionNow(tester, 6, 'Move down');
      await tester.pump();
      final shownOffset = laidOffset(tester);
      final harness = _harness(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('handle 2'))),
      );
      await gesture.moveBy(const Offset(0, 20));
      expect(harness.starts, hasLength(1));
      await tester.pump();
      // A reveal the move booked before the grab never lands under the
      // lifted item (R45).
      expect(laidOffset(tester), shownOffset);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
      'R56: a list scroll an app scroll listener throws on is reported, and '
      "each scroll booked after it for the same frame's start still runs",
      (tester) async {
        final handle = tester.ensureSemantics();
        var armed = false;
        await tester.pumpWidget(
          _app(
            NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (!armed) return false;
                armed = false;
                throw StateError('app scroll listener');
              },
              child: _Harness(
                count: 200,
                itemsController: ReorderableItemsController(),
              ),
            ),
          ),
        );
        positionOf(tester).jumpTo(4000);
        await tester.pump();

        // Both moves book a jump for the next frame's start (R46): the
        // first, to the end, meets the throwing listener.
        armed = true;
        moveActionNow(tester, 100, 'Move to the end');
        moveActionNow(tester, 101, 'Move to the start');
        await tester.pump();

        expect(tester.takeException(), isA<StateError>());
        expect(laidOffset(tester), 0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    /// Pumps the [wall] list scrolled to [offset], with item 100 expanded
    /// and focused; returns its position, State, and node.
    Future<(ScrollPosition, _ItemState, FocusNode)> wallScene(
      WidgetTester tester, {
      double offset = 4000,
    }) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          heights: wall,
          handles: true,
          itemsController: ReorderableItemsController(),
        ),
        offset: offset,
      );
      final state = _itemState(tester, 100)..expanded = true;
      final node = await _focusItem(tester, 100);
      return (position, state, node);
    }

    /// [wallScene] with item 100 moved far, to 150: the move's frame misses
    /// its slot, so the list reaches for it; returns with that reach
    /// running and the item parked off screen.
    Future<(ScrollPosition, _ItemState, FocusNode)> reachRunning(
      WidgetTester tester,
    ) async {
      final scene = await wallScene(tester);
      _harness(tester).move(100, 150);
      await tester.pump();
      expect(_builtInView(tester, 100), isFalse);
      return scene;
    }

    /// Item [id] kept [state], its expanded flag, and primary focus on
    /// [node], parked off screen (R29).
    void expectParked(
      WidgetTester tester,
      int id,
      _ItemState state,
      FocusNode node,
    ) {
      expectKept(tester, id, state, node: node);
      expect(_builtInView(tester, id), isFalse);
    }

    /// The offsets the next [count] frames, 16 ms apart, lay the list out
    /// at.
    Future<List<double>> laidFrames(WidgetTester tester, int count) async {
      final laid = <double>[];
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        laid.add(laidOffset(tester));
      }
      return laid;
    }

    testWidgets(
      'R45: an app jumpTo while a reach runs is what the next frame lays '
      'out, no later frame jumps over it, and the item stays parked',
      (tester) async {
        final (position, state, node) = await reachRunning(tester);
        final target = laidOffset(tester) + 300;

        position.jumpTo(target);
        await tester.pump();
        expect(laidOffset(tester), target);
        expect(await laidFrames(tester, 10), everyElement(target));
        await tester.pumpAndSettle();

        expect(position.pixels, target);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      'R45: an app animateTo while a reach runs runs to its end on its own '
      'path, and the item stays parked',
      (tester) async {
        final (position, state, node) = await reachRunning(tester);
        final shownOffset = laidOffset(tester);
        final target = shownOffset + 600;

        final done = position.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutSine,
        );
        final laid = await laidFrames(tester, 30);
        await tester.pumpAndSettle();
        await done;

        // Every frame lies on the animation's own path, from the shown
        // offset on toward the target: no reach jump lands between them.
        expect(laid, everyElement(inInclusiveRange(shownOffset, target)));
        expect([...laid]..sort(), laid);
        expect(laid.last, target);
        expect(position.pixels, target);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      'R45: an app jumpTo from the frame callbacks that build and lay out, '
      'as from an app build or layout, ends a running reach',
      (tester) async {
        final (position, state, node) = await reachRunning(tester);
        final target = laidOffset(tester) + 300;
        var jumped = false;
        // A persistent callback stays for the binding's life: it acts once.
        tester.binding.addPersistentFrameCallback((_) {
          if (jumped) return;
          jumped = true;
          position.jumpTo(target);
        });

        await tester.pump();
        expect(jumped, isTrue);
        expect(await laidFrames(tester, 10), everyElement(target));
        await tester.pumpAndSettle();

        expect(position.pixels, target);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      'R45: an app jumpTo past the end while a reach runs ends the reach, '
      'and only the physics settles the offset back to the end',
      (tester) async {
        final (position, state, node) = await reachRunning(tester);

        position.jumpTo(position.maxScrollExtent + 200);
        final laid = await laidFrames(tester, 30);
        await tester.pumpAndSettle();

        // The settle moves only back toward the end, frame by frame.
        expect([...laid]..sort((a, b) => b.compareTo(a)), laid);
        expect(position.pixels, position.maxScrollExtent);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      'R45: a grab after an app moveItem, before its frame, keeps every '
      'frame where the EndUser grabbed: no reach the move left scrolls '
      'under it',
      (tester) async {
        // Items 95 to 99 show above item 100, so a handle other than the
        // moved item's sits in view before the move's frame.
        await wallScene(tester, offset: 3800);
        final shownOffset = laidOffset(tester);
        final handle = find.byKey(const ValueKey('handle 95'));
        final view = tester.getRect(find.byType(Scrollable));
        expect(view.intersect(tester.getRect(handle)), tester.getRect(handle));

        final harness = _harness(tester)..move(100, 150);
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await gesture.moveBy(const Offset(0, 20));
        expect(tester.takeException(), isNull);
        expect(harness.starts, hasLength(1));
        await tester.pump();
        await tester.pump();
        expect(laidOffset(tester), shownOffset);
        expect(await laidFrames(tester, 5), everyElement(shownOffset));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(harness.ends, hasLength(1));
      },
    );

    testWidgets(
      'R45: a scroll drag held still after an app moveItem, before its '
      'frame, keeps every frame under the finger: no reach the move left '
      'scrolls under it',
      (tester) async {
        final (position, _, _) = await wallScene(tester);
        final shownOffset = laidOffset(tester);
        _harness(tester).move(100, 150);

        final before = position.pixels;
        final view = tester.getRect(find.byType(Scrollable));
        final gesture = await tester.startGesture(view.center);
        await gesture.moveBy(const Offset(0, -60));
        final userDelta = position.pixels - before;
        expect(userDelta, isNot(0.0));
        await tester.pump();
        await tester.pump();
        expect(laidOffset(tester), shownOffset + userDelta);
        expect(
          await laidFrames(tester, 5),
          everyElement(shownOffset + userDelta),
        );

        // The drag still follows the finger: no list jump ended it.
        final held = position.pixels;
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        expect(position.pixels - held, 40.0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'R45: a mouse-wheel scroll after an app moveItem, before its frame, '
      'is what every frame lays out, and the moved item stays parked',
      (tester) async {
        final (position, state, node) = await wallScene(tester);
        _harness(tester).move(100, 150);

        final view = tester.getRect(find.byType(Scrollable));
        final pointer = TestPointer(81, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(view.center));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
        final wheeled = position.pixels;
        expect(wheeled, 4120.0);
        expect(await laidFrames(tester, 8), everyElement(wheeled));
        await tester.pumpAndSettle();

        expect(position.pixels, wheeled);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      'R60: an app jumpTo one frame into a reach, while the reached item '
      'grows in, is what every later frame lays out: no re-reveal scrolls '
      'over it',
      (tester) async {
        final (position, state, node) = await reachRunning(tester);
        await tester.pump();
        expect(_runningTransitions(tester), isNotEmpty);
        final target = laidOffset(tester) - 300;

        position.jumpTo(target);
        await tester.pump();
        expect(laidOffset(tester), target);
        expect(await laidFrames(tester, 10), everyElement(target));
        await tester.pumpAndSettle();

        expect(position.pixels, target);
        expectKept(tester, 100, state, node: node);
        expect(_builtInView(tester, 100), isFalse);
      },
    );

    testWidgets(
      'R62: an app jumpTo in the turn of its own far moveItem wins: every '
      'frame lays out its offset, and the moved item stays parked with its '
      'State and focus',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        _harness(tester).move(100, 150);
        position.jumpTo(2000);
        expect(await laidFrames(tester, 12), everyElement(2000.0));
        await tester.pumpAndSettle();

        expect(position.pixels, 2000);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      "R61: an app jumpTo while a drop settles wins over the drop's reveal: "
      'the offset stays, and the dropped item stays parked with its State '
      'and focus',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 200,
              handles: true,
              itemsController: ReorderableItemsController(),
            ),
          ),
        );
        final position = positionOf(tester);
        final state = _itemState(tester, 3)..expanded = true;
        final node = await _focusItem(tester, 3);
        final harness = _harness(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('handle 3'))),
        );
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 50));
        // The drag ended at pointer-up, and its drop still settles.
        expect(harness.ends, hasLength(1));
        expect(harness.moves, isEmpty);

        position.jumpTo(4000);
        await tester.pumpAndSettle();

        expect(harness.moves, [(3, 6)]);
        expect(position.pixels, 4000);
        expectParked(tester, 3, state, node);
      },
    );

    testWidgets(
      'fo06/us11/fr04/e04 and e17 (R45): an app jumpTo after the app removes a '
      'focused item and inserts it back at an unbuilt slot in one turn wins, '
      'and the item stays parked with its State and focus, never lost',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        // The insert moves the item's element, with its State, into the new
        // slot in place, so the park keeps it while the app's scroll holds:
        // focus never falls to nothing (E04).
        _harness(tester)
          ..remove(100)
          ..insert(0, 100);
        position.jumpTo(4040);
        await tester.pumpAndSettle();

        expect(position.pixels, 4040);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      "R63 (limit): an app listener's jump inside the list's own reach jump "
      "counts as the list's, so the reach runs on and reaches the item",
      (tester) async {
        final (position, state, node) = await reachRunning(tester);
        final shownOffset = laidOffset(tester);
        var sprang = false;
        position.addListener(() {
          if (sprang || position.pixels == shownOffset) return;
          sprang = true;
          position.jumpTo(shownOffset);
        });

        await tester.pumpAndSettle();

        // Flutter dispatches the app's jump inside the list's own: nothing
        // tells the two apart, so the list owns both (R63).
        expect(sprang, isTrue);
        expectKept(tester, 100, state, node: node);
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets(
      'R63 (limit): an app animateTo that starts while a physics settle runs '
      'sends no scroll start, so the list keeps the scroll and its move jump '
      'lands over it',
      (tester) async {
        var starts = 0;
        await tester.pumpWidget(
          _app(
            NotificationListener<ScrollStartNotification>(
              onNotification: (_) {
                starts += 1;
                return false;
              },
              child: _Harness(
                count: 200,
                itemsController: ReorderableItemsController(),
              ),
            ),
          ),
        );
        final position = positionOf(tester)..jumpTo(7700);
        await tester.pump();
        final state = _itemState(tester, 190)..expanded = true;
        final node = await _focusItem(tester, 190);
        final harness = _harness(tester);
        // Three items fewer leave the offset past the new end: the physics
        // starts its settle in the layout that measures it.
        for (var i = 0; i < 3; i++) {
          harness.removeData(197);
        }
        await tester.pump();
        expect(position.outOfRange, isTrue);

        harness.move(190, 10);
        final before = starts;
        final animation = position.animateTo(
          3000,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutSine,
        );
        // An activity that takes over a running one starts no scroll
        // (R63): the list never sees the app's.
        expect(starts, before);
        await tester.pumpAndSettle();
        await animation;

        expectKept(tester, 190, state, node: node);
        expect(_builtInView(tester, 190), isTrue);
      },
    );

    testWidgets(
      'R63 (limit): an app jump past the end from the frame callbacks that '
      'build and lay out counts as the physics settle, so the reach runs on '
      'and reaches the item',
      (tester) async {
        final (position, state, node) = await reachRunning(tester);
        var jumped = false;
        // A persistent callback stays for the binding's life: it acts once.
        tester.binding.addPersistentFrameCallback((_) {
          if (jumped) return;
          jumped = true;
          position.jumpTo(position.maxScrollExtent + 200);
        });

        await tester.pumpAndSettle();

        // A start in layout past the end reads as the physics' own settle
        // (R63): the list cannot tell the app's jump from it.
        expect(jumped, isTrue);
        expectKept(tester, 100, state, node: node);
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets(
      "L18 (limit, tripwire): an app scroll that starts while the lift's "
      "own edge auto-scroll still steps counts as the lift's own",
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 1000, handles: true)),
        );
        final position = positionOf(tester);
        final view = tester.getRect(find.byType(Scrollable));
        await _focusItem(tester, 3);
        final gesture = await _grabHandle(tester, 3);
        await gesture.moveTo(Offset(view.center.dx, view.bottom - 5));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        // L18's own window: the pointer is up, and the lift's own edge
        // auto-scroll still steps through the drop's settle.
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 16));
        final stepping = position.pixels;
        await tester.pump(const Duration(milliseconds: 16));
        expect(position.pixels, greaterThan(stepping));

        // The app starts its own scroll there (L18, design:667): nothing
        // tells it from the edge step, so it counts as the lift's, and the
        // drop still reveals the dropped item over it. Had the list told
        // the two apart, the app's scroll would win over the drop's reveal
        // (FR-03 E14), and the item would stay off screen.
        position.jumpTo(position.pixels + 5000);
        final afterJump = position.pixels;
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(position.pixels, lessThan(afterJump));
        expect(_builtInView(tester, 3), isTrue);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 3');
      },
    );

    testWidgets(
      'L20 (limit, tripwire): an app animateTo that starts during an EndUser '
      'fling sends no scroll start, so the list reads it as the fling and a '
      'move input stops it',
      (tester) async {
        var starts = 0;
        await tester.pumpWidget(
          _app(
            NotificationListener<ScrollStartNotification>(
              onNotification: (_) {
                starts += 1;
                return false;
              },
              child: const _Harness(count: 200),
            ),
          ),
        );
        final position = positionOf(tester)..jumpTo(4000);
        await tester.pump();
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -100),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final before = starts;
        final animation = position.animateTo(
          5000,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutSine,
        );
        // An activity that takes over the running fling starts no scroll
        // (L20, R63): the list never sees the app's.
        expect(starts, before);
        await tester.pump(const Duration(milliseconds: 16));

        // Nothing tells the app's scroll from the fling, so the key stops
        // it and reveals the moved item at slot 101, 4040 px. Had the list
        // told the two apart, the app's scroll would run on to 5000 and the
        // item would stay off screen (R45).
        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await animation;

        expect(position.pixels, 4040);
        expect(shown(tester, 100), isTrue);
        expectKept(tester, 100, state, node: node);
        expect(_harness(tester).moves, [(100, 101)]);
      },
    );

    testWidgets(
      'R45: an app jumpTo in the turn the app removes the focused item holds '
      'every frame, and focus moves on from the gap with no scroll',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        await _focusItem(tester, 100);

        _harness(tester).remove(100);
        position.jumpTo(5000);
        expect(await laidFrames(tester, 10), everyElement(5000.0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(position.pixels, 5000);
        final focused = FocusManager.instance.primaryFocus?.debugLabel;
        expect(focused, startsWith('item '));
        expect(focused, isNot('item 100'));
      },
    );

    // A call before the shown focused item that shifts it, in the same turn
    // as the app's jumpTo.
    final shifts = ValueVariant<String>({'removeItem', 'insertItem'});
    testWidgets(
      'R45: an app jumpTo after a call that shifts the shown focused item, '
      'in one turn, holds every frame, and the item stays parked with its '
      'State and focus',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        final harness = _harness(tester);
        if (shifts.currentValue == 'removeItem') {
          harness.remove(50);
        } else {
          harness.insert(50, 900);
        }
        position.jumpTo(2000);
        expect(await laidFrames(tester, 10), everyElement(2000.0));
        await tester.pumpAndSettle();

        expect(position.pixels, 2000);
        expectParked(tester, 100, state, node);
      },
      variant: shifts,
    );

    // A far move of the focused item while the EndUser drags another one:
    // by a call, by a reorder key, and by a screen reader's action.
    final movesInDrag = ValueVariant<String>({
      'moveItem',
      'Alt+End',
      'Move to the end',
    });
    testWidgets(
      'R45: a far move of the focused item during a live drag of another '
      'item ends the drag first, and the list shows the item where it lands',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            handles: true,
            itemsController: ReorderableItemsController(),
          ),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);
        final harness = _harness(tester);
        final gesture = await _grabHandle(tester, 103);
        expect(harness.starts, hasLength(1));

        switch (movesInDrag.currentValue!) {
          case 'moveItem':
            harness.move(100, 199);
          case 'Alt+End':
            await _altNow(tester, LogicalKeyboardKey.end);
          default:
            moveActionNow(tester, 100, 'Move to the end');
        }
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(harness.ends, hasLength(1));
        expect(harness.ids.last, 100);
        expectKept(tester, 100, state, node: node);
        expect(_builtInView(tester, 100), isTrue);
        handle.dispose();
      },
      variant: movesInDrag,
    );

    testWidgets(
      'R45: an item-count change with no call that moves the focused item '
      'kept alive off screen during a live drag of another item ends the '
      'drag first, and the list shows the item at its slot',
      (tester) async {
        final controller = ReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(count: 200, appIndex: true, itemsController: controller),
          ),
        );
        final state = _itemState(tester, 0)..expanded = true;
        final focused = await _focusItem(tester, 0);
        final harness = _harness(tester)
          ..remove(0)
          ..insert(199, 0);
        await tester.pump();
        expect(_statesOf(tester, 0), [same(state)]);

        final gesture = await _liftItem(tester, 2);
        expect(harness.starts, hasLength(1));

        harness.removeData(5);
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(harness.ends, hasLength(1));
        expectKept(tester, 0, state, node: focused);
        expect(_builtInView(tester, 0), isTrue);
      },
    );

    testWidgets(
      'R45: a far moveItem of the focused item from onReorderStart ends the '
      'drag it reports, and the list shows the item where it lands',
      (tester) async {
        await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            handles: true,
            itemsController: ReorderableItemsController(),
          ),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);
        final harness = _harness(tester)
          ..onStart = (_) => _harness(tester).move(100, 199);

        final gesture = await _grabHandle(tester, 103);
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(harness.starts, hasLength(1));
        expect(harness.ends, hasLength(1));
        expect(harness.ids.last, 100);
        expectKept(tester, 100, state, node: node);
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets('R60: an app scroll during the grow-in of a near move, then an '
        'unrelated call, leaves no re-reveal to scroll over the app', (
      tester,
    ) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(count: 200, itemsController: ReorderableItemsController()),
      );
      final state = _itemState(tester, 100)..expanded = true;
      final node = await _focusItem(tester, 100);
      final harness = _harness(tester)..move(100, 103);
      await tester.pump();
      expect(_runningTransitions(tester), isNotEmpty);

      // The item, at slot 103 from 4120 to 4160, stays shown but clipped
      // at the viewport's bottom edge.
      position.jumpTo(3850);
      await tester.pump();
      harness.insert(199, 900);
      expect(await laidFrames(tester, 30), everyElement(3850.0));
      await tester.pumpAndSettle();

      expect(position.pixels, 3850);
      expectKept(tester, 100, state, node: node);
    });

    testWidgets(
      'R45: a mouse-wheel scroll after an app moveItem, then an unrelated '
      'call, both before the frame: no reach the move left scrolls over the '
      'wheel',
      (tester) async {
        final (position, state, node) = await wallScene(tester);
        final harness = _harness(tester)..move(100, 150);

        final view = tester.getRect(find.byType(Scrollable));
        final pointer = TestPointer(81, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(view.center));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
        final wheeled = position.pixels;
        expect(wheeled, 4120.0);
        harness.insert(199, 900);
        expect(await laidFrames(tester, 8), everyElement(wheeled));
        await tester.pumpAndSettle();

        expect(position.pixels, wheeled);
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      'R56: a frame jump, a reveal, and a second frame jump booked for one '
      "frame's start run in booking order, so the last one stands",
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        // Item 107 runs 20 px past the viewport's bottom edge at 4000.
        await _focusItem(tester, 107);

        // Posted before the key move, so it runs ahead of the move's reveal
        // in the next post-frame batch: a jump to the end.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => moveActionNow(tester, 110, 'Move to the end'),
        );
        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        // Posted after the key move's reveal: a jump to the start.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => moveActionNow(tester, 111, 'Move to the start'),
        );
        await tester.pump();
        await tester.pump();
        expect(laidOffset(tester), 0);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    // A move input during the momentum of a fling the EndUser let go of,
    // with the focused item in view or flung out above it (R66).
    final flingMoves = ValueVariant<(String, String)>({
      for (final input in ['Alt+Down', 'Move down'])
        for (final place in ['in view', 'above the view']) (input, place),
    });
    testWidgets(
      'R66: an <Alt+Down, "Move down"> during the momentum of an EndUser '
      'fling, the focused item <in view, above the view>, stops the fling '
      'and reveals the moved item with its State and focus',
      (tester) async {
        final (input, place) = flingMoves.currentValue!;
        final handle = tester.ensureSemantics();
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        // At 4000 px, item 100 sits at the top of the 300 px view and item
        // 106 at 240 to 280 px; the fling carries item 100 out above it.
        final id = place == 'in view' ? 106 : 100;
        final state = _itemState(tester, id)..expanded = true;
        final node = await _focusItem(tester, id);

        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -100),
          1000,
        );
        await tester.pump();
        final flung = position.pixels;
        await tester.pump(const Duration(milliseconds: 16));
        // The momentum still runs once the EndUser let go.
        expect(position.pixels, greaterThan(flung));
        expect(shown(tester, id), place == 'in view');

        final atInput = position.pixels;
        if (input == 'Alt+Down') {
          await _altNow(tester, LogicalKeyboardKey.arrowDown);
        } else {
          moveActionNow(tester, id, 'Move down');
        }
        await tester.pump();
        await tester.pump();
        // The input stopped the fling: in view, where it stood; above the
        // view, at the least scroll that shows slot 101, 4040 px.
        final stopped = place == 'in view' ? atInput : 4040.0;
        expect(laidOffset(tester), stopped);
        expect(await laidFrames(tester, 10), everyElement(stopped));
        await tester.pumpAndSettle();

        expect(position.pixels, stopped);
        expect(shown(tester, id), isTrue);
        expectKept(tester, id, state, node: node);
        expect(_harness(tester).moves, [(id, id + 1)]);
        handle.dispose();
      },
      variant: flingMoves,
    );

    testWidgets(
      'R66: an app animateTo still running at an Alt+Down runs on to its end '
      'on its own path, and the moved item keeps its State and focus',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        final done = position.animateTo(
          4600,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutSine,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final atKey = position.pixels;
        expect(atKey, greaterThan(4000));

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        final laid = await laidFrames(tester, 30);
        await tester.pumpAndSettle();
        await done;

        // Every frame lies on the animation's own path, from where the key
        // found it on toward its target: the key stopped nothing, and no
        // reveal jump lands between them.
        expect(laid, everyElement(inInclusiveRange(atKey, 4600)));
        expect([...laid]..sort(), laid);
        expect(laid.last, 4600);
        expect(position.pixels, 4600);
        expectKept(tester, 100, state, node: node);
        expect(_harness(tester).moves, [(100, 101)]);
      },
    );

    testWidgets(
      'R66: an Alt+Down during a scroll drag the EndUser still holds stops '
      'nothing: the drag still follows the finger',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        // The first move crosses the touch slop and starts the drag; the
        // second scrolls the list under the finger.
        final view = tester.getRect(find.byType(Scrollable).first);
        final gesture = await tester.startGesture(view.center);
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        final held = position.pixels;
        expect(held, greaterThan(4000));

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        expect(await laidFrames(tester, 5), everyElement(held));
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        expect(position.pixels - held, 40.0);

        await gesture.up();
        await tester.pumpAndSettle();
        expectKept(tester, 100, state, node: node);
        expect(_harness(tester).moves, [(100, 101)]);
      },
    );

    testWidgets(
      'R66: an Alt+Down while an EndUser fling bounces back from past the '
      'end stops the bounce and reveals the moved item with its State and '
      'focus',
      (tester) async {
        // Under bouncing physics a fling runs past the end and springs back
        // as part of its own momentum.
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200, physics: BouncingScrollPhysics()),
          offset: 7500,
        );
        final state = _itemState(tester, 188)..expanded = true;
        final node = await _focusItem(tester, 188);

        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -100),
          3000,
        );
        for (var i = 0; i < 60 && !position.outOfRange; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(position.pixels, greaterThan(position.maxScrollExtent));

        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.pump();
        // Slot 189 lies at 7560 to 7600 px, above the view: the least
        // scroll that shows it puts it at the top.
        expect(laidOffset(tester), 7560);
        expect(await laidFrames(tester, 10), everyElement(7560.0));
        await tester.pumpAndSettle();

        expect(position.pixels, 7560);
        expect(shown(tester, 188), isTrue);
        expectKept(tester, 188, state, node: node);
        expect(_harness(tester).moves, [(188, 189)]);
      },
    );

    // A focus move through the traversal policy from the focused item a
    // fling carried out of view: the EndUser's Tab or an app's nextFocus()
    // (R66; main's ruling on the Task 26 review, Minor 3).
    final flingFocusMoves = ValueVariant<String>({'Tab', 'nextFocus()'});
    testWidgets(
      'R66: a <Tab, app nextFocus()> from the focused item a fling carried '
      "out of view, during the fling's momentum, stops the fling at once, "
      'brings the item back, then moves focus on as from the item in view',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        final state = _itemState(tester, 100)..expanded = true;
        await _focusItem(tester, 100);

        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -400),
          3000,
        );
        await tester.pump();
        final flung = position.pixels;
        await tester.pump(const Duration(milliseconds: 16));
        // The momentum still runs once the EndUser let go, item 100 held
        // with its focus past the cache band, where its rect reads NaN, so
        // the focus move brings it back first (R40, invariant 21).
        expect(position.pixels, greaterThan(flung));
        expect(state.node.rect.isFinite, isFalse);

        final atMove = position.pixels;
        if (flingFocusMoves.currentValue == 'Tab') {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        } else {
          state.node.nextFocus();
        }
        // The fling stops at the move: no frame lays out past it.
        await tester.pump();
        expect(laidOffset(tester), lessThanOrEqualTo(atMove));
        await tester.pump();
        expect(laidOffset(tester), 4000);
        expect(await laidFrames(tester, 10), everyElement(4000.0));
        await tester.pumpAndSettle();

        // The bring-back shows item 100 by the least scroll from above, at
        // 4000 px, where item 101 already shows: focus moves on with no
        // further scroll.
        expect(position.pixels, 4000);
        expect(shown(tester, 100), isTrue);
        expect(shown(tester, 101), isTrue);
        expect(
          FocusManager.instance.primaryFocus,
          same(_itemState(tester, 101).node),
        );
        expectKept(tester, 100, state);
      },
      variant: flingFocusMoves,
    );

    testWidgets(
      'R66: an app moveItem of the focused item during the momentum of an '
      'EndUser fling stops nothing: the fling runs on, and the item stays '
      'parked with its State and focus',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(count: 200, itemsController: ReorderableItemsController()),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -100),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final atCall = position.pixels;

        _harness(tester).move(100, 101);
        // An app's input never stops the EndUser's scroll: each frame lays
        // the momentum out further.
        final laid = await laidFrames(tester, 5);
        expect(laid.first, greaterThan(atCall));
        expect([...laid]..sort(), laid);
        expect(laid.toSet(), hasLength(5));
        await tester.pumpAndSettle();

        expect(position.pixels, greaterThan(laid.last));
        expectParked(tester, 100, state, node);
      },
    );

    testWidgets(
      'R66: an Alt+Down during the momentum of a trackpad fling, with a '
      'mouse button held on an item, stops the fling and reveals the moved '
      'item: a mouse holds no drag of the list',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          const _Harness(count: 200),
        );
        final state = _itemState(tester, 100)..expanded = true;
        final node = await _focusItem(tester, 100);

        await tester.trackpadFling(
          find.byType(Scrollable).first,
          const Offset(0, -100),
          1000,
        );
        await tester.pump();
        final flung = position.pixels;
        await tester.pump(const Duration(milliseconds: 16));
        expect(position.pixels, greaterThan(flung));
        expect(shown(tester, 100), isFalse);

        // Under the default drag devices a mouse never drags the list, so
        // its button held on an item holds no drag of it.
        final mouse = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey(105))),
          kind: PointerDeviceKind.mouse,
        );
        await _altNow(tester, LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.pump();
        // Slot 101 lies at 4040 to 4080 px, above the view: the least
        // scroll that shows it puts it at the top.
        expect(laidOffset(tester), 4040);
        expect(await laidFrames(tester, 10), everyElement(4040.0));
        await mouse.cancel();
        await tester.pumpAndSettle();

        expect(position.pixels, 4040);
        expect(shown(tester, 100), isTrue);
        expectKept(tester, 100, state, node: node);
        expect(_harness(tester).moves, [(100, 101)]);
      },
    );
  });

  group('ReorderableListViewLayout reduced motion', () {
    final motion = ValueVariant<String>({'no', 'app', 'platform'});

    testWidgets(
      'NFR-U03, fo06/us11/fr01/e09, and s03/inv59: a neighbor a drag passes '
      'takes its slot at once only under reduced motion',
      (tester) async {
        if (motion.currentValue == 'platform') {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await tester.pumpWidget(
          motion.currentValue == 'app'
              ? _app(
                  Builder(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: const _Harness(count: 5),
                    ),
                  ),
                )
              : _app(const _Harness(count: 5)),
        );

        final gesture = await _liftItem(tester, 0);
        await _dragPastNeighbor(tester, gesture);

        if (motion.currentValue == 'no') {
          expect(_top(tester, 1), allOf(greaterThan(0), lessThan(40)));
        } else {
          expect(_top(tester, 1), 0);
        }

        await gesture.up();
        await tester.pumpAndSettle();
      },
      variant: motion,
    );

    testWidgets(
      'NFR-U03, fo06/us11/fr01/e09, and s03/inv59: a dropped item settles at '
      'once only under reduced motion',
      (tester) async {
        if (motion.currentValue == 'platform') {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await tester.pumpWidget(
          motion.currentValue == 'app'
              ? _app(
                  Builder(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: const _Harness(count: 5),
                    ),
                  ),
                )
              : _app(const _Harness(count: 5)),
        );

        final gesture = await _liftItem(tester, 0);
        await _dragPastNeighbor(tester, gesture);
        await tester.pumpAndSettle();

        await gesture.up();
        await tester.pump();
        // `onReorderEnd` always fires at once (FR-04 E06, `_endDrag`), so it
        // cannot tell reduced motion from plain; the drop's own settle, over
        // the theme's normal level, ticked on the same seamed State as the
        // gap reflow, only lands `onReorderItem` (`moves`) once it ends.
        expect(
          _harness(tester).moves,
          motion.currentValue == 'no' ? isEmpty : [(0, 1)],
        );

        await tester.pumpAndSettle();
        expect(_harness(tester).ends, isNotEmpty);
        expect(_harness(tester).moves, [(0, 1)]);
      },
      variant: motion,
    );

    testWidgets(
      'NFR-U03 and fo06/us11/fr04/e01 (D4): turning reduced motion on and off '
      'keeps a kept-alive item that holds its own semantics boundary, with '
      'its State and no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        Widget host({required bool reduced}) => _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: const _Harness(
                count: 200,
                keepAliveIds: {100},
                boundaryAt: 100,
                boundary: _nestedListBoundary,
              ),
            ),
          ),
        );
        await tester.pumpWidget(host(reduced: false));
        final position =
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
              ..jumpTo(4000);
        await tester.pump();
        final state = _itemState(tester, 100)..expanded = true;
        position.jumpTo(0);
        await tester.pump();

        for (final reduced in [true, false]) {
          await tester.pumpWidget(host(reduced: reduced));
          expect(tester.takeException(), isNull);
          expect(_statesOf(tester, 100), [same(state)]);
        }
        position.jumpTo(4000);
        await tester.pump();

        expect(_statesOf(tester, 100), [same(state)]);
        expect(state.expanded, isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'matrix I01xT03 and fo06/us11/fr01/e10 (R52): a drag that starts while a '
      'drop settles completes the drop at once, then lifts the new item',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 5, handles: true)));
        final harness = _harness(tester);
        final first = await _grabHandle(tester, 0);
        await _dragPastNeighbor(tester, first);
        await tester.pumpAndSettle();
        await first.up();
        await tester.pump();
        expect(harness.moves, isEmpty);
        expect(harness.ends, hasLength(1));

        final second = await _grabHandle(tester, 3, pointer: 2);

        expect(harness.moves, [(0, 1)]);
        expect(harness.ends, hasLength(1));
        expect(harness.starts, [0, 3]);
        await second.up();
        await tester.pumpAndSettle();
        expect(harness.ends, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ReorderableListViewLayout accessibility gate', () {
    // NFR-U01 n/a: the list draws no text and owns no tap target; its own
    // node takes focus only, and each item's node carries move actions,
    // not a tap; the app's items own their text and taps.
    // NFR-U05 n/a: the list's own stop takes no pointer tap, the drag
    // handle is the app's (FR-01 E01), and the long-press target is the
    // app's item.
    // NFR-E01, NFR-E02 n/a: a FO-06 layout primitive, not a component (the
    // reason container_layout_builder_test.dart gives, D12).

    void useTraditionalHighlight() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
    }

    /// The color of the ring the list's [StratumFocusBorder] paints, the
    /// `#drawDRRect` under the `DecoratedBox` below it, as `_painted` in
    /// `focus_border_test.dart` reads it.
    Color ringColor(WidgetTester tester) {
      late Color color;
      expect(
        tester.renderObject(
          find
              .descendant(
                of: find.byType(StratumFocusBorder),
                matching: find.byType(DecoratedBox),
              )
              .first,
        ),
        paints..something((method, arguments) {
          if (method != #drawDRRect) return false;
          color = (arguments[2] as Paint).color;
          return true;
        }),
      );
      return color;
    }

    /// The WCAG 1.4.11 contrast ratio between [a] and [b].
    double contrast(Color a, Color b) {
      final luminanceA = a.computeLuminance();
      final luminanceB = b.computeLuminance();
      return (math.max(luminanceA, luminanceB) + 0.05) /
          (math.min(luminanceA, luminanceB) + 0.05);
    }

    /// [child] under the package default's high-contrast theme of
    /// [themeMode], light by default, under a [MaterialApp] so the list finds
    /// an overlay.
    Widget highContrastHost(
      Widget child, {
      ThemeMode themeMode = ThemeMode.light,
    }) => MaterialApp(
      home: Material(
        child: StratumThemeApplication(
          themes: defaultThemeSet,
          themeMode: themeMode,
          highContrast: StratumHighContrastMode.on,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: child),
          ),
        ),
      ),
    );

    testWidgets('NFR-U02: Tab reaches the list and changes its look', (
      tester,
    ) async {
      useTraditionalHighlight();
      final before = FocusNode();
      addTearDown(before.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Focus(
                focusNode: before,
                child: const SizedBox(width: 40, height: 20),
              ),
              const Expanded(child: _Harness(count: 50, focusable: true)),
            ],
          ),
        ),
      );
      before.requestFocus();
      await tester.pump();
      final idle = ringColor(tester);
      expect(idle.a, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringColor(tester), isNot(isSameColorAs(idle)));
    });

    testWidgets(
      'NFR-U02 (D4): an item at rest whose StratumInkWell paints its focus '
      'ring outside its box sits under no clip of the list',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const _Harness(count: 5, boundaryAt: 2, boundary: _inkWellBoundary),
          ),
        );

        var child = tester.renderObject(find.byKey(const ValueKey(2)));
        final clips = <String>[];
        for (
          var parent = child.parent;
          parent != null && parent is! RenderSliverMultiBoxAdaptor;
          parent = parent.parent
        ) {
          if (parent.describeApproximatePaintClip(child) != null) {
            clips.add('${parent.runtimeType}');
          }
          child = parent;
        }
        expect(clips, isEmpty);
      },
    );

    final insertMotion = ValueVariant<String>({'no', 'app', 'platform'});
    testWidgets(
      'NFR-U03: with <no, app, platform> reduced motion one frame after '
      'an insert the new item <still grows, takes its size> and its '
      'fade still runs',
      (tester) async {
        final reduced = insertMotion.currentValue != 'no';
        if (insertMotion.currentValue == 'platform') {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final controller = ReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: insertMotion.currentValue == 'app',
                ),
                child: _Harness(count: 5, itemsController: controller),
              ),
            ),
            theme: theme,
          ),
        );

        _harness(tester).insert(1, 9);
        await tester.pump();
        final gap = _offsetBetween(tester, 0, 1);
        reduced ? expect(gap, 80) : expect(gap, lessThan(80));

        await tester.pump(_halfForward(theme));
        expect(_enteringOpacity(tester, 9), allOf(greaterThan(0), lessThan(1)));
      },
      variant: insertMotion,
    );

    testWidgets('NFR-U04: twice the text size shows no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: const _Harness(count: 20),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'NFR-U06: the list node reads its label, count, and focus state, '
      'and an item reads its child with its valid move actions',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            const _Harness(count: 5, focusable: true, semanticsLabel: 'Tasks'),
          ),
        );

        expect(
          tester.getSemantics(find.bySemanticsLabel('Tasks')),
          matchesSemantics(
            label: 'Tasks',
            isFocusable: true,
            hasFocusAction: true,
          ),
        );
        final scrollNode = find.semantics
            .byFlag(SemanticsFlag.hasImplicitScrolling)
            .evaluate()
            .single;
        expect(scrollNode.scrollChildCount, 5);
        expect(
          tester.getSemantics(find.byKey(const ValueKey(0))),
          matchesSemantics(
            label: '0',
            isFocusable: true,
            hasFocusAction: true,
            customActions: const [
              CustomSemanticsAction(label: 'Move down'),
              CustomSemanticsAction(label: 'Move to the end'),
            ],
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'NFR-U07 exception: an app-wide StratumFocusBorder style replaces '
      'the list ring color',
      (tester) async {
        useTraditionalHighlight();
        final before = FocusNode();
        addTearDown(before.dispose);
        await tester.pumpWidget(
          _app(
            StratumComponentDefaults(
              styles: const {},
              parts: const {
                StratumFocusBorder: StratumFocusBorderStyle(
                  color: WidgetStatePropertyAll(Color(0xFF2563EB)),
                ),
              },
              child: Column(
                children: [
                  Focus(
                    focusNode: before,
                    child: const SizedBox(width: 40, height: 20),
                  ),
                  const Expanded(child: _Harness(count: 5, focusable: true)),
                ],
              ),
            ),
          ),
        );
        before.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        expect(ringColor(tester), isSameColorAs(const Color(0xFF2563EB)));
      },
    );

    final ringModes = ValueVariant<ThemeMode>({
      ThemeMode.light,
      ThemeMode.dark,
    });
    testWidgets(
      'NFR-U07: under high contrast, light and dark, the list ring holds 3:1 '
      'on the page and on a surface',
      (tester) async {
        useTraditionalHighlight();
        final mode = ringModes.currentValue!;
        await tester.pumpWidget(
          highContrastHost(
            const _Harness(count: 20, focusable: true),
            themeMode: mode,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        final dark = mode == ThemeMode.dark;
        final highContrast =
            (dark
                    ? defaultThemeSet.highContrastDark!
                    : defaultThemeSet.highContrastLight!)
                .color;
        final ring = highContrast.border.subtle.blue;
        // palette.blue.600 in light, palette.blue.400 in dark (D31).
        expect(
          ring,
          isSameColorAs(
            dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          ),
        );
        expect(ringColor(tester), isSameColorAs(ring));
        final backgrounds = highContrast.background.defaults;
        for (final background in [backgrounds.normal, backgrounds.surface]) {
          expect(contrast(ring, background), greaterThanOrEqualTo(3));
        }
      },
      variant: ringModes,
    );

    testWidgets(
      'NFR-U08: the focused list shows its ring shape under high contrast',
      (tester) async {
        useTraditionalHighlight();
        await tester.pumpWidget(
          highContrastHost(const _Harness(count: 20, focusable: true)),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        expect(ringColor(tester).a, greaterThan(0));
      },
    );

    testWidgets(
      'NFR-U08: under high contrast a lifted item still shows its place '
      'under the pointer, drawn over the list',
      (tester) async {
        await tester.pumpWidget(highContrastHost(const _Harness(count: 5)));
        final start = tester.getCenter(find.text('0'));
        final topLeft = tester.getTopLeft(find.byKey(const ValueKey(0)));

        final gesture = await tester.startGesture(start);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await tester.pump();

        // R49: the drag proxy floats a raster of the item in the overlay,
        // outside the list's own tree, under the pointer.
        final lifted = find.byType(RawImage);
        expect(lifted, findsOne);
        expect(
          find.ancestor(
            of: lifted,
            matching: find.byType(ReorderableListViewLayout),
          ),
          findsNothing,
        );
        expect(tester.getTopLeft(lifted), topLeft + const Offset(0, 30));
        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'matrix I01xT08 and I03xT08, fo06/us11/fr04/e14: a lift of the item a '
      'leaving item is drawn beside ends that leaving item at once, and the '
      'drop finds none',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              handles: true,
              itemsController: ReorderableItemsController(),
            ),
          ),
        );
        final harness = _harness(tester)..remove(2);
        await tester.pump();
        final leaving = find.byKey(const ValueKey(2), skipOffstage: false);
        expect(leaving, findsOne);

        final gesture = await _grabHandle(tester, 3);
        expect(leaving, findsNothing);
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(leaving, findsNothing);
        expect(harness.ends, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'matrix I01xT07 and fo06/us11/fr01/e10: a drag that starts on an item still '
      'growing in ends its grow-in at once, and the item lifts at full size',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              handles: true,
              itemsController: ReorderableItemsController(),
            ),
            theme: _normalTheme(const Duration(seconds: 2)),
          ),
        );
        _harness(tester).insert(1, 9);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(_offsetBetween(tester, 0, 1), lessThan(80));

        final gesture = await _grabHandle(tester, 9);

        expect(_runningTransitions(tester), isEmpty);
        expect(_offsetBetween(tester, 0, 1), 80);
        // The proxy shows the item at its full 40 px, box and raster alike,
        // though the grab landed on a slot grown only partway: the lift
        // reads the boundary below the grow-in (D5).
        final proxy = tester.widget<RawImage>(find.byType(RawImage));
        final pixelRatio = tester.view.devicePixelRatio;
        expect(tester.getSize(find.byType(RawImage)).height, 40);
        expect(proxy.image!.height / pixelRatio, 40);

        // The drag opens a gap of the item's full slot, as from rest: the
        // frame after the lift lays that slot out at full size.
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(seconds: 3));
        expect(_offsetBetween(tester, 0, 1), 40);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_harness(tester).moves, [(1, 3)]);
      },
    );

    testWidgets(
      "invariant 30: a lift ends the item's own grow-in through the file's "
      'own ending path, so a later build reads it at rest, never a '
      'leftover entry',
      (tester) async {
        Animation<double>? incoming;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              handles: true,
              itemsController: ReorderableItemsController(),
              itemTransitionBuilder: (context, animation, child) {
                // R48: the builder wraps every item, at rest with a
                // completed animation; the entering or leaving one runs.
                if (animation != kAlwaysCompleteAnimation) incoming = animation;
                return FadeTransition(opacity: animation, child: child);
              },
            ),
            theme: _normalTheme(const Duration(seconds: 2)),
          ),
        );
        _harness(tester).insert(1, 9);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(incoming, isNotNull);

        final gesture = await _grabHandle(tester, 9);
        incoming = null;
        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          incoming,
          isNull,
          reason:
              "a lift ends the item's own grow-in through _finishInsert, so "
              'a later build of it reads the default kAlwaysCompleteAnimation, '
              'never the incoming entry the lift only froze in place',
        );
        expect(tester.takeException(), isNull);
      },
    );

    final starters = ValueVariant<String>({'long press', 'handle'});
    testWidgets(
      'matrix I01xT15 and fo06/us11/fr01/e12: a <long press, handle drag> on an '
      'item whose text field holds focus <leaves the item in place, lifts it>',
      (tester) async {
        final field = FocusNode();
        addTearDown(field.dispose);
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              handles: true,
              boundaryAt: 1,
              boundary: (child) => Row(
                children: [
                  child,
                  SizedBox(
                    width: 100,
                    height: 40,
                    child: TextField(focusNode: field),
                  ),
                ],
              ),
            ),
          ),
        );
        field.requestFocus();
        await tester.pump();
        final harness = _harness(tester);

        if (starters.currentValue == 'long press') {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(TextField)),
          );
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 50),
          );
          await gesture.moveBy(const Offset(0, 40));
          await tester.pump();
          expect(harness.starts, isEmpty);
          await gesture.up();
        } else {
          final gesture = await _grabHandle(tester, 1);
          expect(harness.starts, [1]);
          await gesture.up();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(field.hasPrimaryFocus, isTrue);
      },
      variant: starters,
    );

    testWidgets(
      'matrix I01xT15 and fo06/us11/fr01/e12: a long press on a focused '
      'EditableText with no long-press recognizer of its own still leaves '
      'the item in place, never starting a drag',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final field = FocusNode();
        addTearDown(field.dispose);
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 5,
              handles: true,
              boundaryAt: 1,
              boundary: (child) => Row(
                children: [
                  child,
                  SizedBox(
                    width: 100,
                    height: 40,
                    // A bare EditableText, unlike TextField, arms no
                    // recognizer of its own (no TextSelectionGestureDetector),
                    // so only this guard keeps the item's own long press
                    // from winning the arena here.
                    child: EditableText(
                      controller: controller,
                      focusNode: field,
                      style: const TextStyle(),
                      cursorColor: _red,
                      backgroundCursorColor: _red,
                      // RenderEditable itself otherwise arms its own
                      // _tap/_longPress on every pointer down (SDK
                      // rendering/editable.dart's handleEvent), which wins
                      // this arena first regardless of the guard; this is
                      // the one switch that leaves a focused field with
                      // truly no long-press recognizer of its own.
                      rendererIgnoresPointer: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        field.requestFocus();
        await tester.pump();
        final harness = _harness(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(EditableText)),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(harness.starts, isEmpty);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(field.hasPrimaryFocus, isTrue);
      },
    );

    group('item root (s03/inv81)', () {
      // Item root Build Gate rows: NFR-U02, NFR-U05, NFR-U06, NFR-U08, and
      // NFR-U09 below. NFR-U01 and NFR-U07 n/a: the join paints nothing; the
      // surface's overlay and ring tokens are US-04 FR-01's and FR-03's,
      // unchanged. NFR-U03 n/a: the join runs no animation; it moves semantics
      // flags between nodes only. NFR-U04 n/a: the join adds and resizes no
      // text; the row's text is the caller's child. NFR-E01 and NFR-E02 n/a:
      // semantics-only change, no look or style changes.

      tearDown(() {
        _rootLog.clear();
        _RootListState.ids = [0, 1, 2, 3, 4];
      });

      testWidgets(
        'NFR-U06, fo06/us04/fr02/e11, fo06/us11/fr03/e03: a root row reads '
        'its label, button role, enabled state, tap, and moves on one node',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            _rootApp(
              _RootList(
                item: (id) => ContainerLayout(
                  interaction: const Interaction(onTap: _tapRow),
                  child: Text('Item $id'),
                ),
              ),
            ),
          );
          final node = _rootNode(tester, 'Item 2');
          expect(
            node,
            isSemantics(
              label: 'Item 2',
              value: '',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
            ),
          );
          expect(_rootMoves(node.getSemanticsData()).toSet(), {
            'Move to the start',
            'Move up',
            'Move down',
            'Move to the end',
          });
          handle.dispose();
        },
      );

      testWidgets(
        'NFR-U02, fo06/us04/fr02/e11: Tab reaches a root row, its ring '
        'shows, Enter taps it, and Alt+Up moves it with focus on its one '
        'node',
        (tester) async {
          useTraditionalHighlight();
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            _rootApp(
              _RootList(
                item: (id) => ContainerLayout(
                  interaction: const Interaction(onTap: _tapRow),
                  child: Text('Item $id'),
                ),
              ),
            ),
          );
          for (var i = 0; i < 8; i++) {
            if (Focus.of(tester.element(find.text('Item 2'))).hasPrimaryFocus) {
              break;
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          expect(
            Focus.of(tester.element(find.text('Item 2'))).hasPrimaryFocus,
            isTrue,
          );
          expect(
            tester
                .widget<StratumFocusBorder>(
                  find.descendant(
                    of: find.byKey(const ValueKey(2)),
                    matching: find.byType(StratumFocusBorder),
                  ),
                )
                .state,
            FullWidgetState.focused,
          );
          expect(
            _rootNode(tester, 'Item 2'),
            isSemantics(label: 'Item 2', isFocused: true),
          );
          expect(
            _rootMoves(_rootNode(tester, 'Item 2').getSemanticsData()),
            hasLength(4),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(_rootLog, ['row']);
          // F14: Space, not only Enter, runs the row's tap.
          _rootLog.clear();
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump();
          expect(_rootLog, ['row']);

          expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isTrue);
          expect(_rootIds(tester), [0, 2, 1, 3, 4]);
          expect(
            _rootNode(tester, 'Item 2'),
            isSemantics(label: 'Item 2', isFocused: true),
          );
          expect(
            _rootMoves(_rootNode(tester, 'Item 2').getSemanticsData()),
            hasLength(4),
          );
          handle.dispose();
        },
      );

      testWidgets(
        "NFR-U09, fo06/us11/fr03/e03: the move actions on a root row's "
        'labeled node move it with no drag',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            _rootApp(
              _RootList(
                item: (id) => ContainerLayout(
                  interaction: const Interaction(onTap: _tapRow),
                  child: Text('Item $id'),
                ),
              ),
            ),
          );
          _rootMove(_rootNode(tester, 'Item 2'), 'Move down');
          await tester.pumpAndSettle();
          expect(_rootIds(tester), [0, 1, 3, 2, 4]);
          _rootMove(_rootNode(tester, 'Item 2'), 'Move to the start');
          await tester.pumpAndSettle();
          expect(_rootIds(tester), [2, 0, 1, 3, 4]);
          handle.dispose();
        },
      );

      testWidgets(
        'NFR-U05, fo06/us04/fr02/e11: joining moves no hit area: root rows '
        'meet the platform tap target and a tap at a row runs it',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            _rootApp(
              _RootList(
                item: (id) => ContainerLayout(
                  interaction: const Interaction(onTap: _tapRow),
                  child: Text('Item $id'),
                ),
              ),
            ),
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await tester.tap(find.text('Item 2'));
          await tester.pump();
          expect(_rootLog, ['row']);
          handle.dispose();
        },
      );

      testWidgets(
        'NFR-U08, fo06/us04/fr02/e11, fo08/us07/fr03: under high contrast a '
        'disabled root reads dimmed on the item node and keeps its named '
        'moves',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            highContrastHost(
              SizedBox(
                width: 300,
                height: 600,
                child: _RootList(
                  item: (id) => switch (id) {
                    2 => StratumInkWell(
                      onTap: _tapRow,
                      disabled: true,
                      child: Text('Item $id'),
                    ),
                    3 => _Tile(
                      disabled: true,
                      child: StratumInkWell(
                        onTap: _tapRow,
                        child: Text('Item $id'),
                      ),
                    ),
                    _ => StratumInkWell(
                      onTap: _tapRow,
                      child: Text('Item $id'),
                    ),
                  },
                ),
              ),
            ),
          );
          for (final label in ['Item 2', 'Item 3']) {
            final node = _rootNode(tester, label);
            expect(
              node,
              isSemantics(
                label: label,
                isButton: true,
                hasEnabledState: true,
                isEnabled: false,
              ),
            );
            expect(_rootMoves(node.getSemanticsData()).toSet(), {
              'Move to the start',
              'Move up',
              'Move down',
              'Move to the end',
            });
          }
          handle.dispose();
        },
      );
    });
  });

  group('ReorderableListViewLayout item root (s03/inv81)', () {
    tearDown(() {
      _rootLog.clear();
      _tileDisabled.value = true;
      _rowDisabled.value = false;
      _rowLabel.value = 'Item 2';
      _extra.value = false;
      _rootShape.value = 0;
      _RootListState.ids = [0, 1, 2, 3, 4];
    });

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R1 a root '
        'StratumInkWell joins the item node', (tester) async {
      final handle = tester.ensureSemantics();
      await _expectJoined(
        tester,
        (id) => StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
      );
      handle.dispose();
    });

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R2 a root '
        'ContainerLayout interaction joins', (tester) async {
      final handle = tester.ensureSemantics();
      await _expectJoined(
        tester,
        (id) => ContainerLayout(
          interaction: const Interaction(onTap: _tapRow),
          child: Text('Item $id'),
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R3 a root row '
      'joins and its delete keeps its own node',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _expectJoined(
          tester,
          (id) => ContainerLayout(
            interaction: const Interaction(onTap: _tapRow),
            child: _row(id),
          ),
        );
        final item2 = _rootNode(tester, 'Item 2');
        final delete2 = _rootNode(tester, 'Delete 2');
        expect(identical(item2, delete2), isFalse);
        expect(
          _shape(delete2),
          'label=Delete 2 tap=true button=true enabled=isTrue moves=0',
        );
        // F5: the delete tap never sees the row's own tap in its log.
        _rootLog.clear();
        await tester.tap(find.text('Delete 2'));
        await tester.pump();
        expect(_rootLog, ['delete']);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R4 a row with no '
      'root tap keeps its moves on its label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _expectJoined(
          tester,
          _row,
          expected:
              'label=Item 2 tap=false button=false enabled=none '
              'moves=4',
        );
        expect(
          _shape(_rootNode(tester, 'Delete 2')),
          'label=Delete 2 tap=true button=true enabled=isTrue moves=0',
        );
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R5a a root '
        'inside a Dismissible at rest joins', (tester) async {
      final handle = tester.ensureSemantics();
      await _expectJoined(
        tester,
        (id) => Dismissible(
          key: ValueKey('d$id'),
          child: StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
        ),
      );
      handle.dispose();
    });

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R5b a root '
        'inside Padding joins', (tester) async {
      final handle = tester.ensureSemantics();
      await _expectJoined(
        tester,
        (id) => Padding(
          padding: const EdgeInsets.all(4),
          child: StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R6i a sibling '
      'from the first build keeps the surface apart',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _expectJoined(
          tester,
          (id) => id == 2
              ? const ColumnLayout(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StratumInkWell(onTap: _tapRow, child: Text('Item 2')),
                    Text('Extra'),
                  ],
                )
              : Text('Item $id'),
          expected: _own,
        );
        expect(
          _rootMoves(_rootNode(tester, 'Extra').getSemanticsData()),
          hasLength(4),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R7 a disabled '
      'root reads dimmed with its moves and no tap',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _expectJoined(
          tester,
          (id) => StratumInkWell(
            onTap: _tapRow,
            disabled: true,
            child: Text('Item $id'),
          ),
          expected:
              'label=Item 2 tap=false button=true enabled=isFalse '
              'moves=4',
        );
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R8 an app '
        'container node keeps the root apart', (tester) async {
      final handle = tester.ensureSemantics();
      await _expectJoined(
        tester,
        (id) => Semantics(
          container: true,
          child: StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
        ),
        expected: _own,
      );
      final parent = _rootNode(tester, 'Item 2').parent!;
      expect(
        _shape(parent),
        'label= tap=false button=false enabled=none moves=0',
      );
      expect(_rootMoves(parent.parent!.getSemanticsData()), hasLength(4));
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R9 a surface '
      'outside any reorder list keeps its own node',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _rootApp(
            Semantics(
              container: true,
              label: 'Host',
              child: const StratumInkWell(onTap: _tapRow, child: Text('Solo')),
            ),
          ),
        );
        final solo = _rootNode(tester, 'Solo');
        expect(
          _shape(solo),
          'label=Solo tap=true button=true enabled=isTrue moves=0',
        );
        expect(solo.parent!.getSemanticsData().label, 'Host');
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: R10 a root with '
      'onSecondaryTap keeps its own node (D6(a))',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _expectJoined(
          tester,
          (id) => StratumInkWell(
            onTap: _tapRow,
            onSecondaryTap: () {},
            child: Text('Item $id'),
          ),
          expected: _own,
        );
        expect(
          _rootMoves(_rootNode(tester, 'Item 2').parent!.getSemanticsData()),
          hasLength(4),
        );
        handle.dispose();
      },
    );

    testWidgets(
      "fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: in Flutter's own "
      'ReorderableListView a root keeps its own node (D6(c))',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _rootApp(
            ReorderableListView(
              onReorderItem: (_, _) {},
              children: [
                for (var id = 0; id < 5; id += 1)
                  StratumInkWell(
                    key: ValueKey(id),
                    onTap: _tapRow,
                    child: Text('Item $id'),
                  ),
              ],
            ),
          ),
        );
        expect(_shape(_rootNode(tester, 'Item 2')), _own);
        expect(
          _rootMoves(_rootNode(tester, 'Item 2').parent!.getSemanticsData()),
          hasLength(4),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo08/us07/fr03, fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: '
      'R11a a disabled base component over a root surface joins in every '
      'frame of a toggle',
      (tester) async {
        final handle = tester.ensureSemantics();
        const off =
            'label=Item 2 tap=false button=true enabled=isFalse '
            'moves=4';
        await tester.pumpWidget(
          _rootApp(
            _RootList(
              item: (id) => id == 2
                  ? ValueListenableBuilder<bool>(
                      valueListenable: _tileDisabled,
                      builder: (context, disabled, _) => _Tile(
                        disabled: disabled,
                        child: const StratumInkWell(
                          onTap: _tapRow,
                          child: Text('Item 2'),
                        ),
                      ),
                    )
                  : _Tile(
                      child: StratumInkWell(
                        onTap: _tapRow,
                        child: Text('Item $id'),
                      ),
                    ),
            ),
          ),
        );
        expect(_shape(_rootNode(tester, 'Item 2')), off);

        _tileDisabled.value = false;
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), _joined);
        // F13: the enabled frame's joined node still runs the row's tap.
        final enabledNode = _rootNode(tester, 'Item 2');
        _rootLog.clear();
        enabledNode.owner!.performAction(enabledNode.id, SemanticsAction.tap);
        await tester.pump();
        expect(_rootLog, ['row']);

        _tileDisabled.value = true;
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), off);
        _rootMove(_rootNode(tester, 'Item 2'), 'Move up');
        await tester.pumpAndSettle();
        expect(_rootIds(tester), [0, 2, 1, 3, 4]);
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: a caller '
        'semantics label reads on the joined node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _rootApp(
          _RootList(
            item: (id) => id == 2
                ? const ContainerLayout(
                    semantics: SemanticsProperties(label: 'Row 2'),
                    interaction: Interaction(onTap: _tapRow),
                    child: SizedBox(width: 20, height: 20),
                  )
                : Text('Item $id'),
          ),
        ),
      );
      final node = tester.getSemantics(find.byKey(const ValueKey(2)));
      expect(
        node,
        isSemantics(label: 'Row 2', isButton: true, hasTapAction: true),
      );
      expect(_rootMoves(node.getSemanticsData()), hasLength(4));
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: disable and '
      'relabel a root row at run time',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _expectJoined(
          tester,
          (id) => id == 2
              ? ValueListenableBuilder<bool>(
                  valueListenable: _rowDisabled,
                  builder: (context, disabled, _) => ContainerLayout(
                    interaction: Interaction(
                      onTap: _tapRow,
                      disabled: disabled,
                    ),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _rowLabel,
                      builder: (context, label, _) => Text(label),
                    ),
                  ),
                )
              : ContainerLayout(
                  interaction: const Interaction(onTap: _tapRow),
                  child: Text('Item $id'),
                ),
        );

        _rowLabel.value = 'Item 2b';
        await tester.pump();
        // F6: the relabel is read by its new text.
        expect(
          _shape(_rootNode(tester, 'Item 2b')),
          'label=Item 2b tap=true button=true enabled=isTrue moves=4',
        );

        _rowDisabled.value = true;
        await tester.pump();
        expect(
          _shape(_rootNode(tester, 'Item 2b')),
          'label=Item 2b tap=false button=true enabled=isFalse moves=4',
        );

        _rowDisabled.value = false;
        await tester.pump();
        expect(
          _shape(_rootNode(tester, 'Item 2b')),
          'label=Item 2b tap=true button=true enabled=isTrue moves=4',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: a horizontal '
      'list names the moves left and right',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _rootApp(
            _RootList(
              scrollDirection: Axis.horizontal,
              item: (id) =>
                  StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
            ),
          ),
        );
        final node = _rootNode(tester, 'Item 2');
        expect(
          node,
          isSemantics(label: 'Item 2', isButton: true, hasTapAction: true),
        );
        expect(_rootMoves(node.getSemanticsData()).toSet(), {
          'Move to the start',
          'Move left',
          'Move right',
          'Move to the end',
        });
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, fo06/us11/fr03/e03, fo08/us07/fr03/e04, s03/inv81: '
      'R11b a disabled base component with no tap surface at the item root '
      'joins the item node in every frame of a toggle',
      (tester) async {
        final handle = tester.ensureSemantics();
        const off =
            'label=Item 2 tap=false button=false enabled=isFalse moves=4';
        const on = 'label=Item 2 tap=false button=false enabled=none moves=4';
        await tester.pumpWidget(
          _rootApp(
            _RootList(
              item: (id) => id == 2
                  ? ValueListenableBuilder<bool>(
                      valueListenable: _tileDisabled,
                      builder: (context, disabled, _) =>
                          _Tile(disabled: disabled, child: _row(id)),
                    )
                  : _row(id),
            ),
          ),
        );
        expect(_shape(_rootNode(tester, 'Item 2')), off);
        expect(
          _shape(_rootNode(tester, 'Delete 2')),
          'label=Delete 2 tap=false button=true enabled=isFalse moves=0',
        );
        // FR-03 E04: the flag sits on the item's node, never on the list's.
        for (
          var node = _rootNode(tester, 'Item 2').parent;
          node != null;
          node = node.parent
        ) {
          expect(
            node.getSemanticsData().flagsCollection.isEnabled.name,
            'none',
          );
        }

        _tileDisabled.value = false;
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), on);
        expect(
          _shape(_rootNode(tester, 'Delete 2')),
          'label=Delete 2 tap=true button=true enabled=isTrue moves=0',
        );

        _tileDisabled.value = true;
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), off);
        _rootMove(_rootNode(tester, 'Item 2'), 'Move up');
        await tester.pumpAndSettle();
        expect(_rootIds(tester), [0, 2, 1, 3, 4]);
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e11, s03/inv81: R6c a sibling beside a const '
        'surface flips the join within one frame', (tester) async {
      final handle = tester.ensureSemantics();
      Widget item(int id) =>
          id == 2 ? const _Sibling(surface: _constSurface) : Text('Item $id');
      await expectFlips(tester, item);
      handle.dispose();
    });

    testWidgets('fo06/us04/fr02/e11, s03/inv81: R6f a sibling beside a fresh '
        'surface flips the join within one frame', (tester) async {
      final handle = tester.ensureSemantics();
      Widget item(int id) => id == 2
          ? _Sibling(
              surface: () =>
                  StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
            )
          : Text('Item $id');
      await expectFlips(tester, item);
      handle.dispose();
    });

    testWidgets('fo06/us04/fr02/e11, s03/inv81: R6c2 a const surface read two '
        'frames after each change', (tester) async {
      final handle = tester.ensureSemantics();
      Widget item(int id) =>
          id == 2 ? const _Sibling(surface: _constSurface) : Text('Item $id');
      // F12: each shape still holds a frame later than R6c reads it, with
      // no further flip back.
      await expectFlips(tester, item, frames: 2);
      handle.dispose();
    });

    testWidgets('fo06/us04/fr02/e11, s03/inv81: R6d an inner control keeps its '
        'node id across each flip', (tester) async {
      final handle = tester.ensureSemantics();
      Widget item(int id) => id == 2
          ? _Sibling(
              surface: () => ContainerLayout(
                interaction: const Interaction(onTap: _tapRow),
                child: _row(2),
              ),
            )
          : Text('Item $id');
      await tester.pumpWidget(_rootApp(_RootList(item: item)));
      await tester.pump();
      final id0 = _rootNode(tester, 'Delete 2').id;
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);

      _extra.value = true;
      await tester.pump();
      expect(_rootNode(tester, 'Delete 2').id, id0);
      await tester.pump();
      expect(_rootNode(tester, 'Delete 2').id, id0);
      expect(_shape(_rootNode(tester, 'Item 2')), _own);

      _extra.value = false;
      await tester.pump();
      expect(_rootNode(tester, 'Delete 2').id, id0);
      await tester.pump();
      expect(_rootNode(tester, 'Delete 2').id, id0);
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);

      expect(
        _shape(_rootNode(tester, 'Delete 2')),
        'label=Delete 2 tap=true button=true enabled=isTrue moves=0',
      );
      handle.dispose();
    });

    testWidgets('fo06/us04/fr02/e11, s03/inv81: inside the one-frame window a '
        "tappable sibling's label may read with the row, and its tap "
        'never joins the row node', (tester) async {
      final handle = tester.ensureSemantics();
      Widget item(int id) => id == 2
          ? _Sibling(
              surface: _constSurface,
              extra: GestureDetector(
                onTap: _tapExtra,
                child: const Text('Extra'),
              ),
            )
          : Text('Item $id');
      await tester.pumpWidget(_rootApp(_RootList(item: item)));
      await tester.pump();
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);

      _extra.value = true;
      await tester.pump();
      final windowRow = _rootNode(tester, 'Item 2');
      expect(
        windowRow.getSemanticsData().label,
        anyOf('Item 2', 'Item 2\nExtra'),
      );
      final windowExtra = _rootNode(tester, 'Extra');
      expect(identical(windowRow, windowExtra), isFalse);
      _rootLog.clear();
      windowRow.owner!.performAction(windowRow.id, SemanticsAction.tap);
      windowExtra.owner!.performAction(windowExtra.id, SemanticsAction.tap);
      expect(_rootLog, ['row', 'extra']);

      await tester.pump();
      final itemNode = _rootNode(tester, 'Item 2');
      expect(_shape(itemNode), _own);
      final extraNode = itemNode.parent!;
      expect(identical(extraNode, itemNode), isFalse);
      // Self-verifying: the lookup must land on the node that actually
      // merged Extra's label, never pass on another ancestor.
      expect(extraNode.getSemanticsData().label, contains('Extra'));
      expect(_rootMoves(extraNode.getSemanticsData()), hasLength(4));
      _rootLog.clear();
      extraNode.owner!.performAction(extraNode.id, SemanticsAction.tap);
      expect(_rootLog, ['extra']);

      _extra.value = false;
      await tester.pump();
      await tester.pump();
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e11, s03/inv81: R5a a moving Dismissible reads as '
      'two stops and joins again at rest',
      (tester) async {
        final handle = tester.ensureSemantics();
        Widget item(int id) => id == 2
            ? const Dismissible(
                key: ValueKey('d2'),
                background: ColoredBox(color: _red),
                child: StratumInkWell(onTap: _tapRow, child: Text('Item 2')),
              )
            : StratumInkWell(onTap: _tapRow, child: Text('Item $id'));
        await tester.pumpWidget(_rootApp(_RootList(item: item)));
        expect(_shape(_rootNode(tester, 'Item 2')), _joined);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Item 2')),
        );
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), _own);
        expect(
          _rootMoves(_rootNode(tester, 'Item 2').parent!.getSemanticsData()),
          hasLength(4),
        );

        await gesture.up();
        await tester.pumpAndSettle();
        await tester.pump();
        // Limit tripwire, not a loosened pin: a Dismissible keeps its
        // background child after a snap-back
        // (`widgets/dismissible.dart:539-545@3.47.7`), so the row stays
        // split at rest; flips to `_joined` if Flutter rebuilds it; owner
        // ruling pending (D2, D6(e)).
        expect(_shape(_rootNode(tester, 'Item 2')), _own);
        handle.dispose();
      },
    );

    testWidgets(
      'fo08/us07/fr03, fo06/us04/fr02/e11, s03/inv81: a disabled base '
      'component at the root flips with its surface on a sibling add '
      'and remove',
      (tester) async {
        final handle = tester.ensureSemantics();
        const mount =
            'label=Item 2 tap=false button=true enabled=isFalse moves=4';
        const added =
            'label=Item 2 tap=false button=true enabled=isFalse moves=0';
        Widget item(int id) => id == 2
            ? _Sibling(
                surface: () => const _Tile(
                  disabled: true,
                  child: StratumInkWell(onTap: _tapRow, child: Text('Item 2')),
                ),
              )
            : Text('Item $id');
        await tester.pumpWidget(_rootApp(_RootList(item: item)));
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), mount);

        _extra.value = true;
        await tester.pump();
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), added);
        expect(
          _rootMoves(_rootNode(tester, 'Extra').getSemanticsData()),
          hasLength(4),
        );

        _extra.value = false;
        await tester.pump();
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), mount);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, s03/inv81: removing a root row exits with no '
      'assert and the rows beside it stay joined',
      (tester) async {
        final handle = tester.ensureSemantics();
        final itemsController = ReorderableItemsController();
        await tester.pumpWidget(
          _rootApp(
            _RootList(
              itemsController: itemsController,
              item: (id) =>
                  StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
            ),
          ),
        );
        tester.state<_RootListState>(find.byType(_RootList)).remove(2);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Item 2'), findsNothing);
        expect(
          _shape(_rootNode(tester, 'Item 3')),
          'label=Item 3 tap=true button=true enabled=isTrue moves=4',
        );
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: I1 a '
        'ReorderableListViewLayout nested inside a row of another one keeps '
        'the outer and inner rows each joined to their own item root', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final innerIds = [0, 1];
      Widget inner() => SizedBox(
        height: 60,
        child: ReorderableListViewLayout.builder(
          itemExtent: 24,
          itemCount: innerIds.length,
          onReorderItem: (from, to) =>
              innerIds.insert(to, innerIds.removeAt(from)),
          itemBuilder: (context, index) => KeyedSubtree(
            key: ValueKey('inner${innerIds[index]}'),
            child: StratumInkWell(
              onTap: _tapInner,
              child: Text('Inner ${innerIds[index]}'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        _rootApp(
          _RootList(
            item: (id) => id == 2
                ? StratumInkWell(
                    onTap: _tapRow,
                    child: ColumnLayout(
                      mainAxisSize: MainAxisSize.min,
                      children: [const Text('Item 2'), inner()],
                    ),
                  )
                : Text('Item $id'),
          ),
        ),
      );
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);
      expect(
        _rootNode(tester, 'Inner 0'),
        isSemantics(label: 'Inner 0', isButton: true, hasTapAction: true),
      );
      expect(
        _rootNode(tester, 'Inner 1'),
        isSemantics(label: 'Inner 1', isButton: true, hasTapAction: true),
      );
      _rootLog.clear();
      await tester.tap(find.text('Inner 0'));
      await tester.pump();
      expect(_rootLog, ['inner']);
      final rowNode = _rootNode(tester, 'Item 2');
      rowNode.owner!.performAction(rowNode.id, SemanticsAction.tap);
      await tester.pump();
      expect(_rootLog, ['inner', 'row']);
      handle.dispose();
    });

    testWidgets('fo08/us07/fr03, fo06/us04/fr02/e11, s03/inv81: M1 two stacked '
        'disabled layers over a root surface both hide and the outer '
        "layer's toggle still flips the surface", (tester) async {
      final handle = tester.ensureSemantics();
      const off = 'label=Item 2 tap=false button=true enabled=isFalse moves=4';
      await tester.pumpWidget(
        _rootApp(
          _RootList(
            item: (id) => id == 2
                ? ValueListenableBuilder<bool>(
                    valueListenable: _tileDisabled,
                    builder: (context, disabled, _) => _Tile(
                      disabled: disabled,
                      child: const _Tile(
                        disabled: false,
                        child: StratumInkWell(
                          onTap: _tapRow,
                          child: Text('Item 2'),
                        ),
                      ),
                    ),
                  )
                : _Tile(
                    child: StratumInkWell(
                      onTap: _tapRow,
                      child: Text('Item $id'),
                    ),
                  ),
          ),
        ),
      );
      expect(_shape(_rootNode(tester, 'Item 2')), off);

      _tileDisabled.value = false;
      await tester.pump();
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);
      final enabledNode = _rootNode(tester, 'Item 2');
      _rootLog.clear();
      enabledNode.owner!.performAction(enabledNode.id, SemanticsAction.tap);
      await tester.pump();
      expect(_rootLog, ['row']);

      _tileDisabled.value = true;
      await tester.pump();
      expect(_shape(_rootNode(tester, 'Item 2')), off);
      _rootMove(_rootNode(tester, 'Item 2'), 'Move up');
      await tester.pumpAndSettle();
      expect(_rootIds(tester), [0, 2, 1, 3, 4]);
      handle.dispose();
    });

    testWidgets(
      'fo06/us04/fr02/e11, s03/inv81: M2 removing a root row while its '
      'flip is still pending from the same frame throws no assert',
      (tester) async {
        final handle = tester.ensureSemantics();
        final itemsController = ReorderableItemsController();
        Widget item(int id) => id == 2
            ? const _Sibling(surface: _constSurface)
            : StratumInkWell(onTap: _tapRow, child: Text('Item $id'));
        await tester.pumpWidget(
          _rootApp(_RootList(itemsController: itemsController, item: item)),
        );
        // _Sibling's ValueListenableBuilder settles one frame after mount,
        // as expectFlips's own settle() already accounts for.
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), _joined);

        _extra.value = true;
        tester.state<_RootListState>(find.byType(_RootList)).remove(2);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Item 2'), findsNothing);
        expect(
          _shape(_rootNode(tester, 'Item 3')),
          'label=Item 3 tap=true button=true enabled=isTrue moves=4',
        );
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e11, fo06/us11/fr03/e03, s03/inv81: M3 a root '
        'surface that swaps widget type across a rebuild still joins once a '
        'surface is back', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _rootApp(
          _RootList(
            item: (id) => id == 2
                ? ValueListenableBuilder<int>(
                    valueListenable: _rootShape,
                    builder: (context, shape, _) => shape == 1
                        ? const Text('Item 2')
                        : const StratumInkWell(
                            onTap: _tapRow,
                            child: Text('Item 2'),
                          ),
                  )
                : Text('Item $id'),
          ),
        ),
      );
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);

      _rootShape.value = 1;
      await tester.pump();
      expect(
        _shape(_rootNode(tester, 'Item 2')),
        'label=Item 2 tap=false button=false enabled=none moves=4',
      );

      _rootShape.value = 2;
      await tester.pump();
      expect(_shape(_rootNode(tester, 'Item 2')), _joined);
      final node = _rootNode(tester, 'Item 2');
      _rootLog.clear();
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(_rootLog, ['row']);
      handle.dispose();
    });

    testWidgets('fo08/us07/fr03, s03/inv81: final review I1 a disabled base '
        'component over a root surface with only onHover reads disabled '
        'in every frame of a toggle', (tester) async {
      final handle = tester.ensureSemantics();
      const off = 'label=Item 2 tap=false button=false enabled=isFalse moves=4';
      const on = 'label=Item 2 tap=false button=false enabled=none moves=4';
      await tester.pumpWidget(
        _rootApp(
          _RootList(
            item: (id) => id == 2
                ? ValueListenableBuilder<bool>(
                    valueListenable: _tileDisabled,
                    builder: (context, disabled, _) => _Tile(
                      disabled: disabled,
                      child: ContainerLayout(
                        interaction: Interaction(onHover: (_) {}),
                        child: const Text('Item 2'),
                      ),
                    ),
                  )
                : _Tile(child: Text('Item $id')),
          ),
        ),
      );
      expect(_shape(_rootNode(tester, 'Item 2')), off);

      _tileDisabled.value = false;
      await tester.pump();
      expect(_shape(_rootNode(tester, 'Item 2')), on);

      _tileDisabled.value = true;
      await tester.pump();
      expect(_shape(_rootNode(tester, 'Item 2')), off);
      handle.dispose();
    });

    testWidgets('fo08/us07/fr03, s03/inv81: final review I1 a disabled base '
        'component over a root surface with only onFocusChange still reads '
        'disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _rootApp(
          _RootList(
            item: (id) => id == 2
                ? _Tile(
                    disabled: true,
                    child: ContainerLayout(
                      interaction: Interaction(onFocusChange: (_) {}),
                      child: const Text('Item 2'),
                    ),
                  )
                : _Tile(child: Text('Item $id')),
          ),
        ),
      );
      expect(
        _shape(_rootNode(tester, 'Item 2')),
        'label=Item 2 tap=false button=false enabled=isFalse moves=4',
      );
      handle.dispose();
    });

    testWidgets(
      'fo08/us07/fr03, s03/inv81: final review I3 R11a mounted before the '
      'screen reader turns on reads disabled once semantics turns on',
      (tester) async {
        await tester.pumpWidget(
          _rootApp(
            _RootList(
              item: (id) => id == 2
                  ? const _Tile(
                      disabled: true,
                      child: StratumInkWell(
                        onTap: _tapRow,
                        child: Text('Item 2'),
                      ),
                    )
                  : _Tile(
                      child: StratumInkWell(
                        onTap: _tapRow,
                        child: Text('Item $id'),
                      ),
                    ),
            ),
          ),
        );
        final handle = tester.ensureSemantics();
        await tester.pump();
        await tester.pump();
        expect(
          _shape(_rootNode(tester, 'Item 2')),
          'label=Item 2 tap=false button=true enabled=isFalse moves=4',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, s03/inv81: final review I3 R1 mounted before '
      'the screen reader turns on still joins once semantics turns on',
      (tester) async {
        await tester.pumpWidget(
          _rootApp(
            _RootList(
              item: (id) =>
                  StratumInkWell(onTap: _tapRow, child: Text('Item $id')),
            ),
          ),
        );
        final handle = tester.ensureSemantics();
        await tester.pump();
        await tester.pump();
        expect(_shape(_rootNode(tester, 'Item 2')), _joined);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us04/fr02/e11, s03/inv81: final review M1 an app GlobalKey '
      'moving a root surface from one live item to another still joins',
      (tester) async {
        final handle = tester.ensureSemantics();
        final target = ValueNotifier<int>(2);
        final movingKey = GlobalKey(debugLabel: 'm1 moving surface');
        Widget moving() => KeyedSubtree(
          key: movingKey,
          child: const StratumInkWell(onTap: _tapRow, child: Text('Moving')),
        );
        Widget item(int id) => (id == 2 || id == 3)
            ? ValueListenableBuilder<int>(
                valueListenable: target,
                builder: (context, current, _) =>
                    id == current ? moving() : Text('Item $id'),
              )
            : Text('Item $id');
        await tester.pumpWidget(_rootApp(_RootList(item: item)));
        expect(
          _shape(_rootNode(tester, 'Moving')),
          'label=Moving tap=true button=true enabled=isTrue moves=4',
        );

        target.value = 3;
        await tester.pump();
        expect(
          _shape(_rootNode(tester, 'Moving')),
          'label=Moving tap=true button=true enabled=isTrue moves=4',
        );
        // The flip the marker scheduled lands one frame later (D4, D6(e)).
        await tester.pump();
        expect(
          _shape(_rootNode(tester, 'Moving')),
          'label=Moving tap=true button=true enabled=isTrue moves=4',
        );
        handle.dispose();
      },
    );

    testWidgets('fo06/us04/fr02/e11, s03/inv81: final review M2 a run-time '
        'activation toggle under a disabled base component re-flags the '
        'pass node', (tester) async {
      final handle = tester.ensureSemantics();
      final tap = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        _rootApp(
          _RootList(
            item: (id) => id == 2
                ? _Tile(
                    disabled: true,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: tap,
                      builder: (context, canTap, _) => ContainerLayout(
                        interaction: Interaction(
                          onHover: (_) {},
                          onTap: canTap ? _tapRow : null,
                        ),
                        child: const Text('Item 2'),
                      ),
                    ),
                  )
                : _Tile(child: Text('Item $id')),
          ),
        ),
      );
      expect(
        _shape(_rootNode(tester, 'Item 2')),
        'label=Item 2 tap=false button=false enabled=isFalse moves=4',
      );

      tap.value = true;
      await tester.pump();
      await tester.pump();
      expect(
        _shape(_liveRootNode(tester, 'Item 2')),
        'label=Item 2 tap=false button=true enabled=isFalse moves=4',
      );

      tap.value = false;
      await tester.pump();
      await tester.pump();
      expect(
        _shape(_liveRootNode(tester, 'Item 2')),
        'label=Item 2 tap=false button=false enabled=isFalse moves=4',
      );
      handle.dispose();
    });
  });
}
