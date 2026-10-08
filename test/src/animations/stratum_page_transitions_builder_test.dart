import 'package:animations/animations.dart' show FadeThroughTransition;
import 'package:flutter/cupertino.dart'
    show CupertinoPageTransitionsBuilder, CupertinoRouteTransitionMixin;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/animations/stratum_page_transitions_builder.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

/// The package default's motion, with [transitions] as its
/// `animation.transition` config, and [curves] replacing its
/// `animation.curve` roles when given.
StratumAnimation _motion(
  Map<String, String> transitions, {
  Map<String, StratumCurve>? curves,
}) => StratumAnimation.fromConfig(
  defaultThemeConfig.animation.copyWith(
    transitions: transitions,
    curves: curves ?? defaultThemeConfig.animation.curves,
  ),
);

/// A [MaterialApp] whose Material theme installs a builder of [motion] for
/// every platform, with no [WindowSizeScope] unless [builder] adds one.
Widget _app(
  GlobalKey<NavigatorState> navigator,
  StratumAnimation motion, {
  TransitionBuilder? builder,
}) => MaterialApp(
  navigatorKey: navigator,
  theme: ThemeData(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: StratumPageTransitionsBuilder(
            motion: motion,
            platform: platform,
          ),
      },
    ),
  ),
  builder: builder,
  home: const SizedBox(key: ValueKey('home')),
);

/// Pushes a plain Material page keyed `page` and pumps [elapsed] into its
/// transition.
Future<void> _pushPage(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator, {
  Duration elapsed = const Duration(milliseconds: 100),
}) async {
  navigator.currentState!
      .push(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox(key: ValueKey('page')),
        ),
      )
      .ignore();
  await tester.pump();
  await tester.pump(elapsed);
}

