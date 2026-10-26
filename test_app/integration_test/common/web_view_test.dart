import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// The platform seam and message models this test reads are not in the
// package barrel.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/model/web_view/web_view_error.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/model/web_view/web_view_navigation_decision.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/web_view.dart';
// Group A's `debugStratumWebViewPlatformFactory` seam (M3-T10, M3-T11): lets
// the started check read a lasting record of the load callbacks instead of
// a UI state that may never reach a drawn frame.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui_test_app/fixtures/common/web_view.dart';

import 'support/pump_until.dart';

/// Turns on the screenshot checkpoints, a device-round aid that belongs to no
/// story: `--dart-define=WEB_VIEW_CHECKPOINTS=true`.
const _checkpoints = bool.fromEnvironment('WEB_VIEW_CHECKPOINTS');

/// How long a native checkpoint holds still for the capture script.
const _hold = Duration(seconds: 3);

/// How long a group B case keeps listening after its first report, so a
/// second report of the same failure shows up.
const _settle = Duration(seconds: 2);

/// The URL tab prints a failed load as `<type>: <description>`.
final _errorLine = RegExp(r'^(network|http): ');

/// The method channel test_app's `MainActivity` answers on: the device
/// tests' own oracle for the system WebView, apart from stratum_ui's code.
const _webViewFeatures = MethodChannel(
  'dev.stratum.stratum_ui_test_app/web_view_features',
);

/// The `StateError` message of a send with the Android bridge off
/// (CO-01-02 US-03 FR-02 E11).
const _bridgeDisabledMessage =
    'The bridge is disabled because the WebView lacks '
    'WEB_MESSAGE_LISTENER or JS_INJECTION_IN_FRAME_AND_WORLD support.';

/// The WebView major version from which the bridge features must be
/// present: the owner ruling of plan M7-T51, set above the highest measured
/// lack (2026-10-24: `Pixel_2_API_28` 138 and `Pixel_Tablet_API_35` 124 lack
/// them; `Pixel_8_API_37` 149 and `Small_Phone_API_33` 155 have both).
const _bridgeFloorMajor = 146;

/// What the system WebView of an Android device reports about the two
/// features the bridge needs.
class _BridgeFeatures {
  const _BridgeFeatures({
    required this.webMessageListener,
    required this.jsInjectionInFrameAndWorld,
    required this.versionName,
  });

  final bool webMessageListener;
  final bool jsInjectionInFrameAndWorld;
  final String? versionName;

  /// Whether the bridge can open: it needs both features.
  bool get both => webMessageListener && jsInjectionInFrameAndWorld;

  /// The WebView's major version, or null when it reports none.
  int? get major => int.tryParse(versionName?.split('.').first ?? '');
}

/// Asks the system WebView on Android; other platforms have no such limit,
/// so the bridge counts as supported there.
Future<_BridgeFeatures?> _readBridgeFeatures() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final answer = await _webViewFeatures.invokeMapMethod<String, Object?>(
    'bridgeFeatures',
  );
  if (answer == null) {
    throw StateError('test_app answered no WebView features');
  }
  // A key the handler renamed or dropped must fail here, never read as a
  // missing feature.
  for (final key in ['webMessageListener', 'jsInjectionInFrameAndWorld']) {
    if (answer[key] is! bool) {
      throw StateError('test_app answered no boolean "$key": $answer');
    }
  }
  if (!answer.containsKey('versionName')) {
    throw StateError('test_app answered no "versionName": $answer');
  }
  return _BridgeFeatures(
    webMessageListener: answer['webMessageListener']! as bool,
    jsInjectionInFrameAndWorld: answer['jsInjectionInFrameAndWorld']! as bool,
    versionName: answer['versionName'] as String?,
  );
}

/// Chrome's `URL` tab page: the static page `web/web_view_device_page.html`,
/// which the web build serves at the app's own port under the other loopback
/// host name (`localhost` and `127.0.0.1` swap), so the page is cross-origin
/// and no public address loads.
Uri _webCrossOriginPage() {
  final app = Uri.base;
  return Uri(
    scheme: app.scheme,
    host: app.host == 'localhost' ? '127.0.0.1' : 'localhost',
    port: app.port,
    path: '/web_view_device_page.html',
  );
}

