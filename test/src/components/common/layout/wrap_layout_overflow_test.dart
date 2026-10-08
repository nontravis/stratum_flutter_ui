import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_overflow.dart';
import 'package:stratum_ui/src/src.dart';

/// [child] at the top left of the view, [width] wide.
Widget _host(
  Widget child, {
  double width = 230,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: textDirection,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  );
}

/// Tag [i]: a 40 by 20 box that a screen reader reads as `tag <i>`.
Widget _tag(int i) => Semantics(
  key: ValueKey('tag $i'),
  container: true,
  label: 'tag $i',
  child: const SizedBox(width: 40, height: 20),
);

List<Widget> _tags(int count) => [for (var i = 0; i < count; i++) _tag(i)];

/// The "+N" child: 30 by 20, keyed `more`, read as `+<count>`.
Widget _more(BuildContext context, int count) => Semantics(
  container: true,
  child: SizedBox(
    key: const ValueKey('more'),
    width: 30,
    height: 20,
    child: Text('+$count'),
  ),
);

/// A wrap of [children] with a gap of 10 and a run gap of 6.
WrapLayout _wrap({
  int? maxRuns,
  int? maxChildren,
  Widget Function(BuildContext, int)? overflowBuilder = _more,
  StratumFocusGroup? focusGroup,
  WidgetStyle? style,
  required List<Widget> children,
}) {
  return WrapLayout(
    style: style,
    gap: 10,
    runGap: 6,
    maxRuns: maxRuns,
    maxChildren: maxChildren,
    overflowBuilder: overflowBuilder,
    focusGroup: focusGroup,
    children: children,
  );
}

/// The indices of the tags that show, built and onstage.
List<int> _shownTags() => [
  for (var i = 0; i < 20; i++)
    if (find.byKey(ValueKey('tag $i')).evaluate().isNotEmpty) i,
];

/// A 40 by 20 chip that the EndUser selects by tap.
class _Chip extends StatefulWidget {
  const new({super.key});

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool selected = false;

  void toggle() => setState(() => selected = !selected);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      child: const SizedBox(width: 40, height: 20),
    );
  }
}

List<Widget> _chips(int count) => [
  for (var i = 0; i < count; i++) _Chip(key: ValueKey('chip $i')),
];

/// A 10 by 10 box whose ticker calls [onTick] on every frame.
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

/// A 40 by 20 box that adds to [log], each time its [TickerMode] flips,
/// whether the flip came inside a render object's layout.
class _TickerWatch extends StatefulWidget {
  const new({super.key, required this.log});

  final List<bool> log;

  @override
  State<_TickerWatch> createState() => _TickerWatchState();
}

class _TickerWatchState extends State<_TickerWatch> {
  ValueListenable<TickerModeData>? _mode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = TickerMode.getValuesNotifier(context);
    if (mode == _mode) return;
    _mode?.removeListener(_flipped);
    _mode = mode..addListener(_flipped);
  }

  @override
  void dispose() {
    _mode?.removeListener(_flipped);
    super.dispose();
  }

  void _flipped() => widget.log.add(RenderObject.debugActiveLayout != null);

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}

/// Tag [i], keyed `tag <i>`, whose root reads its [TickerMode]: a
/// [SizedBox] [on] wide while on, a [ColoredBox] [off] wide while off,
/// both 20 high, so showing or hiding it swaps its render object and its
/// size.
Widget _swapTag(int i, {required double on, required double off}) => Builder(
  key: ValueKey('tag $i'),
  builder: (context) => TickerMode.valuesOf(context).enabled
      ? SizedBox(width: on, height: 20)
      : ColoredBox(
          color: const Color(0xFF000000),
          child: SizedBox(width: off, height: 20),
        ),
);

/// An [AssertionError] whose message contains every one of [parts].
Matcher _assertionNaming(List<String> parts) => throwsA(
  isA<AssertionError>().having(
    (error) => '${error.message}',
    'message',
    allOf([for (final part in parts) contains(part)]),
  ),
);

