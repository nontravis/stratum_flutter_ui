// NFR-U01, NFR-U07 n/a: the splash paints no text, border, focus ring, or
// icon of its own; the app's builder draws every frame.
// NFR-U02: proven below — Tab reaches a focusable retry button in a failed
// frame, and Enter activates it, through the splash's own default
// Shortcuts/Actions.
// NFR-U04 n/a: the splash paints no text; the loading label is semantics
// only.
// NFR-U05 n/a: the splash has no interactive target.
// NFR-U08 n/a: each state reaches the app's builder as a sealed type, never
// as a color.
// NFR-U09 n/a: the splash takes no gesture.
// NFR-E01 n/a: the splash draws no visual value of its own; the app's
// builder draws every frame from the app's theme.
// NFR-E02 n/a: the splash draws nothing a customStyle could style; the
// widgets the app's builder returns take their own customStyle.
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';

import '../../themes/theme_runtime_fakes.dart';

/// The text the test builder draws for [state], so a finder reads which
/// state is on screen.
String _nameOf(StratumSplashState<Object?> state) => switch (state) {
  StratumSplashLoadingTheme() => 'loading theme',
  StratumSplashLoadingApp() => 'loading app',
  StratumSplashFailed(:final phase) => 'failed ${phase.name}',
  StratumSplashDone(:final data) => 'done $data',
};

/// A splash over [bundle] whose builder adds each state it gets to
/// [states] and draws [_nameOf] it.
Widget _splash(
  AssetBundle bundle, {
  required Future<String> Function() postload,
  String? initialThemeId,
  List<StratumSplashState<String>>? states,
  Duration minimumDuration = Duration.zero,
}) => DefaultAssetBundle(
  bundle: bundle,
  child: StratumSplashScreen<String>(
    initialThemeId: initialThemeId,
    minimumDuration: minimumDuration,
    postload: (context, controller) => postload(),
    builder: (context, state) {
      states?.add(state);
      return Text(_nameOf(state), textDirection: TextDirection.ltr);
    },
  ),
);

/// The state [_splash]'s builder got last.
StratumSplashState<String> _last(List<StratumSplashState<String>> states) =>
    states.last;

const Key _frame = ValueKey('frame');
const Key _app = ValueKey('app');

/// A splash whose builder draws a full-size frame until done, then a
/// full-size app, exiting by [type] (else the default), [duration], and
/// [curve]; [work] ends its postload. Under app reduced motion when
/// [reduced].
Widget _exit(
  Completer<String> work, {
  ScreenTransitionType? type,
  Duration? duration,
  Curve? curve,
  bool reduced = false,
}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: DefaultAssetBundle(
      bundle: FakeThemeBundle(),
      child: StratumSplashScreen<String>(
        exitTransition: type ?? ScreenTransitionType.fadeThrough,
        exitDuration: duration,
        exitCurve: curve,
        postload: (context, controller) => work.future,
        builder: (context, state) => switch (state) {
          StratumSplashDone() => const SizedBox.expand(key: _app),
          _ => const SizedBox.expand(key: _frame),
        },
      ),
    ),
  ),
);

