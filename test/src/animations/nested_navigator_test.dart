import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

/// The host page's bar, outside the nested navigator, as a router
/// shell's tab bar sits outside the shell's own navigator.
final Finder _bar = find.byKey(const ValueKey('bar'));

/// The left edge of the widget keyed [key].
double _dx(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dx;

/// The width of the widget keyed [key].
double _width(WidgetTester tester, String key) =>
    tester.getSize(find.byKey(ValueKey(key))).width;

/// A [MaterialApp] with [outer] as its navigator, below an application
/// of [theme], whose home is a host page: [_bar] above [nested], a
/// navigator nested in the page, as go_router's `ShellRoute` nests one.
Widget _app(
  GlobalKey<NavigatorState> outer,
  StratumThemeData theme,
  Widget nested,
) => MaterialApp(
  navigatorKey: outer,
  builder: (context, child) => StratumThemeApplication(
    themes: StratumThemeSet(light: theme),
    themeMode: ThemeMode.light,
    child: child!,
  ),
  home: Column(
    children: [
      const SizedBox(key: ValueKey('bar'), width: double.infinity, height: 56),
      Expanded(child: nested),
    ],
  ),
);

/// A nested navigator keyed [inner] whose first route is a plain
/// Material page keyed `innerHome`.
Widget _pushNavigator(GlobalKey<NavigatorState> inner) => Navigator(
  key: inner,
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const SizedBox.expand(key: ValueKey('innerHome')),
  ),
);

/// A plain Material page route whose page is keyed [key].
MaterialPageRoute<void> _route(String key) => MaterialPageRoute<void>(
  builder: (_) => SizedBox.expand(key: ValueKey(key)),
);

/// The first page of a nested page list, keyed `innerHome`.
const _innerHome = MaterialPage<void>(
  key: ValueKey('innerHomePage'),
  child: SizedBox.expand(key: ValueKey('innerHome')),
);

