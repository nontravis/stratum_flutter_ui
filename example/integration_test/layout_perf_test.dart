// The harness measures the layouts through their src paths, because the
// gesture layouts are not exported by the layout barrel.
// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/src/src.dart';

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

/// Flings the first [Scrollable] up and down until [duration] has passed.
Future<void> flingFor(WidgetTester tester, Duration duration) async {
  final scrollable = find.byType(Scrollable).first;
  final watch = Stopwatch()..start();
  var down = true;
  while (watch.elapsed < duration) {
    await tester.fling(scrollable, Offset(0, down ? -600 : 600), 3000);
    await tester.pumpAndSettle();
    down = !down;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('harness builds an empty host', (tester) async {
    await tester.pumpWidget(perfHost(const SizedBox()));
    await binding.traceAction(
      () async => tester.pump(const Duration(milliseconds: 100)),
      reportKey: 'S0',
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
