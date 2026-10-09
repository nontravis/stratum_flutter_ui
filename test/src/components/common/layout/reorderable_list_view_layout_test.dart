import 'package:flutter/rendering.dart'
    show
        ItemExtentBuilder,
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
    this.keepAliveIds,
    this.scrollCacheExtent,
    this.appIndex = false,
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
  final StratumReorderableItemsController? itemsController;

  /// The list's `focusable`; null keeps the platform default.
  final bool? focusable;

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

  /// The ids of the items that keep themselves alive off screen.
  final Set<int>? keepAliveIds;

  /// The list's `scrollCacheExtent`; null keeps the default 250 px.
  final ScrollCacheExtent? scrollCacheExtent;

  /// Whether the list gets `findChildIndexCallback`, as under [_appIndex].
  final bool appIndex;

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
      physics: widget.physics,
      itemExtent: widget.itemExtent,
      itemTransitionBuilder: widget.itemTransitionBuilder,
      reverse: widget.reverse,
      itemExtentBuilder: widget.itemExtentBuilder,
      prototypeItem: widget.prototypeItem,
      scrollCacheExtent: widget.scrollCacheExtent,
      findChildIndexCallback: widget.appIndex || _appIndex ? indexOf : null,
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
          keepAlive: widget.keepAliveIds?.contains(ids[index]) ?? false,
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
    this.keepAlive = false,
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

  /// The item's height; its width stays 40.
  final double height;

  /// Whether the item keeps itself alive when it leaves the built range.
  final bool keepAlive;

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
      width: 40,
      height: widget.height,
      child: Text('${widget.id}'),
    );
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

/// The opacity of the nearest [FadeTransition] around item [id].
double _opacity(WidgetTester tester, int id) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(FadeTransition),
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
            matching: find.byType(FadeTransition, skipOffstage: false),
          )
          .first,
    )
    .opacity
    .value;

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

