import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_overflow.dart';
import 'package:stratum_ui/src/src.dart';

/// [child] at the top left of the view, [width] wide, left to right.
Widget _host(Widget child, {double width = 230}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  );
}

/// [count] tags of 40 by 20, keyed `tag <i>`.
List<Widget> _tags(int count) => [
  for (var i = 0; i < count; i++)
    SizedBox(key: ValueKey('tag $i'), width: 40, height: 20),
];

/// The "+N" child: 30 by 20, keyed `more`, showing [count].
Widget _more(BuildContext context, int count) => SizedBox(
  key: const ValueKey('more'),
  width: 30,
  height: 20,
  child: Text('+$count'),
);

/// A frame with a gap of 10 and a run gap of 6, counting with [builder],
/// else [_more], unless [counted] is false.
WrapOverflowFrame _frame({
  int? maxRuns,
  int? maxChildren,
  bool counted = true,
  Widget Function(BuildContext, int)? builder,
  Clip clipBehavior = Clip.none,
  required List<Widget> children,
}) {
  return WrapOverflowFrame(
    spacing: 10,
    runSpacing: 6,
    clipBehavior: clipBehavior,
    maxRuns: maxRuns,
    maxChildren: maxChildren,
    overflowBuilder: counted ? builder ?? _more : null,
    children: children,
  );
}

/// The indices of the tags that show, built and onstage.
List<int> _shownTags() => [
  for (var i = 0; i < 20; i++)
    if (find.byKey(ValueKey('tag $i')).evaluate().isNotEmpty) i,
];

/// Whether the tag [i] is built, shown or hidden.
bool _built(int i) =>
    find.byKey(ValueKey('tag $i'), skipOffstage: false).evaluate().isNotEmpty;

/// Tags of varied sizes for the parity check.
List<Widget> _varied() {
  const widths = [
    40.0,
    60.0,
    30.0,
    50.0,
    40.0,
    70.0,
    20.0,
    40.0,
    60.0,
    30.0,
    50.0,
    40.0,
  ];
  const heights = [
    20.0,
    30.0,
    20.0,
    25.0,
    20.0,
    15.0,
    20.0,
    30.0,
    20.0,
    25.0,
    20.0,
    15.0,
  ];
  return [
    for (var i = 0; i < 12; i++)
      SizedBox(key: ValueKey('tag $i'), width: widths[i], height: heights[i]),
  ];
}

const _moreBox = SizedBox(key: ValueKey('more'), width: 30, height: 20);

/// One parameter set of the parity check against Flutter's [Wrap].
class _Config {
  const new({
    required this.direction,
    required this.textDirection,
    required this.verticalDirection,
    required this.alignment,
    required this.runAlignment,
    required this.crossAxisAlignment,
    required this.maxRuns,
    required this.maxChildren,
  });

  final Axis direction;
  final TextDirection textDirection;
  final VerticalDirection verticalDirection;
  final WrapAlignment alignment;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final int? maxRuns;
  final int? maxChildren;

  /// [child] in a 230 by 150 box at the top left of the view.
  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 230, height: 150, child: child),
    ),
  );

  Widget frame() => host(
    WrapOverflowFrame(
      direction: direction,
      alignment: alignment,
      spacing: 10,
      runSpacing: 6,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      maxRuns: maxRuns,
      maxChildren: maxChildren,
      overflowBuilder: (_, _) => _moreBox,
      children: _varied(),
    ),
  );

  Widget wrap(int shown, {required bool more}) => host(
    Wrap(
      direction: direction,
      alignment: alignment,
      spacing: 10,
      runSpacing: 6,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      children: [..._varied().take(shown), if (more) _moreBox],
    ),
  );

  @override
  String toString() =>
      '$direction $textDirection $verticalDirection '
      '$alignment/$runAlignment/$crossAxisAlignment '
      'maxRuns $maxRuns maxChildren $maxChildren';
}

final List<_Config> _configs = [
  for (final direction in Axis.values)
    for (final textDirection in TextDirection.values)
      for (final verticalDirection in VerticalDirection.values)
        for (final (alignment, runAlignment, crossAxisAlignment) in const [
          (WrapAlignment.start, WrapAlignment.start, WrapCrossAlignment.start),
          (WrapAlignment.end, WrapAlignment.center, WrapCrossAlignment.end),
          (
            WrapAlignment.spaceBetween,
            WrapAlignment.spaceAround,
            WrapCrossAlignment.center,
          ),
          (
            WrapAlignment.spaceEvenly,
            WrapAlignment.end,
            WrapCrossAlignment.start,
          ),
        ])
          for (final (maxRuns, maxChildren) in const [
            (2, null),
            (null, 5),
            (1, 3),
          ])
            _Config(
              direction: direction,
              textDirection: textDirection,
              verticalDirection: verticalDirection,
              alignment: alignment,
              runAlignment: runAlignment,
              crossAxisAlignment: crossAxisAlignment,
              maxRuns: maxRuns,
              maxChildren: maxChildren,
            ),
];

