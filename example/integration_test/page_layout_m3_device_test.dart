// Proves the page-layout M3 device cases code can reach:
// `docs/superpowers/specs/2026-10-10-page-layout-design.md:839-857`.
//
// Already proven, not re-derived here (`test/src/components/common/layout/page_drawer_test.dart`):
// - An Android edge swipe opens the start drawer, and off the start edge
//   opens the end one (US-19 Scenario 2, FR-03): `:454-476`.
// - On iOS the start-edge back swipe of a pushed page goes back instead of
//   opening the drawer (Scenario 3): `:489-515`.
// - Android back closes an open drawer first, before the route pops
//   (Scenario 9): `:560-590`.
// - A drawer opened while loading takes focus once loading ends, and Esc
//   returns it to the opener (R19): `:592` onward.
// - The right overlay drawer is 450 wide at big-desktop and 400 below it
//   (US-19 Scenarios 4, 5): `:1424-1513`.
// - A divider resizes by drag, by arrow keys, and by Home/End, and reads
//   as a slider with a percent value (R17, US-19 FR-06, US-21 Scenarios
//   1-4): `:1901-2092`, `:2332-2363`.
// - Reduced motion drops the drawer's slide to a fade (Scenario 6), and
//   RTL opens the start drawer from the right and moves its divider left
//   on the left arrow (Scenarios 5, 7): `:716`, `:971`, `:1502`, `:2047`,
//   `:2239`.
// - US-18 Scenario 3 (the header fill runs under the status bar and a
//   body list scrolls under the home indicator), Scenario 4 (the keyboard
//   shrinks the body and lifts `bottom`), and R20 (with no header, the
//   left and right slots pad the status bar themselves): proven with
//   faked `MediaQuery` padding and view insets, not a real device, in
//   `test/src/components/common/layout/page_layout_test.dart:341-699`
//   (search `fo06/us18/s3`, `fo06/us18/s4`, and the `R20` rows).
//
// New here: the menu button opening the drawer at its real 80%-up-to-360
// width over the real dimmed, blurred page (not the always-present
// `ModalBarrier` alone), VoiceOver's named-screen-plus-silent-page pair,
// and RTL opening the start drawer from the right, each driven through a
// real `PageLayout` inside a real `MaterialApp`, which is the one seam
// the component-level tests above never assemble.
//
// Code cannot judge:
// - VoiceOver and TalkBack's own spoken announcement: this file checks
//   the semantics tree a screen reader speaks from, never the audio.
//
//   flutter test integration_test/page_layout_m3_device_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

/// A page with a `Menu` button in its header that opens the start drawer,
/// a labeled `left` slot, and a `Page` body standing in for the page
/// behind it.
Widget _app(StratumThemeController controller, {TextDirection? direction}) =>
    MaterialApp(
      builder: (context, child) => Directionality(
        textDirection: direction ?? TextDirection.ltr,
        child: StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: child!,
        ),
      ),
      home: Builder(
        builder: (context) => PageLayout(
          header: Builder(
            builder: (context) => ContainerLayout(
              interaction: Interaction(
                onTap: () => PageLayout.of(context).openLeft(),
              ),
              semantics: const SemanticsProperties(label: 'Menu'),
              child: const Text('Menu'),
            ),
          ),
          left: const Text('Drawer'),
          body: const Text('Page'),
        ),
      ),
    );

Future<StratumThemeController> _controller() =>
    StratumThemeController.preload();

/// Every `backgroundBlur`-styled box in the tree: the drawer's `Scrim`
/// dim/blur fill behind it carries one; a width check below distinguishes
/// it from any other such box.
Finder get _blurredBoxes => find.byWidgetPredicate(
  (widget) => widget is ContainerLayout && widget.style?.backgroundBlur != null,
);

/// Whether one of [finder]'s matches is at least [screenWidth] wide,
/// proving a dim, blurred fill spans the screen.
bool _hasFullWidthBlur(WidgetTester tester, Finder finder, double screenWidth) {
  return finder.evaluate().any(
    (element) =>
        (element.renderObject! as RenderBox).size.width >= screenWidth - 1,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'us19/s1: the menu button opens the start drawer at 80% of the screen '
    'width, up to 360, over a dimmed, blurred page',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(controller));
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Drawer'), findsOneWidget);
      expect(
        tester.getRect(find.text('Drawer')).width,
        closeTo(312, 1),
        reason: '80% of a 390-wide screen is 312, below the 360 cap',
      );
      expect(
        _hasFullWidthBlur(tester, _blurredBoxes, 390),
        isTrue,
        reason: 'the dimmed, blurred page sits behind the drawer',
      );
    },
  );

  testWidgets('us19/s8: an open drawer reads as a named screen with the page '
      'behind it silent', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = await _controller();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Menu'),
      findsNothing,
      reason:
          'the page behind the open drawer, including the control '
          'that opened it, reads as hidden',
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Navigation menu')),
      matchesSemantics(
        label: 'Navigation menu',
        scopesRoute: true,
        namesRoute: true,
      ),
      reason:
          'with no side label, the drawer names itself with the '
          "built-in drawer label",
    );
    semantics.dispose();
  });

  testWidgets(
    'us19/s7: in RTL the start drawer opens from the screen\'s right edge',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(controller, direction: TextDirection.rtl));
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('Drawer')).right,
        closeTo(390, 1),
        reason:
            'the start side sits at the screen\'s end in RTL, the '
            'right edge',
      );
    },
  );
}
