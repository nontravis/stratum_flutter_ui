import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

import '../../fakes/fake_webview_all_platform.dart';
import '../../fakes/native_bridge_envelope.dart';
import '../../fakes/recording_listener.dart';
import 'native_adapter_contract.dart';

void main() {
  runNativeAdapterContract('WebviewAllAdapter', _Harness.new);

  for (final (platform, reported) in [
    (TargetPlatform.windows, false),
    (TargetPlatform.linux, true),
  ]) {
    test(
      'co01_02/us01/fr02/e04: a resource error with code 14 on ${platform.name} '
      'is ${reported ? 'reported' : 'dropped as a cancelled navigation'}',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final harness = _Harness();
        final listener = RecordingListener(
          allowedOrigins: {Uri.parse('https://app.example.com')},
        );
        harness.createAdapter(listener);
        await pumpEventQueue();
        harness.failResource(
          code: 14,
          description: 'The operation was canceled.',
          isForMainFrame: true,
          url: 'https://app.example.com/',
        );
        expect(listener.errors, hasLength(reported ? 1 : 0));
      },
    );
  }

  group('WebviewAllAdapter JavaScript channel', () {
    final appOrigin = Uri.parse('https://app.example.com');
    late _Harness harness;
    late RecordingListener listener;

    setUp(() async {
      harness = _Harness();
      listener = RecordingListener(allowedOrigins: {appOrigin});
      harness.createAdapter(listener);
      await pumpEventQueue();
    });

    test('Q7d: carries the bridge on the StratumBridge JavaScript '
        'channel', () {
      expect(harness.channelNames, {'StratumBridge'});
    });
  });

  for (final (platform, story, engine) in [
    (TargetPlatform.windows, 'us05', 'Windows'),
    (TargetPlatform.linux, 'us06', 'Linux'),
  ]) {
    group('WebviewAllAdapter sender on $engine', () {
      final appOrigin = Uri.parse('https://app.example.com');
      final appPage = Uri.parse('https://app.example.com/home');
      final otherPage = Uri.parse('https://evil.example.net/');
      late _Harness harness;
      late RecordingListener listener;
      late PlatformStratumWebView adapter;

      setUp(() async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        harness = _Harness();
        listener = RecordingListener(allowedOrigins: {appOrigin});
        adapter = harness.createAdapter(listener);
        await pumpEventQueue();
      });

      test('co01_02/$story/fr01/e02: an allowed sender is delivered with its '
          'origin while the view tracks a page of another origin', () {
        harness
          ..startPage(otherPage.toString())
          ..sendBridgeMessage('moving', senderUrl: appPage.toString());
        expect(listener.messages, [
          StratumWebViewMessage(data: 'moving', origin: appOrigin),
        ]);
      });

      test('co01_02/$story/fr01/e03: a sender outside the allowed origins '
          'drops while the view tracks an allowed page', () {
        harness
          ..startPage(appPage.toString())
          ..sendBridgeMessage('late', senderUrl: otherPage.toString());
        expect(listener.messages, isEmpty);
      });

      test('co01_02/$story/fr01/e04: a message without a main-frame flag '
          'drops, though the tracked page and the origin are allowed', () {
        harness
          ..startPage(appPage.toString())
          ..sendRaw(
            JavaScriptMessage(
              message: 'unflagged',
              sourceUrl: appPage.toString(),
              sourceOrigin: appOrigin.toString(),
            ),
          )
          ..sendRaw(const JavaScriptMessage(message: 'bare'));
        expect(listener.messages, isEmpty);
      });

      test('co01_02/$story/fr01/e04: a tagged message without a main-frame '
          'flag drops, and the document stays unproven', () async {
        await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
        final nonce = nonceIn(harness.loadedHtml.single);
        harness.sendRaw(
          JavaScriptMessage(message: envelope(nonce, 'hello', documentA)),
        );
        expect(listener.messages, isEmpty);
        await expectLater(
          adapter.replyToDocument(
            const NativeHtmlDocumentSender(load: 1, documentId: documentA),
            'late',
          ),
          throwsA(isA<StateError>()),
        );
      });

      // Windows raises its channel event for the top-level document only,
      // so only Linux can name an iframe (US-05 FR-01 E05, US-06 FR-01 E05).
      test(
        '${story == 'us06' ? 'co01_02/us06/fr01/e05' : 'co01_02/us05/fr01'}: '
        'a message flagged as an iframe drops, whatever the '
        "iframe's origin",
        () {
          harness
            ..startPage(appPage.toString())
            ..sendBridgeMessage(
              'framed',
              senderUrl: appPage.toString(),
              isMainFrame: false,
            )
            ..sendBridgeMessage(
              'foreign',
              senderUrl: otherPage.toString(),
              isMainFrame: false,
            );
          expect(listener.messages, isEmpty);
        },
      );

      test('co01_02/$story/fr01/e06: a reply targets the sender origin and '
          'throws when the page shown has another origin', () async {
        harness.sendBridgeMessage('ping', senderUrl: appPage.toString());
        final sender = listener.senders.single as PlatformUrlPageSender;
        expect(sender.origin, appOrigin);
        harness.scriptResult = true;
        await adapter.postMessage('pong', targetOrigin: sender.origin);
        expect(
          harness.scripts.last,
          buildMessageDispatchScript(
            'pong',
            token: null,
            allowedOrigins: [appOrigin],
          ),
        );
        harness.scriptResult = false;
        await expectLater(
          adapter.postMessage('pong', targetOrigin: sender.origin),
          throwsA(isA<StateError>()),
        );
      });

      // The page shown is compared in page JavaScript, which the fake
      // platform does not run: this pins the Dart half, a script bound to
      // the sender's origin whatever page the view moved to since.
      test('co01_02/$story/fr01/e06: a reply after the view moved to another '
          'page is still bound to the sender origin, and an allowlist that '
          'dropped it first throws', () async {
        harness.sendBridgeMessage('ping', senderUrl: appPage.toString());
        final sender = listener.senders.single as PlatformUrlPageSender;
        harness
          ..startPage(otherPage.toString())
          ..scriptResult = true;
        await adapter.postMessage('pong', targetOrigin: sender.origin);
        expect(
          harness.scripts.last,
          buildMessageDispatchScript(
            'pong',
            token: null,
            allowedOrigins: [appOrigin],
          ),
        );
        final scriptsSent = harness.scripts.length;
        listener.allowedOrigins = {otherPage};
        await expectLater(
          adapter.postMessage('pong', targetOrigin: sender.origin),
          throwsA(isA<StateError>()),
        );
        expect(harness.scripts, hasLength(scriptsSent));
      });

      if (platform == TargetPlatform.linux) {
        test('co01_02/us06/fr01/e07: the sender origin text decides over the '
            'sender address, and "null" is an opaque origin that drops', () {
          harness
            ..sendRaw(
              JavaScriptMessage(
                message: 'opaque',
                sourceUrl: appPage.toString(),
                sourceOrigin: 'null',
                isMainFrame: true,
              ),
            )
            ..sendRaw(
              JavaScriptMessage(
                message: 'foreign origin',
                sourceUrl: appPage.toString(),
                sourceOrigin: otherPage.toString(),
                isMainFrame: true,
              ),
            )
            ..sendRaw(
              JavaScriptMessage(
                message: 'named origin',
                sourceUrl: otherPage.toString(),
                sourceOrigin: appOrigin.toString(),
                isMainFrame: true,
              ),
            )
            ..sendRaw(
              JavaScriptMessage(
                message: 'blank address',
                sourceUrl: 'about:blank',
                sourceOrigin: appOrigin.toString(),
                isMainFrame: true,
              ),
            );
          expect(listener.messages, [
            StratumWebViewMessage(data: 'named origin', origin: appOrigin),
            StratumWebViewMessage(data: 'blank address', origin: appOrigin),
          ]);
        });
      } else {
        test('co01_02/us05/fr01/e07: a sandboxed document at an allowed '
            "address is delivered with that address's origin", () {
          harness.sendRaw(
            JavaScriptMessage(
              message: 'sandboxed',
              sourceUrl: appPage.toString(),
              isMainFrame: true,
            ),
          );
          expect(listener.messages, [
            StratumWebViewMessage(data: 'sandboxed', origin: appOrigin),
          ]);
        });
      }

      test(
        'co01_02/$story/fr01: sourceOrigin text that is empty, unparsable, or '
        'host-less is an opaque origin that drops',
        () {
          for (final text in ['', 'not a url', 'about:blank', 'NULL']) {
            harness.sendRaw(
              JavaScriptMessage(
                message: 'opaque $text',
                sourceUrl: appPage.toString(),
                sourceOrigin: text,
                isMainFrame: true,
              ),
            );
          }
          expect(listener.messages, isEmpty);
        },
      );

      test('co01_02/$story/fr01: a sender address with no host never names an '
          'origin, whatever the allowed page the view tracks', () {
        harness.startPage(appPage.toString());
        for (final url in [
          null,
          'about:blank',
          'data:text/html,x',
          'blob:https://app.example.com/id',
          'file:///x',
          '',
        ]) {
          harness.sendRaw(
            JavaScriptMessage(
              message: 'untagged $url',
              sourceUrl: url,
              isMainFrame: true,
            ),
          );
        }
        expect(listener.messages, isEmpty);
      });

      test('co01_02/$story/fr01: a sender address is normalized to its origin, '
          'and a host spelled another way does not match', () {
        harness
          ..sendBridgeMessage(
            'cased',
            senderUrl: 'HTTPS://APP.Example.com:443/p/',
          )
          ..sendBridgeMessage('dotted', senderUrl: 'https://app.example.com./p')
          ..sendBridgeMessage(
            'unicode',
            senderUrl: 'https://b\u00fccher.example/p',
          );
        expect(listener.messages, [
          StratumWebViewMessage(data: 'cased', origin: appOrigin),
        ]);
      });

      // WebKitGTK erases the plugin's sender listener on `document.open()`,
      // so the page's `bye` reaches the public handler with no metadata.
      if (platform == TargetPlatform.linux) {
        test('co01_02/us03/fr04/e14, co01_02/us06/fr01/e04: a bye with no '
            'main-frame flag revokes the proof, so the next send is refused '
            'and delivers nothing', () async {
          await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
          final html = harness.loadedHtml.single;
          final nonce = nonceIn(html);
          harness
            ..sendRaw(
              JavaScriptMessage(
                message: envelope(nonce, 'hello', documentA),
                isMainFrame: true,
              ),
            )
            ..sendRaw(
              JavaScriptMessage(message: envelope(nonce, 'bye', documentA)),
            );
          expect(listener.messages, isEmpty);
          harness.scriptResult = false;
          await expectLater(
            adapter.postMessage('ping'),
            throwsA(isA<StateError>()),
          );
          expect(harness.scripts.last, isNot(contains(tokenIn(html))));
        });
      }

      test('co01_02/$story/fr01: a tagged message that arrives after dispose '
          'is not delivered', () async {
        await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
        final nonce = nonceIn(harness.loadedHtml.single);
        harness.sendRaw(
          JavaScriptMessage(
            message: envelope(nonce, 'hello', documentA),
            isMainFrame: true,
          ),
        );
        adapter.dispose();
        harness.sendRaw(
          JavaScriptMessage(
            message: messageEnvelope(nonce, 'late'),
            isMainFrame: true,
          ),
        );
        expect(listener.messages, isEmpty);
      });

      test('co01_02/$story/fr01: a main-frame message with no sender address '
          'passes as the own-HTML bridge by its nonce', () async {
        await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
        final nonce = nonceIn(harness.loadedHtml.single);
        harness
          ..sendRaw(
            JavaScriptMessage(
              message: envelope(nonce, 'hello', documentA),
              isMainFrame: true,
            ),
          )
          ..sendRaw(
            JavaScriptMessage(
              message: messageEnvelope(nonce, 'm'),
              isMainFrame: true,
            ),
          );
        expect(listener.messages, hasLength(1));
        expect(listener.messages.single.data, 'm');
        expect(listener.senders.single, isA<PlatformHtmlDocumentSender>());
      });
    });
  }
}