FocusNode _node(String label) {
  final node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

/// Tag [i], 40 by 20, that takes focus on [node].
Widget _focusTag(int i, FocusNode node) => Focus(
  key: ValueKey('tag $i'),
  focusNode: node,
  child: const SizedBox(width: 40, height: 20),
);

/// The "+N" child of [_more] on a focus node labeled `+N`.
Widget _focusMore(BuildContext context, int count) =>
    Focus(debugLabel: '+N', child: _more(context, count));

/// The label of the node that holds primary focus.
String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// [child] between two focusable boxes, [before] and [after], under the
/// app's default Tab and activation keys.
Widget _keyboardHost(
  Widget child, {
  required FocusNode before,
  required FocusNode after,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 230,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Focus(
                  focusNode: before,
                  child: const SizedBox(width: 10, height: 10),
                ),
                child,
                Focus(
                  focusNode: after,
                  child: const SizedBox(width: 10, height: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The labels a screen reader reads, in its order.
List<String> _readOut(WidgetTester tester) => [
  for (final node in tester.semantics.simulatedAccessibilityTraversal())
    if (node.label.isNotEmpty) node.label,
];

void main() {
  group('WrapLayout overflow (US-14)', () {
    testWidgets(
      'us14/s1: a wrap of 12 tags cut to two runs shows 8 tags and "+4" '
      'at the end of the second run',
      (tester) async {
        await tester.pumpWidget(_host(_wrap(maxRuns: 2, children: _tags(12))));

        expect(_shownTags(), [0, 1, 2, 3, 4, 5, 6, 7]);
        expect(find.text('+4'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('more'))),
          const Offset(200, 26),
        );
      },
    );

    testWidgets(
      'us14/s2, us14/fr01/e01, s03/inv37: the limit that hides more wins',
      (tester) async {
        await tester.pumpWidget(
          _host(_wrap(maxRuns: 2, maxChildren: 5, children: _tags(12))),
        );
        expect(_shownTags(), [0, 1, 2, 3, 4]);
        expect(find.text('+7'), findsOneWidget);

        await tester.pumpWidget(
          _host(_wrap(maxRuns: 2, maxChildren: 10, children: _tags(12))),
        );
        expect(_shownTags(), [0, 1, 2, 3, 4, 5, 6, 7]);
        expect(find.text('+4'), findsOneWidget);
      },
    );

    testWidgets(
      'us14/s3: a wrap whose 4 tags fit in one run shows them and no "+N"',
      (tester) async {
        await tester.pumpWidget(_host(_wrap(maxRuns: 2, children: _tags(4))));

        expect(_shownTags(), [0, 1, 2, 3]);
        expect(find.byKey(const ValueKey('more')), findsNothing);
      },
    );

    testWidgets(
      'us14/s11, us14/fr01/e06, s03/inv37: a limit or an overflowBuilder '
      'with scroll fails an assertion that names both, collapsed or '
      'expanded',
      (tester) async {
        const names = ['maxRuns', 'maxChildren', 'overflowBuilder', 'scroll'];
        expect(
          () => WrapLayout(
            maxRuns: 2,
            scroll: const StratumScroll(),
            children: const [],
          ),
          _assertionNaming(names),
        );
        expect(
          () => WrapLayout(
            maxChildren: 3,
            scroll: const StratumScroll(),
            children: const [],
          ),
          _assertionNaming(names),
        );
        expect(
          () => WrapLayout(
            overflowBuilder: _more,
            scroll: const StratumScroll(),
            children: const [],
          ),
          _assertionNaming(names),
        );
      },
    );

    testWidgets(
      'us14/s12, us14/fr01/e02, s03/inv37: a limit below its bound fails an '
      'assertion that states the bound',
      (tester) async {
        expect(
          () => WrapLayout(maxRuns: 0, children: const []),
          _assertionNaming(['maxRuns is at least 1']),
        );
        expect(
          () => WrapLayout(maxChildren: -1, children: const []),
          _assertionNaming(['maxChildren is at least 0']),
        );
      },
    );

    testWidgets(
      'us14/fr01/e05, s03/inv36: with no overflowBuilder and both limits '
      "null the wrap builds Flutter's Wrap; any of the three builds the "
      'overflow frame',
      (tester) async {
        await tester.pumpWidget(
          _host(_wrap(overflowBuilder: null, children: _tags(4))),
        );
        expect(find.byType(Wrap), findsOneWidget);
        expect(find.byType(WrapOverflowFrame), findsNothing);

        for (final wrap in [
          _wrap(maxRuns: 2, overflowBuilder: null, children: _tags(4)),
          _wrap(maxChildren: 2, overflowBuilder: null, children: _tags(4)),
          _wrap(children: _tags(4)),
        ]) {
          await tester.pumpWidget(_host(wrap));
          expect(find.byType(WrapOverflowFrame), findsOneWidget);
          expect(find.byType(Wrap), findsNothing);
        }
      },
    );

    testWidgets(
      'us14/fr01/e04: an overflowBuilder with both limits null shows every '
      'child and builds no overflow child',
      (tester) async {
        await tester.pumpWidget(_host(_wrap(children: _tags(12))));

        expect(_shownTags(), [for (var i = 0; i < 12; i++) i]);
        expect(find.byKey(const ValueKey('more')), findsNothing);
      },
    );

    testWidgets(
      's03/inv36: with overflowBuilder set, switching both limits between '
      'null and a value keeps the children mounted',
      (tester) async {
        Widget build(int? maxRuns) =>
            _host(_wrap(maxRuns: maxRuns, children: _chips(12)));
        await tester.pumpWidget(build(null));
        final chip = tester.state(find.byKey(const ValueKey('chip 9')));

        await tester.pumpWidget(build(2));
        expect(
          tester.state(
            find.byKey(const ValueKey('chip 9'), skipOffstage: false),
          ),
          same(chip),
        );
        await tester.pumpWidget(build(null));
        expect(tester.state(find.byKey(const ValueKey('chip 9'))), same(chip));
      },
    );

    testWidgets(
      's03/inv36: with no overflowBuilder, switching both limits between '
      'null and a value remounts the children',
      (tester) async {
        Widget build(int? maxRuns) => _host(
          _wrap(maxRuns: maxRuns, overflowBuilder: null, children: _chips(12)),
        );
        await tester.pumpWidget(build(2));
        final chip = tester.state(find.byKey(const ValueKey('chip 0')));

        await tester.pumpWidget(build(null));
        expect(
          tester.state(find.byKey(const ValueKey('chip 0'))),
          isNot(same(chip)),
        );
      },
    );

    testWidgets(
      "us01/fr02/e06: the wrap row's parameters reach the overflow frame",
      (tester) async {
        Widget more(BuildContext context, int count) => _more(context, count);
        await tester.pumpWidget(
          _host(
            SizedBox(
              height: 200,
              child: WrapLayout(
                direction: Axis.vertical,
                alignment: WrapAlignment.center,
                gap: 4,
                runAlignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                textDirection: TextDirection.rtl,
                verticalDirection: VerticalDirection.up,
                clipBehavior: Clip.hardEdge,
                maxRuns: 3,
                maxChildren: 7,
                overflowBuilder: more,
                children: _tags(12),
              ),
            ),
          ),
        );

        final frame = tester.widget<WrapOverflowFrame>(
          find.byType(WrapOverflowFrame),
        );
        expect(frame.direction, Axis.vertical);
        expect(frame.alignment, WrapAlignment.center);
        expect(frame.spacing, 4);
        expect(frame.runSpacing, 4);
        expect(frame.runAlignment, WrapAlignment.end);
        expect(frame.crossAxisAlignment, WrapCrossAlignment.center);
        expect(frame.textDirection, TextDirection.rtl);
        expect(frame.verticalDirection, VerticalDirection.up);
        expect(frame.clipBehavior, Clip.hardEdge);
        expect(frame.maxRuns, 3);
        expect(frame.maxChildren, 7);
        expect(frame.overflowBuilder, same(more));
        expect(frame.children, hasLength(12));
      },
    );

    testWidgets(
      'us14/fr01: a focus group and a box style wrap the overflow frame as '
      'they wrap a plain wrap',
      (tester) async {
        await tester.pumpWidget(
          _host(
            _wrap(
              maxRuns: 2,
              focusGroup: const StratumFocusGroup(),
              style: const WidgetStyle(),
              children: _tags(12),
            ),
          ),
        );

        expect(
          find.ancestor(
            of: find.byType(WrapOverflowFrame),
            matching: find.byType(FocusGroupFrame),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byType(WrapOverflowFrame),
            matching: find.byType(AnimatedStyledBox),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('WrapLayout hidden children (US-14 FR-03)', () {
    testWidgets(
      "us14/fr03, us14/fr03/e04, s03/inv39: a hidden child's ticker stops "
      'and ticks again when a limit change shows it',
      (tester) async {
        final ticks = [0, 0];
        Widget build(int? maxChildren) => _host(
          _wrap(
            maxChildren: maxChildren,
            children: [
              _Spinner(onTick: () => ticks[0]++),
              _Spinner(onTick: () => ticks[1]++),
            ],
          ),
        );
        await tester.pumpWidget(build(1));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        expect(ticks[0], greaterThan(0));
        expect(ticks[1], 0);

        await tester.pumpWidget(build(null));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        expect(ticks[1], greaterThan(0));
      },
    );

    testWidgets(
      'us14/s5, us14/fr03/e04: a chip selected before a collapse shows '
      'still selected after the expand',
      (tester) async {
        Widget build(int? maxRuns) =>
            _host(_wrap(maxRuns: maxRuns, children: _chips(12)));
        await tester.pumpWidget(build(null));
        await tester.tap(find.byKey(const ValueKey('chip 9')));
        await tester.pump();
        final chip = tester.state<_ChipState>(
          find.byKey(const ValueKey('chip 9')),
        );
        expect(chip.selected, isTrue);

        await tester.pumpWidget(build(2));
        expect(find.byKey(const ValueKey('chip 9')), findsNothing);
        await tester.pumpWidget(build(null));
        await tester.pumpAndSettle();

        expect(
          tester.state<_ChipState>(find.byKey(const ValueKey('chip 9'))),
          same(chip),
        );
        expect(chip.selected, isTrue);
      },
    );

    testWidgets(
      'us14/s7, us14/fr03/e05: Tab moves through the shown items and then '
      '"+4", never a hidden item',
      (tester) async {
        final nodes = [for (var i = 0; i < 12; i++) _node('tag $i')];
        final before = _node('before');
        await tester.pumpWidget(
          _keyboardHost(
            before: before,
            after: _node('after'),
            _wrap(
              maxRuns: 2,
              overflowBuilder: _focusMore,
              children: [
                for (final (i, node) in nodes.indexed) _focusTag(i, node),
              ],
            ),
          ),
        );
        before.requestFocus();
        await tester.pump();

        final visited = <String?>[];
        for (var i = 0; i < 10; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          visited.add(_focused());
        }

        expect(visited, [for (var i = 0; i < 8; i++) 'tag $i', '+N', 'after']);
      },
    );

    testWidgets(
      'us14/fr03/e05: Shift+Tab moves back through "+4" and the shown items, '
      'never a hidden item',
      (tester) async {
        final nodes = [for (var i = 0; i < 12; i++) _node('tag $i')];
        final after = _node('after');
        await tester.pumpWidget(
          _keyboardHost(
            before: _node('before'),
            after: after,
            _wrap(
              maxRuns: 2,
              overflowBuilder: _focusMore,
              children: [
                for (final (i, node) in nodes.indexed) _focusTag(i, node),
              ],
            ),
          ),
        );
        after.requestFocus();
        await tester.pump();

        final visited = <String?>[];
        for (var i = 0; i < 10; i++) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
          await tester.pump();
          visited.add(_focused());
        }

        expect(visited, [
          '+N',
          for (var i = 7; i >= 0; i--) 'tag $i',
          'before',
        ]);
      },
    );

    testWidgets(
      'us14/fr03, s03/inv39: a hidden child cannot take focus, and takes it '
      'once a limit change shows it',
      (tester) async {
        final hidden = _node('tag 9');
        Widget build(int? maxRuns) => _host(
          _wrap(
            maxRuns: maxRuns,
            children: [
              for (var i = 0; i < 12; i++)
                if (i == 9) _focusTag(9, hidden) else _tag(i),
            ],
          ),
        );
        await tester.pumpWidget(build(2));
        hidden.requestFocus();
        await tester.pump();
        expect(hidden.hasFocus, isFalse);

        await tester.pumpWidget(build(null));
        await tester.pumpAndSettle();
        hidden.requestFocus();
        await tester.pump();
        expect(hidden.hasFocus, isTrue);
      },
    );

    testWidgets(
      'us14/s9, us14/fr03, us14/fr03/e04, s03/inv39: a screen reader reads '
      'the shown items and "+4", never a hidden item',
      (tester) async {
        final handle = tester.ensureSemantics();
        final collapsed = [for (var i = 0; i < 8; i++) 'tag $i', '+4'];
        await tester.pumpWidget(_host(_wrap(maxRuns: 2, children: _tags(12))));
        expect(_readOut(tester), collapsed);

        await tester.pumpWidget(_host(_wrap(children: _tags(12))));
        await tester.pumpAndSettle();
        expect(_readOut(tester), [for (var i = 0; i < 12; i++) 'tag $i']);

        await tester.pumpWidget(_host(_wrap(maxRuns: 2, children: _tags(12))));
        await tester.pumpAndSettle();
        expect(_readOut(tester), collapsed);
        handle.dispose();
      },
    );

    testWidgets('keyed children reordered while some hide keep their State', (
      tester,
    ) async {
      Widget build(List<int> order) => _host(
        _wrap(
          maxChildren: 2,
          children: [for (final i in order) _Chip(key: ValueKey('chip $i'))],
        ),
      );
      await tester.pumpWidget(build([0, 1, 2, 3]));
      final moved = tester.state(
        find.byKey(const ValueKey('chip 3'), skipOffstage: false),
      );

      await tester.pumpWidget(build([3, 0, 1, 2]));

      expect(tester.state(find.byKey(const ValueKey('chip 3'))), same(moved));
      expect(find.byKey(const ValueKey('chip 1')), findsNothing);
      expect(
        find.byKey(const ValueKey('chip 1'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets(
      'a hidden child that calls setState rebuilds and stays hidden',
      (tester) async {
        await tester.pumpWidget(
          _host(_wrap(maxChildren: 1, children: _chips(2))),
        );
        final hidden = tester.state<_ChipState>(
          find.byKey(const ValueKey('chip 1'), skipOffstage: false),
        );
        expect(hidden.selected, isFalse);

        hidden.toggle();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(hidden.selected, isTrue);
        expect(find.byKey(const ValueKey('chip 1')), findsNothing);
      },
    );

    testWidgets(
      'us14/fr03/e04, s03/inv39: a focused child that a children change '
      'moves past the old cut keeps focus when the new cut still shows it',
      (tester) async {
        final nodes = [for (var i = 0; i < 12; i++) _node('tag $i')];
        Widget build({required bool inserted, required int maxChildren}) =>
            _host(
              _wrap(
                maxChildren: maxChildren,
                children: [
                  if (inserted) _tag(12),
                  for (final (i, node) in nodes.indexed) _focusTag(i, node),
                ],
              ),
            );
        await tester.pumpWidget(build(inserted: false, maxChildren: 8));
        nodes[7].requestFocus();
        await tester.pump();
        expect(nodes[7].hasFocus, isTrue);

        await tester.pumpWidget(build(inserted: true, maxChildren: 9));
        await tester.pump();

        expect(find.byKey(const ValueKey('tag 7')), findsOneWidget);
        expect(nodes[7].hasFocus, isTrue);
      },
    );

    testWidgets(
      's03/inv39: a shown child that a children change moves past the cut '
      'hides inside the layout of the new cut, never in the build before it',
      (tester) async {
        final flips = <bool>[];
        Widget build({required bool inserted}) => _host(
          _wrap(
            maxChildren: 8,
            children: [
              if (inserted) _tag(12),
              for (var i = 0; i < 12; i++)
                if (i == 7)
                  _TickerWatch(key: const ValueKey('tag 7'), log: flips)
                else
                  _tag(i),
            ],
          ),
        );
        await tester.pumpWidget(build(inserted: false));
        expect(flips, isEmpty);

        await tester.pumpWidget(build(inserted: true));

        expect(find.byKey(const ValueKey('tag 7')), findsNothing);
        expect(flips, [true]);
      },
    );

    testWidgets(
      'us14/fr03/e04, s03/inv39: an unkeyed focused child that a keyed '
      'insert moves past the old cut keeps focus and never flips when the '
      'new cut still shows it',
      (tester) async {
        final b = _node('b');
        final flips = <bool>[];
        // [A, tag 1, B] becomes [tag 0, A, tag 1, B]: Flutter matches the
        // unkeyed A and B from the end, so B's slot moves from index 2 to 3.
        Widget build({required bool inserted, required int maxChildren}) =>
            _host(
              _wrap(
                maxChildren: maxChildren,
                children: [
                  if (inserted) _tag(0),
                  const SizedBox(width: 40, height: 20),
                  _tag(1),
                  Focus(
                    focusNode: b,
                    child: _TickerWatch(log: flips),
                  ),
                ],
              ),
            );
        await tester.pumpWidget(build(inserted: false, maxChildren: 3));
        b.requestFocus();
        await tester.pump();
        expect(b.hasFocus, isTrue);

        await tester.pumpWidget(build(inserted: true, maxChildren: 4));
        await tester.pump();

        expect(b.hasFocus, isTrue);
        expect(flips, isEmpty);
      },
    );

    testWidgets(
      's03/inv39: an unkeyed child that a keyed insert moves past the cut '
      'hides inside the layout of the new cut, never in the build before it',
      (tester) async {
        final flips = <bool>[];
        Widget build({required bool inserted}) => _host(
          _wrap(
            maxChildren: 3,
            children: [
              if (inserted) _tag(0),
              const SizedBox(width: 40, height: 20),
              _tag(1),
              _TickerWatch(log: flips),
            ],
          ),
        );
        await tester.pumpWidget(build(inserted: false));
        expect(flips, isEmpty);

        await tester.pumpWidget(build(inserted: true));

        expect(find.byType(_TickerWatch), findsNothing);
        expect(flips, [true]);
      },
    );

    testWidgets(
      'a child whose root swaps its render object and size when a limit '
      'change shows it lays out at its shown size',
      (tester) async {
        Widget build(int? maxChildren) => _host(
          _wrap(
            maxChildren: maxChildren,
            children: [_tag(0), _swapTag(1, on: 40, off: 200)],
          ),
        );
        await tester.pumpWidget(build(1));
        expect(tester.takeException(), isNull);
        expect(_shownTags(), [0]);

        await tester.pumpWidget(build(null));

        expect(tester.takeException(), isNull);
        expect(_shownTags(), [0, 1]);
        final tag = find.byKey(const ValueKey('tag 1'));
        expect(tester.getRect(tag), const Rect.fromLTWH(50, 0, 40, 20));
        final wrap = tester.renderObject(find.byType(WrapOverflowFrame));
        expect(wrap.paintsChild(tester.renderObject(tag)), isTrue);
      },
    );

    testWidgets('a child that fits only while hidden reports the unsettled cut '
        'instead of cutting again', (tester) async {
      await tester.pumpWidget(
        _host(
          _wrap(
            maxRuns: 1,
            overflowBuilder: null,
            children: [_tag(0), _swapTag(1, on: 200, off: 40)],
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.toString(),
          'message',
          contains('changed its render object or size'),
        ),
      );
    });
  });
}
