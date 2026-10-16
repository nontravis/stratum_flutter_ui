// Drives the hover-and-focus demo with a simulated mouse and keyboard to
// prove device cases 1-5 of the interaction builders in code (FO-06 US-16,
// US-17, US-04 FR-04; F-01 US-12), so stratum-device-round can run them
// with no owner and no computer-use:
//
//   flutter test integration_test/interaction_device_test.dart -d <device>
//
// Case 5's live screen-reader speech (TalkBack, VoiceOver) still needs an
// owner-attended round with the reader switched on; this file only proves
// the semantics a reader would speak from: role, label, and group order.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/interaction_demo.dart';

import 'support/pump_until.dart';

Future<void> _pumpDemo(WidgetTester tester) async {
  final themes = await loadInteractionDemoTheme();
  await tester.pumpWidget(InteractionDemoApp(themes: themes));
  await tester.pumpAndSettle();
}

/// A mouse pointer added at the origin, then moved onto [target], scrolled
/// into view first.
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

/// Moves the already-added [mouse] onto [target], scrolled into view first.
Future<void> _moveMouseTo(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
}

// WORKAROUND: the web engine echoes a DOM focus as a deferred
// SemanticsAction.focus (Timer.run, platform_dispatcher.dart:1429-1430); a
// key sent in the same JS task lands before the echo, which pulls focus
// back. Real input never shares a task. Remove when the engine applies the
// echo before the next event or drops a stale one.
/// Pumps once, then yields a full event-loop turn, so a key sent right
/// after never lands in the same JS task as a just-queued focus echo.
Future<void> _pumpFocusMove(WidgetTester tester) async {
  await tester.pump();
  await Future<void>.delayed(Duration.zero);
}