/// Walks the web view fixture `common/web_view` on every target (group A),
/// with the `URL` tab pointed at a local page server on Android, iOS, macOS,
/// and Linux, and at a static file of the web build on Chrome; on those same
/// native targets, group B drives StratumWebView against that server
/// directly. CO-01-02 US-01 to US-04 (`Device legs`) and NFR-Sec01 to
/// NFR-Sec03 of US-03.
///
/// Run it with `flutter test integration_test/common/web_view_test.dart -d
/// DEVICE`, or on the web with `flutter drive
/// --driver=test_driver/integration_test.dart
/// --target=integration_test/common/web_view_test.dart -d web-server
/// --browser-name=chrome`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Android alone can lack the bridge, by its system WebView (CO-01-02 US-03
  // FR-01 E11, FR-02 E11). The answer is read at run time, in `setUpAll`,
  // because the round's entry calls `main` unawaited and so no declaration may
  // wait; null off Android, where the bridge counts as open.
  _BridgeFeatures? features;

  // Marks the running case skipped and returns true when the device lacks the
  // bridge: a case that needs the bridge open starts with `if (...) return;`.
  bool skipWithoutBridge() {
    if (features?.both ?? true) return false;
    markTestSkipped('the system WebView lacks the bridge features');
    return true;
  }

  // The same for the E11 cases, which need the bridge off.
  bool skipWithBridge() {
    if (!(features?.both ?? true)) return false;
    markTestSkipped('the bridge is open on this device');
    return true;
  }

  // Starts before group A on Android, iOS, and macOS, so the URL tab never
  // reaches a public test service; group B, native only, reuses
  // this same server instead of starting a second one, except the
  // `co01_02/us03/s8` case, which starts a second server, on another ephemeral
  // port, for page B's origin. On the web, where there is no dart:io, this
  // never runs, and group A's `URL` tab loads the web build's own page
  // under the other loopback name instead.
  late _PageServer server;

  // The URL tab's address: the web build never starts the page server.
  Uri fixtureUrl() => kIsWeb ? _webCrossOriginPage() : server.page('/ok');

  setUpAll(() async {
    features = await _readBridgeFeatures();
    if (!kIsWeb) server = await _PageServer.start();
  });
  tearDownAll(() {
    if (!kIsWeb) server.close();
  });

  group('group A, the fixture tabs', () {
    // Records the URL tab's own load callbacks so the started and loaded
    // checks below read a lasting record, not the spinner, which exists
    // only between onPageStarted and onPageFinished and so can miss every
    // drawn frame (CO-01-02 US-01 Scenario 1 on Linux, M3-T10).
    late _Recorder recorder;

    setUp(() {
      recorder = _Recorder();
      debugStratumWebViewPlatformFactory = (listener) =>
          createPlatformStratumWebView(_ListenerRecorder(listener, recorder));
    });

    tearDown(() => debugStratumWebViewPlatformFactory = null);

    testWidgets('co01_02/us01/s1, co01_02/us02/s1: the URL and HTML tabs show '
        'their content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebViewFixture(
              urlAddress: kIsWeb ? _webCrossOriginPage() : server.page('/ok'),
            ),
          ),
        ),
      );

      if (kIsWeb) {
        expect(
          _webCrossOriginPage().origin,
          isNot(Uri.base.origin),
          reason: 'the URL tab page must be cross-origin to the app',
        );
      }

      // `started` and `loaded` read `recorder`, filled through the
      // platform hook above, not the spinner: the spinner stays below as
      // a logged observation only, never an assertion (M3-T10 Fix
      // direction, Option A).
      final spinner = find.byType(CircularProgressIndicator);
      final started = await pumpUntil(
        tester,
        () => recorder.starts.isNotEmpty || recorder.errors.isNotEmpty,
        budget: const Duration(seconds: 45),
        interval: const Duration(milliseconds: 16),
      );
      if (started && spinner.evaluate().isEmpty) {
        debugPrint('co01_02/us01/s1: started with no spinner frame drawn');
      }
      final loaded =
          started &&
          await pumpUntil(
            tester,
            () => recorder.starts.isEmpty || recorder.finishes.isNotEmpty,
            budget: const Duration(seconds: 45),
          );
      await _checkpoint(binding, tester, 'a_url');
      expect(
        started,
        isTrue,
        reason: 'the URL tab never started loading its address',
      );
      expect(
        loaded,
        isTrue,
        reason: 'the URL tab never finished loading its address',
      );
      expect(find.textContaining(_errorLine), findsNothing);
      expect(find.byType(StratumWebView), findsOneWidget);

      await tester.tap(find.text('HTML'));
      await tester.pump(const Duration(seconds: 2));
      await _checkpoint(binding, tester, 'a_html');
      expect(find.byType(StratumWebView), findsOneWidget);
    });

    // The two Bridge tab cases follow the device's bridge at run time, since a
    // name cannot; neither name opens with the repeat prefix of group B's
    // block, `co01_02/us03/s1`.
    testWidgets('co01_02/us03/s2, co01_02/us03/s1: the Bridge tab sends to the '
        'page and shows no error', (tester) async {
      if (skipWithoutBridge()) return;
      await _pumpFixture(tester, urlAddress: fixtureUrl());
      await tester.tap(find.text('Bridge'));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('No messages yet'), findsOneWidget);
      await tester.tap(find.text('Send to page'));
      await tester.pump(const Duration(seconds: 1));
      await _checkpoint(binding, tester, 'a_bridge');
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'postMessage threw a StateError: the HTML bridge is closed',
      );
    });

    testWidgets('co01_02/us03/fr02/e11: the Bridge tab shows the disabled '
        'bridge error', (tester) async {
      if (skipWithBridge()) return;
      await _pumpFixture(tester, urlAddress: fixtureUrl());
      await tester.tap(find.text('Bridge'));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Send to page'));
      await tester.pump(const Duration(seconds: 1));
      await _checkpoint(binding, tester, 'a_bridge_e11');
      expect(
        find.text(_bridgeDisabledMessage),
        findsOneWidget,
        reason: 'the send did not fail closed with the E11 StateError',
      );
    });
  });

  group('group B, native only', () {
    testWidgets(
      'co01_02/us01/s1: a 200 page starts and finishes with no error',
      (tester) async {
        final page = server.page('/ok');
        final recorder = await _showPage(tester, page);
        final finished = await pumpUntil(
          tester,
          () => recorder.finishes.isNotEmpty,
        );
        await tester.pump(_settle);
        recorder.logOrder('200 page');
        await _checkpoint(binding, tester, 'b_ok');
        expect(finished, isTrue, reason: 'no onPageFinished for $page');
        expect(recorder.starts, isNotEmpty);
        // The page's missing image answers 404: CO-01-02 US-01 FR-02 E02
        // drops a sub-resource error.
        expect(recorder.errors, isEmpty);
      },
    );

    testWidgets('co01_02/us01/s4: a plain 404 reports one http error', (
      tester,
    ) async {
      final page = server.page('/missing');
      final recorder = await _showPage(tester, page);
      final reported = await pumpUntil(
        tester,
        () => recorder.errors.isNotEmpty,
      );
      await tester.pump(_settle);
      recorder.logOrder('plain 404');
      await _checkpoint(binding, tester, 'b_404');
      expect(reported, isTrue, reason: 'no onError for $page');
      expect(recorder.errors, hasLength(1));
      expect(recorder.errors.single.type, StratumWebViewErrorType.http);
      expect(recorder.errors.single.code, HttpStatus.notFound);
      expect(recorder.errors.single.url, page);
    });

    testWidgets('co01_02/us01/s4, co01_02/us01/fr02/e07: a 302 then 404 reports one http error that '
        'names the redirect target', (tester) async {
      // CO-01-02 US-01 FR-02 E07 of the package docs.
      final page = server.page('/redirect');
      final target = server.page('/gone');
      final recorder = await _showPage(tester, page);
      final reported = await pumpUntil(
        tester,
        () => recorder.errors.isNotEmpty,
      );
      await tester.pump(_settle);
      recorder.logOrder('302 then 404');
      await _checkpoint(binding, tester, 'b_redirect');
      expect(reported, isTrue, reason: 'no onError for $page');
      expect(recorder.errors, hasLength(1));
      expect(recorder.errors.single.type, StratumWebViewErrorType.http);
      expect(recorder.errors.single.code, HttpStatus.notFound);
      expect(recorder.errors.single.url, target);
      expect(recorder.kindsSince(0), ['started', 'error', 'finished']);
    });

    testWidgets('co01_02/us01/s1, co01_02/us01/fr01/e05: a 302 then 200 starts once, finishes once, '
        'and reports no error', (tester) async {
      // CO-01-02 US-01 FR-01 E05 of the package docs: Android's finish for
      // the redirect target before it starts never reaches the app.
      final page = server.page('/redirect-ok');
      final recorder = await _showPage(tester, page);
      final finished = await pumpUntil(
        tester,
        () => recorder.finishes.isNotEmpty,
      );
      await tester.pump(_settle);
      recorder.logOrder('302 then 200');
      await _checkpoint(binding, tester, 'b_redirect_ok');
      expect(finished, isTrue, reason: 'no onPageFinished for $page');
      expect(recorder.kindsSince(0), ['started', 'finished']);
      // The /ok page's missing image answers 404: FR-02 E02 drops it.
      expect(recorder.errors, isEmpty);
    });

    testWidgets('co01_02/us01/s4: a closed port reports one network error', (
      tester,
    ) async {
      final page = await _closedPortPage();
      final recorder = await _showPage(tester, page);
      final reported = await pumpUntil(
        tester,
        () => recorder.errors.isNotEmpty,
      );
      await tester.pump(_settle);
      recorder.logOrder('closed port');
      await _checkpoint(binding, tester, 'b_closed');
      expect(reported, isTrue, reason: 'no onError for $page');
      expect(recorder.errors, hasLength(1));
      expect(recorder.errors.single.type, StratumWebViewErrorType.network);
    });

    testWidgets(
      'co01_02/us04/s5, co01_02/us01/fr02/e08, co01_02/us04/fr01/e07: going back to a no-store page '
      'that now answers 404 reports start, one http error, finish on '
      'Android, and start, finish with no error on iOS, macOS, and Linux',
      (tester) async {
        // CO-01-02 US-01 FR-02 E08 and US-04 FR-01 E07 of the package docs.
        final controller = StratumWebViewController();
        final flip = server.page('/flip-nostore', query: 'case=back');
        final recorder = await _showPage(tester, flip, controller: controller);
        final shown = await pumpUntil(
          tester,
          () => recorder.finishes.isNotEmpty,
        );
        await tester.pump(_settle);
        final left =
            shown &&
            await _finishAfter(
                  tester,
                  recorder,
                  () => controller.loadUrl(server.page('/ok')),
                ) !=
                null;
        final mark = left
            ? await _finishAfter(tester, recorder, controller.goBack)
            : null;
        recorder.logOrder('back to 404');
        await _checkpoint(binding, tester, 'b_back');
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        expect(shown, isTrue, reason: 'no onPageFinished for $flip');
        expect(left, isTrue, reason: 'the second page never finished');
        expect(mark, isNotNull, reason: 'no onPageFinished after goBack');
        if (_isWebKit()) {
          _expectWebKitHistoryMove(recorder, mark!, flip);
        } else {
          expect(recorder.kindsSince(mark!), ['started', 'error', 'finished']);
          expect(recorder.errors, hasLength(1));
          expect(recorder.errors.single.type, StratumWebViewErrorType.http);
          expect(recorder.errors.single.code, HttpStatus.notFound);
          expect(recorder.errors.single.url, flip);
        }
      },
    );

    testWidgets('co01_02/us04/s5, co01_02/us01/fr02/e08, co01_02/us04/fr01/e07: going forward to an entry that '
        'answered 404 reports start, one http error, finish on Android, '
        'start, finish with no error on iOS and macOS, and start, the kept '
        'http error, finish on Linux', (tester) async {
      // CO-01-02 US-01 FR-02 E08: Android replays the 404 from its HTTP
      // cache without a request; WebKit either restores the entry from
      // its back-forward cache with no request — no error, or, on Linux,
      // that restored entry's kept 404 reported once — or requests the
      // page again, leaving the load's own error the last one (CO-01-02
      // US-04 Scenario 5).
      final controller = StratumWebViewController();
      final first = server.page('/ok');
      final missing = server.page('/missing', query: 'case=forward');
      final recorder = await _showPage(tester, first, controller: controller);
      final shown = await pumpUntil(tester, () => recorder.finishes.isNotEmpty);
      await tester.pump(_settle);
      final failed =
          shown &&
          await _finishAfter(
                tester,
                recorder,
                () => controller.loadUrl(missing),
              ) !=
              null;
      final back =
          failed &&
          await _finishAfter(tester, recorder, controller.goBack) != null;
      final mark = back
          ? await _finishAfter(tester, recorder, controller.goForward)
          : null;
      recorder.logOrder('forward to 404');
      await _checkpoint(binding, tester, 'b_forward');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(shown, isTrue, reason: 'no onPageFinished for $first');
      expect(failed, isTrue, reason: 'no onPageFinished for $missing');
      expect(back, isTrue, reason: 'no onPageFinished after goBack');
      expect(mark, isNotNull, reason: 'no onPageFinished after goForward');
      if (_isWebKit()) {
        _expectWebKitHistoryMove(recorder, mark!, missing);
      } else {
        // One error for the load of the 404 entry, plus one for the
        // replay from Android's HTTP cache.
        expect(recorder.errors, hasLength(2));
        expect(recorder.errors.last.type, StratumWebViewErrorType.http);
        expect(recorder.errors.last.code, HttpStatus.notFound);
        expect(recorder.errors.last.url, missing);
        expect(recorder.kindsSince(mark!), ['started', 'error', 'finished']);
      }
    });

    testWidgets('co01_02/us04/s5, co01_02/us01/fr02/e08, co01_02/us04/fr01/e07: reloading a page that now answers 404 '
        'reports start, one http error, finish', (tester) async {
      // CO-01-02 US-01 FR-02 E08 and US-04 FR-01 E07 of the package docs.
      final controller = StratumWebViewController();
      final flip = server.page('/flip', query: 'case=reload');
      final recorder = await _showPage(tester, flip, controller: controller);
      final shown = await pumpUntil(tester, () => recorder.finishes.isNotEmpty);
      await tester.pump(_settle);
      final mark = shown
          ? await _finishAfter(tester, recorder, controller.reload)
          : null;
      recorder.logOrder('reload to 404');
      await _checkpoint(binding, tester, 'b_reload');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(shown, isTrue, reason: 'no onPageFinished for $flip');
      expect(mark, isNotNull, reason: 'no onPageFinished after reload');
      expect(recorder.kindsSince(mark!), ['started', 'error', 'finished']);
      expect(recorder.errors, hasLength(1));
      expect(recorder.errors.single.type, StratumWebViewErrorType.http);
      expect(recorder.errors.single.code, HttpStatus.notFound);
      expect(recorder.errors.single.url, flip);
    });

    testWidgets('co01_02/us04/s5, co01_02/us01/fr02/e08, co01_02/us04/fr01/e07: reloading after a 302 then 404 reports '
        'start, one http error naming the target, finish', (tester) async {
      // CO-01-02 US-01 FR-02 E07 and E08: Android reloads the redirect
      // target, never the original address.
      final controller = StratumWebViewController();
      final page = server.page('/redirect');
      final target = server.page('/gone');
      final recorder = await _showPage(tester, page, controller: controller);
      final failed = await pumpUntil(tester, () => recorder.errors.isNotEmpty);
      await tester.pump(_settle);
      final mark = failed
          ? await _finishAfter(tester, recorder, controller.reload)
          : null;
      recorder.logOrder('reload after 302 then 404');
      await _checkpoint(binding, tester, 'b_reload_redirect');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(failed, isTrue, reason: 'no onError for $page');
      expect(mark, isNotNull, reason: 'no onPageFinished after reload');
      expect(recorder.kindsSince(mark!), ['started', 'error', 'finished']);
      // One error for the redirected load, one for the reload.
      expect(recorder.errors, hasLength(2));
      expect(recorder.errors.last.type, StratumWebViewErrorType.http);
      expect(recorder.errors.last.code, HttpStatus.notFound);
      expect(recorder.errors.last.url, target);
    });

    testWidgets('co01_02/us03/s1, co01_02/us03/s2: a page on the allowlist and the app trade '
        'messages both ways', (tester) async {
      if (skipWithoutBridge()) return;
      final controller = StratumWebViewController();
      final page = server.page('/bridge');
      final recorder = await _showPage(
        tester,
        page,
        controller: controller,
        allowedOrigins: {server.origin},
      );
      final ready = await pumpUntil(
        tester,
        () => recorder.messages.contains('ready'),
      );
      if (ready) await controller.postMessage('ping');
      final echoed =
          ready &&
          await pumpUntil(
            tester,
            () => recorder.messages.contains('echo:ping'),
          );
      recorder.logOrder('bridge round trip');
      await _checkpoint(binding, tester, 'b_bridge');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(ready, isTrue, reason: 'the page message "ready" never came');
      expect(echoed, isTrue, reason: 'the page never echoed "ping"');
      expect(recorder.errors, isEmpty);
    });

    testWidgets(
      'co01_02/us03/s3, nf01/NFR-Sec01: the app HTML document and the app '
      'trade messages both ways, the document in standards mode',
      (tester) async {
        if (skipWithoutBridge()) return;
        // CO-01-02 US-03 FR-04 of the package docs: the document proves the
        // per-load nonce, so its messages arrive with no origin and the
        // app's send reaches it; US-02 FR-01 E02: the bootstrap goes after
        // the doctype, so the document keeps standards mode.
        final controller = StratumWebViewController();
        final recorder = await _show(
          tester,
          const StratumWebViewSource.html(_htmlBridgePage),
          controller: controller,
          allowedOrigins: {server.origin},
        );
        final ready = await pumpUntil(
          tester,
          () => recorder.messages.contains('ready:CSS1Compat'),
        );
        if (ready) await controller.postMessage('ping');
        final echoed =
            ready &&
            await pumpUntil(
              tester,
              () => recorder.messages.contains('echo:ping'),
            );
        // A reply to the `ready` message itself, so the native own-HTML
        // reply script (US-03 FR-05 E06) runs on a real engine, not only
        // compared against its own generated output (R-a).
        if (echoed) await controller.reply(recorder.received.first, 'pong');
        final replied =
            echoed &&
            await pumpUntil(
              tester,
              () => recorder.messages.contains('echo:pong'),
            );
        recorder.logOrder('html round trip');
        await _checkpoint(binding, tester, 'b_html');
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        expect(
          ready,
          isTrue,
          reason:
              'the HTML message "ready:CSS1Compat" never came: '
              '${recorder.messages}',
        );
        expect(echoed, isTrue, reason: 'the HTML page never echoed "ping"');
        expect(replied, isTrue, reason: 'the HTML page never echoed "pong"');
        expect(recorder.origins, everyElement(isNull));
      },
    );

    testWidgets('co01_02/us03/s3, co01_02/us03/fr04/e04: a reload keeps the app HTML document connected on Android; '
        'on iOS, macOS, and Linux the reloaded page is empty and the bridge '
        'stays closed', (tester) async {
      if (skipWithoutBridge()) return;
      // CO-01-02 US-03 FR-04 E04 of the package docs: Android parses the
      // same HTML string again, so the reloaded document carries the same
      // nonce; WebKit on iOS and macOS, and WebKitGTK on Linux, reload an
      // empty page, which carries none, so it never says ready and a send
      // throws.
      final controller = StratumWebViewController();
      final recorder = await _show(
        tester,
        const StratumWebViewSource.html(_htmlBridgePage),
        controller: controller,
        allowedOrigins: {server.origin},
      );
      int readyCount() =>
          recorder.messages.where((data) => data.startsWith('ready:')).length;
      final first = await pumpUntil(tester, () => readyCount() == 1);
      final mark = first
          ? await _finishAfter(tester, recorder, controller.reload)
          : null;
      final keepsHtml = _reloadKeepsHtml();
      var again = false;
      var echoed = false;
      if (keepsHtml) {
        again =
            mark != null && await pumpUntil(tester, () => readyCount() == 2);
        if (again) await controller.postMessage('pong');
        echoed =
            again &&
            await pumpUntil(
              tester,
              () => recorder.messages.contains('echo:pong'),
            );
      } else if (mark != null) {
        await expectLater(controller.postMessage('pong'), throwsStateError);
      }
      recorder.logOrder('html reload');
      await _checkpoint(binding, tester, 'b_html_reload');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(first, isTrue, reason: 'the HTML message "ready" never came');
      expect(mark, isNotNull, reason: 'no onPageFinished after reload');
      if (keepsHtml) {
        expect(
          again,
          isTrue,
          reason:
              'the reloaded HTML never sent "ready": this engine did '
              'not keep the nonce on reload (UV-1)',
        );
        expect(echoed, isTrue, reason: 'the reloaded HTML never echoed');
      } else {
        expect(readyCount(), 1, reason: 'the empty reloaded page spoke');
        expect(recorder.messages, isNot(contains('echo:pong')));
      }
    });

    testWidgets('co01_02/us03/s7, nf01/NFR-Sec02: the app HTML document follows a link off the '
        'allowlist, and the next send is refused', (tester) async {
      if (skipWithoutBridge()) return;
      // CO-01-02 US-03 FR-04 E10 of the package docs: the document posts
      // bye on pagehide, so the app withholds the token (FR-02 E10).
      await _expectLinkAwayRefused(
        binding,
        tester,
        away: server.page('/token-copy'),
        html: _htmlLinkAwayPage,
        caseName: 'html link away',
        checkpoint: 'b_html_link_away',
      );
    });

    testWidgets('co01_02/us03/s7, nf01/NFR-Sec02: the app HTML document reopens itself, puts '
        'its root back, follows a link off the allowlist, and the next send is '
        'refused', (tester) async {
      if (skipWithoutBridge()) return;
      // CO-01-02 US-03 FR-04 E14 of the package docs: document.open() erases
      // the pagehide hook, but the bootstrap's observer sees the root
      // removed, even though the page puts it back, and posts bye at once.
      await _expectLinkAwayRefused(
        binding,
        tester,
        away: server.page('/token-copy'),
        html: _htmlReopenLinkAwayPage,
        caseName: 'html reopen link away',
        checkpoint: 'b_html_reopen_link_away',
      );
    });

    testWidgets('co01_02/us03/s8, co01_02/us03/fr05/e03, nf01/NFR-Sec02: a reply after the web view moves from page '
        'A to page B of another allowed origin throws, and page B receives '
        'nothing', (tester) async {
      if (skipWithoutBridge()) return;
      // CO-01-02 US-03 FR-05 E03 of the package docs: a reply reaches only
      // the message's sender, by origin for a URL page.
      final partner = await _PageServer.start();
      addTearDown(partner.close);
      final controller = StratumWebViewController();
      final recorder = await _showPage(
        tester,
        server.page('/bridge'),
        controller: controller,
        allowedOrigins: {server.origin, partner.origin},
      );
      StratumWebViewMessage? readyFrom(_PageServer from) {
        for (final message in recorder.received) {
          if (message.data == 'ready' &&
              message.origin?.port == from.origin.port) {
            return message;
          }
        }
        return null;
      }

      final readyA = await pumpUntil(tester, () => readyFrom(server) != null);
      if (readyA) await controller.loadUrl(partner.page('/bridge'));
      final readyB =
          readyA && await pumpUntil(tester, () => readyFrom(partner) != null);
      Object? refusal;
      if (readyB) {
        try {
          await controller.reply(readyFrom(server)!, 'late');
        } on StateError catch (error) {
          refusal = error;
        }
      }
      if (readyB) await controller.reply(readyFrom(partner)!, 'control');
      final controlled =
          readyB &&
          await pumpUntil(
            tester,
            () => recorder.messages.contains('echo:control'),
          );
      await tester.pump(_settle);
      recorder.logOrder('reply after a move');
      await _checkpoint(binding, tester, 'b_reply_after_move');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(readyA, isTrue, reason: 'page A never said "ready"');
      expect(readyB, isTrue, reason: 'page B never said "ready"');
      expect(
        refusal,
        isA<StateError>(),
        reason: 'the reply to page A reached somewhere after the move',
      );
      expect(
        controlled,
        isTrue,
        reason:
            'page B never echoed "control": it was not listening, so its '
            'silence below proves nothing',
      );
      expect(
        recorder.messages,
        isNot(contains('echo:late')),
        reason: 'page B echoed the refused reply to page A',
      );
      expect(recorder.errors, isEmpty);
    });

    // The E11 cases below run on a device whose system WebView lacks a bridge
    // feature; the pin case after them keeps that set honest.
    testWidgets(
      'co01_02/us03/fr01/e11: a page on the allowlist posts and no page '
      'message reaches onMessage',
      (tester) async {
        if (skipWithBridge()) return;
        // CO-01-02 US-03 FR-01 E11 of the package docs: the bridge stays off
        // and no other channel stands in. The probe page records in its
        // fragment whether `StratumBridge` exists, so an empty `messages`
        // proves a page that ran and found no bridge, not a page that never
        // ran.
        final controller = StratumWebViewController();
        final recorder = await _showPage(
          tester,
          server.page('/bridge-probe'),
          controller: controller,
          allowedOrigins: {server.origin},
        );
        final loaded = await pumpUntil(
          tester,
          () => recorder.finishes.isNotEmpty,
        );
        await tester.pump(_settle);
        final probe = loaded ? (await controller.currentUrl())?.fragment : null;
        recorder.logOrder('e11 page message');
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        expect(loaded, isTrue, reason: 'the probe page never finished');
        expect(
          probe,
          'bridge:absent',
          reason: 'the page did not run, or found a StratumBridge object',
        );
        expect(
          recorder.messages,
          isEmpty,
          reason: 'a page message reached onMessage with the bridge off',
        );
      },
    );

    testWidgets('co01_02/us03/fr02/e11: postMessage throws the disabled-bridge '
        'StateError', (tester) async {
      if (skipWithBridge()) return;
      // CO-01-02 US-03 FR-02 E11 of the package docs.
      final controller = StratumWebViewController();
      final recorder = await _showPage(
        tester,
        server.page('/bridge'),
        controller: controller,
        allowedOrigins: {server.origin},
      );
      final loaded = await pumpUntil(
        tester,
        () => recorder.finishes.isNotEmpty,
      );
      Object? refusal;
      if (loaded) {
        try {
          await controller.postMessage('ping');
        } on StateError catch (error) {
          refusal = error;
        }
      }
      recorder.logOrder('e11 post message');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(loaded, isTrue, reason: 'the bridge page never finished');
      expect(
        refusal,
        isA<StateError>().having(
          (error) => error.message,
          'message',
          _bridgeDisabledMessage,
        ),
        reason: 'postMessage did not fail closed',
      );
    });

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      testWidgets(
        'the Android system WebView of major version $_bridgeFloorMajor or '
        'newer has both bridge features',
        (tester) async {
          // The bridge's measured floor (plan M7-T51): a new enough WebView
          // that reads a feature missing means the device, or this oracle,
          // is wrong, so the run fails instead of passing as E11.
          final read = features;
          if (read == null) fail('the setUpAll read no WebView features');
          final major = read.major;
          if (major == null) {
            fail(
              read.versionName == null
                  ? 'the device reports no WebView package'
                  : 'the system WebView version "${read.versionName}" has no '
                        'major number',
            );
          }
          if (major >= _bridgeFloorMajor) {
            expect(
              read.webMessageListener,
              isTrue,
              reason: 'WebView ${read.versionName} lacks WEB_MESSAGE_LISTENER',
            );
            expect(
              read.jsInjectionInFrameAndWorld,
              isTrue,
              reason:
                  'WebView ${read.versionName} lacks '
                  'JS_INJECTION_IN_FRAME_AND_WORLD',
            );
          }
        },
      );
    }
  }, skip: kIsWeb);

  // Group L runs on Linux alone: WebKitGTK names the sender of each message
  // (CO-01-02 US-06 FR-01). Every "never arrives" case ends on a later message
  // that does arrive, so the order proves the drop, and on a beacon the page
  // sent to the server, which proves the page ran up to its post.
  group('group L, Linux senders', () {
    testWidgets(
      'co01_02/us06/s1: an allowed page posts and the app gets one message '
      'with the origin of that page',
      (tester) async {
        final controller = StratumWebViewController();
        final recorder = await _showPage(
          tester,
          server.page('/bridge'),
          controller: controller,
          allowedOrigins: {server.origin},
        );
        final ready = await pumpUntil(
          tester,
          () => recorder.messages.contains('ready'),
        );
        // The echo is the later message: a second `ready` would sit before
        // it.
        if (ready) await controller.postMessage('ping');
        final echoed =
            ready &&
            await pumpUntil(
              tester,
              () => recorder.messages.contains('echo:ping'),
            );
        recorder.logOrder('linux allowed page');
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        expect(ready, isTrue, reason: 'the page message "ready" never came');
        expect(echoed, isTrue, reason: 'the page never echoed "ping"');
        expect(recorder.messages, ['ready', 'echo:ping']);
        expect(recorder.origins.map(_originText), [
          _originText(server.origin),
          _originText(server.origin),
        ]);
        expect(recorder.errors, isEmpty);
      },
    );

    testWidgets(
      'co01_02/us06/s2, co01_02/us06/fr01/e02, co01_02/us06/fr01/e08: an '
      'allowed page posts as the view moves to another allowed origin and '
      'the message arrives with the first origin',
      (tester) async {
        // Both pages sit on loopback, so the move stays in one web process;
        // the pass rule of the upstream-senders design D6 that lets a process
        // swap drop the message does not apply.
        final partner = await _PageServer.start();
        addTearDown(partner.close);
        final recorder = await _showPage(
          tester,
          _leavePage(server, partner.page('/bridge')),
          allowedOrigins: {server.origin, partner.origin},
        );
        final landed = await pumpUntil(
          tester,
          () => _messageFrom(recorder, 'ready', partner) != null,
        );
        recorder.logOrder('linux allowed page leaves');
        await tester.pumpWidget(const SizedBox());
        final events = recorder.events;
        final startedAt = _moveStartIndex(events);
        final leavings = recorder.received
            .where((message) => message.data.startsWith('leaving:'))
            .toList();
        expect(landed, isTrue, reason: 'the partner page never said "ready"');
        expect(
          startedAt,
          isNonNegative,
          reason: 'the move off the first page never started',
        );
        expect(leavings, isNotEmpty, reason: 'no message of the first page');
        expect(leavings.map((message) => _originText(message.origin)).toSet(), {
          _originText(server.origin),
        }, reason: 'a message of the first page lost its sender origin');
        // A message judged while the partner is the tracked page must still
        // carry its sender's origin, not the partner's.
        expect(
          events
              .skip(startedAt + 1)
              .any((e) => e.startsWith('message leaving:')),
          isTrue,
          reason:
              'every message of the first page arrived before the move '
              'started, so the case cannot tell the sender from the tracked '
              'page',
        );
        expect(
          recorder.messages.where((data) => !data.startsWith('leaving:')),
          ['ready'],
        );
        expect(recorder.errors, isEmpty);
      },
    );

    testWidgets(
      'co01_02/us06/s3, co01_02/us06/fr01/e03: a page off the list posts as '
      'the view moves to an allowed page and the message never arrives',
      (tester) async {
        // A server of its own keeps the beacons of the case above out of this
        // record.
        final offList = await _PageServer.start();
        addTearDown(offList.close);
        final partner = await _PageServer.start();
        addTearDown(partner.close);
        // The beacons join the ordered log, so the page's later posts show
        // against the start of the move; the hook is set before the page
        // loads, so no beacon is missed.
        final recorder = _Recorder();
        offList.onBeacon = (query) => recorder.note('beacon $query');
        await _showPage(
          tester,
          _leavePage(offList, partner.page('/bridge')),
          allowedOrigins: {partner.origin},
          recorder: recorder,
        );
        final landed = await pumpUntil(
          tester,
          () => _messageFrom(recorder, 'ready', partner) != null,
        );
        recorder.logOrder('linux page off the list leaves');
        await tester.pumpWidget(const SizedBox());
        final events = recorder.events;
        final startedAt = _moveStartIndex(events);
        bool isBeacon(String event) => event.startsWith('beacon leaving:');
        expect(
          landed,
          isTrue,
          reason: 'the allowed page never said "ready", the later message',
        );
        expect(
          startedAt,
          isNonNegative,
          reason: 'the move off the first page never started',
        );
        expect(
          events.take(startedAt).any(isBeacon),
          isTrue,
          reason:
              'the page off the list sent no beacon, so it never reached '
              'its post and its silence proves nothing',
        );
        // A beacon follows its message in the same tick, so a beacon after
        // the start shows the page kept posting past it.
        expect(
          events.skip(startedAt + 1).any(isBeacon),
          isTrue,
          reason:
              'the page off the list posted nothing after the move started, '
              'so the case cannot tell the sender from the tracked page',
        );
        expect(recorder.messages, ['ready']);
        expect(recorder.origins.map(_originText), [
          _originText(partner.origin),
        ]);
        expect(recorder.errors, isEmpty);
      },
    );

    testWidgets('co01_02/us06/s4, co01_02/us06/fr01/e05: a same-origin and a '
        'cross-origin iframe in an allowed page post and neither message '
        'arrives', (tester) async {
      // Both origins are on the list, so only the iframe's place in the
      // page can stop the messages.
      final partner = await _PageServer.start();
      addTearDown(partner.close);
      final same = Uri.encodeQueryComponent(
        server.page('/linux-frame-child').toString(),
      );
      final cross = Uri.encodeQueryComponent(
        partner.page('/linux-frame-child').toString(),
      );
      final recorder = await _showPage(
        tester,
        server.page('/linux-frames', query: 'same=$same&cross=$cross'),
        allowedOrigins: {server.origin, partner.origin},
      );
      final topPosted = await pumpUntil(
        tester,
        () => recorder.messages.any((data) => data.startsWith('top:')),
      );
      recorder.logOrder('linux iframes');
      await tester.pumpWidget(const SizedBox());
      expect(
        topPosted,
        isTrue,
        reason: 'the top page never posted, the later message',
      );
      expect(
        recorder.messages,
        ['top:child:present,child:present'],
        reason:
            'a frame message arrived, or a frame had no bridge and so '
            'its silence proves nothing',
      );
      expect(recorder.origins.map(_originText), [_originText(server.origin)]);
      expect(recorder.errors, isEmpty);
    });

    testWidgets('co01_02/us06/s5, co01_02/us06/fr01/e07: a page its server '
        'sandboxes posts from an allowed address and the message never '
        'arrives', (tester) async {
      final controller = StratumWebViewController();
      final recorder = await _showPage(
        tester,
        server.page('/linux-sandbox'),
        controller: controller,
        allowedOrigins: {server.origin},
      );
      final posted = await pumpUntil(
        tester,
        () => server.beacons.any((text) => text.startsWith('sandbox:')),
      );
      if (posted) await controller.loadUrl(server.page('/bridge'));
      final landed =
          posted &&
          await pumpUntil(tester, () => recorder.messages.contains('ready'));
      recorder.logOrder('linux sandboxed page');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(posted, isTrue, reason: 'the sandboxed page sent no beacon');
      expect(
        landed,
        isTrue,
        reason: 'the plain page never said "ready", the later message',
      );
      expect(
        server.beacons,
        contains('sandbox:present'),
        reason: 'the sandboxed page had no bridge, so its silence is empty',
      );
      expect(recorder.messages, ['ready']);
      expect(recorder.errors, isEmpty);
    });

    testWidgets(
      'co01_02/us06/s6, co01_02/us06/fr01/e06: a reply to a page the view '
      'left for another allowed origin throws, and the page shown receives '
      'nothing',
      (tester) async {
        final partner = await _PageServer.start();
        addTearDown(partner.close);
        final controller = StratumWebViewController();
        final recorder = await _showPage(
          tester,
          server.page('/bridge'),
          controller: controller,
          allowedOrigins: {server.origin, partner.origin},
        );
        final readyA = await pumpUntil(
          tester,
          () => _messageFrom(recorder, 'ready', server) != null,
        );
        if (readyA) await controller.loadUrl(partner.page('/bridge'));
        final readyB =
            readyA &&
            await pumpUntil(
              tester,
              () => _messageFrom(recorder, 'ready', partner) != null,
            );
        Object? refusal;
        if (readyB) {
          try {
            await controller.reply(
              _messageFrom(recorder, 'ready', server)!,
              'late',
            );
          } on StateError catch (error) {
            refusal = error;
          }
        }
        // The control reply to page B is the later message: page B echoes
        // it, so its listener works and its silence about `late` counts.
        if (readyB) {
          await controller.reply(
            _messageFrom(recorder, 'ready', partner)!,
            'control',
          );
        }
        final controlled =
            readyB &&
            await pumpUntil(
              tester,
              () => recorder.messages.contains('echo:control'),
            );
        recorder.logOrder('linux reply after a move');
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        expect(readyA, isTrue, reason: 'page A never said "ready"');
        expect(readyB, isTrue, reason: 'page B never said "ready"');
        expect(
          refusal,
          isA<StateError>(),
          reason: 'the reply to page A reached somewhere after the move',
        );
        expect(
          controlled,
          isTrue,
          reason: 'page B never echoed "control", the later message',
        );
        expect(
          recorder.messages,
          isNot(contains('echo:late')),
          reason: 'page B echoed the refused reply to page A',
        );
        expect(recorder.errors, isEmpty);
      },
    );

    testWidgets(
      'co01_02/us06/fr01/e10: a URL page reopens its document, rebuilds it '
      'with DOM calls, posts, and the message arrives with its origin',
      (tester) async {
        final recorder = await _showPage(
          tester,
          server.page('/linux-reopen'),
          allowedOrigins: {server.origin},
        );
        final reopened = await pumpUntil(
          tester,
          () => server.beacons.any((text) => text.startsWith('reopen:')),
        );
        final posted =
            reopened &&
            await pumpUntil(tester, () => recorder.messages.contains('after'));
        recorder.logOrder('linux document reopened');
        await tester.pumpWidget(const SizedBox());
        expect(reopened, isTrue, reason: 'the page never reopened itself');
        expect(
          server.beacons,
          contains('reopen:present'),
          reason: 'the bridge was gone after document.open()',
        );
        expect(
          posted,
          isTrue,
          reason: 'the message after document.open() never arrived',
        );
        expect(recorder.messages, ['before', 'after']);
        expect(recorder.origins.map(_originText), [
          _originText(server.origin),
          _originText(server.origin),
        ]);
        expect(recorder.errors, isEmpty);
      },
    );
  }, skip: kIsWeb || defaultTargetPlatform != TargetPlatform.linux);
}

