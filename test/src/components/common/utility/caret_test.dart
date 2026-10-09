import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/utility/caret.dart'
    show CaretPainter;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// The one widget that paints a caret glyph.
final Finder _glyph = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is CaretPainter,
);

CaretPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_glyph).painter! as CaretPainter;

/// The style, side, color, and angle the glyph paints with.
List<Object> _look(WidgetTester tester) {
  final painter = _painter(tester);
  return [painter.style, painter.side, painter.color, painter.angle];
}

/// The path and the paint of the glyph's one `drawPath` call.
({Path path, Paint paint}) _drawn() {
  late Path path;
  late Paint paint;
  expect(
    _glyph,
    paints..something((method, arguments) {
      if (method != #drawPath) return false;
      path = arguments[0] as Path;
      paint = arguments[1] as Paint;
      return true;
    }),
  );
  return (path: path, paint: paint);
}

/// The style of the caret's own box, which `customStyle` reaches.
WidgetStyle _box(WidgetTester tester) => tester
    .widget<ContainerLayout>(
      find
          .descendant(
            of: find.byType(StratumCaret),
            matching: find.byType(ContainerLayout),
          )
          .first,
    )
    .style!;

/// [caret] on the package default theme, in [mode].
Widget _defaultThemeHost(Widget caret, {ThemeMode mode = ThemeMode.light}) =>
    StratumThemeApplication(
      themes: defaultThemeSet,
      themeMode: mode,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: caret),
      ),
    );

const _custom = Color(0xFF123456);

/// A caret pointing [direction] under [textDirection] on [theme], else on
/// [fakeTheme], whose fast level is the package default 125 ms on
/// easeInOutSine.
Widget _turning(
  StratumCaretDirection direction, {
  TextDirection textDirection = TextDirection.ltr,
  StratumThemeData? theme,
  Color? customColor,
}) => themedHost(
  StratumCaret(direction: direction, customColor: customColor),
  theme: theme,
  textDirection: textDirection,
);

double _angle(WidgetTester tester) => _painter(tester).angle;

/// [fakeTheme] with its fast level replaced by [fast].
StratumThemeData _fastLevel(AnimationStyle fast) {
  final motion = fakeTheme.animation;
  return fakeTheme.copyWith(
    animation: StratumAnimation(
      veryFast: motion.veryFast,
      fast: fast,
      normal: motion.normal,
      slow: motion.slow,
      verySlow: motion.verySlow,
      appear: motion.appear,
      defaultLevel: motion.defaultLevel,
      transition: motion.transition,
    ),
  );
}