/// The rect a person sees [key]'s box take: its layout rect moved, scaled,
/// and turned by every transition above it.
Rect _seen(WidgetTester tester, Key key) {
  final box = tester.renderObject<RenderBox>(find.byKey(key));
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// The whole test view, where the app ends.
const _screen = Rect.fromLTWH(0, 0, 800, 600);

void main() {
  // Scoped to this file: `flutter test` runs each file in its own process.
  LeakTesting.enable();
  setUp(ThemeFontLoader.reset);

  group('StratumSplashScreen preload and postload', () {
    testWidgets('us12/fr01, us12/s1: the builder gets loading app, then '
        'done with the result and the controller', (tester) async {
      final states = <StratumSplashState<String>>[];
      final work = Completer<String>();
      await tester.pumpWidget(
        _splash(FakeThemeBundle(), postload: () => work.future, states: states),
      );
      await tester.pumpAndSettle();
      expect(find.text('loading app'), findsOneWidget);

      work.complete('ready');
      await tester.pump(Duration.zero);

      expect(find.text('done ready'), findsOneWidget);
      final loading = states.whereType<StratumSplashLoadingApp<String>>().first;
      final done = _last(states) as StratumSplashDone<String>;
      expect(done.controller, same(loading.controller));
      expect(done.controller.activeId, 'default');
    });

    testWidgets('us12/fr01: postload runs once, with the controller of the '
        'start theme', (tester) async {
      final controllers = <StratumThemeController>[];
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FakeThemeBundle(themes: {'brand': appTheme()}),
          child: StratumSplashScreen<int>(
            initialThemeId: 'brand',
            postload: (context, controller) async {
              controllers.add(controller);
              return 1;
            },
            builder: (context, state) =>
                const SizedBox.shrink(key: ValueKey('frame')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controllers, hasLength(1));
      expect(controllers.single.activeId, 'brand');
    });

    testWidgets('us12/fr01/e01, us12/s11: a start theme that fails to load '
        'shows failed with the theme step and the format report', (
      tester,
    ) async {
      final states = <StratumSplashState<String>>[];
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(themes: {'brand': brokenTheme()}),
          initialThemeId: 'brand',
          postload: () async => 'never',
          states: states,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('failed theme'), findsOneWidget);
      expect(
        (_last(states) as StratumSplashFailed<String>).error,
        isA<StratumThemeFormatException>(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('us12/fr01/e02, us12/s9: postload that throws shows failed '
        'with the postload step and the thrown error', (tester) async {
      final states = <StratumSplashState<String>>[];
      final thrown = StateError('offline');
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          postload: () async => throw thrown,
          states: states,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('failed postload'), findsOneWidget);
      expect(
        (_last(states) as StratumSplashFailed<String>).error,
        same(thrown),
      );
    });

    testWidgets('us12/fr01/e03: a result after the splash left the tree is '
        'dropped and the controller is disposed', (tester) async {
      final states = <StratumSplashState<String>>[];
      final work = Completer<String>();
      await tester.pumpWidget(
        _splash(FakeThemeBundle(), postload: () => work.future, states: states),
      );
      await tester.pumpAndSettle();
      final controller =
          (_last(states) as StratumSplashLoadingApp<String>).controller;

      await tester.pumpWidget(const SizedBox.shrink());
      work.complete('late');
      await tester.pumpAndSettle();

      expect(states.whereType<StratumSplashDone<String>>(), isEmpty);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      expect(tester.takeException(), isNull);
    });

    testWidgets('us12/fr01/e04, us12/fr01/e05: done reaches the builder, '
        'which returns the app itself; the splash pushes no route', (
      tester,
    ) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FakeThemeBundle(),
          child: StratumSplashScreen<String>(
            postload: (context, controller) async => 'ready',
            builder: (context, state) => switch (state) {
              StratumSplashDone() => const MaterialApp(home: Text('home')),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      );
      expect(find.byType(Navigator), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(Navigator), findsOneWidget);
    });
  });

  group('StratumSplashScreen first-frame hold', () {
    testWidgets('us12/fr02, us12/s2: no frame reaches the engine until the '
        'start theme is active; the builder first runs then', (tester) async {
      final bundle = FakeThemeBundle();
      final release = bundle.hold[packageDefaultKey] = Completer<void>();
      final states = <StratumSplashState<String>>[];
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(
        _splash(
          bundle,
          postload: () => Completer<String>().future,
          states: states,
        ),
      );
      await tester.pump();
      expect(tester.binding.sendFramesToEngine, isFalse);
      expect(states, isEmpty);

      release.complete();
      await tester.pumpAndSettle();

      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(states.first, isA<StratumSplashLoadingApp<String>>());
    });

    testWidgets('us12/fr02/e01: the builder never gets loading theme at '
        'launch', (tester) async {
      final states = <StratumSplashState<String>>[];
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          postload: () async => 'ready',
          states: states,
        ),
      );
      await tester.pumpAndSettle();

      expect(states.whereType<StratumSplashLoadingTheme<String>>(), isEmpty);
    });

    testWidgets('us12/fr02/e03: a start theme that fails ends the hold on '
        'the failed state', (tester) async {
      final states = <StratumSplashState<String>>[];
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(themes: {'brand': brokenTheme()}),
          initialThemeId: 'brand',
          postload: () async => 'never',
          states: states,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(states.first, isA<StratumSplashFailed<String>>());
    });

    testWidgets('a splash that leaves the tree mid-preload frees the frames', (
      tester,
    ) async {
      final bundle = FakeThemeBundle();
      final release = bundle.hold[packageDefaultKey] = Completer<void>();
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(_splash(bundle, postload: () async => 'never'));
      expect(tester.binding.sendFramesToEngine, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      release.complete();
      await tester.pumpAndSettle();

      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('StratumSplashScreen minimum display time', () {
    testWidgets('us12/fr03, us12/s4: a 2 s minimum holds a 1 s postload until '
        '2 s after the first frame', (tester) async {
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          minimumDuration: const Duration(seconds: 2),
          postload: () =>
              Future.delayed(const Duration(seconds: 1), () => 'ready'),
        ),
      );
      await tester.pump();
      expect(find.text('loading app'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1999));
      expect(find.text('loading app'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('done ready'), findsOneWidget);
    });

    testWidgets('us12/fr03/e01: with no minimum, done shows when postload '
        'returns', (tester) async {
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          postload: () =>
              Future.delayed(const Duration(seconds: 1), () => 'ready'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.text('loading app'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('done ready'), findsOneWidget);
    });

    testWidgets('us12/fr03/e03: postload that outlasts the minimum ends the '
        'splash when it returns', (tester) async {
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          minimumDuration: const Duration(seconds: 1),
          postload: () =>
              Future.delayed(const Duration(seconds: 3), () => 'ready'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('loading app'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('done ready'), findsOneWidget);
    });

    testWidgets('us12/fr03/e02, us12/fr06/e04: a retry does not restart the '
        'minimum', (tester) async {
      final states = <StratumSplashState<String>>[];
      var calls = 0;
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          minimumDuration: const Duration(seconds: 2),
          states: states,
          postload: () async {
            calls += 1;
            if (calls == 1) throw StateError('offline');
            return 'ready';
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      (_last(states) as StratumSplashFailed<String>).retry();
      await tester.pump();
      expect(find.text('loading app'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('done ready'), findsOneWidget);
    });
  });

  group('StratumSplashScreen retry', () {
    testWidgets('us12/fr06, us12/s10: retry after a postload failure shows '
        'loading app, runs postload again, then done', (tester) async {
      final states = <StratumSplashState<String>>[];
      var calls = 0;
      final second = Completer<String>();
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          states: states,
          postload: () {
            calls += 1;
            if (calls == 1) return Future.error(StateError('offline'));
            return second.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('failed postload'), findsOneWidget);

      (_last(states) as StratumSplashFailed<String>).retry();
      await tester.pump();
      expect(find.text('loading app'), findsOneWidget);
      expect(calls, 2);

      second.complete('ready');
      await tester.pump(Duration.zero);
      expect(find.text('done ready'), findsOneWidget);
    });

    testWidgets('us12/fr06/e01: retry after a theme format failure shows '
        'loading theme and fails again with the same report', (tester) async {
      final bundle = FakeThemeBundle(themes: {'brand': brokenTheme()});
      final states = <StratumSplashState<String>>[];
      await tester.pumpWidget(
        _splash(
          bundle,
          initialThemeId: 'brand',
          postload: () async => 'never',
          states: states,
        ),
      );
      await tester.pumpAndSettle();
      final first = _last(states) as StratumSplashFailed<String>;
      final release = bundle.hold[themeKey('brand')] = Completer<void>();

      first.retry();
      await tester.pump();
      expect(find.text('loading theme'), findsOneWidget);

      release.complete();
      await tester.pumpAndSettle();
      final again = _last(states) as StratumSplashFailed<String>;
      expect(again.phase, StratumSplashPhase.theme);
      expect(again.error, isA<StratumThemeFormatException>());
      expect(bundle.reads[themeKey('brand')], 2);
    });

    testWidgets('us12/fr06/e03: the package retries nothing by itself', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          postload: () async {
            calls += 1;
            throw StateError('offline');
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(minutes: 1));

      expect(calls, 1);
      expect(find.text('failed postload'), findsOneWidget);
    });

    testWidgets('a second tap on retry runs the failed step once', (
      tester,
    ) async {
      final states = <StratumSplashState<String>>[];
      var calls = 0;
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          states: states,
          postload: () {
            calls += 1;
            if (calls == 1) return Future.error(StateError('offline'));
            return Completer<String>().future;
          },
        ),
      );
      await tester.pumpAndSettle();
      (_last(states) as StratumSplashFailed<String>)
        ..retry()
        ..retry();
      await tester.pump();

      expect(calls, 2);
    });

    testWidgets(
      'a stale retry after the screen moved on to done runs nothing',
      (tester) async {
        final states = <StratumSplashState<String>>[];
        var calls = 0;
        final second = Completer<String>();
        await tester.pumpWidget(
          _splash(
            FakeThemeBundle(),
            states: states,
            postload: () {
              calls += 1;
              if (calls == 1) return Future.error(StateError('offline'));
              return second.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        final first = _last(states) as StratumSplashFailed<String>;

        first.retry();
        await tester.pump();
        expect(calls, 2);

        second.complete('ready');
        await tester.pump(Duration.zero);
        expect(find.text('done ready'), findsOneWidget);

        first.retry();
        await tester.pump();

        expect(calls, 2);
        expect(find.text('done ready'), findsOneWidget);
      },
    );

    testWidgets('us12/fr06: a postload failure keeps its stack trace', (
      tester,
    ) async {
      final states = <StratumSplashState<String>>[];
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(),
          states: states,
          postload: () async {
            throw StateError('offline');
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        (_last(states) as StratumSplashFailed<String>).stackTrace,
        isNot(StackTrace.empty),
      );
    });

    testWidgets(
      'us12/fr06/e01: a theme format failure keeps its stack trace too',
      (tester) async {
        final states = <StratumSplashState<String>>[];
        await tester.pumpWidget(
          _splash(
            FakeThemeBundle(themes: {'brand': brokenTheme()}),
            initialThemeId: 'brand',
            postload: () async => 'never',
            states: states,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          (_last(states) as StratumSplashFailed<String>).stackTrace,
          isNot(StackTrace.empty),
        );
      },
    );
  });

  group('StratumSplashScreen hosts its frames', () {
    /// A splash over [bundle] whose builder hands [seen] the context of
    /// every frame, by state.
    Widget host(
      AssetBundle bundle,
      Map<Type, BuildContext> seen, {
      String? initialThemeId,
      ThemeMode themeMode = ThemeMode.system,
      HighContrastMode highContrast = HighContrastMode.system,
      Future<String> Function()? postload,
      Widget Function(StratumSplashDone<String> state)? app,
      List<StratumSplashState<String>>? states,
    }) => DefaultAssetBundle(
      bundle: bundle,
      child: StratumSplashScreen<String>(
        initialThemeId: initialThemeId,
        themeMode: themeMode,
        highContrast: highContrast,
        postload: (context, controller) =>
            (postload ?? () => Completer<String>().future)(),
        builder: (context, state) {
          if (state case final StratumSplashDone<String> done
              when app != null) {
            return app(done);
          }
          seen[state.runtimeType] = context;
          states?.add(state);
          return const SizedBox.shrink();
        },
      ),
    );

    testWidgets('us12/fr07: a frame reads the start theme, the window '
        'metrics, and a text direction', (tester) async {
      final seen = <Type, BuildContext>{};
      await tester.pumpWidget(host(FakeThemeBundle(), seen));
      await tester.pumpAndSettle();
      final context = seen[StratumSplashLoadingApp<String>]!;
      final controller = StratumThemeController.of(context);

      expect(
        StratumThemeApplication.of(context),
        same(controller.themes.pick(dark: false, highContrast: false)),
      );
      expect(MediaQuery.maybeOf(context), isNotNull);
      expect(Directionality.of(context), TextDirection.ltr);
    });

    testWidgets('us12/fr07, us12/s7: the theme mode and high-contrast mode '
        'the app passes pick the data', (tester) async {
      final seen = <Type, BuildContext>{};
      await tester.pumpWidget(
        host(
          FakeThemeBundle(),
          seen,
          themeMode: ThemeMode.dark,
          highContrast: HighContrastMode.on,
        ),
      );
      await tester.pumpAndSettle();
      final context = seen[StratumSplashLoadingApp<String>]!;

      expect(
        StratumThemeApplication.of(context),
        same(
          StratumThemeController.of(context).themes
              .pick(dark: true, highContrast: true),
        ),
      );
    });

    testWidgets('us12/fr07/e02: the splash and the app it returns draw the '
        'same data', (tester) async {
      final seen = <Type, BuildContext>{};
      late StratumThemeData appData;
      final work = Completer<String>();
      await tester.pumpWidget(
        host(
          FakeThemeBundle(),
          seen,
          themeMode: ThemeMode.dark,
          postload: () => work.future,
          app: (done) => StratumThemeApplication.controlled(
            controller: done.controller,
            themeMode: ThemeMode.dark,
            child: Builder(
              builder: (context) {
                appData = StratumThemeApplication.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final splashData = StratumThemeApplication.of(
        seen[StratumSplashLoadingApp<String>]!,
      );

      work.complete('ready');
      await tester.pumpAndSettle();

      expect(appData, same(splashData));
    });

    testWidgets('us12/fr07/e01: after a theme failure, the failed frame and '
        'the loading theme frames of its retry read the package default '
        'alone', (tester) async {
      final bundle = FakeThemeBundle(
        themes: {'default': markTheme('app-mark'), 'brand': brokenTheme()},
      );
      final seen = <Type, BuildContext>{};
      final states = <StratumSplashState<String>>[];
      await tester.pumpWidget(
        host(bundle, seen, initialThemeId: 'brand', states: states),
      );
      await tester.pumpAndSettle();
      Iterable<String> fontsOf(Type state) =>
          StratumThemeApplication.of(seen[state]!).typography.fonts.keys;
      expect(fontsOf(StratumSplashFailed<String>), contains('inter'));
      expect(fontsOf(StratumSplashFailed<String>), isNot(contains('app-mark')));

      final release = bundle.hold[themeKey('brand')] = Completer<void>();
      (states.last as StratumSplashFailed<String>).retry();
      await tester.pump();

      expect(fontsOf(StratumSplashLoadingTheme<String>), contains('inter'));
      expect(
        fontsOf(StratumSplashLoadingTheme<String>),
        isNot(contains('app-mark')),
      );
      release.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('us12/fr07/e03, nfr-l02: the text direction follows the '
        'platform locale', (tester) async {
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      for (final (language, direction) in [
        ('ar', TextDirection.rtl),
        ('ja', TextDirection.ltr),
      ]) {
        tester.platformDispatcher.localeTestValue = Locale(language);
        final seen = <Type, BuildContext>{};
        await tester.pumpWidget(host(FakeThemeBundle(), seen));
        await tester.pumpAndSettle();

        expect(
          Directionality.of(seen[StratumSplashLoadingApp<String>]!),
          direction,
          reason: language,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a package default theme that cannot be read is reported, '
        'and the hold still ends on the failed state', (tester) async {
      final states = <StratumSplashState<String>>[];
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(
        _splash(
          FakeThemeBundle(packageDefault: 'spcae:\n  md: 12'),
          postload: () async => 'never',
          states: states,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<StratumThemeFormatException>());
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(_last(states), isA<StratumSplashFailed<String>>());
    });

    testWidgets(
      "NFR-U02, us12/fr07: Tab reaches a failed frame's retry button, and "
      'Enter activates it',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FakeThemeBundle(),
            child: StratumSplashScreen<String>(
              postload: (context, controller) async {
                calls += 1;
                throw StateError('offline');
              },
              builder: (context, state) => switch (state) {
                StratumSplashFailed(:final retry) => TextButton(
                  onPressed: retry,
                  child: const Text('Retry'),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(Focus.of(tester.element(find.text('Retry'))).hasFocus, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(Focus.of(tester.element(find.text('Retry'))).hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(calls, 2);
      },
    );
  });

  group('StratumSplashScreen exit in place', () {
    testWidgets('us12/fr04, us12/s1: by default the app fades through in '
        'place over the theme slow level, 300 ms', (tester) async {
      final work = Completer<String>();
      await tester.pumpWidget(_exit(work));
      await tester.pumpAndSettle();

      work.complete('ready');
      await tester.pump(Duration.zero);
      expect(find.byKey(_frame), findsOneWidget);
      expect(find.byKey(_app), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byKey(_frame), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(_seen(tester, _app), _screen);
      // The exit ends on the first frame past its duration
      // (`_InterpolationSimulation.isDone`), and the splash frame goes then.
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(_frame), findsNothing);
      expect(find.byType(Navigator), findsNothing);
    });

    testWidgets('us12/fr04, us12/s5: a right-to-left exit slides the app in '
        'from the right over the splash in 300 ms', (tester) async {
      final work = Completer<String>();
      await tester.pumpWidget(
        _exit(work, type: ScreenTransitionType.rightToLeft),
      );
      await tester.pumpAndSettle();

      work.complete('ready');
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_seen(tester, _app).left, inExclusiveRange(0, 800));
      expect(_seen(tester, _frame), _screen);

      await tester.pump(const Duration(milliseconds: 150));
      expect(_seen(tester, _app), _screen);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(_frame), findsNothing);
    });

    testWidgets('us12/fr04/e04: an exit duration and curve replace the '
        "theme's", (tester) async {
      final work = Completer<String>();
      await tester.pumpWidget(
        _exit(
          work,
          type: ScreenTransitionType.rightToLeft,
          duration: const Duration(milliseconds: 100),
          // A test may name another curve to measure a value.
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();

      work.complete('ready');
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 25));
      expect(_seen(tester, _app).left, 600);

      await tester.pump(const Duration(milliseconds: 75));
      expect(_seen(tester, _app), _screen);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(_frame), findsNothing);
    });

    testWidgets('the app keeps its own state when the exit ends', (
      tester,
    ) async {
      final work = Completer<String>();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FakeThemeBundle(),
          child: StratumSplashScreen<String>(
            postload: (context, controller) => work.future,
            builder: (context, state) => switch (state) {
              StratumSplashDone() => const MaterialApp(home: Text('home')),
              _ => const SizedBox.expand(key: _frame),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      work.complete('ready');
      await tester.pump(Duration.zero);
      final during = tester.state(find.byType(MaterialApp));

      await tester.pumpAndSettle();

      expect(find.byKey(_frame), findsNothing);
      expect(tester.state(find.byType(MaterialApp)), same(during));
    });

    testWidgets('the app keeps its own state through a disableAnimations flip '
        'after the exit', (tester) async {
      final work = Completer<String>();
      var reduced = false;
      Widget host() => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: DefaultAssetBundle(
            bundle: FakeThemeBundle(),
            child: StratumSplashScreen<String>(
              postload: (context, controller) => work.future,
              builder: (context, state) => switch (state) {
                StratumSplashDone() => const MaterialApp(home: Text('home')),
                _ => const SizedBox.expand(key: _frame),
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      work.complete('ready');
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();
      final during = tester.state(find.byType(MaterialApp));

      reduced = true;
      await tester.pumpWidget(host());
      await tester.pump();

      expect(tester.state(find.byType(MaterialApp)), same(during));
    });

    testWidgets(
      'the app keeps its own state through platform reduced motion plus '
      'a theme switchTo after the exit',
      (tester) async {
        final work = Completer<String>();
        final states = <StratumSplashState<String>>[];
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FakeThemeBundle(themes: {'brand': appTheme()}),
            child: StratumSplashScreen<String>(
              postload: (context, controller) => work.future,
              builder: (context, state) {
                states.add(state);
                return switch (state) {
                  StratumSplashDone() => const MaterialApp(home: Text('home')),
                  _ => const SizedBox.expand(key: _frame),
                };
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        work.complete('ready');
        await tester.pump(Duration.zero);
        await tester.pumpAndSettle();
        final during = tester.state(find.byType(MaterialApp));

        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller =
            (_last(states) as StratumSplashDone<String>).controller;
        await controller.switchTo('brand');
        await tester.pump();

        expect(tester.state(find.byType(MaterialApp)), same(during));
      },
    );

    testWidgets('a childless frame lays out at the size of the view', (
      tester,
    ) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FakeThemeBundle(),
          child: StratumSplashScreen<String>(
            postload: (context, controller) => Completer<String>().future,
            builder: (context, state) =>
                const ColoredBox(color: Color(0xFF000000), key: _frame),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byKey(_frame)), _screen.size);
    });

    testWidgets('us12/fr04/e02: none shows the app at once', (tester) async {
      final work = Completer<String>();
      await tester.pumpWidget(_exit(work, type: ScreenTransitionType.none));
      await tester.pumpAndSettle();

      work.complete('ready');
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(find.byKey(_frame), findsNothing);
      expect(_seen(tester, _app), _screen);
    });

    for (final type in [
      ScreenTransitionType.platform,
      ScreenTransitionType.cupertino,
    ]) {
      testWidgets('us12/fr04/e01: $type fails an assertion that names the '
          'types an exit takes', (tester) async {
        await tester.pumpWidget(_exit(Completer<String>(), type: type));

        expect(
          tester.takeException(),
          isA<AssertionError>().having(
            (error) => '${error.message}',
            'message',
            allOf(
              contains('needs a page route'),
              contains('takes fade, rightToLeft,'),
              contains('fadeThrough'),
              isNot(contains(', platform')),
              isNot(contains(', cupertino')),
            ),
          ),
        );
      });
    }

    for (final type in [
      ScreenTransitionType.fadeThrough,
      ScreenTransitionType.rightToLeft,
    ]) {
      for (final (source, app, platform) in [
        ('no', false, false),
        ('app', true, false),
        ('platform', false, true),
      ]) {
        final reduced = app || platform;
        testWidgets('NFR-U03, us12/fr04/e03, us12/s6: with $source reduced '
            'motion, one frame after done, a ${type.name} exit '
            '${reduced ? 'shows' : 'still moves or scales'} the app where it '
            'ends', (tester) async {
          if (platform) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(reduceMotion: true);
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
          }
          // The target: where the app ends once the exit has settled.
          final settled = Completer<String>();
          await tester.pumpWidget(_exit(settled, type: type, reduced: app));
          await tester.pumpAndSettle();
          settled.complete('ready');
          await tester.pumpAndSettle();
          final target = _seen(tester, _app);
          // A fresh splash; then the same change and one frame. The zero
          // duration flushes postload's result before the frame
          // (flutter_test binding.dart:2249-2263) and lets no time pass.
          await tester.pumpWidget(const SizedBox.shrink());
          final work = Completer<String>();
          await tester.pumpWidget(_exit(work, type: type, reduced: app));
          await tester.pumpAndSettle();
          work.complete('ready');
          await tester.pump(Duration.zero);

          expect(_seen(tester, _app), reduced ? target : isNot(target));
        });
      }
    }
  });

  group('StratumSplashScreen announces loading', () {
    /// A splash whose builder draws a labeled app node, `app <state>`, for
    /// every state, keyed [_frame] while not done.
    Widget announced(
      AssetBundle bundle, {
      String? initialThemeId,
      String? loadingLabel,
      Future<String> Function()? postload,
      List<StratumSplashState<String>>? states,
    }) => DefaultAssetBundle(
      bundle: bundle,
      child: StratumSplashScreen<String>(
        initialThemeId: initialThemeId,
        loadingLabel: loadingLabel,
        postload: (context, controller) =>
            (postload ?? () => Completer<String>().future)(),
        builder: (context, state) {
          states?.add(state);
          return Semantics(
            container: true,
            label: 'app ${_nameOf(state)}',
            child: const SizedBox(width: 40, height: 20),
          );
        },
      ),
    );

    testWidgets('NFR-U06, us12/fr08, us12/s8: a loading app frame sits '
        "under a live region that reads Loading; the app's node reads "
        'unchanged', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(announced(FakeThemeBundle()));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Loading')),
        matchesSemantics(
          label: 'Loading',
          isLiveRegion: true,
          role: SemanticsRole.none,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('app loading app')),
        matchesSemantics(label: 'app loading app'),
      );
      handle.dispose();
    });

    testWidgets('us12/fr08/e01: a loading theme frame of a retry reads '
        'Loading too', (tester) async {
      final handle = tester.ensureSemantics();
      final bundle = FakeThemeBundle(themes: {'brand': brokenTheme()});
      final states = <StratumSplashState<String>>[];
      await tester.pumpWidget(
        announced(bundle, initialThemeId: 'brand', states: states),
      );
      await tester.pumpAndSettle();
      final release = bundle.hold[themeKey('brand')] = Completer<void>();

      (states.last as StratumSplashFailed<String>).retry();
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Loading')),
        matchesSemantics(
          label: 'Loading',
          isLiveRegion: true,
          role: SemanticsRole.none,
        ),
      );
      release.complete();
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets("NFR-U06: the failed and done frames add no node; the app's "
        'node reads unchanged', (tester) async {
      final handle = tester.ensureSemantics();
      final states = <StratumSplashState<String>>[];
      var calls = 0;
      await tester.pumpWidget(
        announced(
          FakeThemeBundle(),
          states: states,
          postload: () async {
            calls += 1;
            if (calls == 1) throw StateError('offline');
            return 'ready';
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Loading'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('app failed postload')),
        matchesSemantics(label: 'app failed postload'),
      );

      (states.last as StratumSplashFailed<String>).retry();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Loading'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('app done ready')),
        matchesSemantics(label: 'app done ready'),
      );
      handle.dispose();
    });

    testWidgets('us12/fr08/e02, nfr-l01: a loading label the app passes '
        'replaces the built-in one', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        announced(FakeThemeBundle(), loadingLabel: 'Starting'),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Loading'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Starting')),
        matchesSemantics(
          label: 'Starting',
          isLiveRegion: true,
          role: SemanticsRole.none,
        ),
      );
      handle.dispose();
    });

    testWidgets('us12/s8, nfr-l01: on a Thai device the announcement reads '
        'Thai', (tester) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.localeTestValue = const Locale('th');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.pumpWidget(announced(FakeThemeBundle()));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('กำลังโหลด')),
        matchesSemantics(
          label: 'กำลังโหลด',
          isLiveRegion: true,
          role: SemanticsRole.none,
        ),
      );
      handle.dispose();
    });

    testWidgets("the app's frame keeps its own state when loading turns "
        'failed', (tester) async {
      final work = Completer<String>();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FakeThemeBundle(),
          child: StratumSplashScreen<String>(
            postload: (context, controller) => work.future,
            builder: (context, state) => const _Spinner(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.state(find.byType(_Spinner));

      work.completeError(StateError('offline'));
      await tester.pump(Duration.zero);

      expect(tester.state(find.byType(_Spinner)), same(before));
    });
  });
}

/// A stand-in for an app frame that keeps state, such as a spinner.
class _Spinner extends StatefulWidget {
  const new();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
