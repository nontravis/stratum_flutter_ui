import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';
import 'system_style_fakes.dart';

/// The package default theme with the status bar and navigation bar
/// colors set for light and dark mode.
final StratumThemeSet _coloredBars = StratumThemeSet.fromConfig(
  StratumThemeConfig.parse(
    base: const StratumThemeSource(
      id: 'stratum-default',
      folder: 'packages/stratum_ui/assets/themes/default',
      yaml: defaultThemeSource,
    ),
    layers: const [
      StratumThemeSource(
        id: 'bars',
        folder: 'themes/bars',
        yaml: r'''
$schema: stratum-theme/v1.3.0
system:
  light:
    statusBarColor: "#0000AA"
    navigationBarColor: "#0000BB"
  dark:
    statusBarColor: "#0000CC"
    navigationBarColor: "#0000DD"
''',
      ),
    ],
  ),
);

void main() {
  group('us14: the theme and the app-wide style', () {
    testWidgets("us14/s1: a page with no style shows the theme's dark "
        'colors in dark mode', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          themes: _coloredBars,
          themeMode: ThemeMode.dark,
          home: const SizedBox(),
        ),
      );

      expect(
        barStrips(tester),
        paints
          ..rect(rect: statusStrip, color: const Color(0xFF0000CC))
          ..rect(rect: navigationStrip, color: const Color(0xFF0000DD)),
      );
    });

    testWidgets('us14/s2, us14/fr01/e01: the app sets only the navigation bar '
        'color', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          themes: _coloredBars,
          systemStyle: const SystemStyle(navigationBarColor: Color(0xFF00FF00)),
          home: const SizedBox(),
        ),
      );

      expect(
        barStrips(tester),
        paints
          ..rect(rect: statusStrip, color: const Color(0xFF0000AA))
          ..rect(rect: navigationStrip, color: const Color(0xFF00FF00)),
      );
    });

    testWidgets('us14/fr01/e03: a mode change takes the new set with no app '
        'code', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(themes: _coloredBars, home: const SizedBox()),
      );
      expect(
        barStrips(tester),
        paints..rect(rect: statusStrip, color: const Color(0xFF0000AA)),
      );

      await tester.pumpWidget(
        systemStyleApp(
          themes: _coloredBars,
          themeMode: ThemeMode.dark,
          home: const SizedBox(),
        ),
      );

      expect(
        barStrips(tester),
        paints..rect(rect: statusStrip, color: const Color(0xFF0000CC)),
      );
    });

    testWidgets('us14/fr01/e05: a theme switch while the page shows takes the '
        "new theme's look with no app code", (tester) async {
      final calls = systemBarsView(tester);
      const appWide = SystemStyle(barMode: SystemBarMode.immersive);
      await tester.pumpWidget(
        systemStyleApp(
          themes: _coloredBars,
          systemStyle: appWide,
          home: const SizedBox(),
        ),
      );
      expect(
        barStrips(tester),
        paints..rect(rect: statusStrip, color: const Color(0xFF0000AA)),
      );

      await tester.pumpWidget(
        systemStyleApp(systemStyle: appWide, home: const SizedBox()),
      );

      expect(barStrips(tester), paintsNothing);
      expect(lastMode(calls), 'SystemUiMode.immersive');
    });

    testWidgets("us14/fr02/e05: Stratum turns Flutter's own overlay write off "
        'while it is in the tree', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(systemStyleApp(home: const SizedBox()));

      expect(
        tester.binding.renderViews.single.automaticSystemUiAdjustment,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox());

      expect(
        tester.binding.renderViews.single.automaticSystemUiAdjustment,
        isTrue,
      );
    });

    testWidgets('us14/s5, us14/fr02/e03: no fill takes the page background '
        'of the mode', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(systemStyleApp(home: const SizedBox()));
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      await tester.pumpWidget(
        systemStyleApp(themeMode: ThemeMode.dark, home: const SizedBox()),
      );

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    });

    testWidgets('us14/fr02/e05, us08/fr01/e05: a dark app bar under auto '
        'icons gives light icons', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          home: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF000000),
              title: const Text('Page'),
            ),
          ),
        ),
      );

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    });

    testWidgets('us14/fr02/e06: off Android the navigation bar fields are '
        'left unset', (tester) async {
      systemBarsView(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(systemStyleApp(home: const SizedBox()));
      final overlay = SystemChrome.latestStyle;
      debugDefaultTargetPlatformOverride = null;

      expect(overlay?.systemNavigationBarColor, isNull);
      expect(overlay?.systemNavigationBarIconBrightness, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('us14/fr03: with no layer setting them, the app is edge to '
        'edge with no lock; the app-wide style sets them', (tester) async {
      final calls = systemBarsView(tester);
      await tester.pumpWidget(systemStyleApp(home: const SizedBox()));
      expect(lastMode(calls), 'SystemUiMode.edgeToEdge');
      expect(lastOrientations(calls), isEmpty);

      await tester.pumpWidget(
        systemStyleApp(
          systemStyle: const SystemStyle(
            barMode: SystemBarMode.leanBack,
            orientations: [DeviceOrientation.landscapeLeft],
          ),
          home: const SizedBox(),
        ),
      );

      expect(lastMode(calls), 'SystemUiMode.leanBack');
      expect(lastOrientations(calls), ['DeviceOrientation.landscapeLeft']);
    });
  });

  group('us14/fr01/e06: the bar colors the application paints', () {
    testWidgets('us14/fr01/e06: the platform gets transparent bar colors '
        'while the strips show the theme colors', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(themes: _coloredBars, home: const SizedBox()),
      );

      expect(SystemChrome.latestStyle?.statusBarColor, const Color(0x00000000));
      expect(
        SystemChrome.latestStyle?.systemNavigationBarColor,
        const Color(0x00000000),
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarDividerColor,
        const Color(0x00000000),
      );
      expect(
        barStrips(tester),
        paints
          ..rect(rect: statusStrip, color: const Color(0xFF0000AA))
          ..rect(rect: navigationStrip, color: const Color(0xFF0000BB)),
      );
    });

    testWidgets('us14/s16, us14/fr02/e07: an opaque status bar color gives '
        'icons against itself', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          systemStyle: const SystemStyle(statusBarColor: Color(0xFF101828)),
          home: const SizedBox(),
        ),
      );

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      expect(
        barStrips(tester),
        paints..rect(rect: statusStrip, color: const Color(0xFF101828)),
      );
    });

    testWidgets('us14/fr01/e06: the divider is a one-pixel line on the edge '
        'of the navigation strip that faces the page', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          systemStyle: const SystemStyle(
            navigationBarColor: Color(0xFF0000BB),
            navigationBarDividerColor: Color(0xFFFF0000),
          ),
          home: const SizedBox(),
        ),
      );

      expect(
        barStrips(tester),
        paints
          ..rect(
            rect: Rect.fromLTWH(0, navigationStrip.top, 800, 1),
            color: const Color(0xFFFF0000),
          )
          ..rect(
            rect: Rect.fromLTRB(0, navigationStrip.top + 1, 800, 600),
            color: const Color(0xFF0000BB),
          ),
      );
    });

    testWidgets('us14/fr02/e06: on iOS the status strip paints and the '
        'navigation strip does not', (tester) async {
      systemBarsView(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        systemStyleApp(themes: _coloredBars, home: const SizedBox()),
      );
      final strips = barStrips(tester);
      debugDefaultTargetPlatformOverride = null;

      expect(
        strips,
        paints..rect(rect: statusStrip, color: const Color(0xFF0000AA)),
      );
      expect(strips, paintsExactlyCountTimes(#drawRect, 1));
    });

    testWidgets('us14/fr01/e07: a navigation bar on a side gets no strip and '
        "keeps the platform's contrast scrim", (tester) async {
      systemBarsView(tester);
      tester.view.padding = const FakeViewPadding(top: 72, right: 144);
      await tester.pumpWidget(
        systemStyleApp(themes: _coloredBars, home: const SizedBox()),
      );

      expect(
        barStrips(tester),
        paints..rect(rect: statusStrip, color: const Color(0xFF0000AA)),
      );
      expect(barStrips(tester), paintsExactlyCountTimes(#drawRect, 1));
      expect(
        SystemChrome.latestStyle?.systemNavigationBarContrastEnforced,
        isTrue,
      );
    });

    testWidgets('only the outermost theme application on a view paints the '
        'strips', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          home: StratumThemeApplication(
            themes: defaultThemeSet,
            themeMode: ThemeMode.light,
            systemStyle: const SystemStyle(statusBarColor: Color(0xFF00AA00)),
            child: const SizedBox(),
          ),
        ),
      );

      expect(
        barStrips(tester),
        paints..rect(rect: statusStrip, color: const Color(0xFF00AA00)),
      );
      expect(barStrips(tester, index: 1), paintsNothing);
    });
  });

  group('us14: one writer', () {
    testWidgets('frames that change no style send no platform message '
        'again', (tester) async {
      final calls = systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          systemStyle: const SystemStyle(
            barMode: SystemBarMode.leanBack,
            orientations: [DeviceOrientation.portraitUp],
            appSwitcherLabel: 'Shop',
          ),
          home: const Center(child: CircularProgressIndicator()),
        ),
      );
      await tester.pump();
      final sent = calls.length;

      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(calls, hasLength(sent));
      expect(lastMode(calls), 'SystemUiMode.leanBack');
    });
  });

  group('us14/fr04: the app-wide label', () {
    testWidgets('us14/fr04: the color is the merged appSwitcherColor, made '
        'opaque', (tester) async {
      final calls = systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          systemStyle: const SystemStyle(
            appSwitcherLabel: 'Shop',
            appSwitcherColor: Color(0x80123456),
          ),
          home: const SizedBox(),
        ),
      );

      expect(lastSwitcherColor(calls), 0xFF123456);
    });

    testWidgets("us14/fr04/e05: with no label anywhere the app widget's "
        'title shows with the appSwitcherColor', (tester) async {
      final calls = systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(title: 'Stratum', home: const SizedBox()),
      );

      expect(lastLabel(calls), 'Stratum');
      expect(
        lastSwitcherColor(calls),
        defaultThemeSet.light.systemStyle.appSwitcherColor!.toARGB32(),
      );
    });

    testWidgets('us14/fr04/e04: on a desktop the entry is sent with no '
        'error', (tester) async {
      final calls = systemBarsView(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.pumpWidget(
        systemStyleApp(
          systemStyle: const SystemStyle(appSwitcherLabel: 'Shop'),
          home: const SizedBox(),
        ),
      );
      debugDefaultTargetPlatformOverride = null;

      expect(tester.takeException(), isNull);
      expect(lastLabel(calls), 'Shop');
    });
  });
}
