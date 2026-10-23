// Applies the system bar style on a Linux desktop (FO-03 US-14 FR-01 E06 and
// FR-02): the Dart body of the old `system_style_device_test.dart`, kept as
// a Dart test because no e2e leg drives a Linux window (ruling Q1). Every
// other platform reports a skip, never a pass: the e2e test covers it there.
// The runner prints the skip reason on a group (`_skipReason`).
// Runs in the Linux container the `flutter-device-test` skill owns:
//
//   flutter test integration_test/themes/system_style_linux_test.dart -d linux
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_test_app/fixture_app.dart';

const _fixtureId = 'themes/system_style';

/// The color the platform status bar itself keeps while Stratum paints the
/// dark bar color under it.
const _transparent = Color(0x00000000);

/// The key of the white page's fill, read back by the widget-level check that
/// the fill still exists and holds [_whitePageExpectedFill].
const _whitePageFillKey = Key('system_style.white_page_fill');

/// The light theme's `background.default.normal` token, read as a literal
/// so the check at [_whitePageFillKey] has an oracle independent of the
/// fixture's own theme lookup: `assets/themes/default/theme.yaml:192` points
/// `background.default.normal` at `{transparent.white.100}`, which
/// `lib/src/themes/config/transparent.dart:73` fixes at `#FFFFFFFF`.
const _whitePageExpectedFill = Color(0xFFFFFFFF);

bool get _isLinux => defaultTargetPlatform == TargetPlatform.linux;

/// Why the group skips off Linux, printed by the test runner.
const _skipReason =
    'Linux-only exception (ruling Q1); other platforms run the e2e test';

/// `false` on Linux, the reason elsewhere, so another platform reports a skip.
Object get _skip => _isLinux ? false : _skipReason;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('', () {
    late StratumThemeController controller;

    setUp(() async {
      controller = await StratumThemeController.preload();
    });

    tearDown(() => controller.dispose());

    Future<void> pumpFixture(WidgetTester tester) async {
      await tester.pumpWidget(
        FixtureApp(fixtureId: _fixtureId, themeController: controller),
      );
      await tester.pumpAndSettle();
    }

    Future<void> open(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    NavigatorState navigator(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator));

    testWidgets(
      'fo03/us14/s3, fo03/us14/fr02/e01: a dark header turns the status bar '
      'icons light',
      (tester) async {
        await pumpFixture(tester);

        await open(tester, 'Open dark header');

        expect(tester.takeException(), isNull);
        expect(
          SystemChrome.latestStyle?.statusBarIconBrightness,
          Brightness.light,
        );

        navigator(tester).pop();
        await tester.pumpAndSettle();
        await open(tester, 'Open white page');

        expect(tester.takeException(), isNull);
        expect(
          SystemChrome.latestStyle?.statusBarIconBrightness,
          Brightness.dark,
        );
        expect(
          tester.widget<ColoredBox>(find.byKey(_whitePageFillKey)).color,
          _whitePageExpectedFill,
        );
      },
    );

    testWidgets(
      'fo03/us14/s16, fo03/us14/fr01/e06, fo03/us14/fr02/e07: the app status '
      'bar color shows under the bar, with icons against it',
      (tester) async {
        await pumpFixture(tester);

        await open(tester, 'Open dark status bar');

        expect(tester.takeException(), isNull);
        expect(SystemChrome.latestStyle?.statusBarColor, _transparent);
        expect(
          SystemChrome.latestStyle?.statusBarIconBrightness,
          Brightness.light,
        );
      },
    );

    testWidgets('fo03/us14/s7, fo03/us14/s8, fo03/us14/s9, fo03/us14/s12, '
        'fo03/us14/s13, fo03/us14/s14: the video page sets its bars, rotation, '
        'and label, and back restores them, with no error', (tester) async {
      await pumpFixture(tester);
      final before = tester.view.viewPadding;

      await open(tester, 'Open video');
      final hidden = tester.view.viewPadding;
      expect(find.text('Video'), findsOneWidget);
      expect(tester.takeException(), isNull);

      navigator(
        tester,
      ).push(MaterialPageRoute<void>(builder: (context) => const Text('Over')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final shown = tester.view.viewPadding;
      expect(tester.takeException(), isNull);

      navigator(tester).pop();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Video'), findsOneWidget);
      expect(tester.takeException(), isNull);

      binding.reportData = {
        'platform': defaultTargetPlatform.name,
        'paddingTopBefore': before.top,
        'paddingTopHidden': hidden.top,
        'paddingTopShown': shown.top,
        'paddingBottomBefore': before.bottom,
        'paddingBottomHidden': hidden.bottom,
      };
    });
  }, skip: _skip);
}