void main() {
  final joinedTheme = motionTheme(
    transitions: transitionsOf(ScreenTransitionType.rightToLeftJoined),
  );
  final fadeTheme = motionTheme(
    transitions: transitionsOf(ScreenTransitionType.fade),
  );

  testWidgets('fo05/us05/fr01/e06: a push or pop on the nested navigator moves '
      'only its pages and leaves the host page still', (tester) async {
    final inner = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(GlobalKey<NavigatorState>(), joinedTheme, _pushNavigator(inner)),
    );

    inner.currentState!.push(_route('innerPage')).ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(_bar), Offset.zero);
    expect(_dx(tester, 'innerHome'), lessThan(0));
    expect(
      _dx(tester, 'innerHome'),
      closeTo(_dx(tester, 'innerPage') - _width(tester, 'innerPage'), 1e-6),
    );

    await tester.pumpAndSettle();
    inner.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(_bar), Offset.zero);
    expect(_dx(tester, 'innerPage'), greaterThan(0));
  });

  testWidgets(
    'fo05/us05/fr01/e06: a push on the outer navigator moves the host '
    'page once, its nested page with it',
    (tester) async {
      final outer = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(outer, joinedTheme, _pushNavigator(GlobalKey<NavigatorState>())),
      );

      outer.currentState!.push(_route('upper')).ignore();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final host = tester.getTopLeft(_bar).dx;
      expect(host, lessThan(0));
      expect(
        host,
        closeTo(_dx(tester, 'upper') - _width(tester, 'upper'), 1e-6),
      );
      expect(_dx(tester, 'innerHome'), closeTo(host, 1e-6));
    },
  );

  testWidgets(
    'fo05/us05/fr01/e06, fo05/us05/fr05: a StratumTransitionPage in the '
    'nested page list moves only the nested pages',
    (tester) async {
      final pages = ValueNotifier<List<Page<Object?>>>(const [_innerHome]);
      addTearDown(pages.dispose);
      await tester.pumpWidget(
        _app(
          GlobalKey<NavigatorState>(),
          fadeTheme,
          ValueListenableBuilder<List<Page<Object?>>>(
            valueListenable: pages,
            builder: (context, list, _) =>
                Navigator(pages: list, onDidRemovePage: (_) {}),
          ),
        ),
      );

      pages.value = const [
        _innerHome,
        StratumTransitionPage<void>(
          key: ValueKey('innerPagePage'),
          type: ScreenTransitionType.rightToLeftJoined,
          child: SizedBox.expand(key: ValueKey('innerPage')),
        ),
      ];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(_bar), Offset.zero);
      expect(_dx(tester, 'innerHome'), lessThan(0));
      expect(
        _dx(tester, 'innerHome'),
        closeTo(_dx(tester, 'innerPage') - _width(tester, 'innerPage'), 1e-6),
      );

      await tester.pumpAndSettle();
      pages.value = const [_innerHome];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.getTopLeft(_bar), Offset.zero);
      expect(_dx(tester, 'innerPage'), greaterThan(0));
    },
  );

  testWidgets(
    'fo05/us05/fr01/e06: every ScreenTransitionType in the nested page list '
    'moves only the nested pages',
    (tester) async {
      final pages = ValueNotifier<List<Page<Object?>>>(const [_innerHome]);
      addTearDown(pages.dispose);
      await tester.pumpWidget(
        _app(
          GlobalKey<NavigatorState>(),
          fadeTheme,
          ValueListenableBuilder<List<Page<Object?>>>(
            valueListenable: pages,
            builder: (context, list, _) =>
                Navigator(pages: list, onDidRemovePage: (_) {}),
          ),
        ),
      );

      const innerPage = ValueKey('innerPage');

      /// What the nested page shows now: where it sits, how big it is, how
      /// opaque, and how much of it a size transition reveals; null while it
      /// is not in the tree.
      (Offset, Size, double, double)? shown() {
        final page = find.byKey(innerPage);
        if (page.evaluate().isEmpty) return null;
        var opacity = 1.0;
        for (final fade in tester.widgetList<FadeTransition>(
          find.ancestor(of: page, matching: find.byType(FadeTransition)),
        )) {
          opacity *= fade.opacity.value;
        }
        var revealed = 1.0;
        for (final size in tester.widgetList<SizeTransition>(
          find.ancestor(of: page, matching: find.byType(SizeTransition)),
        )) {
          revealed *= size.sizeFactor.value;
        }
        return (
          tester.getTopLeft(page),
          tester.getSize(page),
          opacity,
          revealed,
        );
      }

      /// Pumps frames until none is scheduled, failing at the first frame
      /// whose host bar is off the origin, and returns what the nested page
      /// showed at each frame it was in the tree.
      Future<List<(Offset, Size, double, double)>> settleWatching(
        String label,
      ) async {
        final frames = <(Offset, Size, double, double)>[];
        var count = 0;
        do {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getTopLeft(_bar),
            Offset.zero,
            reason: '$label: the host bar moved',
          );
          final frame = shown();
          if (frame != null) frames.add(frame);
          expect(++count, lessThan(300), reason: '$label: never settled');
        } while (tester.binding.hasScheduledFrame);
        return frames;
      }

      for (final type in ScreenTransitionType.values) {
        pages.value = [
          _innerHome,
          StratumTransitionPage<void>(
            key: const ValueKey('innerPagePage'),
            type: type,
            child: const SizedBox.expand(key: innerPage),
          ),
        ];
        final opening = await settleWatching('${type.name}, opening');
        expect(tester.takeException(), isNull, reason: type.name);
        expect(find.byKey(innerPage), findsOneWidget);
        final resting = shown();
        final opened = opening.any((frame) => frame != resting);

        pages.value = const [_innerHome];
        final closing = await settleWatching('${type.name}, closing');
        expect(tester.takeException(), isNull, reason: type.name);
        expect(
          find.byKey(innerPage, skipOffstage: false),
          findsNothing,
          reason: '${type.name}: the nested page is gone',
        );
        final closed = closing.any((frame) => frame != resting);

        expect(
          [opened, closed],
          type == ScreenTransitionType.none ? [false, false] : [true, true],
          reason:
              '${type.name}: the nested page moves or fades on open and on '
              'close, except with no animation',
        );
      }
    },
  );
}
