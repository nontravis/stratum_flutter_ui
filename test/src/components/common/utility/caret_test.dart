import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/utility/caret.dart'
    show CaretPainter;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// The one widget that paints a caret glyph; foreground, so a
/// `customStyle` background never hides it.
final Finder _glyph = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.foregroundPainter is CaretPainter,
);

CaretPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_glyph).foregroundPainter! as CaretPainter;

/// The style, color, and angle the glyph paints with.
List<Object> _look(WidgetTester tester) {
  final painter = _painter(tester);
  return [painter.style, painter.color, painter.angle];
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
      micro: motion.micro,
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
    testWidgets(
      'co01_03/us01/fr01/e01, co01_03/us01/s1: with no values set it draws a '
      '16 px caret pointing down as a 1.5 px round chevron',
      (tester) async {
        await tester.pumpWidget(themedHost(const StratumCaret()));

        expect(tester.getSize(find.byType(StratumCaret)), const Size(16, 16));
        expect(_painter(tester).angle, 0);
        expect(_painter(tester).style, StratumCaretGlyph.regular);
        final (:path, :paint) = _drawn();
        expect(paint.style, PaintingStyle.stroke);
        expect(paint.strokeWidth, 1.5);
        expect(paint.strokeCap, StrokeCap.round);
        expect(paint.strokeJoin, StrokeJoin.round);
        expect(
          paint.color,
          isSameColorAs(fakeTheme.color.icon.defaults.primary),
        );
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
      },
    );

    testWidgets(
      'co01_03/us01/fr01/e02, co01_03/us01/s2: light draws the round chevron '
      '1.0 px wide, 11 x 6 in the 16 px box',
      (tester) async {
        await tester.pumpWidget(
          themedHost(const StratumCaret(style: StratumCaretGlyph.light)),
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
      },
    );

    testWidgets('co01_03/us01/fr01/e03, co01_03/us01/s2: fill draws a solid triangle 11 x 6 '
        'with no line', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumCaret(style: StratumCaretGlyph.fill)),
      );

      final (:path, :paint) = _drawn();
      expect(paint.style, PaintingStyle.fill);
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-5.5, -3, 5.5, 3)),
      );
    });

    for (final style in StratumCaretGlyph.values) {
      testWidgets(
        'co01_03/us01/fr01/e04: up points the ${style.name} glyph up',
        (tester) async {
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
        },
      );
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
      testWidgets('co01_03/us01/fr02: ${size.name} gives a $side px box', (
        tester,
      ) async {
        await tester.pumpWidget(themedHost(StratumCaret(size: size)));

        expect(tester.getSize(find.byType(StratumCaret)), Size.square(side));
        final (:path, paint: _) = _drawn();
        final unit = side / 16;
        expect(
          path.getBounds(),
          rectMoreOrLessEquals(
            Rect.fromLTRB(-5 * unit, -2.5 * unit, 5 * unit, 2.5 * unit),
          ),
        );
      });
    }

    testWidgets(
      "co01_03/us01/fr02/e01: no size takes the theme's default widget "
      'size',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const StratumCaret(),
            theme: fakeTheme.copyWith(defaultWidgetSize: WidgetSize.large),
          ),
        );

        expect(tester.getSize(find.byType(StratumCaret)), const Size(20, 20));
      },
    );

    testWidgets(
      'co01_03/us01/fr02/e02, co01_03/us01/s4: customSize wins over size',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const StratumCaret(size: WidgetSize.small, customSize: 40),
          ),
        );

        expect(tester.getSize(find.byType(StratumCaret)), const Size(40, 40));
        final (:path, paint: _) = _drawn();
        expect(
          path.getBounds(),
          rectMoreOrLessEquals(const Rect.fromLTRB(-12.5, -6.25, 12.5, 6.25)),
        );
      },
    );

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

    testWidgets(
      'co01_03/us01/s3, R1: a regular caret at the large size measures '
      '20 px and keeps its 1.5 px line',
      (tester) async {
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
      },
    );

    testWidgets(
      'co01_03/us01/fr02/e03, co01_03/us01/s5: in a 100 x 100 space the glyph '
      'keeps its 16 px and sits centered',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const SizedBox(width: 100, height: 100, child: StratumCaret()),
          ),
        );

        expect(tester.getSize(_glyph), const Size(16, 16));
        expect(_glyph, paints..translate(x: 8, y: 8));
        final (:path, paint: _) = _drawn();
        expect(
          path.getBounds(),
          rectMoreOrLessEquals(const Rect.fromLTRB(-5, -2.5, 5, 2.5)),
        );
      },
    );

    testWidgets('a 5 x 5 parent tighter than the 16 px box scales the glyph '
        'to fit it', (tester) async {
      await tester.pumpWidget(
        themedHost(const SizedBox(width: 5, height: 5, child: StratumCaret())),
      );

      expect(tester.getSize(find.byType(StratumCaret)), const Size(5, 5));
      expect(_glyph, paints..translate(x: 2.5, y: 2.5));
      final (:path, paint: _) = _drawn();
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(
          const Rect.fromLTRB(
            -5 / 16 * 5,
            -2.5 / 16 * 5,
            5 / 16 * 5,
            2.5 / 16 * 5,
          ),
        ),
      );
    });

    testWidgets('an IntrinsicWidth ancestor lays the caret out at 16 px '
        'with no exception', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const IntrinsicWidth(
            child: RowLayout(
              mainAxisSize: MainAxisSize.min,
              children: [Text('x'), StratumCaret()],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(StratumCaret)), const Size(16, 16));
    });

    testWidgets(
      'co01_03/us01/fr02/e04: a fill caret at the large size scales its '
      'triangle to the 20 px box',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const StratumCaret(
              style: StratumCaretGlyph.fill,
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
      },
    );

    testWidgets('co01_03/us01/fr02: in a row the caret keeps its square box', (
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
    testWidgets(
      'co01_03/us01/fr03/e01: no color draws icon.default.primary, 80% '
      'black on the light default theme',
      (tester) async {
        await tester.pumpWidget(_defaultThemeHost(const StratumCaret()));

        expect(
          _painter(tester).color,
          isSameColorAs(defaultThemeSet.light.color.icon.defaults.primary),
        );
        expect(
          _painter(tester).color,
          isSameColorAs(StratumTransparentTokens.builtIn.black.p80),
        );
      },
    );

    testWidgets('co01_03/us01/fr03/e01: no color draws 100% white on the dark '
        'default theme', (tester) async {
      await tester.pumpWidget(
        _defaultThemeHost(const StratumCaret(), mode: ThemeMode.dark),
      );

      expect(
        _painter(tester).color,
        isSameColorAs(StratumTransparentTokens.builtIn.white.p100),
      );
    });

    testWidgets(
      "co01_03/us01/fr03/e01: the caret's own themeMode picks the dark "
      'token under a light app',
      (tester) async {
        await tester.pumpWidget(
          _defaultThemeHost(const StratumCaret(themeMode: ThemeMode.dark)),
        );

        expect(
          _painter(tester).color,
          isSameColorAs(defaultThemeSet.dark!.color.icon.defaults.primary),
        );
      },
    );

    testWidgets(
      'co01_03/us01/fr03/e02, co01_03/us01/s6: customColor wins over color',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const StratumCaret(color: ColorEnum.blue, customColor: _custom),
          ),
        );

        expect(_painter(tester).color, _custom);
      },
    );

    testWidgets(
      "co01_03/us01/fr03/e03: blue draws the theme's icon.color.blue",
      (tester) async {
        await tester.pumpWidget(
          themedHost(const StratumCaret(color: ColorEnum.blue)),
        );

        expect(_painter(tester).color, fakeTheme.color.icon.color.blue);
      },
    );

    testWidgets('co01_03/us01/fr03/e04, co01_03/us01/s9: red, which icon.color lacks, draws '
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

    testWidgets('co01_03/us01/fr04/e01, co01_03/us01/s7, D11: disabled adds no look of its '
        'own; the dimming belongs to StratumDisabled', (tester) async {
      final (look, box) = await baseline(tester);

      await tester.pumpWidget(themedHost(const StratumCaret(disabled: true)));

      expect(_look(tester), look);
      expect(_box(tester), box);
    });

    testWidgets('R1, R10(1), co01_03/us01/fr04: the caret takes no state, '
        'feedback tone, loading value, or window size', (tester) async {
      // The constructor takes none of the four; the base fields keep
      // their defaults.
      const caret = StratumCaret();

      expect(caret.state, FullWidgetState.normal);
      expect(caret.feedbackState, isNull);
      expect(caret.loading, isFalse);
      expect(caret.windowSize, isNull);
    });

    testWidgets('R1, fo08/us01/fr01: size changes the caret box', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(const StratumCaret()));
      final medium = tester.getSize(find.byType(StratumCaret));

      await tester.pumpWidget(
        themedHost(const StratumCaret(size: WidgetSize.huge)),
      );

      expect(medium, const Size(16, 16));
      expect(tester.getSize(find.byType(StratumCaret)), const Size(32, 32));
    });

    testWidgets('R1, fo08/us01/fr01: color changes the glyph color', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(const StratumCaret()));
      final plain = _painter(tester).color;

      await tester.pumpWidget(
        themedHost(const StratumCaret(color: ColorEnum.blue)),
      );

      expect(_painter(tester).color, isNot(isSameColorAs(plain)));
    });

    testWidgets('R1, fo08/us01/fr01: themeMode changes the glyph color', (
      tester,
    ) async {
      Future<Color> paintedIn(ThemeMode mode) async {
        await tester.pumpWidget(
          _defaultThemeHost(StratumCaret(themeMode: mode)),
        );
        return _painter(tester).color;
      }

      expect(
        await paintedIn(ThemeMode.dark),
        isNot(isSameColorAs(await paintedIn(ThemeMode.light))),
      );
    });

    testWidgets('R1, fo08/us01/fr01: disabled dims the caret through the '
        "base's wrapper", (tester) async {
      double opacity() => tester
          .widget<Opacity>(
            find.ancestor(of: _glyph, matching: find.byType(Opacity)).first,
          )
          .opacity;

      await tester.pumpWidget(themedHost(const StratumCaret()));
      expect(opacity(), 1);

      await tester.pumpWidget(themedHost(const StratumCaret(disabled: true)));
      expect(opacity(), fakeTheme.opacity.disabled);
    });

    testWidgets('co01_03/us01/fr04/e05, co01_03/us01/s8: customStyle fills the box and the '
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

    testWidgets('inv. 14: customStyle padding never shrinks the glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const StratumCaret(
            customStyle: WidgetStyle(padding: EdgeInsets.all(2)),
          ),
        ),
      );

      expect(tester.getSize(_glyph), const Size(16, 16));
      final (:path, paint: _) = _drawn();
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-5, -2.5, 5, 2.5)),
      );
    });

    testWidgets('a customStyle margin leaves the glyph centered in the box '
        'inside the margin at full size', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const StratumCaret(
            customStyle: WidgetStyle(margin: EdgeInsets.all(4)),
          ),
        ),
      );

      expect(tester.getSize(find.byType(StratumCaret)), const Size(24, 24));
      expect(tester.getSize(_glyph), const Size(24, 24));
      expect(_glyph, paints..translate(x: 12, y: 12));
      final (:path, paint: _) = _drawn();
      expect(
        path.getBounds(),
        rectMoreOrLessEquals(const Rect.fromLTRB(-5, -2.5, 5, 2.5)),
      );
    });
  });

  group('StratumCaret text direction', () {
    // Angles run clockwise from pointing down: a quarter turn points
    // left, three quarters point right.
    const quarter = math.pi / 2;
    for (final (name, textDirection, direction, angle) in [
      (
        'co01_03/us02/fr01/e01: left to right, start points left',
        TextDirection.ltr,
        StratumCaretDirection.start,
        quarter,
      ),
      (
        'co01_03/us02/fr01/e01: left to right, end points right',
        TextDirection.ltr,
        StratumCaretDirection.end,
        3 * quarter,
      ),
      (
        'co01_03/us02/fr01/e02, nfr-l02: right to left, start points right',
        TextDirection.rtl,
        StratumCaretDirection.start,
        3 * quarter,
      ),
      (
        'co01_03/us02/fr01/e02, co01_03/us02/s4, nfr-l02: right to left, end points left',
        TextDirection.rtl,
        StratumCaretDirection.end,
        quarter,
      ),
      (
        'co01_03/us02/fr01/e03, nfr-l02: right to left, up points up',
        TextDirection.rtl,
        StratumCaretDirection.up,
        math.pi,
      ),
      (
        'co01_03/us02/fr01/e03, nfr-l02: right to left, down points down',
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

  testWidgets(
    'co01_03/us02/fr05/e01, co01_03/us02/s7: the caret adds nothing to its '
    "owner's semantics",
    (tester) async {
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
    },
  );

  testWidgets(
    'co01_03/us02/fr05/e02, us07/fr03/e01, R11: a disabled caret adds no '
    'disabled node',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          Semantics(
            container: true,
            label: 'Details',
            child: const StratumCaret(disabled: true),
          ),
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('Details'));
      expect(node, matchesSemantics(label: 'Details', hasEnabledState: false));
      expect(node.childrenCount, 0);
      semantics.dispose();
    },
  );

  group('StratumCaret turn', () {
    testWidgets('co01_03/us02/fr02/e02, co01_03/us02/s1: the first half turn, down to up, '
        'turns clockwise over the 125 ms fast level', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pumpWidget(_turning(StratumCaretDirection.up));
      expect(_angle(tester), 0);

      await tester.pump(const Duration(milliseconds: 62));
      expect(_angle(tester), allOf(greaterThan(0), lessThan(math.pi)));

      await tester.pump(const Duration(milliseconds: 62));
      expect(_angle(tester), lessThan(math.pi));

      // Exactly the 125 ms fast level: t == 1.0 evaluates to the end
      // value exactly.
      await tester.pump(const Duration(milliseconds: 1));
      expect(_angle(tester), math.pi);

      // 1 ms past the 125 ms fast level: AnimationController's isDone is
      // strictly past its duration, so the ticker unregisters one tick
      // after the value already read its end.
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets(
      'co01_03/us02/fr02/e03, co01_03/us02/s2: the next half turn, up to down, '
      'turns back counterclockwise',
      (tester) async {
        await tester.pumpWidget(_turning(StratumCaretDirection.down));
        await tester.pumpWidget(_turning(StratumCaretDirection.up));
        await tester.pumpAndSettle();
        expect(_angle(tester), math.pi);

        await tester.pumpWidget(_turning(StratumCaretDirection.down));
        await tester.pump(const Duration(milliseconds: 62));
        expect(_angle(tester), allOf(greaterThan(0), lessThan(math.pi)));
        await tester.pumpAndSettle();
        expect(_angle(tester), 0);
      },
    );

    testWidgets(
      'co01_03/us02/fr02/e03: a third half turn goes clockwise again, '
      'opposite to the second',
      (tester) async {
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
      },
    );

    testWidgets('co01_03/us02/fr02/e01, co01_03/us02/s3: end to down in a left-to-right app '
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

    testWidgets(
      'co01_03/us02/fr02/e04: down to start turns a quarter clockwise, '
      'then start to end, the first half turn, turns clockwise',
      (tester) async {
        await tester.pumpWidget(_turning(StratumCaretDirection.down));
        await tester.pumpWidget(_turning(StratumCaretDirection.start));
        await tester.pumpAndSettle();
        expect(_angle(tester), moreOrLessEquals(math.pi / 2));

        await tester.pumpWidget(_turning(StratumCaretDirection.end));
        await tester.pumpAndSettle();
        expect(_angle(tester), moreOrLessEquals(3 * math.pi / 2));
      },
    );

    testWidgets(
      'co01_03/us02/fr02/e04: a quarter turn between two half turns leaves '
      'the next half turn opposite to the last one',
      (tester) async {
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
      },
    );

    testWidgets(
      "co01_03/us02/fr02: a turn runs over the theme's fast level on its "
      'standard curve',
      (tester) async {
        final theme = motionTheme(
          fast: const Duration(milliseconds: 200),
          standard: const StratumNamedCurve('easeIn'),
        );
        await tester.pumpWidget(
          _turning(StratumCaretDirection.down, theme: theme),
        );
        await tester.pumpWidget(
          _turning(StratumCaretDirection.up, theme: theme),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(
          _angle(tester),
          moreOrLessEquals(math.pi * Curves.easeIn.transform(0.5)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(_angle(tester), math.pi);
      },
    );

    for (final (name, viaMediaQuery) in [
      ('co01_03/us02/fr03/e01, nfr-u03: the app disables animations', true),
      (
        'co01_03/us02/fr03/e02, co01_03/us02/s5, nfr-u03: the platform reduce-motion flag is '
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
      (
        'co01_03/us02/fr03/e01, nfr-u03: the app disables animations mid-turn',
        true,
      ),
      (
        'co01_03/us02/fr03/e02, nfr-u03: the platform reduce-motion flag turns on '
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

    testWidgets(
      'co01_03/us02/fr03: a direction change turns instead of jumping '
      'when reduced motion turns off in the same frame',
      (tester) async {
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        await tester.pumpWidget(_turning(StratumCaretDirection.down));

        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.pumpWidget(_turning(StratumCaretDirection.up));

        expect(_angle(tester), 0);
        expect(tester.hasRunningAnimations, isTrue);

        await tester.pumpAndSettle();
        expect(_angle(tester), math.pi);
      },
    );

    testWidgets('co01_03/us02/fr04/e01, co01_03/us02/s6: end moves to the left at once when '
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
      testWidgets(
        'co01_03/us02/fr04/e02: ${direction.name} stays as it is when the '
        'text direction flips',
        (tester) async {
          await tester.pumpWidget(_turning(direction));
          final before = _angle(tester);

          await tester.pumpWidget(
            _turning(direction, textDirection: TextDirection.rtl),
          );

          expect(_angle(tester), before);
          expect(tester.hasRunningAnimations, isFalse);
        },
      );
    }

    testWidgets(
      'co01_03/us02/fr02: a new direction mid-turn turns on from the live '
      'angle with no jump',
      (tester) async {
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
      },
    );

    testWidgets('co01_03/us02/fr02: three overlapping direction changes in one '
        'turn alternate the half-turn way (inv. 8)', (tester) async {
      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pumpWidget(_turning(StratumCaretDirection.up));
      await tester.pump(const Duration(milliseconds: 62));
      final afterFirst = _angle(tester);
      // down → up, the first half turn, clockwise.
      expect(afterFirst, allOf(greaterThan(0), lessThan(math.pi)));

      await tester.pumpWidget(_turning(StratumCaretDirection.down));
      await tester.pump(const Duration(milliseconds: 20));
      final afterSecond = _angle(tester);
      // up → down, interrupted before it settles, turns back
      // counterclockwise from the live angle.
      expect(afterSecond, allOf(greaterThan(0), lessThan(afterFirst)));

      await tester.pumpWidget(_turning(StratumCaretDirection.up));
      await tester.pump(const Duration(milliseconds: 20));
      // down → up again, interrupted before it settles too, turns
      // clockwise again: opposite to the second half turn, same as the
      // first.
      expect(_angle(tester), greaterThan(afterSecond));

      await tester.pumpAndSettle();
      expect(_angle(tester), math.pi);
    });

    testWidgets(
      'co01_03/us02/fr02: a rebuild that keeps the direction starts no '
      'turn',
      (tester) async {
        await tester.pumpWidget(_turning(StratumCaretDirection.up));

        await tester.pumpWidget(
          _turning(StratumCaretDirection.up, customColor: _custom),
        );

        expect(tester.hasRunningAnimations, isFalse);
        expect(_angle(tester), math.pi);
        expect(_painter(tester).color, _custom);
      },
    );

    testWidgets(
      'co01_03/us02/fr02, co01_03/us02/fr04: a direction and a text direction that '
      'change in one frame turn once, the short way to the new side',
      (tester) async {
        await tester.pumpWidget(_turning(StratumCaretDirection.down));

        await tester.pumpWidget(
          _turning(
            StratumCaretDirection.start,
            textDirection: TextDirection.rtl,
          ),
        );
        expect(tester.hasRunningAnimations, isTrue);
        await tester.pumpAndSettle();

        // Right to left, start points right: a quarter counterclockwise
        // from down.
        expect(_angle(tester), moreOrLessEquals(-math.pi / 2));
      },
    );

    testWidgets(
      'co01_03/us02/fr02: a fast level with no duration shows the new '
      'direction at once (themes s03 inv. 15)',
      (tester) async {
        final theme = _fastLevel(const AnimationStyle());
        await tester.pumpWidget(
          _turning(StratumCaretDirection.down, theme: theme),
        );

        await tester.pumpWidget(
          _turning(StratumCaretDirection.up, theme: theme),
        );

        expect(_angle(tester), math.pi);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('co01_03/us02/fr02: a fast level with no curve turns on '
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
