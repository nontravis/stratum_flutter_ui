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
  StyledBoxBuilder? boxBuilder,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: AnimatedStyledBox(
        style: style,
        ratio: ratio,
        boxBuilder: boxBuilder,
        child: child,
      ),
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

class _BoxProbe extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_BoxProbe> createState() => _BoxProbeState();
}

class _BoxProbeState extends State<_BoxProbe> {
  @override
  Widget build(BuildContext context) => widget.child;
}

Widget _probe(WidgetStyle style, Widget box) => _BoxProbe(child: box);

void main() {
  _robustnessTests();

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
      const linear = AnimationStyle(
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: linear)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: linear),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
    });

    testWidgets('a missing curve defaults to easeInOutSine', (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: _slow),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        _fillColor(tester),
        Color.lerp(_red, _blue, Curves.easeInOutSine.transform(0.5)),
      );
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

  group('AnimatedStyledBox reduced motion', () {
    const linear = AnimationStyle(
      duration: Duration(milliseconds: 100),
      curve: Curves.linear,
    );
    const small = WidgetStyle(
      width: 40,
      height: 20,
      backgroundColor: _red,
      animationStyle: linear,
    );
    const large = WidgetStyle(
      width: 80,
      height: 40,
      backgroundColor: _blue,
      animationStyle: linear,
    );

    void useFeatures(WidgetTester tester, FakeAccessibilityFeatures features) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('a fade keeps its duration under disableAnimations', (
      tester,
    ) async {
      useFeatures(
        tester,
        const FakeAccessibilityFeatures(disableAnimations: true),
      );
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: linear)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: linear),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // AnimationBehavior.normal would have cut the fade to 5 ms.
      expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
    });

    for (final (name, features) in const [
      ('reduceMotion', FakeAccessibilityFeatures(reduceMotion: true)),
      ('disableAnimations', FakeAccessibilityFeatures(disableAnimations: true)),
    ]) {
      testWidgets('$name: geometry jumps while the color fades', (
        tester,
      ) async {
        useFeatures(tester, features);
        await tester.pumpWidget(_host(small, child: null));
        await tester.pumpWidget(_host(large, child: null));

        expect(tester.getSize(_decorated()), const Size(80, 40));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.getSize(_decorated()), const Size(80, 40));
        expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
      });
    }

    testWidgets('reads the flag again on every style change', (tester) async {
      await tester.pumpWidget(_host(small, child: null));
      await tester.pumpWidget(_host(large, child: null));
      await tester.pumpAndSettle();
      useFeatures(tester, const FakeAccessibilityFeatures(reduceMotion: true));

      await tester.pumpWidget(_host(small, child: null));

      expect(tester.getSize(_decorated()), const Size(40, 20));
    });

    testWidgets('(pin) without a flag the geometry animates', (tester) async {
      await tester.pumpWidget(_host(small, child: null));
      await tester.pumpWidget(_host(large, child: null));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.getSize(_decorated()), const Size(60, 30));
    });
  });

  group('AnimatedStyledBox boxBuilder', () {
    testWidgets('wraps the box inside the margin and outside the size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            width: 40,
            height: 20,
            margin: EdgeInsets.all(8),
          ),
          boxBuilder: _probe,
        ),
      );

      expect(
        find.ancestor(
          of: find.byType(_BoxProbe),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding == const EdgeInsets.all(8),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(_BoxProbe),
          matching: find.byType(ConstrainedBox),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(_BoxProbe)), const Size(40, 20));
    });

    testWidgets('keeps the builder State when an Opacity appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(width: 40, height: 20), boxBuilder: _probe),
      );
      final before = tester.state(find.byType(_BoxProbe));

      await tester.pumpWidget(
        _host(
          const WidgetStyle(width: 40, height: 20, opacity: 0.5),
          boxBuilder: _probe,
        ),
      );

      expect(find.byType(Opacity), findsOneWidget);
      expect(tester.state(find.byType(_BoxProbe)), same(before));
    });

    testWidgets('passes the style of the current frame', (tester) async {
      final radii = <BorderRadiusGeometry?>[];
      Widget record(WidgetStyle style, Widget box) {
        radii.add(style.borderRadius);
        return box;
      }

      const linear = AnimationStyle(
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );

      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            borderRadius: BorderRadius.zero,
            animationStyle: linear,
          ),
          boxBuilder: record,
        ),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            animationStyle: linear,
          ),
          boxBuilder: record,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(radii.last, const BorderRadius.all(Radius.circular(4)));
    });

    testWidgets('applies with a null style', (tester) async {
      await tester.pumpWidget(_host(null, boxBuilder: _probe));

      expect(find.byType(_BoxProbe), findsOneWidget);
    });
  });
}

void _robustnessTests() {
  group('AnimatedStyledBox robustness', () {
    testWidgets('removing a shadow with an overshooting curve does not throw',
        (tester) async {
      const bouncy = AnimationStyle(
        duration: Duration(milliseconds: 100),
        curve: Curves.easeOutBack,
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: _red,
            dropShadow: [BoxShadow(blurRadius: 8)],
            animationStyle: bouncy,
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _red, animationStyle: bouncy),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('min and max that cross mid-animation do not throw',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: _red,
            minWidth: 0,
            maxWidth: 100,
            animationStyle: _slow,
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: _red,
            minWidth: 300,
            animationStyle: _slow,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a focused child keeps focus when a foreground tint appears',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      Widget build(WidgetStyle style) {
        return _host(
          style,
          child: Focus(
            focusNode: node,
            child: const SizedBox(width: 40, height: 20),
          ),
        );
      }

      await tester.pumpWidget(build(const WidgetStyle()));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);

      await tester.pumpWidget(
        build(const WidgetStyle(foregroundColor: Color(0x1F000000))),
      );

      expect(node.hasFocus, isTrue);
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