/// Shows [html], waits for its `ready:`, has it follow a link to [away] with
/// its outbound token in the fragment, then expects the copy to have landed
/// and the next send to be refused.
///
/// [away] copies the token, as a stolen copy would, and reports
/// `copied:true` in its title and fragment; only that positive control
/// makes the refusal prove a revoked proof, not a token that never arrived.
Future<void> _expectLinkAwayRefused(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester, {
  required Uri away,
  required String html,
  required String caseName,
  required String checkpoint,
}) async {
  final controller = StratumWebViewController();
  final recorder = await _show(
    tester,
    StratumWebViewSource.html(html),
    controller: controller,
    allowedOrigins: {Uri.parse('https://allowed.example')},
  );
  final ready = await pumpUntil(
    tester,
    () => recorder.messages.contains('ready:CSS1Compat'),
  );
  if (ready) await controller.postMessage('go:$away');
  final arrived =
      ready &&
      await pumpUntil(
        tester,
        () => recorder.finishes.any((url) => url?.path == away.path),
      );
  String? copied;
  bool? refused;
  if (arrived) {
    await tester.pump(_settle);
    copied = (await controller.currentUrl())?.fragment;
    refused = await controller
        .postMessage('ping')
        .then<bool>(
          (_) => false,
          onError: (Object error) => error is StateError,
        );
  }
  recorder.logOrder(caseName);
  await _checkpoint(binding, tester, checkpoint);
  await tester.pumpWidget(const SizedBox());
  controller.dispose();
  expect(ready, isTrue, reason: 'the HTML message "ready" never came');
  expect(arrived, isTrue, reason: 'the linked page never finished');
  expect(
    copied,
    'copied:true',
    reason:
        'the away page never received the token, so a refusal proves '
        'nothing',
  );
  expect(refused, isTrue, reason: 'the send reached the away page: no bye');
}

