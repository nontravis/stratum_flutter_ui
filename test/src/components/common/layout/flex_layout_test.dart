import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _child = SizedBox(width: 20, height: 20);

void _noop() {}

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

Flex _flex(WidgetTester tester) => tester.widget<Flex>(find.byType(Flex));

FocusNode _node(String label) {
  final node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

void main() {
  group('FlexLayout', () {
    for (final direction in Axis.values) {
      testWidgets('builds a $direction Flex', (tester) async {
        await tester.pumpWidget(
          _host(FlexLayout(direction: direction, children: const [_child])),
        );

        expect(_flex(tester).direction, direction);
        expect(find.byType(AnimatedStyledBox), findsNothing);
      });
    }

    for (final (direction, style) in const [
      (Axis.vertical, WidgetStyle(height: 200)),
      (Axis.vertical, WidgetStyle(maxHeight: 200)),
      (Axis.horizontal, WidgetStyle(width: 200)),
      (Axis.horizontal, WidgetStyle(maxWidth: 200)),
    ]) {
      testWidgets('a main-axis size in the style forces MainAxisSize.max: '
          '$direction, $style', (tester) async {
        await tester.pumpWidget(
          _host(
            FlexLayout(
              direction: direction,
              style: style,
              mainAxisSize: MainAxisSize.min,
              children: const [_child],
            ),
          ),
        );

        expect(_flex(tester).mainAxisSize, MainAxisSize.max);
      });
    }

    for (final (direction, style) in const [
      (Axis.vertical, WidgetStyle(width: 200)),
      (Axis.horizontal, WidgetStyle(height: 200)),
    ]) {
      testWidgets('a cross-axis size keeps MainAxisSize.min: $direction', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            FlexLayout(
              direction: direction,
              style: style,
              mainAxisSize: MainAxisSize.min,
              children: const [_child],
            ),
          ),
        );

        expect(_flex(tester).mainAxisSize, MainAxisSize.min);
      });
    }

    for (final (direction, crossStyle) in const [
      (Axis.vertical, WidgetStyle(width: 100)),
      (Axis.horizontal, WidgetStyle(height: 100)),
    ]) {
      testWidgets('crossAxisIntrinsic sizes the cross axis to the largest '
          'child unless the style sets it: $direction', (tester) async {
        const stretched = Key('stretched');
        final vertical = direction == Axis.vertical;
        double cross(Size size) => vertical ? size.width : size.height;
        Widget flex({WidgetStyle? style}) => _host(
          FlexLayout(
            direction: direction,
            crossAxisIntrinsic: true,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            style: style,
            children: [
              // The largest child, 60 px across the axis.
              SizedBox(width: vertical ? 60 : 20, height: vertical ? 20 : 60),
              const SizedBox(key: stretched, width: 20, height: 20),
            ],
          ),
        );

        await tester.pumpWidget(flex());
        expect(cross(tester.getSize(find.byType(FlexLayout))), 60);
        expect(cross(tester.getSize(find.byKey(stretched))), 60);

        await tester.pumpWidget(flex(style: crossStyle));
        expect(cross(tester.getSize(find.byType(FlexLayout))), 100);
        expect(cross(tester.getSize(find.byKey(stretched))), 100);
      });
    }

    for (final direction in Axis.values) {
      final reference = direction == Axis.vertical
          ? 'IntrinsicWidth'
          : 'IntrinsicHeight';
      testWidgets('crossAxisIntrinsic answers intrinsic, dry layout, dry '
          'baseline, and unbounded layout as $reference does: $direction', (
        tester,
      ) async {
        final vertical = direction == Axis.vertical;
        // The aspect ratio's size across the axis follows its size along
        // it, and the turned text's least height is its longest word, so
        // every answer depends on the size the layout gives its child.
        // Neither has a baseline.
        const children = [
          IgnoreBaseline(
            child: AspectRatio(aspectRatio: 1, child: SizedBox(width: 30)),
          ),
          Text('a'),
          Text('a longer line that wraps'),
          IgnoreBaseline(
            child: RotatedBox(quarterTurns: 1, child: Text('turned text')),
          ),
        ];
        Widget layout() => FlexLayout(
          direction: direction,
          crossAxisIntrinsic: true,
          children: children,
        );
        final inner = find.descendant(
          of: find.byType(FlexLayout),
          matching: find.byType(Flex),
        );
        await tester.pumpWidget(_host(layout()));
        final flex = tester.widget<Flex>(inner);

        // Both lay out side by side under unbounded constraints.
        await tester.pumpWidget(
          _host(
            UnconstrainedBox(
              child: Flex(
                direction: vertical ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                children: [
                  layout(),
                  if (vertical)
                    IntrinsicWidth(child: flex)
                  else
                    IntrinsicHeight(child: flex),
                ],
              ),
            ),
          ),
        );
        final cross =
            tester.renderObject<RenderBox>(inner).parent! as RenderBox;
        final expected = tester.renderObject<RenderBox>(
          find.byType(vertical ? IntrinsicWidth : IntrinsicHeight),
        );

        expect(cross, isNot(same(expected)));
        expect(cross.size, expected.size);
        for (final extent in [0.0, 40.0, 120.0, 600.0, double.infinity]) {
          expect(
            cross.getMinIntrinsicWidth(extent),
            expected.getMinIntrinsicWidth(extent),
            reason: 'min width at height $extent',
          );
          expect(
            cross.getMaxIntrinsicWidth(extent),
            expected.getMaxIntrinsicWidth(extent),
            reason: 'max width at height $extent',
          );
          expect(
            cross.getMinIntrinsicHeight(extent),
            expected.getMinIntrinsicHeight(extent),
            reason: 'min height at width $extent',
          );
          expect(
            cross.getMaxIntrinsicHeight(extent),
            expected.getMaxIntrinsicHeight(extent),
            reason: 'max height at width $extent',
          );
        }
        for (final constraints in const [
          BoxConstraints(),
          BoxConstraints(maxWidth: 120),
          BoxConstraints(maxHeight: 40),
          BoxConstraints(maxWidth: 600, maxHeight: 600),
          BoxConstraints.tightFor(width: 80),
          BoxConstraints.tightFor(height: 80),
        ]) {
          expect(
            cross.getDryLayout(constraints),
            expected.getDryLayout(constraints),
            reason: 'dry layout under $constraints',
          );
          expect(
            cross.getDryBaseline(constraints, TextBaseline.alphabetic),
            expected.getDryBaseline(constraints, TextBaseline.alphabetic),
            reason: 'dry baseline under $constraints',
          );
        }
      });
    }

    for (final direction in Axis.values) {
      testWidgets('scroll scrolls along $direction without a direction of '
          'its own', (tester) async {
        await tester.pumpWidget(
          _host(
            FlexLayout(
              direction: direction,
              scroll: const StratumScroll(),
              children: const [_child],
            ),
          ),
        );

        final view = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(view.scrollDirection, direction);
      });
    }

    for (final (direction, next, previous) in const [
      (
        Axis.vertical,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
      ),
      (
        Axis.horizontal,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
      ),
    ]) {
      testWidgets('focusGroup arrows move along $direction', (tester) async {
        final items = [_node('item 0'), _node('item 1'), _node('item 2')];
        await tester.pumpWidget(
          themedHost(
            FlexLayout(
              direction: direction,
              mainAxisSize: MainAxisSize.min,
              focusGroup: const StratumFocusGroup(),
              children: [
                for (final item in items)
                  ContainerLayout(
                    style: const WidgetStyle(width: 40, height: 40),
                    interaction: StratumInteraction(
                      onTap: _noop,
                      focusNode: item,
                    ),
                  ),
              ],
            ),
          ),
        );
        items[0].requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(next);
        await tester.pump();
        expect(items[1].hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(next);
        await tester.pump();
        expect(items[2].hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(previous);
        await tester.pump();
        expect(items[1].hasPrimaryFocus, isTrue);
      });
    }

    // The width and height of each layout below in the 800 by 600 window,
    // vertical and then horizontal: the main axis fills the window unless
    // the style sizes it; null takes the field's own size, which sizes the
    // cross axis unless the style does.
    for (final (name, style, vertical, horizontal) in const [
      ('no style', null, (null, 600.0), (800.0, null)),
      (
        'a width-only style',
        WidgetStyle(width: 200),
        (200.0, 600.0),
        (200.0, null),
      ),
      (
        'a height-only style',
        WidgetStyle(height: 200),
        (null, 200.0),
        (800.0, 200.0),
      ),
    ]) {
      testWidgets('with crossAxisIntrinsic, a direction change keeps a '
          "focused TextField's State, text, focus, and size: $name "
          '(us08/fr01/e01)', (tester) async {
        Widget flex(Axis direction) => MaterialApp(
          home: Material(
            child: Center(
              child: FlexLayout(
                direction: direction,
                crossAxisIntrinsic: true,
                style: style,
                children: const [SizedBox(width: 120, child: TextField())],
              ),
            ),
          ),
        );
        void expectSize(Axis direction) {
          final (width, height) = direction == Axis.vertical
              ? vertical
              : horizontal;
          final field = tester.getSize(find.byType(TextField));
          expect(
            tester.getSize(find.byType(FlexLayout)),
            Size(width ?? field.width, height ?? field.height),
          );
        }

        await tester.pumpWidget(flex(Axis.vertical));
        await tester.enterText(find.byType(TextField), 'typed');
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(state.widget.focusNode.hasFocus, isTrue);
        expectSize(Axis.vertical);

        await tester.pumpWidget(flex(Axis.horizontal));
        expectSize(Axis.horizontal);
        await tester.pumpWidget(flex(Axis.vertical));
        expectSize(Axis.vertical);

        final after = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(identical(after, state), isTrue);
        expect(after.textEditingValue.text, 'typed');
        expect(after.widget.focusNode.hasFocus, isTrue);
      });
    }

    testWidgets("a direction change keeps the children's State", (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const FlexLayout(direction: Axis.vertical, children: [_Probe()]),
        ),
      );
      final before = tester.state(find.byType(_Probe));

      await tester.pumpWidget(
        _host(
          const FlexLayout(direction: Axis.horizontal, children: [_Probe()]),
        ),
      );

      expect(_flex(tester).direction, Axis.horizontal);
      expect(identical(tester.state(find.byType(_Probe)), before), isTrue);
    });

    test('ColumnLayout and RowLayout are FlexLayout with their direction', () {
      expect(
        const ColumnLayout(children: []),
        isA<FlexLayout>().having(
          (f) => f.direction,
          'direction',
          Axis.vertical,
        ),
      );
      expect(
        const RowLayout(children: []),
        isA<FlexLayout>().having(
          (f) => f.direction,
          'direction',
          Axis.horizontal,
        ),
      );
    });
  });
}

class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20);
}
