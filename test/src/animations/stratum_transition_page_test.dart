import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

const _home = MaterialPage<void>(
  key: ValueKey('homePage'),
  child: SizedBox(key: ValueKey('home')),
);

/// A [MaterialApp] whose only navigator is a Navigator 2.0 page list of
/// [pages] below an application of [theme], with the app's
/// `disableAnimations` set when [reducedMotion] is.
Widget _app(
  StratumThemeData theme,
  List<Page<Object?>> pages, {
  bool reducedMotion = false,
}) => MaterialApp(
  builder: (context, _) {
    Widget result = StratumThemeApplication(
      themes: StratumThemeSet(light: theme),
      themeMode: ThemeMode.light,
      child: Navigator(pages: pages, onDidRemovePage: (_) {}),
    );
    if (reducedMotion) {
      result = MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: result,
      );
    }
    return result;
  },
);

StratumTransitionPage<void> _next(ScreenTransitionType type) =>
    StratumTransitionPage<void>(
      key: const ValueKey('next'),
      type: type,
      child: const SizedBox(key: ValueKey('page')),
    );

final Finder _page = find.byKey(const ValueKey('page'));

Finder _above(Type type) =>
    find.ancestor(of: _page, matching: find.byType(type));

/// Opens [type]'s page over the home page and pumps 100 ms into it.
Future<void> _open(
  WidgetTester tester,
  StratumThemeData theme,
  ScreenTransitionType type, {
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    _app(theme, const [_home], reducedMotion: reducedMotion),
  );
  await tester.pumpWidget(
    _app(theme, [_home, _next(type)], reducedMotion: reducedMotion),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final fadeTheme = motionTheme(
    transitions: transitionsOf(ScreenTransitionType.fade),
  );

  testWidgets("us05/s9: the page shows its own type over the theme's", (
    tester,
  ) async {
    await _open(tester, fadeTheme, ScreenTransitionType.rightToLeft);

    expect(_above(SlideTransition), findsOneWidget);
    expect(_above(FadeTransition), findsNothing);
  });

  testWidgets("us05/fr05: the route takes the theme's slow level", (
    tester,
  ) async {
    await _open(tester, fadeTheme, ScreenTransitionType.rightToLeft);
    final route = ModalRoute.of(tester.element(_page))!;

    expect(route.transitionDuration, const Duration(milliseconds: 333));
    expect(
      route.reverseTransitionDuration,
      const Duration(microseconds: 213120),
    );
  });

  testWidgets('us05/fr05/e02: none shows the page at once, in push and '
      'pop', (tester) async {
    await _open(tester, fadeTheme, ScreenTransitionType.none);

    expect(_page, findsOneWidget);
    expect(_above(FadeTransition), findsNothing);
    expect(_above(SlideTransition), findsNothing);

    await tester.pumpWidget(_app(fadeTheme, const [_home]));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_above(FadeTransition), findsNothing);
    expect(_above(SlideTransition), findsNothing);
  });

  testWidgets('us05/fr05/e02: a pop of a none page leaves it gone after one '
      'pump', (tester) async {
    await _open(tester, fadeTheme, ScreenTransitionType.none);

    await tester.pumpWidget(_app(fadeTheme, const [_home]));
    await tester.pump();

    expect(_page, findsNothing);
  });

  for (final signal in ['disableAnimations', 'reduceMotion']) {
    testWidgets('us05/fr03, nfr-u03: under $signal rightToLeft shows the '
        'page at once', (tester) async {
      if (signal == 'reduceMotion') {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await _open(
        tester,
        fadeTheme,
        ScreenTransitionType.rightToLeft,
        reducedMotion: signal == 'disableAnimations',
      );

      expect(_page, findsOneWidget);
      expect(_above(SlideTransition), findsNothing);
    });
  }

  group('ruling R10: a type that needs a caller input', () {
    testWidgets('scale grows from the center and never throws', (tester) async {
      await _open(tester, fadeTheme, ScreenTransitionType.scale);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<ScaleTransition>(_above(ScaleTransition)).alignment,
        Alignment.center,
      );
    });

    testWidgets('rightToLeftJoined never throws', (tester) async {
      await _open(tester, fadeTheme, ScreenTransitionType.rightToLeftJoined);

      expect(tester.takeException(), isNull);
      expect(_above(SlideTransition), findsWidgets);
    });
  });

  group('us05/fr01: the page below a new page', () {
    /// The left edge of the page keyed [key].
    double dxOf(WidgetTester tester, String key) =>
        tester.getTopLeft(find.byKey(ValueKey(key))).dx;

    testWidgets('cupertino parallaxes a MaterialPage out', (tester) async {
      await _open(tester, fadeTheme, ScreenTransitionType.cupertino);

      expect(dxOf(tester, 'home'), lessThan(0));
    });

    testWidgets('rightToLeftJoined slides a MaterialPage out joined to it', (
      tester,
    ) async {
      await _open(tester, fadeTheme, ScreenTransitionType.rightToLeftJoined);

      expect(dxOf(tester, 'home'), lessThan(0));
      expect(
        dxOf(tester, 'home'),
        closeTo(dxOf(tester, 'page') - tester.getSize(_page).width, 1e-6),
      );
    });

    testWidgets('a joined page over a joined page moves it once', (
      tester,
    ) async {
      const lower = StratumTransitionPage<void>(
        key: ValueKey('lowerPage'),
        type: ScreenTransitionType.rightToLeftJoined,
        child: SizedBox(key: ValueKey('lower')),
      );
      await tester.pumpWidget(_app(fadeTheme, const [_home, lower]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _app(fadeTheme, [
          _home,
          lower,
          _next(ScreenTransitionType.rightToLeftJoined),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(dxOf(tester, 'lower'), lessThan(0));
      expect(
        dxOf(tester, 'lower'),
        closeTo(dxOf(tester, 'page') - tester.getSize(_page).width, 1e-6),
      );
    });

    testWidgets("a MaterialPage moves a joined page out by the theme's "
        'joined type', (tester) async {
      final joinedTheme = motionTheme(
        transitions: transitionsOf(ScreenTransitionType.rightToLeftJoined),
      );
      final pages = [_home, _next(ScreenTransitionType.rightToLeftJoined)];
      await tester.pumpWidget(_app(joinedTheme, pages));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _app(joinedTheme, [
          ...pages,
          const MaterialPage<void>(
            key: ValueKey('upperPage'),
            child: SizedBox(key: ValueKey('upper')),
          ),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(dxOf(tester, 'page'), lessThan(0));
      expect(
        dxOf(tester, 'page'),
        closeTo(dxOf(tester, 'upper') - tester.getSize(_page).width, 1e-6),
      );
    });
  });

  testWidgets('the route scopes its page for assistive technology, as a '
      "MaterialPage's does", (tester) async {
    await _open(tester, fadeTheme, ScreenTransitionType.rightToLeft);

    final scopes = find.ancestor(
      of: _page,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.scopesRoute == true &&
            widget.explicitChildNodes,
      ),
    );
    expect(scopes, findsOneWidget);
  });

  test('the page keeps its type and child', () {
    final page = _next(ScreenTransitionType.cupertino);

    expect(page.type, ScreenTransitionType.cupertino);
    expect(page.key, const ValueKey('next'));
  });
}