/// Whether this run's engine is WebKit: iOS and macOS WebKit, and, on
/// Linux, WebKitGTK. Each restores a `goBack` or `goForward` entry from its
/// back-forward cache with no request, so the back and forward cases assert
/// one `onPageStarted`, one `onPageFinished`, and no error, or the start,
/// error, finish order when the engine asks the server again; every other
/// native target reports the page's current HTTP status (CO-01-02 US-04
/// Scenario 5).
bool _isWebKit() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Whether a `reload` of the app's HTML keeps the document on this engine
/// (CO-01-02 US-03 Scenario 3, FR-04 E04): Android and Windows parse the same HTML string
/// again; WebKit on iOS and macOS and WebKitGTK on Linux reload an empty
/// `about:blank` document that runs no bootstrap, so the bridge stays
/// closed.
bool _reloadKeepsHtml() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows);

/// Asserts the either-outcome contract of one WebKit history move (CO-01-02 US-04
/// Scenario 5): WebKit either restores [entry] from its back-forward
/// cache with no request — start, finish, and no new error, or, when the
/// restored entry itself answered 404 (Linux), that kept 404 reported
/// once — or requests [entry] again, and then the Android order holds
/// with exactly one new `http` error naming [entry], counted since
/// [mark].
void _expectWebKitHistoryMove(_Recorder recorder, int mark, Uri entry) {
  final kinds = recorder.kindsSince(mark);
  final errors = recorder.errorsSince(mark);
  if (kinds.contains('error')) {
    expect(kinds, ['started', 'error', 'finished']);
    expect(errors, hasLength(1));
    expect(errors.single.type, StratumWebViewErrorType.http);
    expect(errors.single.code, HttpStatus.notFound);
    expect(errors.single.url, entry);
  } else {
    expect(kinds, ['started', 'finished']);
    expect(errors, isEmpty);
  }
}

