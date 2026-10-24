// Launch 1 of FO-10 US-01 Scenario 2's cold-restart case on a Linux desktop: a
// real close and reopen, never a same-process rebuild. The Dart body of the
// old `widget_setting_restart_1_device_test.dart`, kept as a Dart test because
// no e2e leg drives a Linux window (ruling Q1). Every other platform reports
// a skip, never a pass: the e2e test covers it there. The runner prints
// the skip reason, set on a group.
//
// This file resets the Stratum settings, checks the left pane's default
// width, sets 300 px through the fixture's own button, and waits for that
// write to land in the real store before ending.
// `page_layout_restart_2_linux_test.dart` starts the app again and checks the
// first frame already shows 300 px. Both files are one sequence: one
// `flutter test` per file, in this order, app data kept between them (one
// desktop `flutter test` run cannot launch a second file,
// flutter/flutter#101031). Run in the Linux container the e2e round owns:
//
//   flutter test integration_test/common/page_layout_restart_1_linux_test.dart -d linux
//   flutter test integration_test/common/page_layout_restart_2_linux_test.dart -d linux
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_test_app/fixture_app.dart';
import 'package:stratum_ui_test_app/fixtures/common/page_layout.dart';

import 'support/pump_until.dart';

const _fixtureId = 'common/page_layout';

/// The left pane's width before any resize, fixed by the test window's
/// pinned desktop size (FR-02: the Figma desktop default, 260 px under
/// `bigDesktop`).
const _defaultLeftWidth = 260.0;

const _leftPaneId = 'page_layout.left_pane';

bool get _isLinux => defaultTargetPlatform == TargetPlatform.linux;

/// Why the group skips off Linux, printed by the test runner.
const _skipReason =
    'Linux-only exception (ruling Q1); other platforms run the e2e test';

/// `false` on Linux, the reason elsewhere, so another platform reports a skip.
Object get _skip => _isLinux ? false : _skipReason;

/// Captures every report library `stratum_ui` makes through
/// `FlutterError.reportError` during this test, and passes every other
/// report, a failed `expect` included, to the previous handler; restores
/// that handler in [addTearDown]. A handler that swallowed every report once
/// hung this suite (RCA `tmp/widget-setting-round/rca-m13.findings.md`).
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('', () {
    testWidgets(
      'fo10/us01/s2 setup: launch 1 stores 300 px for the left pane through '
      'the default store and ends',
      (tester) async {
        // The semantics-identifier finder needs the semantics tree on.
        final semantics = tester.ensureSemantics();

        final reports = _captureErrorReports();

        final reset = await StratumWidgetSettingsController.preload();
        await reset.resetAll();
        reset.dispose();

        // Desktop width (FR-02: 260 px left default at desktop and below,
        // under 1600 px bigDesktop) with plenty of room past 300 px, so no
        // window clamp at draw time interferes with this case's value.
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

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
        await tester.pumpAndSettle();

        expect(
          tester.getSize(leftPane).width,
          _defaultLeftWidth,
          reason:
              'with the settings reset and no app width, the left pane opens '
              'at its Figma desktop default (FR-02)',
        );
        expect(find.text('stored left width: none'), findsOneWidget);

        await tester.tap(find.text('Set left width to 300'));
        await tester.pump();
        expect(
          tester.getSize(leftPane).width,
          pageLayoutFixtureStoredLeftWidth,
        );

        final landed = await pumpUntil(
          tester,
          () => find.text('stored left width: 300').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(
          landed,
          isTrue,
          reason:
              'the settled 300 px write never reached the real store within '
              '10s',
        );
        expect(
          reports,
          isEmpty,
          reason: 'the settled save must land with no report',
        );
        semantics.dispose();
      },
    );
  }, skip: _skip);
}
