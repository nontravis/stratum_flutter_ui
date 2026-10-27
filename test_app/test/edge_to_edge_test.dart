import 'package:flutter_test/flutter_test.dart';
// The platform seam the package keeps out of its barrel; the loop pumps the
// web view fixture, which would otherwise build the real platform view.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/fixtures.dart';
// stratum_ui owns shared_preferences as its settings store seam; the loop
// pumps page_layout over the default store, which needs a platform instance
// the same way the package's own flutter_test_config provides.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A web view platform that loads nothing and draws an empty box, so the
/// fixture's controller never touches the real platform view.
final class _EmptyPlatformWebView implements PlatformStratumWebView {
  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {}

  @override
  Future<void> load(StratumWebViewSource source) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<Uri?> currentUrl() async => null;

  @override
  Future<void> postMessage(String data, {Uri? targetOrigin}) async {}

  @override
  Future<void> replyToDocument(
    PlatformHtmlDocumentSender document,
    String data,
  ) async {}

  @override
  Widget buildView(BuildContext context) => const SizedBox.expand();

  @override
  void dispose() {}
}

/// The fixtures that keep the host `SafeArea` above their `PageLayout` on
/// purpose, to prove a drawer stays inside the smaller box (FO-06 US-19 FR-04
/// E09).
const _keepsHostSafeArea = {'common/page_drawer_in_safe_area'};

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    debugStratumWebViewPlatformFactory = (_) => _EmptyPlatformWebView();
    addTearDown(() => debugStratumWebViewPlatformFactory = null);
  });

  testWidgets('every fixture that builds a PageLayout, except the one that '
      'proves a drawer inside a smaller box, is hosted with no SafeArea above '
      'it, and every edge-to-edge fixture gets none', (tester) async {
    // The theme preload reads assets, which needs real time, not fake
    // async.
    final theme = await tester.runAsync(
      () => StratumThemeController.preload(googleFontsTimeout: Duration.zero),
    );
    addTearDown(theme!.dispose);

    // The fixtures the loop saw a PageLayout in: a fixture that mounted its
    // PageLayout after the two pumps would be checked by nothing, so the
    // known PageLayout fixtures must all be seen.
    final withPageLayout = <String>{};
    for (final entry in fixtures.entries) {
      await tester.pumpWidget(
        FixtureApp(fixtureId: entry.key, themeController: theme),
      );
      await tester.pump();
      // A second pump lets fixtures whose first build awaits a load, such
      // as page_layout over the settings store, mount their PageLayout.
      await tester.pump();

      final hostSafeArea = find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(SafeArea),
      );
      if (entry.value.edgeToEdge) {
        expect(
          hostSafeArea.evaluate(),
          isEmpty,
          reason:
              '${entry.key} declares edgeToEdge, so the host must add no '
              'SafeArea around it.',
        );
      }

      final pageLayout = find.byType(PageLayout);
      if (pageLayout.evaluate().isNotEmpty) {
        withPageLayout.add(entry.key);
        final safeAreas = find.ancestor(
          of: pageLayout,
          matching: find.byType(SafeArea),
        );
        if (_keepsHostSafeArea.contains(entry.key)) {
          expect(
            safeAreas,
            findsOneWidget,
            reason:
                '${entry.key} keeps the host SafeArea on purpose, so exactly '
                'one must sit above its PageLayout.',
          );
        } else {
          expect(
            safeAreas.evaluate(),
            isEmpty,
            reason:
                '${entry.key} builds a PageLayout, so no SafeArea may sit '
                'above it: PageLayout pads its own slots by the insets, and a '
                'host SafeArea shrinks its box below the screen.',
          );
        }
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    expect(
      withPageLayout,
      containsAll(<String>[
        'common/page_layout',
        'common/page_drawer',
        'common/page_drawer_in_safe_area',
        'common/page_layout_loading',
      ]),
    );
  });
}
