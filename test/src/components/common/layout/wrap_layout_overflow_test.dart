import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_overflow.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

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

/// Tag [i], keyed `tag <i>`, whose root reads its [TickerMode]: a box 40
/// wide, 40 high while on and 20 while off, so showing it makes its run
/// taller.
Widget _tallWhileOnTag(int i) => Builder(
  key: ValueKey('tag $i'),
  builder: (context) => SizedBox(
    width: 40,
    height: TickerMode.valuesOf(context).enabled ? 40 : 20,
  ),
);

/// Tag `i`, keyed `tag <i>`: a box 40 wide whose height its State's
/// `grow` sets.
class _GrowingTag extends StatefulWidget {
  new(int i) : super(key: ValueKey('tag $i'));

  @override
  State<_GrowingTag> createState() => _GrowingTagState();
}

class _GrowingTagState extends State<_GrowingTag> {
  double _height = 20;

  void grow(double height) => setState(() => _height = height);

  @override
  Widget build(BuildContext context) => SizedBox(width: 40, height: _height);
}

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

/// The height of the one wrap on screen.
double _height(WidgetTester tester) =>
    tester.getSize(find.byType(WrapLayout)).height;

/// [Curves.easeInOutSine] at half time: the midpoint of a size move.
final double _mid = Curves.easeInOutSine.transform(0.5);

