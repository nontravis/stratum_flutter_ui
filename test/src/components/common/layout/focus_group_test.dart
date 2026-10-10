import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/focus_group.dart'
    show firstTabStopIn, revealInViewports;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _dot = SizedBox(width: 10, height: 10);

void _noop() {}

FocusNode _node([String? label]) {
  final node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

/// [count] focus nodes, disposed after the test.
List<FocusNode> _nodes([int count = 3]) {
  return [for (var i = 0; i < count; i++) _node('item $i')];
}

/// A 40 px tappable item on [node].
///
/// [tapTargetSize] defaults to the platform minimum (NFR-U05); a geometry
/// test that hardcodes this item's own 40 px bounds passes `shrinkWrap`.
Widget _item(
  FocusNode node, {
  SemanticsProperties? semantics,
  TapTargetSize tapTargetSize = TapTargetSize.platform,
}) {
  return ContainerLayout(
    style: const WidgetStyle(width: 40, height: 40),
    semantics: semantics,
    interaction: Interaction(
      onTap: _noop,
      focusNode: node,
      tapTargetSize: tapTargetSize,
    ),
  );
}

/// [child] between a focusable box before it and one after it, under the
/// app's default Tab, arrow, and activation keys.
Widget _host(Widget child, {required FocusNode before, FocusNode? after}) {
  return themedHost(
    Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(focusNode: before, child: _dot),
            child,
            if (after != null) Focus(focusNode: after, child: _dot),
          ],
        ),
      ),
    ),
  );
}

Future<void> _focus(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
}

Future<bool> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

Future<void> _tab(WidgetTester tester) async {
  await _key(tester, LogicalKeyboardKey.tab);
}

Future<void> _shiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// A toolbar row group, `[bold] [italic] [scroller: a, b] [color]`,
/// between a focusable box before it and one after it.
class _Toolbar {
  final FocusNode before = _node('before');
  final FocusNode bold = _node('bold');
  final FocusNode italic = _node('italic');
  final FocusNode a = _node('a');
  final FocusNode b = _node('b');
  final FocusNode color = _node('color');
  final FocusNode after = _node('after');

  /// The label of the node that holds primary focus; the scroller's own
  /// stop is `box`.
  String get focused {
    final primary = FocusManager.instance.primaryFocus;
    if (primary?.debugLabel == 'ScrollFocus') return 'box';
    return primary?.debugLabel ?? '-';
  }

  /// Pumps the toolbar, whose third member is the scroller that
  /// [scroller] builds from the items a and b.
  Future<void> pump(
    WidgetTester tester,
    Widget Function(List<Widget> items) scroller,
  ) async {
    await tester.pumpWidget(
      _host(
        RowLayout(
          mainAxisSize: MainAxisSize.min,
          focusGroup: const FocusGroup(),
          children: [
            _item(bold),
            _item(italic),
            SizedBox(
              width: 40,
              height: 100,
              child: scroller([_item(a), _item(b)]),
            ),
            _item(color),
          ],
        ),
        before: before,
        after: after,
      ),
    );
  }

  /// Presses each of [keys] in turn, expecting no error, and returns the
  /// focused node after each.
  Future<List<String>> press(
    WidgetTester tester,
    List<Future<void> Function(WidgetTester tester)> keys,
  ) async {
    final path = <String>[];
    for (final key in keys) {
      await key(tester);
      expect(tester.takeException(), isNull);
      path.add(focused);
    }
    return path;
  }
}

/// Ten 100 px items in a group inside a 200 px wide scrolling row under
/// [direction], with focus on the first item.
Future<List<FocusNode>> _scrollingRow(
  WidgetTester tester,
  TextDirection direction,
) async {
  final items = _nodes(10);
  await tester.pumpWidget(
    themedHost(
      SizedBox(
        width: 200,
        height: 50,
        child: RowLayout(
          style: const WidgetStyle(),
          scroll: const Scroll(),
          focusGroup: const FocusGroup(),
          children: [
            for (final node in items)
              Focus(
                focusNode: node,
                child: const SizedBox(width: 100, height: 50),
              ),
          ],
        ),
      ),
      textDirection: direction,
    ),
  );
  await _focus(tester, items[0]);
  return items;
}