void main() {
  group('WrapOverflowFrame', () {
    testWidgets(
      'us14/fr01/e07, s03/inv36: runs, child order, and alignment follow '
      "Flutter's Wrap over the shown children and the overflow child in "
      'every direction',
      (tester) async {
        for (final config in _configs) {
          await tester.pumpWidget(config.frame());
          final shown = _shownTags();
          expect(shown, [for (var i = 0; i < shown.length; i++) i]);
          final more = find.byKey(const ValueKey('more'));
          final hasMore = more.evaluate().isNotEmpty;
          final rects = {
            for (final i in shown)
              'tag $i': tester.getRect(find.byKey(ValueKey('tag $i'))),
            if (hasMore) 'more': tester.getRect(more),
          };

          await tester.pumpWidget(config.wrap(shown.length, more: hasMore));
          for (final MapEntry(:key, :value) in rects.entries) {
            expect(
              tester.getRect(find.byKey(ValueKey(key))),
              value,
              reason: '$config, $key',
            );
          }
        }
      },
    );

    testWidgets(
      'us14/s1, us14/fr02, s03/inv38: the overflow child shows the exact '
      'hidden count in the first frame',
      (tester) async {
        final counts = <int>[];
        await tester.pumpWidget(
          _host(
            _frame(
              maxRuns: 2,
              builder: (context, count) {
                counts.add(count);
                return _more(context, count);
              },
              children: _tags(12),
            ),
          ),
        );

        expect(counts, [4]);
        expect(find.text('+4'), findsOneWidget);
        expect(_shownTags(), [0, 1, 2, 3, 4, 5, 6, 7]);
        expect([for (var i = 8; i < 12; i++) _built(i)], everyElement(isTrue));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('more'))),
          const Offset(200, 26),
        );
        expect(
          tester.getSize(find.byType(WrapOverflowFrame)),
          const Size(230, 46),
        );
      },
    );

    testWidgets(
      'us14/fr02/e04: at the cap shown children hide from the end, one at '
      'a time, and the count grows with each',
      (tester) async {
        final counts = <int>[];
        await tester.pumpWidget(
          _host(
            _frame(
              maxRuns: 2,
              builder: (context, count) {
                counts.add(count);
                return SizedBox(
                  key: const ValueKey('more'),
                  width: 90,
                  height: 20,
                  child: Text('+$count'),
                );
              },
              children: _tags(12),
            ),
          ),
        );

        expect(counts, [4, 5, 6]);
        expect(find.text('+6'), findsOneWidget);
        expect(_shownTags(), [0, 1, 2, 3, 4, 5]);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('more'))),
          const Offset(100, 26),
        );
      },
    );

    testWidgets(
      'us14/fr02/e05, r7: an overflow child wider than a run is capped at '
      'the run extent, as Wrap caps it, and sits alone in the last allowed '
      'run with no clip',
      (tester) async {
        await tester.pumpWidget(
          _host(
            _frame(
              maxRuns: 2,
              builder: (context, count) => SizedBox(
                key: const ValueKey('more'),
                width: 300,
                height: 20,
                child: Text('+$count'),
              ),
              clipBehavior: Clip.hardEdge,
              children: _tags(12),
            ),
          ),
        );

        expect(_shownTags(), [0, 1, 2, 3]);
        expect(find.text('+8'), findsOneWidget);
        final more = find.byKey(const ValueKey('more'));
        expect(tester.getTopLeft(more), const Offset(0, 26));
        expect(tester.getSize(more), const Size(230, 20));
        expect(
          tester.getSize(find.byType(WrapOverflowFrame)),
          const Size(230, 46),
        );
        expect(
          tester.renderObject(find.byType(WrapOverflowFrame)),
          isNot(paints..clipRect()),
        );
      },
    );

    testWidgets(
      'us14/fr02/e06, us14/fr01/e03: maxChildren 0 shows the overflow '
      'child alone with every child counted',
      (tester) async {
        await tester.pumpWidget(
          _host(_frame(maxChildren: 0, children: _tags(5))),
        );

        expect(_shownTags(), isEmpty);
        expect(find.text('+5'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('more'))),
          Offset.zero,
        );
      },
    );

    testWidgets(
      'us14/fr02/e01, us14/fr01/e04: with nothing hidden, or both limits '
      'null, no overflow child is built',
      (tester) async {
        final counts = <int>[];
        Widget logged(BuildContext context, int count) {
          counts.add(count);
          return _more(context, count);
        }

        await tester.pumpWidget(
          _host(_frame(maxRuns: 2, builder: logged, children: _tags(4))),
        );
        expect(_shownTags(), [0, 1, 2, 3]);
        expect(find.byKey(const ValueKey('more')), findsNothing);

        await tester.pumpWidget(
          _host(_frame(builder: logged, children: _tags(12))),
        );
        expect(_shownTags(), [for (var i = 0; i < 12; i++) i]);
        expect(find.byKey(const ValueKey('more')), findsNothing);
        expect(counts, isEmpty);
      },
    );

    testWidgets(
      'us14/fr02/e02: with no overflowBuilder the hidden children hide with '
      'no indicator',
      (tester) async {
        await tester.pumpWidget(
          _host(_frame(maxRuns: 2, counted: false, children: _tags(12))),
        );

        expect(_shownTags(), [0, 1, 2, 3, 4, 5, 6, 7]);
        expect(find.byKey(const ValueKey('more')), findsNothing);
        expect(tester.getSize(find.byType(WrapOverflowFrame)).height, 46);
      },
    );

    testWidgets(
      'us14/fr02/e08: a change of limits, children, or constraints shows '
      'the new count in that frame',
      (tester) async {
        await tester.pumpWidget(_host(_frame(maxRuns: 2, children: _tags(12))));
        expect(find.text('+4'), findsOneWidget);

        await tester.pumpWidget(_host(_frame(maxRuns: 1, children: _tags(12))));
        expect(find.text('+8'), findsOneWidget);

        await tester.pumpWidget(_host(_frame(maxRuns: 1, children: _tags(14))));
        expect(find.text('+10'), findsOneWidget);

        await tester.pumpWidget(
          _host(_frame(maxRuns: 1, children: _tags(14)), width: 130),
        );
        expect(find.text('+12'), findsOneWidget);
      },
    );

    testWidgets(
      'us14/fr02/e07, s03/inv38: intrinsic sizes run the limits at the '
      'queried extent, leave the overflow child out, and never throw',
      (tester) async {
        await tester.pumpWidget(
          _host(
            IntrinsicHeight(child: _frame(maxRuns: 2, children: _tags(12))),
          ),
        );
        expect(tester.takeException(), isNull);
        final box = tester.renderObject<RenderBox>(
          find.byType(WrapOverflowFrame),
        );

        expect(box.size.height, 46);
        expect(box.getMaxIntrinsicHeight(230), 46);
        expect(box.getMinIntrinsicHeight(230), 46);
        expect(
          box.getDryLayout(const BoxConstraints(maxWidth: 230)).height,
          46,
        );
        expect(box.getMinIntrinsicWidth(double.infinity), 40);
        expect(box.getMaxIntrinsicWidth(double.infinity), 480);

        await tester.pumpWidget(
          _host(_frame(maxChildren: 5, children: _tags(12))),
        );
        final five = tester.renderObject<RenderBox>(
          find.byType(WrapOverflowFrame),
        );
        expect(five.getMaxIntrinsicWidth(double.infinity), 200);
        expect(five.getMaxIntrinsicHeight(230), 46);
      },
    );

    testWidgets('us14/fr02/e07: an overflow child larger than the tags under '
        'IntrinsicHeight lays out with no exception', (tester) async {
      await tester.pumpWidget(
        _host(
          IntrinsicHeight(
            child: _frame(
              maxRuns: 2,
              builder: (context, count) => SizedBox(
                key: const ValueKey('more'),
                width: 30,
                height: 30,
                child: Text('+$count'),
              ),
              children: _tags(12),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('+4'), findsOneWidget);
      expect(tester.getSize(find.byType(WrapOverflowFrame)).height, 46);
    });

    testWidgets(
      'us14/fr03: hidden children take no hit test and are not painted',
      (tester) async {
        var hiddenTaps = 0;
        await tester.pumpWidget(
          _host(
            _frame(
              maxChildren: 1,
              counted: false,
              children: [
                const SizedBox(key: ValueKey('tag 0'), width: 40, height: 20),
                GestureDetector(
                  key: const ValueKey('tag 1'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => hiddenTaps++,
                  child: const SizedBox(width: 40, height: 20),
                ),
              ],
            ),
          ),
        );

        await tester.tapAt(const Offset(5, 5));
        expect(hiddenTaps, 0);
        final wrap = tester.renderObject(find.byType(WrapOverflowFrame));
        final shown = tester.renderObject(find.byKey(const ValueKey('tag 0')));
        final hidden = tester.renderObject(
          find.byKey(const ValueKey('tag 1'), skipOffstage: false),
        );
        expect(wrap.paintsChild(shown), isTrue);
        expect(wrap.paintsChild(hidden), isFalse);
      },
    );

    testWidgets(
      'an overflowBuilder that throws shows an ErrorWidget and reports the '
      'error',
      (tester) async {
        // maxChildren 1 asks the builder once: the error box, 230 px wide,
        // opens a run of its own after tag 0.
        await tester.pumpWidget(
          _host(
            _frame(
              maxChildren: 1,
              builder: (context, count) => throw StateError('no count'),
              children: _tags(12),
            ),
          ),
        );

        expect(tester.takeException(), isA<StateError>());
        expect(find.byType(ErrorWidget), findsOneWidget);
        expect(_shownTags(), [0]);
      },
    );
  });
}
