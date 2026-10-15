import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

Widget _item(BuildContext context, int index) {
  return SizedBox(key: ValueKey(index), width: 40, height: 40);
}

Widget _sized(Widget child) {
  return SizedBox(width: 200, height: 300, child: child);
}

/// [MaterialScrollBehavior] reads the platform from [Theme], and the
/// fallback theme keeps the platform of the first test, so desktop cases
/// set it here.
Widget _macOSTheme(Widget child) {
  return Theme(
    data: ThemeData(platform: TargetPlatform.macOS),
    child: child,
  );
}

List<Type> _physicsChain(WidgetTester tester) {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final chain = <Type>[];
  for (
    ScrollPhysics? physics = state.position.physics;
    physics != null;
    physics = physics.parent
  ) {
    chain.add(physics.runtimeType);
  }
  return chain;
}

final Finder _indicator = find.byWidgetPredicate(
  (widget) =>
      widget is StretchingOverscrollIndicator ||
      widget is GlowingOverscrollIndicator,
);

/// [child], kept alive when it leaves the built range.
class _KeptBox extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_KeptBox> createState() => _KeptBoxState();
}

class _KeptBoxState extends State<_KeptBox> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A 40 px item whose node is labeled `item <id>`; it keeps itself alive
/// when it leaves the built range, unless [keepAlive] is false.
class _KeptItem extends StatefulWidget {
  const new({
    super.key,
    required this.id,
    this.group = false,
    this.keepAlive = true,
  });

  final int id;
  final bool keepAlive;

  /// Whether the node sits in a focus group, before a second node labeled
  /// `second <id>`.
  final bool group;

  @override
  State<_KeptItem> createState() => _KeptItemState();
}

class _KeptItemState extends State<_KeptItem>
    with AutomaticKeepAliveClientMixin {
  late final node = FocusNode(debugLabel: 'item ${widget.id}');
  late final second = FocusNode(debugLabel: 'second ${widget.id}');

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void dispose() {
    node.dispose();
    second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.group) {
      return Focus(focusNode: node, child: const SizedBox(height: 40));
    }
    return RowLayout(
      focusGroup: const FocusGroup(),
      children: [
        for (final each in [node, second])
          Focus(focusNode: each, child: const SizedBox(width: 40, height: 40)),
      ],
    );
  }
}

/// A 40 px item whose node is labeled `item <id>`, before a second node
/// labeled `second <id>`, both under an app's own [FocusTraversalGroup]
/// running [OrderedTraversalPolicy], never Stratum's own focus group. It
/// keeps itself alive when it leaves the built range.
class _AppGroupItem extends StatefulWidget {
  const new({super.key, required this.id});

  final int id;

  @override
  State<_AppGroupItem> createState() => _AppGroupItemState();
}

