@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// Build Gate rows of HoverBuilder (US-16 Accessibility and UX):
// NFR-U01, NFR-U07 n/a: no paint of its own, no hover overlay, no ring.
// NFR-U02 n/a: an observer takes no focus and adds no Tab stop (FR-03).
// NFR-U03 n/a: it runs no animation and paints nothing.
// NFR-U04 n/a: no text of its own and no footprint of its own.
// NFR-U05 n/a: not interactive; the wrapped widget keeps its own target.
// NFR-U09 n/a: it handles no gesture and no tap.
// NFR-E01, NFR-E02 n/a: a FO-06 primitive, not a component; it draws no
//   visual value and takes no customStyle.

/// A component on the stateless base, which gives its child the disabled
/// scope of a disabled component (FO-08 US-07).
class _Component extends StratumStatelessWidget {
  const new({super.disabled, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// [child], counting its own builds through [onBuild].
class _Counted extends StatelessWidget {
  const new({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

/// A card whose look is its hover value in words; [seen] holds every value
/// the builder received, [hovers] every `onHover` call.
HoverBuilder _card(List<bool> hovers, List<bool> seen) => HoverBuilder(
  onHover: hovers.add,
  builder: (context, hovered, child) {
    seen.add(hovered);
    return SizedBox(
      width: 80,
      height: 40,
      child: Text(hovered ? 'hovered' : 'idle'),
    );
  },
);

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Future<void> _enter(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(tester.getCenter(find.byType(HoverBuilder)));
  await tester.pump();
}

void main() {
  group('HoverBuilder', () {
    testWidgets('us16/s1, us16/fr01: a pointer entering builds the hover '
        'look and calls onHover(true)', (tester) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      await tester.pumpWidget(themedHost(_card(hovers, seen)));
      expect(find.text('idle'), findsOneWidget);

      await _enter(tester, await _mouse(tester));

      expect(find.text('hovered'), findsOneWidget);
      expect(hovers, [true]);
    });

    testWidgets('us16/s2, us16/fr01: the pointer leaving builds the idle '
        'look and calls onHover(false)', (tester) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      await tester.pumpWidget(themedHost(_card(hovers, seen)));
      final mouse = await _mouse(tester);
      await _enter(tester, mouse);

      await mouse.moveTo(Offset.zero);
      await tester.pump();

      expect(find.text('idle'), findsOneWidget);
      expect(hovers, [true, false]);
    });

    testWidgets('us16/fr01/e01, BP5: a pointer move inside builds nothing '
        'and calls nothing', (tester) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      await tester.pumpWidget(themedHost(_card(hovers, seen)));
      final mouse = await _mouse(tester);
      await _enter(tester, mouse);
      final calls = seen.length;

      await mouse.moveBy(const Offset(3, 2));
      await tester.pump();
      await mouse.moveBy(const Offset(-6, 0));
      await tester.pump();

      expect(seen, hasLength(calls));
      expect(hovers, [true]);
    });

    testWidgets('us16/fr01, PD4: the builder and onHover see the new value in '
        'the same frame', (tester) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      await tester.pumpWidget(themedHost(_card(hovers, seen)));
      final mouse = await _mouse(tester);

      await mouse.moveTo(tester.getCenter(find.byType(HoverBuilder)));
      await tester.pump();

      expect(hovers, [true]);
      expect(seen.last, isTrue);
    });

    testWidgets('us16/s3, us16/fr01/e02, BP4: content scrolling under a '
        'still pointer moves hover to the row that comes under it', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final hovers = [<bool>[], <bool>[], <bool>[], <bool>[]];
      await tester.pumpWidget(
        themedHost(
          SizedBox(
            width: 200,
            height: 100,
            child: ListView(
              controller: controller,
              children: [
                for (var i = 0; i < 4; i++)
                  HoverBuilder(
                    onHover: hovers[i].add,
                    builder: (context, hovered, child) => SizedBox(
                      height: 50,
                      child: Text(hovered ? 'row $i hovered' : 'row $i'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('row 0')));
      await tester.pump();
      expect(find.text('row 0 hovered'), findsOneWidget);

      controller.jumpTo(50);
      // The scroll frame, after which Flutter's mouse tracker reports the
      // exit and the enter, then the frame the two builders schedule.
      await tester.pump();
      await tester.pump();

      expect(find.text('row 0 hovered'), findsNothing);
      expect(find.text('row 1 hovered'), findsOneWidget);
      expect(hovers[0], [true, false]);
      expect(hovers[1], [true]);
    });

    testWidgets('us16/fr01/e03, BP1: child reaches builder as the same widget '
        'on every call and does not rebuild', (tester) async {
      var childBuilds = 0;
      final counted = _Counted(
        onBuild: () => childBuilds++,
        child: const SizedBox(width: 40, height: 20),
      );
      final received = <Widget?>[];
      await tester.pumpWidget(
        themedHost(
          HoverBuilder(
            builder: (context, hovered, child) {
              received.add(child);
              return child!;
            },
            child: counted,
          ),
        ),
      );
      final mouse = await _mouse(tester);
      await _enter(tester, mouse);
      await mouse.moveTo(Offset.zero);
      await tester.pump();

      expect(received, hasLength(3));
      expect(received, everyElement(same(counted)));
      expect(childBuilds, 1);
    });

    testWidgets('us16/fr01: removing a hovered builder calls no listener and '
        'throws nothing', (tester) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      await tester.pumpWidget(themedHost(_card(hovers, seen)));
      await _enter(tester, await _mouse(tester));

      await tester.pumpWidget(themedHost(const SizedBox()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(hovers, [true]);
    });

    testWidgets('us16/fr03/e02, us16/fr03: a 16 px icon keeps its size and '
        'gets no overlay while hovered', (tester) async {
      await tester.pumpWidget(
        themedHost(
          HoverBuilder(
            builder: (context, hovered, child) =>
                const Icon(Icons.star, size: 16),
          ),
        ),
      );
      expect(tester.getSize(find.byType(HoverBuilder)), const Size(16, 16));

      await _enter(tester, await _mouse(tester));

      expect(tester.getSize(find.byType(HoverBuilder)), const Size(16, 16));
      expect(
        find.descendant(
          of: find.byType(HoverBuilder),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('us16/fr03, D1: taps, the cursor, and hover reach the widgets '
        'it wraps and the widgets behind it', (tester) async {
      var taps = 0;
      final behind = <bool>[];
      await tester.pumpWidget(
        themedHost(
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MouseRegion(
                    onEnter: (_) => behind.add(true),
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(
                  child: HoverBuilder(
                    builder: (context, hovered, child) => child!,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        // A childless box takes no hit of its own.
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps++,
                        child: const SizedBox(width: 40, height: 40),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await _enter(tester, await _mouse(tester));
      await tester.tap(find.byType(HoverBuilder));

      expect(behind, [true]);
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
      expect(taps, 1);
    });

    testWidgets('us16/fr04/e01, NFR-U06: semantics label the wrapped group '
        'in one node of its own, read before the nodes inside', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          HoverBuilder(
            semantics: const SemanticsProperties(label: 'ที่อยู่จัดส่ง'),
            builder: (context, hovered, child) => child!,
            child: Semantics(
              container: true,
              textField: true,
              label: 'ถนน',
              child: const SizedBox(width: 80, height: 20),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('ที่อยู่จัดส่ง')),
        matchesSemantics(
          label: 'ที่อยู่จัดส่ง',
          children: [matchesSemantics(label: 'ถนน', isTextField: true)],
        ),
      );
      handle.dispose();
    });

    testWidgets('us16/fr04/e02, NFR-U06: null semantics adds no node; the '
        'wrapped node reads unchanged', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          HoverBuilder(
            builder: (context, hovered, child) => child!,
            child: Semantics(
              container: true,
              button: true,
              label: 'Card',
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Card')),
        matchesSemantics(label: 'Card', isButton: true),
      );
      expect(
        find.descendant(
          of: find.byType(HoverBuilder),
          matching: find.byType(Semantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('us16/s8, us16/fr05/e01, BP3: inside a disabled component a '
        'pointer entering builds the idle look and calls nothing', (
      tester,
    ) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      await tester.pumpWidget(
        themedHost(_Component(disabled: true, child: _card(hovers, seen))),
      );

      await _enter(tester, await _mouse(tester));

      expect(find.text('idle'), findsOneWidget);
      expect(hovers, isEmpty);
    });

    testWidgets('us16/fr05/e02, BP3: a hovered builder whose component turns '
        'disabled reads false and calls nothing', (tester) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      final card = _card(hovers, seen);
      await tester.pumpWidget(
        themedHost(_Component(disabled: false, child: card)),
      );
      await _enter(tester, await _mouse(tester));
      expect(hovers, [true]);

      await tester.pumpWidget(
        themedHost(_Component(disabled: true, child: card)),
      );
      await tester.pump();

      expect(find.text('idle'), findsOneWidget);
      expect(seen.last, isFalse);
      expect(hovers, [true]);
    });

    testWidgets("NFR-U08: under high contrast the app's text cue for hover "
        'shows', (tester) async {
      final hovers = <bool>[];
      final seen = <bool>[];
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: defaultThemeSet,
          themeMode: ThemeMode.light,
          highContrast: StratumHighContrastMode.on,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: _card(hovers, seen)),
          ),
        ),
      );

      await _enter(tester, await _mouse(tester));

      expect(find.text('hovered'), findsOneWidget);
    });

    test('us16/fr01/e04, us16/fr01/e05, us16/fr03/e03, BP6, PD12: the '
        "dartdoc names the observer's limits and warns about touch and "
        'color-only state', () {
      final source = File(
        'lib/src/components/common/utility/hover_builder.dart',
      ).readAsStringSync();

      for (final text in [
        '(WCAG 1.4.13)',
        '(WCAG 1.4.1)',
        '`ContainerLayout(interaction:)`',
        '`MouseRegion`',
        '`Timer`',
      ]) {
        expect(source, contains(text), reason: text);
      }
    });
  });
}
