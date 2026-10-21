// Launch 1 of FO-10 US-01 Scenario 2's cold-restart case: a real close and
// reopen, never a same-process rebuild. This file resets the Stratum
// settings, checks the left pane's default width, sets 400 px through the
// page's own controller (a settled change, never by key or pointer, so a
// profile-mode Android run can drive it too), and waits for that write to
// land in the real store before ending. `widget_setting_restart_2_device_test.dart`
// starts the app again and checks the first frame already shows 400 px.
// Both files are one sequence, app data kept between them, run in roadmap
// phase stratum-device-round, never in a feature session:
//
//   flutter test --no-uninstall \
//     integration_test/widget_setting_restart_1_device_test.dart \
//     integration_test/widget_setting_restart_2_device_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/pump_until.dart';
import 'support/widget_setting_restart_app.dart';

/// `PageLayout`'s own internal settings namespace and value name for the
/// left pane's width (`lib/src/components/common/layout/page_layout.dart`
/// `_settingNamespace` and `_leftWidthName`), read here only to prove a
/// settled write landed in the real store; `PageLayout` exposes neither
/// itself.
const String _pageLayoutNamespace = 'stratum.page_layout';
const String _leftWidthName = 'left_width';

/// The left pane, measured on the pinned test window.
final Key _leftPaneKey = UniqueKey();

/// Captures every report library `stratum_ui` makes through
/// `FlutterError.reportError` during this test, and passes every other
/// report, a failed `expect` included, to the previous handler; restores
/// that handler in [addTearDown]. Mirrors the merged M13 case's own
/// `_captureErrorReports` (`widget_setting_device_test.dart`), since a
/// handler that swallowed every report once hung this suite (RCA
/// `tmp/widget-setting-round/rca-m13.findings.md`).
List<FlutterErrorDetails> _captureErrorReports() {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.library == 'stratum_ui') {
      reported.add(details);
    } else {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return reported;
}

/// The left width a fresh, real-store-backed controller reads back, else
/// null while unset; a new instance every call, so this never reads this
/// process's own cache.
Future<double?> _storedLeftWidth() async {
  final prover = await StratumWidgetSettingsController.preload();
  try {
    return prover.box(_pageLayoutNamespace).global.getDouble(_leftWidthName);
  } finally {
    prover.dispose();
  }
}

/// Polls [_storedLeftWidth] until it reads [expected]: `PageLayout`'s
/// settled save runs fire-and-forget (`WidgetSettingBinding.save`,
/// `unawaited`), so no handle here can await it directly.
Future<bool> _waitForStoredLeftWidth(
  WidgetTester tester,
  double expected, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (await _storedLeftWidth() == expected) return true;
    if (DateTime.now().isAfter(deadline)) return false;
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fo10/us01/s2 setup: launch 1 stores 400 px for the left pane through '
    'the default store and ends',
    (tester) async {
      final reports = _captureErrorReports();

      final reset = await StratumWidgetSettingsController.preload();
      await reset.resetAll();
      reset.dispose();

      // Desktop width (FR-02: 260 px left default at desktop and below,
      // under 1600 px bigDesktop) with plenty of room past 400 px, so no
      // window clamp at draw time interferes with this case's value.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final pageController = PageLayoutController();
      addTearDown(pageController.dispose);
      StratumSplashState<void>? latestState;
      await tester.pumpWidget(
        widgetSettingRestartApp(
          controller: pageController,
          leftPaneKey: _leftPaneKey,
          onState: (state) => latestState = state,
        ),
      );
      final reachedDone = await pumpUntil(
        tester,
        () => latestState is StratumSplashDone<void>,
        timeout: const Duration(seconds: 10),
      );
      expect(
        reachedDone,
        isTrue,
        reason: 'the splash never reached its done state within 10s',
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(_leftPaneKey)).width,
        widgetSettingRestartDefaultLeftWidth,
        reason:
            'with the settings reset and no app width, the left pane opens '
            'at its Figma desktop default (FR-02)',
      );

      pageController.leftWidth = widgetSettingRestartStoredLeftWidth;
      await tester.pump();
      expect(
        tester.getSize(find.byKey(_leftPaneKey)).width,
        widgetSettingRestartStoredLeftWidth,
      );

      final landed = await _waitForStoredLeftWidth(
        tester,
        widgetSettingRestartStoredLeftWidth,
      );
      expect(
        landed,
        isTrue,
        reason:
            'the settled 400 px write never reached the real store within '
            '10s',
      );
      expect(
        reports,
        isEmpty,
        reason: 'the settled save must land with no report',
      );
    },
  );
}
