// Proves the page-layout M5 device cases code can reach:
// `docs/superpowers/specs/2026-10-10-page-layout-design.md:890-897`.
//
// Already proven, not re-derived here (`test/src/application/stratum_application_test.dart`):
// - The app starts in its active theme (Scenario 1), a notice shows from
//   any screen with no host of its own (Scenario 2), a `CupertinoApp`
//   gets the same layers (Scenario 3), and the app keeps its own
//   locale under the theme's language (Scenario 4): `:140-183, 315-352,
//   665-688`.
// - `MaterialApp.router` renders a pushed page under the same layers,
//   with the navigator's `State` kept across a theme rebuild: `:1164-1230`.
// - A `required` update-gate answer hides a shown notice (US-13 FR-04
//   E03): `:814-861`; the gate's own blocking of every route lives in
//   `test/src/components/feedback/update_gate/update_gate_test.dart`.
// - `systemStyle` sets the bar icons app-wide: `:688-706`, and on real
//   Android and iOS targets, `example/integration_test/system_style_device_test.dart`.
//
// New here: the project's own router, `go_router` (the one `example/`
// actually ships, per `example/pubspec.yaml`), wrapped in
// `StratumApplication` rather than the hand-rolled delegate the cited
// unit tests use, since no existing test builds that exact combination.
//
// Code cannot judge:
// - A real two-finger pinch on a touchscreen or trackpad (US-13 Scenario
//   6, web with no `webZoom`): `flutter_test` sends pointer events, never
//   a platform's own gesture recognizer output, and no browser automation
//   tool is driven from this file.
//
//   flutter test integration_test/page_layout_m5_device_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'us13/fr02: StratumApplication starts in its theme, shows a notice '
    'from a routed page, and keeps go_router navigation working',
    (tester) async {
      final controller = await StratumThemeController.preload();
      addTearDown(controller.dispose);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Builder(
              builder: (context) => Scaffold(
                body: ContainerLayout(
                  interaction: Interaction(onTap: () => context.go('/second')),
                  semantics: const SemanticsProperties(label: 'Go'),
                  child: const Text('Home'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/second',
            builder: (context, state) => Builder(
              builder: (context) => Scaffold(
                body: ContainerLayout(
                  interaction: Interaction(
                    onTap: () =>
                        context.showToast(message: 'From the second page'),
                  ),
                  semantics: const SemanticsProperties(label: 'Notify'),
                  child: const Text('Second'),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        StratumApplication(
          controller: controller,
          themeMode: ThemeMode.light,
          appBuilder: (context, config) => MaterialApp.router(
            routerConfig: router,
            builder: config.builder,
            theme: config.theme,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Home'))).brightness,
        Brightness.light,
        reason:
            'the app starts already in the active theme, before any '
            'navigation',
      );

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('From the second page'), findsOneWidget);
    },
  );
}
