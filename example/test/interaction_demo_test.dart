import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/interaction_demo.dart';

Future<void> _pumpDemo(WidgetTester tester) async {
  final themes = await tester.runAsync(loadInteractionDemoTheme);
  await tester.pumpWidget(InteractionDemoApp(themes: themes!));
  await tester.pumpAndSettle();
}

/// A mouse moved onto [target], scrolled into view first.
Future<TestGesture> _mouseOn(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
  return mouse;
}

void main() {
  testWidgets('us12/fr01, us12/fr01/e01, us12/fr01/e04: loads the default '
      'theme and shows the four checks, each opening with its steps', (
    tester,
  ) async {
    await _pumpDemo(tester);

    for (final opening in [
      '1. Hover. Move the mouse onto the card',
      '2. Cards built from their state. Hover, press and hold',
      '3. Disabled under a still mouse. Press a button below',
      '4. Focus inside a group. Click the street field',
    ]) {
      expect(find.textContaining(opening), findsOneWidget, reason: opening);
    }
    expect(find.text('Hover and focus demo'), findsOneWidget);
    expect(find.text('Not hovered'), findsOneWidget);
    expect(find.text('Card A: Idle'), findsOneWidget);
    expect(find.text('Card B: Idle'), findsOneWidget);
    expect(find.text('Toggle card A in 3 s'), findsOneWidget);
    expect(find.text('Group: no focus'), findsOneWidget);
    expect(find.text('Log: nothing yet.'), findsOneWidget);
  });

  testWidgets('us12/s1: the hover card reads Hovered, then Not hovered, and '
      'logs one hover on and one hover off', (tester) async {
    await _pumpDemo(tester);
    final mouse = await _mouseOn(tester, find.text('Not hovered'));
    expect(find.text('Hovered'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();

    expect(find.text('Not hovered'), findsOneWidget);
    expect(
      find.text('Log: Hover card onHover(true); Hover card onHover(false)'),
      findsOneWidget,
    );
  });

  testWidgets('us12/s2: the row list scrolling under a still mouse moves '
      'hover to the next row', (tester) async {
    await _pumpDemo(tester);
    await _mouseOn(tester, find.text('Row 1'));
    expect(find.text('Row 1, hovered'), findsOneWidget);

    // The nearest scrollable above the row is the row list's own.
    tester
        .state<ScrollableState>(
          find
              .ancestor(
                of: find.text('Row 1, hovered'),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(40);
    await tester.pump();
    await tester.pump();

    expect(find.text('Row 1, hovered'), findsNothing);
    expect(find.text('Row 2, hovered'), findsOneWidget);
  });

  testWidgets('us12/s3: Tab to card A reads Focused', (tester) async {
    await _pumpDemo(tester);

    // Tests run as Android, where a scrolling box is no Tab stop; on web and
    // desktop Tab passes the page's scroll stops first (device case 4).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.text('Card A: Focused'), findsOneWidget);
  });

  testWidgets('us12/s4, us12/fr01/e03: a toggle disables card A under a '
      'still pointer and logs one hover off, then one hover on', (
    tester,
  ) async {
    await _pumpDemo(tester);
    await _mouseOn(tester, find.text('Card A: Idle'));
    expect(find.text('Card A: Hovered'), findsOneWidget);

    await tester.tap(find.text('Toggle card A in 3 s'));
    await tester.pump(toggleDelay);
    await tester.pump();
    expect(find.text('Card A: Disabled'), findsOneWidget);

    await tester.tap(find.text('Toggle card A in 3 s'));
    await tester.pump(toggleDelay);
    await tester.pump();

    expect(find.text('Card A: Hovered'), findsOneWidget);
    expect(
      find.text(
        'Log: Card A onHover(true); Card A onHover(false); '
        'Card A onHover(true)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('us12/s5: a click on the street field reads focus inside and '
      'logs one focus in', (tester) async {
    await _pumpDemo(tester);
    final street = find.widgetWithText(TextField, 'ถนน');
    await tester.ensureVisible(street);
    await tester.pumpAndSettle();

    await tester.tap(street);
    await tester.pump();

    expect(find.text('Group: focus inside'), findsOneWidget);
    expect(find.text('Log: Group onFocusChange(true)'), findsOneWidget);
  });

  testWidgets('us12/s6: the address group carries its screen-reader label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpDemo(tester);

    expect(find.bySemanticsLabel('ที่อยู่จัดส่ง'), findsOneWidget);
    handle.dispose();
  });

  test('us12/fr01/e02: every state reads as text', () {
    expect(stateText('Card A', const InteractionState()), 'Card A: Idle');
    expect(
      stateText(
        'Card A',
        const InteractionState(hovered: true, focused: true, pressed: true),
      ),
      'Card A: Hovered, Pressed, Focused',
    );
    expect(
      stateText('Card A', const InteractionState(disabled: true)),
      'Card A: Disabled',
    );
  });
}
