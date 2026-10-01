import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _style = WidgetStyle(backgroundColor: Color(0xFFFFFFFF));

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('StackLayout', () {
    testWidgets('builds no ContainerLayout without container values',
        (tester) async {
      await tester.pumpWidget(
        _host(const StackLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(ContainerLayout), findsNothing);
    });

    testWidgets('wraps the stack in ContainerLayout when a style is set',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            style: _style,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, _style);
    });

    testWidgets('semantics alone still wraps the stack', (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            semantics: SemanticsProperties(label: 'stack'),
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      expect(find.byType(ContainerLayout), findsOneWidget);
    });

    testWidgets('keeps clipBehavior and alignment on the Stack',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            style: _style,
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.clipBehavior, Clip.none);
      expect(stack.alignment, Alignment.center);
      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style?.clipBehavior, isNull);
    });
  });
}
