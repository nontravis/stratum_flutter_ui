import 'package:animations/animations.dart'
    show FadeThroughTransition, SharedAxisTransition, SharedAxisTransitionType;
import 'package:flutter/cupertino.dart'
    show
        CupertinoPageTransition,
        CupertinoPageTransitionsBuilder,
        CupertinoRouteTransitionMixin;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

/// A [MaterialApp] whose builder places an application of [theme] above
/// the navigator, or none when [theme] is null, and, when [reducedMotion]
/// is true, a [MediaQuery] with `disableAnimations: true` above that.
Widget _app(
  GlobalKey<NavigatorState> navigator, {
  StratumThemeData? theme,
  bool reducedMotion = false,
}) => MaterialApp(
  navigatorKey: navigator,
  builder: (theme == null && !reducedMotion)
      ? null
      : (context, child) {
          var result = theme == null
              ? child!
              : StratumThemeApplication(
                  themes: StratumThemeSet(light: theme),
                  themeMode: ThemeMode.light,
                  child: child!,
                );
          if (reducedMotion) {
            result = MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: result,
            );
          }
          return result;
        },
  home: const SizedBox(key: ValueKey('home')),
);

Future<PageTransition<void>> _push(
  WidgetTester tester, {
  StratumThemeData? theme,
  ScreenTransitionType type = ScreenTransitionType.fade,
  Duration? duration,
  Curve? curve,
  Widget child = const SizedBox(),
  Widget? childCurrent,
  Alignment? alignment,
  bool reducedMotion = false,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    _app(navigator, theme: theme, reducedMotion: reducedMotion),
  );
  final route = PageTransition<void>(
    type: type,
    duration: duration,
    curve: curve,
    child: child,
    childCurrent: childCurrent,
    alignment: alignment,
  );
  navigator.currentState!.push(route).ignore();
  await tester.pump();
  return route;
}

/// A second, time-free pump after [_push]: on the frame a route is pushed,
/// `HeroController` (heroes.dart) marks it offstage until the hero search
/// runs, and `find.byKey`/`find.ancestor` skip an offstage widget by
/// default. A caller that checks the pushed page or its transition widget
/// with no further time-advancing pump needs this first; a caller that
/// already pumps a duration before checking does not.
Future<void> _settleHeroOffstage(WidgetTester tester) => tester.pump();

/// The page keyed `page`.
final Finder _page = find.byKey(const ValueKey('page'));

/// The motion widgets between [_page] and its route.
List<Widget> _transitionsAbove(WidgetTester tester) => tester
    .widgetList(
      find.ancestor(
        of: _page,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is FadeTransition ||
              widget is SlideTransition ||
              widget is ScaleTransition ||
              widget is RotationTransition ||
              widget is SizeTransition ||
              widget is CupertinoPageTransition ||
              widget is FadeThroughTransition ||
              widget is SharedAxisTransition,
        ),
      ),
    )
    .toList();

/// The two reduced-motion signals of NFR-U03. The platform's
/// `disableAnimations` is left out of mid-transition checks: it runs every
/// route controller at 5% of its duration.
enum _Reduce { disableAnimations, reduceMotion }

