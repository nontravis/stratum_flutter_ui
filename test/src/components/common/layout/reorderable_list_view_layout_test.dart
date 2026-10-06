import 'package:flutter/rendering.dart'
    show ItemExtentBuilder, SliverLayoutDimensions;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _red = Color(0xFFFF0000);

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

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final List<int> ids = [for (var i = 0; i < widget.count; i++) i];
  final moves = <(int, int)>[];
  final starts = <int>[];
  final ends = <int>[];

  /// Runs inside `onReorderStart`, after the start is logged.
  void Function(int index)? onStart;

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
      onReorderStart: (index) {
        starts.add(index);
        onStart?.call(index);
      },
      onReorderEnd: ends.add,
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
        );
      },
    );
  }
}

/// A 40 px item with a focus node labeled `item <id>` and an `expanded`
/// flag that lives in its State.
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

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  late final node = FocusNode(debugLabel: 'item ${widget.id}');
  late final inner = FocusNode(debugLabel: 'inner ${widget.id}');
  bool expanded = false;

  @override
  void dispose() {
    node.dispose();
    inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.field) {
      return SizedBox(width: 40, height: 40, child: TextField(focusNode: node));
    }
    final label = SizedBox(width: 40, height: 40, child: Text('${widget.id}'));
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

void main() {
  group('ReorderableListViewLayout pointer', () {
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
  });

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

  group('ReorderableListViewLayout insert and remove', () {
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
            of: find.byType(ReorderableList),
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
            of: find.byType(ReorderableList),
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
          of: find.byType(ReorderableList),
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
        Finder inList(Type type) => find.descendant(
          of: find.byType(ReorderableList),
          matching: find.byType(type),
        );

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
      'us11/fr04/e06: a drag its gesture canceled fires no onReorderEnd at a '
      'later removal',
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
        expect(_harness(tester).ends, isEmpty);

        _harness(tester).remove(3);
        await tester.pumpAndSettle();

        expect(_harness(tester).ends, isEmpty);
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
      'takes out and puts back at the last slot: the list scrolls there and '
      'focus lands on the first control',
      (tester) async {
        final controller = StratumReorderableItemsController();
        await tester.pumpWidget(
          _app(_Harness(count: 200, itemsController: controller, innerAt: 0)),
        );
        _itemState(tester, 0).inner.requestFocus();
        await tester.pump();

        _harness(tester)
          ..remove(0)
          ..insert(199, 0);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 0');
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
  });

  group('ReorderableListViewLayout moveItem', () {
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
          of: find.byType(ReorderableList),
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
            of: find.byType(ReorderableList),
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
            of: find.byType(ReorderableList),
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
        // As above, the jump in the call turn lands short of slot 40. Each
        // jump of the reach then springs back to that landing, so the reach
        // fails; the list's return to 8000 is the first move let through.
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
        final landing = position.pixels;
        var springs = 0;
        position.addListener(() {
          if (springs == 4 || position.pixels == landing) return;
          springs += 1;
          position.jumpTo(landing);
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
        // Each jump of the reach springs back to where the call-turn jump
        // landed, so the reach gives up and the E04 handoff runs.
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        final landing = position.pixels;
        var springs = 0;
        position.addListener(() {
          if (springs == 4 || position.pixels == landing) return;
          springs += 1;
          position.jumpTo(landing);
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
  });

  group('ReorderableListViewLayout data and frame indices', () {
    // 200 items of 40 px in a 300 px viewport scrolled to 4000, with the
    // default 250 px cache extent: the frame builds slots 93 to 113.
    Future<ScrollPosition> pumpAt4000(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          _Harness(
            count: 200,
            itemsController: StratumReorderableItemsController(),
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
      'insertItem in the same turn jumps first and keeps its State',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // After three inserts item 100 sits at index 103; slot 116, the slot
        // it enters, is past the built 93 to 113.
        _harness(tester)
          ..insert(0, 1000)
          ..insert(0, 1001)
          ..insert(0, 1002)
          ..move(103, 115);
        expect(position.pixels, isNot(4000));
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
      'us11/fr05/e04: a focused move down to the last built slot jumps '
      'first, since the item enters the slot after it, and keeps its State',
      (tester) async {
        final position = await pumpAt4000(tester);
        final state = _itemState(tester, 100);
        final focused = await _focusItem(tester, 100);

        // A move down to 113 enters slot 114, which the frame did not build.
        _harness(tester).move(100, 113);
        expect(position.pixels, isNot(4000));
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
  });
}
