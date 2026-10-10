import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:stratum_ui/src/components/common/splash_screen.dart';
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
  });
}
