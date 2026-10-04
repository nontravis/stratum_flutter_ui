// The harness imports the src barrel, which also exports the theme types
// the fake theme implements.
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// Length of every traced window. Two seconds fit the timeline recorder's
/// buffer at 144 Hz; a longer trace loses its first frames.
const traceWindow = Duration(seconds: 2);

/// Timeline streams that carry the `Frame` (Dart) and `GPURasterizer::Draw`
/// (Embedder) events. The default `all` adds the API stream, whose events
/// fill the recorder's buffer and push the traced frames out of it.
const perfStreams = ['Dart', 'Embedder', 'GC'];

/// Untraced time between pumping a scene and tracing it, so the first
/// build and the previous scene's teardown stay out of the window.
const settleTime = Duration(milliseconds: 250);

late StratumThemeSet _themes;

/// Reads the package default theme for [perfHost] and turns Google Fonts
/// runtime fetching off, so every run draws the theme's Google fonts from
/// the files under `assets/google_fonts/` and no run waits on the network;
/// call it in `setUpAll`.
Future<void> loadPerfTheme() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final text = await rootBundle.loadString(
    'packages/stratum_ui/assets/themes/default/theme.yaml',
  );
  _themes = StratumThemeSet.fromConfig(
    StratumThemeConfig.parse(
      base: StratumThemeSource(
        id: 'stratum-default',
        folder: 'packages/stratum_ui/assets/themes/default',
        yaml: text,
      ),
    ),
  );
}

/// Places a scene in a [MaterialApp] (a real [Theme] platform) under a
/// [StratumThemeApplication] of the package default theme.
Widget perfHost(Widget child) {
  return MaterialApp(
    home: StratumThemeApplication(
      themes: _themes,
      themeMode: ThemeMode.light,
      child: Scaffold(body: child),
    ),
  );
}

/// Scrolls the first [Scrollable] down for half of [duration] and back up
/// for the other half at a constant speed, so every traced frame is a
/// scroll frame and every run scrolls the same way.
Future<void> scrollFor(
  WidgetTester tester,
  Duration duration, {
  double distance = 4000,
}) async {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  expect(position.maxScrollExtent, greaterThanOrEqualTo(distance));
  final half = duration ~/ 2;
  await position.animateTo(distance, duration: half, curve: Curves.linear);
  await position.animateTo(0, duration: half, curve: Curves.linear);
}
