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

/// An [AssertionError] whose message contains every one of [parts].
Matcher _assertionNaming(List<String> parts) => throwsA(
  isA<AssertionError>().having(
    (error) => '${error.message}',
    'message',
    allOf([for (final part in parts) contains(part)]),
  ),
);

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
}
