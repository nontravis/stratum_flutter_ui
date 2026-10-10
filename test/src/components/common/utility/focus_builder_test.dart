@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// Build Gate rows of FocusBuilder (US-16 Accessibility and UX):
// NFR-U01, NFR-U07 n/a: no paint of its own and no focus ring.
// NFR-U02 n/a: an observer takes no focus and adds no Tab stop (FR-03); the
//   wrapped widgets keep their own Tab order and focused looks.
// NFR-U03 n/a: it runs no animation and paints nothing.
// NFR-U04 n/a: no text of its own and no footprint of its own.
// NFR-U05 n/a: not interactive; the wrapped widgets keep their own targets.
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

FocusNode _node(String label) {
  final node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

/// [child] under a [MaterialApp], which a [TextField] needs, with the test
/// theme.
Widget _app(Widget child) =>
    MaterialApp(home: Material(child: themedHost(child)));

/// The delivery address group: a focus builder around a street and a city
/// field, whose look reads 'group focused' or 'group idle'.
Widget _addressGroup({
  required FocusNode street,
  required FocusNode city,
  List<bool>? changes,
  List<bool>? seen,
}) => FocusBuilder(
  onFocusChange: changes?.add,
  builder: (context, focused, child) {
    seen?.add(focused);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text(focused ? 'group focused' : 'group idle'), child!],
    );
  },
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 200, child: TextField(focusNode: street)),
      SizedBox(width: 200, child: TextField(focusNode: city)),
    ],
  ),
);

