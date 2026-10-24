// Launch 2 of FO-10 US-01 Scenario 2's cold-restart case on a Linux desktop:
// the app starts again (a real close and reopen, never a same-process
// rebuild) and the first frame of its page already shows the left pane at the
// width launch 1 stored, never at its default width first. The Dart body of
// the old `widget_setting_restart_2_device_test.dart`, kept as a Dart test
// because no e2e leg drives a Linux window (ruling Q1). Every other platform
// reports a skip, never a pass: the e2e test covers it there. The runner prints
// the skip reason, set on a group.
//
// `page_layout_restart_1_linux_test.dart` is launch 1, and must run
// immediately before this file in the same lane, app data kept between them;
// alone this file fails naming that. Resets the Stratum settings at the end,
// so the next round starts clean. Runs in the Linux container the e2e
// round owns:
//
//   flutter test --no-uninstall \
//     integration_test/common/page_layout_restart_1_linux_test.dart \
//     integration_test/common/page_layout_restart_2_linux_test.dart -d linux
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/common/page_layout.dart';

import 'support/pump_until.dart';

const _fixtureId = 'common/page_layout';
const _leftPaneId = 'page_layout.left_pane';

/// The left width the fixture shows with nothing stored, distinct from
/// [pageLayoutFixtureStoredLeftWidth] so a flash of the default is caught.
const _defaultLeftWidth = 260.0;

bool get _isLinux => defaultTargetPlatform == TargetPlatform.linux;

/// Why the group skips off Linux, printed by the test runner.
const _skipReason =
    'Linux-only exception (ruling Q1); other platforms run the e2e test';

/// `false` on Linux, the reason elsewhere, so another platform reports a skip.
Object get _skip => _isLinux ? false : _skipReason;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('', () {
    testWidgets(
      'fo10/us01/s2: launch 2 shows the left pane at 300 px on its first '
      'frame, never at the default width first',
      (tester) async {
        // The semantics-identifier finder needs the semantics tree on.
        final semantics = tester.ensureSemantics();

        // Same pinned window as launch 1's: the Figma default this case must
        // never show first is 260 px here, distinct from the 300 px launch 1
        // stored, so a flash of the default would be caught.
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        // Registered first, so it runs even when an expect below fails: a
        // stored 300 px left behind would let a later launch 2 pass without
        // its launch 1.
        addTearDown(() async {
          final reset = await StratumWidgetSettingsController.preload();
          await reset.resetAll();
          reset.dispose();
        });
        final theme = await StratumThemeController.preload();
        addTearDown(theme.dispose);
        await tester.pumpWidget(
          FixtureApp(fixtureId: _fixtureId, themeController: theme),
        );
        final leftPane = find.bySemanticsIdentifier(_leftPaneId);
        final loaded = await pumpUntil(
          tester,
          () => leftPane.evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(
          loaded,
          isTrue,
          reason: 'the fixture never showed its left pane within 10s',
        );

        // No settle: the restore happens silently before the page's first
        // build, so the very first frame the pane has must already show the
        // stored width (FR-02).
        expect(
          tester.getSize(leftPane).width,
          pageLayoutFixtureStoredLeftWidth,
          reason:
              'the first frame must show 300 px at once; reading the default '
              '${_defaultLeftWidth.toInt()} px here means '
              'page_layout_restart_1_linux_test.dart did not run first in this '
              'lane with app data kept, or its write did not land',
        );

        await tester.pumpAndSettle();
        // The fixture records the left pane's width at its first layout: it
        // drew the stored width, never the default (US-01 s2).
        expect(find.text('first frame left width: 300'), findsOneWidget);
        semantics.dispose();
      },
    );
  }, skip: _skip);
}