final class _Harness implements NativeAdapterHarness {
  new() {
    WebViewPlatform.instance = _platform;
  }

  final FakeWebviewAllPlatform _platform = FakeWebviewAllPlatform();

  FakeWebviewAllController get _controller => _platform.controllers.single;

  FakeWebviewAllNavigationDelegate get _delegate => _platform.delegates.single;

  @override
  PlatformStratumWebView createAdapter(
    PlatformStratumWebViewListener listener,
  ) => WebviewAllAdapter(listener);

  @override
  List<Uri> get loadedUrls => _controller.loadedUrls;

  @override
  List<String> get loadedHtml => _controller.loadedHtml;

  @override
  List<String> get scripts => _controller.scripts;

  @override
  List<bool> get javaScriptEnabledStates => [
    for (final mode in _controller.javaScriptModes)
      mode == JavaScriptMode.unrestricted,
  ];

  @override
  Set<String> get channelNames => _controller.channels.keys.toSet();

  @override
  int get reloadCount => _controller.reloadCount;

  @override
  int get goBackCount => _controller.goBackCount;

  @override
  int get goForwardCount => _controller.goForwardCount;

  @override
  set scriptResult(Object value) => _controller.scriptResult = value;

  @override
  set scriptAnswer(Future<Object> Function() answer) =>
      _controller.scriptAnswer = answer;

