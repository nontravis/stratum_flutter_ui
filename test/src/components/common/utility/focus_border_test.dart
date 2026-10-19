import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/utility/focus_border.dart'
    show focusBorderOutsideReach;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// NFR-U02, NFR-U05, and NFR-U09 n/a: a decorator whose state the caller
// supplies; each host's gate proves its keys, target, and gesture
// (focus-style-cleanup design, ## Accessibility and UX).
// NFR-U04 n/a: the ring draws no text; it follows its child's size.

const _radius = BorderRadius.all(Radius.circular(10));

/// The owner's red-border example: 5 px of red.
const _red = Color(0xFFFF0000);
const _redStyle = StratumFocusBorderStyle(
  color: WidgetStatePropertyAll(_red),
  width: WidgetStatePropertyAll(5),
);
const _inside = StratumFocusBorderStyle(
  placement: StratumFocusBorderPlacement.inside,
);

class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}

Widget _ring({
  FullWidgetState state = FullWidgetState.normal,
  bool insideEdge = false,
  BorderRadiusGeometry? borderRadius = _radius,
  StratumFocusBorderStyle? customStyle,
  Map<Type, Object> parts = const {},
  Map<Type, WidgetStyle> styles = const {},
  StratumThemeData? theme,
  Widget child = const _Probe(),
}) {
  return themedHost(
    StratumComponentDefaults(
      styles: styles,
      parts: parts,
      child: StratumFocusBorder(
        state: state,
        insideEdge: insideEdge,
        borderRadius: borderRadius,
        customStyle: customStyle,
        child: child,
      ),
    ),
    theme: theme,
  );
}

Finder get _ringBox => find
    .descendant(
      of: find.byType(StratumFocusBorder),
      matching: find.byType(DecoratedBox),
    )
    .first;

/// Every ring the one [StratumFocusBorder] paints, in paint order: the
/// second ring, when set, then the first ring, last.
List<({RRect outer, RRect inner, Color color})> _rings(WidgetTester tester) {
  final rings = <({RRect outer, RRect inner, Color color})>[];
  expect(
    tester.renderObject(_ringBox),
    paints..everything((method, arguments) {
      if (method == #drawDRRect) {
        rings.add((
          outer: arguments[0] as RRect,
          inner: arguments[1] as RRect,
          color: (arguments[2] as Paint).color,
        ));
      }
      return true;
    }),
  );
  return rings;
}

/// The glow strokes the ring paints under its child.
List<Paint> _glow(WidgetTester tester) {
  final strokes = <Paint>[];
  expect(
    tester.renderObject(_ringBox),
    paints..everything((method, arguments) {
      if (method == #drawRRect && (arguments[1] as Paint).maskFilter != null) {
        strokes.add(arguments[1] as Paint);
      }
      return true;
    }),
  );
  return strokes;
}

