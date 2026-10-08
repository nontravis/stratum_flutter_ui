import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import '../../fakes/native_bridge_envelope.dart';
import '../../fakes/recording_listener.dart';

/// Drives one native adapter through its fake platform.
abstract interface class NativeAdapterHarness {
  PlatformStratumWebView createAdapter(PlatformStratumWebViewListener listener);
  List<Uri> get loadedUrls;
  List<String> get loadedHtml;
  List<String> get scripts;
  List<bool> get javaScriptEnabledStates;
  Set<String> get channelNames;
  int get reloadCount;

  /// What the platform answers for the next dispatch script.
  set scriptResult(Object value);

  /// How the platform answers every later dispatch script, overriding
  /// [scriptResult]: a late answer or a platform error.
  set scriptAnswer(Future<Object> Function() answer);
  void setCurrentUrl(String? url);
  void startPage(String url);
  void finishPage(String url);
  void changeUrl(String? url);

  /// Sends [message] as the document at [senderUrl] would; a platform that
  /// names no sender (Windows, Linux) ignores [senderUrl] and
  /// [isMainFrame].
  void sendBridgeMessage(
    String message, {
    required String senderUrl,
    bool isMainFrame = true,
  });
  Future<bool> requestNavigation(String url, {required bool isMainFrame});
  void failResource({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  });
  void failHttp({required int statusCode, required Uri requestUrl});
}

