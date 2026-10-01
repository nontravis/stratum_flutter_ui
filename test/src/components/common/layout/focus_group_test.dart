import 'package:flutter_test/flutter_test.dart';
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
Widget _item(FocusNode node, {SemanticsProperties? semantics}) {
  return ContainerLayout(
    style: const WidgetStyle(width: 40, height: 40),
    semantics: semantics,
    interaction: StratumInteraction(onTap: _noop, focusNode: node),
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

Future<void> _shiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

void main() {
  group('StratumFocusGroup Tab', () {
    testWidgets('Tab enters the group once, on the first item', (tester) async {
      final before = _node();
      final after = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
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
            focusGroup: const StratumFocusGroup(),
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
            focusGroup: const StratumFocusGroup(),
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

  group('StratumFocusGroup arrows', () {
    testWidgets('Left and Right move by screen position in a row', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
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
            focusGroup: const StratumFocusGroup(),
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
            focusGroup: const StratumFocusGroup(),
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
            focusGroup: const StratumFocusGroup(),
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
              focusGroup: const StratumFocusGroup(),
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
            focusGroup: const StratumFocusGroup(),
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
              focusGroup: StratumFocusGroup(loop: loop),
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
              focusGroup: const StratumFocusGroup(),
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
                focusGroup: const StratumFocusGroup(),
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

  group('StratumFocusGroup role', () {
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
            focusGroup: const StratumFocusGroup(role: SemanticsRole.tabBar),
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
            focusGroup: const StratumFocusGroup(role: SemanticsRole.tabBar),
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
}