void main() {
  group('StratumCaret glyph', () {
    testWidgets('us01/fr01/e01, us01/s1: with no values set it draws a '
        '16 px caret pointing down as a 1.5 px round chevron', (tester) async {
      await tester.pumpWidget(themedHost(const StratumCaret()));

      expect(tester.getSize(find.byType(StratumCaret)), const Size(16, 16));
      expect(_painter(tester).angle, 0);
      expect(_painter(tester).style, StratumCaretStyle.regular);
      final (:path, :paint) = _drawn();
      expect(paint.style, PaintingStyle.stroke);
      expect(paint.strokeWidth, 1.5);
      expect(paint.strokeCap, StrokeCap.round);
      expect(paint.strokeJoin, StrokeJoin.round);
      expect(paint.color, isSameColorAs(fakeTheme.color.icon.defaults.primary));
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-5, -2.5, 5, 2.5)),
      );
      // Round caps and joins reach half the line past the centerline:
      // the Figma REGULAR outline box (R8).
      expect(
        path.getBounds().inflate(paint.strokeWidth / 2).size,
        const Size(11.5, 6.5),
      );
    });

    testWidgets('us01/fr01/e02, us01/s2: light draws the round chevron '
        '1.0 px wide, 11 x 6 in the 16 px box', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumCaret(style: StratumCaretStyle.light)),
      );

      final (:path, :paint) = _drawn();
      expect(paint.style, PaintingStyle.stroke);
      expect(paint.strokeWidth, 1.0);
      expect(paint.strokeCap, StrokeCap.round);
      expect(paint.strokeJoin, StrokeJoin.round);
      expect(
        path.getBounds().inflate(paint.strokeWidth / 2).size,
        const Size(11, 6),
      );
    });

    testWidgets('us01/fr01/e03, us01/s2: fill draws a solid triangle 11 x 6 '
        'with no line', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumCaret(style: StratumCaretStyle.fill)),
      );

      final (:path, :paint) = _drawn();
      expect(paint.style, PaintingStyle.fill);
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-5.5, -3, 5.5, 3)),
      );
    });

    for (final style in StratumCaretStyle.values) {
      testWidgets('us01/fr01/e04: up points the ${style.name} glyph up', (
        tester,
      ) async {
        await tester.pumpWidget(
          themedHost(
            StratumCaret(style: style, direction: StratumCaretDirection.up),
          ),
        );

        expect(_painter(tester).angle, math.pi);
        expect(
          _glyph,
          paints
            ..translate(x: 8, y: 8)
            ..rotate(angle: math.pi),
        );
      });
    }
  });

  group('StratumCaret size', () {
    const sides = {
      WidgetSize.tiny: 10.0,
      WidgetSize.extraSmall: 12.0,
      WidgetSize.small: 14.0,
      WidgetSize.medium: 16.0,
      WidgetSize.large: 20.0,
      WidgetSize.extraLarge: 24.0,
      WidgetSize.huge: 32.0,
    };
    for (final MapEntry(key: size, value: side) in sides.entries) {
      testWidgets('us01/fr02: ${size.name} gives a $side px box', (
        tester,
      ) async {
        await tester.pumpWidget(themedHost(StratumCaret(size: size)));

        expect(tester.getSize(find.byType(StratumCaret)), Size.square(side));
        expect(_painter(tester).side, side);
      });
    }

    testWidgets("us01/fr02/e01: no size takes the theme's default widget "
        'size', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const StratumCaret(),
          theme: fakeTheme.copyWith(defaultWidgetSize: WidgetSize.large),
        ),
      );

      expect(tester.getSize(find.byType(StratumCaret)), const Size(20, 20));
    });

    testWidgets('us01/fr02/e02, us01/s4: customSize wins over size', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(const StratumCaret(size: WidgetSize.small, customSize: 40)),
      );

      expect(tester.getSize(find.byType(StratumCaret)), const Size(40, 40));
      expect(_painter(tester).side, 40);
    });

    testWidgets('customSize of -1 fails the assertion', (tester) async {
      expect(() => StratumCaret(customSize: -1), throwsAssertionError);
    });

    testWidgets('customSize of NaN fails the assertion', (tester) async {
      expect(() => StratumCaret(customSize: double.nan), throwsAssertionError);
    });

    testWidgets('customSize of infinity fails the assertion', (tester) async {
      expect(
        () => StratumCaret(customSize: double.infinity),
        throwsAssertionError,
      );
    });

    testWidgets('customSize of 0 builds', (tester) async {
      await tester.pumpWidget(themedHost(const StratumCaret(customSize: 0)));

      expect(tester.getSize(find.byType(StratumCaret)), Size.zero);
    });

    testWidgets('us01/s3, R1: a regular caret at the large size measures '
        '20 px and keeps its 1.5 px line', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumCaret(size: WidgetSize.large)),
      );

      final (:path, :paint) = _drawn();
      expect(tester.getSize(find.byType(StratumCaret)), const Size(20, 20));
      expect(paint.strokeWidth, 1.5);
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-6.25, -3.125, 6.25, 3.125)),
      );
    });

    testWidgets('us01/fr02/e03, us01/s5: in a 100 x 100 space the glyph '
        'keeps its 16 px and sits centered', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const SizedBox(width: 100, height: 100, child: StratumCaret()),
        ),
      );

      expect(_glyph, paints..translate(x: 50, y: 50));
      final (:path, paint: _) = _drawn();
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-5, -2.5, 5, 2.5)),
      );
    });

    testWidgets('us01/fr02/e04: a fill caret at the large size scales its '
        'triangle to the 20 px box', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const StratumCaret(
            style: StratumCaretStyle.fill,
            size: WidgetSize.large,
          ),
        ),
      );

      final (:path, :paint) = _drawn();
      expect(paint.style, PaintingStyle.fill);
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-6.875, -3.75, 6.875, 3.75)),
      );
    });

    testWidgets('us01/fr02: in a row the caret keeps its square box', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const Row(mainAxisSize: MainAxisSize.min, children: [StratumCaret()]),
        ),
      );

      expect(tester.getSize(find.byType(StratumCaret)), const Size(16, 16));
    });
  });

  group('StratumCaret color', () {
    testWidgets('us01/fr03/e01: no color draws icon.default.primary, 80% '
        'black on the light default theme', (tester) async {
      await tester.pumpWidget(_defaultThemeHost(const StratumCaret()));

      expect(
        _painter(tester).color,
        isSameColorAs(defaultThemeSet.light.color.icon.defaults.primary),
      );
      expect(
        _painter(tester).color,
        isSameColorAs(StratumTransparentTokens.builtIn.black.p80),
      );
    });

    testWidgets('us01/fr03/e01: no color draws 100% white on the dark '
        'default theme', (tester) async {
      await tester.pumpWidget(
        _defaultThemeHost(const StratumCaret(), mode: ThemeMode.dark),
      );

      expect(
        _painter(tester).color,
        isSameColorAs(StratumTransparentTokens.builtIn.white.p100),
      );
    });

    testWidgets("us01/fr03/e01: the caret's own themeMode picks the dark "
        'token under a light app', (tester) async {
      await tester.pumpWidget(
        _defaultThemeHost(const StratumCaret(themeMode: ThemeMode.dark)),
      );

      expect(
        _painter(tester).color,
        isSameColorAs(defaultThemeSet.dark!.color.icon.defaults.primary),
      );
    });

    testWidgets('us01/fr03/e02, us01/s6: customColor wins over color', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const StratumCaret(color: ColorEnum.blue, customColor: _custom),
        ),
      );

      expect(_painter(tester).color, _custom);
    });

    testWidgets("us01/fr03/e03: blue draws the theme's icon.color.blue", (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(const StratumCaret(color: ColorEnum.blue)),
      );

      expect(_painter(tester).color, fakeTheme.color.icon.color.blue);
    });

    testWidgets('us01/fr03/e04, us01/s9: red, which icon.color lacks, draws '
        'icon.default.primary', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumCaret(color: ColorEnum.red)),
      );

      expect(_painter(tester).color, fakeTheme.color.icon.defaults.primary);
    });
  });

  group('StratumCaret base props', () {
    Future<(List<Object>, WidgetStyle)> baseline(WidgetTester tester) async {
      await tester.pumpWidget(themedHost(const StratumCaret()));
      return (_look(tester), _box(tester));
    }

    testWidgets('us01/fr04/e01, us01/s7, D11: disabled adds no look of its '
        'own; the dimming belongs to StratumDisabled', (tester) async {
      final (look, box) = await baseline(tester);

      await tester.pumpWidget(themedHost(const StratumCaret(disabled: true)));

      expect(_look(tester), look);
      expect(_box(tester), box);
    });

    for (final state in [
      FullWidgetState.hovered,
      FullWidgetState.pressed,
      FullWidgetState.focused,
      FullWidgetState.dragged,
    ]) {
      testWidgets('us01/fr04/e02: ${state.name} keeps the look', (
        tester,
      ) async {
        final (look, box) = await baseline(tester);

        await tester.pumpWidget(themedHost(StratumCaret(state: state)));

        expect(_look(tester), look);
        expect(_box(tester), box);
      });
    }

    for (final feedback in FeedbackState.values) {
      testWidgets('us01/fr04/e03: feedback ${feedback.name} keeps the look '
          'and color', (tester) async {
        final (look, box) = await baseline(tester);

        await tester.pumpWidget(
          themedHost(StratumCaret(feedbackState: feedback)),
        );

        expect(_look(tester), look);
        expect(_box(tester), box);
      });
    }

    testWidgets('us01/fr04/e04: loading keeps the look', (tester) async {
      final (look, box) = await baseline(tester);

      await tester.pumpWidget(themedHost(const StratumCaret(loading: true)));

      expect(_look(tester), look);
      expect(_box(tester), box);
    });

    testWidgets('us01/fr04/e05, us01/s8: customStyle fills the box and the '
        'glyph keeps its style, size, and color', (tester) async {
      const fill = Color(0xFFEEEEEE);
      final (look, _) = await baseline(tester);

      await tester.pumpWidget(
        themedHost(
          const StratumCaret(customStyle: WidgetStyle(backgroundColor: fill)),
        ),
      );

      expect(_box(tester).backgroundColor, fill);
      expect(_box(tester).width, 16);
      expect(_look(tester), look);
    });
  });

  group('StratumCaret text direction', () {
    // Angles run clockwise from pointing down: a quarter turn points
    // left, three quarters point right.
    const quarter = math.pi / 2;
    for (final (name, textDirection, direction, angle) in [
      (
        'us02/fr01/e01: left to right, start points left',
        TextDirection.ltr,
        StratumCaretDirection.start,
        quarter,
      ),
      (
        'us02/fr01/e01: left to right, end points right',
        TextDirection.ltr,
        StratumCaretDirection.end,
        3 * quarter,
      ),
      (
        'us02/fr01/e02, nfr-l02: right to left, start points right',
        TextDirection.rtl,
        StratumCaretDirection.start,
        3 * quarter,
      ),
      (
        'us02/fr01/e02, us02/s4, nfr-l02: right to left, end points left',
        TextDirection.rtl,
        StratumCaretDirection.end,
        quarter,
      ),
      (
        'us02/fr01/e03, nfr-l02: right to left, up points up',
        TextDirection.rtl,
        StratumCaretDirection.up,
        math.pi,
      ),
      (
        'us02/fr01/e03, nfr-l02: right to left, down points down',
        TextDirection.rtl,
        StratumCaretDirection.down,
        0.0,
      ),
    ]) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(
          themedHost(
            StratumCaret(direction: direction),
            textDirection: textDirection,
          ),
        );

        expect(_painter(tester).angle, moreOrLessEquals(angle));
      });
    }
  });

  testWidgets('us02/fr05/e01, us02/s7: the caret adds nothing to its '
      "owner's semantics", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      themedHost(
        Semantics(
          container: true,
          label: 'Details',
          expanded: true,
          child: const StratumCaret(),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Details'));
    expect(
      node,
      matchesSemantics(
        label: 'Details',
        hasExpandedState: true,
        isExpanded: true,
      ),
    );
    expect(node.childrenCount, 0);
    semantics.dispose();
  });

  group('StratumCaret turn', () {
    testWidgets('us02/fr02/e02, us02/s1: the first half turn, down to up, '
        'turns clockwise over the 125 ms fast level', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pumpWidget(_turning(StratumCaretDirection.up));
      expect(_angle(tester), 0);

      await tester.pump(const Duration(milliseconds: 62));
      expect(_angle(tester), allOf(greaterThan(0), lessThan(math.pi)));

      await tester.pump(const Duration(milliseconds: 62));
      expect(_angle(tester), lessThan(math.pi));

      // 1 ms past the 125 ms fast level: AnimationController's isDone is
      // strictly past its duration, so the ticker unregisters one tick
      // after the value already reads its end.
      await tester.pump(const Duration(milliseconds: 2));
      expect(_angle(tester), math.pi);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('us02/fr02/e03, us02/s2: the next half turn, up to down, '
        'turns back counterclockwise', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pumpWidget(_turning(StratumCaretDirection.up));
      await tester.pumpAndSettle();
      expect(_angle(tester), math.pi);

      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pump(const Duration(milliseconds: 62));
      expect(_angle(tester), allOf(greaterThan(0), lessThan(math.pi)));
      await tester.pumpAndSettle();
      expect(_angle(tester), 0);
    });

    testWidgets('us02/fr02/e03: a third half turn goes clockwise again, '
        'opposite to the second', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      for (final direction in [
        StratumCaretDirection.up,
        StratumCaretDirection.down,
        StratumCaretDirection.up,
      ]) {
        await tester.pumpWidget(_turning(direction));
        await tester.pumpAndSettle();
      }

      expect(_angle(tester), math.pi);
    });

    testWidgets('us02/fr02/e01, us02/s3: end to down in a left-to-right app '
        'turns a quarter clockwise, never three quarters back', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.end));
      expect(_angle(tester), moreOrLessEquals(3 * math.pi / 2));

      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pump(const Duration(milliseconds: 62));
      expect(
        _angle(tester),
        allOf(greaterThan(3 * math.pi / 2), lessThan(2 * math.pi)),
      );
      await tester.pumpAndSettle();
      expect(_angle(tester), moreOrLessEquals(2 * math.pi));
    });

    testWidgets('us02/fr02/e04: down to start turns a quarter clockwise, '
        'then start to end, the first half turn, turns clockwise', (
      tester,
    ) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pumpWidget(_turning(StratumCaretDirection.start));
      await tester.pumpAndSettle();
      expect(_angle(tester), moreOrLessEquals(math.pi / 2));

      await tester.pumpWidget(_turning(StratumCaretDirection.end));
      await tester.pumpAndSettle();
      expect(_angle(tester), moreOrLessEquals(3 * math.pi / 2));
    });

    testWidgets('us02/fr02/e04: a quarter turn between two half turns leaves '
        'the next half turn opposite to the last one', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      for (final direction in [
        StratumCaretDirection.up,
        StratumCaretDirection.start,
        StratumCaretDirection.end,
      ]) {
        await tester.pumpWidget(_turning(direction));
        await tester.pumpAndSettle();
      }

      // down → up: +π, clockwise; up → start: −π/2, the short way;
      // start → end: −π, opposite to the clockwise half turn.
      expect(_angle(tester), moreOrLessEquals(-math.pi / 2));
    });

    testWidgets("us02/fr02: a turn runs over the theme's fast level on its "
        'standard curve', (tester) async {
      final theme = motionTheme(
        fast: const Duration(milliseconds: 200),
        standard: const StratumNamedCurve('easeIn'),
      );
      await tester.pumpWidget(
        _turning(StratumCaretDirection.down, theme: theme),
      );
      await tester.pumpWidget(_turning(StratumCaretDirection.up, theme: theme));

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _angle(tester),
        moreOrLessEquals(math.pi * Curves.easeIn.transform(0.5)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_angle(tester), math.pi);
    });

    for (final (name, viaMediaQuery) in [
      ('us02/fr03/e01, nfr-u03: the app disables animations', true),
      (
        'us02/fr03/e02, us02/s5, nfr-u03: the platform reduce-motion flag is '
            'on',
        false,
      ),
    ]) {
      testWidgets('$name: the new direction shows in the next frame', (
        tester,
      ) async {
        if (!viaMediaQuery) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        Widget host(StratumCaretDirection direction) => MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(disableAnimations: viaMediaQuery),
          child: _turning(direction),
        );
        await tester.pumpWidget(host(StratumCaretDirection.down));

        await tester.pumpWidget(host(StratumCaretDirection.up));

        expect(_angle(tester), math.pi);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    for (final (name, viaMediaQuery) in [
      ('us02/fr03/e01, nfr-u03: the app disables animations mid-turn', true),
      (
        'us02/fr03/e02, nfr-u03: the platform reduce-motion flag turns on '
            'mid-turn',
        false,
      ),
    ]) {
      testWidgets('$name: the live turn snaps to the end angle', (
        tester,
      ) async {
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        Widget host(StratumCaretDirection direction, {required bool reduce}) {
          if (!viaMediaQuery) {
            tester.platformDispatcher.accessibilityFeaturesTestValue = reduce
                ? const FakeAccessibilityFeatures(reduceMotion: true)
                : const FakeAccessibilityFeatures();
          }
          return MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(disableAnimations: viaMediaQuery && reduce),
            child: _turning(direction),
          );
        }

        await tester.pumpWidget(
          host(StratumCaretDirection.down, reduce: false),
        );
        await tester.pumpWidget(host(StratumCaretDirection.up, reduce: false));
        await tester.pump(const Duration(milliseconds: 62));
        expect(_angle(tester), allOf(greaterThan(0), lessThan(math.pi)));

        await tester.pumpWidget(host(StratumCaretDirection.up, reduce: true));
        await tester.pump();

        expect(_angle(tester), math.pi);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('us02/fr04/e01, us02/s6: end moves to the left at once when '
        'the app switches to right to left', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.end));

      await tester.pumpWidget(
        _turning(StratumCaretDirection.end, textDirection: TextDirection.rtl),
      );

      expect(_angle(tester) % (2 * math.pi), moreOrLessEquals(math.pi / 2));
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final direction in [
      StratumCaretDirection.up,
      StratumCaretDirection.down,
    ]) {
      testWidgets('us02/fr04/e02: ${direction.name} stays as it is when the '
          'text direction flips', (tester) async {
        await tester.pumpWidget(_turning(direction));
        final before = _angle(tester);

        await tester.pumpWidget(
          _turning(direction, textDirection: TextDirection.rtl),
        );

        expect(_angle(tester), before);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('us02/fr02: a new direction mid-turn turns on from the live '
        'angle with no jump', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pumpWidget(_turning(StratumCaretDirection.up));
      await tester.pump(const Duration(milliseconds: 62));
      final live = _angle(tester);

      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      expect(_angle(tester), moreOrLessEquals(live));

      await tester.pump(const Duration(milliseconds: 62));
      expect(_angle(tester), allOf(greaterThan(0), lessThan(live)));
      await tester.pumpAndSettle();
      expect(_angle(tester), 0);
    });

    testWidgets('us02/fr02: a rebuild that keeps the direction starts no '
        'turn', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.up));

      await tester.pumpWidget(
        _turning(StratumCaretDirection.up, customColor: _custom),
      );

      expect(tester.hasRunningAnimations, isFalse);
      expect(_angle(tester), math.pi);
      expect(_painter(tester).color, _custom);
    });

    testWidgets('us02/fr02, us02/fr04: a direction and a text direction that '
        'change in one frame turn once, the short way to the new side', (
      tester,
    ) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));

      await tester.pumpWidget(
        _turning(StratumCaretDirection.start, textDirection: TextDirection.rtl),
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();

      // Right to left, start points right: a quarter counterclockwise
      // from down.
      expect(_angle(tester), moreOrLessEquals(-math.pi / 2));
    });

    testWidgets('us02/fr02: a fast level with no duration shows the new '
        'direction at once (themes s03 inv. 15)', (tester) async {
      final theme = _fastLevel(const AnimationStyle());
      await tester.pumpWidget(
        _turning(StratumCaretDirection.down, theme: theme),
      );

      await tester.pumpWidget(_turning(StratumCaretDirection.up, theme: theme));

      expect(_angle(tester), math.pi);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('us02/fr02: a fast level with no curve turns on '
        'easeInOutSine (themes s03 inv. 15)', (tester) async {
      final theme = _fastLevel(
        const AnimationStyle(duration: Duration(milliseconds: 200)),
      );
      await tester.pumpWidget(
        _turning(StratumCaretDirection.down, theme: theme),
      );
      await tester.pumpWidget(_turning(StratumCaretDirection.up, theme: theme));

      await tester.pump(const Duration(milliseconds: 100));

      expect(
        _angle(tester),
        moreOrLessEquals(math.pi * Curves.easeInOutSine.transform(0.5)),
      );
    });
  });
}