/// Marks the checkpoint [name] (device-round aid) when checkpoints are on.
///
/// A native target prints `CHECKPOINT $name` and holds still so the capture
/// script outside the repository takes the screenshot; on the web the driver
/// takes it.
Future<void> _checkpoint(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  if (!_checkpoints) return;
  if (kIsWeb) {
    await binding.takeScreenshot(name);
    return;
  }
  debugPrint('CHECKPOINT $name');
  await tester.pump(_hold);
}

/// Serves group A's `URL` tab page and group B's pages on 127.0.0.1 at a
/// port the system assigns; it runs inside the test and is
/// never a public service.
class _PageServer {
  _PageServer._(this._server);

  final HttpServer _server;

  /// Addresses of the flip pages that have answered once.
  final _answered = <String>{};

  /// The query of each beacon a page sent to `/posted`, in arrival order: a
  /// lasting proof that a page ran its script up to the beacon, which a
  /// message the app drops cannot give (CO-01-02 US-06 group L).
  final beacons = <String>[];

  /// Called with the query of each beacon, as it arrives.
  void Function(String query)? onBeacon;

  static Future<_PageServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final pages = _PageServer._(server);
    server.listen(pages._answer);
    return pages;
  }

  /// The origin the bridge case puts on the allowlist.
  Uri get origin => Uri.parse('http://127.0.0.1:${_server.port}');

  /// The address of [path] on this server, with [query] when given.
  Uri page(String path, {String? query}) =>
      origin.replace(path: path, query: query);

  void _answer(HttpRequest request) {
    final response = request.response;
    switch (request.uri.path) {
      case '/ok':
        // The missing image is a sub-resource 404 (CO-01-02 US-01 FR-02 E02).
        _writePage(
          response,
          HttpStatus.ok,
          '<h1>Loaded</h1><img src="/missing.png" alt="">',
        );
      case '/redirect':
        response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, page('/gone').toString());
      case '/redirect-ok':
        response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, page('/ok').toString());
      case '/flip' || '/flip-nostore':
        // 200 on the first request of each address, 404 after it: the back
        // and reload cases (CO-01-02 US-01 FR-02 E08). Android skips the
        // back-forward cache for the no-store variant and requests it
        // again; WebKit restores it from the cache the same as `/flip`, so
        // going back there reports the kept status with no request.
        if (request.uri.path == '/flip-nostore') {
          response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        }
        final first = _answered.add(request.uri.toString());
        _writePage(
          response,
          first ? HttpStatus.ok : HttpStatus.notFound,
          first ? '<h1>Flip</h1>' : '<h1>Not found</h1>',
        );
      case '/bridge':
        _writePage(response, HttpStatus.ok, _bridgeBody);
      case '/bridge-probe':
        _writePage(response, HttpStatus.ok, _bridgeProbeBody);
      case '/token-copy':
        _writePage(response, HttpStatus.ok, _tokenCopyBody);
      case '/posted':
        beacons.add(request.uri.query);
        onBeacon?.call(request.uri.query);
        response.statusCode = HttpStatus.noContent;
      case '/linux-leave':
        _writePage(response, HttpStatus.ok, _linuxLeaveBody);
      case '/linux-frames':
        _writePage(response, HttpStatus.ok, _linuxFramesBody);
      case '/linux-frame-child':
        // dart:io sends `X-Frame-Options: SAMEORIGIN` by default, which would
        // block the cross-origin frame from rendering.
        response.headers.removeAll('x-frame-options');
        _writePage(response, HttpStatus.ok, _linuxFrameChildBody);
      case '/linux-sandbox':
        // CO-01-02 US-06 FR-01 E07: the server sandboxes the page, which
        // gives its document an opaque origin.
        response.headers.set(
          'Content-Security-Policy',
          'sandbox allow-scripts',
        );
        _writePage(response, HttpStatus.ok, _linuxSandboxBody);
      case '/linux-reopen':
        _writePage(response, HttpStatus.ok, _linuxReopenBody);
      default:
        // '/missing', '/gone', '/missing.png', and any favicon request.
        _writePage(response, HttpStatus.notFound, '<h1>Not found</h1>');
    }
    response.close();
  }

  static void _writePage(HttpResponse response, int status, String body) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><html><body style="font-family: sans-serif">'
        '$body</body></html>',
      );
  }

  Future<void> close() => _server.close(force: true);
}