class _AppGroupItemState extends State<_AppGroupItem>
    with AutomaticKeepAliveClientMixin {
  late final node = FocusNode(debugLabel: 'item ${widget.id}');
  late final second = FocusNode(debugLabel: 'second ${widget.id}');

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    node.dispose();
    second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: RowLayout(
        children: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(0),
            child: Focus(
              focusNode: node,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: Focus(
              focusNode: second,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('ListViewLayout', () {
    testWidgets('builds its items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(itemCount: 3, itemBuilder: _item),
          ),
        ),
      );

      expect(find.byKey(const ValueKey(2)), findsOneWidget);
    });

    testWidgets('builds no box without a style', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(itemCount: 3, itemBuilder: _item),
          ),
        ),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets(
      'fo06/us03/fr01, fo06/us03/s1: scrolls style padding with the items '
      'and keeps the box',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            _sized(
              const ListViewLayout.builder(
                style: WidgetStyle(
                  padding: EdgeInsets.all(16),
                  backgroundColor: Color(0xFFFFFFFF),
                ),
                itemCount: 50,
                itemBuilder: _item,
              ),
            ),
          ),
        );

        final list = tester.widget<ListView>(find.byType(ListView));
        expect(list.padding, const EdgeInsets.all(16));
        final box = tester.widget<AnimatedStyledBox>(
          find.byType(AnimatedStyledBox),
        );
        expect(box.style?.padding, isNull);
        final boxTop = tester.getTopLeft(find.byType(AnimatedStyledBox));
        final itemTop = tester.getTopLeft(find.byKey(const ValueKey(0)));
        expect(itemTop.dy - boxTop.dy, 16);

        await tester.drag(find.byType(ListView), const Offset(0, -40));
        await tester.pump();

        expect(tester.getTopLeft(find.byType(AnimatedStyledBox)), boxTop);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey(0))).dy,
          lessThan(itemTop.dy),
        );
      },
    );

    testWidgets('clips a rounded box with antiAlias', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(
              style: WidgetStyle(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.clipBehavior, Clip.antiAlias);
      expect(
        find.descendant(
          of: find.byType(AnimatedStyledBox),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'fo06/us03/fr02: applies the physics parameter on top of the theme',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            _sized(
              const ListViewLayout.builder(
                physics: NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: _item,
              ),
            ),
          ),
        );

        final chain = _physicsChain(tester);
        expect(chain.first, NeverScrollableScrollPhysics);
        expect(chain, contains(ClampingScrollPhysics));
      },
    );

    testWidgets('reads the theme physics', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(itemCount: 3, itemBuilder: _item),
          ),
          theme: fakeStratumTheme(physics: const BouncingScrollPhysics()),
        ),
      );

      expect(_physicsChain(tester), contains(BouncingScrollPhysics));
    });

    testWidgets('builds no overscroll indicator under the theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
          ),
        ),
      );

      expect(_indicator, findsNothing);
    });

    testWidgets('lets an ancestor hear the overscroll indicator', (
      tester,
    ) async {
      var heard = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              heard++;
              return false;
            },
            child: const ListViewLayout.builder(
              itemCount: 50,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pump();

      expect(heard, greaterThan(0));
    });

    testWidgets('puts a vertical gap between items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(
              gap: 8,
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final first = tester.getBottomLeft(find.byKey(const ValueKey(0)));
      final second = tester.getTopLeft(find.byKey(const ValueKey(1)));
      expect(second.dy - first.dy, 8);
    });

    testWidgets('puts a horizontal gap between items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(
              scrollDirection: Axis.horizontal,
              gap: 8,
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final first = tester.getTopRight(find.byKey(const ValueKey(0)));
      final second = tester.getTopLeft(find.byKey(const ValueKey(1)));
      expect(second.dx - first.dx, 8);
    });

    test('asserts that gap has an itemCount', () {
      expect(
        () =>
            ListViewLayout.builder(gap: 8, itemCount: null, itemBuilder: _item),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no itemExtent', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          itemExtent: 40,
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no prototypeItem', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          prototypeItem: const SizedBox(height: 40),
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no semanticChildCount', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          semanticChildCount: 3,
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('hands findChildIndexCallback to separated as item indices', (
      tester,
    ) async {
      int? finder(Key key) => key == const ValueKey('x') ? 1 : null;
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              gap: 8,
              itemCount: 3,
              itemBuilder: _item,
              findChildIndexCallback: finder,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.findChildIndexCallback!(const ValueKey('x')), 2);
    });

    testWidgets('forwards scrollCacheExtent', (tester) async {
      const extent = ScrollCacheExtent.pixels(120);
      await tester.pumpWidget(
        themedHost(
          _sized(
            const ListViewLayout.builder(
              scrollCacheExtent: extent,
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.scrollCacheExtent, extent);
    });

    testWidgets('keeps the scrollbar of a nested list', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _macOSTheme(
            _sized(
              ListViewLayout.builder(
                showScrollbar: false,
                itemCount: 1,
                itemBuilder: (context, index) => const SizedBox(
                  height: 200,
                  child: ListViewLayout.builder(
                    itemCount: 50,
                    itemBuilder: _item,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Scrollbar), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('keeps the scrollbar of a nested list without a theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: _sized(
              ListViewLayout.builder(
                showScrollbar: false,
                itemCount: 1,
                itemBuilder: (context, index) => const SizedBox(
                  height: 200,
                  child: ListViewLayout.builder(
                    itemCount: 50,
                    itemBuilder: _item,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((widget) => widget is RawScrollbar),
        findsOneWidget,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('ListViewLayout focused item kept alive off screen', () {
    /// [list] in an app with the default keys, 200 by 300, under the
    /// Stratum theme.
    Widget app(Widget list) {
      return MaterialApp(
        home: Material(
          child: themedHost(SizedBox(width: 200, height: 300, child: list)),
        ),
      );
    }

    /// The list's own [Scrollable], above any a text field holds.
    final list = find.byType(Scrollable).first;

    /// Jumps the list to [pixels], pumps a frame, and returns its position.
    Future<ScrollPosition> jump(WidgetTester tester, double pixels) async {
      final position = tester.state<ScrollableState>(list).position
        ..jumpTo(pixels);
      await tester.pump();
      return position;
    }

    /// Whether the row keyed [id] is built and lies wholly inside the
    /// list's viewport.
    bool showsWhole(WidgetTester tester, int id) {
      final row = find.byKey(ValueKey(id));
      if (row.evaluate().isEmpty) return false;
      final view = tester.getRect(list);
      final rect = tester.getRect(row);
      return view.intersect(rect) == rect;
    }

    final moves = ValueVariant<({bool focusable, String move})>({
      for (final focusable in [false, true])
        for (final move in [
          'nextFocus',
          'Tab',
          'Shift+Tab',
          'focusInDirection down',
        ])
          (focusable: focusable, move: move),
    });
    testWidgets('fo06/us07/fr01/e07 and fo06/us07/fr01/e08: a move from a focused item kept '
        'alive off screen brings it back first, then moves', (tester) async {
      final (:focusable, :move) = moves.currentValue!;
      await tester.pumpWidget(
        app(
          ListViewLayout.builder(
            focusable: focusable,
            itemCount: 1000,
            itemBuilder: (context, index) =>
                _KeptItem(key: ValueKey(index), id: index),
          ),
        ),
      );
      await jump(tester, 4000);
      final node =
          tester.state<_KeptItemState>(find.byKey(const ValueKey(103))).node
            ..requestFocus();
      await tester.pump();
      final position = await jump(tester, 20000);

      switch (move) {
        case 'nextFocus':
          node.nextFocus();
        case 'Tab':
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        case 'Shift+Tab':
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        default:
          node.focusInDirection(TraversalDirection.down);
      }
      await tester.pumpAndSettle();

      final back = move == 'Shift+Tab';
      final target = back ? 102 : 104;
      expect(tester.takeException(), isNull);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item $target');
      expect(showsWhole(tester, target), isTrue);
      expect(position.pixels, back ? 4080 : 4120);
    }, variant: moves);

    testWidgets('fo06/us07/fr01/e07: Tab from a focused text field scrolled far away brings '
        'its row back, then moves to the next row', (tester) async {
      final fields = [
        for (var index = 0; index < 1000; index++)
          FocusNode(debugLabel: 'field $index'),
      ];
      addTearDown(() {
        for (final field in fields) {
          field.dispose();
        }
      });
      await tester.pumpWidget(
        app(
          ListViewLayout.builder(
            itemCount: 1000,
            itemBuilder: (context, index) => SizedBox(
              key: ValueKey(index),
              height: 40,
              child: TextField(focusNode: fields[index]),
            ),
          ),
        ),
      );
      await jump(tester, 4000);
      fields[103].requestFocus();
      await tester.pump();
      await jump(tester, 20000);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(FocusManager.instance.primaryFocus, same(fields[104]));
      expect(showsWhole(tester, 104), isTrue);
    });

    // Whether the list is a Tab stop, and the key that moves focus.
    final leaves = ValueVariant<({bool focusable, String key})>({
      for (final focusable in [false, true])
        for (final key in ['Tab', 'Shift+Tab'])
          (focusable: focusable, key: key),
    });
    testWidgets(
      'fo06/us07/fr01/e07: when the app holds the scroll so a focused text field '
      'kept alive off screen cannot come back and no other node in the list '
      'shows, Tab or Shift+Tab leaves the list in its direction',
      (tester) async {
        final (:focusable, :key) = leaves.currentValue!;
        final field = FocusNode(debugLabel: 'field');
        final before = FocusNode(debugLabel: 'before');
        final after = FocusNode(debugLabel: 'after');
        addTearDown(field.dispose);
        addTearDown(before.dispose);
        addTearDown(after.dispose);
        await tester.pumpWidget(
          app(
            Column(
              children: [
                Focus(
                  focusNode: before,
                  child: const SizedBox(width: 40, height: 20),
                ),
                Expanded(
                  child: ListViewLayout.builder(
                    focusable: focusable,
                    itemCount: 1000,
                    itemBuilder: (context, index) => SizedBox(
                      key: ValueKey(index),
                      height: 40,
                      child: index == 103 ? TextField(focusNode: field) : null,
                    ),
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
        await jump(tester, 4000);
        field.requestFocus();
        await tester.pump();
        final position = await jump(tester, 20000);
        // The app holds the list there: each jump away springs back.
        position.addListener(() {
          if (position.pixels != 20000) position.jumpTo(20000);
        });

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
        expect(FocusManager.instance.primaryFocus?.debugLabel, target);
        expect(position.pixels, 20000);
      },
      variant: leaves,
    );

    final groupMoves = ValueVariant<String>({
      'Tab',
      'Shift+Tab',
      'nextFocus',
      'previousFocus',
      'focusInDirection down',
    });
    testWidgets('fo06/us07/fr01/e07 and fo06/us07/fr01/e08: a move from a focus group inside a '
        'focused item kept alive off screen brings the item back, then leaves '
        'the group for the item next in order', (tester) async {
      await tester.pumpWidget(
        app(
          ListViewLayout.builder(
            itemCount: 1000,
            // Only the focused item stays alive, so its neighbors lose
            // their place in the tree as a real list's do.
            itemBuilder: (context, index) => _KeptItem(
              key: ValueKey(index),
              id: index,
              group: true,
              keepAlive: index == 103,
            ),
          ),
        ),
      );
      await jump(tester, 4000);
      final node =
          tester.state<_KeptItemState>(find.byKey(const ValueKey(103))).node
            ..requestFocus();
      await tester.pump();
      await jump(tester, 20000);

      final move = groupMoves.currentValue!;
      switch (move) {
        case 'Tab':
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        case 'Shift+Tab':
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        case 'nextFocus':
          node.nextFocus();
        case 'previousFocus':
          node.previousFocus();
        default:
          node.focusInDirection(TraversalDirection.down);
      }
      await tester.pumpAndSettle();

      final target = move == 'Shift+Tab' || move == 'previousFocus' ? 102 : 104;
      expect(tester.takeException(), isNull);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'item $target');
      expect(showsWhole(tester, target), isTrue);
    }, variant: groupMoves);

    final appGroupMoves = ValueVariant<String>({'Tab', 'Shift+Tab'});
    testWidgets(
      'fo06/us07/fr01/e07 and fo06/us07/fr01/e08: Tab or Shift+Tab from a node inside '
      "an app's own FocusTraversalGroup, inside an item kept alive off "
      'screen, brings the item back before moving inside its own order',
      (tester) async {
        await tester.pumpWidget(
          app(
            ListViewLayout.builder(
              itemCount: 1000,
              itemBuilder: (context, index) => index == 103
                  ? _AppGroupItem(key: ValueKey(index), id: index)
                  : SizedBox(key: ValueKey(index), height: 40),
            ),
          ),
        );
        await jump(tester, 4000);
        final item = tester.state<_AppGroupItemState>(
          find.byKey(const ValueKey(103)),
        );
        final move = appGroupMoves.currentValue!;
        (move == 'Tab' ? item.node : item.second).requestFocus();
        await tester.pump();
        await jump(tester, 20000);

        if (move == 'Tab') {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        } else {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }
        await tester.pumpAndSettle();

        final label = move == 'Tab' ? 'second 103' : 'item 103';
        expect(tester.takeException(), isNull);
        expect(FocusManager.instance.primaryFocus?.debugLabel, label);
        expect(showsWhole(tester, 103), isTrue);
      },
      variant: appGroupMoves,
    );

    testWidgets('fo06/us07/fr01/e07: Tab from a text field that a row scrolled away, inside '
        'an item kept alive off screen, brings back the item and then the '
        'field, then moves to the next field and shows it', (tester) async {
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
        app(
          ListViewLayout.builder(
            itemCount: 1000,
            itemBuilder: (context, index) => SizedBox(
              key: ValueKey(index),
              height: 40,
              child: index == 103
                  ? _KeptBox(
                      child: ListViewLayout.builder(
                        key: rowKey,
                        scrollDirection: Axis.horizontal,
                        itemCount: fields.length,
                        itemBuilder: (context, field) => SizedBox(
                          width: 40,
                          child: TextField(focusNode: fields[field]),
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
          .descendant(of: find.byKey(rowKey), matching: find.byType(Scrollable))
          .first;
      await jump(tester, 4000);
      final row = tester.state<ScrollableState>(rowView).position..jumpTo(1100);
      await tester.pump();
      fields[30].requestFocus();
      await tester.pump();
      row.jumpTo(3000);
      await tester.pump();
      await jump(tester, 20000);
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
      expect(tester.getRect(list).intersect(field), field);
    });

    testWidgets(
      'fo06/us07/fr01/e07: a focus the app moves before the frame that brings a '
      'focused item kept alive off screen back stays where the app put it',
      (tester) async {
        await tester.pumpWidget(
          app(
            ListViewLayout.builder(
              itemCount: 1000,
              itemBuilder: (context, index) =>
                  _KeptItem(key: ValueKey(index), id: index),
            ),
          ),
        );
        _KeptItemState item(int id) =>
            tester.state<_KeptItemState>(find.byKey(ValueKey(id)));
        await jump(tester, 4000);
        final node = item(103).node..requestFocus();
        await tester.pump();
        await jump(tester, 20000);

        node.nextFocus();
        item(500).node.requestFocus();
        final log = <String?>[];
        void record() {
          final label = FocusManager.instance.primaryFocus?.debugLabel;
          if (log.isEmpty || log.last != label) log.add(label);
        }

        FocusManager.instance.addListener(record);
        addTearDown(() => FocusManager.instance.removeListener(record));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'item 500');
        expect(log, ['item 500']);
      },
    );
  });
}
