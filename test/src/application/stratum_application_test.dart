import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/l10n/stratum_labels.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';

import '../components/common/fakes/fake_stratum_theme.dart';
import '../themes/theme_runtime_fakes.dart';

Future<StratumThemeController> _controller() =>
    StratumThemeController.preload(bundle: FakeThemeBundle());

/// The brand color of [_brandTheme]'s light set.
const _brandRed = Color(0xFFFF0000);

/// An app theme whose light brand color, and so its Material primary, is
/// [_brandRed].
final String _brandTheme = appTheme('palette:\n  brand:\n    500: "#FF0000"');

/// The no-splash background box of [color].
Finder _backgroundBox(Color color) =>
    find.byWidgetPredicate((w) => w is ColoredBox && w.color == color);

/// A wrapper with no controller whose start theme `x` fails to parse.
Widget _failingStart({Widget Function(BuildContext, Object)? error}) =>
    DefaultAssetBundle(
      bundle: FakeThemeBundle(themes: {'x': brokenTheme()}),
      child: StratumApplication(
        initialThemeId: 'x',
        error: error,
        appBuilder: (c, s) =>
            MaterialApp(builder: s.builder, home: const Text('home')),
      ),
    );

/// An update check whose every ask returns [answer].
class _OneAnswer implements UpdateChecker {
  const new(this.answer);

  final Future<UpdateStatus> answer;

  @override
  Future<UpdateStatus> check() => answer;
}

/// A controller whose active theme holds no dark data; only listening and
/// [themes] work, so its app must not call `stratum.builder`.
class _NoDarkController extends ChangeNotifier
    implements StratumThemeController {
  @override
  final StratumThemeSet themes = StratumThemeSet(light: defaultThemeSet.light);

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A counter whose own [State] would reset if its ancestor remounted
/// (edge case: `StratumApplication.controller` moving null to non-null).
class _Counter extends StatefulWidget {
  const new();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _count++),
    child: Text('$_count'),
  );
}

/// A `RouteInformationParser` with one route: this file's `MaterialApp.router`
/// test pushes pages directly on its delegate, never through route
/// information.
class _NoOpRouteInformationParser extends RouteInformationParser<Object> {
  @override
  Future<Object> parseRouteInformation(RouteInformation information) async =>
      Object();
}

