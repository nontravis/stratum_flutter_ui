import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/utility/focus_border.dart'
    show focusBorderOutsideReach;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _radius = BorderRadius.all(Radius.circular(10));

/// The owner's red-border example: 5 px of red on the inner edge.
const _red = Color(0xFFFF0000);
const _redStyle = WidgetStyle(
  border: Border.fromBorderSide(BorderSide(color: _red, width: 5)),
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
  StratumFocusBorderStyle style = StratumFocusBorderStyle.outside,
  FullWidgetState state = FullWidgetState.normal,
  bool insideEdge = false,
  BorderRadiusGeometry? borderRadius = _radius,
  Color? customColor,
  double? width,
  double? gap,
  WidgetStyle? customStyle,
  Map<Type, WidgetStyle> defaults = const {},
  StratumThemeData? theme,
}) {
  return themedHost(
    StratumComponentDefaults(
      styles: defaults,
      child: StratumFocusBorder(
        style: style,
        state: state,
        insideEdge: insideEdge,
        borderRadius: borderRadius,
        customColor: customColor,
        width: width,
        gap: gap,
        customStyle: customStyle,
        child: const _Probe(),
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

/// Pumps [host] for every style and [FullWidgetState], and expects
/// [_redStyle] on the shown looks only: the focused look of either style
/// and the inside style's hovered look.
Future<void> _expectShownLooksOnly(
  WidgetTester tester,
  Widget Function(StratumFocusBorderStyle style, FullWidgetState state) host,
) async {
  for (final style in StratumFocusBorderStyle.values) {
    for (final state in FullWidgetState.values) {
      await tester.pumpWidget(host(style, state));
      await tester.pumpAndSettle();
      final why = '$style $state';
      final shown =
          state == FullWidgetState.focused ||
          (state == FullWidgetState.hovered &&
              style == StratumFocusBorderStyle.inside);
      final ring = _painted(tester);
      if (!shown) {
        expect(ring.color.a, 0, reason: why);
        continue;
      }
      expect(ring.color, isSameColorAs(_red), reason: why);
      if (style == StratumFocusBorderStyle.outside) {
        // The restyle moves color and width only (R8): the outside ring
        // still sits after the default 2 px gap, at the restyled width.
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
      'us04/fr03: an outside ring shows only when focused, 3 px in '
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
      'us04/fr03/e07: an outside ring with insideEdge paints the outside '
      'color and width on the inner edge at the child radius, gap unused',
      (tester) async {
        for (final gap in [null, 6.0]) {
          await tester.pumpWidget(
            _ring(state: FullWidgetState.focused, insideEdge: true, gap: gap),
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
      'us04/fr03: an inside ring paints border.default.normal on the inner '
      'edge, 3 px when hovered and 2 px when focused, nothing when normal',
      (tester) async {
        const inside = StratumFocusBorderStyle.inside;
        await tester.pumpWidget(_ring(style: inside));
        expect(_hidden(tester), isTrue);

        await tester.pumpWidget(
          _ring(style: inside, state: FullWidgetState.hovered),
        );
        await tester.pumpAndSettle();
        var ring = _painted(tester);
        expect(ring.color, isSameColorAs(_colors.border.defaults.normal));
        expect(ring.outer, _rrect(0, 0, 40, 20, 10));
        expect(ring.inner, _rrect(3, 3, 37, 17, 7));

        await tester.pumpWidget(
          _ring(style: inside, state: FullWidgetState.focused),
        );
        await tester.pumpAndSettle();
        ring = _painted(tester);
        expect(ring.color, isSameColorAs(_colors.border.defaults.normal));
        expect(ring.outer, _rrect(0, 0, 40, 20, 10));
        expect(ring.inner, _rrect(2, 2, 38, 18, 8));
      },
    );

    testWidgets(
      'us04/fr03/e11: every other FullWidgetState value shows the normal '
      'look, no ring, in either style',
      (tester) async {
        const shown = {
          FullWidgetState.normal,
          FullWidgetState.hovered,
          FullWidgetState.focused,
        };
        for (final style in StratumFocusBorderStyle.values) {
          for (final state in FullWidgetState.values) {
            if (shown.contains(state)) continue;
            await tester.pumpWidget(_ring(style: style, state: state));
            await tester.pumpAndSettle();
            expect(_hidden(tester), isTrue, reason: '$style $state');
          }
        }
      },
    );

    testWidgets(
      'us04/fr03/e08: a width override applies in every shown state of '
      'either style',
      (tester) async {
        for (final state in [
          FullWidgetState.hovered,
          FullWidgetState.focused,
        ]) {
          await tester.pumpWidget(
            _ring(
              style: StratumFocusBorderStyle.inside,
              state: state,
              width: 4,
            ),
          );
          await tester.pumpAndSettle();
          expect(_painted(tester).inner, _rrect(4, 4, 36, 16, 6));
        }

        await tester.pumpWidget(
          _ring(state: FullWidgetState.focused, width: 4),
        );
        await tester.pumpAndSettle();
        final ring = _painted(tester);
        expect(ring.inner, _rrect(-2, -2, 42, 22, 12));
        expect(ring.outer, _rrect(-6, -6, 46, 26, 16));
      },
    );

    testWidgets("us04/fr03: customColor replaces either style's color and gap "
        'replaces the 2 px gap', (tester) async {
      const red = Color(0xFFFF0000);
      await tester.pumpWidget(
        _ring(state: FullWidgetState.focused, customColor: red, gap: 6),
      );
      await tester.pumpAndSettle();
      final ring = _painted(tester);
      expect(ring.color, isSameColorAs(red));
      expect(ring.inner, _rrect(-6, -6, 46, 26, 16));
      expect(ring.outer, _rrect(-9, -9, 49, 29, 19));

      await tester.pumpWidget(
        _ring(
          style: StratumFocusBorderStyle.inside,
          state: FullWidgetState.hovered,
          customColor: red,
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester).color, isSameColorAs(red));
    });

    testWidgets(
      'us04/fr03: a ring around a child with no radius takes the gap as '
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

    testWidgets(
      'us07/fr03/e01: an outside ring reaches its gap plus its width, the '
      "app-wide default's after a restyle",
      (tester) async {
        double? reach;
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              reach = focusBorderOutsideReach(context);
              return const SizedBox();
            },
          ),
        );
        expect(reach, 5);

        await tester.pumpWidget(
          StratumComponentDefaults(
            styles: const {
              StratumFocusBorder: WidgetStyle(
                border: Border.fromBorderSide(BorderSide(width: 7)),
              ),
            },
            child: Builder(
              builder: (context) {
                reach = focusBorderOutsideReach(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(reach, 9);
      },
    );

    testWidgets(
      "us04/fr03/e13: a caller's customStyle restyles only the shown looks; "
      'every nothing look still shows no ring',
      (tester) async {
        await _expectShownLooksOnly(
          tester,
          (style, state) =>
              _ring(style: style, state: state, customStyle: _redStyle),
        );
      },
    );

    testWidgets(
      'us04/fr03/e13: an app-wide default restyles only the shown looks of '
      'every ring; every nothing look still shows no ring',
      (tester) async {
        await _expectShownLooksOnly(
          tester,
          (style, state) => _ring(
            style: style,
            state: state,
            defaults: const {StratumFocusBorder: _redStyle},
          ),
        );
      },
    );

    testWidgets(
      'us04/fr03/e14: an app-wide default restyles width, but insideEdge '
      'still places the ring on the inner edge',
      (tester) async {
        await tester.pumpWidget(
          _ring(
            state: FullWidgetState.focused,
            insideEdge: true,
            defaults: const {StratumFocusBorder: _redStyle},
          ),
        );
        await tester.pumpAndSettle();

        final ring = _painted(tester);
        expect(ring.color, isSameColorAs(_red));
        expect(ring.outer, _rrect(0, 0, 40, 20, 10));
        expect(ring.inner, _rrect(5, 5, 35, 15, 5));
      },
    );

    testWidgets(
      'us04/fr03/e14: a customStyle restyles color and width, but the '
      'outside ring still computes its placement after the gap',
      (tester) async {
        await tester.pumpWidget(
          _ring(state: FullWidgetState.focused, customStyle: _redStyle),
        );
        await tester.pumpAndSettle();

        final ring = _painted(tester);
        expect(ring.color, isSameColorAs(_red));
        expect(ring.inner, _rrect(-2, -2, 42, 22, 12));
        expect(ring.outer, _rrect(-7, -7, 47, 27, 17));
      },
    );

    testWidgets(
      "us04/fr03/e14: the ring's own customColor, width, and gap win over "
      'either style layer',
      (tester) async {
        const blue = Color(0xFF0000FF);
        await tester.pumpWidget(
          _ring(
            state: FullWidgetState.focused,
            customColor: blue,
            width: 4,
            gap: 1,
            customStyle: _redStyle,
            defaults: const {StratumFocusBorder: _redStyle},
          ),
        );
        await tester.pumpAndSettle();

        final ring = _painted(tester);
        expect(ring.color, isSameColorAs(blue));
        expect(ring.inner, _rrect(-1, -1, 41, 21, 11));
        expect(ring.outer, _rrect(-5, -5, 45, 25, 15));
      },
    );
  });

  group('StratumFocusBorder motion', () {
    testWidgets("us04/fr03: the ring fades over the theme's fast level on its "
        'standard curve', (tester) async {
      final theme = motionTheme(
        fast: const Duration(milliseconds: 100),
        standard: const StratumNamedCurve('easeIn'),
      );
      await tester.pumpWidget(_ring(theme: theme));
      await tester.pumpWidget(
        _ring(state: FullWidgetState.focused, theme: theme),
      );

      final builder = tester.widget<TweenAnimationBuilder<WidgetStyle>>(
        find.byType(TweenAnimationBuilder<WidgetStyle>),
      );
      expect(builder.duration, const Duration(milliseconds: 100));
      expect(builder.curve, Curves.easeIn);
      expect(_painted(tester).color.a, 0);

      await tester.pump(const Duration(milliseconds: 50));
      final half = _painted(tester).color.a;
      expect(half, greaterThan(0));
      expect(half, lessThan(1));

      await tester.pump(const Duration(milliseconds: 50));
      expect(_painted(tester).color, isSameColorAs(_colors.border.subtle.blue));
    });

    for (final (name, fromMediaQuery) in [
      ('MediaQuery.disableAnimations', true),
      ('the platform reduceMotion flag', false),
    ]) {
      testWidgets(
        'us04/fr03/e06: under $name the ring takes its new look at once',
        (tester) async {
          if (!fromMediaQuery) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(reduceMotion: true);
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
          }
          Widget host(FullWidgetState state) => MediaQuery(
            data: MediaQueryData(disableAnimations: fromMediaQuery),
            child: _ring(state: state),
          );
          await tester.pumpWidget(host(FullWidgetState.normal));

          await tester.pumpWidget(host(FullWidgetState.focused));
          expect(
            _painted(tester).color,
            isSameColorAs(_colors.border.subtle.blue),
          );

          await tester.pumpWidget(host(FullWidgetState.normal));
          expect(_hidden(tester), isTrue);
        },
      );
    }

    testWidgets(
      'us04/fr03: a state flip before the fade settles continues smoothly '
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
      'us04/fr03/e09: no style, state, placement, or width changes the '
      "child's layout size, position, or State",
      (tester) async {
        await tester.pumpWidget(_ring());
        final probe = tester.state(find.byType(_Probe));
        final origin = tester.getTopLeft(find.byType(_Probe));

        for (final style in StratumFocusBorderStyle.values) {
          for (final state in [
            FullWidgetState.normal,
            FullWidgetState.hovered,
            FullWidgetState.focused,
          ]) {
            for (final insideEdge in [false, true]) {
              for (final width in [null, 8.0]) {
                await tester.pumpWidget(
                  _ring(
                    style: style,
                    state: state,
                    insideEdge: insideEdge,
                    width: width,
                  ),
                );
                await tester.pump(const Duration(milliseconds: 60));
                final why = '$style $state $insideEdge $width';
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
              style: StratumFocusBorderStyle.inside,
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
}