  @override
  void setCurrentUrl(String? url) => _controller.currentUrlValue = url;

  @override
  void startPage(String url) => _delegate.pageStartedCallback!(url);

  @override
  void finishPage(String url) => _delegate.pageFinishedCallback!(url);

  @override
  void changeUrl(String? url) =>
      _delegate.urlChangeCallback!(UrlChange(url: url));

  @override
  void sendBridgeMessage(
    String message, {
    required String senderUrl,
    bool isMainFrame = true,
  }) => sendRaw(
    JavaScriptMessage(
      message: message,
      sourceUrl: senderUrl,
      isMainFrame: isMainFrame,
    ),
  );

  /// Delivers [message] with exactly the sender fields it carries.
  void sendRaw(JavaScriptMessage message) =>
      _controller.channels['StratumBridge']!(message);

  @override
  Future<bool> requestNavigation(
    String url, {
    required bool isMainFrame,
  }) async {
    final decision = await _delegate.navigationRequestCallback!(
      NavigationRequest(url: url, isMainFrame: isMainFrame),
    );
    return decision == NavigationDecision.navigate;
  }

  @override
  void failResource({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  }) => _delegate.webResourceErrorCallback!(
    WebResourceError(
      errorCode: code,
      description: description,
      isForMainFrame: isForMainFrame,
      url: url,
    ),
  );

  @override
  void failHttp({required int statusCode, required Uri requestUrl}) =>
      _delegate.httpErrorCallback!(
        HttpResponseError(
          request: WebResourceRequest(uri: requestUrl),
          response: WebResourceResponse(
            uri: requestUrl,
            statusCode: statusCode,
          ),
        ),
      );
}