/// Long-presses item [id] past the long-press delay and moves it [by] px
/// down: a drag of the item in progress, on [pointer] when given.
Future<TestGesture> _liftItem(
  WidgetTester tester,
  int id, {
  double by = 10,
  int? pointer,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text('$id')),
    pointer: pointer,
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.moveBy(Offset(0, by));
  await tester.pump();
  return gesture;
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

/// Dispatches [event] as the test's own pointer source, with no frame.
void _sendPointer(WidgetTester tester, PointerEvent event) {
  tester.binding.handlePointerEventForSource(
    event,
    source: TestBindingEventSource.test,
  );
}

void main() {
  void pointerTests() {
    testWidgets(
      'us11/fr01: the list builds one SliverReorderableList, found by a '
      'subtype predicate',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 3)));

        expect(_reorderSliver(), findsOneWidget);
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

    testWidgets("us11/fr01: the lift takes the theme's fast level", (
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

    testWidgets('C1: under reduced motion the lift still fades over the '
        "theme's duration", (tester) async {
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

    testWidgets(
      'us11/fr03: a count change with no call during a drag ends the drag, '
      'the dragged item back in its slot with its State',
      (tester) async {
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
      },
    );

    // Item 3 of the view, lifted by its center and held 10 px inside the
    // bottom edge at 0 px, or the top edge after a scroll to 800 px.
    final viewportEdges = ValueVariant<String>({'bottom edge', 'top edge'});
    testWidgets(
      'us11/fr01/e08: a drag held near a viewport edge scrolls the list '
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
      testWidgets('$axis: Alt and the axis arrows, Home, and End move the '
          'focused item', (tester) async {
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
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
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

    testWidgets('a "Move up" semantics action keeps the moved item\'s State', (
      tester,
    ) async {
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
    });

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
    testWidgets('us11/fr04/e07: an out-of-range index fails a debug assert', (
      tester,
    ) async {
      final controller = StratumReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 3, itemsController: controller)),
      );

      expect(() => controller.insertItem(4), throwsAssertionError);
      expect(() => controller.insertItem(-1), throwsAssertionError);
      expect(() => controller.removeItem(3), throwsAssertionError);
      expect(() => controller.removeItem(-1), throwsAssertionError);
      await tester.pump();
      expect(_harness(tester).ids, [0, 1, 2]);
    });

    testWidgets(
      'us11/fr04/e08: one controller on two lists at once fails a debug '
      'assert',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e09: a call on a controller attached to no list fails a '
      'debug assert',
      (tester) async {
        final controller = StratumReorderableItemsController();
        expect(() => controller.insertItem(0), throwsAssertionError);
        expect(() => controller.removeItem(0), throwsAssertionError);

        await tester.pumpWidget(
          _app(_Harness(count: 2, itemsController: controller)),
        );
        await tester.pumpWidget(_app(const SizedBox()));

        expect(() => controller.insertItem(0), throwsAssertionError);
      },
    );

    testWidgets(
      'us11/fr04/e09: a controller handed to another list detaches from the '
      'first',
      (tester) async {
        final first = StratumReorderableItemsController();
        final second = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 3, itemsController: first)),
        );
        await tester.pumpWidget(
          _app(_Harness(count: 3, itemsController: second)),
        );

        expect(() => first.insertItem(0), throwsAssertionError);
        _harness(tester).insert(0, 9);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids, [9, 0, 1, 2]);
      },
    );

    testWidgets(
      'us11/fr04/e10: without an itemsController an added item shows at once',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 3)));

        _harness(tester).insertData(1, 9);
        await tester.pump();

        expect(_offsetBetween(tester, 0, 1), 80);
        expect(
          find.descendant(
            of: _reorderSliver(),
            matching: find.byType(SizeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'us11/s8: an added item grows into its slot and fades in over the '
      'normal level',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
        expect(
          find.descendant(
            of: _reorderSliver(),
            matching: find.byType(SizeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'us11/s9: a removed item shrinks and fades out while its gap closes',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e15: an insert or a remove the app defers from inside a '
      'build to after the frame animates as calls made outside',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets("us11/fr04: insert and remove take the theme's normal level", (
      tester,
    ) async {
      final controller = StratumReorderableItemsController();
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
    });

    testWidgets(
      'us11/fr04/e03: a removed item keeps the look and State it had at '
      'removeItem',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets('us11/fr04/e03: a removeItem builder replaces the look', (
      tester,
    ) async {
      final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04: adding back the key of a leaving item ends its old copy at '
      'once, and the new item takes the State',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04: a list unmounted mid-animation leaves no running ticker',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets('us11/fr04/e12: a count change with no call ends the running '
        'animations and shows the data at once', (tester) async {
      final controller = StratumReorderableItemsController();
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
      expect(
        find.descendant(
          of: _reorderSliver(),
          matching: find.byType(SizeTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'us11/fr04/e05: calls in one turn take indices of the data the calls '
      'before them left',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04: removing an item still growing in shrinks it from where it '
      'stands',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets('us11/fr04: the last item left in a list shrinks out too', (
      tester,
    ) async {
      final controller = StratumReorderableItemsController();
      final theme = _normalTheme(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        _app(_Harness(count: 1, itemsController: controller), theme: theme),
      );
      final mid = Curves.easeInOutSine.transform(0.5);
      final size = find.ancestor(
        of: find.byKey(const ValueKey(0)),
        matching: find.byType(SizeTransition),
      );

      _harness(tester).remove(0);
      await tester.pump();
      expect(tester.getSize(size.first).height, 40);
      await tester.pump(_halfReverse(theme));
      expect(find.text('0'), findsOneWidget);
      expect(tester.getSize(size.first).height, moreOrLessEquals(40 * mid));

      await tester.pumpAndSettle();
      expect(find.text('0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'us11/fr04: a horizontal list shrinks a removed item along its width',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04: items removed bottom-up in two turns leave in list order',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04: items removed bottom-up in one turn leave in list order',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      "us11/fr04: an item added at a leaving item's gap in a later turn "
      'lands after it',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04: adding back a GlobalKey item while its old copy leaves '
      'raises no duplicate key',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      "us11/s10: under the app's reduced motion the gap closes at once and "
      'the removed item fades out',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      "us11/fr04/e01: under the platform's reduced motion an added item "
      'takes its size at once and fades in',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e02: an itemTransitionBuilder replaces the size and fade on '
      'insert and remove',
      (tester) async {
        final controller = StratumReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        Animation<double>? received;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 3,
              itemsController: controller,
              itemTransitionBuilder: (context, animation, child) {
                received = animation;
                return ScaleTransition(scale: animation, child: child);
              },
            ),
            theme: theme,
          ),
        );
        final mid = Curves.easeInOutSine.transform(0.5);
        Finder inList(Type type) =>
            find.descendant(of: _reorderSliver(), matching: find.byType(type));

        _harness(tester).insert(1, 9);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 125));
        expect(inList(ScaleTransition), findsOneWidget);
        expect(inList(SizeTransition), findsNothing);
        expect(inList(FadeTransition), findsNothing);
        expect(_offsetBetween(tester, 0, 1), 80);
        expect(received!.value, moreOrLessEquals(mid));
        await tester.pumpAndSettle();

        _harness(tester).remove(1);
        await tester.pump();
        expect(received!.value, 1);
        await tester.pump(_halfReverse(theme));
        expect(inList(ScaleTransition), findsOneWidget);
        expect(inList(SizeTransition), findsNothing);
        expect(received!.value, moreOrLessEquals(mid));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'us11/fr04/e02: under reduced motion an itemTransitionBuilder gets the '
      'animation unchanged',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
        Animation<double>? received;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 3,
              itemsController: controller,
              itemTransitionBuilder: (context, animation, child) {
                received = animation;
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
      },
    );

    testWidgets(
      'us11/fr04/e11: with a fixed item extent the size jumps and the fade '
      'plays',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e01: under reduced motion a removed item paints over the '
      'item that takes its place, and a removed last item just past it',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
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

        expect(painted.where((id) => id >= 2).toList(), [3, 2, 4]);
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
      'us11/fr04/e01: in a reversed list under reduced motion a removed item '
      "lies over its host from the host's edge nearest index 0",
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e11: with a fixed item extent a removed last item leaves at '
      'once and a quick insert never shows it again',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e11: with a fixed item extent a removed item takes no room '
      'under a caller transition, along a horizontal list too',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e11: with a fixed item extent a removed item lays out at '
      'the extent of the slot it fills',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
    testWidgets(
      'us11/fr04/e11: itemExtentBuilder and prototypeItem fix the extent as '
      'itemExtent does',
      (tester) async {
        final byBuilder = fixedBy.currentValue == 'itemExtentBuilder';
        final controller = StratumReorderableItemsController();
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
      },
      variant: fixedBy,
    );

    testWidgets(
      'us11/fr04/e02: under reduced motion a removed item keeps its room '
      'under a caller transition, which gets the animation unchanged',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
        final theme = _normalTheme(const Duration(milliseconds: 250));
        Animation<double>? received;
        await tester.pumpWidget(
          _app(
            _Harness(
              count: 3,
              itemsController: controller,
              itemTransitionBuilder: (context, animation, child) {
                received = animation;
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
      'us11/fr04/e05: a leaving item takes no pointer and starts no drag',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e05: a leaving item takes no focus and has no screen-reader '
      'node',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(count: 5, itemsController: controller),
            theme: _normalTheme(const Duration(seconds: 2)),
          ),
        );
        expect(find.bySemanticsLabel('2'), findsOneWidget);

        _harness(tester).remove(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final node = _itemState(tester, 2).node..requestFocus();
        await tester.pump();

        expect(node.hasFocus, isFalse);
        expect(find.text('2'), findsOneWidget);
        expect(find.bySemanticsLabel('2'), findsNothing);
        await tester.pumpAndSettle();
        handle.dispose();
      },
    );

    testWidgets(
      'us11/fr04/e05: removeItem and a reorder key skip a leaving item',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/s11: focus on a removed item moves to the first control of the '
      'item after it',
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        await _focusItem(tester, 2);

        _harness(tester).remove(2);
        await tester.pumpAndSettle();

        expect(_itemState(tester, 3).node.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'us11/fr04/e04: with no item after it, focus moves to the item before',
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        await _focusItem(tester, 4);

        _harness(tester).remove(4);
        await tester.pumpAndSettle();

        expect(_itemState(tester, 3).node.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      "us11/fr04/e04: with no other item, focus moves to the list's own Tab "
      'stop',
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(
            _Harness(count: 1, itemsController: controller, focusable: true),
          ),
        );
        await _focusItem(tester, 0);

        _harness(tester).remove(0);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'ScrollFocus');
      },
    );

    testWidgets(
      'us11/fr04/e04: the item that takes focus from a removed item shows on '
      'screen',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e05: a tap on a fixed-extent slot reaches the item under a '
      'leaving item, past the caller transition',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
                    onTap: () => transitionTaps += 1,
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
      },
    );

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
      'us11/fr04/e04: focus goes to the item after a removed one as the '
      'later calls of the same turn leave it',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/s12: a removal during a drag ends the drag with the dragged item '
      'back in its slot',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets('us11/fr04/e06: an insert during a drag ends the drag first', (
      tester,
    ) async {
      final controller = StratumReorderableItemsController();
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
    });

    testWidgets(
      'us11/fr04/e06: a drag its gesture canceled fires one onReorderEnd, '
      'and none at a later removal',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e06: a count change with no call ends a drag with one '
      'onReorderEnd, and a removal while the pointer stays down fires none',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e06: a removal while a dropped item settles ends the drop '
      'with no onReorderItem and no second onReorderEnd',
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller)),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 100));
        // The lift runs its full 250 ms, so the drop takes 250 ms to settle.
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pump();
        final ends = [..._harness(tester).ends];
        expect(ends, hasLength(1));
        // 50 ms of the settle left: less than the next frame's step.
        await tester.pump(const Duration(milliseconds: 200));

        _harness(tester).remove(3);
        await tester.pumpAndSettle();

        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ends, ends);
        expect(_harness(tester).ids, [0, 1, 2, 4]);
      },
    );

    testWidgets(
      'us11/fr04/e06: a count change with no call while a dropped item '
      'settles fires no second onReorderEnd',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e06: drag chrome that the app hides in onReorderEnd goes '
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

    testWidgets(
      'us11/fr04/e06: removing the dragged item ends the drag, then the item '
      'leaves from its slot',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
        final shrinking = find.ancestor(
          of: find.byKey(const ValueKey(0)),
          matching: find.byType(SizeTransition),
        );
        expect(tester.getTopLeft(shrinking.first), slot);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('0'), findsNothing);
        expect(_harness(tester).moves, isEmpty);
        expect(_harness(tester).ends, [0]);
        expect(_harness(tester).ids, [1, 2, 3, 4]);
      },
    );

    testWidgets(
      "us11/fr04/e01: under the platform's disableAnimations flag an insert "
      "and a remove still fade over the theme's durations",
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
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
      'us11/fr04: a removal in the turn of a move with no call ends the '
      'leaving copy of an item the data still holds',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04: adding back an item whose look holds an app GlobalKey ends '
      'its leaving copy at once',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e03: adding back the key of an item that leaves in a '
      'builder look keeps that look leaving',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e13: a leaving key the data holds again with no insertItem '
      'fails a debug assert when its item builds',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e04: focus the app moves in the turn of a removal stays '
      'where the app put it',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e16: a focused item removed and inserted back at its index '
      'with its key in one turn keeps its State and focus',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e16: a focused item removed in a builder look and inserted '
      'back at its index with its key in one turn keeps its State and focus',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e16: a focused item removed and inserted back at another '
      'index with its key in one turn keeps its State and focus',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e16: a focused node inside an item removed and inserted '
      'back at its index with its key in one turn keeps focus',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
    testWidgets(
      'us11/fr04/e17: a focused item removed and inserted back with its key '
      'in one turn at a slot the list has not built takes focus on its first '
      'control and shows on screen',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
      variant: returnsUnbuilt,
    );

    testWidgets(
      'us11/fr04/e16: a focused item removed and inserted back with its key '
      'in one turn at a slot built past the viewport keeps its State and '
      'focus and shows on screen',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e18: a focused node inside an item removed and inserted '
      'back with its key in one turn, gone while the item keeps its State, '
      "hands focus to the item's first node",
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e16: focus the app moves in the turn it removes a focused '
      'item and inserts it back stays where the app put it',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/s13: a button inside an item the app takes out and puts back at '
      'the fifth slot keeps focus, and the item shows there',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e17: in a reversed list a focused item inserted back at a '
      'slot the list has not built takes focus and shows on screen',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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
      'us11/fr04/e17: in a horizontal list a focused item inserted back at '
      'a slot the list has not built takes focus and shows on screen',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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
      'us11/fr04/e17: in a horizontal list under right-to-left text a '
      'focused item inserted back at an unbuilt slot takes focus and shows '
      'on screen',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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

    testWidgets(
      'us11/fr04/e17: in a list of varied item extents the list jumps again '
      'after a missed estimate and reaches the slot',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the items
        // built around index 100 put slot 40 too far down; the items built
        // after that first jump are all 80 px and land it.
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
            itemExtentBuilder: (index, dimensions) => index < 100 ? 80 : 40,
          ),
          offset: 8000,
          id: 100,
          slot: 40,
        );
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 100');
        expect(_itemInView(tester, 100), isTrue);
      },
    );

    testWidgets(
      'us11/fr04/e17: the list calls itemBuilder only inside a build while '
      'it reaches an unbuilt slot',
      (tester) async {
        var outside = 0;
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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
      },
    );

    testWidgets(
      'us11/fr04/e17: a node that takes focus while the list reaches a slot '
      'ends the reach and keeps that focus',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
          offset: 4000,
          id: 100,
          slot: 0,
        );
        _pinScroll(tester, 4000);
        await tester.pump();
        final other = _itemState(tester, 105).node..requestFocus();
        await tester.pumpAndSettle();

        expect(other.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'us11/fr04/e17: an insert while the list reaches a slot puts another '
      'key there, so the list returns to its offset and hands focus to the '
      'item after the gap',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
      },
    );

    testWidgets(
      'us11/fr04/e17: a slot the list does not reach in 4 frames hands focus '
      'on from the gap',
      (tester) async {
        var jumps = 0;
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
          offset: 4000,
          id: 100,
          slot: 0,
        );
        // Every jump of the reach springs back, so slot 0 is never built.
        _pinScroll(tester, 4000, onSpringBack: () => jumps += 1);
        await tester.pumpAndSettle();

        expect(jumps, 4);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 101');
      },
    );

    testWidgets(
      'us11/fr04/e17: focus Flutter hands back to an item focused earlier '
      'does not end the reach',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e17: a list taken out of the tree while it reaches a slot '
      'stops reaching',
      (tester) async {
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
          offset: 4000,
          id: 100,
          slot: 0,
        );
        await tester.pump();
        await tester.pumpWidget(_app(const SizedBox()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    // A physics the list can tell apart from the platform default by type, so
    // a rebuild that swaps it in makes the Scrollable replace and dispose the
    // position the reach in flight still holds.
    const swapPhysics = NeverScrollableScrollPhysics();

    testWidgets(
      "us11/fr04/e17: a reach that gives up after the app swaps the list's "
      'scroll physics returns on the live position and hands focus off with '
      'no exception',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump in
        // the call turn misses slot 40 and the State is lost.
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/s14: a button inside the first item of a long list the app '
      'takes out and puts back at the last slot: the list scrolls there, the '
      'button keeps focus, and the item shows on screen',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e14: a reorder key on the item a leaving item is drawn beside '
      'ends that leaving item at once',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e11: under an itemExtentBuilder a removed item keeps its '
      'own extent, clipped to the slot it fades over',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04: in a reversed list a removed item shrinks out below the '
      'item after it',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e01: in a horizontal right-to-left list under reduced '
      "motion a removed item lies from its host's right edge, and a removed "
      'last item just left of it',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e06: an insert from onReorderStart ends the drag it starts, '
      'the dragged item keeping its State',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e06: a remove and an insert from onReorderStart end the drag '
      'they start, so the drop moves nothing',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e06: a drag that starts between a call and its frame ends '
      'at once, and a later removal fires no second onReorderEnd',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e06: a drag that starts between the removal of its item and '
      'the frame ends at once, the item leaving from its slot',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e06: a drag that starts between an insert and the frame ends '
      'at once when its slot holds a leaving item',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );
  }

  group('ReorderableListViewLayout insert and remove', insertAndRemoveTests);

  void moveItemTests() {
    testWidgets(
      'us11/s15: the app moves the third item to the first slot: the third '
      'slot closes, the item grows and fades in, and its button keeps focus',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr05: a move down closes the old slot as the item grows into '
      'its new one, and the items past both slots hold still',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr05: in a reversed list a move to an earlier index closes the '
      "old slot at the data's last slot as the item grows into its new one, "
      'and the items past both slots hold still',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets('us11/fr05/e01: a move to the same index does nothing', (
      tester,
    ) async {
      final controller = StratumReorderableItemsController();
      await tester.pumpWidget(
        _app(_Harness(count: 5, itemsController: controller)),
      );
      final state = _itemState(tester, 2);

      _harness(tester).move(2, 2);
      await tester.pump();

      expect(
        find.descendant(
          of: _reorderSliver(),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(_itemState(tester, 2), same(state));
      expect(_harness(tester).ids, [0, 1, 2, 3, 4]);
    });

    testWidgets(
      'us11/fr05/e02: under reduced motion the old slot closes at once and '
      'the moved item fades in over the full forward duration',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
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
      "us11/fr05/e02: under the platform's disableAnimations flag the old "
      'slot closes at once and the moved item fades in over the full '
      'forward duration',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = StratumReorderableItemsController();
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
      'us11/fr05/e02: reduced motion switched on mid-move leaves the running '
      'fade to finish and settles the list right',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
        // old slot is already closed and no size transition runs, the moved
        // item only fading in.
        _harness(tester).move(0, 3);
        await tester.pump();
        expect(
          find.descendant(
            of: _reorderSliver(),
            matching: find.byType(SizeTransition),
          ),
          findsNothing,
        );
        expect(_opacity(tester, 2), 0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_harness(tester).ids, [0, 1, 3, 2, 4]);
        expect(_top(tester, 2), 120);
        expect(_top(tester, 4), 160);
      },
    );

    testWidgets(
      'us11/fr05/e02: with a fixed item extent the old slot closes at once '
      'and the moved item fades in',
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 5, itemsController: controller, itemExtent: 40)),
        );

        _harness(tester).move(2, 0);
        await tester.pump();

        expect(_top(tester, 0), 40);
        expect(_top(tester, 3), 120);
        expect(_opacity(tester, 2), 0);
        expect(
          find.descendant(
            of: _reorderSliver(),
            matching: find.byType(SizeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'us11/fr05/e03: a caller itemTransitionBuilder wraps the entering '
      'item and never the slot it left',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

        expect(find.byKey(const ValueKey('caller')), findsOneWidget);
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

    testWidgets('us11/fr05/e06: a move during a drag ends the drag first', (
      tester,
    ) async {
      final controller = StratumReorderableItemsController();
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
    });

    testWidgets(
      'us11/fr05/e07: an out-of-range index or a controller attached to no '
      'list fails a debug assert',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05/e08: a move the app defers to after the frame animates as '
      'a move made outside a build',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05/e08: a moveItem the app defers from inside a build to '
      'after the frame animates as a call made outside',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr05/e09: a move ends at once the leaving item drawn beside the '
      'moved item',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05/e10: a moved item still growing in starts its entry again '
      'at its new slot',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e05: an item playing its remove animation counts in no '
      'index of moveItem',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr05: a remove and a move in one turn read the move against the '
      'data after the remove',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05: an item moved from beyond the built slots grows in at its '
      'new slot with no closing slot and no scroll',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05/e04: a focused item moved to the unbuilt last slot keeps '
      'its State and focus, and shows on screen',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr05/e04: a focused item moved to the unbuilt first slot keeps '
      'its State and focus, and shows on screen',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    // The axis of a list whose focused item moves to an unbuilt middle slot.
    final moveAxes = ValueVariant<Axis>({Axis.vertical, Axis.horizontal});
    testWidgets(
      'us11/fr05/e04: a focused item moved to an unbuilt middle slot keeps '
      'its State and focus, and the list calls itemBuilder only inside a '
      'build',
      (tester) async {
        var outside = 0;
        final controller = StratumReorderableItemsController();
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
      },
      variant: moveAxes,
    );

    testWidgets(
      'us11/fr05/e04: after a missed estimate the list reaches the moved '
      "item's slot and focuses its first node",
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump
        // in the call turn lands short of slot 40 and the State is lost.
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr05/e04: when the reach after a move fails, the list returns to '
      'its offset from before the move and hands focus on from the slot the '
      'item left',
      (tester) async {
        // As above, the jump at the next frame's start lands short of slot
        // 40. Each jump of the reach then springs back to that landing, so
        // the reach fails; the list's return to 8000 is the first move let
        // through.
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05/e04: a focused item moved to a slot built past the viewport '
      'shows on screen once it has grown in',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05/e04: an insert in the same turn as a focused move whose '
      'estimate misses hands focus off from the shifted gap',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump in
        // the call turn lands short of slot 40 and the State is lost.
        final controller = StratumReorderableItemsController();
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
      'us11/fr05/e04: a focused item moved and then removed in one turn '
      'hands focus off, never to the scope',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets('us11/fr05/e04: a focused move with a missed estimate and an '
        'unexplained count change in one turn hands focus off, never to the '
        'scope', (tester) async {
      // Slots before index 100 are 80 px and the rest 40 px, so the jump
      // in the call turn lands short of slot 40 and the State is lost.
      final controller = StratumReorderableItemsController();
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
    });

    testWidgets(
      'us11/fr05/e05: the list never scrolls for a moved item that does not '
      'hold focus',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr05/e04: handing the controller to a second list in the turn '
      'of a focused move to an unbuilt slot keeps focus on a live item of '
      'the first list, never on the second list',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
            itemsController: StratumReorderableItemsController(),
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
      'us11/fr05/e04: a focused move down past the built slots after an '
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

    testWidgets('us11/fr05/e04: a focused move up into a built slot after an '
        'insertItem in the same turn does not scroll in the call turn', (
      tester,
    ) async {
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
    });

    testWidgets(
      'us11/fr05/e04: a focused move down to the last built slot scrolls '
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
    testWidgets(
      'us11/fr02/e07: a reorder key between an insertItem call and its frame '
      "moves the focused item by indices of the app's data",
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
      variant: windowKeys,
    );

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
      'us11/fr03/e07: a screen-reader move between an insertItem call and '
      "its frame moves the item it names by indices of the app's data",
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = StratumReorderableItemsController();
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
    testWidgets('us11/fr03/e07: a key or screen-reader move on an item the app '
        'removed in the same turn moves nothing', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = StratumReorderableItemsController();
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
    }, variant: removedInput);

    // The input that moves an item the app moved in that turn.
    final movedInput = ValueVariant<String>({'Alt+Up', 'Move up'});
    testWidgets('us11/fr03/e07: a key or screen-reader move on an item the app '
        'moved in the same turn moves it from its new index', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = StratumReorderableItemsController();
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
    }, variant: movedInput);

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
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr04/e06: a drag that starts between a reorder key and its frame '
      'ends at once, and the key move stands',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e04: a focused item a reorder key moved and the app then '
      'removed in the same turn leaves from there and hands focus on',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr05: a moveItem of an item a reorder key moved in the same turn '
      'closes the slot the key moved it to, and the items past both slots '
      'hold still',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr02: a reorder key the app does not apply leaves the next key '
      'on the indices the frame shows',
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr04/e04: an app call earlier in the same post-frame batch '
      'leaves focus on the item after a removed one',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e04: the handoff skips an item an insertItem call after '
      'the frame adds at the gap and goes to the next item the frame shows',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e04: the handoff skips an item a moveItem call after the '
      'frame brings to the gap and goes to the next item the frame shows',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr05: an item moved and then removed in one turn shows no '
      'leaving copy at its new index',
      (tester) async {
        final controller = StratumReorderableItemsController();
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

    testWidgets(
      'us11/fr05: a second moveItem of an item in the same turn closes only '
      'the slot the frame drew it in, and the items past both slots hold '
      'still',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e17: a reach that gives up where it started hands focus on '
      'from the gap an app call in its last frame moved',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr03: an insert the app defers from onReorderItem leaves the '
      'reveal on the moved item',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = StratumReorderableItemsController();
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
      'us11/fr05/e04: a reach that gives up away from where it started hands '
      'focus on from the gap an app call before the handoff moved',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump in
        // the call turn lands short of slot 40 and the State is lost.
        final controller = StratumReorderableItemsController();
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
    testWidgets(
      'us11/fr02/e02: a reorder key on an item the app removed in the same '
      'turn is handled with no move even with one item left, and a key on '
      'that item left is not handled',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
      variant: removedOfTwo,
    );

    testWidgets(
      'us11/fr03/e07: a screen-reader move on an item the app removed in the '
      'same turn moves nothing even with one item left',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 2, itemsController: controller)),
        );

        final harness = _harness(tester)..remove(1);
        await _moveAction(tester, 1, 'Move up');

        expect(harness.moves, isEmpty);
        expect(harness.ids, [0]);
        handle.dispose();
      },
    );

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
        _app(
          _Harness(
            count: 5,
            itemsController: StratumReorderableItemsController(),
          ),
        ),
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
      // The lift runs its full 250 ms, so the drop takes 250 ms to settle.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_harness(tester).starts, [3]);
      expect(_harness(tester).ends, hasLength(1));
      return (null, [..._harness(tester).ends]);
    }

    // After the input moved item 2 below item 3: the drag or the drop ended
    // as a call ends it, with one onReorderEnd and no move of its own.
    void expectDragEndedFirst(
      WidgetTester tester,
      List<int> ends,
      _ItemState state,
    ) {
      final harness = _harness(tester);
      expect(harness.moves, [(2, 3)]);
      expect(harness.ends, ends.isEmpty ? [3] : ends);
      expect(harness.ids, [0, 1, 3, 2, 4]);
      expect(_itemState(tester, 2), same(state));
    }

    testWidgets(
      'us11/fr02/e08: a reorder key during a pointer drag, or while a drop '
      'settles, ends it first and then moves the focused item',
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

    testWidgets(
      'us11/fr03/e08: a screen-reader move during a pointer drag, or while a '
      'drop settles, ends it first and then moves the item',
      (tester) async {
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
      },
      variant: dragPhase,
    );

    // The input that moves item 5 to the end right after the app inserts
    // an item at the end of its data.
    final endInput = ValueVariant<String>({'Alt+End', 'Move to the end'});
    testWidgets(
      'us11/fr03/e07: a key or screen-reader move to the end past an item a '
      'call of its turn grows in shows the moved item once that grow-in ends',
      (tester) async {
        final handle = tester.ensureSemantics();
        final controller = StratumReorderableItemsController();
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
        final controller = StratumReorderableItemsController();
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
      'us11/fr05/e04: an app insert from the scroll listener of a focused '
      "move's jump at the next frame's start leaves the give-up handoff on "
      'the item after the gap',
      (tester) async {
        // Slots before index 100 are 80 px and the rest 40 px, so the jump at
        // the next frame's start lands short of slot 40.
        final controller = StratumReorderableItemsController();
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
      itemsController: StratumReorderableItemsController(),
      heights: heights,
      itemExtent: itemExtent,
      scrollCacheExtent: scrollCacheExtent,
      axis: axis,
      reverse: reverse,
    );

    // Slots past the last laid-out one that item 100 enters.
    final pastLast = ValueVariant<int>({1, 2, 5});
    testWidgets(
      'us11/fr05/e04: a focused move to a near slot past the last laid-out '
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
    testWidgets('us11/fr05/e04: a focused move to a near slot before the first '
        'laid-out one scrolls nothing in the call turn and keeps State '
        'and focus', (tester) async {
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
    }, variant: beforeFirst);

    // (k + 1) x 40 px past one 300 px viewport: k = 7 is the first far one.
    final farPast = ValueVariant<int>({7, 10, 30});
    testWidgets(
      'us11/fr05/e04: a focused move to a slot whose distance plus one slot '
      'exceeds one viewport scrolls nothing in the call turn, jumps at the '
      "next frame's start, and keeps State and focus",
      (tester) async {
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
      },
      variant: farPast,
    );

    testWidgets(
      'us11/fr05/e04: a near move whose unbuilt items run taller than the '
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
      'us11/fr05/e04: under a fixed item extent the estimate is exact, so '
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
      'us11/fr05/e04: a viewport-relative scrollCacheExtent reaches the '
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
      'us11/fr05/e04: a focused move past the last laid-out slot scrolls '
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
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
      'us11/fr05/e08: a second focused move the app defers into the first '
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
      'us11/fr03/e09: Alt and an arrow to a near unbuilt slot scrolls '
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
      'us11/fr03/e09: a screen-reader move of one slot to a near unbuilt '
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

    testWidgets(
      'us11/fr03/e09: Alt and an arrow to a far unbuilt slot scrolls nothing '
      "in the turn of the key, jumps at the next frame's start, and keeps "
      'State and focus',
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr03/e09: Alt and an arrow past an unbuilt item taller than the '
      'laid-out average falls back to the reach, and the item keeps its '
      'State and focus off screen and shows on screen',
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr03/e09: Alt and an arrow to an unbuilt edge slot far off '
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
      'us11/fr03/e09: a screen-reader step action a same-turn removeItem '
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
            itemsController: StratumReorderableItemsController(),
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

    testWidgets(
      'us11/fr03/e09: when the reach after a far key move gives up, the list '
      "returns to the offset before the jump at the next frame's start and "
      'hands focus on from the slot the item left',
      (tester) async {
        // 200 px items and item 23 at 1200 px: the sliver lays out 18 to 22
        // at 4000 px. Alt+Down on item 22 enters slot 23, so the next
        // frame's start jumps by the 200 px average to 4600, where item 23,
        // now in slot 22, leaves slot 23 at 5600, past the frame.
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            heights: {
              for (var id = 0; id < 200; id++) id: id == 23 ? 1200 : 200,
            },
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
        // reach lands where the key's jump did and the reach gives up: the
        // list's next move is back to 4000, and item 23, now in the slot
        // item 22 left, takes focus.
        expect(moves.take(2), [4600, 4000]);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 23');
      },
    );

    // A later call of the key's turn: none, or an insert at index 0, before
    // the slot the item leaves, which that slot follows.
    final laterCall = ValueVariant<String>({'none', 'an insert before'});
    testWidgets(
      'us11/fr03/e09: when the reach after a key move gives up, focus goes on '
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
            itemsController: StratumReorderableItemsController(),
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
          itemsController: StratumReorderableItemsController(),
          scrollCacheExtent: const ScrollCacheExtent.pixels(0),
          heights: {for (var id = 0; id < 200; id++) id: 200},
        ),
      );
      expect(_laidOut(tester), (first: 19, last: 21, count: 3));
      return position;
    }

    testWidgets(
      'us11/fr03/e10: an app insert from the scroll listener of the jump of '
      'Alt+Home lands the moved item right after the inserted one, with its '
      'State and focus',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
      },
    );

    testWidgets(
      'us11/fr03/e10: an app insert from the scroll listener of the jump of '
      'a "Move to the start" action lands the moved item right after the '
      'inserted one, with its State and focus',
      (tester) async {
        final handle = tester.ensureSemantics();
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
      },
    );

    testWidgets(
      'us11/fr03/e10: an app insert from the scroll listener of the far '
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
      'us11/fr03/e10: an app insert from the scroll listener of the far '
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

    testWidgets(
      'us11/fr03/e02: an app that takes the moved item out of the data and '
      'the controller from onReorderItem of Alt+End leaves no jump and '
      'throws nothing after the frame',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
        );
        await _focusItem(tester, 100);
        final harness = _harness(tester)
          ..onMove = (_, to) => _harness(tester).remove(to);

        await _altNow(tester, LogicalKeyboardKey.end);

        expect(position.pixels, 4000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(harness.ids.contains(100), isFalse);
      },
    );
  });

  void keptAliveSlotsTests() {
    // Item 50 keeps itself alive: shown once at 2000 px, it stays mounted
    // after the list scrolls to 4000 px, outside the sliver's child list.
    Future<ScrollPosition> pumpKeptAlive(WidgetTester tester) async {
      final position = await _pumpScrolled(
        tester,
        _Harness(
          count: 200,
          itemsController: StratumReorderableItemsController(),
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
      'us11/fr05/e12: a kept-alive item never counts as built, so a far move '
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

    testWidgets(
      'us11/fr05/e12: a kept-alive item never counts as built, so it never '
      "stops a near move's jump at the next frame's start",
      (tester) async {
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
      },
    );
  }

  group(
    'ReorderableListViewLayout unbuilt slots and kept-alive items',
    keptAliveSlotsTests,
  );

  group('ReorderableListViewLayout unbuilt slot and a focus the app moves', () {
    testWidgets(
      'us11/fr05/e11: a focus the app moves in the turn of a near move '
      "stays, the list skips the move's jump, and the moved item is not kept "
      'alive',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
      'us11/fr05/e11: a focus the app moves in the turn of a far move stays, '
      "and the list skips the move's jump at the next frame's start",
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
      'us11/fr05/e11: a far move of a second item the app focuses in the '
      "same turn as a first item's far move keeps the second item's own "
      "jump, not the first's offset",
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
        // 101 back off screen.
        expect(position.pixels, 6400.0);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(other));
        expect(_statesOf(tester, 101), contains(otherState));
        expect(_builtInView(tester, 101), isTrue);
      },
    );

    testWidgets(
      'us11/fr05/e11: a far move of a first item the app refocuses after a '
      "second item's far move in the same turn runs only the first item's "
      "jump at the next frame's start, toward its slot after both calls",
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
        // 100's runs toward index 149, where item 101's move from before it
        // left it, by the 40 px average.
        expect(position.pixels, 149 * 40.0);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(a));
        expect(_statesOf(tester, 100), contains(aState));
        expect(_builtInView(tester, 100), isTrue);
      },
    );

    testWidgets(
      'us11/fr05/e11: three far moves in one turn, with the app refocusing '
      "the middle item, run only the middle item's jump at the next frame's "
      'start',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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

        // Only item 101's jump runs, toward index 159, where item 102's move
        // from before it left it, by the 40 px average.
        expect(position.pixels, 159 * 40.0);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(b));
        expect(_statesOf(tester, 101), contains(bState));
        expect(_builtInView(tester, 101), isTrue);
      },
    );

    testWidgets(
      'us11/fr03/e09: a focus the app moves in the turn of Alt+Down to a '
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
      'us11/fr03/e09: a focus the app moves in the turn of a far Alt+Down '
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

    testWidgets(
      'us11/fr03/e09: a focus the app moves in the turn of a screen-reader '
      "move to a near unbuilt slot stays, the list skips the move's jump, "
      'and the moved item is not kept alive',
      (tester) async {
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
      },
    );

    testWidgets('us11/fr03/e09: a focus the app moves in the turn of a far '
        "screen-reader move stays, and the list skips the move's jump at the "
        "next frame's start", (tester) async {
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
    });

    testWidgets(
      'us11/fr03/e09: a focus the app moves outside the list in the turn of '
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
      'us11/fr03/e09: the app focuses a bare FocusScopeNode outside the '
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

    testWidgets(
      'us11/fr03/e09: a focus the app moves outside the list in the turn of '
      'Alt+Down to a near unbuilt slot stays, and the list never pulls it '
      'back',
      (tester) async {
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
      },
    );
  });

  void dragEndsTests() {
    testWidgets(
      'us11/fr04/e06: a second pointer that takes a long-press drag over '
      'ends it with one onReorderEnd, in the microtask after its down '
      '(the SDK calls cancelReorder on the second pointer)',
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        final gesture = await _liftItem(tester, 2);
        final harness = _harness(tester);
        final second = TestPointer(9);

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
      'us11/fr04/e06: a second long press that starts a second drag ends '
      'the first drag before the second one starts',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final gesture = await _liftItem(tester, 2);
        final harness = _harness(tester);

        final second = await _liftItem(tester, 5, by: 50, pointer: 9);
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

    testWidgets(
      'us11/fr04/e06: a pointer cancel ends the drag with one onReorderEnd, '
      'and a later insertItem reports none',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      'us11/fr04/e06: a pointer cancel reports onReorderEnd in a microtask '
      'after the cancel, not inside its dispatch (the SDK reads the '
      "recognizer's onStart lazily and its own cancel skips cancelReorder)",
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr04/e06: a drop reports onReorderEnd once, at the pointer up, '
      "with the index Flutter's list gives the drop",
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final gesture = await _liftItem(tester, 2, by: 100);
        final harness = _harness(tester);

        await gesture.up();
        expect(harness.ends, [4]);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [4]);
        expect(harness.moves, [(2, 3)]);
      },
    );

    testWidgets('us11/fr04/e06: disposing the list during a drag reports no '
        'onReorderEnd', (tester) async {
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
    });

    testWidgets(
      'us11/fr01/e01: a second pointer on a handle takes the handle drag '
      'over and ends it with one onReorderEnd, in the microtask after its '
      'down',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
        final second = TestPointer(9);

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

    testWidgets(
      'us11/fr01/e01: a second handle drag ends the first one before it '
      'starts',
      (tester) async {
        await tester.pumpWidget(
          _app(const _Harness(count: 20, handles: true, longPressDrag: false)),
        );
        final gesture = await _grabHandle(tester, 2);
        final harness = _harness(tester);

        final second = await _grabHandle(tester, 5, pointer: 9);
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
      'us11/fr01/e01: a pointer cancel on a handle drag ends it with one '
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

    testWidgets(
      'us11/fr04/e06: an app that calls removeItem from the onReorderEnd of '
      "a second pointer's takeover fails no assert",
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 20, itemsController: controller)),
        );
        final gesture = await _liftItem(tester, 2);
        final harness = _harness(tester);
        harness.onEnd = (_) => harness.remove(0);
        final second = TestPointer(9);

        _sendPointer(tester, second.down(tester.getCenter(find.text('5'))));
        await tester.idle();
        _sendPointer(tester, second.up());
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(harness.ends, [2]);
        expect(harness.ids.take(3), [1, 2, 3]);
      },
    );

    testWidgets(
      'us11/fr04/e06: an app that calls removeItem from the onReorderEnd of '
      'a pointer cancel fails no assert',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );
  }

  group('ReorderableListViewLayout drag ends', dragEndsTests);

  void sameCountDragTests() {
    testWidgets(
      'us11/fr03/e06: a same-count change that moves the dragged item to a '
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
      'us11/fr01/e07: a same-count change that moves the unfocused dragged '
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

    testWidgets(
      'us11/fr04/e06: a same-count change that moves a dropped item while it '
      'settles ends the drop with no onReorderItem and no second '
      'onReorderEnd, and the item keeps its State',
      (tester) async {
        await tester.pumpWidget(_app(const _Harness(count: 20)));
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('3')),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 100));
        // The lift runs its full 250 ms, so the drop takes 250 ms to settle.
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
      },
    );

    testWidgets(
      "us11/fr04/e12: a same-count change that replaces the dragged item's "
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

    testWidgets(
      'us11/fr01/e07: a same-count change that moves only other items keeps '
      'the drag',
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr01/e07: the dragged-key check costs one itemBuilder call per '
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
    testWidgets(
      'us11/fr05/e12: two items moved in one turn to slots the frame does not '
      'build, a focused one and one the app keeps alive, both keep their '
      'State',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    testWidgets(
      's03/inv35: the list frames its items by key over each of the four '
      'slivers the SDK builds, with findChildIndexCallback set',
      (tester) async {
        final harnesses = [
          const _Harness(key: ValueKey(0), count: 5),
          const _Harness(key: ValueKey(1), count: 5, itemExtent: 40),
          _Harness(
            key: const ValueKey(2),
            count: 5,
            itemExtentBuilder: (index, dimensions) => 40,
          ),
          const _Harness(
            key: ValueKey(3),
            count: 5,
            prototypeItem: SizedBox(width: 40, height: 40),
          ),
        ];
        final kinds = <Type>[];
        for (final harness in harnesses) {
          await tester.pumpWidget(_app(harness));
          final sliver = tester.widget<SliverMultiBoxAdaptorWidget>(
            find.byWidgetPredicate(
              (widget) => widget is SliverMultiBoxAdaptorWidget,
            ),
          );
          kinds.add(sliver.runtimeType);
          final delegate = sliver.delegate;
          expect(delegate, isA<SliverChildBuilderDelegate>());
          expect(
            (delegate as SliverChildBuilderDelegate).findChildIndexCallback,
            isNotNull,
          );
        }

        expect(tester.takeException(), isNull);
        expect(kinds, [
          SliverList,
          SliverFixedExtentList,
          SliverVariedExtentList,
          SliverPrototypeExtentList,
        ]);
      },
    );

    testWidgets(
      'us11/fr05/e05: an unfocused item the app keeps alive keeps its State '
      'through a moveItem to a slot the frame does not build: its keep-alive '
      'follows it to its new slot',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );
  });

  void parkedItemTests() {
    testWidgets(
      'us11/fr04/e17: a node that takes focus while a focused item waits off '
      'screen ends its park, so the item, never laid out, leaves with its '
      'State',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      },
    );

    // A list shape the parked item's element follows its key in.
    final shapes = ValueVariant<String>({
      'itemExtent',
      'itemExtentBuilder',
      'prototypeItem',
      'reversed',
      'horizontal',
      'right-to-left',
    });
    testWidgets(
      'us11/fr04/e17: a focused item the app takes out and puts back far down '
      'keeps its State and focus off screen under a fixed, built, or '
      'prototype extent, and on a reversed, horizontal, or right-to-left '
      'list',
      (tester) async {
        final shape = shapes.currentValue!;
        final horizontal = shape == 'horizontal' || shape == 'right-to-left';
        await _returnFocused(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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
      },
      variant: shapes,
    );

    testWidgets(
      'us11/fr04/e17: an insertItem before an item that waits off screen '
      'carries its kept-alive State to its new index, until the reach gives '
      'up and hands focus on',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e17: a focused item the app takes out and puts back far '
      'down waits off screen with its State and the node that holds focus, '
      'then shows on screen',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/s04: on a lazy list whose unbuilt items run taller than the '
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
      'us11/fr04/e12: an item-count change with no call while a focused '
      'item waits off screen for its slot ends its State and hands focus '
      'on, and with the app index follows the item by its key',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
      'us11/fr04/e17: a moveItem of the item that waits off screen keeps it '
      'alive for its new slot, with its State and focus, and shows it there',
      (tester) async {
        final controller = StratumReorderableItemsController();
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
        _Harness(
          count: 200,
          itemsController: StratumReorderableItemsController(),
        ),
        offset: 4200,
      );
      await _focusItem(tester, 105);
      position.addListener(() => moves.add(position.pixels));
      return position;
    }

    // A move to the end: by Alt+End, or by the "Move to the end" action.
    final endMove = ValueVariant<String>({'Alt+End', 'Move to the end'});
    testWidgets('us11/fr03/e01: a focus the app moves to another item in '
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

    testWidgets('us11/fr03/e01: a focus the app moves to another item in '
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

    testWidgets(
      'us11/fr03/e02: the scroll offset read in onReorderItem of Alt+End has '
      "not moved; the list jumps to the end at the next frame's start and "
      'keeps the item State and focus',
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr05/e04: the scroll offset read right after a far moveItem has '
      "not moved; it moves at the next frame's start, before that frame "
      'builds',
      (tester) async {
        double? atBuild;
        var armed = false;
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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

        expect(atBuild, isNot(4000));
        expect(atBuild, position.pixels);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_builtInView(tester, 100), isTrue);
      },
    );
  });

  group('ReorderableListViewLayout handoff away from the laid-out items', () {
    testWidgets(
      'us11/fr04/e04: when the app takes a moved item out before the frame '
      'whose jump would reach its slot, the list reaches toward the gap and '
      'hands focus to an item laid out there, so focus is never lost',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
          ),
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
      'us11/fr04/e04: an item the app keeps alive off screen beside the gap '
      'of a removed focused item is never the handoff target: the list '
      'reaches the gap and focus goes to an item laid out there',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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

    testWidgets(
      'us11/fr04/e04: when the reach toward the gap gives up, focus goes to '
      'the laid-out item nearest the gap, on a list with no Tab stop of its '
      'own',
      (tester) async {
        final position = await _pumpScrolled(
          tester,
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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
      },
    );
  });

  group('ReorderableListViewLayout reorders the app makes alone', () {
    testWidgets(
      'us11/fr05/e13: an item the app keeps alive follows a reorder of its '
      'data with no call to a slot the frame does not build',
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr01/input-output: an app index past the data counts as no '
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
            itemsController: StratumReorderableItemsController(),
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

    testWidgets(
      'us11/fr05/e13: with no callback, a focused item the app moves in its '
      'data with no call to a slot the frame does not build loses its State',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          const _Harness(count: 1000),
        );

        _harness(tester).moveData(103, 600);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(state.mounted, isFalse);
        expect(FocusManager.instance.primaryFocus, isNot(same(state.node)));
        expect(position.pixels, 4000);
      },
    );

    final farTargets = ValueVariant<int>({600, 5, 999});
    testWidgets(
      'us11/fr05/e13: a focused item the app moves in its data with no call '
      'to a slot the frame does not build keeps its State and focus, shows '
      'one frame after the build that learns of it, and leaves once out of '
      'view',
      (tester) async {
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
        expect(state.mounted, isFalse);
      },
      variant: farTargets,
    );

    testWidgets(
      'us11/fr05/e13: a focused item the app moves to a laid-out slot out of '
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

    testWidgets(
      'us11/fr05/e13: a focused item the app moves within the viewport keeps '
      'its State and focus, and the list does not scroll',
      (tester) async {
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
      },
    );

    testWidgets(
      'us11/fr05/e13: an item that does not hold focus, moved by the app to '
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
      'us11/fr01/e07 and us11/fr03/e06: the app moves the dragged item in its '
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
          // Never parked or followed. The proxy holds the item when the
          // drag ends, outside the sliver, so the app's own keep-alive does
          // not keep it either (measured).
          expect(state.mounted, isFalse);
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
      'us11/fr05/e13: a focus the app moves to another item in the turn of '
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
      'us11/fr05/e13: a focus the app moves to another item after the build '
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
    testWidgets(
      'us11/fr05/e13: a null app answer for the focused item, or one outside '
      'the data, counts as no move, as with no callback',
      (tester) async {
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
      },
      variant: answers,
    );

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
            itemsController: StratumReorderableItemsController(),
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
      'us11/fr05/e13: on a lazy extent whose unbuilt items run taller, a '
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
      'us11/fr05/e13: on a lazy extent whose unbuilt items run taller, a '
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
      'us11/fr05/e13: a later reorder of the item kept alive off screen aims '
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
      's03/inv35: an insertItem that shifts the focused item, with no '
      'reorder, books no move: the list does not scroll for the item',
      (tester) async {
        final (state, position) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            itemsController: StratumReorderableItemsController(),
          ),
          id: 107,
        );
        expect(_itemInView(tester, 107), isFalse);

        _harness(tester).insert(101, 5000);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_statesOf(tester, 107), [same(state)]);
        expect(position.pixels, 4000);
      },
    );

    testWidgets(
      'us11/fr01/input-output: the list asks the app once per built item on '
      'each build, plus once for the focused item, and never while it only '
      'scrolls',
      (tester) async {
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
      },
    );

    final shapes = ValueVariant<(String, int)>({
      ('reversed', 600),
      ('reversed', 5),
      ('horizontal', 600),
      ('horizontal', 5),
    });
    testWidgets(
      'us11/fr05/e13: on a reversed or horizontal list, a focused item the '
      'app moves far keeps its State and focus and shows',
      (tester) async {
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
      },
      variant: shapes,
    );

    // Another item's reorder shifts the focused item one slot: a fully
    // visible item scrolls nothing, a partly hidden one shows whole.
    final shifted = ValueVariant<(int, double, double)>({
      (103, 4000, 4000),
      (100, 4020, 3960),
    });
    testWidgets(
      'us11/fr05/e13: a shift of the focused item, when the app moves another '
      'item past it, counts as its move',
      (tester) async {
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
      },
      variant: shifted,
    );

    // An item-count change with no call, with the app's index: in the
    // reorder's own turn, in the turn after the build that parks the item,
    // and while the item is dragged. The list keeps following the item by
    // its key (R25).
    final countChange = ValueVariant<String>({
      'in the same turn',
      'after the build',
      'while dragged',
    });
    testWidgets(
      'us11/fr04/e12: with the app index, an item-count change with no call '
      'keeps following the focused item by its key: State and focus stay, '
      'and the list shows the item at its slot',
      (tester) async {
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
      },
      variant: countChange,
    );

    testWidgets(
      'us11/fr01/e07 and s03/inv28: an unfocused dragged item the app keeps '
      'alive loses its State when an item-count change ends the drag and '
      'its new slot is not laid out',
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
        expect(state.mounted, isFalse);
        expect(position.pixels, 4000);
      },
    );

    // The park the count change meets: a moveItem's, or a raw move's, while
    // the reach runs into taller unbuilt items.
    final parkedBy = ValueVariant<String>({'moveItem', 'a raw move'});
    testWidgets(
      'us11/fr04/e17 and s03/inv32: with the app index, an item-count change '
      'during the retry frames re-aims the reach, and the parked item keeps '
      'its State and focus and shows',
      (tester) async {
        final (state, _) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            heights: taller,
            itemsController: StratumReorderableItemsController(),
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
      },
      variant: parkedBy,
    );

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
      'us11/fr04/e12 and s03/inv35: with the app index, a null answer for the '
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
            itemsController: StratumReorderableItemsController(),
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
    testWidgets(
      'us11/fr03/e06, us11/fr04/e06, and s03/inv28: an item-count change '
      'during a drag that shifts the focused dragged item to a slot the '
      'frame does not lay out ends the drag; with no callback the item loses '
      'its State, and with the app index it keeps its State and focus and '
      'shows',
      (tester) async {
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
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
        expect(position.pixels, 4000);
      },
      variant: countDrag,
    );

    // A focused dragged item a raw move took to a laid-out slot, then shifted
    // by an item-count change with no call before the drag proxy lets it go:
    // by one slot, still laid out, or by twenty, past the laid-out slots.
    final liftedShift = ValueVariant<int>({1, 20});
    testWidgets(
      'us11/fr04/e06 and s03/inv35: with the app index, an item-count change '
      'before the drag proxy lets go of a focused item a raw move took to a '
      'laid-out slot keeps following the item by its key',
      (tester) async {
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
      },
      variant: liftedShift,
    );

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
    testWidgets(
      'us11/fr04/e12 and s03/inv35: with the app index, an item-count change '
      'with no call in the turn of a key move drops the booked target, and '
      'the list follows the focused item by its key',
      (tester) async {
        final (change, at) = staleTarget.currentValue!;
        final (state, _) = await pumpItem(
          tester,
          _Harness(
            count: 1000,
            appIndex: true,
            heights: taller,
            itemsController: StratumReorderableItemsController(),
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
      },
      variant: staleTarget,
    );

    // Kept alive by the app or not, with no callback or with the app index.
    final keptAliveDragged = ValueVariant<(bool, bool)>({
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    });
    testWidgets(
      'us11/fr05/e05 and s03/inv28: a moveItem that ends a drag moves the '
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
            itemsController: StratumReorderableItemsController(),
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
}
