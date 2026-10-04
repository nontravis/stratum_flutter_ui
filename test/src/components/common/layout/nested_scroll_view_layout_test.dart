import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// The header's collapse extent: H in the unified offset.
const _header = 200.0;

final _desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

FocusNode _node(String label) {
  final node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

/// [child], [width] by 300, after a focusable box, under the app's
/// default Tab, arrow, and activation keys.
Widget _keyboardHost(
  Widget child, {
  required FocusNode before,
  double width = 200,
}) {
  return themedHost(
    Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              focusNode: before,
              child: const SizedBox(width: 10, height: 10),
            ),
            SizedBox(width: width, height: 300, child: child),
          ],
        ),
      ),
    ),
  );
}

List<Widget> _headerSlivers(BuildContext context, bool innerBoxIsScrolled) {
  return const [SliverToBoxAdapter(child: SizedBox(height: _header))];
}

/// A list of 100 focusable rows of 40 px, labeled `<label> <index>`.
///
/// Lists that share the inner controller of a tab body build no
/// scrollbar: a desktop scrollbar asserts while a tab swipe attaches two
/// lists to the controller it watches.
Widget _list({
  Key? key,
  ScrollController? controller,
  String label = 'row',
  bool? showScrollbar,
}) {
  return ListViewLayout.builder(
    key: key,
    controller: controller,
    showScrollbar: showScrollbar,
    itemCount: 100,
    itemBuilder: (context, index) =>
        Focus(debugLabel: '$label $index', child: const SizedBox(height: 40)),
  );
}

/// A nested scroll view whose header is [_header] tall, with [body], else
/// [_list], after the focusable box [before].
Widget _nested({required FocusNode before, Widget? body}) {
  return _keyboardHost(
    NestedScrollViewLayout(
      headerSliverBuilder: _headerSlivers,
      body: body ?? _list(),
    ),
    before: before,
  );
}

NestedScrollViewState _state(WidgetTester tester) =>
    tester.state<NestedScrollViewState>(find.byType(NestedScrollView));

ScrollPosition _outer(WidgetTester tester) =>
    _state(tester).outerController.position;

ScrollPosition _inner(WidgetTester tester) =>
    _state(tester).innerController.position;

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Focuses [before], then Tabs once, onto the body list's Tab stop.
Future<void> _tabIn(WidgetTester tester, FocusNode before) async {
  before.requestFocus();
  await tester.pump();
  await _key(tester, LogicalKeyboardKey.tab);
  expect(_focused(), 'ScrollFocus');
}

Finder _row(String label) => find.byWidgetPredicate(
  (widget) => widget is Focus && widget.debugLabel == label,
  skipOffstage: false,
);

/// The position of the list that holds the row labeled [row].
ScrollPosition _listPosition(WidgetTester tester, String row) => tester
    .state<ScrollableState>(
      find.ancestor(of: _row(row), matching: find.byType(Scrollable)).first,
    )
    .position;

/// The Tab stop of the list that holds the row labeled [row].
FocusNode _listStopOf(String row) {
  final node = FocusManager.instance.rootScope.descendants.firstWhere(
    (node) => node.debugLabel == row,
  );
  return node.ancestors.firstWhere((node) => node.debugLabel == 'ScrollFocus');
}

/// A list that its tab keeps alive while another tab shows.
class _KeptAlive extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends State<_KeptAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A 200 px header that collapses to a 50 px bar pinned on top.
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  const new();

  /// The key of the header's box.
  static const ValueKey<String> bar = ValueKey('bar');

  @override
  double get minExtent => 50;

  @override
  double get maxExtent => _header;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return const SizedBox.expand(key: bar);
  }

  @override
  bool shouldRebuild(_PinnedHeader oldDelegate) => false;
}

