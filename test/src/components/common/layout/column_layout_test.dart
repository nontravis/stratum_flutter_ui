import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _radius = BorderRadius.all(Radius.circular(8));
const _a = ValueKey<String>('a');
const _b = ValueKey<String>('b');

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

/// Gives [child] a bounded viewport of [size].
Widget _sized(Size size, Widget child) {
  return _host(SizedBox.fromSize(size: size, child: child));
}

Finder _decoration() {
  return find.byWidgetPredicate(
    (widget) => widget is DecoratedBox && widget.decoration is StyleDecoration,
  );
}

void main() {
  group('ColumnLayout', () {
    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(
          const ColumnLayout(style: style, children: [SizedBox(height: 20)]),
        ),
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
        _host(const ColumnLayout(children: [SizedBox(height: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('a height in the style makes the column fill it', (
      tester,
    ) async {
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

    testWidgets('crossAxisIntrinsic applies only without a style width', (
      tester,
    ) async {
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

    testWidgets('gap becomes Column.spacing, also with an interaction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            gap: 8,
            interaction: StratumInteraction(),
            children: [SizedBox(height: 20), SizedBox(height: 20)],
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.spacing, 8);
      expect(column.children, hasLength(2));
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

  group('ColumnLayout scrollable', () {
    testWidgets('a scrollable column with a style height lays out', (
      tester,
    ) async {
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

    testWidgets('toggling scrollable keeps the children State', (tester) async {
      Widget build({required bool scrollable}) => _sized(
        const Size(100, 100),
        ColumnLayout(
          style: const WidgetStyle(),
          scrollable: scrollable,
          children: const [_Probe()],
        ),
      );

      await tester.pumpWidget(build(scrollable: false));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(scrollable: true));
      expect(tester.state(find.byType(_Probe)), same(before));

      await tester.pumpWidget(build(scrollable: false));
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('(pin) short content fills a bounded viewport', (tester) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 300),
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(padding: EdgeInsets.all(10)),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(key: _a, height: 20),
              SizedBox(key: _b, height: 20),
            ],
          ),
        ),
      );

      final top = tester.getTopLeft(find.byType(ColumnLayout)).dy;
      expect(tester.getTopLeft(find.byKey(_a)).dy - top, 10);
      expect(tester.getBottomLeft(find.byKey(_b)).dy - top, 290);
    });

    testWidgets(
      'a min-size scrollable column keeps its content height (ruling A)',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const ColumnLayout(
              scrollable: true,
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(height: 50)],
            ),
          ),
        );

        expect(tester.getSize(find.byType(ColumnLayout)).height, 50);
      },
    );

    testWidgets('an unbounded parent sizes it to the content (D17)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              ColumnLayout(scrollable: true, children: [SizedBox(height: 50)]),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ColumnLayout)).height, 50);
    });

    testWidgets('the decoration stays in place while the content scrolls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 200),
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(
              backgroundColor: Color(0xFFFFFFFF),
              padding: EdgeInsets.all(10),
            ),
            children: [SizedBox(key: _a, height: 500)],
          ),
        ),
      );
      final box = tester.getRect(_decoration());
      final content = tester.getTopLeft(find.byKey(_a)).dy;

      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      expect(tester.getRect(_decoration()), box);
      expect(tester.getTopLeft(find.byKey(_a)).dy, content - 100);
    });

    testWidgets('the scroll position survives a style or interaction change', (
      tester,
    ) async {
      Widget build({Border? border, StratumInteraction? interaction}) {
        return themedHost(
          SizedBox.fromSize(
            size: const Size(100, 200),
            child: ColumnLayout(
              scrollable: true,
              style: WidgetStyle(border: border),
              interaction: interaction,
              children: const [SizedBox(height: 500)],
            ),
          ),
        );
      }

      await tester.pumpWidget(build());
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      await tester.pumpWidget(build(border: Border.all()));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        100,
      );

      await tester.pumpWidget(
        build(
          border: Border.all(),
          interaction: StratumInteraction(onTap: () {}),
        ),
      );
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        100,
      );
    });

    testWidgets('a rounded scrollable box builds exactly one clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 200),
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(
              backgroundColor: Color(0xFFFFFFFF),
              borderRadius: _radius,
            ),
            children: [SizedBox(height: 500)],
          ),
        ),
      );

      expect(find.byType(ClipRect), findsNothing);
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.clipBehavior, Clip.antiAlias);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.clipBehavior, Clip.hardEdge);
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
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}
