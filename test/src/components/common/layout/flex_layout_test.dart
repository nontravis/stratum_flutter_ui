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

    for (final (direction, intrinsic, crossStyle) in const [
      (Axis.vertical, IntrinsicWidth, WidgetStyle(width: 100)),
      (Axis.horizontal, IntrinsicHeight, WidgetStyle(height: 100)),
    ]) {
      testWidgets('crossAxisIntrinsic builds $intrinsic unless the style '
          'sets the cross size: $direction', (tester) async {
        await tester.pumpWidget(
          _host(
            FlexLayout(
              direction: direction,
              crossAxisIntrinsic: true,
              children: const [_child],
            ),
          ),
        );
        expect(find.byType(intrinsic), findsOneWidget);

        await tester.pumpWidget(
          _host(
            FlexLayout(
              direction: direction,
              crossAxisIntrinsic: true,
              style: crossStyle,
              children: const [_child],
            ),
          ),
        );
        expect(find.byType(intrinsic), findsNothing);
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
