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

class _PerfTransparent extends Fake implements TransparentColors {
  @override
  Color get t0 => const Color(0x00000000);
}

class _PerfColors extends Fake implements BaseThemeColor {
  @override
  Color get overlayHover => const Color(0x11000000);

  @override
  Color get overlayActive => const Color(0x22000000);

  @override
  Color get borderBrand => const Color(0xFF0000FF);

  @override
  TransparentColors get transparent => _PerfTransparent();
}

/// Answers only what the measured widgets read.
class _PerfTheme extends Fake implements StratumThemeData {
  @override
  final BaseThemeColor color = _PerfColors();

  @override
  ScrollBehavior get scrollBehavior => const StratumScrollBehavior();

  @override
  ScrollPhysics get physics => const ClampingScrollPhysics();
}

final _theme = _PerfTheme();

/// Places a scene in a [MaterialApp] (a real [Theme] platform) under a
/// [StratumThemeApplication].
Widget perfHost(Widget child) {
  return MaterialApp(
    home: StratumThemeApplication(
      themeMode: ThemeMode.light,
      lightTheme: _theme,
      darkTheme: null,
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
