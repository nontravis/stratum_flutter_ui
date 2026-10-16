// Proves the page-layout M4 device cases code can reach:
// `docs/superpowers/specs/2026-10-10-page-layout-design.md:871-888`.
//
// Already proven, not re-derived here:
// - A solid top notice runs under the status bar (Scenario 3), a bottom
//   one rides above the open keyboard (Scenario 14), and a float curves
//   with the screen radius (`fo06/us01/fr02/e02`):
//   `test/src/components/feedback/toast/toast_test.dart:81-134,1864`.
// - VoiceOver and TalkBack announce the kind name then the message in
//   English (Scenario 9) and Thai (Scenario 10), and a notice with an
//   action stays until acted on (Scenario 8): same file, `:296-477`.
// - Hover pauses a float (Scenario 7), a swipe closes one (Scenario 13),
//   and reduced motion fades it (Scenario 18): same file, `:244-299,
//   634-804`.
// - The default shortcut (F8, or Option+T on macOS and iOS) reaches the
//   notice from a focused text field and types nothing into it, and Esc
//   returns focus with the field's text intact: same file,
//   `:1053-1089`, plus the macOS-ordered variant at `:1196-1230` (grep
//   `co05_07/us01/fr05/e13`).
// - A desktop float stays inside the body beside a left pane (Scenario
//   15), and on mobile and tablet a bottom float rises above the footer
//   or tab bar (R26): `test/src/components/feedback/toast/toast_page_test.dart:106-226`.
// - A dark solid top notice over a light page flips the status bar icons
//   light: `test/src/components/common/layout/page_layout_system_style_test.dart`
//   (search `fo06/us18/fr07`).
//
// New here: the same F8/Option+T shortcut reaching a notice through the
// full `StratumApplication` wrapper (theme runtime, notice host, and
// webZoom layered together) rather than a bare `StratumToastHost`, the
// one assembly the cited unit tests never build.
//
// Code cannot judge:
// - VoiceOver and TalkBack's own spoken announcement: every cited test,
//   and this one, checks the semantics tree a screen reader speaks from,
//   never the audio.
//
//   flutter test integration_test/page_layout_m4_device_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

bool get _appleShortcut =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'us01/fr05: the notice shortcut reaches a notice through the full '
    'StratumApplication wrapper and types nothing into a focused text '
    'field',
    (tester) async {
      final controller = await StratumThemeController.preload();
      addTearDown(controller.dispose);
      final field = FocusNode(debugLabel: 'field');
      addTearDown(field.dispose);
      final fieldText = TextEditingController();
      addTearDown(fieldText.dispose);
      await tester.pumpWidget(
        StratumApplication(
          controller: controller,
          themeMode: ThemeMode.light,
          appBuilder: (context, config) => MaterialApp(
            builder: config.builder,
            theme: config.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ColumnLayout(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(focusNode: field, controller: fieldText),
                    ContainerLayout(
                      interaction: Interaction(
                        onTap: () =>
                            context.showToast(message: 'From the real app'),
                      ),
                      semantics: const SemanticsProperties(label: 'Notify'),
                      child: const Text('Notify'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Notify'));
      await tester.pumpAndSettle();
      field.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();

      if (_appleShortcut) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
      }
      await tester.pumpAndSettle();

      expect(
        fieldText.text,
        'hi',
        reason:
            'the shortcut moves focus to the notice, never a keystroke '
            'into the field it left',
      );
      expect(FocusManager.instance.primaryFocus, isNot(field));
    },
  );
}
