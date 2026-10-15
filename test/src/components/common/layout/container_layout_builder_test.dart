@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// Build Gate rows of ContainerLayout.builder (US-17 Accessibility and UX):
// NFR-U03 n/a: the builder adds no animation; the box's style animation and
//   the tap surface's overlay and ring keep their own reduced-motion rules.
// NFR-U04 n/a: the builder has no text of its own; its content sits in the
//   box as a child does.
// NFR-U07 n/a: no paint of its own; the focus ring keeps the tap surface's
//   colors and their US-04 NF-01 exception, which the us04/nf01 tests of
//   ink_well_test.dart prove.
// NFR-U09 n/a: the builder adds no gesture; the tap surface keeps its taps
//   and keys.
// NFR-E01, NFR-E02 n/a: a FO-06 layout primitive, not a component; the
//   builder draws no visual value of its own.

void _noop() {}

const ValueKey<String> _contentKey = ValueKey('content');

/// A component on the stateless base, which gives its child the disabled
/// scope of a disabled component (FO-08 US-07).
class _Component extends StratumStatelessWidget {
  const new({super.disabled, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Every state a builder received, one entry per call.
final class _Seen {
  final states = <InteractionState>[];

  InteractionState get last => states.last;
}

/// The words of [state]'s true values, else 'idle'.
String _words(InteractionState state) {
  final words = [
    if (state.hovered) 'hovered',
    if (state.pressed) 'pressed',
    if (state.focused) 'focused',
    if (state.disabled) 'disabled',
  ];
  return words.isEmpty ? 'idle' : words.join(' ');
}

/// A [ContainerLayout] whose content is its state in words.
ContainerLayout _card(_Seen seen, {Interaction? interaction}) =>
    ContainerLayout(
      interaction: interaction,
      builder: (context, state) {
        seen.states.add(state);
        return Text(_words(state));
      },
    );

WidgetStatesController _states(Set<WidgetState> value) {
  final controller = WidgetStatesController(value);
  addTearDown(controller.dispose);
  return controller;
}

FocusNode _node() {
  final node = FocusNode();
  addTearDown(node.dispose);
  return node;
}

/// A mouse moved over the first [ContainerLayout].
Future<TestGesture> _mouseOver(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(tester.getCenter(find.byType(ContainerLayout).first));
  await tester.pump();
  return mouse;
}

/// [child] under the app's default Tab and activation keys, in a focused
/// scope so the first Tab reaches the keys.
Widget _keyboardHost(Widget child) => themedHost(
  Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(
      actions: WidgetsApp.defaultActions,
      child: FocusScope(autofocus: true, child: child),
    ),
  ),
);

/// Whether the tap surface's ring shows.
bool _ring(WidgetTester tester) =>
    tester.widget<StratumFocusBorder>(find.byType(StratumFocusBorder)).state ==
    FullWidgetState.focused;

/// The hover and press overlay color, or null when it paints nothing.
Color? _overlayColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(InkWell),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground,
      ),
    ),
  );
  final color = (box.decoration as BoxDecoration).color;
  return color == null || color.a == 0 ? null : color;
}