/// A page that records in its fragment whether `StratumBridge` exists
/// (`bridge:absent` or `bridge:present`) and posts `ready` only when it does,
/// so the FR-01 E11 case sees a page that ran with the bridge off.
const _bridgeProbeBody = '''
<h1>Bridge probe</h1>
<script>
  window.addEventListener('load', function () {
    var state = typeof StratumBridge === 'undefined' ? 'absent' : 'present';
    history.replaceState(null, '', '#bridge:' + state);
    if (state === 'present') StratumBridge.postMessage('ready');
  });
</script>
''';

/// Says `ready` once loaded and answers each app message with
/// `echo:<data>` (FR-01 output `bridge round trip`).
const _bridgeBody = '''
<h1>Bridge</h1>
<script>
  window.addEventListener('message', function (event) {
    StratumBridge.postMessage('echo:' + event.data);
  });
  window.addEventListener('load', function () {
    StratumBridge.postMessage('ready');
  });
</script>
''';

/// An app HTML document with a doctype: it says `ready:` and its
/// `document.compatMode` once loaded, and answers each app message with
/// `echo:<data>` (FR-01 outputs `html round trip` and `html reload`).
const _htmlBridgePage = '''
<!doctype html>
<html><body style="font-family: sans-serif"><h1>HTML bridge</h1>
<script>
  window.addEventListener('message', function (event) {
    StratumBridge.postMessage('echo:' + event.data);
  });
  window.addEventListener('load', function () {
    StratumBridge.postMessage('ready:' + document.compatMode);
  });
</script>
</body></html>
''';

