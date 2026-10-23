import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui/src/themes/system/system_style_resolver.dart'
    show SystemStyleRoot;
import 'package:stratum_ui_test_app/fixture_app.dart';

import '../one_actionable_node.dart';

/// The pages and styles of `system_style_device_test.dart:28-95` hosted as
/// one fixture, opened by button; M3-T19 reads them through Appium.
void main() {
  testWidgets('each open button is one node with its label, role, and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester);

    for (final label in [
      'Open dark header',
      'Open white page',
      'Open dark status bar',
      'Open video',
    ]) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel(label),
        label: label,
      );
    }
    handle.dispose();
  });

  testWidgets('dark_header: the page turns the status bar icons light', (
    tester,
  ) async {
    final calls = await _open(tester);

    await tester.tap(find.text('Open dark header'));
    await tester.pumpAndSettle();

    expect(find.text('Dark header'), findsOneWidget);
    expect(_statusBarIconBrightness(calls), Brightness.light);
  });

  testWidgets('white_page: the page turns the icons dark', (tester) async {
    final calls = await _open(tester);

    await tester.tap(find.text('Open white page'));
    await tester.pumpAndSettle();

    expect(find.text('White page'), findsOneWidget);
    expect(_statusBarIconBrightness(calls), Brightness.dark);
  });

  testWidgets(
    'dark_statusbar: the page paints the bar color with light icons',
    (tester) async {
      final calls = await _open(tester);

      await tester.tap(find.text('Open dark status bar'));
      await tester.pumpAndSettle();

      expect(find.text('Dark status bar'), findsOneWidget);
      // The root paints the bar color itself, so the platform style stays
      // transparent and the strip's paint is what the screenshot reads.
      expect(SystemChrome.latestStyle?.statusBarColor, const Color(0x00000000));
      expect(_barStrips(tester), paints..rect(color: const Color(0xFF101828)));
      expect(_statusBarIconBrightness(calls), Brightness.light);
    },
  );

  testWidgets(
    'video: the page hides the bars, locks portrait, and labels the entry',
    (tester) async {
      final calls = await _open(tester);

      await tester.tap(find.text('Open video'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Video'), findsOneWidget);
      expect(
        argumentsOf(
          calls,
          'SystemChrome.setEnabledSystemUIMode',
        ).cast<String?>(),
        contains('SystemUiMode.immersiveSticky'),
      );
      expect(
        argumentsOf(calls, 'SystemChrome.setPreferredOrientations'),
        contains(
          predicate<Object?>(
            (sent) =>
                sent is List<Object?> &&
                sent.length == 1 &&
                sent.single == 'DeviceOrientation.portraitUp',
            'orientations locked to portraitUp',
          ),
        ),
      );
      expect(
        argumentsOf(
          calls,
          'SystemChrome.setApplicationSwitcherDescription',
        ).cast<Map<Object?, Object?>>().map((sent) => sent['label']),
        contains('Video'),
      );
    },
  );

  testWidgets(
    'back from video restores the app-wide edge-to-edge bars and label',
    (tester) async {
      final calls = await _open(tester);
      await tester.tap(find.text('Open video'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The OS back button, as the e2e leg presses it; the pages carry
      // no app bar.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Open dark header'), findsOneWidget);
      expect(
        argumentsOf(
          calls,
          'SystemChrome.setApplicationSwitcherDescription',
        ).cast<Map<Object?, Object?>>().map((sent) => sent['label']),
        contains('Stratum'),
      );
    },
  );
}

/// Paints the bar color strips the theme application's root holds, as the
/// `paints` matcher's subject, so the child's own draws stay out of the
/// record.
void Function(Canvas) _barStrips(WidgetTester tester) {
  final strips = find
      .descendant(
        of: find.byType(SystemStyleRoot),
        matching: find.byType(CustomPaint),
      )
      .first;
  final painter = tester.widget<CustomPaint>(strips).foregroundPainter!;
  final size = tester.getSize(strips);
  return (canvas) => painter.paint(canvas, size);
}

Brightness? _statusBarIconBrightness(List<MethodCall> calls) =>
    SystemChrome.latestStyle?.statusBarIconBrightness;

List<Object?> argumentsOf(List<MethodCall> calls, String method) => [
  for (final call in calls)
    if (call.method == method) call.arguments,
];

/// Pumps the fixture under the preloaded theme, as `main.dart` does, with
/// the platform channel recorded.
Future<List<MethodCall>> _open(WidgetTester tester) async {
  tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
  addTearDown(tester.view.reset);
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  final theme = await tester.runAsync(
    () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
  );
  addTearDown(theme!.dispose);

  await tester.pumpWidget(
    FixtureApp(fixtureId: 'themes/system_style', themeController: theme),
  );
  await tester.pumpAndSettle();
  return calls;
}