void main() {
  group('FocusBuilder', () {
    testWidgets('us16/s4, us16/fr02, us16/fr02/e02, BP2: a tap on a field '
        'inside builds the focused look and calls onFocusChange(true)', (
      tester,
    ) async {
      final changes = <bool>[];
      final street = _node('street');
      await tester.pumpWidget(
        _app(
          _addressGroup(street: street, city: _node('city'), changes: changes),
        ),
      );
      expect(find.text('group idle'), findsOneWidget);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      expect(street.hasPrimaryFocus, isTrue);
      expect(find.text('group focused'), findsOneWidget);
      expect(changes, [true]);
    });

    testWidgets('us16/s5, us16/fr02/e01: Tab from the street field to the '
        'city field keeps the look and calls nothing', (tester) async {
      final changes = <bool>[];
      final seen = <bool>[];
      final city = _node('city');
      await tester.pumpWidget(
        _app(
          _addressGroup(
            street: _node('street'),
            city: city,
            changes: changes,
            seen: seen,
          ),
        ),
      );
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      final calls = seen.length;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(city.hasPrimaryFocus, isTrue);
      expect(find.text('group focused'), findsOneWidget);
      expect(seen, hasLength(calls));
      expect(changes, [true]);
    });

    testWidgets('us16/fr02: focus leaving the group builds the idle look and '
        'calls onFocusChange(false)', (tester) async {
      final changes = <bool>[];
      final outside = _node('outside');
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _addressGroup(
                street: _node('street'),
                city: _node('city'),
                changes: changes,
              ),
              SizedBox(width: 200, child: TextField(focusNode: outside)),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      outside.requestFocus();
      await tester.pump();

      expect(find.text('group idle'), findsOneWidget);
      expect(changes, [true, false]);
    });

    testWidgets('us16/fr02, PD4: the builder and onFocusChange see the new '
        'value in the same frame', (tester) async {
      final changes = <bool>[];
      final seen = <bool>[];
      final street = _node('street');
      await tester.pumpWidget(
        _app(
          _addressGroup(
            street: street,
            city: _node('city'),
            changes: changes,
            seen: seen,
          ),
        ),
      );

      street.requestFocus();
      await tester.pump();

      expect(changes, [true]);
      expect(seen.last, isTrue);
    });

    testWidgets('us16/fr03, D1: taps and the cursor reach the widget a focus '
        'builder wraps, and its footprint stays the same', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        themedHost(
          FocusBuilder(
            builder: (context, focused, child) => child!,
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
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();

      await mouse.moveTo(tester.getCenter(find.byType(FocusBuilder)));
      await tester.pump();
      await tester.tap(find.byType(FocusBuilder));

      expect(tester.getSize(find.byType(FocusBuilder)), const Size(40, 40));
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
      expect(taps, 1);
    });

    testWidgets('us16/s6, us16/fr03/e01, us16/fr03, D1: Tab lands straight in '
        'a wrapped text field, with no stop and no ring on the wrapper', (
      tester,
    ) async {
      final before = _node('before');
      final field = _node('field');
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 200, child: TextField(focusNode: before)),
              FocusBuilder(
                builder: (context, focused, child) => child!,
                child: SizedBox(width: 200, child: TextField(focusNode: field)),
              ),
            ],
          ),
        ),
      );
      before.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(field.hasPrimaryFocus, isTrue);
      expect(find.byType(StratumFocusBorder), findsNothing);
    });

    testWidgets('us16/fr02/e03: a subtree with no node that takes focus '
        'stays unfocused', (tester) async {
      final seen = <bool>[];
      final outside = _node('outside');
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FocusBuilder(
                builder: (context, focused, child) {
                  seen.add(focused);
                  return const Text('label');
                },
              ),
              SizedBox(width: 200, child: TextField(focusNode: outside)),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(outside.hasPrimaryFocus, isTrue);
      expect(seen, everyElement(isFalse));
    });

    testWidgets('us16/fr02/e04, BP1: child reaches builder as the same '
        'widget on every call and does not rebuild', (tester) async {
      var childBuilds = 0;
      final inner = _node('inner');
      final counted = _Counted(
        onBuild: () => childBuilds++,
        child: Focus(
          focusNode: inner,
          child: const SizedBox(width: 40, height: 20),
        ),
      );
      final received = <Widget?>[];
      await tester.pumpWidget(
        themedHost(
          FocusBuilder(
            builder: (context, focused, child) {
              received.add(child);
              return child!;
            },
            child: counted,
          ),
        ),
      );

      inner.requestFocus();
      await tester.pump();
      // The focus change lands in a microtask (FocusManager
      // .applyFocusChangesIfNeeded), which the preceding bare pump() checked
      // for a frame before flushing; one more pump drains it. The first bare
      // requestFocus() has the same gap when no frame is already scheduled.
      await tester.pump();
      inner.unfocus();
      await tester.pump();
      await tester.pump();

      expect(received, hasLength(3));
      expect(received, everyElement(same(counted)));
      expect(childBuilds, 1);
    });

    testWidgets('us16/fr02: removing a focused builder calls no listener and '
        'throws nothing', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          _addressGroup(
            street: _node('street'),
            city: _node('city'),
            changes: changes,
          ),
        ),
      );
      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(changes, [true]);
    });

    testWidgets('us16/s7, us16/fr04/e01, NFR-U06: the group label reads '
        'before its street field', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          FocusBuilder(
            semantics: const SemanticsProperties(label: 'ที่อยู่จัดส่ง'),
            builder: (context, focused, child) => child!,
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

    testWidgets('us16/fr04/e02, PD6, NFR-U06: null semantics adds no node; '
        'the wrapped node reads unchanged', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          FocusBuilder(
            builder: (context, focused, child) => child!,
            child: Semantics(
              container: true,
              textField: true,
              label: 'Field',
              child: const SizedBox(width: 80, height: 20),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Field')),
        matchesSemantics(label: 'Field', isTextField: true),
      );
      expect(
        find.descendant(
          of: find.byType(FocusBuilder),
          matching: find.byType(Semantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('us16/fr05/e03, BP3: a focused field whose component turns '
        'disabled loses focus, reads false, and calls nothing', (tester) async {
      final changes = <bool>[];
      final street = _node('street');
      final group = _addressGroup(
        street: street,
        city: _node('city'),
        changes: changes,
      );
      await tester.pumpWidget(_app(_Component(disabled: false, child: group)));
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(changes, [true]);

      await tester.pumpWidget(_app(_Component(disabled: true, child: group)));
      await tester.pump();

      expect(street.hasFocus, isFalse);
      expect(find.text('group idle'), findsOneWidget);
      expect(changes, [true]);
    });

    testWidgets("NFR-U08: under high contrast the app's text cue for focus "
        'shows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StratumThemeApplication(
              themes: defaultThemeSet,
              themeMode: ThemeMode.light,
              highContrast: StratumHighContrastMode.on,
              child: Center(
                child: _addressGroup(
                  street: _node('street'),
                  city: _node('city'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      expect(find.text('group focused'), findsOneWidget);
    });

    test('us16/fr02, us16/fr03/e03, BP6, PD12: the dartdoc names the '
        "observer's limits and warns against color-only state", () {
      final source = File(
        'lib/src/components/common/utility/focus_builder.dart',
      ).readAsStringSync();

      for (final text in [
        '(WCAG 1.4.1)',
        '`ContainerLayout(interaction:)`',
        '`InteractionState.focused`',
      ]) {
        expect(source, contains(text), reason: text);
      }
    });
  });
}