/// The ring the one [StratumFocusBorder] paints, in its child's frame.
({RRect outer, RRect inner, Color color}) _painted(WidgetTester tester) {
  late RRect outer;
  late RRect inner;
  late Color color;
  expect(
    tester.renderObject(_ringBox),
    paints..something((method, arguments) {
      if (method != #drawDRRect) return false;
      outer = arguments[0] as RRect;
      inner = arguments[1] as RRect;
      color = (arguments[2] as Paint).color;
      return true;
    }),
  );
  return (outer: outer, inner: inner, color: color);
}

/// Matches an [RRect] with the edges [l], [t], [r], and [b] and [radius]
/// at every corner, to 1e-9.
Matcher _rrect(double l, double t, double r, double b, double radius) {
  return predicate<RRect>(
    (rrect) => [
      rrect.left - l,
      rrect.top - t,
      rrect.right - r,
      rrect.bottom - b,
      rrect.tlRadiusX - radius,
      rrect.tlRadiusY - radius,
      rrect.trRadiusX - radius,
      rrect.brRadiusX - radius,
      rrect.blRadiusX - radius,
    ].every((delta) => delta.abs() < 1e-9),
    'RRect.fromLTRBR($l, $t, $r, $b, $radius)',
  );
}

/// Whether the one ring paints nothing a user sees.
bool _hidden(WidgetTester tester) => _painted(tester).color.a == 0;

StratumColorTokens get _colors => fakeTheme.color;

/// Pumps [host] for every placement and [FullWidgetState], and expects
/// [_redStyle] on the shown looks only: the focused look of either
/// placement and the inside placement's hovered look.
Future<void> _expectShownLooksOnly(
  WidgetTester tester,
  Widget Function(StratumFocusBorderPlacement placement, FullWidgetState state)
  host,
) async {
  for (final placement in StratumFocusBorderPlacement.values) {
    for (final state in FullWidgetState.values) {
      await tester.pumpWidget(host(placement, state));
      await tester.pumpAndSettle();
      final why = '$placement $state';
      final shown =
          state == FullWidgetState.focused ||
          (state == FullWidgetState.hovered &&
              placement == StratumFocusBorderPlacement.inside);
      final ring = _painted(tester);
      if (!shown) {
        expect(ring.color.a, 0, reason: why);
        continue;
      }
      expect(ring.color, isSameColorAs(_red), reason: why);
      if (placement == StratumFocusBorderPlacement.outside) {
        // The theme's 2 px gap still applies: the style restyles color
        // and width only.
        expect(ring.inner, _rrect(-2, -2, 42, 22, 12), reason: why);
        expect(ring.outer, _rrect(-7, -7, 47, 27, 17), reason: why);
      } else {
        expect(ring.outer, _rrect(0, 0, 40, 20, 10), reason: why);
        expect(ring.inner, _rrect(5, 5, 35, 15, 5), reason: why);
      }
    }
  }
}

void main() {
  group('StratumFocusBorder look', () {
    testWidgets(
      'fo06/us04/fr03: an outside ring shows only when focused, 3 px in '
      'border.subtle.blue after a 2 px gap at the child radius plus the gap',
      (tester) async {
        for (final state in [FullWidgetState.normal, FullWidgetState.hovered]) {
          await tester.pumpWidget(_ring(state: state));
          expect(_hidden(tester), isTrue, reason: '$state');
        }

        await tester.pumpWidget(_ring(state: FullWidgetState.focused));
        await tester.pumpAndSettle();

        final ring = _painted(tester);
        expect(ring.color, isSameColorAs(_colors.border.subtle.blue));
        expect(ring.inner, _rrect(-2, -2, 42, 22, 12));
        expect(ring.outer, _rrect(-5, -5, 45, 25, 15));
      },
    );

    testWidgets(
      'fo06/us04/fr03/e07: an outside ring with insideEdge paints the outside '
      'color and width on the inner edge at the child radius, gap unused',
      (tester) async {
        for (final gap in [null, 6.0]) {
          await tester.pumpWidget(
            _ring(
              state: FullWidgetState.focused,
              insideEdge: true,
              customStyle: gap == null
                  ? null
                  : StratumFocusBorderStyle(gap: WidgetStatePropertyAll(gap)),
            ),
          );
          await tester.pumpAndSettle();

          final ring = _painted(tester);
          expect(
            ring.color,
            isSameColorAs(_colors.border.subtle.blue),
            reason: 'gap $gap',
          );
          expect(ring.outer, _rrect(0, 0, 40, 20, 10), reason: 'gap $gap');
          expect(ring.inner, _rrect(3, 3, 37, 17, 7), reason: 'gap $gap');
        }
        for (final state in [FullWidgetState.normal, FullWidgetState.hovered]) {
          await tester.pumpWidget(_ring(state: state, insideEdge: true));
          await tester.pumpAndSettle();
          expect(_hidden(tester), isTrue, reason: '$state');
        }
      },
    );

    testWidgets(
      'fo06/us04/fr03: an inside ring paints border.default.normal on the inner '
      'edge, 3 px when hovered and 2 px when focused, nothing when normal',
      (tester) async {
        await tester.pumpWidget(_ring(customStyle: _inside));
        expect(_hidden(tester), isTrue);

        await tester.pumpWidget(
          _ring(customStyle: _inside, state: FullWidgetState.hovered),
        );
        await tester.pumpAndSettle();
        var ring = _painted(tester);
        expect(ring.color, isSameColorAs(_colors.border.defaults.normal));
        expect(ring.outer, _rrect(0, 0, 40, 20, 10));
        expect(ring.inner, _rrect(3, 3, 37, 17, 7));

        await tester.pumpWidget(
          _ring(customStyle: _inside, state: FullWidgetState.focused),
        );
        await tester.pumpAndSettle();
        ring = _painted(tester);
        expect(ring.color, isSameColorAs(_colors.border.defaults.normal));
        expect(ring.outer, _rrect(0, 0, 40, 20, 10));
        expect(ring.inner, _rrect(2, 2, 38, 18, 8));
      },
    );

    testWidgets(
      'fo06/us04/fr03/e11: every other FullWidgetState value shows the normal '
      'look, no ring, in either placement',
      (tester) async {
        const shown = {
          FullWidgetState.normal,
          FullWidgetState.hovered,
          FullWidgetState.focused,
        };
        for (final placement in StratumFocusBorderPlacement.values) {
          for (final state in FullWidgetState.values) {
            if (shown.contains(state)) continue;
            await tester.pumpWidget(
              _ring(
                state: state,
                customStyle: StratumFocusBorderStyle(placement: placement),
              ),
            );
            await tester.pumpAndSettle();
            expect(_hidden(tester), isTrue, reason: '$placement $state');
          }
        }
      },
    );

    testWidgets(
      'fo06/us04/fr03: a ring around a child with no radius takes the gap as '
      'its radius',
      (tester) async {
        await tester.pumpWidget(
          _ring(state: FullWidgetState.focused, borderRadius: null),
        );
        await tester.pumpAndSettle();

        final ring = _painted(tester);
        expect(ring.inner, _rrect(-2, -2, 42, 22, 2));
        expect(ring.outer, _rrect(-5, -5, 45, 25, 5));
      },
    );
  });

  group('StratumFocusBorder levels', () {
    testWidgets('fo06/us04/fr03/e08: one width for every shown state applies '
        'to both, and a width per state to each', (tester) async {
      for (final state in [FullWidgetState.hovered, FullWidgetState.focused]) {
        await tester.pumpWidget(
          _ring(
            state: state,
            customStyle: _inside.copyWith(
              width: const WidgetStatePropertyAll(4),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          _painted(tester).inner,
          _rrect(4, 4, 36, 16, 6),
          reason: '$state',
        );
      }

      final perState = _inside.copyWith(
        width: const WidgetStateProperty.fromMap({
          WidgetState.hovered: 6,
          WidgetState.focused: 1,
        }),
      );
      await tester.pumpWidget(
        _ring(state: FullWidgetState.hovered, customStyle: perState),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester).inner, _rrect(6, 6, 34, 14, 4));

      await tester.pumpWidget(
        _ring(state: FullWidgetState.focused, customStyle: perState),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester).inner, _rrect(1, 1, 39, 19, 9));
    });

    testWidgets('fo06/us04/fr03/e14: each field takes the highest level that '
        'sets it, and a field no level sets keeps level 0', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          parts: const {
            StratumFocusBorder: StratumFocusBorderStyle(
              color: WidgetStatePropertyAll(_red),
              width: WidgetStatePropertyAll(9),
            ),
          },
          customStyle: const StratumFocusBorderStyle(
            width: WidgetStatePropertyAll(5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ring = _painted(tester);
      expect(ring.color, isSameColorAs(_red));
      // Width 5 from the instance over the app-wide 9; the 2 px gap from
      // the theme's focus group.
      expect(ring.inner, _rrect(-2, -2, 42, 22, 12));
      expect(ring.outer, _rrect(-7, -7, 47, 27, 17));
    });

    testWidgets('fo06/us04/fr03/e14, PD4: a level that sets a field for one '
        'state leaves the other state to the level below', (tester) async {
      final hoveredOnly = _inside.copyWith(
        width: const WidgetStateProperty.fromMap({WidgetState.hovered: 6}),
      );
      await tester.pumpWidget(
        _ring(state: FullWidgetState.focused, customStyle: hoveredOnly),
      );
      await tester.pumpAndSettle();
      // The theme's inside focused width, 2 px.
      expect(_painted(tester).inner, _rrect(2, 2, 38, 18, 8));
    });

    testWidgets('fo06/us04/fr03/e13: a style at any level restyles only the '
        'shown looks', (tester) async {
      await _expectShownLooksOnly(
        tester,
        (placement, state) => _ring(
          state: state,
          customStyle: _redStyle.copyWith(placement: placement),
        ),
      );
      await _expectShownLooksOnly(
        tester,
        (placement, state) => _ring(
          state: state,
          parts: {StratumFocusBorder: _redStyle.copyWith(placement: placement)},
        ),
      );
    });

    testWidgets('fo06/us04/fr03/e07, e14: a restyled width keeps insideEdge on '
        'the inner edge with no gap', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          insideEdge: true,
          customStyle: _redStyle.copyWith(gap: const WidgetStatePropertyAll(6)),
        ),
      );
      await tester.pumpAndSettle();

      final ring = _painted(tester);
      expect(ring.color, isSameColorAs(_red));
      expect(ring.outer, _rrect(0, 0, 40, 20, 10));
      expect(ring.inner, _rrect(5, 5, 35, 15, 5));
    });

    testWidgets('fo03/us06/fr01/e03, Review Focus: a level-1 value of another '
        'type is an error that names both types', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          parts: const {StratumFocusBorder: WidgetStyle(opacity: 1)},
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('partsOf<StratumFocusBorderStyle>(StratumFocusBorder)'),
        ),
      );
    });

    testWidgets('fo03/us06/fr01/e05, (j): a WidgetStyle under '
        'StratumFocusBorder in the styles map fails a debug assert naming '
        'componentPartDefaults and StratumFocusBorderStyle', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          styles: const {
            StratumFocusBorder: WidgetStyle(
              border: Border.fromBorderSide(BorderSide(color: _red, width: 5)),
            ),
          },
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('componentPartDefaults'),
            contains('StratumFocusBorderStyle'),
          ),
        ),
      );
    });
  });

  group('StratumFocusBorder second ring and glow', () {
    testWidgets('fo06/us04/fr03/e17: a second ring color draws a ring '
        'touching the first, outward from an outside ring, at its width '
        'unless set', (tester) async {
      const green = Color(0xFF00FF00);
      for (final (width, outer) in [
        (null, _rrect(-8, -8, 48, 28, 18)),
        (4.0, _rrect(-9, -9, 49, 29, 19)),
      ]) {
        await tester.pumpWidget(
          _ring(
            state: FullWidgetState.focused,
            customStyle: StratumFocusBorderStyle(
              secondRing: WidgetStatePropertyAll((color: green, width: width)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final [second, first] = _rings(tester);
        expect(first.color, isSameColorAs(_colors.border.subtle.blue));
        expect(first.outer, _rrect(-5, -5, 45, 25, 15));
        expect(second.color, isSameColorAs(green));
        expect(second.inner, _rrect(-5, -5, 45, 25, 15), reason: '$width');
        expect(second.outer, outer, reason: '$width');
      }
    });

    testWidgets('fo06/us04/fr03/e17, R10(4): on an inside ring the second '
        'ring stacks inward, touching the first', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          customStyle: _inside.copyWith(
            secondRing: const WidgetStatePropertyAll((
              color: Color(0xFF00FF00),
              width: null,
            )),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final [second, first] = _rings(tester);
      expect(first.outer, _rrect(0, 0, 40, 20, 10));
      expect(first.inner, _rrect(2, 2, 38, 18, 8));
      expect(second.outer, _rrect(2, 2, 38, 18, 8));
      expect(second.inner, _rrect(4, 4, 36, 16, 6));
    });

    testWidgets('fo06/us04/fr03/e17, R10(4): on an insideEdge ring the second '
        'ring stacks inward and stays inside the box', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          insideEdge: true,
          customStyle: const StratumFocusBorderStyle(
            secondRing: WidgetStatePropertyAll((
              color: Color(0xFF00FF00),
              width: null,
            )),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final [second, first] = _rings(tester);
      expect(first.outer, _rrect(0, 0, 40, 20, 10));
      expect(first.inner, _rrect(3, 3, 37, 17, 7));
      expect(second.outer, _rrect(3, 3, 37, 17, 7));
      expect(second.inner, _rrect(6, 6, 34, 14, 4));
    });

    testWidgets('fo06/us04/fr03/e17, e13: a nothing look shows neither ring '
        'nor the glow', (tester) async {
      // debugDisableShadows, on by default in tests, drops the maskFilter
      // _glow reads (test/src/components/common/style/style_decoration_test.dart
      // s03/inv6 convention).
      debugDisableShadows = false;
      try {
        await tester.pumpWidget(
          _ring(
            customStyle: const StratumFocusBorderStyle(
              secondRing: WidgetStatePropertyAll((
                color: Color(0xFF00FF00),
                width: null,
              )),
              glow: WidgetStatePropertyAll([
                BoxShadow(color: Color(0xFF0000FF), blurRadius: 6),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_rings(tester).every((ring) => ring.color.a == 0), isTrue);
        expect(_glow(tester).every((paint) => paint.color.a == 0), isTrue);
      } finally {
        debugDisableShadows = true;
      }
    });

    testWidgets('fo06/us04/fr03/e18: a glow paints a soft halo along the '
        "shown ring and never changes the child's layout size", (tester) async {
      debugDisableShadows = false;
      try {
        await tester.pumpWidget(_ring(state: FullWidgetState.focused));
        final size = tester.getSize(find.byType(_Probe));

        await tester.pumpWidget(
          _ring(
            state: FullWidgetState.focused,
            customStyle: const StratumFocusBorderStyle(
              glow: WidgetStatePropertyAll([
                BoxShadow(color: Color(0xFF0000FF), blurRadius: 6),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final [halo] = _glow(tester);
        expect(halo.style, PaintingStyle.stroke);
        expect(halo.color, isSameColorAs(const Color(0xFF0000FF)));
        expect(tester.getSize(find.byType(_Probe)), size);
      } finally {
        debugDisableShadows = true;
      }
    });
  });

  group('StratumFocusBorder refuses a hidden ring', () {
    for (final (name, style, field) in [
      (
        'a width of 0',
        const StratumFocusBorderStyle(width: WidgetStatePropertyAll(0)),
        'StratumFocusBorderStyle.width',
      ),
      (
        'a fully transparent color',
        const StratumFocusBorderStyle(
          color: WidgetStatePropertyAll(Color(0x00FF0000)),
        ),
        'StratumFocusBorderStyle.color',
      ),
    ]) {
      testWidgets('fo06/us04/fr03/e19: $name at level 1 or 3 fails a debug '
          'assert naming the field', (tester) async {
        await tester.pumpWidget(
          _ring(state: FullWidgetState.focused, customStyle: style),
        );
        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (error) => error.message,
            'message',
            contains(field),
          ),
        );

        await tester.pumpWidget(
          _ring(
            state: FullWidgetState.focused,
            parts: {StratumFocusBorder: style},
          ),
        );
        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (error) => error.message,
            'message',
            contains(field),
          ),
        );
      });
    }

    testWidgets('fo06/us04/fr03/e19: an inside ring checks both shown states; '
        'an outside ring checks focused only', (tester) async {
      const hoveredZero = WidgetStateProperty<double?>.fromMap({
        WidgetState.hovered: 0,
        WidgetState.focused: 2,
      });
      await tester.pumpWidget(
        _ring(customStyle: _inside.copyWith(width: hoveredZero)),
      );
      expect(tester.takeException(), isA<FlutterError>());

      await tester.pumpWidget(
        _ring(customStyle: const StratumFocusBorderStyle(width: hoveredZero)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('fo06/us04/fr03, Review Focus: a per-state width for the '
        'focused look only builds in every state of an outside ring', (
      tester,
    ) async {
      const style = StratumFocusBorderStyle(
        width: WidgetStateProperty.fromMap({WidgetState.focused: 4}),
      );
      for (final state in [FullWidgetState.normal, FullWidgetState.hovered]) {
        await tester.pumpWidget(_ring(state: state, customStyle: style));
        expect(tester.takeException(), isNull, reason: '$state');
      }

      await tester.pumpWidget(
        _ring(state: FullWidgetState.focused, customStyle: style),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester).outer, _rrect(-6, -6, 46, 26, 16));
    });
  });

  group('StratumFocusBorder reach', () {
    testWidgets('fo06/us07/fr03/e01: an outside ring reaches its gap plus its '
        "width, plus a second ring's width when one is set", (tester) async {
      double? reach;
      Widget host({
        Map<Type, Object> parts = const {},
        StratumFocusBorderStyle? customStyle,
      }) => themedHost(
        StratumComponentDefaults(
          styles: const {},
          parts: parts,
          child: Builder(
            builder: (context) {
              reach = focusBorderOutsideReach(
                context,
                customStyle: customStyle,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(host());
      expect(reach, 5);

      await tester.pumpWidget(
        host(
          parts: const {
            StratumFocusBorder: StratumFocusBorderStyle(
              width: WidgetStatePropertyAll(4),
            ),
          },
        ),
      );
      expect(reach, 6);

      await tester.pumpWidget(
        host(
          customStyle: const StratumFocusBorderStyle(
            gap: WidgetStatePropertyAll(1),
            secondRing: WidgetStatePropertyAll((
              color: Color(0xFF00FF00),
              width: null,
            )),
          ),
        ),
      );
      expect(reach, 7);

      await tester.pumpWidget(
        host(
          customStyle: const StratumFocusBorderStyle(
            secondRing: WidgetStatePropertyAll((
              color: Color(0xFF00FF00),
              width: 2,
            )),
            glow: WidgetStatePropertyAll([BoxShadow(blurRadius: 40)]),
          ),
        ),
      );
      expect(reach, 7);
    });

    testWidgets('fo06/us04/fr03: an inside-placed host style reaches '
        'nothing past its child, not the outside floor', (tester) async {
      double? reach;
      await tester.pumpWidget(
        themedHost(
          Builder(
            builder: (context) {
              reach = focusBorderOutsideReach(
                context,
                customStyle: const StratumFocusBorderStyle(
                  placement: StratumFocusBorderPlacement.inside,
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      // An inside ring paints at `strokeAlignInside` and never protrudes
      // past the child, not the outside floor (gap 2 + width 3 = 5) that
      // ignoring the merged placement would read.
      expect(reach, 0);
    });

    testWidgets('fo06/us07/fr03/e03: no Stratum theme above, no reach', (
      tester,
    ) async {
      double? reach;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            reach = focusBorderOutsideReach(context);
            return const SizedBox();
          },
        ),
      );
      expect(reach, 0);
    });
  });

  group('StratumFocusBorder motion', () {
    testWidgets(
      "fo06/us04/fr03: the ring fades over the theme's fast level on its "
      'standard curve',
      (tester) async {
        final theme = motionTheme(
          fast: const Duration(milliseconds: 100),
          standard: const StratumNamedCurve('easeIn'),
        );
        await tester.pumpWidget(_ring(theme: theme));
        await tester.pumpWidget(
          _ring(state: FullWidgetState.focused, theme: theme),
        );

        // _Looks is private to focus_border.dart, so the test reads the
        // TweenAnimationBuilder by its raw, unparameterized type: duration
        // and curve come from ImplicitlyAnimatedWidget, not the type
        // argument.
        final builder = tester.widget<TweenAnimationBuilder>(
          find.byWidgetPredicate((widget) => widget is TweenAnimationBuilder),
        );
        expect(builder.duration, const Duration(milliseconds: 100));
        expect(builder.curve, Curves.easeIn);
        expect(_painted(tester).color.a, 0);

        await tester.pump(const Duration(milliseconds: 50));
        final half = _painted(tester).color.a;
        expect(half, greaterThan(0));
        expect(half, lessThan(1));

        await tester.pump(const Duration(milliseconds: 50));
        expect(
          _painted(tester).color,
          isSameColorAs(_colors.border.subtle.blue),
        );
      },
    );

    testWidgets(
      'fo06/us04/fr03: a state flip before the fade settles continues smoothly '
      'from the live value, not a restart',
      (tester) async {
        await tester.pumpWidget(_ring());
        await tester.pumpWidget(_ring(state: FullWidgetState.focused));
        await tester.pump(const Duration(milliseconds: 60));
        final rising = _painted(tester).color.a;
        expect(rising, greaterThan(0));
        expect(rising, lessThan(1));

        await tester.pumpWidget(_ring());
        expect(_painted(tester).color.a, moreOrLessEquals(rising));

        await tester.pump(const Duration(milliseconds: 20));
        expect(_painted(tester).color.a, lessThan(rising));
      },
    );
  });

  group('StratumFocusBorder layout', () {
    testWidgets(
      'fo06/us04/fr03/e09: no style, state, placement, or width changes the '
      "child's layout size, position, or State",
      (tester) async {
        await tester.pumpWidget(_ring());
        final probe = tester.state(find.byType(_Probe));
        final origin = tester.getTopLeft(find.byType(_Probe));

        for (final placement in StratumFocusBorderPlacement.values) {
          for (final state in [
            FullWidgetState.normal,
            FullWidgetState.hovered,
            FullWidgetState.focused,
          ]) {
            for (final insideEdge in [false, true]) {
              for (final width in [null, 8.0]) {
                await tester.pumpWidget(
                  _ring(
                    state: state,
                    insideEdge: insideEdge,
                    customStyle: StratumFocusBorderStyle(
                      placement: placement,
                      width: width == null
                          ? null
                          : WidgetStatePropertyAll(width),
                    ),
                  ),
                );
                await tester.pump(const Duration(milliseconds: 60));
                final why = '$placement $state $insideEdge $width';
                expect(
                  tester.state(find.byType(_Probe)),
                  same(probe),
                  reason: why,
                );
                expect(
                  tester.getSize(find.byType(StratumFocusBorder)),
                  const Size(40, 20),
                  reason: why,
                );
                expect(
                  tester.getTopLeft(find.byType(_Probe)),
                  origin,
                  reason: why,
                );
              }
            }
          }
        }
      },
    );
  });

  group('StratumFocusBorder contrast', () {
    for (final (mode, theme) in [
      ('light', defaultThemeSet.light),
      ('dark', defaultThemeSet.dark!),
    ]) {
      testWidgets(
        'us04/nf01: in the package default $mode theme the outside ring '
        'paints border.subtle.blue and the inside ring border.default.normal',
        (tester) async {
          await tester.pumpWidget(
            _ring(state: FullWidgetState.focused, theme: theme),
          );
          await tester.pumpAndSettle();
          expect(
            _painted(tester).color,
            isSameColorAs(theme.color.border.subtle.blue),
          );
          expect(
            theme.color.border.subtle.blue,
            isSameColorAs(
              mode == 'light'
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFF1E40AF),
            ),
          );

          await tester.pumpWidget(
            _ring(
              customStyle: _inside,
              state: FullWidgetState.focused,
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            _painted(tester).color,
            isSameColorAs(theme.color.border.defaults.normal),
          );
        },
      );
    }

    testWidgets(
      'us04/nf01: swapping the theme while focused lerps the ring color, '
      'not a pop',
      (tester) async {
        final light = defaultThemeSet.light;
        final dark = defaultThemeSet.dark!;
        await tester.pumpWidget(
          _ring(state: FullWidgetState.focused, theme: light),
        );
        await tester.pumpAndSettle();
        expect(
          _painted(tester).color,
          isSameColorAs(light.color.border.subtle.blue),
        );

        await tester.pumpWidget(
          _ring(state: FullWidgetState.focused, theme: dark),
        );
        await tester.pump(const Duration(milliseconds: 60));
        final mid = _painted(tester).color;
        expect(mid, isNot(isSameColorAs(light.color.border.subtle.blue)));
        expect(mid, isNot(isSameColorAs(dark.color.border.subtle.blue)));

        await tester.pumpAndSettle();
        expect(
          _painted(tester).color,
          isSameColorAs(dark.color.border.subtle.blue),
        );
      },
    );
  });

  group('StratumFocusBorder accessibility gate', () {
    testWidgets('NFR-U06: the ring owns no node; its child reads unchanged', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final child = Semantics(
        label: 'Save',
        button: true,
        child: const SizedBox(width: 40, height: 20),
      );
      await tester.pumpWidget(
        _ring(state: FullWidgetState.focused, child: child),
      );

      expect(
        tester.getSemantics(find.byType(SizedBox).last),
        isSemantics(label: 'Save', isButton: true),
      );
      semantics.dispose();
    });

    for (final (name, fromMediaQuery) in [
      ('MediaQuery.disableAnimations', true),
      ('the platform reduceMotion flag', false),
    ]) {
      testWidgets('NFR-U03, fo06/us04/fr03/e06: under $name the ring, its '
          'second ring, and its glow take their new look at once', (
        tester,
      ) async {
        if (!fromMediaQuery) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        // debugDisableShadows, on by default in tests, drops the
        // maskFilter _glow reads.
        debugDisableShadows = false;
        try {
          const style = StratumFocusBorderStyle(
            secondRing: WidgetStatePropertyAll((
              color: Color(0xFF00FF00),
              width: null,
            )),
            glow: WidgetStatePropertyAll([
              BoxShadow(color: Color(0xFF0000FF), blurRadius: 6),
            ]),
          );
          Widget host(FullWidgetState state) => MediaQuery(
            data: MediaQueryData(disableAnimations: fromMediaQuery),
            child: _ring(state: state, customStyle: style),
          );
          await tester.pumpWidget(host(FullWidgetState.normal));

          await tester.pumpWidget(host(FullWidgetState.focused));
          final [second, first] = _rings(tester);
          expect(first.color, isSameColorAs(_colors.border.subtle.blue));
          expect(second.color, isSameColorAs(const Color(0xFF00FF00)));
          expect(_glow(tester).single.color.a, 1);

          await tester.pumpWidget(host(FullWidgetState.normal));
          expect(_rings(tester).every((ring) => ring.color.a == 0), isTrue);
          expect(_glow(tester).single.color.a, 0);
        } finally {
          debugDisableShadows = true;
        }
      });
    }

    testWidgets('NFR-U01 exception, us04/nf01: an app-wide focus style color '
        'replaces the token that fails 3:1', (tester) async {
      const strong = Color(0xFF1D4ED8);
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          theme: defaultThemeSet.light,
          parts: const {
            StratumFocusBorder: StratumFocusBorderStyle(
              color: WidgetStatePropertyAll(strong),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester).color, isSameColorAs(strong));
    });

    Widget highContrast(Widget child) => StratumThemeApplication(
      themes: defaultThemeSet,
      themeMode: ThemeMode.light,
      highContrast: StratumHighContrastMode.on,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

    testWidgets('NFR-U07, us04/nf01: under high contrast the ring paints the '
        'high-contrast token, and an app-wide focus style still shows its '
        'own color', (tester) async {
      await tester.pumpWidget(
        highContrast(
          const StratumFocusBorder(
            state: FullWidgetState.focused,
            child: _Probe(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final contrast = defaultThemeSet.highContrastLight!;
      expect(
        _painted(tester).color,
        isSameColorAs(contrast.focus.outsideColor),
      );

      const own = Color(0xFF7C3AED);
      await tester.pumpWidget(
        highContrast(
          const StratumComponentDefaults(
            styles: {},
            parts: {
              StratumFocusBorder: StratumFocusBorderStyle(
                color: WidgetStatePropertyAll(own),
              ),
            },
            child: StratumFocusBorder(
              state: FullWidgetState.focused,
              child: _Probe(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester).color, isSameColorAs(own));
    });

    testWidgets('NFR-U08: focus shows as an outline shape under high '
        'contrast, not a color change alone', (tester) async {
      await tester.pumpWidget(
        highContrast(
          const StratumFocusBorder(
            state: FullWidgetState.focused,
            borderRadius: _radius,
            child: _Probe(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ring = _painted(tester);
      expect(ring.color.a, greaterThan(0));
      expect(ring.outer, _rrect(-5, -5, 45, 25, 15));
    });

    testWidgets("NFR-E01: the ring follows the theme's focus group with no "
        'focus style set', (tester) async {
      const teal = Color(0xFF0D9488);
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          theme: fakeTheme.copyWith(
            focus: fakeTheme.focus.copyWith(outsideColor: teal, outsideGap: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ring = _painted(tester);
      expect(ring.color, isSameColorAs(teal));
      expect(ring.inner, _rrect(-4, -4, 44, 24, 14));
    });

    // NFR-E02, one test per field of StratumFocusBorderStyle: the field
    // shows, and a second probed field keeps the theme default.
    testWidgets('NFR-E02: color', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          customStyle: const StratumFocusBorderStyle(
            color: WidgetStatePropertyAll(_red),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ring = _painted(tester);
      expect(ring.color, isSameColorAs(_red));
      expect(ring.outer, _rrect(-5, -5, 45, 25, 15));
    });

    testWidgets('NFR-E02: width', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          customStyle: const StratumFocusBorderStyle(
            width: WidgetStatePropertyAll(4),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ring = _painted(tester);
      expect(ring.outer, _rrect(-6, -6, 46, 26, 16));
      expect(ring.color, isSameColorAs(_colors.border.subtle.blue));
    });

    testWidgets('NFR-E02: gap', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          customStyle: const StratumFocusBorderStyle(
            gap: WidgetStatePropertyAll(6),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ring = _painted(tester);
      expect(ring.inner, _rrect(-6, -6, 46, 26, 16));
      expect(ring.color, isSameColorAs(_colors.border.subtle.blue));
    });

    testWidgets('NFR-E02: radius', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          customStyle: const StratumFocusBorderStyle(
            radius: WidgetStatePropertyAll(
              BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ring = _painted(tester);
      expect(ring.inner, _rrect(-2, -2, 42, 22, 6));
      expect(ring.color, isSameColorAs(_colors.border.subtle.blue));
    });

    testWidgets('NFR-E02: placement', (tester) async {
      await tester.pumpWidget(
        _ring(state: FullWidgetState.focused, customStyle: _inside),
      );
      await tester.pumpAndSettle();
      final ring = _painted(tester);
      expect(ring.outer, _rrect(0, 0, 40, 20, 10));
      expect(ring.color, isSameColorAs(_colors.border.defaults.normal));
    });

    testWidgets('NFR-E02: motion', (tester) async {
      Widget host(FullWidgetState state) => _ring(
        state: state,
        customStyle: const StratumFocusBorderStyle(
          motion: WidgetStatePropertyAll(
            AnimationStyle(
              duration: Duration(milliseconds: 400),
              curve: Curves.easeInOutSine,
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(FullWidgetState.normal));
      await tester.pumpWidget(host(FullWidgetState.focused));
      // The theme's fast level, 125 ms, would have settled by now.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_painted(tester).color.a, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_painted(tester).color, isSameColorAs(_colors.border.subtle.blue));
    });

    testWidgets('NFR-E02: secondRing', (tester) async {
      await tester.pumpWidget(
        _ring(
          state: FullWidgetState.focused,
          customStyle: const StratumFocusBorderStyle(
            secondRing: WidgetStatePropertyAll((color: _red, width: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final [second, first] = _rings(tester);
      expect(second.color, isSameColorAs(_red));
      expect(first.color, isSameColorAs(_colors.border.subtle.blue));
    });

    testWidgets('NFR-E02: glow', (tester) async {
      // debugDisableShadows, on by default in tests, drops the maskFilter
      // _glow reads.
      debugDisableShadows = false;
      try {
        await tester.pumpWidget(
          _ring(
            state: FullWidgetState.focused,
            customStyle: const StratumFocusBorderStyle(
              glow: WidgetStatePropertyAll([
                BoxShadow(color: _red, blurRadius: 6),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_glow(tester).single.color, isSameColorAs(_red));
        expect(
          _painted(tester).color,
          isSameColorAs(_colors.border.subtle.blue),
        );
      } finally {
        debugDisableShadows = true;
      }
    });
  });
}
