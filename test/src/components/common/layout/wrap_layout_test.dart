import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _style = WidgetStyle(backgroundColor: Color(0xFFFFFFFF));
const _first = ValueKey<int>(0);
const _third = ValueKey<int>(2);

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

List<Widget> _tiles() {
  return [
    for (var i = 0; i < 4; i++)
      SizedBox(key: ValueKey<int>(i), width: 40, height: 40),
  ];
}

void main() {
  group('WrapLayout', () {
    testWidgets('builds no AnimatedStyledBox without box values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const WrapLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      await tester.pumpWidget(
        _host(
          const WrapLayout(
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

    testWidgets('keeps clipBehavior and alignment on the Wrap', (tester) async {
      await tester.pumpWidget(
        _host(
          const WrapLayout(
            style: _style,
            clipBehavior: Clip.hardEdge,
            alignment: WrapAlignment.center,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.clipBehavior, Clip.hardEdge);
      expect(wrap.alignment, WrapAlignment.center);
    });

    testWidgets('gap and runGap become spacing and runSpacing', (tester) async {
      await tester.pumpWidget(
        _host(WrapLayout(gap: 4, runGap: 12, children: _tiles())),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 4);
      expect(wrap.runSpacing, 12);
    });

    testWidgets('a null runGap falls back to gap', (tester) async {
      await tester.pumpWidget(_host(WrapLayout(gap: 6, children: _tiles())));

      expect(tester.widget<Wrap>(find.byType(Wrap)).runSpacing, 6);
    });
  });

  group('WrapLayout scrollable', () {
    testWidgets('a horizontal wrap scrolls vertically and still wraps (D1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 100,
            height: 60,
            child: WrapLayout(scrollable: true, children: _tiles()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.vertical,
      );
      expect(
        tester.getTopLeft(find.byKey(_third)).dy,
        greaterThan(tester.getTopLeft(find.byKey(_first)).dy),
      );
    });

    testWidgets('a vertical wrap scrolls horizontally', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 60,
            height: 100,
            child: WrapLayout(
              direction: Axis.vertical,
              scrollable: true,
              children: _tiles(),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.horizontal,
      );
      expect(
        tester.getTopLeft(find.byKey(_third)).dx,
        greaterThan(tester.getTopLeft(find.byKey(_first)).dx),
      );
    });
  });
}