void main() {
  group('NestedScrollViewLayout keys', () {
    testWidgets('Down collapses the header 50 px per press and then scrolls '
        'the list', (tester) async {
      final before = _node('before');
      await tester.pumpWidget(_nested(before: before));
      await _tabIn(tester, before);

      for (var press = 1; press <= 4; press++) {
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(_outer(tester).pixels, 50.0 * press);
        expect(_inner(tester).pixels, 0);
      }
      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(_outer(tester).pixels, _header);
      expect(_inner(tester).pixels, 50);
    }, variant: _desktop);

    testWidgets('under reduced motion Down jumps along the range '
        '(us07/fr04)', (tester) async {
      final before = _node('before');
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _nested(before: before),
        ),
      );
      await _tabIn(tester, before);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_outer(tester).pixels, 50);
      expect(_inner(tester).pixels, 0);
    }, variant: _desktop);

    testWidgets('a press across the header extent moves both positions', (
      tester,
    ) async {
      final before = _node('before');
      await tester.pumpWidget(_nested(before: before));
      await _tabIn(tester, before);
      _outer(tester).jumpTo(180);
      await tester.pumpAndSettle();

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_outer(tester).pixels, _header);
      expect(_inner(tester).pixels, 30);

      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_outer(tester).pixels, 180);
      expect(_inner(tester).pixels, 0);
    }, variant: _desktop);

    testWidgets('Page Down moves 0.8 of the inner viewport along the range', (
      tester,
    ) async {
      final before = _node('before');
      await tester.pumpWidget(_nested(before: before));
      await _tabIn(tester, before);

      final viewport = _inner(tester).viewportDimension;
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_outer(tester).pixels, 0.8 * viewport);
      expect(_inner(tester).pixels, 0);

      final offset =
          _outer(tester).pixels + 0.8 * _inner(tester).viewportDimension;
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_outer(tester).pixels, _header);
      expect(_inner(tester).pixels, offset - _header);
    }, variant: _desktop);

    testWidgets('End scrolls the list to its end and Home expands the header '
        'and returns the list to its start', (tester) async {
      final before = _node('before');
      await tester.pumpWidget(_nested(before: before));
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.end);
      expect(_outer(tester).pixels, _header);
      expect(_inner(tester).pixels, _inner(tester).maxScrollExtent);
      expect(_inner(tester).pixels, 100 * 40 - 300);

      await _key(tester, LogicalKeyboardKey.home);
      expect(_outer(tester).pixels, 0);
      expect(_inner(tester).pixels, 0);
    }, variant: _desktop);

    testWidgets('a body list with its own controller keeps lines behavior', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final before = _node('before');
      await tester.pumpWidget(
        _nested(
          before: before,
          body: _list(controller: controller),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(controller.offset, 50);
      expect(_outer(tester).pixels, 0);
    }, variant: _desktop);

    testWidgets('a body list in a plain NestedScrollView scrolls as one '
        'range', (tester) async {
      final before = _node('before');
      await tester.pumpWidget(
        _keyboardHost(
          NestedScrollView(headerSliverBuilder: _headerSlivers, body: _list()),
          before: before,
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(_outer(tester).pixels, 50);
      expect(_inner(tester).pixels, 0);
    }, variant: _desktop);
  });

  group('NestedScrollViewLayout focus', () {
    testWidgets('the layout is not a Tab stop; its body list is', (
      tester,
    ) async {
      final before = _node('before');
      await tester.pumpWidget(_nested(before: before));
      await _tabIn(tester, before);

      final stops = FocusManager.instance.rootScope.traversalDescendants.where(
        (node) => node.debugLabel == 'ScrollFocus',
      );
      expect(stops, hasLength(1));
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<ListViewLayout>(),
        isNotNull,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(_focused(), 'before');
    }, variant: _desktop);

    testWidgets('(pin) Tab into a row below the window reveals it', (
      tester,
    ) async {
      final before = _node('before');
      await tester.pumpWidget(_nested(before: before));
      await _tabIn(tester, before);

      for (var row = 0; row < 6; row++) {
        await _key(tester, LogicalKeyboardKey.tab);
        expect(_focused(), 'row $row');
        final rect = tester.getRect(_row('row $row'));
        final view = tester.getRect(find.byType(NestedScrollViewLayout));
        expect(view.top <= rect.top && rect.bottom <= view.bottom, isTrue);
      }
      expect(_outer(tester).pixels, greaterThan(0));
    }, variant: _desktop);
  });

  group('NestedScrollViewLayout tabs', () {
    testWidgets('a two-tab body keeps each list its own offset', (
      tester,
    ) async {
      final tabs = TabController(length: 2, vsync: const TestVSync());
      addTearDown(tabs.dispose);
      final before = _node('before');
      // A route's PageStorage keeps each list's offset while its tab is
      // away, as in an app.
      await tester.pumpWidget(
        _nested(
          before: before,
          body: PageStorage(
            bucket: PageStorageBucket(),
            child: TabBarView(
              controller: tabs,
              children: [
                _list(
                  key: const PageStorageKey('a'),
                  label: 'a',
                  showScrollbar: false,
                ),
                _list(
                  key: const PageStorageKey('b'),
                  label: 'b',
                  showScrollbar: false,
                ),
              ],
            ),
          ),
        ),
      );
      await _tabIn(tester, before);
      await _key(tester, LogicalKeyboardKey.end);
      final end = _inner(tester).pixels;
      expect(end, 100 * 40 - 300);

      tabs.animateTo(1);
      await tester.pumpAndSettle();
      _listStopOf('b 0').requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_outer(tester).pixels, _header);
      expect(_inner(tester).pixels, 50);

      tabs.animateTo(0);
      await tester.pumpAndSettle();
      expect(_inner(tester).pixels, end);
      tabs.animateTo(1);
      await tester.pumpAndSettle();
      expect(_inner(tester).pixels, 50);
    }, variant: _desktop);

    testWidgets('with both tabs attached, the keys move the list below the '
        'focus', (tester) async {
      final tabs = TabController(length: 2, vsync: const TestVSync());
      addTearDown(tabs.dispose);
      final before = _node('before');
      await tester.pumpWidget(
        _nested(
          before: before,
          body: TabBarView(
            controller: tabs,
            children: [
              _KeptAlive(child: _list(label: 'a', showScrollbar: false)),
              _KeptAlive(child: _list(label: 'b', showScrollbar: false)),
            ],
          ),
        ),
      );
      tabs.animateTo(1);
      await tester.pumpAndSettle();
      expect(_state(tester).innerController.positions, hasLength(2));
      _listStopOf('b 0').requestFocus();
      await tester.pump();
      _outer(tester).jumpTo(_header);
      await tester.pumpAndSettle();

      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(_listPosition(tester, 'b 0').pixels, 50);
    }, variant: _desktop);
  });

  group('NestedScrollViewLayout reveal', () {
    /// Expects [node] wholly inside the part of the scroll view around it
    /// that the nested scroll view shows: below the header, inside the
    /// window, and above anything below the scroll view in the body.
    void expectShown(WidgetTester tester, FocusNode node) {
      final box =
          Scrollable.of(node.context!).context.findRenderObject()! as RenderBox;
      final view = tester.getRect(find.byType(NestedScrollViewLayout));
      final shown = (box.localToGlobal(Offset.zero) & box.size).intersect(view);
      final rect = node.rect;
      expect(
        rect.top >= shown.top - 0.5 && rect.bottom <= shown.bottom + 0.5,
        isTrue,
        reason: '${node.debugLabel} at $rect, shown $shown',
      );
    }

    testWidgets(
      'a group arrow reveals the next item whole past either edge of the '
      'window',
      (tester) async {
        final items = [for (var i = 0; i < 12; i++) _node('item $i')];
        await tester.pumpWidget(
          _nested(
            before: _node('before'),
            body: ColumnLayout(
              scroll: const StratumScroll(),
              focusGroup: const StratumFocusGroup(),
              children: [
                for (final item in items)
                  Focus(
                    focusNode: item,
                    child: const SizedBox(width: 200, height: 40),
                  ),
              ],
            ),
          ),
        );
        // Under the 200 px header, the window shows the body's first
        // 100 px; item 2, at 80 to 120, ends 20 px below it.
        items[1].requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowDown);

        expect(items[2].hasPrimaryFocus, isTrue);
        expectShown(tester, items[2]);

        // Item 8, at 320 to 360, ends past the body's own 300 px viewport.
        items[7].requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowDown);

        expect(items[8].hasPrimaryFocus, isTrue);
        expectShown(tester, items[8]);

        // The body has scrolled past item 1, at 40 to 80.
        items[2].requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowUp);

        expect(items[1].hasPrimaryFocus, isTrue);
        expectShown(tester, items[1]);
      },
      variant: _desktop,
    );

    testWidgets(
      'a reorder move reveals the moved item whole past the window and past '
      "the body's own viewport",
      (tester) async {
        final nodes = [for (var i = 0; i < 12; i++) _node('item $i')];
        final ids = [for (var i = 0; i < 12; i++) i];
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: themedHost(
                SizedBox(
                  width: 200,
                  height: 300,
                  child: NestedScrollViewLayout(
                    headerSliverBuilder: _headerSlivers,
                    body: StatefulBuilder(
                      builder: (context, setState) =>
                          ReorderableListViewLayout.builder(
                            itemCount: ids.length,
                            onReorderItem: (from, to) => setState(
                              () => ids.insert(to, ids.removeAt(from)),
                            ),
                            itemBuilder: (context, index) => Focus(
                              key: ValueKey(ids[index]),
                              focusNode: nodes[ids[index]],
                              child: const SizedBox(height: 40),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Item 1 sits at 40 to 80 under the 200 px header; its next slot,
        // at 80 to 120, ends 20 px below the window.
        nodes[1].requestFocus();
        await tester.pump();

        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(ids.indexOf(1), 2);
        expect(nodes[1].hasPrimaryFocus, isTrue);
        expectShown(tester, nodes[1]);

        // Item 7's next slot, at 320 to 360, ends past the body's own
        // 300 px viewport.
        nodes[7].requestFocus();
        await tester.pump();

        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(ids.indexOf(7), 8);
        expect(nodes[7].hasPrimaryFocus, isTrue);
        expectShown(tester, nodes[7]);
      },
      variant: _desktop,
    );

    testWidgets(
      "Flutter's Down to a row past a list body's end moves the body once",
      (tester) async {
        await tester.pumpWidget(
          _keyboardHost(
            FocusTraversalGroup(
              child: NestedScrollViewLayout(
                headerSliverBuilder: _headerSlivers,
                body: _list(),
              ),
            ),
            before: _node('before'),
          ),
        );
        // The header has collapsed and the body shows 100 to 400, which
        // row 9 ends; row 10 ends 40 px past it.
        _inner(tester).jumpTo(100);
        await tester.pump();
        _focusNode('row 9').requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowDown);

        expect(_focused(), 'row 10');
        expect(_outer(tester).pixels, _header);
        expect(_inner(tester).pixels, 140);
      },
      variant: _desktop,
    );

    testWidgets("Shift+Tab reveals a row above a list body's start whole", (
      tester,
    ) async {
      await tester.pumpWidget(_nested(before: _node('before')));
      // The header has collapsed and the body shows 60 to 360; row 1, at
      // 40 to 80, starts 20 px above it.
      _inner(tester).jumpTo(60);
      await tester.pump();
      _focusNode('row 2').requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(_focused(), 'row 1');
      expectShown(tester, _focusNode('row 1'));
    }, variant: _desktop);

    // A 50 px gap below the list, inside the body.
    final gaps = <String, Widget Function(Widget list)>{
      'a footer': (list) => Column(
        children: [
          Expanded(child: list),
          const SizedBox(height: 50),
        ],
      ),
      'bottom padding': (list) =>
          Padding(padding: const EdgeInsets.only(bottom: 50), child: list),
    };
    for (final MapEntry(key: name, value: gap) in gaps.entries) {
      testWidgets(
        'Tab reveals a row whole in a list body with $name below it',
        (tester) async {
          await tester.pumpWidget(
            _nested(before: _node('before'), body: gap(_list())),
          );
          // Under the 200 px header the list shows 0 to 50, above the gap;
          // row 2, at 80 to 120, lies 70 px past that.
          _focusNode('row 1').requestFocus();
          await tester.pump();

          await _key(tester, LogicalKeyboardKey.tab);

          expect(_focused(), 'row 2');
          expectShown(tester, _focusNode('row 2'));
        },
        variant: _desktop,
      );
    }

    /// A nested scroll view 400 px wide, wider than its header, whose body
    /// is three lists, `a`, `b`, and `c`, in a tab view on [tabs], above a
    /// 50 px footer with [footer].
    Widget tabBody(TabController tabs, {bool footer = false}) {
      Widget body = TabBarView(
        controller: tabs,
        children: [
          for (final label in const ['a', 'b', 'c'])
            _list(label: label, showScrollbar: false),
        ],
      );
      if (footer) {
        body = Column(
          children: [
            Expanded(child: body),
            const SizedBox(height: 50),
          ],
        );
      }
      return _keyboardHost(
        NestedScrollViewLayout(headerSliverBuilder: _headerSlivers, body: body),
        before: _node('before'),
        width: 400,
      );
    }

    TabController tabsAt(int index) {
      final tabs = TabController(
        length: 3,
        vsync: const TestVSync(),
        initialIndex: index,
      );
      addTearDown(tabs.dispose);
      return tabs;
    }

    for (final (index, label) in const [(0, 'a'), (1, 'b'), (2, 'c')]) {
      testWidgets(
        'Tab to a visible row of tab $index in a tab view body moves nothing',
        (tester) async {
          await tester.pumpWidget(tabBody(tabsAt(index)));
          // Under the 200 px header the list shows 0 to 100; rows 0 and 1
          // lie inside.
          _focusNode('$label 0').requestFocus();
          await tester.pump();

          await _key(tester, LogicalKeyboardKey.tab);

          expect(_focused(), '$label 1');
          expect(_outer(tester).pixels, 0);
          expect(_inner(tester).pixels, 0);
        },
        variant: _desktop,
      );
    }

    testWidgets(
      'a second reveal in a tab view body before the next layout moves '
      'nothing',
      (tester) async {
        await tester.pumpWidget(tabBody(tabsAt(0)));
        // Row 2, at 80 to 120, ends 20 px below the list's 100 px.
        final row = _focusNode('a 2');

        revealInViewports(row);
        final outer = _outer(tester).pixels;
        final inner = _inner(tester).pixels;
        revealInViewports(row);

        expect(_outer(tester).pixels, outer);
        expect(_inner(tester).pixels, inner);
        await tester.pump();
        expectShown(tester, row);
      },
      variant: _desktop,
    );

    testWidgets(
      'Tab reveals a row whole in a tab view body with a footer below it',
      (tester) async {
        await tester.pumpWidget(tabBody(tabsAt(1), footer: true));
        // Under the 200 px header the list shows 0 to 50, above the
        // footer; row 2, at 80 to 120, lies 70 px past that.
        _focusNode('b 1').requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.tab);

        expect(_focused(), 'b 2');
        expectShown(tester, _focusNode('b 2'));
      },
      variant: _desktop,
    );

    testWidgets(
      'a reorder move that drops focus reveals the moved item whole',
      (tester) async {
        final ids = [for (var i = 0; i < 12; i++) i];
        // Each move rebuilds every item under a new key, so focus leaves
        // the list and the move focuses the item's first Tab stop.
        var moves = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: themedHost(
                SizedBox(
                  width: 200,
                  height: 300,
                  child: NestedScrollViewLayout(
                    headerSliverBuilder: _headerSlivers,
                    body: StatefulBuilder(
                      builder: (context, setState) =>
                          ReorderableListViewLayout.builder(
                            itemCount: ids.length,
                            onReorderItem: (from, to) => setState(() {
                              ids.insert(to, ids.removeAt(from));
                              moves++;
                            }),
                            itemBuilder: (context, index) => Focus(
                              key: ValueKey('${ids[index]} $moves'),
                              debugLabel: 'item ${ids[index]}',
                              child: const SizedBox(height: 40),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Item 1 sits at 40 to 80 under the 200 px header; its next slot,
        // at 80 to 120, ends 20 px below the window.
        _focusNode('item 1').requestFocus();
        await tester.pump();

        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(ids.indexOf(1), 2);
        expect(_focused(), 'item 1');
        expectShown(tester, _focusNode('item 1'));
      },
      variant: _desktop,
    );

    testWidgets(
      '(pin) a group arrow can leave an item under a pinned header, as '
      'FR-01 E02 documents',
      (tester) async {
        final items = [for (var i = 0; i < 20; i++) _node('item $i')];
        await tester.pumpWidget(
          _keyboardHost(
            NestedScrollViewLayout(
              headerSliverBuilder: (context, innerBoxIsScrolled) => const [
                SliverPersistentHeader(pinned: true, delegate: _PinnedHeader()),
              ],
              body: ColumnLayout(
                scroll: const StratumScroll(),
                focusGroup: const StratumFocusGroup(),
                children: [
                  for (final item in items)
                    Focus(
                      focusNode: item,
                      child: const SizedBox(width: 200, height: 40),
                    ),
                ],
              ),
            ),
            before: _node('before'),
          ),
        );
        // The header has collapsed to its 50 px bar, which the body scrolls
        // under; the body shows 220 on, and item 5, at 200 to 240, starts
        // 20 px above it.
        _inner(tester).jumpTo(220);
        await tester.pump();
        items[6].requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowUp);

        expect(items[5].hasPrimaryFocus, isTrue);
        final bar = tester.getRect(find.byKey(_PinnedHeader.bar));
        final rect = items[5].rect;
        expect(
          rect.top >= bar.top - 0.5 && rect.bottom <= bar.bottom + 0.5,
          isTrue,
          reason: 'item 5 at $rect, bar $bar',
        );
      },
      variant: _desktop,
    );
  });
}

/// The node labeled [label].
FocusNode _focusNode(String label) => FocusManager
    .instance
    .rootScope
    .descendants
    .firstWhere((node) => node.debugLabel == label);

/// Presses [key] with Alt held.
Future<void> _alt(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}
