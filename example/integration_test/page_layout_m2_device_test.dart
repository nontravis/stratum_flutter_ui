// Proves the page-layout M2 device cases code can reach:
// `docs/superpowers/specs/2026-10-10-page-layout-design.md:821-837`.
//
// Already proven, not re-derived here (`test/src/components/common/layout/modal_layout_test.dart`,
// group `showModalLayout`):
// - A drag past the closing point dismisses a sheet with null (US-20
//   Scenario 3), and a drag below half that ends short of it returns to
//   full height: `:1746-1860` (`fo06/us20/fr07/e01`, `e02`).
// - An Android API 31+ screen radius follows the sheet's bottom corners
//   (FR-04 E01): search `modal_layout_test.dart` for `fo06/us20/fr04/e01`.
// - An upward overdrag past the status bar settles `fullHeight` once, with
//   no flicker (FR-04 E03, FR-05 E02): `:692-742`.
// - Windows, Linux, and Fuchsia exclude the scrim from the semantics tree
//   (Flutter's own `ModalBarrier` behavior there), while Esc, the handle,
//   and the close button still dismiss: covered by the Esc/handle/close
//   rows throughout the same group, platform-independent since none of
//   them reads the scrim's semantics node.
// - The `ScreenRadiusScope` pass-through `MediaQuery` the R8 swap depends
//   on: `test/src/components/common/responsive/screen_radius_scope_test.dart:588-611`.
//
// New here: a bottom sheet rising at mobile width (its full width proven,
// not just its left edge) and a centered card at tablet width (its 24 px
// corner radius proven, and the dim/blur fill itself, not the
// always-present `ModalBarrier`), a desktop Esc returning focus to the
// opener, VoiceOver's named-screen-plus-silent-page-plus-Dismiss-scrim
// trio, reduced motion dropping the sheet's slide, and US-20 Scenario 4
// (the keyboard lifts the sheet) through a real soft keyboard
// (`tester.showKeyboard`) rather than the `FakeViewPadding` stand-in
// `modal_layout_test.dart:1558-1583` uses — each driven through the
// public `showModalLayout` call a device round's own app also calls,
// gated by the window size and `MediaQuery.disableAnimationsOf` the run
// reads at runtime rather than a device name.
//
// Code cannot judge:
// - VoiceOver and TalkBack's own spoken announcement: this file checks
//   the semantics tree `matchesSemantics` reads from, never audio a real
//   screen reader speaks.
// - A real on-screen keyboard on a host with no such keyboard at all
//   (desktop, web, and `-d flutter-tester`, which answers `defaultTargetPlatform`
//   as Android but has no window manager to open one): the keyboard-lift
//   test below skips there with a named reason, so it still proves the
//   lift's logical-height math only on a real Android or iOS device or
//   simulator, where `tester.showKeyboard` reaches the real OS keyboard.
//   On a real Android or iOS target it never passes silently: a bounded
//   wait with no keyboard fails, naming the view inset it saw.
//
//   flutter test integration_test/page_layout_m2_device_test.dart -d <device>
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/key_simulation.dart';
import 'support/os_major_version.dart';
import 'support/pump_until.dart';