/// Sets the test view to [size] logical pixels until the test ends.
void _window(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Finder _above(String key, Type type) =>
    find.ancestor(of: find.byKey(ValueKey(key)), matching: find.byType(type));

void main() {
  final fadeMobileSlideDesktop = _motion(
    transitionsOf(
      ScreenTransitionType.platform,
      sizes: {
        WindowSize.mobile: ScreenTransitionType.fade,
        WindowSize.desktop: ScreenTransitionType.rightToLeft,
      },
    ),
  );

  testWidgets('us05/s7: a desktop window takes the desktop type', (
    tester,
  ) async {
    _window(tester, const Size(1300, 800));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(navigator, fadeMobileSlideDesktop));
    await _pushPage(tester, navigator);

    expect(_above('page', SlideTransition), findsOneWidget);
    expect(_above('page', FadeTransition), findsNothing);
  });

  testWidgets('us05/fr04/e01, us05/s11: no scope above takes the '
      "window's size and never throws", (tester) async {
    _window(tester, const Size(400, 800));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(navigator, fadeMobileSlideDesktop));
    await _pushPage(tester, navigator);

    expect(tester.takeException(), isNull);
    expect(_above('page', FadeTransition), findsOneWidget);
    expect(_above('page', SlideTransition), findsNothing);
  });

  testWidgets('us05/fr04: the scope above wins over the window size the '
      'route reads', (tester) async {
    _window(tester, const Size(400, 800));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(
        navigator,
        fadeMobileSlideDesktop,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(1300, 800)),
          child: WindowSizeScope(
            child: MediaQuery(data: MediaQuery.of(context), child: child!),
          ),
        ),
      ),
    );
    await _pushPage(tester, navigator);

    expect(_above('page', SlideTransition), findsOneWidget);
  });

  testWidgets("us05/fr04/e02: the durations take the implicit view's "
      'window size', (tester) async {
    final motion = _motion(
      transitionsOf(
        ScreenTransitionType.fade,
        sizes: {WindowSize.desktop: ScreenTransitionType.cupertino},
      ),
    );
    final builder = StratumPageTransitionsBuilder(
      motion: motion,
      platform: TargetPlatform.android,
    );

    _window(tester, const Size(1300, 800));
    expect(
      builder.transitionDuration,
      CupertinoRouteTransitionMixin.kTransitionDuration,
    );
    expect(
      builder.reverseTransitionDuration,
      const CupertinoPageTransitionsBuilder().reverseTransitionDuration,
    );

    tester.view.physicalSize = const Size(400, 800);
    expect(builder.transitionDuration, const Duration(milliseconds: 300));
    expect(
      builder.reverseTransitionDuration,
      const Duration(milliseconds: 192),
    );
  });

  testWidgets('us05/fr04/e02: platform durations follow the platform the '
      'builder is installed for', (tester) async {
    final motion = _motion(transitionsOf(ScreenTransitionType.platform));

    expect(
      StratumPageTransitionsBuilder(
        motion: motion,
        platform: TargetPlatform.iOS,
      ).transitionDuration,
      CupertinoRouteTransitionMixin.kTransitionDuration,
    );
    expect(
      StratumPageTransitionsBuilder(
        motion: motion,
        platform: TargetPlatform.android,
      ).transitionDuration,
      const PredictiveBackPageTransitionsBuilder().transitionDuration,
    );
  });

  test('us05/fr01: none takes zero push and pop durations in every route', () {
    final motion = _motion(transitionsOf(ScreenTransitionType.none));
    final builder = StratumPageTransitionsBuilder(
      motion: motion,
      platform: TargetPlatform.iOS,
    );

    expect(builder.transitionDuration, Duration.zero);
    expect(builder.reverseTransitionDuration, Duration.zero);
  });

  testWidgets("us05/fr04/e04: platform delegates the Flutter builder's own "
      'delegated transition, so a route below parallaxes', (tester) async {
    final motion = _motion(transitionsOf(ScreenTransitionType.platform));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(
          platform: TargetPlatform.iOS,
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.iOS: StratumPageTransitionsBuilder(
                motion: motion,
                platform: TargetPlatform.iOS,
              ),
            },
          ),
        ),
        home: const SizedBox(key: ValueKey('home')),
      ),
    );
    navigator.currentState!
        .push(
          PageTransition<void>(
            type: ScreenTransitionType.platform,
            child: const SizedBox(key: ValueKey('lower')),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();

    navigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const SizedBox(key: ValueKey('upper')),
          ),
        )
        .ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final slides = tester
        .widgetList<SlideTransition>(_above('lower', SlideTransition))
        .map((slide) => slide.position.value.dx);
    expect(slides.any((dx) => dx < 0), isTrue);
  });

  test('us05/fr04/e02 (R5): no view classifies as mobile', () {
    expect(windowSizeOfView(null), WindowSize.mobile);
  });

  testWidgets('a view classifies by its logical size', (tester) async {
    _window(tester, const Size(1300, 800));
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2600, 1600);

    expect(windowSizeOfView(tester.view), WindowSize.desktop);
  });

  for (final (signal, reduce) in <(String, TransitionBuilder?)>[
    (
      'disableAnimations',
      (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
    ('reduceMotion', null),
  ]) {
    testWidgets('us05/s10, nfr-u03: under $signal fadeThrough fades '
        'with no scale', (tester) async {
      if (reduce == null) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(
          navigator,
          _motion(
            transitionsOf(ScreenTransitionType.fadeThrough),
            curves: {
              ...defaultThemeConfig.animation.curves,
              'standard': const StratumNamedCurve('easeIn'),
            },
          ),
          builder: reduce,
        ),
      );
      await _pushPage(
        tester,
        navigator,
        elapsed: const Duration(milliseconds: 150),
      );

      expect(_above('page', FadeThroughTransition), findsNothing);
      expect(_above('page', ScaleTransition), findsNothing);
      final fade = tester.widget<FadeTransition>(
        _above('page', FadeTransition).first,
      );
      // easeIn, not easeInOutSine: tells the motion's own standard curve
      // from curveOf's hardcoded fallback, which the package default's
      // theme curve can't (both are easeInOutSine).
      expect(fade.opacity.value, closeTo(Curves.easeIn.transform(0.5), 1e-9));
    });
  }

  group('ruling R10: a theme type that needs a caller input', () {
    for (final type in [
      ScreenTransitionType.scale,
      ScreenTransitionType.rotate,
      ScreenTransitionType.size,
    ]) {
      testWidgets('${type.name} grows from the center and never throws', (
        tester,
      ) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_app(navigator, _motion(transitionsOf(type))));
        await _pushPage(tester, navigator);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('page')), findsOneWidget);
        if (type == ScreenTransitionType.scale) {
          expect(
            tester
                .widget<ScaleTransition>(_above('page', ScaleTransition).first)
                .alignment,
            Alignment.center,
          );
        } else if (type == ScreenTransitionType.rotate) {
          expect(
            tester
                .widget<RotationTransition>(
                  _above('page', RotationTransition).first,
                )
                .alignment,
            Alignment.center,
          );
        } else {
          // .last, not .first: SizeTransition wraps its own child in an
          // inner Align (AlignmentDirectional.centerStart by default,
          // transitions.dart:528-533@3.47.3); ours is the outer one.
          expect(
            tester.widget<Align>(_above('page', Align).last).alignment,
            Alignment.center,
          );
        }
      });
    }

    testWidgets('rightToLeftJoined slides the page under it out by its own '
        'route', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(
          navigator,
          _motion(transitionsOf(ScreenTransitionType.rightToLeftJoined)),
        ),
      );
      await _pushPage(tester, navigator);

      expect(tester.takeException(), isNull);
      double dxOf(String key) => tester
          .widget<SlideTransition>(_above(key, SlideTransition).first)
          .position
          .value
          .dx;
      expect(dxOf('page'), greaterThan(0));
      final home = tester
          .widgetList<SlideTransition>(_above('home', SlideTransition))
          .map((slide) => slide.position.value.dx);
      expect(home.any((dx) => dx < 0), isTrue);
    });
  });

  test('two builders of equal motion and platform are equal', () {
    final motion = _motion(transitionsOf(ScreenTransitionType.fade));
    final again = _motion(transitionsOf(ScreenTransitionType.fade));
    final ios = StratumPageTransitionsBuilder(
      motion: motion,
      platform: TargetPlatform.iOS,
    );
    final iosAgain = StratumPageTransitionsBuilder(
      motion: again,
      platform: TargetPlatform.iOS,
    );
    final android = StratumPageTransitionsBuilder(
      motion: motion,
      platform: TargetPlatform.android,
    );

    expect(ios, iosAgain);
    expect(ios.hashCode, iosAgain.hashCode);
    expect(ios, isNot(android));
  });
}
