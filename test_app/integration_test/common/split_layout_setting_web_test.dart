// Proves FO-10 US-03 FR-03 E01 on a real browser: with `window.localStorage`
// full, one settled widget-setting change keeps its new size for the
// session, the save reports exactly once with library `stratum_ui`
// (`widget_settings_controller.dart`'s own `_report`, PD12), and nothing
// throws. Native and desktop targets have no browser storage quota to
// fill, so this case runs only on web (`kIsWeb`), skipped everywhere else:
//
//   flutter test integration_test/common/split_layout_setting_web_test.dart -d chrome
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/common/split_layout_setting_web_test.dart \
//     -d web-server --browser-name=chrome
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/local_storage.dart';
import 'support/pump_until.dart';

/// The key this test fills `window.localStorage` under, outside the
/// `stratum/` prefix `SettingKeyCodec` uses, so filling storage never
/// touches a real setting value.
const _fillerPrefix = 'fo10-us03-fr03-e01-filler-';

/// One filler value: large enough that filling to quota takes only a
/// handful of writes against a real browser's typical multi-MB-per-origin
/// quota.
final String _fillerChunk = 'x'.padRight(1 << 20, 'x');

/// A write past this many filler keys never refused: an env failure, not
/// this package's.
const _maxFillerKeys = 64;

/// The split's left pane, measured before and after the one settled move.
final Key _leftPaneKey = UniqueKey();

/// Fills `window.localStorage` with filler keys outside the `stratum/`
/// prefix until a write refuses (the browser's own `QuotaExceededError`),
/// then asserts one more probe write still refuses, so a transient hiccup
/// is never mistaken for a full quota. Removes every filler key it set, in
/// [addTearDown], so this test leaves the browser's storage as it found it.
void _fillLocalStorageToQuota() {
  final fillerKeys = <String>['${_fillerPrefix}probe'];
  addTearDown(() {
    for (final key in fillerKeys) {
      removeLocalStorageItem(key);
    }
  });

  Object? fillError;
  for (var index = 0; index < _maxFillerKeys; index++) {
    final key = '$_fillerPrefix$index';
    try {
      setLocalStorageItem(key, _fillerChunk);
      fillerKeys.add(key);
    } on Object catch (error) {
      fillError = error;
      break;
    }
  }
  expect(
    fillError,
    isNotNull,
    reason:
        'localStorage never refused a write after $_maxFillerKeys filler '
        'keys (env)',
  );

  // A refused chunk can still leave up to one chunk of room, enough for any
  // small write. Tops the quota off under one tail key: each halving step
  // keeps the longer value only when the browser accepts it, so less than
  // one character of room remains.
  final tailKey = '${_fillerPrefix}tail';
  fillerKeys.add(tailKey);
  var tailLength = 0;
  for (var step = _fillerChunk.length; step > 0; step >>= 1) {
    try {
      setLocalStorageItem(tailKey, 'x' * (tailLength + step));
      tailLength += step;
    } on Object {
      // Refused: the tail keeps its last accepted value; try a smaller step.
    }
  }

  Object? probeError;
  try {
    setLocalStorageItem('${_fillerPrefix}probe', 'x');
  } on Object catch (error) {
    probeError = error;
  }
  expect(
    probeError,
    isNotNull,
    reason: 'a probe write must still refuse while localStorage stays full',
  );
}

/// Captures every report library `stratum_ui` makes through
/// `FlutterError.reportError` during this test, and passes every other
/// report, a failed `expect` included, to the previous handler: flutter_test
/// asserts that its own handler saw a failure before it ends the test.
/// Restores that handler in [addTearDown].
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

/// The done-state app: a two-pane [SplitLayout] that remembers its sizes
/// under one global widget setting, over the default store
/// (`StratumSharedPreferencesSettingStore`, the real plugin, since the
/// splash below passes no `widgetSettings` of its own).
Widget _doneApp(StratumThemeController controller) => MaterialApp(
  builder: (context, child) => StratumThemeApplication.controlled(
    controller: controller,
    themeMode: ThemeMode.light,
    child: child!,
  ),
  home: Scaffold(
    // Autofocus, matching `split_layout_test.dart`'s own proven setup: the
    // first Tab press needs a focused scope to search from, and finds the
    // divider next since neither pane below holds a Tab stop of its own.
    body: FocusScope(
      autofocus: true,
      child: SplitLayout(
        setting: const WidgetSettingKey.global(),
        panes: [
          SplitPane(
            size: 300,
            min: 100,
            child: ColoredBox(
              key: _leftPaneKey,
              color: const Color(0xFFE0E0E0),
            ),
          ),
          SplitPane(
            flex: 1,
            min: 100,
            child: const ColoredBox(color: Color(0xFF2050C0)),
          ),
        ],
      ),
    ),
  ),
);

/// The splash over [_doneApp]: every frame before done is a plain color,
/// since those frames have no `Overlay` and no `Localizations` above them.
Widget _splashApp(ValueChanged<StratumSplashState<void>> onState) =>
    StratumSplashScreen<void>(
      postload: (context, controller) async {},
      builder: (context, state) {
        onState(state);
        if (state is StratumSplashDone<void>) return _doneApp(state.controller);
        return const ColoredBox(color: Color(0xFF2050C0));
      },
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fo10/us03/fr03/e01: a full localStorage refuses the save, the pane '
    'keeps its new size for the session, and one report names stratum_ui',
    (tester) async {
      final reports = _captureErrorReports();
      _fillLocalStorageToQuota();

      StratumSplashState<void>? latestState;
      await tester.pumpWidget(_splashApp((state) => latestState = state));
      final reachedDone = await pumpUntil(
        tester,
        () => latestState is StratumSplashDone<void>,
        budget: const Duration(seconds: 10),
      );
      expect(
        reachedDone,
        isTrue,
        reason: 'the splash never reached its done state within 10s',
      );
      await tester.pumpAndSettle();
      expect(find.byType(SplitLayout), findsOneWidget);

      final before = tester.getSize(find.byKey(_leftPaneKey)).width;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final reported = await pumpUntil(
        tester,
        () => reports.isNotEmpty,
        budget: const Duration(seconds: 10),
      );
      expect(
        reported,
        isTrue,
        reason: 'the failed save never reported within 10s',
      );

      final after = tester.getSize(find.byKey(_leftPaneKey)).width;
      expect(
        after,
        closeTo(before + 16, 1),
        reason:
            'the pane must keep the new size for the session even though '
            'the save to the full localStorage was refused (PD12)',
      );
      expect(reports, hasLength(1));
      expect(
        reports.single.context.toString(),
        contains('saving a widget setting'),
        reason: 'the one report must come from the refused save',
      );
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );
}