/// A `RouterDelegate` whose page stack grows with [push], for the
/// `MaterialApp.router` test that pushes a second page (us13/fr02).
class _StackRouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  List<Page<void>> _pages = const [
    MaterialPage<void>(key: ValueKey('home'), child: Text('home')),
  ];

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  /// Appends [page] to the stack.
  void push(Page<void> page) {
    _pages = [..._pages, page];
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: _pages,
    onDidRemovePage: (page) => _pages = _pages.where((p) => p != page).toList(),
  );

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
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
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1000, 800);
    addTearDown(tester.view.reset);
    final controller = await _controller();
    StratumAppConfig? seen;
    await tester.pumpWidget(
      StratumApplication(
        controller: controller,
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
    final textScaler = MediaQuery.textScalerOf(
      tester.element(find.byType(StratumApplication)),
    );
    ThemeData material(StratumThemeData data) => data.toThemeData(
      locale: const Locale('en', 'US'),
      windowSize: WindowSize.tablet,
      textScaler: textScaler,
    );
    expect(seen!.theme, material(controller.themes.light));
    expect(seen!.darkTheme, material(controller.themes.dark!));
  });

  testWidgets('us13/fr02: a theme with no dark data hands a null '
      'darkTheme', (tester) async {
    final controller = _NoDarkController();
    addTearDown(controller.dispose);
    StratumAppConfig? seen;
    await tester.pumpWidget(
      StratumApplication(
        controller: controller,
        appBuilder: (c, s) {
          seen = s;
          return const SizedBox();
        },
      ),
    );
    expect(seen!.darkTheme, isNull);
    expect(seen!.theme.brightness, Brightness.light);
  });

  testWidgets('us13/fr01: with no controller, the preloaded theme reaches '
      'the app under every layer; unmount disposes it', (tester) async {
    StratumThemeController? preloaded;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: FakeThemeBundle(themes: {'brand': _brandTheme}),
        child: StratumApplication(
          initialThemeId: 'brand',
          appBuilder: (c, s) => MaterialApp(
            builder: s.builder,
            home: Builder(
              builder: (context) {
                preloaded = StratumThemeController.maybeOf(context);
                return const Text('home');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final host = find.descendant(
      of: find.byType(StratumThemeApplication),
      matching: find.byType(StratumToastHost),
    );
    expect(
      find.descendant(of: host, matching: find.text('home')),
      findsOneWidget,
    );
    expect(preloaded!.activeId, 'brand');
    expect(
      _backgroundBox(StratumApplication.noSplashLightBackground),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    expect(() => preloaded!.addListener(() {}), throwsFlutterError);
  });

  testWidgets('us13/fr01/e07: with no error frame, a start theme that fails '
      'keeps the background and is reported once', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(_failingStart());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<StratumThemeFormatException>());
    expect(
      _backgroundBox(StratumApplication.noSplashLightBackground),
      findsOneWidget,
    );
    expect(find.text('home'), findsNothing);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      _backgroundBox(StratumApplication.noSplashDarkBackground),
      findsOneWidget,
    );
  });

  testWidgets('us13/fr01/e07: with an error frame, a start theme that fails '
      'shows that frame, unreported', (tester) async {
    await tester.pumpWidget(
      _failingStart(
        error: (context, error) => Text(
          'failed ${error.runtimeType}',
          textDirection: TextDirection.ltr,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('failed StratumThemeFormatException'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      _backgroundBox(StratumApplication.noSplashLightBackground),
      findsNothing,
    );
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
      'builder again with the new theme', (tester) async {
    final controller = await StratumThemeController.preload(
      bundle: FakeThemeBundle(themes: {'brand': _brandTheme}),
    );
    StratumAppConfig? seen;
    await tester.pumpWidget(
      StratumApplication(
        controller: controller,
        appBuilder: (c, s) {
          seen = s;
          return MaterialApp(builder: s.builder, home: const Text('home'));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(seen!.theme.colorScheme.primary, isNot(_brandRed));
    await controller.switchTo('brand');
    await tester.pump();
    expect(seen!.theme.colorScheme.primary, _brandRed);
  });

  testWidgets('us13/fr02/e03: a resize inside one window size class runs '
      'the app builder no extra time', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1250, 900);
    addTearDown(tester.view.reset);
    var calls = 0;
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) {
          calls++;
          return MaterialApp(builder: s.builder, home: const Text('home'));
        },
      ),
    );
    await tester.pumpAndSettle();
    final before = calls;
    for (final width in [1300.0, 1400.0, 1500.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
    }
    expect(calls, before);
    tester.view.physicalSize = const Size(1700, 900);
    await tester.pump();
    expect(calls, before + 1);
  });

  testWidgets('us13/fr02/e03: a platform locale change runs the app '
      'builder again', (tester) async {
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final controller = await _controller();
    var calls = 0;
    StratumAppConfig? seen;
    await tester.pumpWidget(
      StratumApplication(
        controller: controller,
        appBuilder: (c, s) {
          calls++;
          seen = s;
          return MaterialApp(builder: s.builder, home: const Text('home'));
        },
      ),
    );
    await tester.pumpAndSettle();
    final before = calls;
    tester.platformDispatcher.localeTestValue = const Locale('th');
    await tester.pump();
    expect(calls, before + 1);
    expect(
      seen!.theme,
      controller.themes.light.toThemeData(
        locale: const Locale('th'),
        windowSize: WindowSize.fromSize(
          tester.view.physicalSize / tester.view.devicePixelRatio,
        ),
        textScaler: MediaQuery.textScalerOf(
          tester.element(find.byType(StratumApplication)),
        ),
      ),
    );
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

  testWidgets('us13/fr04/e03: a required answer hides a shown notice and '
      'an open dialog', (tester) async {
    final answer = Completer<UpdateStatus>();
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        updateGate: (child) => StratumUpdateGate(
          checker: _OneAnswer(answer.future),
          builder: (context, gate) => const Text('Required'),
          child: child,
        ),
        appBuilder: (context, stratum) => MaterialApp(
          builder: stratum.builder,
          home: Scaffold(
            body: Builder(
              builder: (b) => TextButton(
                onPressed: () {
                  b.showToast(message: 'Notice');
                  unawaited(
                    showDialog<void>(
                      context: b,
                      builder: (_) => const Text('Dialog'),
                    ),
                  );
                },
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
    expect(find.text('Notice'), findsOneWidget);
    expect(find.text('Dialog'), findsOneWidget);
    answer.complete(UpdateStatus.required);
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Notice'), findsNothing);
    expect(find.text('Dialog'), findsNothing);
  });

  testWidgets('us13/fr01/e01: all four inner layers keep their order, and '
      'notices false keeps the gate over web zoom', (tester) async {
    final controller = await _controller();
    final answer = Completer<UpdateStatus>();
    Widget app({required bool notices}) => StratumApplication(
      controller: controller,
      notices: notices,
      webZoom: (child) => StratumWebZoom(child: child),
      updateGate: (child) => StratumUpdateGate(
        checker: _OneAnswer(answer.future),
        builder: (context, gate) => const Text('Required'),
        child: child,
      ),
      appBuilder: (c, s) =>
          MaterialApp(builder: s.builder, home: const Text('home')),
    );
    Finder under(Finder of, Type type) =>
        find.descendant(of: of, matching: find.byType(type));
    final gate = under(find.byType(StratumThemeApplication), StratumUpdateGate);

    await tester.pumpWidget(app(notices: true));
    await tester.pumpAndSettle();
    final hosted = under(under(gate, StratumToastHost), StratumWebZoom);
    expect(under(hosted, Navigator), findsOneWidget);

    await tester.pumpWidget(app(notices: false));
    await tester.pumpAndSettle();
    expect(find.byType(StratumToastHost), findsNothing);
    expect(under(under(gate, StratumWebZoom), Navigator), findsOneWidget);
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

  testWidgets('us13/fr01/e01: adding updateGate on a rebuild keeps the '
      'pushed route', (tester) async {
    final controller = await _controller();
    Widget app({required bool gate}) => StratumApplication(
      controller: controller,
      updateGate: gate
          ? (child) => StratumUpdateGate(
              checker: _OneAnswer(Future.value(UpdateStatus.upToDate)),
              builder: (context, g) => const Text('Required'),
              child: child,
            )
          : null,
      appBuilder: (c, s) => MaterialApp(
        builder: s.builder,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Text('pushed')),
            ),
            child: const Text('home'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(gate: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);
    await tester.pumpWidget(app(gate: true));
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);
  });

  testWidgets('us13/fr01/e01: removing webZoom on a rebuild keeps the '
      'pushed route', (tester) async {
    final controller = await _controller();
    Widget app({required bool zoom}) => StratumApplication(
      controller: controller,
      webZoom: zoom ? (child) => StratumWebZoom(child: child) : null,
      appBuilder: (c, s) => MaterialApp(
        builder: s.builder,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Text('pushed')),
            ),
            child: const Text('home'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(zoom: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);
    await tester.pumpWidget(app(zoom: false));
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);
  });

  testWidgets('us13/fr01: controller moving from null to non-null keeps '
      'the app widget mounted', (tester) async {
    final controller = await _controller();
    Widget app(StratumThemeController? c) => DefaultAssetBundle(
      bundle: FakeThemeBundle(),
      child: StratumApplication(
        controller: c,
        appBuilder: (context, s) =>
            MaterialApp(builder: s.builder, home: const _Counter()),
      ),
    );
    await tester.pumpWidget(app(null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('us13/fr01: a nested wrapper sharing the outer '
      'controller works, with notices false', (tester) async {
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => MaterialApp(
          builder: s.builder,
          home: Builder(
            builder: (outer) => StratumApplication(
              controller: StratumThemeController.of(outer),
              notices: false,
              appBuilder: (c2, s2) => MaterialApp(
                builder: s2.builder,
                home: Builder(
                  builder: (inner) => TextButton(
                    onPressed: () => inner.showToast(message: 'Hello'),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('us13/fr02: MaterialApp.router renders a pushed page under '
      "the toast host, with no route of the wrapper's own", (tester) async {
    final provider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: Uri.parse('/')),
    );
    final delegate = _StackRouterDelegate();
    addTearDown(provider.dispose);
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      StratumApplication(
        controller: await _controller(),
        appBuilder: (c, s) => MaterialApp.router(
          routerConfig: RouterConfig<Object>(
            routeInformationProvider: provider,
            routeInformationParser: _NoOpRouteInformationParser(),
            routerDelegate: delegate,
          ),
          builder: s.builder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(Navigator), findsOneWidget);
    delegate.push(
      const MaterialPage<void>(key: ValueKey('pushed'), child: Text('pushed')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(StratumToastHost),
        matching: find.text('pushed'),
      ),
      findsOneWidget,
    );
    expect(find.text('home'), findsNothing);
    expect(find.byType(Navigator), findsOneWidget);
  });

  testWidgets('us13/fr01/e01: adding updateGate on a rebuild keeps the '
      'Router State identity and the pushed page, with MaterialApp.router', (
    tester,
  ) async {
    final controller = await _controller();
    final provider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: Uri.parse('/')),
    );
    final delegate = _StackRouterDelegate();
    addTearDown(provider.dispose);
    addTearDown(delegate.dispose);
    Widget app({required bool gate}) => StratumApplication(
      controller: controller,
      updateGate: gate
          ? (child) => StratumUpdateGate(
              checker: _OneAnswer(Future.value(UpdateStatus.upToDate)),
              builder: (context, g) => const Text('Required'),
              child: child,
            )
          : null,
      appBuilder: (c, s) => MaterialApp.router(
        routerConfig: RouterConfig<Object>(
          routeInformationProvider: provider,
          routeInformationParser: _NoOpRouteInformationParser(),
          routerDelegate: delegate,
        ),
        builder: s.builder,
      ),
    );
    await tester.pumpWidget(app(gate: false));
    await tester.pumpAndSettle();
    delegate.push(
      const MaterialPage<void>(key: ValueKey('pushed'), child: Text('pushed')),
    );
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);
    final before = tester.state(find.byType(Router<Object>));
    await tester.pumpWidget(app(gate: true));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(Router<Object>)), same(before));
    expect(find.text('pushed'), findsOneWidget);
  });
}
