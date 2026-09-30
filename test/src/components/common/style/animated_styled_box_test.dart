import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/animated_styled_box.dart';
import 'package:stratum_ui/src/components/common/style/style_decoration.dart';

const _radius = BorderRadius.all(Radius.circular(8));
const _blur = ImageBlurFilter(sigmaX: 10, sigmaY: 10);
const _slow = AnimationStyle(duration: Duration(milliseconds: 100));
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

Widget _host(
  WidgetStyle? style, {
  Widget? child = const SizedBox(width: 40, height: 20),
  double? ratio,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: AnimatedStyledBox(style: style, ratio: ratio, child: child),
    ),
  );
}

Finder _decorated({bool Function(StyleDecoration decoration)? where}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is StyleDecoration &&
        (where?.call(widget.decoration as StyleDecoration) ?? true),
  );
}

Color? _fillColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_decorated());
  return (box.decoration as StyleDecoration).color;
}

void main() {
  group('AnimatedStyledBox structure', () {
    testWidgets('a fill, radius, and padding add no effect layers',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            borderRadius: _radius,
            padding: EdgeInsets.all(8),
          ),
        ),
      );

      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.byType(Padding), findsOneWidget);
      for (final type in const [
        Opacity,
        ClipRRect,
        ClipRect,
        BackdropFilter,
        ImageFiltered,
        ConstrainedBox,
        Align,
        Transform,
      ]) {
        expect(find.byType(type), findsNothing, reason: '$type');
      }
    });

    testWidgets('a null style passes the child through', (tester) async {
      await tester.pumpWidget(_host(null));

      expect(find.byType(DecoratedBox), findsNothing);
      expect(find.byType(Padding), findsNothing);
      expect(
        tester.getSize(find.byType(AnimatedStyledBox)),
        const Size(40, 20),
      );
    });

    testWidgets('a style with only layout fields builds no background',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(padding: EdgeInsets.all(4), borderRadius: _radius),
        ),
      );

      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('opacity below 1 adds Opacity, and 1 does not',
        (tester) async {
      await tester.pumpWidget(_host(const WidgetStyle(opacity: 1)));
      expect(find.byType(Opacity), findsNothing);

      await tester.pumpWidget(_host(const WidgetStyle(opacity: 0.5)));
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets(
        'backgroundBlur clips above the filter and keeps the shadow outside',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            borderRadius: _radius,
            backgroundColor: Color(0x80FFFFFF),
            dropShadow: [BoxShadow(blurRadius: 8)],
            backgroundBlur: _blur,
          ),
        ),
      );

      final clip = find.byType(ClipRRect);
      final filter = find.byType(BackdropFilter);
      final shadow = _decorated(where: (d) => d.dropShadow != null);
      final fill = _decorated(
        where: (d) => d.color == const Color(0x80FFFFFF),
      );
      expect(find.ancestor(of: filter, matching: clip), findsOneWidget);
      expect(find.ancestor(of: clip, matching: shadow), findsOneWidget);
      expect(find.ancestor(of: fill, matching: filter), findsOneWidget);
    });

    testWidgets('backgroundBlur without a radius clips with ClipRect',
        (tester) async {
      await tester.pumpWidget(_host(const WidgetStyle(backgroundBlur: _blur)));

      expect(find.byType(ClipRRect), findsNothing);
      final clip = tester.widget<ClipRect>(find.byType(ClipRect));
      expect(clip.clipBehavior, Clip.hardEdge);
    });

    testWidgets('clipBehavior without blur clips inside the background',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            dropShadow: [BoxShadow(blurRadius: 8)],
            borderRadius: _radius,
            clipBehavior: Clip.antiAlias,
          ),
        ),
      );

      expect(
        find.ancestor(of: find.byType(ClipRRect), matching: _decorated()),
        findsOneWidget,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('foregroundBlur needs a child', (tester) async {
      const style = WidgetStyle(foregroundBlur: _blur);

      await tester.pumpWidget(_host(style, child: null));
      expect(find.byType(ImageFiltered), findsNothing);

      await tester.pumpWidget(_host(style));
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('foreground fields paint over the background', (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            foregroundColor: Color(0x1F000000),
          ),
        ),
      );

      final foreground = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground,
      );
      expect(
        find.ancestor(of: _decorated(), matching: foreground),
        findsOneWidget,
      );
    });

    testWidgets('min and max constraints win over width', (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            width: 300,
            maxWidth: 100,
            height: 50,
          ),
        ),
      );

      expect(tester.getSize(_decorated()), const Size(100, 50));
    });

    testWidgets('a null child becomes an empty box sized by padding',
        (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(padding: EdgeInsets.all(4)), child: null),
      );

      expect(tester.getSize(find.byType(Padding)), const Size(8, 8));
    });

    testWidgets('ratio wraps the child in AspectRatio', (tester) async {
      await tester.pumpWidget(_host(null, ratio: 2));

      expect(find.byType(AspectRatio), findsOneWidget);
    });
  });

  group('AnimatedStyledBox animation', () {
    testWidgets('a null animationStyle applies the new style at once',
        (tester) async {
      await tester.pumpWidget(_host(const WidgetStyle(backgroundColor: _red)));
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _blue)),
      );

      expect(_fillColor(tester), _blue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a set duration interpolates half-way', (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: _slow),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
    });

    testWidgets('an equal style does not restart the animation',
        (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );
      await tester.pumpWidget(
        // A new instance with equal fields, as a build method would create.
        // ignore: prefer_const_constructors
        _host(WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('onEnd fires once when an animation completes',
        (tester) async {
      var ends = 0;
      Widget build(Color color) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedStyledBox(
            style: WidgetStyle(backgroundColor: color, animationStyle: _slow),
            onEnd: () => ends++,
          ),
        );
      }

      await tester.pumpWidget(build(_red));
      await tester.pumpWidget(build(_blue));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });

    testWidgets('a null target interrupts an animation without error',
        (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: _slow),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(_host(null));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_decorated(), findsNothing);
    });

    testWidgets('the child keeps its State when wrappers come and go',
        (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(), child: const _Probe()),
      );
      final before = tester.state(find.byType(_Probe));

      for (final style in const [
        WidgetStyle(foregroundColor: Color(0x1F000000)),
        WidgetStyle(opacity: 0.5),
        WidgetStyle(margin: EdgeInsets.all(4), backgroundBlur: _blur),
        WidgetStyle(animationStyle: AnimationStyle.noAnimation),
        WidgetStyle(),
      ]) {
        await tester.pumpWidget(_host(style, child: const _Probe()));
        expect(
          identical(tester.state(find.byType(_Probe)), before),
          isTrue,
          reason: '$style',
        );
      }
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
