import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/transition_demo.dart';

final Finder _tabBar = find.byKey(const ValueKey('tabBar'));
final Finder _inside = find.byKey(const ValueKey('insidePage'));
final Finder _full = find.byKey(const ValueKey('fullScreenPage'));

/// Pumps the demo on the package default theme, settled on tab A.
Future<void> _start(WidgetTester tester) async {
  final themes = await tester.runAsync(loadTransitionDemoTheme);
  await tester.pumpWidget(TransitionDemoApp(themes: themes!));
  await tester.pumpAndSettle();
}

/// Scrolls the widget keyed [key] into view and taps it.
Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}

/// The page the route that holds [finder] was built from.
Object? _pageOf(WidgetTester tester, Finder finder) =>
    ModalRoute.of(tester.element(finder))!.settings;

void main() {
  testWidgets(
    "us10/fr01, us10/fr01/e04: the page shows the tab bar, the theme's "
    'transition and the nineteen types to pick, and checks 1 to 3, each '
    'naming its step and its result',
    (tester) async {
      await _start(tester);

      expect(_tabBar, findsOneWidget);
      expect(find.byKey(const ValueKey('pick-theme')), findsOneWidget);
      expect(ScreenTransitionType.values, hasLength(19));
      for (final type in ScreenTransitionType.values) {
        expect(find.byKey(ValueKey('pick-${type.name}')), findsOneWidget);
      }
      expect(find.text(checkInside), findsOneWidget);
      expect(find.text(checkFullScreen), findsOneWidget);
      expect(find.text(checkBack), findsOneWidget);
      expect(
        checkInside,
        allOf(contains('Open inside'), contains('the tab bar stays')),
      );
      expect(
        checkFullScreen,
        allOf(contains('Open full screen'), contains('the tab bar included')),
      );
      expect(
        checkBack,
        allOf(contains('"Back"'), contains('leaves with its transition')),
      );
    },
  );

  testWidgets("us10/fr01: the tabs switch the shell's pages while the tab "
      'bar stays where it is', (tester) async {
    await _start(tester);
    final bar = tester.getTopLeft(_tabBar);

    await tester.tap(find.byIcon(Icons.filter_2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(_tabBar), bar);

    await tester.pumpAndSettle();
    expect(find.text('Page transition demo, tab B'), findsOneWidget);
    expect(tester.getTopLeft(_tabBar), bar);
  });

  testWidgets("us10/s1, us10/fr01/e01, us10/fr01/e03: with the theme's "
      'transition the page opens inside the shell as a plain Material page '
      'while the tab bar stays where it is', (tester) async {
    await _start(tester);
    final bar = tester.getTopLeft(_tabBar);

    await _tap(tester, 'openInside');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_pageOf(tester, _inside), isA<MaterialPage<void>>());
    expect(tester.getTopLeft(_tabBar), bar);

    await tester.pumpAndSettle();
    expect(_inside, findsOneWidget);
    expect(tester.getTopLeft(_tabBar), bar);
  });

  testWidgets('us10/s2, us10/fr01/e02: a picked transition opens the page '
      'inside the shell as a StratumTransitionPage of that type while the '
      'tab bar stays where it is', (tester) async {
    await _start(tester);
    await _tap(tester, 'pick-rightToLeftJoined');
    await tester.pumpAndSettle();
    final bar = tester.getTopLeft(_tabBar);

    await _tap(tester, 'openInside');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      _pageOf(tester, _inside),
      isA<StratumTransitionPage<void>>().having(
        (page) => page.type,
        'type',
        ScreenTransitionType.rightToLeftJoined,
      ),
    );
    expect(tester.getTopLeft(_tabBar), bar);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_tabBar), bar);
  });

  testWidgets('us10/s3: the full-screen page covers the shell, its tab bar '
      'included, and the page inside the shell moves only with the shell', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, 'openInside');
    await tester.pumpAndSettle();

    await _tap(tester, 'openFullScreenFromInside');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.getTopLeft(_inside).dx,
      closeTo(tester.getTopLeft(_tabBar).dx, 1e-6),
    );

    await tester.pumpAndSettle();
    expect(_full, findsOneWidget);
    expect(_tabBar, findsNothing);
    expect(_inside, findsNothing);
  });

  testWidgets('us10/s4: back closes the opened page with its transition, '
      'and the page under it shows again', (tester) async {
    await _start(tester);
    await _tap(tester, 'openInside');
    await tester.pumpAndSettle();

    await _tap(tester, 'back');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_inside, findsOneWidget);
    expect(
      ModalRoute.of(tester.element(_inside))!.animation!.status,
      AnimationStatus.reverse,
    );

    await tester.pumpAndSettle();
    expect(_inside, findsNothing);
    expect(find.byKey(const ValueKey('openInside')), findsOneWidget);

    await _tap(tester, 'openFullScreen');
    await tester.pumpAndSettle();
    expect(_full, findsOneWidget);
    expect(_tabBar, findsNothing);

    await _tap(tester, 'back');
    await tester.pumpAndSettle();
    expect(_full, findsNothing);
    expect(_tabBar, findsOneWidget);
  });
}
