import 'package:flutter/cupertino.dart'
    show
        CupertinoPageTransition,
        CupertinoPageTransitionsBuilder,
        CupertinoRouteTransitionMixin;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';
import '../components/common/fakes/fake_view.dart';

/// A theme that names a fade for every window size but desktop, and the
/// Cupertino slide for desktop, so the shown type and the durations each
/// tell which window they come from.
final StratumThemeData _theme = motionTheme(
  transitions: transitionsOf(
    ScreenTransitionType.fade,
    sizes: {WindowSize.desktop: ScreenTransitionType.cupertino},
  ),
);

/// A [MaterialApp] with [navigator], below an application of [_theme].
Widget _app(GlobalKey<NavigatorState> navigator) => MaterialApp(
  navigatorKey: navigator,
  builder: (context, child) => StratumThemeApplication(
    themes: StratumThemeSet(light: _theme),
    themeMode: ThemeMode.light,
    child: child!,
  ),
  home: const SizedBox(),
);

/// Shows one app in the test's own view, the main window, at [main]
/// logical pixels, and one in a [FakeView] beside it at [second], and
/// returns the two apps' navigators, the main window's first.
Future<(GlobalKey<NavigatorState>, GlobalKey<NavigatorState>)> _twoWindows(
  WidgetTester tester, {
  required Size main,
  required Size second,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = main;
  addTearDown(tester.view.reset);
  final mainNavigator = GlobalKey<NavigatorState>();
  final secondNavigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    wrapWithView: false,
    ViewCollection(
      views: [
        View(view: tester.view, child: _app(mainNavigator)),
        View(
          view: FakeView(tester.view)..physicalSize = second,
          child: _app(secondNavigator),
        ),
      ],
    ),
  );
  return (mainNavigator, secondNavigator);
}

/// Pushes a plain Material page keyed [key] on [navigator] and pumps
/// 100 ms into its transition.
Future<void> _push(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  String key,
) async {
  navigator.currentState!
      .push(
        MaterialPageRoute<void>(builder: (_) => SizedBox(key: ValueKey(key))),
      )
      .ignore();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _above(String key, Type type) =>
    find.ancestor(of: find.byKey(ValueKey(key)), matching: find.byType(type));

/// The route that holds the page keyed [key].
ModalRoute<Object?> _routeOf(WidgetTester tester, String key) =>
    ModalRoute.of(tester.element(find.byKey(ValueKey(key))))!;

void main() {
  testWidgets(
    'fo05/us05/fr04/e05: a page in a second window takes the type the '
    "theme names for that window's size",
    (tester) async {
      final (mainWindow, secondWindow) = await _twoWindows(
        tester,
        main: const Size(400, 800),
        second: const Size(1300, 800),
      );

      await _push(tester, secondWindow, 'secondPage');
      expect(_above('secondPage', CupertinoPageTransition), findsOneWidget);

      await _push(tester, mainWindow, 'mainPage');
      expect(_above('mainPage', FadeTransition), findsOneWidget);
      expect(_above('mainPage', CupertinoPageTransition), findsNothing);
    },
  );

  testWidgets("fo05/us05/fr04/e05: a second window's route takes its durations "
      "from the main window's type", (tester) async {
    final (_, secondWindow) = await _twoWindows(
      tester,
      main: const Size(400, 800),
      second: const Size(1300, 800),
    );

    await _push(tester, secondWindow, 'secondPage');

    expect(_above('secondPage', CupertinoPageTransition), findsOneWidget);
    final route = _routeOf(tester, 'secondPage');
    expect(route.transitionDuration, const Duration(milliseconds: 333));
    expect(
      route.reverseTransitionDuration,
      const Duration(microseconds: 213120),
    );
  });

  testWidgets('fo05/us05/fr04/e05: a desktop main window times a mobile second '
      "window's route by the desktop type", (tester) async {
    final (_, secondWindow) = await _twoWindows(
      tester,
      main: const Size(1300, 800),
      second: const Size(400, 800),
    );

    await _push(tester, secondWindow, 'secondPage');

    expect(_above('secondPage', FadeTransition), findsOneWidget);
    final route = _routeOf(tester, 'secondPage');
    expect(
      route.transitionDuration,
      CupertinoRouteTransitionMixin.kTransitionDuration,
    );
    expect(
      route.reverseTransitionDuration,
      const CupertinoPageTransitionsBuilder().reverseTransitionDuration,
    );
  });
}
