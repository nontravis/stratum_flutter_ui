import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

/// A [MaterialApp] below an application whose theme names a fade for
/// every window size.
Widget _app(GlobalKey<NavigatorState> navigator) => MaterialApp(
  navigatorKey: navigator,
  builder: (context, child) => StratumThemeApplication(
    themes: StratumThemeSet(
      light: motionTheme(transitions: transitionsOf(ScreenTransitionType.fade)),
    ),
    themeMode: ThemeMode.light,
    child: child!,
  ),
  home: const SizedBox(),
);

final Finder _page = find.byKey(const ValueKey('page'));

Future<NoPageTransition> _push(WidgetTester tester) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(_app(navigator));
  final route = NoPageTransition(
    builder: (_) => const SizedBox(key: ValueKey('page')),
  );
  navigator.currentState!.push(route).ignore();
  await tester.pump();
  return route;
}

void main() {
  testWidgets('us05/fr02/e02: the durations stay zero under a theme that '
      'names a transition', (tester) async {
    final route = await _push(tester);

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('us05/s3: the page shows in the next frame with no '
      'transition', (tester) async {
    await _push(tester);

    expect(_page, findsOneWidget);
    expect(
      find.ancestor(of: _page, matching: find.byType(FadeTransition)),
      findsNothing,
    );
  });

  testWidgets('us05/fr02/e01: a pop leaves with no transition', (tester) async {
    final route = await _push(tester);
    route.navigator!.pop();
    await tester.pump();

    expect(route.animation!.status, AnimationStatus.dismissed);
    await tester.pump();
    expect(_page, findsNothing);
  });
}
