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

/// The "+N" child of [log]: 90 by 20, keyed `more`; [log] gets [count]
/// each time the live slot's own count changes. The probe (owner ruling
/// R8) builds this too, once per trial, but always inside a disabled
/// [TickerMode], so [TickerMode.valuesOf] tells the two state objects
/// apart; only the live one, never wrapped in one, logs.
class _CountingMore extends StatefulWidget {
  const new({required this.count, required this.log});

  final int count;
  final List<int> log;

  @override
  State<_CountingMore> createState() => _CountingMoreState();
}

class _CountingMoreState extends State<_CountingMore> {
  int? _logged;

  @override
  Widget build(BuildContext context) {
    if (TickerMode.valuesOf(context).enabled && widget.count != _logged) {
      _logged = widget.count;
      widget.log.add(widget.count);
    }
    return SizedBox(
      key: const ValueKey('more'),
      width: 90,
      height: 20,
      child: Text('+${widget.count}'),
    );
  }
}

/// The "+N" child of [_more] on a focus node its own State creates, as a
/// Stratum chip does.
class _OwnNodeMore extends StatefulWidget {
  const new({required this.count});

  final int count;

  @override
  State<_OwnNodeMore> createState() => _OwnNodeMoreState();
}

class _OwnNodeMoreState extends State<_OwnNodeMore> {
  final _node = FocusNode(debugLabel: '+N');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, child: _more(context, widget.count));
}

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
      'us14/fr02/e04: under maxRuns 1 an oversize first child hides, and '
      'the overflow child, alone in the run, counts it',
      (tester) async {
        await tester.pumpWidget(
          _host(
            _frame(
              maxRuns: 1,
              children: [
                const SizedBox(key: ValueKey('tag 0'), width: 400, height: 20),
                ..._tags(3).skip(1),
              ],
            ),
          ),
        );

        expect(_shownTags(), isEmpty);
        expect(_built(0), isTrue);
        expect(find.text('+3'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('more'))),
          Offset.zero,
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

    testWidgets(
      'us14/fr02/e07, s03/inv38, D9: intrinsic sizes over a vertical frame '
      'run the limits at the queried extent, leave the overflow child '
      'out, and never throw',
      (tester) async {
        // The horizontal fr02/e07 test above with every width and height
        // swapped: a vertical frame packs by height (the main axis) and
        // reports width (the cross axis) where the horizontal frame packs
        // by width and reports height, so every number here is that test's
        // number unchanged.
        List<Widget> tags(int count) => [
          for (var i = 0; i < count; i++)
            SizedBox(key: ValueKey('v-tag $i'), width: 20, height: 40),
        ];
        Widget more(BuildContext context, int count) => SizedBox(
          key: const ValueKey('v-more'),
          width: 20,
          height: 30,
          child: Text('+$count'),
        );
        Widget host(Widget child) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(height: 230, child: child),
          ),
        );

        await tester.pumpWidget(
          host(
            IntrinsicWidth(
              child: WrapOverflowFrame(
                direction: Axis.vertical,
                spacing: 10,
                runSpacing: 6,
                maxRuns: 2,
                overflowBuilder: more,
                children: tags(12),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final box = tester.renderObject<RenderBox>(
          find.byType(WrapOverflowFrame),
        );

        expect(box.size.width, 46);
        expect(box.getMaxIntrinsicWidth(230), 46);
        expect(box.getMinIntrinsicWidth(230), 46);
        expect(
          box.getDryLayout(const BoxConstraints(maxHeight: 230)).width,
          46,
        );
        expect(box.getMinIntrinsicHeight(double.infinity), 40);
        expect(box.getMaxIntrinsicHeight(double.infinity), 480);

        await tester.pumpWidget(
          host(
            WrapOverflowFrame(
              direction: Axis.vertical,
              spacing: 10,
              runSpacing: 6,
              maxChildren: 5,
              overflowBuilder: more,
              children: tags(12),
            ),
          ),
        );
        final five = tester.renderObject<RenderBox>(
          find.byType(WrapOverflowFrame),
        );
        expect(five.getMaxIntrinsicHeight(double.infinity), 200);
        expect(five.getMaxIntrinsicWidth(230), 46);
      },
    );

    testWidgets('us14/fr02/e07, D3: a dry-baseline query never throws, as an '
        'ancestor such as IntrinsicHeight over a baseline-aligned Row asks '
        'for it', (tester) async {
      await tester.pumpWidget(_host(_frame(maxRuns: 2, children: _tags(12))));
      final box = tester.renderObject<RenderBox>(
        find.byType(WrapOverflowFrame),
      );

      expect(
        () => box.getDryBaseline(
          const BoxConstraints(maxWidth: 230),
          TextBaseline.alphabetic,
        ),
        returnsNormally,
      );
      expect(tester.takeException(), isNull);
    });

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

    testWidgets(
      'owner ruling R8 (rca-baseline): a baseline query through a Row '
      'around the frame never throws, with or without an IntrinsicHeight '
      'ancestor, and not after a later relayout tries two counts',
      (tester) async {
        Widget sizedText(BuildContext context, int count) =>
            SizedBox(width: 30, height: 20, child: Text('+$count'));
        Widget row(
          Widget content, {
          required bool intrinsic,
          required double width,
        }) {
          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('Tags'),
              Expanded(child: content),
            ],
          );
          return _host(
            intrinsic ? IntrinsicHeight(child: row) : row,
            width: width,
          );
        }

        WrapOverflowFrame rcaFrame() => WrapOverflowFrame(
          spacing: 10,
          runSpacing: 6,
          maxRuns: 1,
          overflowBuilder: sizedText,
          children: _tags(12),
        );

        // First frame, with an IntrinsicHeight ancestor querying the dry
        // baseline round 1 added: the "Tags" text leaves the frame 174
        // px, so two trials (9, then 10), the RCA's own repro geometry.
        await tester.pumpWidget(row(rcaFrame(), intrinsic: true, width: 230));
        expect(tester.takeException(), isNull);

        // No IntrinsicHeight: the real baseline alone, one trial.
        await tester.pumpWidget(row(rcaFrame(), intrinsic: false, width: 236));
        expect(tester.takeException(), isNull);

        // A later relayout at the cap tries two counts (review Minor 3's
        // trigger): the real baseline query must still not throw.
        await tester.pumpWidget(row(rcaFrame(), intrinsic: false, width: 181));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'owner ruling R8, review-minor-3: a stateful overflow child sees '
      'only the final count in the first frame, and in a later relayout '
      'at the cap that tries two counts, only the new final count',
      (tester) async {
        final log = <int>[];
        Widget builder(BuildContext context, int count) =>
            _CountingMore(count: count, log: log);

        // maxRuns 2, the 90 px "+N" child: tries 4, 5, 6 (as e04 does);
        // the live child must see only the last.
        await tester.pumpWidget(
          _host(_frame(maxRuns: 2, builder: builder, children: _tags(12))),
        );
        expect(log, [6]);

        // maxRuns 1, same tags and width: tries 8, 9, 10 (a fresh cut, not
        // a child's own setState, but the same render-layer trigger).
        await tester.pumpWidget(
          _host(_frame(maxRuns: 1, builder: builder, children: _tags(12))),
        );
        expect(log, [6, 10]);
      },
    );

    testWidgets(
      'owner ruling R8, rereview N1/N2: find.text of the overflow label '
      'finds exactly one widget, onstage or off, since the probe drops '
      'once the cut settles and never lingers as a second, hidden copy',
      (tester) async {
        await tester.pumpWidget(
          _host(
            _frame(
              maxRuns: 2,
              builder: (context, count) => SizedBox(
                key: const ValueKey('more'),
                width: 90,
                height: 20,
                child: Text('+$count'),
              ),
              children: _tags(12),
            ),
          ),
        );

        expect(find.text('+6'), findsOneWidget);
        expect(find.text('+6', skipOffstage: false), findsOneWidget);
        // The probe tried 4 and 5 too (review Minor 3's trigger), but a
        // dropped trial leaves nothing behind either.
        expect(find.text('+4', skipOffstage: false), findsNothing);
        expect(find.text('+5', skipOffstage: false), findsNothing);
      },
    );

    testWidgets(
      'owner ruling R8, rereview N1 caveat: an overflowBuilder output '
      'with a GlobalKey reports a duplicate-key error, since the probe '
      'and the live overflow child both inflate it',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          _host(
            _frame(
              maxRuns: 2,
              builder: (context, count) => SizedBox(
                key: key,
                width: 90,
                height: 20,
                child: Text('+$count'),
              ),
              children: _tags(12),
            ),
          ),
        );

        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (e) => e.toString(),
            'message',
            contains('built a widget keyed by a GlobalKey'),
          ),
        );
      },
    );

    testWidgets(
      'rereview R3-N5: a Material "+N" reports nothing over two layouts, '
      'since the GlobalKey its State creates for its ink renderer is its '
      'own per State, never shared by the probe and the live child',
      (tester) async {
        Widget materialMore(BuildContext context, int count) =>
            Material(child: Text('+$count'));

        // The 28 px "+N" fits after 4 tags in the second run.
        await tester.pumpWidget(
          _host(_frame(maxRuns: 2, builder: materialMore, children: _tags(12))),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('+4'), findsOneWidget);

        await tester.pumpWidget(
          _host(_frame(maxRuns: 2, builder: materialMore, children: _tags(14))),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('+6'), findsOneWidget);
      },
    );

    testWidgets(
      'rereview R3-N5: a box-tier BoxLayout "+N" reports nothing over two '
      "layouts, since AnimatedStyledBox's child GlobalKey is its own per "
      'State, never shared by the probe and the live child',
      (tester) async {
        Widget boxMore(BuildContext context, int count) => ContainerLayout(
          style: const WidgetStyle(backgroundColor: Color(0xFF000000)),
          child: Text('+$count'),
        );

        await tester.pumpWidget(
          _host(_frame(maxRuns: 2, builder: boxMore, children: _tags(12))),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('+4'), findsOneWidget);

        await tester.pumpWidget(
          _host(_frame(maxRuns: 2, builder: boxMore, children: _tags(14))),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('+6'), findsOneWidget);
      },
    );

    testWidgets(
      'rereview R3-N6: a GlobalKey "+N" in a second layout at the same '
      'count, with nothing marked dirty, reports again and lays out the '
      'live child, though the probe took its element back',
      (tester) async {
        final key = GlobalKey();
        // One frame widget for both pumps, so the second pump marks no
        // overflow dirty: only the wider host reruns the cut.
        final frame = _frame(
          maxRuns: 2,
          builder: (context, count) =>
              SizedBox(key: key, width: 90, height: 20, child: Text('+$count')),
          children: _tags(12),
        );
        final reportsGlobalKey = isA<FlutterError>().having(
          (e) => e.toString(),
          'message',
          contains('built a widget keyed by a GlobalKey'),
        );

        await tester.pumpWidget(_host(frame));
        expect(tester.takeException(), reportsGlobalKey);
        expect(find.text('+6'), findsOneWidget);

        // Still 4 tags in the first run and 2 beside the 90 px "+6".
        await tester.pumpWidget(_host(frame, width: 232));
        expect(tester.takeException(), reportsGlobalKey);
        expect(find.text('+6'), findsOneWidget);
      },
    );

    testWidgets(
      'owner ruling R9: a "+N" on a FocusNode the app owns reports in each '
      'layout, since the probe and the live overflow child both carry it',
      (tester) async {
        final node = FocusNode(debugLabel: 'app +N');
        addTearDown(node.dispose);
        // One frame widget for both pumps, so the second pump marks no
        // overflow dirty: only the wider host reruns the cut and the probe.
        final frame = _frame(
          maxRuns: 2,
          builder: (context, count) =>
              Focus(focusNode: node, child: _more(context, count)),
          children: _tags(12),
        );
        final reportsFocusNode = isA<FlutterError>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('carries a FocusNode'), contains('app +N')),
        );

        await tester.pumpWidget(_host(frame));
        expect(tester.takeException(), reportsFocusNode);
        expect(find.text('+4'), findsOneWidget);

        await tester.pumpWidget(_host(frame, width: 232));
        expect(tester.takeException(), reportsFocusNode);
        expect(find.text('+4'), findsOneWidget);
      },
    );

    testWidgets(
      'owner ruling R9: a "+N" on a FocusNode its own State creates reports '
      'nothing over two layouts, since the probe and the live child each '
      'create their own',
      (tester) async {
        final frame = _frame(
          maxRuns: 2,
          builder: (context, count) => _OwnNodeMore(count: count),
          children: _tags(12),
        );

        await tester.pumpWidget(_host(frame));
        expect(tester.takeException(), isNull);
        expect(find.text('+4'), findsOneWidget);

        await tester.pumpWidget(_host(frame, width: 232));
        expect(tester.takeException(), isNull);
        expect(find.text('+4'), findsOneWidget);
      },
    );

    testWidgets(
      'rereview N1: an AnimatedSize overflow child whose count crosses a '
      'digit boundary between two layouts measures the new width fresh, '
      'on a probe a stale animation never freezes',
      (tester) async {
        Widget animatedMore(BuildContext context, int count) => AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            key: const ValueKey('more'),
            width: count < 10 ? 28 : 42,
            height: 20,
            child: Text('+$count'),
          ),
        );
        WrapOverflowFrame frame(int tagCount) => WrapOverflowFrame(
          spacing: 10,
          runSpacing: 6,
          maxRuns: 1,
          overflowBuilder: animatedMore,
          children: _tags(tagCount),
        );

        // Layout 1: one trial, "+9" (28 px) fits after 4 tags; the probe's
        // first-ever layout, so AnimatedSize reports the exact size.
        await tester.pumpWidget(_host(frame(13)));
        expect(tester.takeException(), isNull);
        expect(_shownTags(), [0, 1, 2, 3]);
        expect(find.text('+9'), findsOneWidget);

        // Layout 2: two trials, 12 then 13. A probe reused across trials
        // (not dropped) would still report 28 px for "+12", wrongly
        // fitting 4 tags; a fresh probe reports 42 px and settles at 3.
        await tester.pumpWidget(_host(frame(16)));
        expect(tester.takeException(), isNull);
        expect(_shownTags(), [0, 1, 2]);
        expect(find.text('+13'), findsOneWidget);
        expect(find.text('+12', skipOffstage: false), findsNothing);
      },
    );

    testWidgets(
      'rereview N2: a relayout that builds no overflow child drops the '
      'probe too, so no label of either slot survives',
      (tester) async {
        await tester.pumpWidget(_host(_frame(maxRuns: 1, children: _tags(12))));
        expect(
          find.byKey(const ValueKey('more'), skipOffstage: false),
          findsOneWidget,
        );

        await tester.pumpWidget(_host(_frame(maxRuns: 1, children: _tags(2))));
        expect(find.byKey(const ValueKey('more')), findsNothing);
        expect(
          find.byKey(const ValueKey('more'), skipOffstage: false),
          findsNothing,
        );
      },
    );
  });
}
