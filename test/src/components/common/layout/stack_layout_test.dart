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
    testWidgets('builds no AnimatedStyledBox without box values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const StackLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            style: _style,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, _style);
    });

    testWidgets('semantics alone add a node without a box', (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            semantics: SemanticsProperties(label: 'stack'),
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'stack',
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps clipBehavior and alignment on the Stack', (
      tester,
    ) async {
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
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.clipBehavior, isNull);
    });

    testWidgets('(pin) clips the Stack with Clip.hardEdge by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const StackLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(
        tester.widget<Stack>(find.byType(Stack)).clipBehavior,
        Clip.hardEdge,
      );
    });

    testWidgets('scrolls vertically inside the box', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 100,
            height: 100,
            child: StackLayout(
              scrollable: true,
              style: _style,
              children: [SizedBox(width: 20, height: 400)],
            ),
          ),
        ),
      );

      final scroll = find.byType(SingleChildScrollView);
      expect(
        find.ancestor(of: scroll, matching: find.byType(AnimatedStyledBox)),
        findsOneWidget,
      );
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.vertical,
      );
    });
  });
}
