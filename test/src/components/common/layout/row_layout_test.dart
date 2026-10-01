import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('RowLayout', () {
    testWidgets('passes its style to ContainerLayout', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(const RowLayout(style: style, children: [SizedBox(width: 20)])),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, style);
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

    testWidgets('crossAxisIntrinsic applies only without a style height',
        (tester) async {
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
  });
}
