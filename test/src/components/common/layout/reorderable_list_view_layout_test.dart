import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _red = Color(0xFFFF0000);

/// [child], 200 by 300, in an app with an overlay, localizations, and the
/// default keys, under the Stratum theme.
Widget _app(Widget child, {TextDirection textDirection = TextDirection.ltr}) {
  return MaterialApp(
    home: Material(
      child: themedHost(
        SizedBox(width: 200, height: 300, child: child),
        textDirection: textDirection,
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
  });

  final int count;
  final Axis axis;
  final WidgetStyle? dragStyle;
  final bool longPressDrag;

  /// Whether each item has a drag handle at its start.
  final bool handles;

  /// The id of the item that holds a text field.
  final int? fieldAt;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final List<int> ids = [for (var i = 0; i < widget.count; i++) i];
  final moves = <(int, int)>[];

  @override
  Widget build(BuildContext context) {
    return ReorderableListViewLayout.builder(
      scrollDirection: widget.axis,
      itemCount: ids.length,
      dragStyle: widget.dragStyle,
      longPressDrag: widget.longPressDrag,
      onReorderItem: (from, to) => setState(() {
        moves.add((from, to));
        ids.insert(to, ids.removeAt(from));
      }),
      itemBuilder: (context, index) => _Item(
        key: ValueKey(ids[index]),
        id: ids[index],
        index: index,
        handle: widget.handles,
        field: widget.fieldAt == ids[index],
      ),
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
  });

  final int id;
  final int index;
  final bool handle;
  final bool field;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  late final node = FocusNode(debugLabel: 'item ${widget.id}');
  bool expanded = false;

  @override
  void dispose() {
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.field) {
      return SizedBox(width: 40, height: 40, child: TextField(focusNode: node));
    }
    Widget item = Focus(
      focusNode: node,
      child: SizedBox(width: 40, height: 40, child: Text('${widget.id}')),
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
    return item;
  }
}

_HarnessState _harness(WidgetTester tester) =>
    tester.state<_HarnessState>(find.byType(_Harness));

_ItemState _itemState(WidgetTester tester, int id) => tester.state<_ItemState>(
  find.byKey(ValueKey(id), skipOffstage: false),
);

/// Focuses item [id] and returns its node.
Future<FocusNode> _focusItem(WidgetTester tester, int id) async {
  final node = _itemState(tester, id).node..requestFocus();
  await tester.pump();
  return node;
}

/// Presses [key] with Alt held and returns whether it was handled.
Future<bool> _alt(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  final handled = await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
  return handled;
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

    testWidgets('dragStyle reaches the lifted item and animates over 100 ms', (
      tester,
    ) async {
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
        const Duration(milliseconds: 100),
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
  });

  group('ReorderableListViewLayout keys', () {
    for (final (axis, back, forth) in const [
      (
        Axis.vertical,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
      ),
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

    testWidgets('a move past either end, an arrow across the axis, and a '
        'list of one item are not handled', (tester) async {
      await tester.pumpWidget(_app(const _Harness(count: 3)));
      await _focusItem(tester, 0);

      expect(await _alt(tester, LogicalKeyboardKey.arrowUp), isFalse);
      expect(await _alt(tester, LogicalKeyboardKey.home), isFalse);
      expect(await _alt(tester, LogicalKeyboardKey.arrowLeft), isFalse);
      await _focusItem(tester, 2);
      expect(await _alt(tester, LogicalKeyboardKey.arrowDown), isFalse);
      expect(_harness(tester).moves, isEmpty);

      await tester.pumpWidget(_app(const _Harness(key: Key('one'), count: 1)));
      await _focusItem(tester, 0);
      expect(await _alt(tester, LogicalKeyboardKey.arrowDown), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

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
}