/// An app HTML document that says `ready:` and its `document.compatMode`
/// once loaded, and on the app message `go:<url>` follows a link to that URL
/// with its outbound token in the fragment (FR-01 output `html link away`).
const _htmlLinkAwayPage = '''
<!doctype html>
<html><body style="font-family: sans-serif"><h1>HTML link away</h1>
<script>
  window.addEventListener('message', function (event) {
    if (String(event.data).indexOf('go:') !== 0) return;
    location.href = event.data.slice(3) + '#' + window.__stratumBridgeToken;
  });
  window.addEventListener('load', function () {
    StratumBridge.postMessage('ready:' + document.compatMode);
  });
</script>
</body></html>
''';

/// The [_htmlLinkAwayPage] document, but on `go:<url>` it first reopens
/// itself and puts its own root element back, which erases its listeners,
/// the bootstrap's `pagehide` hook included (FR-01 output
/// `html reopen link away`).
const _htmlReopenLinkAwayPage = '''
<!doctype html>
<html><body style="font-family: sans-serif"><h1>HTML reopen link away</h1>
<script>
  var root = document.documentElement;
  window.addEventListener('message', function (event) {
    if (String(event.data).indexOf('go:') !== 0) return;
    var url = event.data.slice(3) + '#' + window.__stratumBridgeToken;
    document.open();
    document.appendChild(root);
    location.href = url;
  });
  window.addEventListener('load', function () {
    StratumBridge.postMessage('ready:' + document.compatMode);
  });
</script>
</body></html>
''';

/// Defines the outbound token property from the fragment, as a page holding
/// a stolen copy would, then shows `copied:true` in its title and fragment
/// once a 32-character token arrived: the positive control of FR-01 outputs
/// `html link away` and `html reopen link away`, which the app reads back
/// through the current URL.
const _tokenCopyBody = '''
<h1>Token copy</h1>
<script>
  Object.defineProperty(window, '__stratumBridgeToken', {
    value: location.hash.slice(1),
  });
  document.title = 'copied:' + (location.hash.length === 33);
  history.replaceState(null, '', '#' + document.title);
</script>
''';

/// A page that posts `leaving:<n>` on a 1 ms timer, each post followed by the
/// beacon `leaving:<n>`, and starts a move to the address in its `to` query
/// parameter after the timer began; the timer runs until the page unloads, so
/// posts land both before and after the new page's start reaches the app
/// (CO-01-02 US-06 Scenarios 2 and 3). The beacon reaches the server even when
/// the app drops the message.
const _linuxLeaveBody = '''
<h1>Leaving</h1>
<script>
  window.addEventListener('load', function () {
    var count = 0;
    setInterval(function () {
      count += 1;
      StratumBridge.postMessage('leaving:' + count);
      navigator.sendBeacon('/posted?leaving:' + count);
    }, 1);
    location.href = new URLSearchParams(location.search).get('to');
  });
</script>
''';

/// A page that holds two iframes, the addresses in its `same` and `cross`
/// query parameters, and posts `top:<what the frames said>` only after both
/// frames told it, through `window.postMessage`, whether their bridge exists.
/// Each frame tells after its own post, so the top message is a sentinel that
/// follows both frames' messages (CO-01-02 US-06 Scenario 4).
const _linuxFramesBody = '''
<h1>Frames</h1>
<script>
  var params = new URLSearchParams(location.search);
  var said = [];
  window.addEventListener('message', function (event) {
    if (String(event.data).indexOf('child:') !== 0) return;
    said.push(String(event.data));
    if (said.length === 2) StratumBridge.postMessage('top:' + said.join(','));
  });
  ['same', 'cross'].forEach(function (name) {
    var frame = document.createElement('iframe');
    frame.src = params.get(name);
    document.body.appendChild(frame);
  });
</script>
''';

/// An iframe page that posts `frame:<port>` when its bridge exists, then tells
/// its parent through `window.postMessage` whether it did.
const _linuxFrameChildBody = '''
<h1>Frame</h1>
<script>
  var state = typeof StratumBridge === 'undefined' ? 'absent' : 'present';
  if (state === 'present') StratumBridge.postMessage('frame:' + location.port);
  parent.postMessage('child:' + state, '*');
</script>
''';