/// Presses Tab until [target] finds a match, up to [maxTabs] times, so a
/// check for where Tab lands stays true on every platform's own count of
/// scroll-box stops. Never fails on its own: the caller's `expect` does.
Future<void> _tabUntil(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 8,
}) async {
  for (var i = 0; i < maxTabs && target.evaluate().isEmpty; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fo06/us16/s1-s3, f01/us12/s1-s2: a real mouse hovers the card and '
    'wheel-scrolling the row list under a still pointer moves hover to '
    'the row under it',
    (tester) async {
      await _pumpDemo(tester);

      final mouse = await _mouseOn(tester, find.text('Not hovered'));
      expect(find.text('Hovered'), findsOneWidget);
      expect(find.text('Log: Hover card onHover(true)'), findsOneWidget);

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(find.text('Not hovered'), findsOneWidget);
      expect(
        find.text('Log: Hover card onHover(true); Hover card onHover(false)'),
        findsOneWidget,
      );

      await mouse.moveTo(tester.getCenter(find.text('Row 1')));
      await tester.pump();
      expect(find.text('Row 1, hovered'), findsOneWidget);

      // A real wheel or trackpad scroll, not a controller jump: the still
      // pointer's own device never moves while the content under it does.
      final wheel = TestPointer(90, PointerDeviceKind.mouse);
      wheel.hover(tester.getCenter(find.text('Row 1, hovered')));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Row 1, hovered'), findsNothing);
      final movedHover = find.textContaining(', hovered');
      expect(movedHover, findsOneWidget);
      expect(
        tester.widget<Text>(movedHover).data,
        isNot('Row 1, hovered'),
        reason:
            'the wheel scroll under a still pointer must move hover to '
            'the row that comes under it, not leave it on row 1',
      );
    },
  );

  testWidgets('fo06/us17/s1-s2, fo06/us17/s5-s7, f01/us12/s3: cards built from '
      'their state show hover and press, and a focus ring after Tab but '
      'not after a click', (tester) async {
    await _pumpDemo(tester);

    final mouse = await _mouseOn(tester, find.text('Card A: Idle'));
    expect(find.text('Card A: Hovered'), findsOneWidget);

    await mouse.down(tester.getCenter(find.text('Card A: Hovered')));
    await tester.pump();
    expect(find.text('Card A: Hovered, Pressed'), findsOneWidget);

    await mouse.up();
    await tester.pump();
    expect(find.text('Card A: Hovered'), findsOneWidget);
    expect(
      find.text('Log: Card A onHover(true); Card A tapped'),
      findsOneWidget,
    );

    await _tabUntil(tester, find.text('Card A: Hovered, Focused'));
    expect(
      find.text('Card A: Hovered, Focused'),
      findsOneWidget,
      reason:
          'Tab must still ring card A even though the earlier click '
          'did not',
    );

    // A scroll that `ensureVisible` needs to reach card B (it wraps to its
    // own line on a narrow body) can hover whatever lands under the still
    // mouse before `moveTo` ever runs, so the finder here reads card B's
    // live text, not the 'Idle' it started at.
    await _moveMouseTo(tester, mouse, find.textContaining('Card B:'));
    await mouse.down(tester.getCenter(find.text('Card B: Hovered')));
    await tester.pump();
    await mouse.up();
    await tester.pump();
    expect(
      find.text('Card B: Hovered, Focused'),
      findsOneWidget,
      reason:
          'FocusType.focused rings card B on any focus, a click '
          'included',
    );
  });

  testWidgets(
    'fo06/us04/fr04/e05-e06, f01/us12/s4: a toggle disables a card under '
    'a still pointer, and re-enabling restores hover, at both the card '
    'and the section level',
    (tester) async {
      await _pumpDemo(tester);

      // The checklist's own order: press the toggle first, then move the
      // mouse onto card A and rest it there before the flip. The toggle
      // row sits far enough below the cards that bringing one into view
      // scrolls the other off screen, so the mouse is (re)positioned on
      // card A fresh after every press, never held through a scroll.
      final toggleCardA = find.text('Toggle card A in 3 s');
      final toggleSection = find.text('Toggle the section in 3 s');

      await tester.ensureVisible(toggleCardA);
      await tester.pumpAndSettle();
      await tester.tap(toggleCardA);
      final mouse = await _mouseOn(tester, find.text('Card A: Idle'));
      expect(find.text('Card A: Hovered'), findsOneWidget);

      // Waits for the log too, not only the text: the disabled flip's own
      // `onHover` report lands a postFrameCallback after the text does, so
      // a `done` that only reads the text can return one frame early.
      expect(
        await pumpUntil(
          tester,
          () =>
              find.text('Card A: Disabled').evaluate().isNotEmpty &&
              find
                  .text('Log: Card A onHover(true); Card A onHover(false)')
                  .evaluate()
                  .isNotEmpty,
          timeout: const Duration(seconds: 6),
        ),
        isTrue,
        reason:
            'card A did not disable, with its onHover(false) logged, '
            'within 6s of the toggle',
      );

      await tester.ensureVisible(toggleCardA);
      await tester.pumpAndSettle();
      await tester.tap(toggleCardA);
      await _moveMouseTo(tester, mouse, find.textContaining('Card A:'));
      expect(
        await pumpUntil(
          tester,
          () =>
              find.text('Card A: Hovered').evaluate().isNotEmpty &&
              find
                  .text(
                    'Log: Card A onHover(true); Card A onHover(false); '
                    'Card A onHover(true)',
                  )
                  .evaluate()
                  .isNotEmpty,
          timeout: const Duration(seconds: 6),
        ),
        isTrue,
        reason:
            'card A did not re-hover, with its onHover(true) logged, '
            'within 6s of re-enabling',
      );

      await tester.ensureVisible(toggleSection);
      await tester.pumpAndSettle();
      await tester.tap(toggleSection);
      await _moveMouseTo(tester, mouse, find.textContaining('Card A:'));
      expect(
        await pumpUntil(
          tester,
          () =>
              find.text('Card A: Disabled').evaluate().isNotEmpty &&
              find.text('Card B: Disabled').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 6),
        ),
        isTrue,
        reason:
            'the section toggle did not disable both cards within 6s, as '
            'a disabled component does',
      );

      await tester.ensureVisible(toggleSection);
      await tester.pumpAndSettle();
      await tester.tap(toggleSection);
      await _moveMouseTo(tester, mouse, find.textContaining('Card A:'));
      expect(
        await pumpUntil(
          tester,
          () => find.text('Card A: Hovered').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 6),
        ),
        isTrue,
        reason:
            'the section toggle did not restore card A hover within 6s '
            'of re-enabling',
      );
      expect(find.text('Card B: Disabled'), findsNothing);
    },
  );

  testWidgets(
    'fo06/us16/s4-s6, fo06/us17/s5, f01/us12/s3, f01/us12/s5: clicking '
    'into the address group reports focus in and out and adds no Tab '
    "stop of its own, and Tab still reaches card A past the page's "
    'scroll stops',
    (tester) async {
      await _pumpDemo(tester);

      final street = find.widgetWithText(TextField, 'ถนน');
      await tester.ensureVisible(street);
      await tester.pumpAndSettle();
      await tester.tap(street);
      await _pumpFocusMove(tester);
      expect(find.text('Group: focus inside'), findsOneWidget);
      expect(find.text('Log: Group onFocusChange(true)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _pumpFocusMove(tester);
      expect(
        find.text('Group: focus inside'),
        findsOneWidget,
        reason: 'Tab to the city field must change nothing in the group',
      );
      expect(find.text('Log: Group onFocusChange(true)'), findsOneWidget);

      // Native macOS binds Tab inside a text field to
      // `DoNothingAndStopPropagationTextIntent`
      // (flutter/lib/src/widgets/default_text_editing_shortcuts.dart:897-904,
      // `_macDisablingTextShortcuts`), so Tab never leaves the field here; a
      // real Mac hands that key to AppKit's key-view loop instead, which this
      // simulation has none of. Native iOS and every web target (including
      // web on macOS) carry no such binding for Tab
      // (`_iOSDisablingTextShortcuts`:943-959, `_webDisablingTextShortcuts`:
      // 828-861: neither lists `LogicalKeyboardKey.tab`), so they take this
      // step. The real Mac already proved it with live input
      // (tmp/device-round/auto-interaction-mac.results.md, 2026-10-16).
      final tabLeavesTextField =
          kIsWeb || defaultTargetPlatform != TargetPlatform.macOS;

      if (tabLeavesTextField) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await _pumpFocusMove(tester);
        expect(find.text('Group: no focus'), findsOneWidget);
        expect(
          find.text(
            'Log: Group onFocusChange(true); Group onFocusChange(false)',
          ),
          findsOneWidget,
        );

        final nextField = tester.widget<EditableText>(
          find.descendant(
            of: find.widgetWithText(TextField, 'Next field'),
            matching: find.byType(EditableText),
          ),
        );
        expect(
          nextField.focusNode.hasFocus,
          isTrue,
          reason:
              'the second Tab must leave the group in exactly two stops, '
              'landing on the field right after it, never on the group '
              'itself',
        );
      } else {
        // Tab cannot blur the field on this platform (see above); blur it
        // directly so the platform-agnostic check below still starts clean.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
      }

      // From a blurred-at-the-group state, Tab wraps the page's own
      // stops (or, on a platform whose scroll boxes are Tab stops,
      // passes them first) and reaches card A.
      await _tabUntil(tester, find.text('Card A: Focused'));
      expect(
        find.text('Card A: Focused'),
        findsOneWidget,
        reason:
            'Tab must still reach card A within 8 presses, however '
            "many scroll stops this platform's traversal gives it first",
      );
    },
  );

  testWidgets('fo06/us16/s7, fo06/us16/fr04, NFR-U06, f01/us12/s6: the address '
      "group's label precedes the street field's, each state card reads "
      'as a button with its state text, and the hover card and a row add '
      'no group stop of their own', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpDemo(tester);

    final groupFinder = find.bySemanticsLabel('ที่อยู่จัดส่ง');
    await tester.ensureVisible(groupFinder);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(groupFinder),
      isSemantics(
        label: 'ที่อยู่จัดส่ง',
        children: [
          isSemantics(label: 'Group: no focus'),
          isSemantics(label: 'ถนน', isTextField: true),
          isSemantics(label: 'เมือง', isTextField: true),
        ],
      ),
    );

    final cardA = find.text('Card A: Idle');
    await tester.ensureVisible(cardA);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(cardA),
      isSemantics(isButton: true, label: 'Card A: Idle'),
    );
    expect(
      tester.getSemantics(find.text('Card B: Idle')),
      isSemantics(isButton: true, label: 'Card B: Idle'),
    );

    final hoverCard = tester.getSemantics(find.text('Not hovered'));
    expect(hoverCard, isSemantics(label: 'Not hovered', isButton: false));
    expect(
      hoverCard.childrenCount,
      0,
      reason: 'the hover card adds no group node of its own',
    );

    final row = tester.getSemantics(find.text('Row 1'));
    expect(row, isSemantics(label: 'Row 1', isButton: false));
    expect(row.childrenCount, 0, reason: 'a row adds no group node of its own');

    handle.dispose();
  });
}