/// Runs the behavior every native adapter must share.
void runNativeAdapterContract(
  String description,
  NativeAdapterHarness Function() createHarness,
) {
  group(description, () {
    final appOrigin = Uri.parse('https://app.example.com');
    final appPage = Uri.parse('https://app.example.com/home');
    late NativeAdapterHarness harness;
    late RecordingListener listener;
    late PlatformStratumWebView adapter;

    setUp(() async {
      harness = createHarness();
      listener = RecordingListener(allowedOrigins: {appOrigin});
      adapter = harness.createAdapter(listener);
      await pumpEventQueue();
    });

    test('enables JavaScript', () {
      expect(harness.javaScriptEnabledStates, [true]);
    });

    test('loads URL and HTML sources', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      expect(harness.loadedUrls, [appPage]);
      expect(harness.loadedHtml.single, startsWith('<script>'));
      expect(harness.loadedHtml.single, endsWith('</script><p>Hi</p>'));
    });

    test('accepts a message from an allowed page', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..sendBridgeMessage('hello', senderUrl: appPage.toString());
      expect(listener.messages, [
        StratumWebViewMessage(data: 'hello', origin: appOrigin),
      ]);
    });

    test('us03/fr05: every delivered message reaches the listener with its '
        'sender', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..sendBridgeMessage('hello', senderUrl: appPage.toString());
      expect(
        listener.senders.single,
        isA<PlatformUrlPageSender>().having(
          (sender) => sender.origin,
          'origin',
          appOrigin,
        ),
      );
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      final nonce = nonceIn(harness.loadedHtml.last);
      harness
        ..sendBridgeMessage(
          envelope(nonce, 'hello', documentA),
          senderUrl: 'about:blank',
        )
        ..sendBridgeMessage(
          messageEnvelope(nonce, 'm', document: documentB),
          senderUrl: 'about:blank',
        );
      expect(
        listener.senders.last,
        isA<NativeHtmlDocumentSender>().having(
          (sender) => sender.documentId,
          'documentId',
          documentB,
        ),
      );
    });

    test('drops a message from a page outside the allowlist', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage('https://evil.example.net/')
        ..sendBridgeMessage('hello', senderUrl: 'https://evil.example.net/');
      expect(listener.messages, isEmpty);
    });

    test('follows URL changes reported without a page load', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..changeUrl('https://evil.example.net/')
        ..sendBridgeMessage('hello', senderUrl: 'https://evil.example.net/');
      expect(listener.messages, isEmpty);
    });

    test('us03/fr04: loads HTML with the native bootstrap and delivers only '
        'messages that carry its proven nonce, whenever they arrive', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      final html = harness.loadedHtml.single;
      final nonce = nonceIn(html);
      expect(html, endsWith('})();</script><p>Hi</p>'));
      harness
        ..sendBridgeMessage(
          messageEnvelope(nonce, 'before hello'),
          senderUrl: 'about:blank',
        )
        ..sendBridgeMessage(
          envelope(nonce, 'hello', documentA),
          senderUrl: 'about:blank',
        )
        ..sendBridgeMessage(
          messageEnvelope(nonce, 'early'),
          senderUrl: 'about:blank',
        )
        ..startPage('about:blank')
        ..sendBridgeMessage(
          messageEnvelope(nonce, 'from html'),
          senderUrl: 'about:blank',
        )
        ..sendBridgeMessage('untagged', senderUrl: 'about:blank')
        ..startPage('https://evil.example.net/')
        ..sendBridgeMessage(
          messageEnvelope('0' * 32, 'spoofed'),
          senderUrl: 'https://evil.example.net/',
        );
      expect(listener.messages, [
        const StratumWebViewMessage(data: 'early'),
        const StratumWebViewMessage(data: 'from html'),
      ]);
    });

    test('us03/fr04/e04: reloading HTML keeps its nonce; the reloaded '
        "document's hello proves it again", () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      final html = harness.loadedHtml.single;
      final nonce = nonceIn(html);
      harness
        ..startPage('about:blank')
        ..sendBridgeMessage(
          envelope(nonce, 'hello', documentA),
          senderUrl: 'about:blank',
        );
      await adapter.reload();
      harness
        ..sendBridgeMessage(
          envelope(nonce, 'bye', documentA),
          senderUrl: 'about:blank',
        )
        ..startPage('about:blank')
        ..sendBridgeMessage(
          messageEnvelope(nonce, 'between'),
          senderUrl: 'about:blank',
        )
        ..sendBridgeMessage(
          envelope(nonce, 'hello', documentB),
          senderUrl: 'about:blank',
        )
        ..sendBridgeMessage(
          messageEnvelope(nonce, 'after'),
          senderUrl: 'about:blank',
        );
      expect(harness.reloadCount, 1);
      expect(listener.messages, [const StratumWebViewMessage(data: 'after')]);
    });

    test("us03/fr04/e10, us03/fr02/e10: after the proving document's bye, "
        'a send runs the allowlist-only dispatch script', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      final nonce = nonceIn(harness.loadedHtml.single);
      harness
        ..sendBridgeMessage(
          envelope(nonce, 'hello', documentA),
          senderUrl: 'about:blank',
        )
        ..sendBridgeMessage(
          envelope(nonce, 'bye', documentA),
          senderUrl: 'about:blank',
        )
        ..startPage(appPage.toString());
      await adapter.postMessage('ping');
      expect(harness.scripts, [
        buildMessageDispatchScript(
          'ping',
          token: null,
          allowedOrigins: {appOrigin},
        ),
      ]);
    });

    test('us03/fr02/e04: a send to HTML before its hello throws and runs no '
        'script', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      harness.startPage('about:blank');
      await expectLater(
        adapter.postMessage('ping'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The HTML page has not connected the bridge yet.',
          ),
        ),
      );
      expect(harness.scripts, isEmpty);
    });

    test('us03/fr02/e03: after its hello, HTML gets the dispatch script '
        'with its outbound token', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      final html = harness.loadedHtml.single;
      harness.sendBridgeMessage(
        envelope(nonceIn(html), 'hello', documentA),
        senderUrl: 'about:blank',
      );
      await adapter.postMessage('ping');
      expect(harness.scripts.single, contains("t==='${tokenIn(html)}'"));
      expect(listener.messages, isEmpty);
    });

    test('us03/fr02/e10: posts the dispatch script to a URL page', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage(appPage.toString());
      await adapter.postMessage('ping');
      expect(harness.scripts, [
        buildMessageDispatchScript(
          'ping',
          token: null,
          allowedOrigins: {appOrigin},
        ),
      ]);
    });

    test(
      'us03/fr02/e17, nf01/NFR-Sec02: a named send runs the one-target '
      'script, and a refusal throws the StateError naming no origin',
      () async {
        await adapter.load(StratumWebViewSource.url(appPage));
        harness
          ..startPage(appPage.toString())
          ..scriptResult = false;
        final partner = Uri.parse('https://partner.example.net');
        await expectLater(
          adapter.postMessage('x', targetOrigin: partner),
          throwsA(_unallowedPage),
        );
        expect(
          harness.scripts.last,
          buildMessageDispatchScript(
            'x',
            token: null,
            allowedOrigins: [partner],
          ),
        );
      },
    );

    test(
      'us03/fr02/e18: a named send the page shown accepts resolves',
      () async {
        await adapter.load(StratumWebViewSource.url(appPage));
        harness
          ..startPage(appPage.toString())
          ..scriptResult = true;
        await adapter.postMessage('x', targetOrigin: appOrigin);
      },
    );

    test('us03/fr02/e03: a send the page refuses throws a StateError that '
        'names no origin', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage('https://evil.example.net/path?x=secret')
        ..scriptResult = false;
      await expectLater(
        adapter.postMessage('ping'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The current page is not an allowed message destination.',
          ),
        ),
      );
      expect(harness.scripts, hasLength(1));
    });

    test('us03/fr02/e12: a dispatch script with no answer within 5 seconds '
        'throws the StateError of an unallowed page', () {
      fakeAsync((async) {
        // Built inside the fake zone, so every await of the adapter runs on
        // fake time.
        final zonedHarness = createHarness();
        final zonedAdapter = zonedHarness.createAdapter(listener);
        unawaited(zonedAdapter.load(StratumWebViewSource.url(appPage)));
        async.flushMicrotasks();
        zonedHarness
          ..startPage(appPage.toString())
          ..scriptAnswer = () => Completer<Object>().future;
        Object? failure;
        var delivered = false;
        unawaited(
          zonedAdapter
              .postMessage('ping')
              .then(
                (_) => delivered = true,
                onError: (Object error) => failure = error,
              ),
        );
        async.elapse(const Duration(milliseconds: 4999));
        expect(failure, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(delivered, isFalse);
        expect(failure, _unallowedPage);
      });
    });

    test('us03/fr02/e12: a platform error while the dispatch script runs '
        'throws the StateError of an unallowed page', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage(appPage.toString());
      for (final error in <Object>[
        PlatformException(code: 'evaluateJavaScript', message: 'TypeError'),
        ArgumentError('The JavaScript returned `null` or `undefined`.'),
      ]) {
        harness.scriptAnswer = () => Future<Object>.error(error);
        await expectLater(
          adapter.postMessage('ping'),
          throwsA(_unallowedPage),
          reason: '$error',
        );
      }
    });

    test('us03/fr02/e12: an error that is neither a timeout nor a platform '
        'error propagates unchanged', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..scriptAnswer = () =>
            Future<Object>.error(MissingPluginException('no plugin'));
      await expectLater(
        adapter.postMessage('ping'),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('asks the listener about main-frame navigation', () async {
      listener.decision = StratumNavigationDecision.prevent;
      final allowed = await harness.requestNavigation(
        'https://evil.example.net/',
        isMainFrame: true,
      );
      expect(allowed, isFalse);
      expect(listener.navigationRequests, [
        Uri.parse('https://evil.example.net/'),
      ]);
    });

    test('prevents an unparsable main-frame URL without asking', () async {
      final allowed = await harness.requestNavigation(
        'http://[::1',
        isMainFrame: true,
      );
      expect(allowed, isFalse);
      expect(listener.navigationRequests, isEmpty);
    });

    test('lets sub-frame and about: navigation through', () async {
      listener.decision = StratumNavigationDecision.prevent;
      expect(
        await harness.requestNavigation(
          'https://ads.example.net/',
          isMainFrame: false,
        ),
        isTrue,
      );
      expect(
        await harness.requestNavigation('about:blank', isMainFrame: true),
        isTrue,
      );
      expect(listener.navigationRequests, isEmpty);
    });

    test('reports page start and finish', () {
      harness
        ..startPage(appPage.toString())
        ..finishPage(appPage.toString());
      expect(listener.pagesStarted, [appPage]);
      expect(listener.pagesFinished, [appPage]);
    });

    test('forwards main-frame network errors only', () {
      harness
        ..failResource(
          code: -2,
          description: 'ads offline',
          isForMainFrame: false,
          url: 'https://ads.example.net/',
        )
        ..failResource(
          code: -2,
          description: 'offline',
          isForMainFrame: true,
          url: appPage.toString(),
        );
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.network,
          description: 'offline',
          code: -2,
          url: appPage,
        ),
      ]);
    });

    test('forwards HTTP errors for the current page only', () {
      harness
        ..startPage(appPage.toString())
        ..failHttp(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/logo.png'),
        )
        ..failHttp(statusCode: 500, requestUrl: appPage);
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 500',
          code: 500,
          url: appPage,
        ),
      ]);
    });

    test(
      'us01/fr02/e07: Android order, an HTTP error after a main-frame '
      'navigation request reaches onError once and names the target',
      () async {
        final target = Uri.parse('https://app.example.com/gone');
        await harness.requestNavigation(target.toString(), isMainFrame: true);
        harness
          ..finishPage(target.toString())
          ..failHttp(statusCode: 404, requestUrl: target)
          ..startPage(target.toString())
          ..changeUrl(target.toString())
          ..finishPage(target.toString())
          ..failHttp(
            statusCode: 404,
            requestUrl: Uri.parse('https://app.example.com/favicon.ico'),
          );
        expect(listener.errors, [
          StratumWebViewError(
            type: StratumWebViewErrorType.http,
            description: 'HTTP error 404',
            code: 404,
            url: target,
          ),
        ]);
        expect(listener.events, [
          'started $target',
          'error http $target',
          'finished $target',
        ]);
      },
    );

    test('us01/fr01/e05: a page finish with no open start never reaches '
        'onPageFinished and releases no candidate', () async {
      final page = Uri.parse('https://app.example.com/missing');
      await adapter.load(StratumWebViewSource.url(page));
      harness
        ..failHttp(statusCode: 404, requestUrl: page)
        ..finishPage(page.toString());
      expect(listener.events, isEmpty);
    });

    test('us01/fr01/e05: Android order, a 302 then 200 reports one start and '
        'one finish', () async {
      final target = Uri.parse('https://app.example.com/ok');
      await adapter.load(
        StratumWebViewSource.url(
          Uri.parse('https://app.example.com/redirect-ok'),
        ),
      );
      await harness.requestNavigation(target.toString(), isMainFrame: true);
      harness
        ..finishPage(target.toString())
        ..startPage(target.toString())
        ..changeUrl(target.toString())
        ..finishPage(target.toString());
      expect(listener.errors, isEmpty);
      expect(listener.events, ['started $target', 'finished $target']);
    });

    test('us01/fr02/e07, us01/fr02/e08: Android order, a reload after a 302 '
        'then 404 reports start, error, finish on the target', () async {
      final target = Uri.parse('https://app.example.com/gone');
      await adapter.load(
        StratumWebViewSource.url(Uri.parse('https://app.example.com/redirect')),
      );
      await harness.requestNavigation(target.toString(), isMainFrame: true);
      harness
        ..finishPage(target.toString())
        ..failHttp(statusCode: 404, requestUrl: target)
        ..startPage(target.toString())
        ..finishPage(target.toString());
      await adapter.reload();
      harness
        ..failHttp(statusCode: 404, requestUrl: target)
        ..startPage(target.toString())
        ..finishPage(target.toString());
      expect(listener.events, [
        'started $target',
        'error http $target',
        'finished $target',
        'started $target',
        'error http $target',
        'finished $target',
      ]);
    });

    test('us01/fr02/e08, us04/fr01/e07: Android order, goBack to a page that '
        'now answers 404 reports start, error, finish', () async {
      // Pin: P3, the no-store variant.
      final flip = Uri.parse('https://app.example.com/flip');
      final other = Uri.parse('https://app.example.com/b');
      await adapter.load(StratumWebViewSource.url(flip));
      harness
        ..startPage(flip.toString())
        ..finishPage(flip.toString());
      await adapter.load(StratumWebViewSource.url(other));
      harness
        ..startPage(other.toString())
        ..finishPage(other.toString());
      await adapter.goBack();
      harness
        ..failHttp(statusCode: 404, requestUrl: flip)
        ..startPage(flip.toString())
        ..changeUrl(flip.toString())
        ..finishPage(flip.toString());
      expect(listener.events.skip(4), [
        'started $flip',
        'error http $flip',
        'finished $flip',
      ]);
      expect(listener.errors.single.code, 404);
    });

    test('us01/fr02/e08, us01/fr01/e05: Android order, a reload while the '
        "page still loads reports the replaced load's late finish, then "
        'start, error, finish for the reload', () async {
      // R14: the reload ends only the at-once error eligibility, so the
      // load it replaces keeps its finish, and its error waits for its own
      // start.
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage(appPage.toString());
      await adapter.reload();
      harness
        ..finishPage(appPage.toString())
        ..failHttp(statusCode: 503, requestUrl: appPage)
        ..startPage(appPage.toString())
        ..finishPage(appPage.toString());
      expect(listener.events, [
        'started $appPage',
        'finished $appPage',
        'started $appPage',
        'error http $appPage',
        'finished $appPage',
      ]);
      expect(listener.errors.single.code, 503);
    });

    test('us04/fr01/e05: goBack with no entry while the page loads still '
        'reports its finish', () async {
      // R14: the fake's goBack loads no document, like a platform with no
      // previous entry; the move ends no pairing.
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage(appPage.toString());
      await adapter.goBack();
      harness.finishPage(appPage.toString());
      expect(listener.events, ['started $appPage', 'finished $appPage']);
    });

    test('us04/fr01/e05: goBack to a same-document entry while the page '
        'loads still reports its finish', () async {
      // R14: a fragment traversal starts no document, so the loading page's
      // own finish still pairs with its start.
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage(appPage.toString());
      await adapter.goBack();
      harness
        ..changeUrl('https://app.example.com/home#section')
        ..finishPage('https://app.example.com/home#section');
      expect(listener.events, [
        'started $appPage',
        'finished https://app.example.com/home#section',
      ]);
    });

    test('us01/fr01/e05, us01/fr02/e07: WebKit order, a server redirect asked '
        'about after the page start keeps its finish', () async {
      // Pin, R10: an allowed main-frame request leaves the start open. The
      // harness's failHttp always carries a request URL, so the error names
      // the target the URL change reported; M1-T2 pins WebKit's null URL.
      final page = Uri.parse('https://app.example.com/redirect');
      final target = Uri.parse('https://app.example.com/gone');
      await adapter.load(StratumWebViewSource.url(page));
      harness.startPage(page.toString());
      await harness.requestNavigation(target.toString(), isMainFrame: true);
      harness
        ..changeUrl(target.toString())
        ..failHttp(statusCode: 404, requestUrl: target)
        ..finishPage(target.toString());
      expect(listener.events, [
        'started $page',
        'error http $target',
        'finished $target',
      ]);
    });

    test(
      'us01/fr02/e10: Android order, a redirecting navigation the page '
      'starts while it loads lets the stray finish pair with its start',
      () async {
        // Pin, R10 residue (b): the allowed request leaves the loading page's
        // start open, so Android's stray finish for the redirect target pairs
        // with it once; the target's own start and finish follow.
        final page = Uri.parse('https://app.example.com/a');
        final target = Uri.parse('https://app.example.com/b');
        await adapter.load(StratumWebViewSource.url(page));
        harness.startPage(page.toString());
        await harness.requestNavigation(target.toString(), isMainFrame: true);
        harness
          ..finishPage(target.toString())
          ..startPage(target.toString())
          ..finishPage(target.toString());
        expect(listener.events, [
          'started $page',
          'finished $target',
          'started $target',
          'finished $target',
        ]);
      },
    );

    test('us04/fr01: Android order, goBack restored from the back-forward '
        'cache reports start and finish with no error', () async {
      // Pin: P3, the default variant: no request, no error.
      final flip = Uri.parse('https://app.example.com/flip');
      final other = Uri.parse('https://app.example.com/b');
      await adapter.load(StratumWebViewSource.url(flip));
      harness
        ..startPage(flip.toString())
        ..finishPage(flip.toString());
      await adapter.load(StratumWebViewSource.url(other));
      harness
        ..startPage(other.toString())
        ..finishPage(other.toString());
      await adapter.goBack();
      harness
        ..startPage(flip.toString())
        ..finishPage(flip.toString());
      expect(listener.events.skip(4), ['started $flip', 'finished $flip']);
      expect(listener.errors, isEmpty);
    });

    test('us01/fr02/e08, us04/fr01/e07: Android order, goForward to an entry '
        'that answered 404 replays the error from the HTTP cache', () async {
      // Pin: P4.
      final first = Uri.parse('https://app.example.com/a');
      final flip = Uri.parse('https://app.example.com/flip');
      await adapter.load(StratumWebViewSource.url(first));
      harness
        ..startPage(first.toString())
        ..finishPage(first.toString());
      await adapter.load(StratumWebViewSource.url(flip));
      harness
        ..failHttp(statusCode: 404, requestUrl: flip)
        ..startPage(flip.toString())
        ..finishPage(flip.toString());
      await adapter.goBack();
      harness
        ..startPage(first.toString())
        ..finishPage(first.toString());
      await adapter.goForward();
      harness
        ..failHttp(statusCode: 404, requestUrl: flip)
        ..startPage(flip.toString())
        ..finishPage(flip.toString());
      expect(listener.events.skip(7), [
        'started $flip',
        'error http $flip',
        'finished $flip',
      ]);
      expect(listener.errors, hasLength(2));
    });

    test('us01/fr02/e08: Android order, a history move the page script '
        'starts reports start, error, finish', () async {
      // Pin: history.back() in the page; no adapter call precedes it.
      final flip = Uri.parse('https://app.example.com/flip');
      final other = Uri.parse('https://app.example.com/b');
      await adapter.load(StratumWebViewSource.url(flip));
      harness
        ..startPage(flip.toString())
        ..finishPage(flip.toString());
      await adapter.load(StratumWebViewSource.url(other));
      harness
        ..startPage(other.toString())
        ..finishPage(other.toString())
        ..failHttp(statusCode: 404, requestUrl: flip)
        ..startPage(flip.toString())
        ..finishPage(flip.toString());
      expect(listener.events.skip(4), [
        'started $flip',
        'error http $flip',
        'finished $flip',
      ]);
    });

    test('us01/fr02/e09: a sub-resource 404 on the URL a later page-script '
        'history move lands on reaches onError as that page error', () async {
      // Pin: D1's stated residual.
      final page = Uri.parse('https://app.example.com/x');
      final image = Uri.parse('https://app.example.com/y');
      await adapter.load(StratumWebViewSource.url(page));
      harness
        ..startPage(page.toString())
        ..failHttp(statusCode: 404, requestUrl: image)
        ..finishPage(page.toString())
        ..startPage(image.toString())
        ..finishPage(image.toString());
      expect(listener.events, [
        'started $page',
        'finished $page',
        'started $image',
        'error http $image',
        'finished $image',
      ]);
    });

    test('us01/fr02: goBack, goForward, reload, and an allowed main-frame '
        'navigation each discard every candidate', () async {
      final image = Uri.parse('https://app.example.com/y');
      Future<void> check(Future<void> Function() begin) async {
        harness.failHttp(statusCode: 404, requestUrl: image);
        await begin();
        harness
          ..startPage(image.toString())
          ..finishPage(image.toString());
      }

      await check(adapter.goBack);
      await check(adapter.goForward);
      await check(adapter.reload);
      await check(
        () => harness.requestNavigation(image.toString(), isMainFrame: true),
      );
      expect(listener.errors, isEmpty);
    });

    test('us01/fr02, us01/fr02/e02: Android order, an HTTP error before its '
        'page starts reaches onError once, after the start; a later favicon '
        '404 is dropped', () async {
      final page = Uri.parse('https://app.example.com/missing');
      await adapter.load(StratumWebViewSource.url(page));
      harness
        ..failHttp(statusCode: 404, requestUrl: page)
        ..startPage(page.toString())
        ..changeUrl(page.toString())
        ..finishPage(page.toString())
        ..failHttp(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/favicon.ico'),
        );
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 404',
          code: 404,
          url: page,
        ),
      ]);
      expect(listener.events, [
        'started $page',
        'error http $page',
        'finished $page',
      ]);
    });

    test('us01/fr02: Android order, a load with an empty path matches the '
        'error on its canonical URL', () async {
      final page = Uri.parse('https://app.example.com/');
      await adapter.load(
        StratumWebViewSource.url(Uri.parse('https://app.example.com')),
      );
      harness
        ..failHttp(statusCode: 404, requestUrl: page)
        ..startPage(page.toString())
        ..finishPage(page.toString());
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 404',
          code: 404,
          url: page,
        ),
      ]);
      expect(listener.events, [
        'started $page',
        'error http $page',
        'finished $page',
      ]);
    });

    test('us01/fr02: Android order, the late start of a replaced load does '
        'not take the error of the newer page', () async {
      final first = Uri.parse('https://app.example.com/first');
      final second = Uri.parse('https://app.example.com/second');
      await adapter.load(StratumWebViewSource.url(first));
      await adapter.load(StratumWebViewSource.url(second));
      harness
        ..startPage(first.toString())
        ..failHttp(statusCode: 404, requestUrl: second)
        ..startPage(second.toString())
        ..finishPage(second.toString());
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 404',
          code: 404,
          url: second,
        ),
      ]);
      expect(listener.events, [
        'started $first',
        'started $second',
        'error http $second',
        'finished $second',
      ]);
    });

    test('us01/fr02: a new load, an HTML load, or dispose discards every '
        'candidate, even when the replaced page starts late', () async {
      final page = Uri.parse('https://app.example.com/missing');
      await adapter.load(StratumWebViewSource.url(page));
      harness.failHttp(statusCode: 404, requestUrl: page);
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(page.toString())
        ..finishPage(page.toString());

      await adapter.load(StratumWebViewSource.url(page));
      harness.failHttp(statusCode: 404, requestUrl: page);
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      harness
        ..startPage(page.toString())
        ..finishPage(page.toString());

      await adapter.load(StratumWebViewSource.url(page));
      harness.failHttp(statusCode: 404, requestUrl: page);
      adapter.dispose();
      harness
        ..startPage(page.toString())
        ..finishPage(page.toString());

      expect(listener.errors, isEmpty);
    });

    test('us01/fr02/e08, us04/fr01/e07: Android order, an HTTP error before a '
        'reloaded page starts reaches onError once, after the start', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..finishPage(appPage.toString());
      await adapter.reload();
      harness
        ..failHttp(statusCode: 503, requestUrl: appPage)
        ..startPage(appPage.toString())
        ..finishPage(appPage.toString());
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 503',
          code: 503,
          url: appPage,
        ),
      ]);
      expect(listener.events, [
        'started $appPage',
        'finished $appPage',
        'started $appPage',
        'error http $appPage',
        'finished $appPage',
      ]);
    });

    test(
      'us01/fr02/e02: an HTTP error on a prevented navigation is dropped',
      () async {
        final target = Uri.parse('https://evil.example.net/');
        listener.decision = StratumNavigationDecision.prevent;
        await harness.requestNavigation(target.toString(), isMainFrame: true);
        harness.failHttp(statusCode: 404, requestUrl: target);
        expect(listener.errors, isEmpty);
      },
    );

    test('toggles JavaScript', () async {
      await adapter.setJavaScriptEnabled(false);
      expect(harness.javaScriptEnabledStates.last, isFalse);
    });

    test('parses the current URL', () async {
      harness.setCurrentUrl('https://app.example.com/now');
      expect(
        await adapter.currentUrl(),
        Uri.parse('https://app.example.com/now'),
      );
      harness.setCurrentUrl(null);
      expect(await adapter.currentUrl(), isNull);
    });

    test('dispose loads about:blank, for parity with web', () async {
      adapter.dispose();
      await pumpEventQueue();
      expect(harness.loadedUrls, [Uri.parse('about:blank')]);
    });
  });
}

/// The [StateError] a send throws when the page is not an allowed
/// destination (US-03 FR-02 E03).
final Matcher _unallowedPage = isA<StateError>().having(
  (error) => error.message,
  'message',
  'The current page is not an allowed message destination.',
);
