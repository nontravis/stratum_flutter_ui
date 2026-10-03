import 'package:flutter_test/flutter_test.dart';
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

/// [child], 200 by 300, after a focusable box, under the app's default
/// Tab, arrow, and activation keys.
Widget _keyboardHost(Widget child, {required FocusNode before}) {
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
            SizedBox(width: 200, height: 300, child: child),
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
    /// Expects [node] wholly inside the nested scroll view, and the header
    /// and the body scrolled to [outer] and [inner].
    void expectRevealed(
      WidgetTester tester,
      FocusNode node, {
      required double outer,
      required double inner,
    }) {
      expect(node.hasPrimaryFocus, isTrue);
      expect(_outer(tester).pixels, outer);
      expect(_inner(tester).pixels, inner);
      final view = tester.getRect(find.byType(NestedScrollViewLayout));
      final rect = node.rect;
      expect(
        rect.top >= view.top - 0.5 && rect.bottom <= view.bottom + 0.5,
        isTrue,
        reason: '${node.debugLabel} at $rect, view $view',
      );
    }

    testWidgets(
      'a group arrow reveals the next item by collapsing the header, then '
      'by scrolling the body past it',
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

        expectRevealed(tester, items[2], outer: 20, inner: 0);

        // Item 8, at 320 to 360, ends past the body's own viewport.
        items[7].requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowDown);

        expectRevealed(tester, items[8], outer: _header, inner: 360 - 300);

        // The body shows 60 to 360; item 1, at 40 to 80, starts above it.
        items[2].requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowUp);

        expectRevealed(tester, items[1], outer: _header, inner: 40);
      },
      variant: _desktop,
    );

    testWidgets(
      'a reorder move reveals the moved item by collapsing the header, then '
      'by scrolling the body past it',
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
        expectRevealed(tester, nodes[1], outer: 20, inner: 0);

        // Item 7's next slot, at 320 to 360, ends past the body's own
        // viewport.
        nodes[7].requestFocus();
        await tester.pump();

        await _alt(tester, LogicalKeyboardKey.arrowDown);

        expect(ids.indexOf(7), 8);
        expectRevealed(tester, nodes[7], outer: _header, inner: 360 - 300);
      },
      variant: _desktop,
    );
  });
}

/// Presses [key] with Alt held.
Future<void> _alt(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}
