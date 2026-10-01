import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('ColumnLayout', () {
    testWidgets('passes its style to ContainerLayout', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(
          const ColumnLayout(style: style, children: [SizedBox(height: 20)]),
        ),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, style);
    });

    testWidgets('a height in the style makes the column fill it',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            style: WidgetStyle(height: 200),
            mainAxisSize: MainAxisSize.min,
            children: [SizedBox(height: 20)],
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.mainAxisSize, MainAxisSize.max);
    });

    testWidgets('crossAxisIntrinsic applies only without a style width',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            crossAxisIntrinsic: true,
            children: [SizedBox(height: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicWidth), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            crossAxisIntrinsic: true,
            style: WidgetStyle(width: 100),
            children: [SizedBox(height: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicWidth), findsNothing);
    });

    testWidgets('a scrollable column with a style height lays out',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(height: 200),
            children: [SizedBox(height: 100)],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('forwards onEndAnimate', (tester) async {
      var ends = 0;
      Widget build(Color color) {
        return _host(
          ColumnLayout(
            style: WidgetStyle(
              backgroundColor: color,
              animationStyle: const AnimationStyle(
                duration: Duration(milliseconds: 100),
              ),
            ),
            onEndAnimate: () => ends++,
            children: const [SizedBox(height: 20)],
          ),
        );
      }

      await tester.pumpWidget(build(const Color(0xFFFF0000)));
      await tester.pumpWidget(build(const Color(0xFF0000FF)));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });
  });
}