/// Sets [signal]: the app's `MediaQuery` flag goes through [_push]'s
/// `reducedMotion`, the platform's `reduceMotion` through the test
/// dispatcher.
bool _apply(WidgetTester tester, _Reduce signal) {
  if (signal == _Reduce.reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  return signal == _Reduce.disableAnimations;
}

void main() {
  testWidgets("us11/fr01: a null duration takes the theme's slow level, "
      'the pop at 64%', (tester) async {
    final route = await _push(tester, theme: motionTheme());

    expect(route.transitionDuration, const Duration(milliseconds: 333));
    expect(
      route.reverseTransitionDuration,
      const Duration(microseconds: 213120),
    );
  });

  testWidgets("us11/fr01: with no theme it takes the package default's "
      'slow level: 300 ms push, 192 ms pop', (tester) async {
    final route = await _push(tester);

    expect(route.transitionDuration, const Duration(milliseconds: 300));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 192));
  });

  testWidgets('a duration the caller passes wins', (tester) async {
    final route = await _push(
      tester,
      theme: motionTheme(),
      duration: const Duration(milliseconds: 500),
    );

    expect(route.transitionDuration, const Duration(milliseconds: 500));
  });

  testWidgets("us11/fr02: a null curve takes the theme's standard curve", (
    tester,
  ) async {
    const page = SizedBox(key: ValueKey('page'));
    await _push(
      tester,
      theme: motionTheme(
        slow: const Duration(milliseconds: 400),
        standard: const StratumNamedCurve('linear'),
      ),
      type: ScreenTransitionType.rightToLeft,
      child: page,
    );
    await tester.pump(const Duration(milliseconds: 100));

    final slide = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(slide.position.value.dx, closeTo(0.75, 1e-9));
  });

  testWidgets("C1: under reduced motion the route keeps the theme's "
      'duration', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final route = await _push(tester, theme: motionTheme());

    expect(route.transitionDuration, const Duration(milliseconds: 333));
  });

  testWidgets('us11/fr01: a slow level with no fields pushes and pops at zero '
      'duration', (tester) async {
    final theme = fakeTheme.copyWith(
      animation: StratumAnimation(
        veryFast: StratumAnimation.packageDefault.veryFast,
        fast: StratumAnimation.packageDefault.fast,
        normal: StratumAnimation.packageDefault.normal,
        slow: const AnimationStyle(),
        verySlow: StratumAnimation.packageDefault.verySlow,
        appear: StratumAnimation.packageDefault.appear,
        defaultLevel: StratumMotionLevel.fast,
      ),
    );

    final route = await _push(tester, theme: theme);

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('us11/fr01: a slow level with a duration and no reverse duration '
      'or curve keeps that duration for the pop and falls back to '
      'easeInOutSine', (tester) async {
    final theme = fakeTheme.copyWith(
      animation: StratumAnimation(
        veryFast: StratumAnimation.packageDefault.veryFast,
        fast: StratumAnimation.packageDefault.fast,
        normal: StratumAnimation.packageDefault.normal,
        slow: const AnimationStyle(duration: Duration(milliseconds: 400)),
        verySlow: StratumAnimation.packageDefault.verySlow,
        appear: StratumAnimation.packageDefault.appear,
        defaultLevel: StratumMotionLevel.fast,
      ),
    );
    const page = SizedBox(key: ValueKey('page'));

    final route = await _push(
      tester,
      theme: theme,
      type: ScreenTransitionType.rightToLeft,
      child: page,
    );
    expect(route.transitionDuration, const Duration(milliseconds: 400));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));

    final slide = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(
      slide.position.value.dx,
      closeTo(1 - Curves.easeInOutSine.transform(0.5), 1e-9),
    );
  });

  testWidgets('us05/fr03: a fade plays over the full duration under reduced '
      'motion', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    await _push(
      tester,
      type: ScreenTransitionType.fade,
      child: page,
      reducedMotion: true,
    );
    await tester.pump(const Duration(milliseconds: 150));

    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(
      fade.opacity.value,
      closeTo(Curves.easeInOutSine.transform(0.5), 1e-9),
    );
  });

  for (final type in [
    ScreenTransitionType.rightToLeftWithFade,
    ScreenTransitionType.leftToRightWithFade,
  ]) {
    testWidgets(
      'us05/fr03: ${type.name} fades with no slide under reduced motion',
      (tester) async {
        const page = SizedBox(key: ValueKey('page'));
        await _push(tester, type: type, child: page, reducedMotion: true);
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(SlideTransition),
          ),
          findsNothing,
        );
        final fade = tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('page')),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(
          fade.opacity.value,
          closeTo(Curves.easeInOutSine.transform(0.5), 1e-9),
        );
      },
    );
  }

  for (final type in [
    ScreenTransitionType.rightToLeft,
    ScreenTransitionType.leftToRight,
    ScreenTransitionType.topToBottom,
    ScreenTransitionType.bottomToTop,
  ]) {
    testWidgets(
      'us05/fr03: ${type.name} shows the new page at once under reduced '
      'motion',
      (tester) async {
        const page = SizedBox(key: ValueKey('page'));
        await _push(tester, type: type, child: page, reducedMotion: true);
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.byKey(const ValueKey('page')), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(SlideTransition),
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets('us05/fr03: scale shows the new page at once under reduced '
      'motion', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    await _push(
      tester,
      type: ScreenTransitionType.scale,
      child: page,
      alignment: Alignment.center,
      reducedMotion: true,
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const ValueKey('page')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('page')),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('us05/fr03: rotate shows the new page at once under reduced '
      'motion', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    await _push(
      tester,
      type: ScreenTransitionType.rotate,
      child: page,
      alignment: Alignment.center,
      reducedMotion: true,
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const ValueKey('page')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('page')),
        matching: find.byType(RotationTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('us05/fr03: size shows the new page at once under reduced '
      'motion', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    await _push(
      tester,
      type: ScreenTransitionType.size,
      child: page,
      alignment: Alignment.center,
      reducedMotion: true,
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const ValueKey('page')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('page')),
        matching: find.byType(SizeTransition),
      ),
      findsNothing,
    );
  });

  for (final type in [
    ScreenTransitionType.leftToRightJoined,
    ScreenTransitionType.rightToLeftJoined,
  ]) {
    testWidgets(
      'us05/fr03: ${type.name} shows the new page at once under reduced '
      'motion',
      (tester) async {
        const page = SizedBox(key: ValueKey('page'));
        const current = SizedBox(key: ValueKey('current'));
        await _push(
          tester,
          type: type,
          child: page,
          childCurrent: current,
          reducedMotion: true,
        );
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.byKey(const ValueKey('page')), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(SlideTransition),
          ),
          findsNothing,
        );
      },
    );
  }

  test('us05/fr01/e01: inheritTheme with no ctx fails an assertion naming '
      'ctx', () {
    expect(
      () => PageTransition<void>(
        type: ScreenTransitionType.fade,
        child: const SizedBox(),
        inheritTheme: true,
      ),
      throwsA(
        isA<AssertionError>().having(
          (error) => '${error.message}',
          'message',
          contains('ctx'),
        ),
      ),
    );
  });

  testWidgets('us05/fr01/e02, us05/s5: a joined type with no '
      'childCurrent fails an assertion naming childCurrent', (tester) async {
    await _push(tester, type: ScreenTransitionType.rightToLeftJoined);

    expect(
      tester.takeException(),
      isA<AssertionError>().having(
        (error) => '${error.message}',
        'message',
        contains('childCurrent'),
      ),
    );
  });

  testWidgets('us05/fr01/e03: scale with no alignment fails with a '
      'null-check error', (tester) async {
    await _push(tester, type: ScreenTransitionType.scale);

    expect(tester.takeException(), isA<TypeError>());
  });

  testWidgets('us05/fr01/e04: the page under a pushed route stays '
      'mounted', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    final route = await _push(
      tester,
      type: ScreenTransitionType.rightToLeft,
      child: page,
    );
    await tester.pumpAndSettle();
    route.navigator!
        .push(MaterialPageRoute<void>(builder: (_) => const SizedBox()))
        .ignore();
    await tester.pumpAndSettle();

    expect(route.maintainState, isTrue);
    expect(
      find.byKey(const ValueKey('page'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('us05/s2: rightToLeftJoined slides the current page '
      'out beside the new one', (tester) async {
    await _push(
      tester,
      theme: motionTheme(
        slow: const Duration(milliseconds: 400),
        standard: const StratumNamedCurve('linear'),
      ),
      type: ScreenTransitionType.rightToLeftJoined,
      child: const SizedBox(key: ValueKey('page')),
      childCurrent: const SizedBox(key: ValueKey('current')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    double dxOf(String key) => tester
        .widget<SlideTransition>(
          find
              .ancestor(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(SlideTransition),
              )
              .first,
        )
        .position
        .value
        .dx;
    expect(dxOf('page'), closeTo(0.75, 1e-9));
    expect(dxOf('current'), closeTo(-0.25, 1e-9));
  });

  testWidgets('us05/s1: a right-to-left push slides in from the right edge '
      'over 300 ms', (tester) async {
    final route = await _push(
      tester,
      type: ScreenTransitionType.rightToLeft,
      child: const SizedBox(key: ValueKey('page')),
    );
    double dx() => tester
        .widget<SlideTransition>(
          find
              .ancestor(of: _page, matching: find.byType(SlideTransition))
              .first,
        )
        .position
        .value
        .dx;

    expect(route.transitionDuration, const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 150));
    expect(dx(), closeTo(1 - Curves.easeInOutSine.transform(0.5), 1e-9));
    await tester.pump(const Duration(milliseconds: 150));
    expect(dx(), 0);
  });

  for (final signal in _Reduce.values) {
    testWidgets('us05/s4: under ${signal.name} a right-to-left push shows '
        'the new page with no slide', (tester) async {
      await _push(
        tester,
        type: ScreenTransitionType.rightToLeft,
        child: const SizedBox(key: ValueKey('page')),
        reducedMotion: _apply(tester, signal),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(_page, findsOneWidget);
      expect(_transitionsAbove(tester), isEmpty);
    });
  }

  testWidgets('us05/fr03/e01: a caller curve drives a Stratum type as '
      'passed', (tester) async {
    await _push(
      tester,
      theme: motionTheme(
        slow: const Duration(milliseconds: 400),
        standard: const StratumNamedCurve('linear'),
      ),
      type: ScreenTransitionType.rightToLeft,
      curve: Curves.easeIn,
      child: const SizedBox(key: ValueKey('page')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final slide = tester.widget<SlideTransition>(
      find.ancestor(of: _page, matching: find.byType(SlideTransition)).first,
    );
    expect(
      slide.position.value.dx,
      closeTo(1 - Curves.easeIn.transform(0.25), 1e-9),
    );
  });

  testWidgets('us05/fr03/e01: a caller curve drives the Flutter motion of '
      'cupertino too', (tester) async {
    await _push(
      tester,
      type: ScreenTransitionType.cupertino,
      curve: Curves.easeIn,
      child: const SizedBox(key: ValueKey('page')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 100 ms of Cupertino's 500 ms: the caller curve, then the primary
    // slide's own fastEaseInToSlowEaseOut
    // (cupertino/route.dart:533-536@3.47.3).
    final slide = tester.widget<SlideTransition>(
      find.ancestor(of: _page, matching: find.byType(SlideTransition)).first,
    );
    expect(
      slide.position.value.dx,
      closeTo(
        1 -
            Curves.fastEaseInToSlowEaseOut.transform(
              Curves.easeIn.transform(0.2),
            ),
        1e-6,
      ),
    );
  });

  testWidgets('review-m1-t4 important-1: a caller curve steps aside for a '
      'Cupertino pop gesture already in progress', (tester) async {
    final route = await _push(
      tester,
      type: ScreenTransitionType.cupertino,
      curve: Curves.easeIn,
      child: const SizedBox(key: ValueKey('page')),
    );
    route.navigator!.didStartUserGesture();
    await tester.pump(const Duration(milliseconds: 250));

    final slide = tester.widget<SlideTransition>(
      find.ancestor(of: _page, matching: find.byType(SlideTransition)).first,
    );
    expect(slide.position.value.dx, closeTo(0.5, 1e-9));
    route.navigator!.didStopUserGesture();
  });

  group('us05/fr01: the seven types of the theme era', () {
    testWidgets('platform shows the Cupertino slide on iOS and takes its '
        'durations', (tester) async {
      final route = await _push(
        tester,
        type: ScreenTransitionType.platform,
        child: const SizedBox(key: ValueKey('page')),
      );
      await _settleHeroOffstage(tester);

      expect(
        find.ancestor(
          of: _page,
          matching: find.byType(CupertinoPageTransition),
        ),
        findsOneWidget,
      );
      expect(
        route.transitionDuration,
        CupertinoRouteTransitionMixin.kTransitionDuration,
      );
      expect(
        route.reverseTransitionDuration,
        const CupertinoPageTransitionsBuilder().reverseTransitionDuration,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('platform takes the predictive-back builder on Android', (
      tester,
    ) async {
      final route = await _push(tester, type: ScreenTransitionType.platform);
      await _settleHeroOffstage(tester);

      expect(find.byType(CupertinoPageTransition), findsNothing);
      expect(
        route.transitionDuration,
        const PredictiveBackPageTransitionsBuilder().transitionDuration,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('cupertino shows the Cupertino slide on every platform', (
      tester,
    ) async {
      final route = await _push(
        tester,
        type: ScreenTransitionType.cupertino,
        child: const SizedBox(key: ValueKey('page')),
      );
      await _settleHeroOffstage(tester);

      expect(
        find.ancestor(
          of: _page,
          matching: find.byType(CupertinoPageTransition),
        ),
        findsOneWidget,
      );
      expect(
        route.transitionDuration,
        CupertinoRouteTransitionMixin.kTransitionDuration,
      );
    }, variant: TargetPlatformVariant.all());

    testWidgets("us05/fr03/e02: cupertino keeps Flutter's curve, not the "
        "theme's standard one", (tester) async {
      await _push(
        tester,
        theme: motionTheme(standard: const StratumNamedCurve('easeIn')),
        type: ScreenTransitionType.cupertino,
        child: const SizedBox(key: ValueKey('page')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // The nearest slide is CupertinoPageTransition's primary one, on
      // fastEaseInToSlowEaseOut over its own 500 ms
      // (cupertino/route.dart:533-536@3.47.3).
      final slide = tester.widget<SlideTransition>(
        find.ancestor(of: _page, matching: find.byType(SlideTransition)).first,
      );
      expect(
        slide.position.value.dx,
        closeTo(1 - Curves.fastEaseInToSlowEaseOut.transform(0.2), 1e-6),
      );
    });

    testWidgets('none shows the new page at once, in push and pop', (
      tester,
    ) async {
      final route = await _push(
        tester,
        type: ScreenTransitionType.none,
        child: const SizedBox(key: ValueKey('page')),
      );
      await _settleHeroOffstage(tester);

      expect(_page, findsOneWidget);
      expect(_transitionsAbove(tester), isEmpty);
      route.navigator!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_transitionsAbove(tester), isEmpty);
    });

    testWidgets("fadeThrough fills with the Stratum theme's canvas color", (
      tester,
    ) async {
      await _push(
        tester,
        theme: defaultThemeSet.dark,
        type: ScreenTransitionType.fadeThrough,
        child: const SizedBox(key: ValueKey('page')),
      );
      await _settleHeroOffstage(tester);

      final transition = tester.widget<FadeThroughTransition>(
        find.ancestor(of: _page, matching: find.byType(FadeThroughTransition)),
      );
      expect(transition.fillColor, Theme.of(tester.element(_page)).canvasColor);
    });

    testWidgets("us05/fr03: fadeThrough runs on the theme's standard curve", (
      tester,
    ) async {
      await _push(
        tester,
        theme: motionTheme(
          slow: const Duration(milliseconds: 400),
          standard: const StratumNamedCurve('easeIn'),
        ),
        type: ScreenTransitionType.fadeThrough,
        child: const SizedBox(key: ValueKey('page')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final transition = tester.widget<FadeThroughTransition>(
        find.ancestor(of: _page, matching: find.byType(FadeThroughTransition)),
      );
      expect(
        transition.animation.value,
        closeTo(Curves.easeIn.transform(0.25), 1e-9),
      );
    });

    for (final (type, axis) in [
      (
        ScreenTransitionType.sharedAxisHorizontal,
        SharedAxisTransitionType.horizontal,
      ),
      (
        ScreenTransitionType.sharedAxisVertical,
        SharedAxisTransitionType.vertical,
      ),
      (ScreenTransitionType.sharedAxisScaled, SharedAxisTransitionType.scaled),
    ]) {
      testWidgets('${type.name} shows the ${axis.name} shared axis on the '
          "Stratum theme's canvas color", (tester) async {
        await _push(
          tester,
          theme: defaultThemeSet.dark,
          type: type,
          child: const SizedBox(key: ValueKey('page')),
        );
        await _settleHeroOffstage(tester);

        final transition = tester.widget<SharedAxisTransition>(
          find.ancestor(of: _page, matching: find.byType(SharedAxisTransition)),
        );
        expect(transition.transitionType, axis);
        expect(
          transition.fillColor,
          Theme.of(tester.element(_page)).canvasColor,
        );
      });
    }
  });

  for (final signal in _Reduce.values) {
    group('us05/fr03, nfr-u03: under ${signal.name}', () {
      for (final type in [
        ScreenTransitionType.cupertino,
        ScreenTransitionType.none,
      ]) {
        testWidgets('${type.name} shows the new page at once', (tester) async {
          await _push(
            tester,
            type: type,
            child: const SizedBox(key: ValueKey('page')),
            reducedMotion: _apply(tester, signal),
          );
          await tester.pump(const Duration(milliseconds: 150));

          expect(_page, findsOneWidget);
          expect(_transitionsAbove(tester), isEmpty);
        });
      }

      for (final type in [
        ScreenTransitionType.fadeThrough,
        ScreenTransitionType.sharedAxisHorizontal,
        ScreenTransitionType.sharedAxisVertical,
        ScreenTransitionType.sharedAxisScaled,
      ]) {
        testWidgets("${type.name} fades on the theme's standard curve with "
            'no slide or scale', (tester) async {
          final route = await _push(
            tester,
            theme: motionTheme(standard: const StratumNamedCurve('easeIn')),
            type: type,
            child: const SizedBox(key: ValueKey('page')),
            reducedMotion: _apply(tester, signal),
          );
          await tester.pump(route.transitionDuration ~/ 4);

          final transitions = _transitionsAbove(tester);
          expect(transitions.map((widget) => widget.runtimeType), [
            FadeTransition,
          ]);
          expect(
            (transitions.single as FadeTransition).opacity.value,
            closeTo(Curves.easeIn.transform(0.25), 1e-9),
          );
        });
      }

      testWidgets('platform on iOS shows the new page at once', (tester) async {
        await _push(
          tester,
          type: ScreenTransitionType.platform,
          child: const SizedBox(key: ValueKey('page')),
          reducedMotion: _apply(tester, signal),
        );
        await tester.pump(const Duration(milliseconds: 150));

        expect(_page, findsOneWidget);
        expect(_transitionsAbove(tester), isEmpty);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('platform on Android keeps its fade over the full '
          "duration, on the theme's standard curve", (tester) async {
        final route = await _push(
          tester,
          theme: motionTheme(standard: const StratumNamedCurve('easeIn')),
          type: ScreenTransitionType.platform,
          child: const SizedBox(key: ValueKey('page')),
          reducedMotion: _apply(tester, signal),
        );
        await tester.pump(route.transitionDuration ~/ 4);

        final transitions = _transitionsAbove(tester);
        expect(transitions.map((widget) => widget.runtimeType), [
          FadeTransition,
        ]);
        expect(
          (transitions.single as FadeTransition).opacity.value,
          closeTo(Curves.easeIn.transform(0.25), 1e-9),
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('platform on Android fades on a caller curve', (
        tester,
      ) async {
        final route = await _push(
          tester,
          type: ScreenTransitionType.platform,
          curve: Curves.easeOut,
          child: const SizedBox(key: ValueKey('page')),
          reducedMotion: _apply(tester, signal),
        );
        await tester.pump(route.transitionDuration ~/ 4);

        final fade = _transitionsAbove(tester).single as FadeTransition;
        expect(
          fade.opacity.value,
          closeTo(Curves.easeOut.transform(0.25), 1e-9),
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    });
  }

  group("us05/fr03: the legacy types run on the theme's standard curve", () {
    final theme = motionTheme(
      slow: const Duration(milliseconds: 400),
      standard: const StratumNamedCurve('easeIn'),
    );
    final quarter = Curves.easeIn.transform(0.25);

    testWidgets('fade', (tester) async {
      await _push(
        tester,
        theme: theme,
        type: ScreenTransitionType.fade,
        child: const SizedBox(key: ValueKey('page')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: _page, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, closeTo(quarter, 1e-9));
    });

    testWidgets('fade under reduced motion', (tester) async {
      await _push(
        tester,
        theme: theme,
        type: ScreenTransitionType.fade,
        child: const SizedBox(key: ValueKey('page')),
        reducedMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 100));

      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: _page, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, closeTo(quarter, 1e-9));
    });

    testWidgets('rotate', (tester) async {
      await _push(
        tester,
        theme: theme,
        type: ScreenTransitionType.rotate,
        alignment: Alignment.center,
        child: const SizedBox(key: ValueKey('page')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final rotation = tester.widget<RotationTransition>(
        find.ancestor(of: _page, matching: find.byType(RotationTransition)),
      );
      expect(rotation.turns.value, closeTo(quarter, 1e-9));
    });

    for (final type in [
      ScreenTransitionType.rightToLeftWithFade,
      ScreenTransitionType.leftToRightWithFade,
    ]) {
      testWidgets('${type.name} fades on the curve', (tester) async {
        await _push(
          tester,
          theme: theme,
          type: type,
          child: const SizedBox(key: ValueKey('page')),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final fade = tester.widget<FadeTransition>(
          find.ancestor(of: _page, matching: find.byType(FadeTransition)).first,
        );
        expect(fade.opacity.value, closeTo(quarter, 1e-9));
      });
    }
  });
}
