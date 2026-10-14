import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/l10n/stratum_labels.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';

import '../components/common/fakes/fake_stratum_theme.dart';
import '../themes/theme_runtime_fakes.dart';

Future<StratumThemeController> _controller() =>
    StratumThemeController.preload(bundle: FakeThemeBundle());

/// An update check whose every ask returns [answer].
class _OneAnswer implements UpdateChecker {
  const new(this.answer);

  final Future<UpdateStatus> answer;

  @override
  Future<UpdateStatus> check() => answer;
}

void main() {
  setUp(ThemeFontLoader.reset);

  // NFR-U06 is not n/a: it gets its own test below ("NFR-U06: the
  // wrapper adds no node"), per SKILL.md:81's "owns no node" rule. Every
  // other Build Gate row the US-13 block answers n/a, each quoted
  // verbatim from USER_STORY.md:63-81:
  // - NFR-U02: "n/a: the wrapper holds no focusable node of its own."
  // - NFR-U09: "n/a: the wrapper handles no gesture of its own."
  // - NFR-U03: "n/a: the wrapper runs no animation of its own; the
  //   splash exit (US-12) and the notices (CO-05-07) answer theirs."
  // - NFR-U04: "n/a: the wrapper shows no text of its own."
  // - NFR-U05: "n/a: the wrapper holds no target of its own."
  // - NFR-U01, NFR-U07: "n/a: the wrapper draws nothing; each layer
  //   draws from theme tokens."
  // - NFR-U08: "n/a: the wrapper shows no state."
  // - empty: "n/a: an app always shows content."
  // - disabled: "n/a: an app has no disabled state."
  // - feedback after an action: "n/a: the wrapper takes no action of
  //   its own."
  // - NFR-E01, NFR-E02: "n/a: the wrapper draws no look of its own and
  //   takes no instance-level style override."
  //
  // `us13/s7` (splash in front) is out of scope for this task: `splash`
  // stays `planned` (themes `s01_architecture.md:183`); M5-T31 defers it.

  testWidgets('us13/s1: us13/fr02: the app builds its MaterialApp from '
      'the config', (tester) async {
    StratumAppConfig? seen;
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        themeMode: ThemeMode.light,
        appBuilder: (context, stratum) {
          seen = stratum;
          return MaterialApp(
            theme: stratum.theme,
            darkTheme: stratum.darkTheme,
            themeMode: stratum.themeMode,
            builder: stratum.builder,
            home: const Text('home'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(seen!.themeMode, ThemeMode.light);
    expect(find.byType(StratumThemeApplication), findsOneWidget);
  });

  testWidgets('us13/fr01: inner layers in order: theme application, '
      'toast host, web zoom, child', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        webZoom: (child) => StratumWebZoom(child: child),
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    final app = find.byType(StratumThemeApplication);
    final host = find.descendant(
      of: app,
      matching: find.byType(StratumToastHost),
    );
    final zoom = find.descendant(
      of: host,
      matching: find.byType(StratumWebZoom),
    );
    expect(
      find.descendant(of: zoom, matching: find.text('home')),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: app, matching: find.byType(MaterialApp)),
      findsOneWidget,
    );
  });

  testWidgets('us13/s2: a notice from a screen shows with no host of '
      'the app', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => MaterialApp(
          builder: s.builder,
          home: Scaffold(
            body: Builder(
              builder: (b) => TextButton(
                onPressed: () => b.showToast(message: 'Hello'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('us13/s3: us13/fr02/e01: a Cupertino app gets the same '
      'layers', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) =>
            CupertinoApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StratumToastHost), findsOneWidget);
    expect(find.byType(StratumThemeApplication), findsOneWidget);
  });

  testWidgets('us13/fr02/e01: a plain WidgetsApp gets the same layers', (
    tester,
  ) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => WidgetsApp(
          color: const Color(0xFF000000),
          builder: s.builder,
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) =>
                builder(context),
          ),
          home: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StratumToastHost), findsOneWidget);
    expect(find.byType(StratumThemeApplication), findsOneWidget);
  });

  testWidgets('us13/s5: us13/fr03: the app wrapper sits inside the '
      'Stratum layers', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => MaterialApp(
          builder: (context, child) => s.builder(
            context,
            KeyedSubtree(key: const Key('mine'), child: child!),
          ),
          home: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(StratumToastHost),
        matching: find.byKey(const Key('mine')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('us13/fr03/e01: an unchanged builder puts the layers '
      'directly around the navigator', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        webZoom: (child) => StratumWebZoom(child: child),
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(StratumWebZoom),
        matching: find.byType(Navigator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('us13/fr03/e02: an app builder that skips the config '
      'builder drops the inner layers', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => MaterialApp(
          builder: (context, child) => child!,
          home: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StratumToastHost), findsNothing);
  });

  testWidgets('us13/s6: us13/fr01/e01: no webZoom leaves the layer '
      'out, others keep order', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StratumWebZoom), findsNothing);
    expect(
      find.descendant(
        of: find.byType(StratumToastHost),
        matching: find.text('home'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('us13/fr01/e02: a component reads the live corner radius, '
      'unaffected by the wrapper', (tester) async {
    const radius = BorderRadius.all(Radius.circular(24));
    BorderRadius? seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(displayCornerRadii: radius),
        child: StratumApplication(
          controller: await _controller(),
          appBuilder: (c, s) => MaterialApp(
            builder: s.builder,
            home: Builder(
              builder: (context) {
                seen = context.deviceWindow.radius;
                return const Text('home');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, radius);
  });

  testWidgets('us13/fr01/e05: notices false leaves the host out and '
      'showToast throws', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        notices: false,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StratumToastHost), findsNothing);
    expect(
      () => tester.element(find.text('home')).showToast(message: 'x'),
      throwsA(isA<FlutterError>()),
    );
  });

  testWidgets('us13/fr01/e06: noticeHost replaces the plain notice '
      'host', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        noticeHost: (child) =>
            StratumToastHost(key: const Key('mine'), child: child),
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mine')), findsOneWidget);
  });

  testWidgets('us13/fr01/e06: notices false drops the layer whatever '
      'noticeHost holds', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        notices: false,
        noticeHost: (child) => StratumToastHost(child: child),
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StratumToastHost), findsNothing);
  });

  testWidgets('us13/fr01/e06: a rebuild with a new noticeHost takes '
      'effect', (tester) async {
    final controller = await _controller();
    Widget app(Key key) => StratumApplication(
      controller: controller,
      noticeHost: (child) => StratumToastHost(key: key, child: child),
      appBuilder: (c, s) =>
          MaterialApp(builder: s.builder, home: const Text('home')),
    );
    await tester.pumpWidget(app(const Key('first')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first')), findsOneWidget);
    await tester.pumpWidget(app(const Key('second')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first')), findsNothing);
    expect(find.byKey(const Key('second')), findsOneWidget);
  });

  testWidgets('us13/fr02/e03: a mode change runs the app builder '
      'again', (tester) async {
    final modes = <ThemeMode>[];
    final controller = await _controller();
    Widget app(ThemeMode mode) => StratumApplication(
      controller: controller,
      themeMode: mode,
      appBuilder: (c, s) {
        modes.add(s.themeMode);
        return MaterialApp(builder: s.builder, home: const Text('home'));
      },
    );
    await tester.pumpWidget(app(ThemeMode.light));
    await tester.pumpWidget(app(ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(modes.last, ThemeMode.dark);
  });

  testWidgets('us13/fr02/e03: an active-theme switch runs the app '
      'builder again', (tester) async {
    final controller = await StratumThemeController.preload(
      bundle: FakeThemeBundle(themes: {'brand': markTheme('brand-mark')}),
    );
    var calls = 0;
    await tester.pumpWidget(
      StratumApplication(
        controller: controller,
        appBuilder: (c, s) {
          calls++;
          return MaterialApp(builder: s.builder, home: const Text('home'));
        },
      ),
    );
    await tester.pumpAndSettle();
    final before = calls;
    await controller.switchTo('brand');
    await tester.pump();
    expect(calls, greaterThan(before));
  });

  testWidgets('us13/fr01: an app-held controller stays usable after the '
      'wrapper unmounts', (tester) async {
    final controller = await _controller();
    await tester.pumpWidget(
      StratumApplication(
        controller: controller,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(() => controller.addListener(() {}), returnsNormally);
  });

  testWidgets('us13/s4: us13/fr02/e02: the app keeps its own locale; the theme '
      'application reads it', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => MaterialApp(
          locale: const Locale('th'),
          supportedLocales: const [Locale('th')],
          localizationsDelegates: StratumLabels.localizationsDelegates,
          builder: s.builder,
          home: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Localizations.localeOf(tester.element(find.text('home'))),
      const Locale('th'),
    );
  });

  testWidgets('us13/fr01: systemStyle reaches StratumThemeApplication', (
    tester,
  ) async {
    const style = SystemStyle(barMode: SystemBarMode.topOnly);
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        systemStyle: style,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<StratumThemeApplication>(
      find.byType(StratumThemeApplication),
    );
    expect(app.systemStyle, style);
  });

  testWidgets('us13/fr01: componentPartDefaults reaches '
      'StratumThemeApplication', (tester) async {
    Map<Type, Object> parts(StratumTheme theme) => const {};
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        componentPartDefaults: parts,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<StratumThemeApplication>(
      find.byType(StratumThemeApplication),
    );
    expect(app.componentPartDefaults, same(parts));
  });

  testWidgets('us13/fr01: componentDefaults and highContrast reach '
      'StratumThemeApplication', (tester) async {
    Map<Type, WidgetStyle> defaults(StratumTheme theme) => const {};
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        componentDefaults: defaults,
        highContrast: StratumHighContrastMode.on,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<StratumThemeApplication>(
      find.byType(StratumThemeApplication),
    );
    expect(app.componentDefaults, same(defaults));
    expect(app.highContrast, StratumHighContrastMode.on);
  });

  testWidgets('us13/fr01: the preload inputs reach StratumThemePreloader', (
    tester,
  ) async {
    void onThemeChanged(String id) {}
    void onRemoteThemeError(String id, StratumRemoteThemeException error) {}
    Widget errorBuilder(BuildContext context, Object error) =>
        const SizedBox.shrink();
    final remoteThemes = <StratumRemoteTheme>[];
    await tester.pumpWidget(
      StratumApplication(
        initialThemeId: 'brand',
        onThemeChanged: onThemeChanged,
        googleFontsTimeout: const Duration(seconds: 7),
        remoteThemes: remoteThemes,
        onRemoteThemeError: onRemoteThemeError,
        error: errorBuilder,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    final preloader = tester.widget<StratumThemePreloader>(
      find.byType(StratumThemePreloader),
    );
    expect(preloader.initialThemeId, 'brand');
    expect(preloader.onThemeChanged, same(onThemeChanged));
    expect(preloader.googleFontsTimeout, const Duration(seconds: 7));
    expect(preloader.remoteThemes, same(remoteThemes));
    expect(preloader.onRemoteThemeError, same(onRemoteThemeError));
    expect(preloader.error, same(errorBuilder));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('us13/fr04/e03: the gate sits first inside '
      'stratum.builder, around the navigator', (tester) async {
    final answer = Completer<UpdateStatus>();
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        updateGate: (child) => StratumUpdateGate(
          checker: _OneAnswer(answer.future),
          builder: (context, gate) => const Text('Required'),
          child: child,
        ),
        appBuilder: (context, stratum) =>
            MaterialApp(builder: stratum.builder, home: const Text('Home')),
      ),
    );
    await tester.pumpAndSettle();
    final app = find.byType(StratumThemeApplication);
    final gate = find.descendant(
      of: app,
      matching: find.byType(StratumUpdateGate),
    );
    expect(gate, findsOneWidget);
    expect(
      find.descendant(of: gate, matching: find.byType(StratumToastHost)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gate, matching: find.byType(Navigator)),
      findsOneWidget,
    );
    answer.complete(UpdateStatus.required);
    await tester.pump(Duration.zero);
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('us13/fr01/e04: with no splash the default background '
      'shows until the theme is active', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color == StratumApplication.noSplashLightBackground,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('us13/fr01/e04: a dark themeMode with no splash shows '
      'the dark background', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        themeMode: ThemeMode.dark,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color == StratumApplication.noSplashDarkBackground,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('us13/fr01/e04: a light themeMode with no splash shows '
      'the light background', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        themeMode: ThemeMode.light,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color == StratumApplication.noSplashLightBackground,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('us13/fr01/e04: themeMode system with platform brightness '
      'dark shows the dark background', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: StratumApplication(
          themeMode: ThemeMode.system,
          appBuilder: (c, s) =>
              MaterialApp(builder: s.builder, home: const Text('home')),
        ),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color == StratumApplication.noSplashDarkBackground,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('us13/fr01/e04: themeMode system with platform brightness '
      'light shows the light background', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.light),
        child: StratumApplication(
          themeMode: ThemeMode.system,
          appBuilder: (c, s) =>
              MaterialApp(builder: s.builder, home: const Text('home')),
        ),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color == StratumApplication.noSplashLightBackground,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('us13/fr01/e04: loadingBuilder replaces the default '
      'background', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        loadingBuilder: (context) =>
            const Text('loading-mine', textDirection: TextDirection.ltr),
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );
    expect(find.text('loading-mine'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is ColoredBox), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('us13/fr01/e04: the no-splash colors equal the default theme '
      'background', () {
    expect(
      StratumApplication.noSplashLightBackground,
      defaultThemeSet.light.color.background.defaults.normal,
    );
    expect(
      StratumApplication.noSplashDarkBackground,
      defaultThemeSet.dark!.color.background.defaults.normal,
    );
  });

  testWidgets('NFR-U06: the wrapper adds no node: a child reads '
      'unchanged', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => MaterialApp(
          builder: s.builder,
          home: TextButton(onPressed: () {}, child: const Text('Act')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Act')),
      matchesSemantics(
        label: 'Act',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    handle.dispose();
  });
}
