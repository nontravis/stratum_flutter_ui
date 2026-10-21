// Launch 2 of FO-10 US-01 Scenario 2's cold-restart case: the app starts
// again (a real close and reopen, never a same-process rebuild) and the
// first frame of its page already shows the left pane at the width launch 1
// stored, never at its default width first. `widget_setting_restart_1_device_test.dart`
// is launch 1, and must run immediately before this file in the same lane,
// app data kept between them; alone this file fails naming that. Resets the
// Stratum settings at the end, so the next round starts clean. Runs in
// roadmap phase stratum-device-round, never in a feature session:
//
//   flutter test --no-uninstall \
//     integration_test/widget_setting_restart_1_device_test.dart \
//     integration_test/widget_setting_restart_2_device_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/pump_until.dart';
import 'support/widget_setting_restart_app.dart';

/// The left pane, measured on the pinned test window.
final Key _leftPaneKey = UniqueKey();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fo10/us01/s2: launch 2 shows the left pane at 400 px on its first '
    'frame, never at the default width first',
    (tester) async {
      // Same pinned window as launch 1's: the Figma default this case must
      // never show first is 260 px here, distinct from the 400 px launch 1
      // stored, so a flash of the default would be caught.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Registered first, so it runs even when an expect below fails: a
      // stored 400 px left behind would let a later launch 2 pass without
      // its launch 1.
      addTearDown(() async {
        final reset = await StratumWidgetSettingsController.preload();
        await reset.resetAll();
        reset.dispose();
      });
      final pageController = PageLayoutController();
      addTearDown(pageController.dispose);
      StratumSplashState<void>? latestState;
      final leftWidths = <double>[];
      await tester.pumpWidget(
        widgetSettingRestartApp(
          controller: pageController,
          leftPaneKey: _leftPaneKey,
          onState: (state) => latestState = state,
          onLeftPaneLayout: leftWidths.add,
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

      // One frame, no settle: the restore happens silently in
      // `didChangeDependencies`, before this build, so the very first frame
      // after done must already show the stored width (FR-02).
      await tester.pump();
      expect(
        tester.getSize(find.byKey(_leftPaneKey)).width,
        widgetSettingRestartStoredLeftWidth,
        reason:
            'the first frame after done must show 400 px at once; reading '
            'the default ${widgetSettingRestartDefaultLeftWidth.toInt()} px '
            'here means widget_setting_restart_1_device_test.dart did not '
            'run first in this lane with app data kept, or its write did '
            'not land',
      );

      await tester.pumpAndSettle();
      // Every layout the left pane ever had, its first included, drew 400 px:
      // no frame showed the default before the stored width (US-01 s2).
      expect(leftWidths, isNotEmpty);
      expect(
        leftWidths,
        everyElement(widgetSettingRestartStoredLeftWidth),
        reason: 'a left-pane layout drew another width: $leftWidths',
      );
    },
  );
}