/// A page that posts `sandboxed` when its bridge exists, then sends a beacon
/// naming whether it did; the server runs it in a sandbox (CO-01-02 US-06
/// Scenario 5).
const _linuxSandboxBody = '''
<h1>Sandbox</h1>
<script>
  var state = typeof StratumBridge === 'undefined' ? 'absent' : 'present';
  if (state === 'present') StratumBridge.postMessage('sandboxed');
  navigator.sendBeacon('/posted?sandbox:' + state);
</script>
''';

/// A page that posts `before`, reopens its own document, rebuilds its tree
/// with DOM calls, and posts `after` (CO-01-02 US-06 FR-01 E10). The beacon
/// names whether the bridge still exists after the reopen.
const _linuxReopenBody = '''
<h1>Reopen</h1>
<script>
  window.addEventListener('load', function () {
    StratumBridge.postMessage('before');
    document.open();
    var root = document.createElement('html');
    var body = document.createElement('body');
    body.textContent = 'Reopened';
    root.appendChild(body);
    document.appendChild(root);
    var state = typeof StratumBridge === 'undefined' ? 'absent' : 'present';
    navigator.sendBeacon('/posted?reopen:' + state);
    if (state === 'present') StratumBridge.postMessage('after');
  });
</script>
''';

/// The `scheme://host:port` of [origin], or `null` when it names none, so two
/// origins compare as text.
String? _originText(Uri? origin) =>
    origin == null ? null : '${origin.scheme}://${origin.host}:${origin.port}';

/// The address of [from]'s `/linux-leave` page, which starts a move to [to].
Uri _leavePage(_PageServer from, Uri to) => from.page(
  '/linux-leave',
  query: 'to=${Uri.encodeQueryComponent(to.toString())}',
);

/// The index in [events] of the start of the move off the first page, or -1:
/// the first `started` event after the first `finished` event, whatever its
/// address. On Linux that start carries the leaving page's own address, never
/// the page the view moves to (`onPageStarted` names no address, CO-01-02
/// US-01 FR-01).
int _moveStartIndex(List<String> events) {
  final firstFinish = events.indexWhere((e) => e.startsWith('finished '));
  if (firstFinish < 0) return -1;
  final started = events
      .skip(firstFinish + 1)
      .toList()
      .indexWhere((e) => e.startsWith('started '));
  return started < 0 ? -1 : firstFinish + 1 + started;
}

/// The first message in [recorder] with text [data] from [from]'s origin, or
/// `null` when none has arrived.
StratumWebViewMessage? _messageFrom(
  _Recorder recorder,
  String data,
  _PageServer from,
) {
  for (final message in recorder.received) {
    if (message.data == data &&
        _originText(message.origin) == _originText(from.origin)) {
      return message;
    }
  }
  return null;
}

/// An address on a loopback port where nothing listens.
Future<Uri> _closedPortPage() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return Uri.parse('http://127.0.0.1:$port/');
}

/// Forwards every callback to [inner], the controller's own listener, and
/// also feeds the load callbacks to [recorder], so a wrapped
/// `debugStratumWebViewPlatformFactory` can observe them the way group B
/// does, with no change to how the wrapped controller behaves (M3-T11,
/// group A's started check).
final class _ListenerRecorder implements PlatformStratumWebViewListener {
  _ListenerRecorder(this.inner, this.recorder);

  final PlatformStratumWebViewListener inner;
  final _Recorder recorder;

  @override
  Set<Uri> get allowedOrigins => inner.allowedOrigins;

  @override
  void onMessage(StratumWebViewMessage message, PlatformMessageSender sender) =>
      inner.onMessage(message, sender);

  @override
  StratumNavigationDecision onNavigationRequest(Uri url) =>
      inner.onNavigationRequest(url);

  @override
  void onPageStarted(Uri? url) {
    recorder.onStarted(url);
    inner.onPageStarted(url);
  }

  @override
  void onPageFinished(Uri? url) {
    recorder.onFinished(url);
    inner.onPageFinished(url);
  }

  @override
  void onError(StratumWebViewError error) {
    recorder.onError(error);
    inner.onError(error);
  }
}

/// What one web view reported in a group B case, in arrival order.
class _Recorder {
  final starts = <Uri?>[];
  final finishes = <Uri?>[];
  final errors = <StratumWebViewError>[];
  final messages = <String>[];
  final origins = <Uri?>[];
  final received = <StratumWebViewMessage>[];
  final _events = <String>[];
  final _errorAt = <int>[];

  void onStarted(Uri? url) {
    starts.add(url);
    _events.add('started $url');
  }

  void onFinished(Uri? url) {
    finishes.add(url);
    _events.add('finished $url');
  }

  void onError(StratumWebViewError error) {
    _errorAt.add(_events.length);
    errors.add(error);
    _events.add(
      'error ${error.type.name} ${error.code} ${error.url} '
      '${error.description}',
    );
  }

  void onMessage(StratumWebViewMessage message) {
    messages.add(message.data);
    origins.add(message.origin);
    received.add(message);
    _events.add('message ${message.data}');
  }

  /// Every callback and noted line so far, in arrival order.
  List<String> get events => List.unmodifiable(_events);

  /// Adds [line] to the ordered log, for an event the web view does not
  /// report.
  void note(String line) => _events.add(line);

  /// Prints the callback order of [caseName]; the six cases of CO-01-02
  /// US-01 FR-01 E05 also assert it.
  void logOrder(String caseName) => debugPrint(
    'ORDER ${defaultTargetPlatform.name} $caseName: ${_events.join(' | ')}',
  );

  /// The position the next callback takes; [kindsSince] reads from it.
  int get mark => _events.length;

  /// The kind of each page callback since [mark]: `started`, `error`, or
  /// `finished`; messages are left out.
  List<String> kindsSince(int mark) => [
    for (final event in _events.skip(mark))
      if (!event.startsWith('message ')) event.split(' ').first,
  ];

  /// Each error that arrived at or after [mark], so a later move's case
  /// leaves the earlier load's own errors out.
  List<StratumWebViewError> errorsSince(int mark) => [
    for (var i = 0; i < errors.length; i++)
      if (_errorAt[i] >= mark) errors[i],
  ];
}

/// Shows the web view fixture with its URL tab on [urlAddress].
Future<void> _pumpFixture(WidgetTester tester, {required Uri urlAddress}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WebViewFixture(urlAddress: urlAddress)),
      ),
    );

/// Shows one StratumWebView on [page] that reports into a new recorder; the
/// test builds its own view, so the fixture keeps its pages.
Future<_Recorder> _showPage(
  WidgetTester tester,
  Uri page, {
  StratumWebViewController? controller,
  Set<Uri> allowedOrigins = const <Uri>{},
  _Recorder? recorder,
}) => _show(
  tester,
  StratumWebViewSource.url(page),
  controller: controller,
  allowedOrigins: allowedOrigins,
  recorder: recorder,
);

/// Shows one StratumWebView on [source] that reports into [recorder], or into
/// a new one when none is given.
Future<_Recorder> _show(
  WidgetTester tester,
  StratumWebViewSource source, {
  StratumWebViewController? controller,
  Set<Uri> allowedOrigins = const <Uri>{},
  _Recorder? recorder,
}) async {
  recorder ??= _Recorder();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StratumWebView(
          controller: controller,
          source: source,
          allowedOrigins: allowedOrigins,
          onPageStarted: recorder.onStarted,
          onPageFinished: recorder.onFinished,
          onError: recorder.onError,
          onMessage: recorder.onMessage,
        ),
      ),
    ),
  );
  return recorder;
}

/// Runs [action], then pumps until a page finish follows it and listens
/// [_settle] longer; returns the mark taken right before [action], or
/// `null` when no finish came.
Future<int?> _finishAfter(
  WidgetTester tester,
  _Recorder recorder,
  Future<void> Function() action,
) async {
  final mark = recorder.mark;
  await action();
  final finished = await pumpUntil(
    tester,
    () => recorder.kindsSince(mark).contains('finished'),
  );
  await tester.pump(_settle);
  return finished ? mark : null;
}
