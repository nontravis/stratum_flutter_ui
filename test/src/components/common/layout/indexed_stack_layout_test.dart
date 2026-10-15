import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

/// [child] after a focusable box, under the app's default Tab, arrow, and
/// activation keys.
Widget _keyboardHost(Widget child, {required FocusNode before}) {
  return _host(
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
            child,
          ],
        ),
      ),
    ),
  );
}

FocusNode _node(String label) {
  final node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

/// A 40 px box that can take focus on [node].
Widget _focusable(FocusNode node) {
  return Focus(focusNode: node, child: const SizedBox(width: 40, height: 40));
}

/// The label of the node that holds primary focus.
String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// Whether the node that holds primary focus lies wholly inside the
/// viewport of the one [Scrollable] on screen.
bool _focusInView(WidgetTester tester) {
  final view = tester.getRect(find.byType(Scrollable));
  final rect = FocusManager.instance.primaryFocus!.rect;
  return view.intersect(rect) == rect;
}

/// A stack of 200 by 300 that shows the focusable box on [outgoing] at
/// index 0 and, at index 1, a list of 100 focusable rows of 40 px, `row
/// <i>`, scrolled by [controller].
Widget _stackOfList(
  int index, {
  required FocusNode outgoing,
  required ScrollController controller,
  bool? focusable,
}) {
  return _host(
    SizedBox(
      width: 200,
      height: 300,
      child: IndexedStackLayout(
        index: index,
        sizing: StackFit.expand,
        children: [
          _focusable(outgoing),
          ListViewLayout.builder(
            controller: controller,
            focusable: focusable,
            itemCount: 100,
            itemBuilder: (context, i) =>
                Focus(debugLabel: 'row $i', child: const SizedBox(height: 40)),
          ),
        ],
      ),
    ),
  );
}

/// Shows the list of [_stackOfList] scrolled to [offset], then switches
/// to the box, focuses it, and switches back to the list.
Future<void> _switchIntoList(
  WidgetTester tester, {
  required double offset,
  bool? focusable,
}) async {
  final outgoing = _node('outgoing');
  final controller = ScrollController();
  addTearDown(controller.dispose);
  Widget build(int index) => _stackOfList(
    index,
    outgoing: outgoing,
    controller: controller,
    focusable: focusable,
  );
  await tester.pumpWidget(build(1));
  controller.jumpTo(offset);
  await tester.pump();
  await tester.pumpWidget(build(0));
  outgoing.requestFocus();
  await tester.pump();

  await tester.pumpWidget(build(1));
  await tester.pump();
}

void main() {
  group('IndexedStackLayout', () {
    testWidgets('fo06/us09/fr01: shows the child at index', (tester) async {
      await tester.pumpWidget(
        _host(
          const IndexedStackLayout(
            index: 1,
            children: [Text('zero'), Text('one'), Text('two')],
          ),
        ),
      );

      expect(find.text('one'), findsOneWidget);
      expect(find.text('zero'), findsNothing);
      expect(find.text('two'), findsNothing);
    });

    testWidgets('a null index shows none', (tester) async {
      await tester.pumpWidget(
        _host(
          const IndexedStackLayout(
            index: null,
            children: [Text('zero'), Text('one')],
          ),
        ),
      );

      expect(find.text('zero'), findsNothing);
      expect(find.text('one'), findsNothing);
    });

    testWidgets('a Positioned child lays out in the stack', (tester) async {
      await tester.pumpWidget(
        _host(
          const IndexedStackLayout(
            style: WidgetStyle(width: 100, height: 100),
            children: [
              Positioned(
                left: 10,
                top: 20,
                child: SizedBox(key: ValueKey('dot'), width: 10, height: 10),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final box = tester.getTopLeft(find.byType(IndexedStackLayout));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('dot'))),
        box + const Offset(10, 20),
      );
    });

    testWidgets("a hidden child's ticker stops and ticks again when shown", (
      tester,
    ) async {
      final ticks = <int>[0, 0];
      Widget build(int index) => _host(
        IndexedStackLayout(
          index: index,
          children: [
            _Spinner(onTick: () => ticks[0]++),
            _Spinner(onTick: () => ticks[1]++),
          ],
        ),
      );

      await tester.pumpWidget(build(0));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ticks[0], greaterThan(0));
      expect(ticks[1], 0);

      await tester.pumpWidget(build(1));
      final hidden = ticks[0];
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ticks[0], hidden);
      expect(ticks[1], greaterThan(0));

      await tester.pumpWidget(build(0));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ticks[0], greaterThan(hidden));
    });

    testWidgets('(pin) a hidden child cannot take focus', (tester) async {
      final hidden = _node('hidden');
      await tester.pumpWidget(
        _host(
          IndexedStackLayout(
            children: [_focusable(_node('shown')), _focusable(hidden)],
          ),
        ),
      );

      hidden.requestFocus();
      await tester.pump();

      expect(hidden.hasFocus, isFalse);
    });

    testWidgets('(pin) a hidden child is absent from semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const IndexedStackLayout(children: [Text('shown'), Text('hidden')]),
        ),
      );

      expect(find.bySemanticsLabel('shown'), findsOneWidget);
      expect(find.bySemanticsLabel('hidden'), findsNothing);
      handle.dispose();
    });

    testWidgets(
      'fo06/us09/fr02, fo06/us09/s1: focus inside the outgoing child moves '
      "to the incoming child's first node",
      (tester) async {
        final outgoing = _node('outgoing');
        final first = _node('incoming first');
        final second = _node('incoming second');
        Widget build(int index) => _host(
          IndexedStackLayout(
            index: index,
            children: [
              _focusable(outgoing),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [_focusable(first), _focusable(second)],
              ),
            ],
          ),
        );
        await tester.pumpWidget(build(0));
        outgoing.requestFocus();
        await tester.pump();

        await tester.pumpWidget(build(1));
        await tester.pump();

        expect(_focused(), 'incoming first');
      },
    );

    testWidgets("focus moves to the Tab stop of the incoming child's scrolled "
        'focusable list, on screen', (tester) async {
      await _switchIntoList(tester, offset: 400);

      expect(_focused(), 'ScrollFocus');
      expect(_focusInView(tester), isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'focus moves to the first row of a scrolled list that is not a Tab '
      'stop and reveals it',
      (tester) async {
        await _switchIntoList(tester, offset: 400, focusable: false);

        // The list builds rows above its viewport; the first of them comes
        // first in Tab order.
        expect(_focused(), 'row 3');
        expect(_focusInView(tester), isTrue);
      },
    );

    testWidgets(
      'focus moves to the entry of a focus group in the incoming child: '
      'the item that last held focus',
      (tester) async {
        final outgoing = _node('outgoing');
        final items = [
          for (final label in ['a', 'b', 'c']) _node(label),
        ];
        Widget build(int index) => _host(
          IndexedStackLayout(
            index: index,
            children: [
              _focusable(outgoing),
              RowLayout(
                focusGroup: const FocusGroup(),
                children: [for (final item in items) _focusable(item)],
              ),
            ],
          ),
        );
        await tester.pumpWidget(build(1));
        items[1].requestFocus();
        await tester.pump();
        await tester.pumpWidget(build(0));
        await tester.pump();
        expect(_focused(), 'outgoing');

        await tester.pumpWidget(build(1));
        await tester.pump();

        expect(_focused(), 'b');
      },
    );

    testWidgets(
      'focus inside the outgoing child moves to the stack node when the '
      'incoming child has none, and Tab moves on from there',
      (tester) async {
        final outgoing = _node('outgoing');
        final after = _node('after');
        Widget build(int? index) => _host(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IndexedStackLayout(
                    index: index,
                    children: [_focusable(outgoing), const Text('none')],
                  ),
                  _focusable(after),
                ],
              ),
            ),
          ),
        );
        await tester.pumpWidget(build(0));
        outgoing.requestFocus();
        await tester.pump();

        await tester.pumpWidget(build(1));
        await tester.pump();
        expect(_focused(), 'IndexedStackLayout');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focused(), 'after');
      },
    );

    testWidgets('a null index also hands focus to the stack node', (
      tester,
    ) async {
      final outgoing = _node('outgoing');
      Widget build(int? index) => _host(
        IndexedStackLayout(index: index, children: [_focusable(outgoing)]),
      );
      await tester.pumpWidget(build(0));
      outgoing.requestFocus();
      await tester.pump();

      await tester.pumpWidget(build(null));
      await tester.pump();

      expect(_focused(), 'IndexedStackLayout');
    });

    testWidgets('focus outside the stack stays where it is', (tester) async {
      final tabs = _node('tabs');
      Widget build(int index) => _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _focusable(tabs),
            IndexedStackLayout(
              index: index,
              children: [
                _focusable(_node('page 0')),
                _focusable(_node('page 1')),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(build(0));
      tabs.requestFocus();
      await tester.pump();

      await tester.pumpWidget(build(1));
      await tester.pump();

      expect(_focused(), 'tabs');
    });

    testWidgets('scroll makes the box a Tab stop whose keys scroll it', (
      tester,
    ) async {
      final before = _node('before');
      await tester.pumpWidget(
        _keyboardHost(
          const IndexedStackLayout(
            style: WidgetStyle(width: 200, height: 100),
            scroll: Scroll(),
            children: [SizedBox(width: 200, height: 1000)],
          ),
          before: before,
        ),
      );
      before.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused(), 'ScrollFocus');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, 50);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}

/// Counts the ticks of a repeating animation.
class _Spinner extends StatefulWidget {
  const new({required this.onTick});

  final VoidCallback onTick;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(widget.onTick);

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}
