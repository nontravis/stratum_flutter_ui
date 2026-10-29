import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_themes.dart';
import 'package:stratum_ui_widgetbook/shell/stratum_theme_addon.dart';
import 'package:stratum_ui_widgetbook/shell/window_size_addon.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/catalog_theme.dart';

/// Reads the window size class the theme application publishes.
class _SizeProbe extends StatelessWidget {
  const _SizeProbe(this.onRead);

  final ValueChanged<WindowSize> onRead;

  @override
  Widget build(BuildContext context) {
    onRead(WindowSizeScope.of(context));
    return const SizedBox(width: 10, height: 10);
  }
}

/// Builds the window size addon at [viewport] around the theme addon around
/// a probe, the order [catalogAddons] puts them in.
Widget _chain(
  ViewportData viewport,
  StratumThemeSet set,
  ValueChanged<WindowSize> onRead,
) {
  final themeAddon = stratumThemeAddon(catalogThemes({'default': set}));
  return MaterialApp(
    home: Builder(
      builder: (context) => WindowSizeAddon().apply(
        context,
        Builder(
          builder: (context) => themeAddon.apply(
            context,
            _SizeProbe(onRead),
            themeAddon.initialValue,
          ),
        ),
        viewport,
      ),
    ),
  );
}

void main() {
  test('fo11/us02/fr01: every window size maps to its class', () {
    for (final MapEntry(:key, :value) in catalogWindowSizes.entries) {
      expect(WindowSize.fromSize(value), key, reason: '$value');
    }
    expect(catalogWindowSizes.keys, WindowSize.values);

    final addon = WindowSizeAddon();
    expect(addon.viewports.map((v) => v.name), [
      for (final size in WindowSize.values) size.name,
    ]);
    expect(addon.initialValue.name, 'mobile');
    expect(addon.showFrame, isFalse);
  });

  testWidgets('fo11/us02/fr01/e01: a window size change renders the story '
      'again', (tester) async {
    final set = await loadDefaultThemeSet();
    final addon = WindowSizeAddon();
    final seen = <WindowSize>[];
    ViewportData named(WindowSize size) =>
        addon.viewports.firstWhere((v) => v.name == size.name);

    await tester.pumpWidget(_chain(named(WindowSize.mobile), set, seen.add));
    await tester.pumpAndSettle();
    expect(seen.last, WindowSize.mobile);

    await tester.pumpWidget(_chain(named(WindowSize.tablet), set, seen.add));
    await tester.pumpAndSettle();
    expect(seen.last, WindowSize.tablet);
  });

  testWidgets('fo11/us02/fr01: Review Focus 1: bigDesktop on a 1280 x 800 '
      'surface throws nothing', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final set = await loadDefaultThemeSet();
    final addon = WindowSizeAddon();
    final seen = <WindowSize>[];
    final bigDesktop = addon.viewports.firstWhere(
      (v) => v.name == WindowSize.bigDesktop.name,
    );

    await tester.pumpWidget(_chain(bigDesktop, set, seen.add));
    await tester.pumpAndSettle();

    expect(seen.last, WindowSize.bigDesktop);
    expect(tester.takeException(), isNull);
  });
}