/// Expects focus on [items] at [index], fully inside the viewport, which
/// has scrolled to [pixels].
void _expectRevealed(
  WidgetTester tester,
  List<FocusNode> items,
  int index,
  double pixels,
) {
  expect(items[index].hasPrimaryFocus, isTrue);
  final scrollable = find.byType(Scrollable);
  expect(tester.state<ScrollableState>(scrollable).position.pixels, pixels);
  final viewport = tester.getRect(scrollable);
  final rect = items[index].rect;
  expect(
    rect.left >= viewport.left - 0.5 && rect.right <= viewport.right + 0.5,
    isTrue,
    reason: 'item $index at $rect, viewport $viewport',
  );
}

/// [row] between two 300 px fillers in a 200 by 200 vertical scroll view
/// on [controller], under [textDirection], reversed with [reverse].
Widget _belowAndAbove(
  Widget row,
  ScrollController controller, {
  TextDirection textDirection = TextDirection.ltr,
  bool reverse = false,
}) {
  return themedHost(
    SizedBox(
      width: 200,
      height: 200,
      child: SingleChildScrollView(
        controller: controller,
        reverse: reverse,
        child: Column(
          children: [
            const SizedBox(height: 300),
            row,
            const SizedBox(height: 300),
          ],
        ),
      ),
    ),
    textDirection: textDirection,
  );
}

/// Ten 100 px cards in a group inside a 200 by 50 scrolling row.
Widget _scrollingCards(List<FocusNode> cards) {
  return SizedBox(
    width: 200,
    height: 50,
    child: RowLayout(
      style: const WidgetStyle(),
      scroll: const Scroll(),
      focusGroup: const FocusGroup(),
      children: [
        for (final card in cards)
          Focus(
            focusNode: card,
            child: const SizedBox(width: 100, height: 50),
          ),
      ],
    ),
  );
}

/// Expects focus on [node], fully inside the outer vertical scroll view,
/// which has scrolled to [pixels].
void _expectInPage(
  WidgetTester tester,
  FocusNode node,
  ScrollController controller,
  double pixels,
) {
  expect(node.hasPrimaryFocus, isTrue);
  expect(controller.offset, pixels);
  final page = tester.getRect(find.byType(SingleChildScrollView).first);
  final rect = node.rect;
  expect(
    rect.top >= page.top - 0.5 && rect.bottom <= page.bottom + 0.5,
    isTrue,
    reason: '${node.debugLabel} at $rect, page $page',
  );
}

ScrollController _controller() {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return controller;
}

/// The [Scrollable] of the only scrolling [RowLayout].
Finder get _rowScrollable => find.descendant(
  of: find.byType(RowLayout),
  matching: find.byType(Scrollable),
);

ScrollPosition _rowPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_rowScrollable).position;

/// Expects [node] fully inside the scrolling row's viewport, horizontally.
void _expectInRow(WidgetTester tester, FocusNode node) {
  final row = tester.getRect(_rowScrollable);
  final rect = node.rect;
  expect(
    rect.left >= row.left - 0.5 && rect.right <= row.right + 0.5,
    isTrue,
    reason: '${node.debugLabel} at $rect, row $row',
  );
}

