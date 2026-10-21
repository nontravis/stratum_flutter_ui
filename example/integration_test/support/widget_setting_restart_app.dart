import 'package:stratum_ui/stratum_ui.dart';

/// The left pane's width before any resize, fixed by the test window's
/// pinned desktop size (FR-02: the Figma desktop default, 1600 px under
/// `bigDesktop`).
const double widgetSettingRestartDefaultLeftWidth = 260;

/// The width the cold-restart case sets and expects back (US-01 Scenario 2).
const double widgetSettingRestartStoredLeftWidth = 400;

/// The app tree both cold-restart case files pump: a splash over one
/// `PageLayout` with a left pane remembered under one global setting key,
/// over the default store (`StratumSharedPreferencesSettingStore`, the real
/// plugin, since the splash passes no `widgetSettings` of its own). [state]
/// hears every splash state, as the merged M13 case's own app does;
/// [controller] is the app's own `PageLayoutController`, read and set from
/// code, never by key or pointer, so a profile-mode Android run can drive
/// it too. [onLeftPaneLayout] hears the left pane's width at every layout,
/// the first one included, so a case can prove no frame drew another width.
Widget widgetSettingRestartApp({
  required PageLayoutController controller,
  required Key leftPaneKey,
  required ValueChanged<StratumSplashState<void>> onState,
  ValueChanged<double>? onLeftPaneLayout,
}) => StratumSplashScreen<void>(
  postload: (context, controller) async {},
  builder: (context, state) {
    onState(state);
    if (state is StratumSplashDone<void>) {
      return MaterialApp(
        builder: (context, child) => StratumThemeApplication.controlled(
          controller: state.controller,
          themeMode: ThemeMode.light,
          child: child!,
        ),
        home: Scaffold(
          body: PageLayout(
            setting: const WidgetSettingKey.global(),
            controller: controller,
            left: LayoutBuilder(
              builder: (context, constraints) {
                onLeftPaneLayout?.call(constraints.maxWidth);
                return ColoredBox(
                  key: leftPaneKey,
                  color: const Color(0xFFE0E0E0),
                );
              },
            ),
          ),
        ),
      );
    }
    return const ColoredBox(color: Color(0xFF2050C0));
  },
);
