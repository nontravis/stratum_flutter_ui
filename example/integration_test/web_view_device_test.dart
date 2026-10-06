import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// Same import as lib/main.dart, the demo this test walks.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/web_view.dart';
import 'package:stratum_ui_example/main.dart';

/// Turns on the screenshot checkpoints (F-01 US-08 FR-01 input
/// `checkpoints`): `--dart-define=WEB_VIEW_CHECKPOINTS=true`.
const _checkpoints = bool.fromEnvironment('WEB_VIEW_CHECKPOINTS');

/// How long a native checkpoint holds still for the capture script.
const _hold = Duration(seconds: 3);

/// How long a group B case keeps listening after its first report, so a
/// second report of the same failure shows up.
const _settle = Duration(seconds: 2);

/// The URL tab prints a failed load as `<type>: <description>`.
final _errorLine = RegExp(r'^(network|http): ');

/// Walks the web view demo on every target (group A) and, on native
/// targets, drives StratumWebView against a local page server (group B).
/// F-01 US-08 FR-01 of `example/docs/`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('group A, the demo tabs', () {
    testWidgets(
      'us08/s1, us08/s8, us08/fr01, us08/fr01/e06: the URL, HTML, and '
      'Bridge tabs show their content',
      (tester) async {
        await tester.pumpWidget(const StratumWebViewExampleApp());

        // The URL tab shows a spinner from onPageStarted to onPageFinished,
        // and an error line from onError. On the web the page starts at
        // once and a refused frame finishes within a few frames, so this
        // polls every frame from the first one on.
        final spinner = find.byType(CircularProgressIndicator);
        final started = await _pumpUntil(
          tester,
          () =>
              spinner.evaluate().isNotEmpty ||
              find.textContaining(_errorLine).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 45),
          interval: const Duration(milliseconds: 16),
        );
        final loaded =
            started &&
            await _pumpUntil(
              tester,
              () => spinner.evaluate().isEmpty,
              timeout: const Duration(seconds: 45),
            );
        await _checkpoint(binding, tester, 'a_url');
        expect(
          started,
          isTrue,
          reason: 'the URL tab never started loading https://flutter.dev',
        );
        expect(
          loaded,
          isTrue,
          reason: 'the URL tab never finished loading https://flutter.dev',
        );
        expect(find.textContaining(_errorLine), findsNothing);
        expect(find.byType(StratumWebView), findsOneWidget);

        await tester.tap(find.text('HTML'));
        await tester.pump(const Duration(seconds: 2));
        await _checkpoint(binding, tester, 'a_html');
        expect(find.byType(StratumWebView), findsOneWidget);

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
      },
    );
  });

  group('us08/s7, us08/fr01/e01, us08/fr01/e02, us08/fr01/e03, '
      'us08/fr01/e05: group B, native only', () {
    late _PageServer server;

    setUpAll(() async => server = await _PageServer.start());
    tearDownAll(() => server.close());

    testWidgets(
      'us08/s2, us08/fr01: a 200 page starts and finishes with no error',
      (tester) async {
        final page = server.page('/ok');
        final recorder = await _showPage(tester, page);
        final finished = await _pumpUntil(
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

    testWidgets('us08/s4, us08/fr01: a plain 404 reports one http error', (
      tester,
    ) async {
      final page = server.page('/missing');
      final recorder = await _showPage(tester, page);
      final reported = await _pumpUntil(
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

    testWidgets(
      'us08/s5, us08/fr01/e04: a 302 then 404 reports one http error that '
      'names the redirect target',
      (tester) async {
        // CO-01-02 US-01 FR-02 E07 of the package docs.
        final page = server.page('/redirect');
        final target = server.page('/gone');
        final recorder = await _showPage(tester, page);
        final reported = await _pumpUntil(
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
      },
    );

    testWidgets(
      'us08/s9, us08/fr01/e05: a 302 then 200 starts once, finishes once, '
      'and reports no error',
      (tester) async {
        // CO-01-02 US-01 FR-01 E05 of the package docs: Android's finish for
        // the redirect target before it starts never reaches the app.
        final page = server.page('/redirect-ok');
        final recorder = await _showPage(tester, page);
        final finished = await _pumpUntil(
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
      },
    );

    testWidgets('us08/s6, us08/fr01: a closed port reports one network error', (
      tester,
    ) async {
      final page = await _closedPortPage();
      final recorder = await _showPage(tester, page);
      final reported = await _pumpUntil(
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
      'us08/s10, us08/s11, us08/fr01/e05: going back to a no-store page '
      'that now answers 404 reports start, one http error, finish on '
      'Android, and start, finish with no error on iOS and macOS',
      (tester) async {
        // CO-01-02 US-01 FR-02 E08 and US-04 FR-01 E07 of the package docs.
        final controller = StratumWebViewController();
        final flip = server.page('/flip-nostore', query: 'case=back');
        final recorder = await _showPage(tester, flip, controller: controller);
        final shown = await _pumpUntil(
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
          // WebKit restores the entry from its back-forward cache with no
          // request, so no HTTP error exists to report.
          expect(recorder.kindsSince(mark!), ['started', 'finished']);
          expect(recorder.errors, isEmpty);
        } else {
          expect(recorder.kindsSince(mark!), ['started', 'error', 'finished']);
          expect(recorder.errors, hasLength(1));
          expect(recorder.errors.single.type, StratumWebViewErrorType.http);
          expect(recorder.errors.single.code, HttpStatus.notFound);
          expect(recorder.errors.single.url, flip);
        }
      },
    );

    testWidgets(
      'us08/s10, us08/s11, us08/fr01/e05: going forward to an entry that '
      'answered 404 reports start, one http error, finish on Android, and '
      'start, finish with no error on iOS and macOS',
      (tester) async {
        // CO-01-02 US-01 FR-02 E08: Android replays the 404 from its HTTP
        // cache without a request; WebKit instead restores the entry from
        // its back-forward cache, so only the load's own error exists.
        final controller = StratumWebViewController();
        final first = server.page('/ok');
        final missing = server.page('/missing', query: 'case=forward');
        final recorder = await _showPage(tester, first, controller: controller);
        final shown = await _pumpUntil(
          tester,
          () => recorder.finishes.isNotEmpty,
        );
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
        // One error for the load of the 404 entry, plus one more wherever
        // the move forward re-requests or replays it; the WebKit cache
        // restore adds none.
        expect(recorder.errors, hasLength(_isWebKit() ? 1 : 2));
        expect(recorder.errors.last.type, StratumWebViewErrorType.http);
        expect(recorder.errors.last.code, HttpStatus.notFound);
        expect(recorder.errors.last.url, missing);
        if (_isWebKit()) {
          expect(recorder.kindsSince(mark!), ['started', 'finished']);
        } else {
          expect(recorder.kindsSince(mark!), ['started', 'error', 'finished']);
        }
      },
    );

    testWidgets(
      'us08/s12, us08/fr01/e05: reloading a page that now answers 404 '
      'reports start, one http error, finish',
      (tester) async {
        // CO-01-02 US-01 FR-02 E08 and US-04 FR-01 E07 of the package docs.
        final controller = StratumWebViewController();
        final flip = server.page('/flip', query: 'case=reload');
        final recorder = await _showPage(tester, flip, controller: controller);
        final shown = await _pumpUntil(
          tester,
          () => recorder.finishes.isNotEmpty,
        );
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
      },
    );

    testWidgets(
      'us08/s12, us08/fr01/e05: reloading after a 302 then 404 reports '
      'start, one http error naming the target, finish',
      (tester) async {
        // CO-01-02 US-01 FR-02 E07 and E08: Android reloads the redirect
        // target, never the original address.
        final controller = StratumWebViewController();
        final page = server.page('/redirect');
        final target = server.page('/gone');
        final recorder = await _showPage(tester, page, controller: controller);
        final failed = await _pumpUntil(
          tester,
          () => recorder.errors.isNotEmpty,
        );
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
      },
    );

    testWidgets('us08/s3, us08/fr01: a page on the allowlist and the app trade '
        'messages both ways', (tester) async {
      final controller = StratumWebViewController();
      final page = server.page('/bridge');
      final recorder = await _showPage(
        tester,
        page,
        controller: controller,
        allowedOrigins: {server.origin},
      );
      final ready = await _pumpUntil(
        tester,
        () => recorder.messages.contains('ready'),
      );
      if (ready) await controller.postMessage('ping');
      final echoed =
          ready &&
          await _pumpUntil(
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
  }, skip: kIsWeb);
}

/// Whether this run's engine is WebKit (iOS, macOS), which restores a
/// `goBack` or `goForward` entry from its back-forward cache with no
/// request, so the back and forward cases assert one `onPageStarted`, one
/// `onPageFinished`, and no error; every other native target reports the
/// page's current HTTP status, the start, error, finish order (US-08
/// scenarios 10 and 11).
bool _isWebKit() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Pumps a frame every [interval] until [done] holds; returns `false` once
/// [timeout] passes.
///
/// It never fails on its own, so a case can log what it saw before it
/// asserts.
Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await tester.pump(interval);
  }
  return true;
}

/// Marks the checkpoint [name] (US-08 scenario 8) when checkpoints are on.
///
/// A native target prints `CHECKPOINT $name` and holds still so the capture
/// script outside the repository takes the screenshot; on the web the driver
/// takes it (FR-01 E06).
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

/// Serves group B's pages on 127.0.0.1 at a port the system assigns
/// (FR-01 E02); it runs inside the test and is never a public service.
class _PageServer {
  _PageServer._(this._server);

  final HttpServer _server;

  /// Addresses of the flip pages that have answered once.
  final _answered = <String>{};

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
        // and reload cases (CO-01-02 US-01 FR-02 E08). The no-store variant
        // keeps the page out of the back-forward cache, so going back
        // requests it again.
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

/// An address on a loopback port where nothing listens.
Future<Uri> _closedPortPage() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return Uri.parse('http://127.0.0.1:$port/');
}

/// What one web view reported in a group B case, in arrival order.
class _Recorder {
  final starts = <Uri?>[];
  final finishes = <Uri?>[];
  final errors = <StratumWebViewError>[];
  final messages = <String>[];
  final _events = <String>[];

  void onStarted(Uri? url) {
    starts.add(url);
    _events.add('started $url');
  }

  void onFinished(Uri? url) {
    finishes.add(url);
    _events.add('finished $url');
  }

  void onError(StratumWebViewError error) {
    errors.add(error);
    _events.add(
      'error ${error.type.name} ${error.code} ${error.url} '
      '${error.description}',
    );
  }

  void onMessage(StratumWebViewMessage message) {
    messages.add(message.data);
    _events.add('message ${message.data}');
  }

  /// Prints the callback order of [caseName]; the six cases of FR-01 E05
  /// also assert it.
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
}

/// Shows one StratumWebView on [page] that reports into a new recorder; the
/// test builds its own view, so the demo app keeps its pages (FR-01 E03).
Future<_Recorder> _showPage(
  WidgetTester tester,
  Uri page, {
  StratumWebViewController? controller,
  Set<Uri> allowedOrigins = const <Uri>{},
}) async {
  final recorder = _Recorder();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StratumWebView(
          controller: controller,
          source: StratumWebViewSource.url(page),
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
  final finished = await _pumpUntil(
    tester,
    () => recorder.kindsSince(mark).contains('finished'),
  );
  await tester.pump(_settle);
  return finished ? mark : null;
}