void main() {
  group('ContainerLayout.builder hover and press', () {
    testWidgets(
      'fo06/us17/s1, fo06/us17/fr01: a pointer over a tappable card builds '
      'the hovered content',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(_card(seen, interaction: const Interaction(onTap: _noop))),
        );
        expect(find.text('idle'), findsOneWidget);

        final mouse = await _mouseOver(tester);
        expect(find.text('hovered'), findsOneWidget);

        await mouse.moveTo(Offset.zero);
        await tester.pump();
        expect(find.text('idle'), findsOneWidget);
      },
    );

    testWidgets('fo06/us17/fr01/e01, BP5: a pointer move inside the card that '
        'changes no value builds nothing', (tester) async {
      final seen = _Seen();
      await tester.pumpWidget(
        themedHost(_card(seen, interaction: const Interaction(onTap: _noop))),
      );
      final mouse = await _mouseOver(tester);
      final calls = seen.states.length;

      await mouse.moveBy(const Offset(1, 1));
      await tester.pump();
      await mouse.moveBy(const Offset(-2, 0));
      await tester.pump();

      expect(seen.states, hasLength(calls));
    });

    testWidgets(
      'fo06/us17/s2: pressing and holding the card builds the pressed '
      'content while it is held',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(_card(seen, interaction: const Interaction(onTap: _noop))),
        );

        final press = await tester.startGesture(
          tester.getCenter(find.byType(ContainerLayout)),
        );
        await tester.pump(kPressTimeout);
        expect(find.text('pressed'), findsOneWidget);

        await press.up();
        await tester.pumpAndSettle();
        expect(find.text('idle'), findsOneWidget);
      },
    );

    testWidgets(
      'fo06/us17/s3, fo06/us17/fr01/e05: a preview that sets hovered shows '
      'the hovered content and the hover overlay',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(
            _card(
              seen,
              interaction: Interaction(
                onTap: _noop,
                statesController: _states({WidgetState.hovered}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('hovered'), findsOneWidget);
        expect(_overlayColor(tester), fakeHover);
      },
    );

    testWidgets(
      'fo06/us17/s4, fo06/us17/fr01/e06, fo06/us04/fr04/e03: a container with only '
      'a hover listener builds the hovered content and paints no overlay',
      (tester) async {
        final seen = _Seen();
        final hovers = <bool>[];
        await tester.pumpWidget(
          themedHost(
            _card(seen, interaction: Interaction(onHover: hovers.add)),
          ),
        );

        await _mouseOver(tester);
        await tester.pumpAndSettle();

        expect(find.text('hovered'), findsOneWidget);
        expect(hovers, [true]);
        expect(_overlayColor(tester), isNull);
      },
    );

    testWidgets('fo06/us17/fr01/e06: adding and removing onTap while hovered '
        'keeps hovered true', (tester) async {
      final seen = _Seen();
      Widget build({required bool tappable}) => themedHost(
        _card(
          seen,
          interaction: Interaction(
            onTap: tappable ? _noop : null,
            onHover: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(build(tappable: true));
      await _mouseOver(tester);
      expect(seen.last.hovered, isTrue);

      await tester.pumpWidget(build(tappable: false));
      await tester.pump();
      expect(seen.last.hovered, isTrue);

      await tester.pumpWidget(build(tappable: true));
      await tester.pump();
      expect(seen.last.hovered, isTrue);
    });

    testWidgets(
      'fo06/us17/fr01/e02: with fit the built content fits the box as '
      'a child does',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            ContainerLayout(
              style: const WidgetStyle(width: 100, height: 50),
              fit: BoxFit.fill,
              interaction: const Interaction(
                onTap: _noop,
                tapTargetSize: TapTargetSize.shrinkWrap,
              ),
              builder: (context, state) =>
                  const SizedBox(key: _contentKey, width: 20, height: 10),
            ),
          ),
        );

        expect(
          tester.getRect(find.byKey(_contentKey)).size,
          const Size(100, 50),
        );
      },
    );
  });

  group('ContainerLayout.builder focus', () {
    testWidgets(
      'fo06/us17/s5, fo06/us17/fr02/e01, NFR-U02: Tab builds the focused '
      'content with the ring',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          _keyboardHost(
            _card(seen, interaction: const Interaction(onTap: _noop)),
          ),
        );
        expect(_ring(tester), isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        expect(find.text('focused'), findsOneWidget);
        expect(_ring(tester), isTrue);
      },
    );

    testWidgets(
      'fo06/us17/s6, fo06/us17/fr02/e02: a mouse click under the default '
      'focus type builds no focused content',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(_card(seen, interaction: const Interaction(onTap: _noop))),
        );

        await tester.tap(
          find.byType(ContainerLayout),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(seen.last.focused, isFalse);
        expect(_ring(tester), isFalse);
      },
    );

    testWidgets(
      'fo06/us17/s7, fo06/us17/fr02/e03: under FocusType.focused a click '
      'builds the focused content with the ring',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(
            _card(
              seen,
              interaction: const Interaction(
                onTap: _noop,
                focusType: FocusType.focused,
              ),
            ),
          ),
        );

        await tester.tap(
          find.byType(ContainerLayout),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(seen.last.focused, isTrue);
        expect(_ring(tester), isTrue);
      },
    );

    for (final type in [FocusType.none, FocusType.invisible]) {
      testWidgets(
        'fo06/us17/fr02/e04: under FocusType.${type.name} Tab builds no '
        'focused content',
        (tester) async {
          final seen = _Seen();
          final node = _node();
          await tester.pumpWidget(
            _keyboardHost(
              _card(
                seen,
                interaction: Interaction(
                  onTap: _noop,
                  focusType: type,
                  focusNode: node,
                ),
              ),
            ),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();

          expect(node.hasPrimaryFocus, type == FocusType.invisible);
          expect(seen.last.focused, isFalse);
        },
      );
    }

    testWidgets('fo06/us17/fr02/e05: a focused card that turns disabled builds '
        'focused false', (tester) async {
      final seen = _Seen();
      final node = _node();
      Widget build({required bool disabled}) => _keyboardHost(
        _card(
          seen,
          interaction: Interaction(
            onTap: _noop,
            focusNode: node,
            disabled: disabled,
          ),
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(seen.last.focused, isTrue);

      await tester.pumpWidget(build(disabled: true));
      await tester.pumpAndSettle();

      expect(seen.last.focused, isFalse);
      expect(seen.last.disabled, isTrue);
    });
  });

  group('ContainerLayout.builder disabled', () {
    testWidgets("fo06/us17/fr03/e01: the interaction's own disabled builds the "
        'disabled content', (tester) async {
      final seen = _Seen();
      await tester.pumpWidget(
        themedHost(
          _card(
            seen,
            interaction: const Interaction(onTap: _noop, disabled: true),
          ),
        ),
      );

      expect(find.text('disabled'), findsOneWidget);
    });

    testWidgets(
      'fo06/us17/s8, fo06/us17/fr03/e02: a card inside a component that turns '
      'disabled builds the disabled content',
      (tester) async {
        final seen = _Seen();
        final card = _card(seen, interaction: const Interaction(onTap: _noop));
        await tester.pumpWidget(
          themedHost(_Component(disabled: false, child: card)),
        );
        expect(find.text('idle'), findsOneWidget);

        await tester.pumpWidget(
          themedHost(_Component(disabled: true, child: card)),
        );

        expect(find.text('disabled'), findsOneWidget);
      },
    );

    testWidgets(
      'fo06/us17/s9, fo06/us17/fr03/e04: a disabled card that a preview sets '
      'hovered builds the disabled content and no hovered content',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(
            _card(
              seen,
              interaction: Interaction(
                onTap: _noop,
                disabled: true,
                statesController: _states({WidgetState.hovered}),
              ),
            ),
          ),
        );

        expect(find.text('disabled'), findsOneWidget);
      },
    );

    testWidgets(
      'fo06/us17/fr03/e05: a hovered and held card that turns disabled '
      'builds hovered and pressed false',
      (tester) async {
        final seen = _Seen();
        Widget build({required bool disabled}) => themedHost(
          _card(
            seen,
            interaction: Interaction(onTap: _noop, disabled: disabled),
          ),
        );
        await tester.pumpWidget(build(disabled: false));
        final mouse = await _mouseOver(tester);
        await mouse.down(tester.getCenter(find.byType(ContainerLayout)));
        await tester.pump(kPressTimeout);
        expect(find.text('hovered pressed'), findsOneWidget);

        await tester.pumpWidget(build(disabled: true));

        expect(find.text('disabled'), findsOneWidget);
        await mouse.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      "fo06/us04/fr04/e05, fo06/us04/fr04/e06: a flip of the card's own "
      'disabled under a still pointer turns hovered within one frame of '
      'onHover, here in the same frame',
      (tester) async {
        final seen = _Seen();
        final hovers = <bool>[];
        Widget build({required bool disabled}) => themedHost(
          _card(
            seen,
            interaction: Interaction(
              onTap: _noop,
              onHover: hovers.add,
              disabled: disabled,
            ),
          ),
        );
        await tester.pumpWidget(build(disabled: false));
        await _mouseOver(tester);
        expect(hovers, [true]);
        expect(seen.last.hovered, isTrue);

        await tester.pumpWidget(build(disabled: true));
        expect(hovers, [true, false]);
        expect(seen.last.hovered, isFalse);

        await tester.pumpWidget(build(disabled: false));
        expect(hovers, [true, false, true]);
        expect(seen.last.hovered, isTrue);
      },
    );

    testWidgets(
      'fo06/us04/fr04/e06, PD3: a component enabled again under a still '
      'pointer calls onHover(true) once, and hovered turns true within one '
      'frame',
      (tester) async {
        final seen = _Seen();
        final hovers = <bool>[];
        final card = _card(
          seen,
          interaction: Interaction(onTap: _noop, onHover: hovers.add),
        );
        Widget build({required bool disabled}) =>
            themedHost(_Component(disabled: disabled, child: card));
        await tester.pumpWidget(build(disabled: false));
        await _mouseOver(tester);

        await tester.pumpWidget(build(disabled: true));
        expect(hovers, [true, false]);
        expect(seen.last.hovered, isFalse);
        expect(seen.last.disabled, isTrue);

        await tester.pumpWidget(build(disabled: false));
        expect(hovers, [true, false, true]);
        // One frame: the one the pointer report schedules when the mouse
        // tracker finds the pointer over the surface again.
        await tester.pump();

        expect(seen.last.hovered, isTrue);
        expect(hovers, [true, false, true]);
      },
    );
  });

  group('ContainerLayout.builder with no tap surface', () {
    testWidgets(
      'fo06/us17/s10, fo06/us17/fr04/e01: a builder with no interaction '
      'builds every value false and adds no tap surface',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(themedHost(_card(seen)));

        await _mouseOver(tester);

        expect(seen.last, const InteractionState());
        expect(find.byType(StratumInkWell), findsNothing);
      },
    );

    testWidgets(
      'fo06/us17/fr04/e02: an interaction with only disabled builds no '
      'tap surface and every value false',
      (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(
            _card(seen, interaction: const Interaction(disabled: true)),
          ),
        );

        expect(seen.last, const InteractionState());
        expect(find.byType(StratumInkWell), findsNothing);
      },
    );

    for (final (name, interaction) in [
      ('no interaction', null),
      ('an empty interaction', const Interaction()),
    ]) {
      testWidgets('fo06/us17/fr03/e03, fo06/us17/fr04/e03: with $name inside a '
          'disabled component every value is false', (tester) async {
        final seen = _Seen();
        await tester.pumpWidget(
          themedHost(
            _Component(
              disabled: true,
              child: _card(seen, interaction: interaction),
            ),
          ),
        );

        expect(seen.last, const InteractionState());
      });
    }

    testWidgets('fo06/us17/fr04/e01: a builder inside a hovered tappable card, '
        'with no tap surface of its own, builds every value false', (
      tester,
    ) async {
      final seen = _Seen();
      final outer = <bool>[];
      await tester.pumpWidget(
        themedHost(
          ContainerLayout(
            interaction: Interaction(onTap: _noop, onHover: outer.add),
            child: _card(seen),
          ),
        ),
      );

      await _mouseOver(tester);

      expect(outer, [true]);
      expect(seen.last, const InteractionState());
    });
  });

  group('ContainerLayout.builder content source', () {
    testWidgets(
      'fo06/us17/s11, fo06/us17/fr05/e01: child and builder together fail a '
      'debug assertion that names the fix',
      (tester) async {
        expect(
          () => ContainerLayout(
            builder: (context, state) => const SizedBox(),
            child: const SizedBox(),
          ),
          throwsA(
            isA<AssertionError>().having(
              (error) => '${error.message}',
              'message',
              allOf(
                contains('Cannot provide both a child and a builder.'),
                contains('not both'),
              ),
            ),
          ),
        );
      },
    );

    testWidgets('fo06/us17/fr05/e02: neither child nor builder builds an empty '
        'box', (tester) async {
      await tester.pumpWidget(themedHost(const ContainerLayout()));

      expect(tester.getSize(find.byType(ContainerLayout)), Size.zero);
    });
  });

  group('ContainerLayout.builder accessibility gate', () {
    Widget labeledCard({required bool built}) => themedHost(
      built
          ? ContainerLayout(
              semantics: const SemanticsProperties(label: 'Card'),
              interaction: const Interaction(onTap: _noop),
              builder: (context, state) =>
                  const SizedBox(width: 20, height: 20),
            )
          : const ContainerLayout(
              semantics: SemanticsProperties(label: 'Card'),
              interaction: Interaction(onTap: _noop),
              child: SizedBox(width: 20, height: 20),
            ),
    );

    testWidgets('NFR-U01: a labeled card built from its state passes text '
        'contrast and labeled tap targets', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(labeledCard(built: true));

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('NFR-U05: a card built from its state meets every platform '
        'tap target', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(labeledCard(built: true));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(
        tester,
        meetsGuideline(
          const MinimumTapTargetGuideline(size: Size(24, 24), link: ''),
        ),
      );
      handle.dispose();
    });

    testWidgets('NFR-U06: a card built from its state reads as it does with '
        'a child', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(labeledCard(built: false));
      final withChild = tester
          .getSemantics(find.bySemanticsLabel('Card'))
          .getSemanticsData();

      await tester.pumpWidget(labeledCard(built: true));
      final node = tester.getSemantics(find.bySemanticsLabel('Card'));

      expect(node.getSemanticsData(), withChild);
      expect(
        node,
        isSemantics(label: 'Card', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('NFR-U08: under high contrast keyboard focus shows the ring, '
        "a shape, and the app's own text cue", (tester) async {
      final seen = _Seen();
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: defaultThemeSet,
          themeMode: ThemeMode.light,
          highContrast: StratumHighContrastMode.on,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: FocusScope(
                  autofocus: true,
                  child: Center(
                    child: _card(
                      seen,
                      interaction: const Interaction(onTap: _noop),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(find.text('focused'), findsOneWidget);
      expect(_ring(tester), isTrue);
    });

    test('fo06/us17/fr01, BP6, PD12: the builder and its state warn against '
        'color-only state (WCAG 1.4.1)', () {
      for (final path in [
        'lib/src/components/common/layout/container_layout.dart',
        'lib/src/components/common/model/interaction_state.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('(WCAG 1.4.1)'),
          reason: path,
        );
      }
    });
  });
}
