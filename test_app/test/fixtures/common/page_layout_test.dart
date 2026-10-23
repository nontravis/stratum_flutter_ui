import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_test_app/fixtures/common/page_layout.dart';

import '../one_actionable_node.dart';

/// The storage key of the left pane width: the device box, namespace
/// `stratum.page_layout`, global part, value `left_width`.
const _storedLeftWidthKey = 'stratum/d/stratum.page_layout/g/left_width';

/// Pins the desktop window the default 260 px left width is defined for.
void _pinDesktopWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<StratumThemeController> _preloadTheme(WidgetTester tester) async {
  // The theme preload reads assets, which needs real time, not fake async.
  final controller = await tester.runAsync(
    () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
  );
  addTearDown(controller!.dispose);
  return controller;
}

/// Opens the fixture over [store], standing in for the device's own store.
Future<void> _open(
  WidgetTester tester, {
  required StratumMemorySettingStore store,
}) async {
  _pinDesktopWindow(tester);
  final theme = await _preloadTheme(tester);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => StratumThemeApplication.controlled(
        controller: theme,
        themeMode: ThemeMode.light,
        child: child!,
      ),
      home: Scaffold(body: PageLayoutFixture(store: store)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

void main() {
  testWidgets('each control is one node with its label, role, and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, store: StratumMemorySettingStore());

    for (final label in ['Set left width to 300', 'Reset settings']) {
      expectOneActionableNode(
        tester,
        find.bySemanticsLabel(label),
        label: label,
      );
    }
    handle.dispose();
  });

  testWidgets('a fresh pump shows the default width on the first frame', (
    tester,
  ) async {
    await _open(tester, store: StratumMemorySettingStore());

    expect(find.text('first frame left width: 260'), findsOneWidget);
    expect(find.text('stored left width: none'), findsOneWidget);
    expect(tester.getSize(_id('page_layout.left_pane')).width, 260);
  });

  testWidgets(
    'the set-width button makes the pane the stored width and reports it',
    (tester) async {
      final store = StratumMemorySettingStore();
      await _open(tester, store: store);

      await tester.tap(find.text('Set left width to 300'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(_id('page_layout.left_pane')).width,
        pageLayoutFixtureStoredLeftWidth,
      );
      expect(
        store.values[_storedLeftWidthKey],
        pageLayoutFixtureStoredLeftWidth,
      );
      expect(find.text('stored left width: 300'), findsOneWidget);
      // The first frame keeps the width the page opened with.
      expect(find.text('first frame left width: 260'), findsOneWidget);
    },
  );

  testWidgets('reset clears the stored width', (tester) async {
    final store = StratumMemorySettingStore();
    await _open(tester, store: store);
    await tester.tap(find.text('Set left width to 300'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset settings'));
    await tester.pumpAndSettle();

    expect(store.values.containsKey(_storedLeftWidthKey), isFalse);
    expect(find.text('stored left width: none'), findsOneWidget);
  });

  testWidgets('a store holding the stored width opens the page at it', (
    tester,
  ) async {
    final store = StratumMemorySettingStore(
      values: {_storedLeftWidthKey: pageLayoutFixtureStoredLeftWidth},
    );
    await _open(tester, store: store);

    expect(find.text('first frame left width: 300'), findsOneWidget);
    expect(find.text('stored left width: 300'), findsOneWidget);
  });

  for (final window in [const Size(360, 640), const Size(411, 731)]) {
    testWidgets('a ${window.width.toInt()} dp phone window lays the left pane '
        'out inline at the stored width', (tester) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = await _preloadTheme(tester);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication.controlled(
            controller: theme,
            themeMode: ThemeMode.light,
            child: child!,
          ),
          home: Scaffold(
            body: PageLayoutFixture(store: StratumMemorySettingStore()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('first frame left width: 260'), findsOneWidget);

      await tester.tap(find.text('Set left width to 300'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(_id('page_layout.left_pane')).width,
        pageLayoutFixtureStoredLeftWidth,
      );
    });
  }
}