/// The rect of the widget keyed [key], from the top left of the one wrap.
Rect _rectIn(WidgetTester tester, String key) => tester
    .getRect(find.byKey(ValueKey(key)))
    .shift(-tester.getTopLeft(find.byType(WrapOverflowFrame)));

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

  group('WrapLayout focus after a limit change (US-14 FR-03, R5, R6)', () {
    /// Twelve tags on [nodes], tag 9 always focusable, cut to [maxRuns].
    Widget build(
      int? maxRuns,
      List<FocusNode> nodes, {
      Widget Function(BuildContext, int) overflowBuilder = _focusMore,
      bool focusableTags = true,
    }) {
      return _wrap(
        maxRuns: maxRuns,
        overflowBuilder: overflowBuilder,
        children: [
          for (var i = 0; i < 12; i++)
            if (focusableTags || i == 9) _focusTag(i, nodes[i]) else _tag(i),
        ],
      );
    }

    List<FocusNode> twelve() => [for (var i = 0; i < 12; i++) _node('tag $i')];

    testWidgets(
      'us14/s10, us14/fr03/e01, s03/inv39: focus on a tag a collapse hides '
      'moves to the "+N" item after the frame',
      (tester) async {
        final nodes = twelve();
        await tester.pumpWidget(_host(build(null, nodes)));
        nodes[9].requestFocus();
        await tester.pump();
        expect(_focused(), 'tag 9');

        await tester.pumpWidget(_host(build(2, nodes)));
        await tester.pump();

        expect(_focused(), '+N');
      },
    );

    testWidgets(
      'us14/fr03/e01: with no focusable "+N" item, focus moves to the '
      "last shown child's first node",
      (tester) async {
        final nodes = twelve();
        await tester.pumpWidget(
          _host(build(null, nodes, overflowBuilder: _more)),
        );
        nodes[9].requestFocus();
        await tester.pump();

        await tester.pumpWidget(_host(build(2, nodes, overflowBuilder: _more)));
        await tester.pump();

        expect(_focused(), 'tag 7');
      },
    );

    testWidgets(
      "us14/fr03/e06: with neither node focusable, focus moves to the wrap's "
      'own node, and Tab moves on from there',
      (tester) async {
        final nodes = twelve();
        final before = _node('before');
        Widget host(int? maxRuns) => _keyboardHost(
          before: before,
          after: _node('after'),
          build(maxRuns, nodes, overflowBuilder: _more, focusableTags: false),
        );
        await tester.pumpWidget(host(null));
        nodes[9].requestFocus();
        await tester.pump();

        await tester.pumpWidget(host(2));
        await tester.pump();
        expect(_focused(), 'WrapLayout');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focused(), 'after');
      },
    );

    testWidgets('us14/fr03: focus outside the hidden children stays put', (
      tester,
    ) async {
      final nodes = twelve();
      await tester.pumpWidget(_host(build(null, nodes)));
      nodes[1].requestFocus();
      await tester.pump();

      await tester.pumpWidget(_host(build(2, nodes)));
      await tester.pump();

      expect(_focused(), 'tag 1');
    });

    testWidgets(
      'us14/fr03/e01, s03/inv39: a focused child keyed by a GlobalKey that '
      'moves into the wrap past the cut hands focus on after the frame',
      (tester) async {
        final nodes = twelve();
        final moved = _node('moved');
        final key = GlobalKey();
        // The moved child arrives in a new slot seeded hidden, so no flip
        // of the cut ever drops its focus.
        Widget host({required bool inside}) {
          final child = Focus(
            key: key,
            focusNode: moved,
            child: const SizedBox(width: 40, height: 20),
          );
          return _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _wrap(
                  maxChildren: 8,
                  overflowBuilder: _focusMore,
                  children: [
                    for (final (i, node) in nodes.indexed) _focusTag(i, node),
                    if (inside) child,
                  ],
                ),
                if (!inside) child,
              ],
            ),
          );
        }

        await tester.pumpWidget(host(inside: false));
        moved.requestFocus();
        await tester.pump();
        expect(_focused(), 'moved');

        await tester.pumpWidget(host(inside: true));
        await tester.pump();

        expect(find.byKey(key), findsNothing);
        expect(_focused(), '+N');
      },
    );

    testWidgets(
      'us14/s8, us14/fr03/e03: End in a wrap focus group moves to "+4", '
      'left to right and right to left',
      (tester) async {
        final nodes = twelve();
        for (final textDirection in TextDirection.values) {
          await tester.pumpWidget(
            _host(
              textDirection: textDirection,
              _wrap(
                maxRuns: 2,
                focusGroup: const StratumFocusGroup(),
                overflowBuilder: _focusMore,
                children: [
                  for (final (i, node) in nodes.indexed) _focusTag(i, node),
                ],
              ),
            ),
          );
          nodes[0].requestFocus();
          await tester.pump();

          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pump();

          expect(_focused(), '+N', reason: '$textDirection');
        }
      },
    );

    testWidgets(
      'us14/fr03/e02, us06/fr01: in a wrap focus group the arrow keys skip '
      'hidden children',
      (tester) async {
        final nodes = twelve();
        await tester.pumpWidget(
          _host(
            _wrap(
              maxRuns: 2,
              focusGroup: const StratumFocusGroup(),
              overflowBuilder: _focusMore,
              children: [
                for (final (i, node) in nodes.indexed) _focusTag(i, node),
              ],
            ),
          ),
        );
        Future<String?> press(
          LogicalKeyboardKey key, {
          required int from,
        }) async {
          nodes[from].requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(key);
          await tester.pump();
          return _focused();
        }

        expect(await press(LogicalKeyboardKey.arrowRight, from: 7), '+N');
        expect(await press(LogicalKeyboardKey.arrowDown, from: 0), 'tag 4');
        expect(await press(LogicalKeyboardKey.arrowDown, from: 4), 'tag 4');
      },
    );

    testWidgets(
      'us14/fr03/e03, r6: under verticalDirection up, End follows reading '
      'order to the last item of the bottom run',
      (tester) async {
        final nodes = twelve();
        await tester.pumpWidget(
          _host(
            WrapLayout(
              gap: 10,
              runGap: 6,
              verticalDirection: VerticalDirection.up,
              maxRuns: 2,
              focusGroup: const StratumFocusGroup(),
              overflowBuilder: _focusMore,
              children: [
                for (final (i, node) in nodes.indexed) _focusTag(i, node),
              ],
            ),
          ),
        );
        nodes[4].requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump();

        expect(_focused(), 'tag 3');
      },
    );

    /// Focuses the "+N" child's own node, which its [Focus] creates.
    Future<void> focusMore(WidgetTester tester) async {
      Focus.of(tester.element(find.byKey(const ValueKey('more'))))
          .requestFocus();
      await tester.pump();
      expect(_focused(), '+N');
    }

    testWidgets('us14/fr03/e07, r5: focus on "+N" moves to the first child the expand shows, after '
        'the frame', (tester) async {
      final nodes = twelve();
      await tester.pumpWidget(_host(build(2, nodes)));
      await focusMore(tester);

      await tester.pumpWidget(_host(build(null, nodes)));
      await tester.pump();

      expect(_focused(), 'tag 8');
    });

    testWidgets('us14/fr03/e07, r5: with no focusable node in the first child the expand shows, '
        "focus moves to the wrap's own node", (tester) async {
      final nodes = twelve();
      await tester.pumpWidget(_host(build(2, nodes, focusableTags: false)));
      await focusMore(tester);

      await tester.pumpWidget(_host(build(null, nodes, focusableTags: false)));
      await tester.pump();

      expect(_focused(), 'WrapLayout');
    });

    testWidgets(
      'us14/fr03/e07, r5: an expand that keeps the "+N" child keeps its '
      'focus',
      (tester) async {
        final nodes = [for (var i = 0; i < 16; i++) _node('tag $i')];
        Widget wrap(int maxRuns) => _host(
          _wrap(
            maxRuns: maxRuns,
            overflowBuilder: _focusMore,
            children: [
              for (final (i, node) in nodes.indexed) _focusTag(i, node),
            ],
          ),
        );
        await tester.pumpWidget(wrap(2));
        expect(find.text('+8'), findsOneWidget);
        await focusMore(tester);

        await tester.pumpWidget(wrap(3));
        await tester.pump();

        expect(find.text('+4'), findsOneWidget);
        expect(_focused(), '+N');
      },
    );

    /// A "+N" child of [_focusMore] keyed by [name] and its count, so a new
    /// count, or a new name, builds it as a new element.
    Widget Function(BuildContext, int) keyedMore(String name) =>
        (context, count) => Focus(
          key: ValueKey('$name $count'),
          debugLabel: '+N',
          child: _more(context, count),
        );

    /// Sixteen focusable tags on [nodes], cut to [maxRuns], with the "+N"
    /// child of [overflowBuilder].
    Widget sixteen(
      int maxRuns,
      List<FocusNode> nodes,
      Widget Function(BuildContext, int) overflowBuilder,
    ) {
      return _host(
        _wrap(
          maxRuns: maxRuns,
          overflowBuilder: overflowBuilder,
          children: [for (final (i, node) in nodes.indexed) _focusTag(i, node)],
        ),
      );
    }

    /// Whether the "+N" child shown now holds primary focus.
    bool moreFocused(WidgetTester tester) =>
        Focus.of(tester.element(find.byKey(const ValueKey('more'))))
            .hasPrimaryFocus;

    testWidgets('us14/fr03/e07, r5: an expand that rebuilds the focused "+N" as a new child moves '
        'focus to the first child the expand shows', (tester) async {
      final nodes = [for (var i = 0; i < 16; i++) _node('tag $i')];
      final more = keyedMore('count');
      await tester.pumpWidget(sixteen(2, nodes, more));
      await focusMore(tester);

      await tester.pumpWidget(sixteen(3, nodes, more));
      await tester.pump();

      expect(find.text('+4'), findsOneWidget);
      expect(_focused(), 'tag 8');
    });

    testWidgets(
      'us14/fr03/e08: a collapse that rebuilds the focused "+N" as a new '
      'child moves focus to the new "+N" after the frame',
      (tester) async {
        final nodes = [for (var i = 0; i < 16; i++) _node('tag $i')];
        final more = keyedMore('count');
        await tester.pumpWidget(sixteen(3, nodes, more));
        expect(find.text('+4'), findsOneWidget);
        await focusMore(tester);

        await tester.pumpWidget(sixteen(2, nodes, more));
        await tester.pump();

        expect(find.text('+8'), findsOneWidget);
        expect(moreFocused(tester), isTrue);
      },
    );

    testWidgets(
      'us14/fr03/e08: an overflowBuilder that rebuilds the focused "+N" as a '
      'new child at the same limits moves focus to the new "+N" after the '
      'frame',
      (tester) async {
        final nodes = [for (var i = 0; i < 16; i++) _node('tag $i')];
        await tester.pumpWidget(sixteen(2, nodes, keyedMore('old')));
        await focusMore(tester);

        await tester.pumpWidget(sixteen(2, nodes, keyedMore('new')));
        await tester.pump();

        expect(find.text('+8'), findsOneWidget);
        expect(moreFocused(tester), isTrue);
      },
    );

    testWidgets('us14/fr03/e07, r5: an expand that also inserts a child before the cut moves focus '
        'to the first child the expand shows', (tester) async {
      final nodes = [...twelve(), _node('tag 12')];
      Widget host(int? maxRuns, {required bool inserted}) => _host(
        _wrap(
          maxRuns: maxRuns,
          overflowBuilder: _focusMore,
          children: [
            if (inserted) _focusTag(12, nodes[12]),
            for (var i = 0; i < 12; i++) _focusTag(i, nodes[i]),
          ],
        ),
      );
      await tester.pumpWidget(host(2, inserted: false));
      await focusMore(tester);

      await tester.pumpWidget(host(null, inserted: true));
      await tester.pump();

      expect(_focused(), 'tag 8');
    });
  });

  group('WrapLayout expand and collapse (US-14 FR-04)', () {
    _ExpandableState expandable(WidgetTester tester) =>
        tester.state<_ExpandableState>(find.byType(_Expandable));

    testWidgets(
      'us14/s4, us14/fr04, s03/inv40: tapping "+4" grows the wrap to its '
      "full size over 125 ms in the package's default theme",
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        expect(_height(tester), 46);

        await tester.tap(find.text('+4'));
        await tester.pump();
        expect(_height(tester), 46);
        expect(_shownTags(), [for (var i = 0; i < 12; i++) i]);

        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), moreOrLessEquals(46 + 26 * _mid));

        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), 72);
      },
    );

    testWidgets("s03/inv40: the size moves over the theme's default level", (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Expandable(),
          theme: motionTheme(fast: const Duration(milliseconds: 80)),
        ),
      );

      await tester.tap(find.text('+4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_height(tester), moreOrLessEquals(46 + 26 * _mid));

      await tester.pump(const Duration(milliseconds: 40));
      expect(_height(tester), 72);
    });

    testWidgets(
      'us14/fr04, s03/inv40: a collapse shrinks the size the same way',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        expandable(tester).set(expanded: true);
        await tester.pumpAndSettle();
        expect(_height(tester), 72);

        expandable(tester).set(expanded: false);
        await tester.pump();
        expect(_height(tester), 72);
        expect(_shownTags(), [0, 1, 2, 3, 4, 5, 6, 7]);

        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), moreOrLessEquals(72 - 26 * _mid));
        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), 46);
      },
    );

    testWidgets(
      'us14/fr04: the content clips to the animating size, and only while '
      'it moves',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        await tester.tap(find.text('+4'));
        await tester.pump();
        await tester.pump(const Duration(microseconds: 62500));

        final wrap = tester.renderObject(find.byType(WrapOverflowFrame));
        expect(
          wrap,
          paints..clipRect(rect: Rect.fromLTWH(0, 0, 230, _height(tester))),
        );

        await tester.pumpAndSettle();
        expect(wrap, isNot(paints..clipRect()));
      },
    );

    for (final (name, features, disable) in const [
      (
        'the platform reduce-motion flag',
        FakeAccessibilityFeatures(reduceMotion: true),
        false,
      ),
      ("the app's disableAnimations", FakeAccessibilityFeatures(), true),
    ]) {
      testWidgets(
        'us14/s6, us14/fr04: under $name an expand shows every tag at its '
        'full size at once',
        (tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue = features;
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData.fromView(tester.view)
                  .copyWith(disableAnimations: disable),
              child: themedHost(const _Expandable()),
            ),
          );

          await tester.tap(find.text('+4'));
          await tester.pump();

          expect(_height(tester), 72);
          expect(_shownTags(), [for (var i = 0; i < 12; i++) i]);
        },
      );
    }

    testWidgets(
      'us14/fr04/e01: a change of constraints, children, or gap lays out at '
      'the new size at once, also mid-move',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        expandable(tester).set(expanded: true);
        await tester.pumpAndSettle();
        expect(_height(tester), 72);

        await tester.pumpWidget(themedHost(const _Expandable(width: 130)));
        expect(_height(tester), 150);
        await tester.pumpWidget(
          themedHost(const _Expandable(width: 130, count: 16)),
        );
        expect(_height(tester), 202);
        await tester.pumpWidget(
          themedHost(const _Expandable(width: 130, count: 16, runGap: 10)),
        );
        expect(_height(tester), 230);
        await tester.pumpWidget(
          themedHost(
            const _Expandable(width: 130, count: 16, runGap: 10, gap: 0),
          ),
        );
        expect(_height(tester), 170);

        expandable(tester).set(expanded: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pumpWidget(themedHost(const _Expandable(count: 16)));
        expect(_height(tester), 46);
      },
    );

    testWidgets(
      'us14/fr04/e02: children an expand shows appear at once, with no fade',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        await tester.tap(find.text('+4'));
        await tester.pump();

        final tag = find.byKey(const ValueKey('tag 8'));
        final wrap = tester.renderObject(find.byType(WrapOverflowFrame));
        expect(tag, findsOneWidget);
        expect(wrap.paintsChild(tester.renderObject(tag)), isTrue);
        for (final fade in [FadeTransition, Opacity, AnimatedOpacity]) {
          expect(
            find.descendant(
              of: find.byType(WrapOverflowFrame),
              matching: find.byType(fade),
            ),
            findsNothing,
            reason: '$fade',
          );
        }
      },
    );

    testWidgets(
      'us14/fr04/e03: with overflowBuilder set, both limits switching '
      "between null and a value animate the size and keep the children's "
      'State',
      (tester) async {
        Widget build(int? maxRuns) => themedHost(
          SizedBox(
            width: 230,
            child: _wrap(maxRuns: maxRuns, children: _chips(12)),
          ),
        );
        await tester.pumpWidget(build(2));
        final chip = tester.state(find.byKey(const ValueKey('chip 0')));

        await tester.pumpWidget(build(null));
        expect(_height(tester), 46);
        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), moreOrLessEquals(46 + 26 * _mid));
        await tester.pumpAndSettle();
        expect(_height(tester), 72);
        expect(tester.state(find.byKey(const ValueKey('chip 0'))), same(chip));
      },
    );

    testWidgets(
      'us14/fr04/e04: with no overflowBuilder, both limits switching between '
      'null and a value remount the children with no animation',
      (tester) async {
        Widget build(int? maxRuns) => themedHost(
          SizedBox(
            width: 230,
            child: _wrap(
              maxRuns: maxRuns,
              overflowBuilder: null,
              children: _chips(12),
            ),
          ),
        );
        await tester.pumpWidget(build(2));
        final chip = tester.state(find.byKey(const ValueKey('chip 0')));
        expect(_height(tester), 46);

        await tester.pumpWidget(build(null));

        expect(_height(tester), 72);
        expect(
          tester.state(find.byKey(const ValueKey('chip 0'))),
          isNot(same(chip)),
        );
      },
    );

    testWidgets(
      'us14/fr04/e05: a bare wrap and a styled wrap move their size the same '
      'way',
      (tester) async {
        for (final style in [null, const WidgetStyle()]) {
          // A new key per style gives each pass a collapsed wrap.
          await tester.pumpWidget(
            themedHost(_Expandable(key: ValueKey(style), style: style)),
          );
          await tester.tap(find.text('+4'));
          await tester.pump();
          await tester.pump(const Duration(microseconds: 62500));

          expect(
            _height(tester),
            moreOrLessEquals(46 + 26 * _mid),
            reason: 'style $style',
          );
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'a collapse during an expand moves on from the size shown now',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        await tester.tap(find.text('+4'));
        await tester.pump();
        await tester.pump(const Duration(microseconds: 62500));
        final shown = _height(tester);

        expandable(tester).set(expanded: false);
        await tester.pump();
        expect(_height(tester), moreOrLessEquals(shown));

        await tester.pump(const Duration(milliseconds: 125));
        expect(_height(tester), 46);
      },
    );

    testWidgets(
      'us14/fr04: an animated limit change lays out with no FlutterError',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        await tester.tap(find.text('+4'));
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull, reason: 'expand $frame');
        }

        expandable(tester).set(expanded: false);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'collapse start');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'collapse end');
      },
    );

    testWidgets(
      "us14/fr04: a parent's dry layout mid-move returns the size the frame "
      'laid out',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        await tester.tap(find.text('+4'));
        await tester.pump();
        final wrap = tester.renderObject<RenderBox>(
          find.byType(WrapOverflowFrame),
        );
        expect(wrap.getDryLayout(wrap.constraints), wrap.size, reason: 'start');

        await tester.pump(const Duration(microseconds: 62500));
        expect(wrap.size.height, moreOrLessEquals(46 + 26 * _mid));
        expect(wrap.getDryLayout(wrap.constraints), wrap.size, reason: 'mid');
      },
    );

    testWidgets(
      'us14/s6, NFR-U03: reduced motion that turns on mid-move shows the '
      'full size in that frame',
      (tester) async {
        Widget host({required bool reduce}) => MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(disableAnimations: reduce),
          child: themedHost(const _Expandable()),
        );
        await tester.pumpWidget(host(reduce: false));
        await tester.tap(find.text('+4'));
        await tester.pump();
        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), moreOrLessEquals(46 + 26 * _mid));

        await tester.pumpWidget(host(reduce: true));

        expect(_height(tester), 72);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'us14/fr04: a wrap a GlobalKey moves mid-move shows its full size in '
      'that frame, with no ticker left running',
      (tester) async {
        final key = GlobalKey();
        Widget host({required bool padded}) => themedHost(
          padded
              ? Padding(
                  padding: EdgeInsets.zero,
                  child: _Expandable(key: key),
                )
              : _Expandable(key: key),
        );
        await tester.pumpWidget(host(padded: false));
        await tester.tap(find.text('+4'));
        await tester.pump();
        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), moreOrLessEquals(46 + 26 * _mid));
        final wrap = tester.renderObject(find.byType(WrapOverflowFrame));

        await tester.pumpWidget(host(padded: true));

        // The same render object, detached and attached again.
        expect(tester.renderObject(find.byType(WrapOverflowFrame)), same(wrap));
        expect(_height(tester), 72);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'us14/fr04: under IntrinsicHeight an expand neither asserts nor sticks '
      'at the old size',
      (tester) async {
        Widget build(int? maxRuns) => themedHost(
          SizedBox(
            width: 230,
            child: IntrinsicHeight(
              child: _wrap(maxRuns: maxRuns, children: _tags(12)),
            ),
          ),
        );
        await tester.pumpWidget(build(2));
        expect(_height(tester), 46);

        await tester.pumpWidget(build(null));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        expect(_height(tester), 72);
        expect(_shownTags(), [for (var i = 0; i < 12; i++) i]);
      },
    );

    testWidgets(
      'us14/fr04: under IntrinsicHeight an expand after a hidden child '
      'rebuilt itself in the layout lays the ancestor out to the new size',
      (tester) async {
        Widget build(int? maxRuns) => themedHost(
          SizedBox(
            width: 230,
            child: IntrinsicHeight(
              child: _wrap(
                maxRuns: maxRuns,
                children: [..._tags(11), _GrowingTag(11)],
              ),
            ),
          ),
        );
        await tester.pumpWidget(build(2));
        expect(_height(tester), 46);

        // The first layout's probe adopt already owes IntrinsicHeight a
        // mark. Tag 11 is hidden: its own setState rebuilds it inside a
        // layout of the wrap alone, which must keep that mark owed.
        tester
            .state<_GrowingTagState>(
              find.byType(_GrowingTag, skipOffstage: false),
            )
            .grow(40);
        await tester.pump();
        expect(_height(tester), 46);

        await tester.pumpWidget(build(null));
        await tester.pumpAndSettle();

        // Three runs, the last as high as tag 11.
        expect(_height(tester), 20 + 6 + 20 + 6 + 40);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'us14/fr04: under IntrinsicHeight an expand after a cut flip resized '
      'a child lays the ancestor out to the new size',
      (tester) async {
        Widget build(int? maxRuns) => themedHost(
          SizedBox(
            width: 230,
            child: IntrinsicHeight(
              child: _wrap(
                maxRuns: maxRuns,
                children: [
                  ..._tags(4),
                  _swapTag(4, on: 30, off: 40),
                  for (var i = 5; i < 12; i++) _tag(i),
                ],
              ),
            ),
          ),
        );
        // The first layout's probe adopt already owes IntrinsicHeight a
        // mark; its cut also hides tag 4, which takes its 40 px
        // ColoredBox inside that layout, and the mark must stay owed.
        await tester.pumpWidget(build(1));
        expect(_height(tester), 20);
        expect(_shownTags(), [0, 1, 2, 3]);
        // The flip measures IntrinsicHeight again, once, at the same size.
        await tester.pump();
        expect(_height(tester), 20);
        expect(tester.binding.hasScheduledFrame, isFalse);

        await tester.pumpWidget(build(2));
        await tester.pumpAndSettle();

        // Shown, tag 4 takes its 30 px SizedBox and fits in the first run.
        expect(_height(tester), 46);
        expect(_shownTags(), [for (var i = 0; i < 9; i++) i]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'us14/fr04: under IntrinsicHeight a shown child that grows by its own '
      'setState lays the ancestor out to its new size in the next frame, '
      'then schedules no more frames',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              width: 230,
              child: IntrinsicHeight(
                child: _wrap(
                  maxRuns: 2,
                  children: [_GrowingTag(0), ..._tags(12).skip(1)],
                ),
              ),
            ),
          ),
        );
        expect(_height(tester), 46);

        // Tag 0 rebuilds inside the wrap's layout, after IntrinsicHeight
        // measured it at its old height.
        tester.state<_GrowingTagState>(find.byType(_GrowingTag)).grow(40);
        await tester.pump();
        await tester.pump();

        // The first run as high as tag 0.
        expect(_height(tester), 40 + 6 + 20);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pump(const Duration(seconds: 1));
        expect(_height(tester), 40 + 6 + 20);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'us14/fr04, NFR-U03: under IntrinsicHeight and reduced motion an expand '
      'in the frame that measures again after a child grew lays the '
      'ancestor out to the size the expand shows',
      (tester) async {
        Widget build(int maxRuns) => MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(disableAnimations: true),
          child: themedHost(
            SizedBox(
              width: 230,
              child: IntrinsicHeight(
                child: _wrap(
                  maxRuns: maxRuns,
                  children: [
                    _GrowingTag(0),
                    ..._tags(4).skip(1),
                    _tallWhileOnTag(4),
                    for (var i = 5; i < 12; i++) _tag(i),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(build(1));
        while (tester.binding.hasScheduledFrame) {
          await tester.pump();
        }
        expect(_height(tester), 20);

        // Frame N rebuilds tag 0 inside the wrap's layout and asks
        // IntrinsicHeight to measure again in frame N + 1.
        tester.state<_GrowingTagState>(find.byType(_GrowingTag)).grow(40);
        await tester.pump();
        expect(_height(tester), 20);

        // Frame N + 1 also lifts the limit: IntrinsicHeight measures tag 4
        // hidden, 20 high, and the expand shows it 40 high.
        await tester.pumpWidget(build(2));
        await tester.pump();

        expect(_height(tester), 40 + 6 + 40);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'us14/fr04: between a limit change and its layout, dry layout returns '
      'the size shown now and the cross-axis intrinsic the target',
      (tester) async {
        await tester.pumpWidget(themedHost(const _Expandable()));
        final wrap = tester.renderObject<RenderBox>(
          find.byType(WrapOverflowFrame),
        );

        expandable(tester).set(expanded: true);
        // Builds the limit change into the render object, before its layout.
        tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
        expect(wrap.debugNeedsLayout, isTrue);

        expect(wrap.getDryLayout(wrap.constraints), const Size(230, 46));
        expect(wrap.getMaxIntrinsicHeight(230), 72);
        expect(wrap.getMinIntrinsicHeight(230), 72);

        await tester.pump();
        expect(_height(tester), 46);
        await tester.pumpAndSettle();
        expect(_height(tester), 72);
      },
    );

    testWidgets(
      'us14/fr04, us14/fr01/e07: an upward wrap keeps its first run on its '
      'bottom edge while an expand moves the size',
      (tester) async {
        Widget build(int? maxRuns) => themedHost(
          SizedBox(
            width: 230,
            child: WrapLayout(
              gap: 10,
              runGap: 6,
              maxRuns: maxRuns,
              verticalDirection: VerticalDirection.up,
              overflowBuilder: _more,
              children: _tags(12),
            ),
          ),
        );
        await tester.pumpWidget(build(2));
        final before = _rectIn(tester, 'tag 0');
        expect(before, const Rect.fromLTWH(0, 26, 40, 20));

        await tester.pumpWidget(build(null));
        expect(_rectIn(tester, 'tag 0'), before, reason: 'first frame');

        await tester.pump(const Duration(microseconds: 62500));
        expect(_height(tester), moreOrLessEquals(46 + 26 * _mid));
        expect(
          _rectIn(tester, 'tag 0').bottom,
          moreOrLessEquals(_height(tester)),
          reason: 'mid-move',
        );
      },
    );

    testWidgets(
      'us14/fr04, us14/fr01/e07: a right-to-left wrap keeps its first run on '
      'its right edge while an expand moves the size',
      (tester) async {
        Widget build(int? maxRuns) => themedHost(
          SizedBox(
            width: 230,
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: _wrap(maxRuns: maxRuns, children: _tags(12)),
            ),
          ),
          textDirection: TextDirection.rtl,
        );
        await tester.pumpWidget(build(2));
        final before = _rectIn(tester, 'tag 0');
        expect(before, const Rect.fromLTWH(190, 0, 40, 20));

        await tester.pumpWidget(build(null));
        expect(_rectIn(tester, 'tag 0'), before, reason: 'first frame');

        await tester.pump(const Duration(microseconds: 62500));
        final width = tester.getSize(find.byType(WrapOverflowFrame)).width;
        expect(width, moreOrLessEquals(230 - 40 * _mid));
        expect(
          _rectIn(tester, 'tag 0').right,
          moreOrLessEquals(width),
          reason: 'mid-move',
        );
      },
    );

    for (final (alignment, share) in const [
      (WrapAlignment.center, 0.5),
      (WrapAlignment.end, 1.0),
    ]) {
      testWidgets(
        'us14/fr04: a wrap with alignment and runAlignment $alignment keeps '
        'its first run in place while an expand or a collapse moves the size',
        (tester) async {
          Widget build(int? maxRuns) => themedHost(
            SizedBox(
              width: 230,
              child: Align(
                alignment: Alignment.topLeft,
                child: WrapLayout(
                  gap: 10,
                  runGap: 6,
                  alignment: alignment,
                  runAlignment: alignment,
                  maxRuns: maxRuns,
                  overflowBuilder: _more,
                  children: _tags(12),
                ),
              ),
            ),
          );
          await tester.pumpWidget(build(2));
          // The first run, 190 wide, in the 230 wide run of the "+4" child.
          final before = _rectIn(tester, 'tag 0');
          expect(before, Rect.fromLTWH(40 * share, 0, 40, 20));

          await tester.pumpWidget(build(null));
          expect(_rectIn(tester, 'tag 0'), before, reason: 'first frame');

          await tester.pump(const Duration(microseconds: 62500));
          final width = tester.getSize(find.byType(WrapOverflowFrame)).width;
          expect(width, moreOrLessEquals(230 - 40 * _mid));
          expect(
            _rectIn(tester, 'tag 0').topLeft,
            offsetMoreOrLessEquals(Offset((width - 190) * share, 0)),
            reason: 'mid-move',
          );

          await tester.pumpAndSettle();
          final expanded = _rectIn(tester, 'tag 0');
          expect(expanded, const Rect.fromLTWH(0, 0, 40, 20));
          await tester.pumpWidget(build(2));
          expect(_rectIn(tester, 'tag 0'), expanded, reason: 'collapse');
        },
      );
    }
  });
}

/// [count] tags in a wrap [width] wide, cut to two runs until the "+N"
/// child is tapped or [_ExpandableState.set] lifts the limit.
class _Expandable extends StatefulWidget {
  const new({
    super.key,
    this.width = 230,
    this.gap = 10,
    this.runGap = 6,
    this.count = 12,
    this.style,
  });

  final double width;
  final double gap;
  final double runGap;
  final int count;
  final WidgetStyle? style;

  @override
  State<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<_Expandable> {
  bool expanded = false;

  void set({required bool expanded}) =>
      setState(() => this.expanded = expanded);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: widget.width,
        child: WrapLayout(
          style: widget.style,
          gap: widget.gap,
          runGap: widget.runGap,
          maxRuns: expanded ? null : 2,
          overflowBuilder: (context, count) => GestureDetector(
            onTap: () => set(expanded: true),
            child: _more(context, count),
          ),
          children: _tags(widget.count),
        ),
      ),
    );
  }
}
