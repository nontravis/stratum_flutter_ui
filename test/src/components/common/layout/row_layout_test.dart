import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _a = ValueKey<String>('a');
const _b = ValueKey<String>('b');

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('RowLayout', () {
    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(const RowLayout(style: style, children: [SizedBox(width: 20)])),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, style);
    });

    testWidgets('builds no AnimatedStyledBox without box values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const RowLayout(children: [SizedBox(width: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('a width in the style makes the row fill it', (tester) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            style: WidgetStyle(width: 200),
            mainAxisSize: MainAxisSize.min,
            children: [SizedBox(width: 20)],
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisSize, MainAxisSize.max);
    });

    testWidgets('crossAxisIntrinsic applies only without a style height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            crossAxisIntrinsic: true,
            children: [SizedBox(width: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicHeight), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const RowLayout(
            crossAxisIntrinsic: true,
            style: WidgetStyle(height: 100),
            children: [SizedBox(width: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicHeight), findsNothing);
    });

    testWidgets('gap becomes Row.spacing, also with an interaction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            gap: 8,
            interaction: StratumInteraction(),
            children: [SizedBox(width: 20), SizedBox(width: 20)],
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.spacing, 8);
      expect(row.children, hasLength(2));
    });
  });

  group('RowLayout scroll', () {
    testWidgets('scrolls horizontally inside the box', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 100,
            height: 50,
            child: RowLayout(
              scroll: StratumScroll(),
              style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
              children: [SizedBox(width: 500, height: 20)],
            ),
          ),
        ),
      );

      final scroll = find.byType(SingleChildScrollView);
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        find.ancestor(of: scroll, matching: find.byType(DecoratedBox)),
        findsWidgets,
      );
    });

    testWidgets('fillViewport stretches short content to the viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 300,
            height: 50,
            child: RowLayout(
              scroll: StratumScroll(fillViewport: true),
              style: WidgetStyle(padding: EdgeInsets.all(10)),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(key: _a, width: 20),
                SizedBox(key: _b, width: 20),
              ],
            ),
          ),
        ),
      );

      final left = tester.getTopLeft(find.byType(RowLayout)).dx;
      expect(tester.getTopLeft(find.byKey(_a)).dx - left, 10);
      expect(tester.getTopRight(find.byKey(_b)).dx - left, 290);
    });

    testWidgets('without fillViewport a max-size row keeps its content '
        'width', (tester) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            scroll: StratumScroll(),
            children: [SizedBox(width: 50, height: 20)],
          ),
        ),
      );

      expect(tester.getSize(find.byType(RowLayout)).width, 50);
    });

    testWidgets('a scrolling row inside IntrinsicHeight lays out without '
        'fillViewport', (tester) async {
      await tester.pumpWidget(
        _host(
          const IntrinsicHeight(
            child: RowLayout(
              scroll: StratumScroll(),
              children: [SizedBox(width: 50, height: 20)],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('an unbounded parent sizes it to the content', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              RowLayout(
                scroll: StratumScroll(fillViewport: true),
                children: [SizedBox(width: 50, height: 20)],
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(RowLayout)).width, 50);
    });
  });
}
