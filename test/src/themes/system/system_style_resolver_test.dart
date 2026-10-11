import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/system/system_style_resolver.dart';

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

  group('us14/fr02: icons against the fill', () {
    testWidgets('us14/s3, us14/fr02/e01, us14/fr05/e03: a dark header gives '
        'light icons on a screen with no page layout', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(home: headerPage(const Color(0xFF101828))),
      );

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
    });

    testWidgets('us14/s4, us14/fr02/e02, us14/fr05/e02: a translucent scrim '
        'blends over the header', (tester) async {
      systemBarsView(tester);
      final scrim = ValueNotifier(false);
      addTearDown(scrim.dispose);
      await tester.pumpWidget(
        systemStyleApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: scrim,
            builder: (context, shown, child) => StackLayout(
              children: [
                headerPage(const Color(0xFFFFFFFF)),
                if (shown)
                  const Positioned.fill(
                    child: SystemBarFill(
                      color: Color(0x99000000),
                      child: ColoredBox(color: Color(0x99000000)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      scrim.value = true;
      await tester.pump();

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    });

    testWidgets('us14/fr05/e01: a fill away from the status bar takes no '
        'part in its icons', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          home: const ColumnLayout(
            children: [
              Expanded(child: SizedBox()),
              SystemBarFill(
                color: Color(0xFF000000),
                child: SizedBox(height: 80, width: double.infinity),
              ),
            ],
          ),
        ),
      );

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.light,
      );
    });

    testWidgets("us14/s6, us14/fr02/e04: the page's own dark icons beat a "
        'dark Material app bar', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          home: SystemStyleScope(
            style: const SystemStyle(statusBarIcons: SystemBarIcons.dark),
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFF000000),
                title: const Text('Page'),
              ),
            ),
          ),
        ),
      );

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    });

    testWidgets('us14/fr01/e06: a page bar color paints while the page '
        'shows, and back removes it', (tester) async {
      systemBarsView(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        systemStyleApp(navigatorKey: navigator, home: const SizedBox()),
      );
      expect(barStrips(tester), paintsNothing);

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => const SystemStyleScope(
            style: SystemStyle(statusBarColor: Color(0xFF101828)),
            child: SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        barStrips(tester),
        paints..rect(rect: statusStrip, color: const Color(0xFF101828)),
      );
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(barStrips(tester), paintsNothing);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    });
  });

  group('us14/fr03: the bar mode and the rotation lock', () {
    testWidgets('us14/s7, us14/s8, us14/s9, us14/fr03/e02, us14/fr03/e03: '
        'the video page hides the bars, a page over it shows them, and back '
        'hides them again', (tester) async {
      final calls = systemBarsView(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        systemStyleApp(navigatorKey: navigator, home: const SizedBox()),
      );
      expect(lastMode(calls), 'SystemUiMode.edgeToEdge');
      expect(lastOrientations(calls), isEmpty);

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) =>
              const SystemStyleScope(style: _immersive, child: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(lastMode(calls), 'SystemUiMode.immersiveSticky');
      expect(lastOrientations(calls), ['DeviceOrientation.portraitUp']);

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (context) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expect(lastMode(calls), 'SystemUiMode.edgeToEdge');
      expect(lastOrientations(calls), isEmpty);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(lastMode(calls), 'SystemUiMode.immersiveSticky');
      expect(lastOrientations(calls), ['DeviceOrientation.portraitUp']);
    });

    testWidgets('us14/s10, us14/fr03/e01: a dialog over the page keeps its '
        'bar mode and rotation lock', (tester) async {
      final calls = systemBarsView(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        systemStyleApp(
          navigatorKey: navigator,
          home: const SystemStyleScope(
            style: SystemStyle(
              barMode: SystemBarMode.immersive,
              orientations: [DeviceOrientation.portraitUp],
            ),
            child: SizedBox(),
          ),
        ),
      );
      expect(lastMode(calls), 'SystemUiMode.immersive');
      final sent = calls.length;

      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (context) => const Text('Dialog'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dialog'), findsOneWidget);
      expect(
        argumentsOf(calls.sublist(sent), 'SystemChrome.setEnabledSystemUIMode'),
        isEmpty,
      );
      expect(
        argumentsOf(
          calls.sublist(sent),
          'SystemChrome.setPreferredOrientations',
        ),
        isEmpty,
      );
    });

    testWidgets('us14/s11, us14/fr03/e04: the tab on screen sets the bars', (
      tester,
    ) async {
      final calls = systemBarsView(tester);
      final tab = ValueNotifier(0);
      addTearDown(tab.dispose);
      await tester.pumpWidget(
        systemStyleApp(
          home: ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (context, index, child) => IndexedStackLayout(
              index: index,
              children: const [
                SystemStyleScope(style: _immersive, child: SizedBox()),
                SizedBox(),
              ],
            ),
          ),
        ),
      );
      expect(lastMode(calls), 'SystemUiMode.immersiveSticky');

      tab.value = 1;
      await tester.pump();

      expect(lastMode(calls), 'SystemUiMode.edgeToEdge');
    });

    testWidgets('us14/fr03/e06: the bars follow what paints with no '
        'navigator at all', (tester) async {
      final calls = systemBarsView(tester);
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: defaultThemeSet,
          themeMode: ThemeMode.light,
          child: const SystemStyleScope(
            style: SystemStyle(barMode: SystemBarMode.leanBack),
            child: SizedBox(),
          ),
        ),
      );

      expect(lastMode(calls), 'SystemUiMode.leanBack');
    });

    testWidgets('us14/fr01: an empty orientation list on a page lifts the '
        'app-wide lock while the page shows', (tester) async {
      final calls = systemBarsView(tester);
      const appWide = SystemStyle(orientations: [DeviceOrientation.portraitUp]);
      await tester.pumpWidget(
        systemStyleApp(systemStyle: appWide, home: const SizedBox()),
      );
      expect(lastOrientations(calls), ['DeviceOrientation.portraitUp']);

      await tester.pumpWidget(
        systemStyleApp(
          systemStyle: appWide,
          home: const SystemStyleScope(
            style: SystemStyle(orientations: []),
            child: SizedBox(),
          ),
        ),
      );

      expect(lastOrientations(calls), isEmpty);
    });

    testWidgets('d11: topOnly and bottomOnly show one bar each', (
      tester,
    ) async {
      final calls = systemBarsView(tester);
      final mode = ValueNotifier(SystemBarMode.topOnly);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        systemStyleApp(
          home: ValueListenableBuilder<SystemBarMode>(
            valueListenable: mode,
            builder: (context, value, child) => SystemStyleScope(
              style: SystemStyle(barMode: value),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      expect(lastOverlays(calls), ['SystemUiOverlay.top']);

      mode.value = SystemBarMode.bottomOnly;
      await tester.pump();

      expect(lastOverlays(calls), ['SystemUiOverlay.bottom']);
    });

    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
      testWidgets('us14/s12, us14/fr03/e05: on ${platform.name} the lock is '
          'ignored with no error', (tester) async {
        final calls = systemBarsView(tester);
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          systemStyleApp(
            home: const SystemStyleScope(
              style: _immersive,
              child: Text('Page'),
            ),
          ),
        );
        debugDefaultTargetPlatformOverride = null;

        expect(find.text('Page'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(lastOrientations(calls), isNull);
        expect(lastMode(calls), isNull);
      });
    }

    testWidgets('us14/s12, us14/fr03/e05: in a web browser the lock is '
        'ignored with no error', (tester) async {
      final calls = systemBarsView(tester);
      debugSystemStyleIsWebOverride = true;
      await tester.pumpWidget(
        systemStyleApp(
          home: const SystemStyleScope(style: _immersive, child: Text('Page')),
        ),
      );

      expect(find.text('Page'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(lastOrientations(calls), isNull);
      expect(lastMode(calls), isNull);
    });
  });

  group('us14/fr04: the page label', () {
    testWidgets('us14/s13, us14/s14, us14/fr04/e01, us14/fr04/e03: on the '
        'web the page label shows, back shows the app label, and no status '
        'bar style is sent', (tester) async {
      final calls = systemBarsView(tester);
      debugSystemStyleIsWebOverride = true;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        systemStyleApp(
          navigatorKey: navigator,
          systemStyle: const SystemStyle(
            appSwitcherLabel: 'Shop',
            statusBarColor: Color(0xFF0A0B0C),
          ),
          home: const SizedBox(),
        ),
      );
      expect(lastLabel(calls), 'Shop');

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => const SystemStyleScope(
            style: SystemStyle(appSwitcherLabel: 'Settings'),
            child: SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(lastLabel(calls), 'Settings');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(lastLabel(calls), 'Shop');
      expect(
        argumentsOf(calls, 'SystemChrome.setSystemUIOverlayStyle'),
        isEmpty,
      );
    });

    testWidgets('us14/fr04/e02: after the app widget rebuilds with a new '
        'title, the page label is sent again', (tester) async {
      final calls = systemBarsView(tester);
      const page = SystemStyleScope(
        style: SystemStyle(appSwitcherLabel: 'Settings'),
        child: SizedBox(),
      );
      await tester.pumpWidget(systemStyleApp(home: page));
      expect(lastLabel(calls), 'Settings');

      await tester.pumpWidget(systemStyleApp(title: 'Renamed', home: page));

      expect(lastLabel(calls), 'Settings');
      expect(
        argumentsOf(
          calls,
          'SystemChrome.setApplicationSwitcherDescription',
        ).map((sent) => (sent! as Map<Object?, Object?>)['label']),
        containsAllInOrder(<Object?>['Renamed', 'Settings']),
      );
    });
  });
}

const _immersive = SystemStyle(
  barMode: SystemBarMode.immersiveSticky,
  orientations: [DeviceOrientation.portraitUp],
);
