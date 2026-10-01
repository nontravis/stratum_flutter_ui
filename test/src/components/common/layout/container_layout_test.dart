import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _style = WidgetStyle(
  backgroundColor: Color(0xFFFFFFFF),
  padding: EdgeInsets.all(8),
);

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

Finder _inside(Type type) {
  return find.descendant(
    of: find.byType(ContainerLayout),
    matching: find.byType(type),
  );
}

void main() {
  group('ContainerLayout', () {
    testWidgets('hands style and layout values to AnimatedStyledBox',
        (tester) async {
      final transform = Matrix4.translationValues(4, 0, 0);
      await tester.pumpWidget(
        _host(
          ContainerLayout(
            style: _style,
            ratio: 2,
            transform: transform,
            child: const SizedBox(width: 40, height: 20),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, _style);
      expect(box.ratio, 2);
      expect(box.transform, transform);
    });

    testWidgets('hands boxBuilder to AnimatedStyledBox', (tester) async {
      Widget builder(WidgetStyle style, Widget box) => box;

      await tester.pumpWidget(
        _host(
          ContainerLayout(
            boxBuilder: builder,
            child: const SizedBox(width: 40, height: 20),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.boxBuilder, builder);
    });

    testWidgets('adds no outer wrappers by default', (tester) async {
      await tester.pumpWidget(_host(const ContainerLayout(style: _style)));

      for (final type in const [
        Semantics,
        RepaintBoundary,
        WidgetPerformanceMonitor,
        Transform,
      ]) {
        expect(_inside(type), findsNothing, reason: '$type');
      }
    });

    testWidgets('rotate turns degrees into an exact quarter turn',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            rotate: 90,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      final transform = tester.widget<Transform>(_inside(Transform)).transform;
      expect(transform.entry(1, 0), 1.0);
    });

    testWidgets('changing rotate from 0 keeps the child State', (tester) async {
      await tester.pumpWidget(
        _host(const ContainerLayout(rotate: 0, child: _Probe())),
      );
      final before = tester.state(find.byType(_Probe));

      await tester.pumpWidget(
        _host(const ContainerLayout(rotate: 90, child: _Probe())),
      );

      expect(identical(tester.state(find.byType(_Probe)), before), isTrue);
    });

    testWidgets('keepAlive outside a lazy list does not throw',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            keepAlive: true,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('keepAlive keeps a scrolled-away item alive in a ListView',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView(
            children: const [
              ContainerLayout(keepAlive: true, child: _Probe()),
              SizedBox(height: 2000),
            ],
          ),
        ),
      );
      final before = tester.state(find.byType(_Probe));

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      final probe = find.byType(_Probe, skipOffstage: false);
      expect(probe, findsOneWidget);
      expect(identical(tester.state(probe), before), isTrue);
    });

    testWidgets('onEndAnimate fires once after a style animation',
        (tester) async {
      var ends = 0;
      Widget build(Color color) {
        return _host(
          ContainerLayout(
            style: WidgetStyle(
              backgroundColor: color,
              animationStyle: const AnimationStyle(
                duration: Duration(milliseconds: 100),
              ),
            ),
            onEndAnimate: () => ends++,
          ),
        );
      }

      await tester.pumpWidget(build(const Color(0xFFFF0000)));
      await tester.pumpWidget(build(const Color(0xFF0000FF)));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });

    testWidgets('onEndAnimate stays silent on a change without animation',
        (tester) async {
      var ends = 0;
      Widget build(Color color) {
        return _host(
          ContainerLayout(
            style: WidgetStyle(backgroundColor: color),
            onEndAnimate: () => ends++,
          ),
        );
      }

      await tester.pumpWidget(build(const Color(0xFFFF0000)));
      await tester.pumpWidget(build(const Color(0xFF0000FF)));
      await tester.pumpAndSettle();

      expect(ends, 0);
    });

    testWidgets('a ratio of 0 is ignored instead of asserting',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            ratio: 0,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('semantics, repaintBoundary, and debug add their wrappers',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            semantics: SemanticsProperties(label: 'card'),
            repaintBoundary: true,
            debug: true,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'card',
        ),
        findsOneWidget,
      );
      expect(_inside(RepaintBoundary), findsOneWidget);
      expect(_inside(WidgetPerformanceMonitor), findsOneWidget);
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
