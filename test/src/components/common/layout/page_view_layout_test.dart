import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

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

/// A page of two focusable rows, `p<page>.0` and `p<page>.1`, 40 by 40 at
/// the page's start. Tab's own reveal of a row in the next page scrolls
/// only 40 px, after which page snapping alone would slide back to the
/// page before.
Widget _page(int page) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final row in [0, 1])
        Focus(
          debugLabel: 'p$page.$row',
          child: const SizedBox(width: 40, height: 40),
        ),
    ],
  );
}

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// The page the view shows, from its offset; the page view's scrollable is
/// the first, above any inside the pages.
double _shown(WidgetTester tester) {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  return position.pixels / position.viewportDimension;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  group('PageViewLayout', () {
    testWidgets('builds pages from children', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const SizedBox(
            width: 200,
            height: 300,
            child: PageViewLayout(children: [Text('zero'), Text('one')]),
          ),
        ),
      );

      expect(find.text('zero'), findsOneWidget);
      expect(find.text('one'), findsNothing);
    });

    testWidgets('builds pages from itemBuilder', (tester) async {
      await tester.pumpWidget(
        themedHost(
          SizedBox(
            width: 200,
            height: 300,
            child: PageViewLayout.builder(
              itemCount: 3,
              itemBuilder: (context, index) => Text('page $index'),
            ),
          ),
        ),
      );

      expect(find.text('page 0'), findsOneWidget);
    });

    testWidgets(
      'fo06/us10/fr03: style.padding insets the viewport and does not '
      'scroll',
      (tester) async {
        final controller = PageController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              width: 200,
              height: 300,
              child: PageViewLayout(
                controller: controller,
                style: const WidgetStyle(padding: EdgeInsets.all(10)),
                children: const [Text('zero'), Text('one')],
              ),
            ),
          ),
        );
        final box = tester.getRect(find.byType(PageViewLayout));

        expect(tester.getRect(find.byType(Scrollable)), box.deflate(10));
        controller.jumpToPage(1);
        await tester.pump();
        expect(tester.getRect(find.byType(Scrollable)), box.deflate(10));
        expect(tester.getTopLeft(find.text('one')), box.deflate(10).topLeft);
      },
    );

    testWidgets("the caller's PageController drives the keys", (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final before = _node('before');
      await tester.pumpWidget(
        _keyboardHost(
          PageViewLayout(
            controller: controller,
            children: [_page(0), _page(1)],
          ),
          before: before,
        ),
      );
      before.requestFocus();
      await tester.pump();

      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(), 'ScrollFocus');
      await _key(tester, LogicalKeyboardKey.arrowRight);

      expect(controller.page, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'fo06/us10/fr02, fo06/us10/s5: Page Down from an item moves focus to '
      "the new page's first node",
      (tester) async {
        final before = _node('before');
        await tester.pumpWidget(
          _keyboardHost(
            PageViewLayout(children: [_page(0), _page(1), _page(2)]),
            before: before,
          ),
        );
        before.requestFocus();
        await tester.pump();
        await _key(tester, LogicalKeyboardKey.tab);
        await _key(tester, LogicalKeyboardKey.tab);
        await _key(tester, LogicalKeyboardKey.tab);
        expect(_focused(), 'p0.1');

        await _key(tester, LogicalKeyboardKey.pageDown);

        expect(_shown(tester), 1);
        expect(_focused(), 'p1.0');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Page Down from an item moves focus to the Tab stop of a focusable '
      'list that starts the new page',
      (tester) async {
        final before = _node('before');
        await tester.pumpWidget(
          _keyboardHost(
            PageViewLayout(
              children: [
                _page(0),
                ListViewLayout.builder(
                  itemCount: 20,
                  itemBuilder: (context, i) => Focus(
                    debugLabel: 'row $i',
                    child: const SizedBox(height: 40),
                  ),
                ),
              ],
            ),
            before: before,
          ),
        );
        before.requestFocus();
        await tester.pump();
        await _key(tester, LogicalKeyboardKey.tab);
        await _key(tester, LogicalKeyboardKey.tab);
        expect(_focused(), 'p0.0');

        await _key(tester, LogicalKeyboardKey.pageDown);

        expect(_shown(tester), 1);
        final primary = FocusManager.instance.primaryFocus!;
        expect(primary.debugLabel, 'ScrollFocus');
        expect(
          primary.context!.findAncestorWidgetOfExactType<ListViewLayout>(),
          isNotNull,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('End from an item jumps and moves focus to the last page', (
      tester,
    ) async {
      final before = _node('before');
      await tester.pumpWidget(
        _keyboardHost(
          PageViewLayout(children: [_page(0), _page(1), _page(2)]),
          before: before,
        ),
      );
      before.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(), 'p0.0');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(_shown(tester), 2);
      await tester.pump();

      expect(_focused(), 'p2.0');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('focus moves to the page view when the new page has no node', (
      tester,
    ) async {
      final before = _node('before');
      await tester.pumpWidget(
        _keyboardHost(
          PageViewLayout(children: [_page(0), const Text('empty')]),
          before: before,
        ),
      );
      before.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(), 'p0.0');

      await _key(tester, LogicalKeyboardKey.pageDown);

      expect(_shown(tester), 1);
      expect(_focused(), 'ScrollFocus');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'with allowImplicitScrolling, Tab visits every node of page 0 before '
      'page 1, and Tab into page 1 shows it whole',
      (tester) async {
        final before = _node('before');
        await tester.pumpWidget(
          _keyboardHost(
            PageViewLayout(
              allowImplicitScrolling: true,
              children: [_page(0), _page(1), _page(2)],
            ),
            before: before,
          ),
        );
        before.requestFocus();
        await tester.pump();

        final path = <String?>[];
        for (var i = 0; i < 4; i++) {
          await _key(tester, LogicalKeyboardKey.tab);
          path.add(_focused());
        }
        expect(path, ['ScrollFocus', 'p0.0', 'p0.1', 'p1.0']);
        expect(_shown(tester), 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('onPageChanged reports the new page', (tester) async {
      final pages = <int>[];
      final before = _node('before');
      await tester.pumpWidget(
        _keyboardHost(
          PageViewLayout(
            onPageChanged: pages.add,
            children: [_page(0), _page(1)],
          ),
          before: before,
        ),
      );
      before.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.tab);

      await _key(tester, LogicalKeyboardKey.arrowRight);

      expect(pages, [1]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("findChildIndexCallback receives the page's own key", (
      tester,
    ) async {
      final keys = <Key>[];
      Widget build() => themedHost(
        SizedBox(
          width: 200,
          height: 300,
          child: PageViewLayout.builder(
            itemCount: 2,
            findChildIndexCallback: (key) {
              keys.add(key);
              return null;
            },
            itemBuilder: (context, index) =>
                Text('page $index', key: ValueKey('page $index')),
          ),
        ),
      );
      await tester.pumpWidget(build());

      await tester.pumpWidget(build());

      expect(keys, contains(const ValueKey('page 0')));
    });

    testWidgets(
      'showScrollbar: null shows no scrollbar, as a PageView, and true '
      'shows one',
      (tester) async {
        Widget build(bool? showScrollbar) => themedHost(
          Theme(
            data: ThemeData(platform: TargetPlatform.macOS),
            child: SizedBox(
              width: 200,
              height: 300,
              child: PageViewLayout(
                scrollDirection: Axis.vertical,
                showScrollbar: showScrollbar,
                children: const [Text('zero'), Text('one')],
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(null));
        expect(find.byType(Scrollbar), findsNothing);
        await tester.pumpWidget(build(true));
        expect(find.byType(Scrollbar), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });
}
