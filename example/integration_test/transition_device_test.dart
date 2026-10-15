// Walks the page transition demo through the theme's transition and the
// nineteen transitions on a device or browser (F-01 US-11 FR-01):
//
//   flutter test integration_test/transition_device_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/transition_device_test.dart \
//     -d web-server --browser-name=chrome
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/transition_demo.dart';

final Finder _tabBar = find.byKey(const ValueKey('tabBar'));
final Finder _inside = find.byKey(const ValueKey('insidePage'));

/// How long one opening or closing may run before the test calls it
/// stuck.
const _stuck = Duration(seconds: 5);

/// Scrolls the widget keyed [key] into view and taps it.
Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}

/// Pumps one frame at a time until [done], and fails at the first frame
/// whose tab bar is off [at], naming [label] (US-11 FR-01 E01).
Future<void> _watch(
  WidgetTester tester,
  String label,
  Offset at,
  bool Function() done,
) async {
  final clock = Stopwatch()..start();
  do {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(_tabBar), at, reason: '$label: the tab bar moved');
    if (clock.elapsed > _stuck) {
      fail('$label: the transition did not end within $_stuck');
    }
  } while (!done());
}

/// Whether the page inside the shell shows and its route has finished
/// coming in.
bool _opened(WidgetTester tester) =>
    _inside.evaluate().isNotEmpty &&
    ModalRoute.of(tester.element(_inside))!.animation!.status ==
        AnimationStatus.completed;

/// Whether the page inside the shell is gone.
bool _closed() => find
    .byKey(const ValueKey('insidePage'), skipOffstage: false)
    .evaluate()
    .isEmpty;

/// Opens a page inside the shell and closes it, watching the tab bar at
/// every frame of both transitions.
Future<void> _openAndClose(WidgetTester tester, String label) async {
  final at = tester.getTopLeft(_tabBar);
  await _tap(tester, 'openInside');
  await _watch(tester, '$label, opening', at, () => _opened(tester));
  await _tap(tester, 'back');
  await _watch(tester, '$label, closing', at, _closed);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late StratumThemeSet themes;
  setUpAll(() async => themes = await loadTransitionDemoTheme());

  testWidgets(
    "f01/us11/s2, f01/us11/fr01: the theme's transition opens and closes "
    'a page inside the shell while the tab bar stays where it is',
    (tester) async {
      await tester.pumpWidget(TransitionDemoApp(themes: themes));
      await tester.pumpAndSettle();

      await _openAndClose(tester, "the theme's transition");
    },
  );

  for (final type in ScreenTransitionType.values) {
    testWidgets('f01/us11/s1, f01/us11/s3, f01/us11/fr01, f01/us11/fr01/e01, f01/us11/fr01/e03: '
        '${type.name} opens and closes a page inside the shell while the tab '
        'bar stays where it is', (tester) async {
      await tester.pumpWidget(TransitionDemoApp(themes: themes));
      await tester.pumpAndSettle();

      await _tap(tester, 'pick-${type.name}');
      await tester.pumpAndSettle();
      await _openAndClose(tester, type.name);
    });
  }
}
