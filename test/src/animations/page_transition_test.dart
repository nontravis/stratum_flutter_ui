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
  home: const SizedBox(),
);

Future<PageTransition<void>> _push(
  WidgetTester tester, {
  StratumThemeData? theme,
  ScreenTransitionType type = ScreenTransitionType.fade,
  Duration? duration,
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
    child: child,
    childCurrent: childCurrent,
    alignment: alignment,
  );
  navigator.currentState!.push(route).ignore();
  await tester.pump();
  return route;
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
    expect(fade.opacity.value, closeTo(0.5, 1e-9));
  });

  testWidgets('us05/fr03: a with-fade slide fades with no slide under '
      'reduced motion', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    await _push(
      tester,
      type: ScreenTransitionType.rightToLeftWithFade,
      child: page,
      reducedMotion: true,
    );
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
    expect(fade.opacity.value, closeTo(0.5, 1e-9));
  });

  testWidgets('us05/fr03: a slide shows the new page at once under reduced '
      'motion', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    await _push(
      tester,
      type: ScreenTransitionType.rightToLeft,
      child: page,
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
  });

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

  testWidgets('us05/fr03: joined slides show the new page at once under '
      'reduced motion', (tester) async {
    const page = SizedBox(key: ValueKey('page'));
    const current = SizedBox(key: ValueKey('current'));
    await _push(
      tester,
      type: ScreenTransitionType.rightToLeftJoined,
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
  });
}