/// A page with an `Open` button that shows [type] (null picks a sheet
/// below the tablet cut, a centered modal at and above it) and a `Page`
/// button standing in for the page behind, over a [controller]'s theme.
/// With [fieldInBody] the modal shows a focusable `TextField` instead of
/// plain text, so a real soft keyboard has something to focus.
Widget _app(
  StratumThemeController controller, {
  ModalLayoutType? type,
  bool fieldInBody = false,
}) => MaterialApp(
  builder: (context, child) => StratumThemeApplication.controlled(
    controller: controller,
    themeMode: ThemeMode.light,
    child: child!,
  ),
  home: Builder(
    builder: (context) => PageLayout(
      body: ColumnLayout(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContainerLayout(
            interaction: Interaction(
              onTap: () => showModalLayout<String>(
                context,
                type: type,
                builder: (context) => ModalLayout(
                  body: fieldInBody ? const TextField() : const Text('Body'),
                  onClose: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            semantics: const SemanticsProperties(label: 'Open'),
            child: const Text('Open'),
          ),
          ContainerLayout(
            interaction: const Interaction(onTap: _noop),
            semantics: const SemanticsProperties(label: 'Page'),
            child: const Text('Page'),
          ),
        ],
      ),
    ),
  ),
);

void _noop() {}

Future<StratumThemeController> _controller() async {
  final controller = await StratumThemeController.preload();
  return controller;
}

/// The modal's own surface box, the first `ContainerLayout` under it,
/// which carries the resolved `borderRadius` and `width` (matching the
/// finder `modal_layout_test.dart` uses for the same box).
Finder get _surface => find
    .descendant(
      of: find.byType(ModalLayout),
      matching: find.byType(ContainerLayout),
    )
    .first;

/// Every `backgroundBlur`-styled box in the tree: both the scrim's dim,
/// blurred fill behind the modal and the modal's own small close-button
/// blur carry one, so a width check below picks out the screen-wide one.
Finder get _blurredBoxes => find.byWidgetPredicate(
  (widget) => widget is ContainerLayout && widget.style?.backgroundBlur != null,
);

/// Whether one of [finder]'s matches is at least [screenWidth] wide,
/// proving a dim, blurred fill spans the screen rather than a small icon
/// blur elsewhere in the tree.
bool _hasFullWidthBlur(WidgetTester tester, Finder finder, double screenWidth) {
  return finder.evaluate().any(
    (element) =>
        (element.renderObject! as RenderBox).size.width >= screenWidth - 1,
  );
}

/// Whether this run has a real on-screen keyboard to show: Android and iOS
/// do, desktop and web never do, and `-d flutter-tester` answers Android to
/// [defaultTargetPlatform] with no window manager behind it, caught here
/// since only that fake Android run also reports a real OS version (an
/// Apple one; a real Android device reports none).
bool get _canShowSoftKeyboard {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return !kIsWeb && realOSMajorVersion == null;
    case TargetPlatform.iOS:
      return !kIsWeb;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('us20/s1: at mobile width a null type rises as a bottom sheet; '
      'us20/s2: at tablet width and above it centers as a 400 px card over a '
      'dimmed, blurred page', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(find.byType(ModalLayout));
    expect(
      sheetRect.width,
      390,
      reason:
          'a sheet below the tablet cut spans the full screen width, '
          'not just a sheet pinned at the left edge',
    );
    expect(
      _hasFullWidthBlur(tester, _blurredBoxes, 390),
      isTrue,
      reason: 'the dimmed, blurred page sits behind the sheet',
    );

    await sendKey(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(900, 1200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byType(ModalLayout));
    expect(cardRect.width, 400);
    expect(
      tester.widget<ContainerLayout>(_surface).style?.borderRadius,
      const BorderRadius.all(Radius.circular(24)),
      reason:
          'a centered modal card takes the theme\'s 24 px `card-large` '
          'corner radius',
    );
    expect(
      _hasFullWidthBlur(tester, _blurredBoxes, 900),
      isTrue,
      reason:
          'the dimmed, blurred page sits behind the centered card, '
          'never just the modal\'s own small close-button blur',
    );
  });

  testWidgets(
    'us20/s6: on desktop Esc closes the modal and focus returns to the '
    'opener',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(controller));
      final opener = find.text('Open');
      Focus.of(tester.element(opener)).requestFocus();
      await tester.pump();
      await tester.tap(opener);
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsOneWidget);

      await sendKey(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ModalLayout), findsNothing);
      expect(
        Focus.of(tester.element(opener)).hasFocus,
        isTrue,
        reason: 'Esc hands focus back to the control that opened the modal',
      );
    },
  );

  testWidgets(
    'co05/us20/fr02: the route reads as a named screen, the page behind it '
    'is silent, and the scrim reads Dismiss',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await _controller();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(controller));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Page'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sheet')),
        matchesSemantics(label: 'Sheet', scopesRoute: true, namesRoute: true),
        reason:
            'with no explicit label, a sheet route names itself with '
            "the built-in sheet label",
      );
      expect(
        find.bySemanticsLabel('Dismiss'),
        findsWidgets,
        reason: 'the scrim barrier and the sheet handle both read Dismiss',
      );
      semantics.dispose();
    },
  );

  testWidgets('us20/s7: reduced motion fades the sheet in with no slide', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(controller),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final partway = tester.getRect(find.byType(ModalLayout)).top;
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byType(ModalLayout)).top;
    expect(
      partway,
      settled,
      reason:
          'a slide would move the top edge frame by frame; a fade '
          'leaves it at its resting position throughout',
    );
  });

  testWidgets(
    'us20/s4: fo06/us20/fr05/e04: a real soft keyboard lifts the sheet by '
    'its height',
    (tester) async {
      if (!_canShowSoftKeyboard) {
        markTestSkipped(
          'a soft keyboard does not apply on '
          '${kIsWeb ? 'web' : defaultTargetPlatform.name}',
        );
        return;
      }
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(controller, type: ModalLayoutType.bottomSheet, fieldInBody: true),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(ModalLayout));

      await tester.showKeyboard(find.byType(TextField));
      // Read at the root `Navigator`, not `ModalLayout`: smooth_sheets'
      // `SheetMediaQuery` subtracts the sheet's own padding from the inset
      // it republishes to descendants (smooth_sheets 1.3.0 viewport.dart
      // :155-158), so a `ModalLayout`-context read always sees 0 once the
      // sheet has lifted. `_SheetContent` reads the un-subtracted value at
      // the `Navigator`, which is what the lift itself used.
      double insetLogical() =>
          MediaQuery.viewInsetsOf(tester.element(find.byType(Navigator).first))
              .bottom;
      final opened = await pumpUntil(
        tester,
        () => insetLogical() > 0,
        timeout: const Duration(seconds: 10),
      );
      await tester.pumpAndSettle();

      if (!opened) {
        final diagnostics = {
          'viewInsetsBottom': tester.view.viewInsets.bottom,
          'devicePixelRatio': tester.view.devicePixelRatio,
          'hasFocus':
              tester.binding.focusManager.primaryFocus?.hasFocus ?? false,
          'platform': defaultTargetPlatform.name,
        };
        // ignore: avoid_print
        print('KEYBOARD_DIAG ${jsonEncode(diagnostics)}');
        fail(
          'soft keyboard did not show: '
          'viewInsets.bottom=${tester.view.viewInsets.bottom}, '
          '${defaultTargetPlatform.name}',
        );
      }

      final lifted = tester.getRect(find.byType(ModalLayout));
      expect(
        lifted.bottom,
        closeTo(before.bottom - insetLogical(), 1),
        reason:
            'a real soft keyboard focus lifts the sheet clear of it by '
            "its logical height, not the FakeViewPadding stand-in a "
            'widget test uses',
      );
    },
  );
}