/// [child], kept alive when it leaves its list's built range.
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
  group('FocusGroup Tab', () {
    testWidgets('Tab enters the group once, on the first item', (tester) async {
      final before = _node();
      final after = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
          after: after,
        ),
      );
      await _focus(tester, before);

      await _key(tester, LogicalKeyboardKey.tab);
      expect(items[0].hasPrimaryFocus, isTrue);

      await _key(tester, LogicalKeyboardKey.tab);
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('Tab returns to the item that last held focus', (tester) async {
      final before = _node();
      final after = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
          after: after,
        ),
      );
      await _focus(tester, items[2]);

      await _key(tester, LogicalKeyboardKey.tab);
      expect(after.hasPrimaryFocus, isTrue);
      await _shiftTab(tester);
      expect(items[2].hasPrimaryFocus, isTrue);

      await _focus(tester, before);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(items[2].hasPrimaryFocus, isTrue);
    });

    testWidgets('Tab and Shift+Tab leave the group from any item', (
      tester,
    ) async {
      final before = _node();
      final after = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          ColumnLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
          after: after,
        ),
      );

      await _focus(tester, items[1]);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(after.hasPrimaryFocus, isTrue);

      await _focus(tester, items[1]);
      await _shiftTab(tester);
      expect(before.hasPrimaryFocus, isTrue);
    });
  });

  group('FocusGroup arrows', () {
    testWidgets('Left and Right move by screen position in a row', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[0]);

      expect(await _key(tester, LogicalKeyboardKey.arrowRight), isTrue);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[2].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[1].hasPrimaryFocus, isTrue);
    });

    testWidgets('Left moves to the item on the left in a row under RTL', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[0]);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[0].hasPrimaryFocus, isTrue);
    });

    testWidgets('Up moves to the item above in a column laid out upwards', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          ColumnLayout(
            mainAxisSize: MainAxisSize.min,
            verticalDirection: VerticalDirection.up,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[0]);

      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(items[0].hasPrimaryFocus, isTrue);
    });

    testWidgets('arrows across the axis are left to Flutter', (tester) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[1]);

      await _key(tester, LogicalKeyboardKey.arrowUp);

      // Flutter's directional focus moved up, out of the group.
      expect(before.hasPrimaryFocus, isTrue);
    });

    testWidgets('Up and Down move to the nearest item of the next run in a '
        'wrap', (tester) async {
      final before = _node();
      final items = _nodes(5);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 100,
            child: WrapLayout(
              gap: 4,
              focusGroup: const FocusGroup(),
              children: [for (final node in items) _item(node)],
            ),
          ),
          before: before,
        ),
      );
      // Runs: items 0 and 1, items 2 and 3, item 4.
      await _focus(tester, items[1]);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(items[3].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(items[4].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(items[2].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[2].hasPrimaryFocus, isTrue);
    });

    testWidgets('Home and End move to the first and last item', (tester) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[1]);

      await _key(tester, LogicalKeyboardKey.end);
      expect(items[2].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.home);
      expect(items[0].hasPrimaryFocus, isTrue);
    });

    testWidgets('loop wraps past either end; without it the arrow is left '
        'to Flutter', (tester) async {
      final before = _node();
      final right = _node('right');
      final items = _nodes();
      Widget build({required bool loop}) => _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RowLayout(
              mainAxisSize: MainAxisSize.min,
              focusGroup: FocusGroup(loop: loop),
              children: [for (final node in items) _item(node)],
            ),
            Focus(focusNode: right, child: _dot),
          ],
        ),
        before: before,
      );

      await tester.pumpWidget(build(loop: true));
      await _focus(tester, items[2]);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[0].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[2].hasPrimaryFocus, isTrue);

      await tester.pumpWidget(build(loop: false));
      await _key(tester, LogicalKeyboardKey.arrowRight);

      // Flutter's directional focus moved right, out of the group.
      expect(right.hasPrimaryFocus, isTrue);
    });

    testWidgets('Up from the first run of a wrap is left to Flutter', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes(5);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 100,
            child: WrapLayout(
              gap: 4,
              focusGroup: const FocusGroup(),
              children: [for (final node in items) _item(node)],
            ),
          ),
          before: before,
        ),
      );
      // Runs: items 0 and 1, items 2 and 3, item 4.
      await _focus(tester, items[1]);

      await _key(tester, LogicalKeyboardKey.arrowUp);

      // Flutter's directional focus moved up, out of the group.
      expect(before.hasPrimaryFocus, isTrue);
    });

    testWidgets('group keys are skipped inside a TextField', (tester) async {
      final field = _node();
      final items = _nodes(1);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: themedHost(
              ColumnLayout(
                mainAxisSize: MainAxisSize.min,
                focusGroup: const FocusGroup(),
                children: [
                  SizedBox(width: 200, child: TextField(focusNode: field)),
                  _item(items[0]),
                ],
              ),
            ),
          ),
        ),
      );
      await _focus(tester, field);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.end);

      expect(field.hasPrimaryFocus, isTrue);
    });
  });

  group('FocusGroup fix round 1', () {
    testWidgets(
      'Right at the wrap end stays when another item lies right on screen',
      (tester) async {
        final before = _node();
        final items = _nodes(5);
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 100,
              child: WrapLayout(
                gap: 4,
                focusGroup: const FocusGroup(),
                children: [for (final node in items) _item(node)],
              ),
            ),
            before: before,
          ),
        );
        // Runs: items 0 and 1, items 2 and 3, item 4.
        await _focus(tester, items[4]);

        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(items[4].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(items[4].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(items[4].hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'Down in a column reaches the last item then after, without '
      'bouncing on stale directional history',
      (tester) async {
        final before = _node();
        final after = _node();
        final items = _nodes();
        await tester.pumpWidget(
          _host(
            ColumnLayout(
              mainAxisSize: MainAxisSize.min,
              focusGroup: const FocusGroup(),
              children: [for (final node in items) _item(node)],
            ),
            before: before,
            after: after,
          ),
        );
        await _focus(tester, items[0]);

        await _key(tester, LogicalKeyboardKey.arrowUp);
        expect(before.hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(items[0].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(items[1].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(items[2].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(after.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'Up then Right then Down in a row reaches after, without bouncing '
      'on stale directional history',
      (tester) async {
        final before = _node();
        final after = _node();
        final items = _nodes();
        await tester.pumpWidget(
          _host(
            RowLayout(
              mainAxisSize: MainAxisSize.min,
              focusGroup: const FocusGroup(),
              children: [for (final node in items) _item(node)],
            ),
            before: before,
            after: after,
          ),
        );
        await _focus(tester, items[1]);

        await _key(tester, LogicalKeyboardKey.arrowUp);
        expect(before.hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(items[1].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(items[2].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(after.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'loop contains wrap Up and Down past the first and last run',
      (tester) async {
        final before = _node();
        final items = _nodes(5);
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 100,
              child: WrapLayout(
                gap: 4,
                focusGroup: const FocusGroup(loop: true),
                children: [for (final node in items) _item(node)],
              ),
            ),
            before: before,
          ),
        );
        // Runs: items 0 and 1, items 2 and 3, item 4.
        await _focus(tester, items[1]);
        await _key(tester, LogicalKeyboardKey.arrowUp);
        expect(items[4].hasPrimaryFocus, isTrue);

        await _focus(tester, items[4]);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(items[0].hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'Down from the last item in a column without loop reaches after',
      (tester) async {
        final before = _node();
        final after = _node();
        final items = _nodes();
        await tester.pumpWidget(
          _host(
            ColumnLayout(
              mainAxisSize: MainAxisSize.min,
              focusGroup: const FocusGroup(),
              children: [for (final node in items) _item(node)],
            ),
            before: before,
            after: after,
          ),
        );
        await _focus(tester, items[2]);

        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(after.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'Home and End in a row under RTL move to the rightmost and '
      'leftmost item',
      (tester) async {
        final before = _node();
        final items = _nodes();
        await tester.pumpWidget(
          _host(
            RowLayout(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              focusGroup: const FocusGroup(),
              children: [for (final node in items) _item(node)],
            ),
            before: before,
          ),
        );
        await _focus(tester, items[1]);

        await _key(tester, LogicalKeyboardKey.home);
        expect(items[0].hasPrimaryFocus, isTrue);
        await _key(tester, LogicalKeyboardKey.end);
        expect(items[2].hasPrimaryFocus, isTrue);
      },
    );
  });

  group('FocusGroup in a horizontal scroll', () {
    testWidgets(
      'Right reveals each item under left-to-right text, then End and Home',
      (tester) async {
        final items = await _scrollingRow(tester, TextDirection.ltr);

        await _key(tester, LogicalKeyboardKey.arrowRight);
        _expectRevealed(tester, items, 1, 0);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        _expectRevealed(tester, items, 2, 100);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        _expectRevealed(tester, items, 3, 200);
        await _key(tester, LogicalKeyboardKey.end);
        _expectRevealed(tester, items, 9, 800);
        await _key(tester, LogicalKeyboardKey.home);
        _expectRevealed(tester, items, 0, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Left reveals each item under right-to-left text, then End and Home',
      (tester) async {
        final items = await _scrollingRow(tester, TextDirection.rtl);

        await _key(tester, LogicalKeyboardKey.arrowLeft);
        _expectRevealed(tester, items, 1, 0);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        _expectRevealed(tester, items, 2, 100);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        _expectRevealed(tester, items, 3, 200);
        await _key(tester, LogicalKeyboardKey.end);
        _expectRevealed(tester, items, 9, 800);
        await _key(tester, LogicalKeyboardKey.home);
        _expectRevealed(tester, items, 0, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('FocusGroup past the viewport', () {
    testWidgets('Right reveals a row group below a vertical viewport', (
      tester,
    ) async {
      final controller = _controller();
      final items = _nodes();
      await tester.pumpWidget(
        _belowAndAbove(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            // Sub-minimum 40 px items: this test's subject is reveal
            // geometry, not tap-target size (NFR-U05).
            children: [
              for (final node in items)
                _item(node, tapTargetSize: TapTargetSize.shrinkWrap),
            ],
          ),
          controller,
        ),
      );
      // The row spans 300 to 340, below the 200 px viewport.
      await _focus(tester, items[0]);

      await _key(tester, LogicalKeyboardKey.arrowRight);

      _expectInPage(tester, items[1], controller, 340 - 200);
    });

    testWidgets('Left reveals a row group above a vertical viewport', (
      tester,
    ) async {
      final controller = _controller();
      final items = _nodes();
      await tester.pumpWidget(
        _belowAndAbove(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(),
            // Sub-minimum 40 px items: this test's subject is reveal
            // geometry, not tap-target size (NFR-U05).
            children: [
              for (final node in items)
                _item(node, tapTargetSize: TapTargetSize.shrinkWrap),
            ],
          ),
          controller,
        ),
      );
      await _focus(tester, items[1]);
      // Scrolled to the end, 440, the row lies above the viewport.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      await _key(tester, LogicalKeyboardKey.arrowLeft);

      _expectInPage(tester, items[0], controller, 300);
    });

    testWidgets(
      'Left in a scrolling row group below a vertical viewport reveals the '
      'row in the outer view',
      (tester) async {
        final controller = _controller();
        final items = _nodes(10);
        await tester.pumpWidget(
          _belowAndAbove(
            SizedBox(
              width: 200,
              height: 50,
              child: RowLayout(
                style: const WidgetStyle(),
                scroll: const Scroll(),
                focusGroup: const FocusGroup(),
                children: [
                  for (final node in items)
                    Focus(
                      focusNode: node,
                      child: const SizedBox(width: 100, height: 50),
                    ),
                ],
              ),
            ),
            controller,
          ),
        );
        // Item 1 lies inside the row's own viewport; the row spans 300 to
        // 350, below the outer one.
        await _focus(tester, items[1]);

        await _key(tester, LogicalKeyboardKey.arrowLeft);

        _expectInPage(tester, items[0], controller, 350 - 200);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Right reveals the next card by the edge of each viewport: the end '
      'of the row and the start of the page',
      (tester) async {
        final controller = _controller();
        final items = _nodes(10);
        await tester.pumpWidget(
          _belowAndAbove(
            SizedBox(
              width: 200,
              height: 50,
              child: RowLayout(
                style: const WidgetStyle(),
                scroll: const Scroll(),
                focusGroup: const FocusGroup(),
                children: [
                  for (final node in items)
                    Focus(
                      focusNode: node,
                      child: const SizedBox(width: 100, height: 50),
                    ),
                ],
              ),
            ),
            controller,
          ),
        );
        await _focus(tester, items[3]);
        // The row shows cards 2 and 3, so card 4 lies past its end; the
        // page shows 320 to 520, so the row, at 300 to 350, extends past
        // the page's top.
        _rowPosition(tester).jumpTo(200);
        controller.jumpTo(320);
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowRight);

        expect(_rowPosition(tester).pixels, 300);
        _expectInRow(tester, items[4]);
        _expectInPage(tester, items[4], controller, 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Left reveals the next card by the edge of each viewport under '
      'right-to-left text: the end of the row and the start of the page',
      (tester) async {
        final controller = _controller();
        final items = _nodes(10);
        await tester.pumpWidget(
          _belowAndAbove(
            _scrollingCards(items),
            controller,
            textDirection: TextDirection.rtl,
          ),
        );
        await _focus(tester, items[3]);
        // The row shows cards 2 and 3 from its right edge, so card 4 lies
        // past its end on the left; the page shows 320 to 520, so the row,
        // at 300 to 350, extends past the page's top.
        _rowPosition(tester).jumpTo(200);
        controller.jumpTo(320);
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowLeft);

        expect(_rowPosition(tester).pixels, 300);
        _expectInRow(tester, items[4]);
        _expectInPage(tester, items[4], controller, 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Right reveals the next card by the edge of each viewport in a '
      'reversed page: the end of the row and the top of the page',
      (tester) async {
        final controller = _controller();
        final items = _nodes(10);
        await tester.pumpWidget(
          _belowAndAbove(_scrollingCards(items), controller, reverse: true),
        );
        await _focus(tester, items[3]);
        // The reversed page counts from the bottom of its 650 px content:
        // at 130 it shows 320 to 520, so the row, at 300 to 350, extends
        // past the page's top.
        _rowPosition(tester).jumpTo(200);
        controller.jumpTo(130);
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.arrowRight);

        expect(_rowPosition(tester).pixels, 300);
        _expectInRow(tester, items[4]);
        _expectInPage(tester, items[4], controller, 650 - 200 - 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'Tab from a group item to the stop after the group reveals it by the '
      'edge of each viewport: the end of the row and the start of the page',
      (tester) async {
        final controller = _controller();
        final cards = _nodes();
        final after = _node('after');
        Widget box(FocusNode node) => Focus(
          focusNode: node,
          child: const SizedBox(width: 100, height: 50),
        );
        await tester.pumpWidget(
          themedHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      children: [
                        const SizedBox(height: 300),
                        SizedBox(
                          width: 200,
                          height: 50,
                          child: RowLayout(
                            style: const WidgetStyle(),
                            scroll: const Scroll(),
                            children: [
                              RowLayout(
                                mainAxisSize: MainAxisSize.min,
                                focusGroup: const FocusGroup(),
                                children: [for (final card in cards) box(card)],
                              ),
                              box(after),
                            ],
                          ),
                        ),
                        const SizedBox(height: 300),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _focus(tester, cards[2]);
        // The row shows cards 1 and 2, so the stop after the group lies
        // past its end; the page shows 320 to 520, so the row, at 300 to
        // 350, extends past the page's top.
        _rowPosition(tester).jumpTo(100);
        controller.jumpTo(320);
        await tester.pump();

        await _tab(tester);

        expect(_rowPosition(tester).pixels, 200);
        _expectInRow(tester, after);
        _expectInPage(tester, after, controller, 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('FocusGroup with a focusable scroller member', () {
    final scrollers = <String, Widget Function(List<Widget> items)>{
      'ColumnLayout': (items) =>
          ColumnLayout(scroll: const Scroll(), children: items),
      'ListViewLayout': (items) => ListViewLayout.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    };
    for (final MapEntry(key: name, value: scroller) in scrollers.entries) {
      testWidgets(
        'Tab from an item inside a $name member moves to the next item, '
        'then leaves the group',
        (tester) async {
          final toolbar = _Toolbar();
          await toolbar.pump(tester, scroller);
          await _focus(tester, toolbar.a);

          final path = await toolbar.press(tester, [_tab, _tab]);

          expect(path, ['b', 'after']);
        },
        variant: TargetPlatformVariant.desktop(),
      );

      testWidgets(
        'Shift+Tab from an item inside a $name member moves to its stop, '
        'then leaves the group backwards',
        (tester) async {
          final toolbar = _Toolbar();
          await toolbar.pump(tester, scroller);
          await _focus(tester, toolbar.a);

          final path = await toolbar.press(tester, [_shiftTab, _shiftTab]);

          expect(path, ['box', 'before']);
        },
        variant: TargetPlatformVariant.desktop(),
      );

      testWidgets(
        'Tab from a member beside a $name member leaves the group',
        (tester) async {
          final toolbar = _Toolbar();
          await toolbar.pump(tester, scroller);
          await _focus(tester, toolbar.bold);

          final path = await toolbar.press(tester, [_tab]);

          expect(path, ['after']);
        },
        variant: TargetPlatformVariant.desktop(),
      );
    }
  });

  group('FocusGroup role', () {
    testWidgets('tabBar over items with role tab passes the debug check', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final before = _node();
      final items = _nodes(2);
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(role: SemanticsRole.tabBar),
            children: [
              for (var i = 0; i < items.length; i++)
                _item(
                  items[i],
                  semantics: SemanticsProperties(
                    role: SemanticsRole.tab,
                    selected: i == 0,
                    label: 'Tab $i',
                  ),
                ),
            ],
          ),
          before: before,
        ),
      );

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('tabBar over items without role tab fails the debug check', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final before = _node();
      final items = _nodes(2);
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const FocusGroup(role: SemanticsRole.tabBar),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );

      expect(
        tester.takeException().toString(),
        contains('Children of TabBar must have the tab role'),
      );
      handle.dispose();
    });
  });

  group('firstTabStopIn', () {
    testWidgets(
      'finds the first Tab stop below the viewport and scrolls to it only '
      'when reveal is true',
      (tester) async {
        final controller = _controller();
        final container = _node('container');
        final item = _node('item');
        await tester.pumpWidget(
          _belowAndAbove(
            Focus(
              focusNode: container,
              skipTraversal: true,
              child: Focus(focusNode: item, child: _dot),
            ),
            controller,
          ),
        );

        expect(firstTabStopIn(container, reveal: false), same(item));
        await tester.pump();
        expect(controller.offset, 0);

        expect(firstTabStopIn(container), same(item));
        await tester.pump();
        expect(controller.offset, 310 - 200);
      },
    );
  });

  group('revealInViewports', () {
    testWidgets(
      'with an origin away from the current offset, lands the target at '
      'the offset nearest the origin that shows it whole, clamped to the '
      'scroll extent',
      (tester) async {
        final controller = _controller();
        final boxes = _nodes(30);
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              height: 300,
              child: ListView(
                controller: controller,
                scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                children: [
                  for (final node in boxes)
                    Focus(focusNode: node, child: const SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        );
        controller.jumpTo(1000);
        await tester.pump();

        revealInViewports(
          boxes[20],
          origin: (position: controller.position, pixels: 0),
        );
        // Box 20's trailing edge, 540, the least scroll from 0: the edge
        // rule from the current offset, 1000, would give its leading
        // edge, 800.
        expect(controller.offset, 540);

        revealInViewports(
          boxes[29],
          origin: (position: controller.position, pixels: 5000),
        );
        // Box 29's leading edge, 1160, clamped to this Scrollable's
        // maxScrollExtent, 900: an origin past the extent never lands
        // past it either.
        expect(controller.offset, 900);
      },
    );

    testWidgets(
      'with an object taller than the viewport, lands its leading edge '
      'whatever the origin',
      (tester) async {
        final controller = _controller();
        final boxes = _nodes(31);
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              height: 300,
              child: ListView(
                controller: controller,
                scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                children: [
                  for (final node in boxes.take(30))
                    Focus(focusNode: node, child: const SizedBox(height: 40)),
                  Focus(
                    focusNode: boxes[30],
                    child: const SizedBox(height: 400),
                  ),
                ],
              ),
            ),
          ),
        );
        controller.jumpTo(0);
        await tester.pump();

        revealInViewports(
          boxes[30],
          origin: (position: controller.position, pixels: 50),
        );
        // Box 30 is 400 px tall, past the 300 px viewport: its leading
        // edge, 1200, not an offset the origin, 50, would clamp to.
        expect(controller.offset, 1200);
      },
    );

    testWidgets(
      "with an origin, jumps only the level it was read from: a target's "
      'own nested scrollable keeps the edge rule',
      (tester) async {
        final controller = _controller();
        final inner = _controller();
        final boxes = _nodes(30);
        final nested = _node('nested');
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              height: 300,
              child: ListView(
                controller: controller,
                scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                children: [
                  for (var i = 0; i < 20; i++)
                    Focus(
                      focusNode: boxes[i],
                      child: const SizedBox(height: 40),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 100,
                      height: 40,
                      child: ListView(
                        controller: inner,
                        scrollDirection: Axis.horizontal,
                        children: [
                          const SizedBox(width: 40, height: 40),
                          const SizedBox(width: 40, height: 40),
                          Focus(
                            focusNode: nested,
                            child: const SizedBox(width: 40, height: 40),
                          ),
                          const SizedBox(width: 40, height: 40),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 21; i < 30; i++)
                    Focus(
                      focusNode: boxes[i],
                      child: const SizedBox(height: 40),
                    ),
                ],
              ),
            ),
          ),
        );
        controller.jumpTo(1000);
        // Box 2 of the nested row, 80 to 120 of its own 100 px viewport,
        // already shows whole at 50: the edge rule asks nothing of it.
        inner.jumpTo(50);
        await tester.pump();

        revealInViewports(
          nested,
          origin: (position: controller.position, pixels: 0),
        );

        // The target's row, slot 20: its trailing edge, 540, the least
        // scroll from the origin the outer list was read at (G5).
        expect(controller.offset, 540);
        // The origin was read from the outer list, not this nested one:
        // it keeps the edge rule, and the target already shows whole, so
        // it never moves to where the origin, misread as its own, would
        // clamp it, 20.
        expect(inner.offset, 50);
      },
    );

    testWidgets(
      'with an origin whose own ScrollPosition a physics swap disposes, '
      'still jumps the level the Scrollable it survives on was read from, '
      'not the stale position (G5)',
      (tester) async {
        final controller = _controller();
        final boxes = _nodes(30);
        Widget list(ScrollPhysics? physics) => themedHost(
          SizedBox(
            height: 300,
            child: ListView(
              controller: controller,
              physics: physics,
              scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
              children: [
                for (final node in boxes)
                  Focus(focusNode: node, child: const SizedBox(height: 40)),
              ],
            ),
          ),
        );
        await tester.pumpWidget(list(null));
        controller.jumpTo(1000);
        await tester.pump();
        final origin = (position: controller.position, pixels: 0.0);

        // A physics the Scrollable tells apart from the default by type
        // makes it dispose and replace the position [origin] still holds;
        // the Scrollable itself, the level [origin] was read from, survives
        // the swap.
        await tester.pumpWidget(list(const NeverScrollableScrollPhysics()));

        revealInViewports(boxes[20], origin: origin);

        // Box 20's trailing edge, 540, the least scroll from the origin's
        // 0 (G5): the edge rule from the current offset, 1000, would give
        // its leading edge, 800, instead, the level's loss when the match
        // reads the stale position identity rather than the surviving
        // Scrollable.
        expect(controller.offset, 540);
      },
    );

    testWidgets('shows a target kept alive off screen with the least scroll', (
      tester,
    ) async {
      final boxes = _nodes(1000);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: themedHost(
              SizedBox(
                width: 200,
                height: 300,
                child: ListViewLayout.builder(
                  itemCount: 1000,
                  itemBuilder: (context, index) => _KeptAlive(
                    child: Focus(
                      focusNode: boxes[index],
                      child: const SizedBox(height: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position
            ..jumpTo(4000);
      await tester.pump();
      position.jumpTo(20000);
      await tester.pump();

      revealInViewports(boxes[103]);

      // Box 103's leading edge: the least scroll from 20000 that shows it
      // whole.
      expect(position.pixels, 4120);
    });
  });

  group('renames', () {
    test('renames: a StratumFocusGroup is a FocusGroup', () {
      // Testing the deprecated alias itself, so ignore the deprecation
      // warning.
      // ignore: deprecated_member_use_from_same_package
      const focusGroup = StratumFocusGroup(loop: true);

      expect(focusGroup, isA<FocusGroup>());
      expect(focusGroup.loop, isTrue);
    });
  });
}
