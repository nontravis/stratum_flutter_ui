import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/native_sender_channel.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
// The internal pigeon-generated file, not the public barrel: its
// `PigeonOverrides` is the package's own seam for standing in for the
// native WebView, WebChromeClient, and WebSettings in a host-side test
// (see webview_flutter_android's own android_webview_controller_test.dart).
import 'package:webview_flutter_android/src/android_webkit.g.dart'
    as android_webview;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../fakes/fake_native_sender_channel.dart';
import '../../fakes/fake_webview_flutter_platform.dart';
import '../../fakes/native_bridge_envelope.dart';
import '../../fakes/recording_listener.dart';
import 'native_adapter_contract.dart';

void main() {
  runNativeAdapterContract('WebviewFlutterAdapter', _Harness.new);

  group('WebviewFlutterAdapter sender channel', () {
    final appOrigin = Uri.parse('https://app.example.com');
    final appPage = Uri.parse('https://app.example.com/home');
    late _Harness harness;
    late RecordingListener listener;
    late PlatformStratumWebView adapter;

    setUp(() async {
      harness = _Harness();
      listener = RecordingListener(allowedOrigins: {appOrigin});
      adapter = harness.createAdapter(listener);
      await pumpEventQueue();
    });

    test('Q6: attaches the sender channel before any load and registers no '
        'JavaScript channel', () async {
      expect(harness.sender.attached, hasLength(1));
      expect(harness.channelNames, isEmpty);
      adapter.dispose();
      await pumpEventQueue();
      expect(harness.sender.detached, harness.sender.attached);
    });

    test('us03/fr01/e10: a message that beats its page start arrives with '
        'its sender origin', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..sendBridgeMessage('ready', senderUrl: appPage.toString())
        ..startPage(appPage.toString());
      expect(listener.messages, [
        StratumWebViewMessage(data: 'ready', origin: appOrigin),
      ]);
    });

    test('us03/fr01/e10: the sender decides, never the last page start', () {
      harness
        ..startPage(appPage.toString())
        ..sendBridgeMessage('late', senderUrl: 'https://evil.example.net/')
        ..startPage('https://evil.example.net/')
        ..sendBridgeMessage('early', senderUrl: appPage.toString());
      expect(listener.messages, [
        StratumWebViewMessage(data: 'early', origin: appOrigin),
      ]);
    });

    test('us03/fr01/e06, us03/fr04/e09: a sub-frame message is dropped, an '
        'own-HTML envelope with the current nonce included', () async {
      harness
        ..startPage(appPage.toString())
        ..sendBridgeMessage(
          'framed',
          senderUrl: appPage.toString(),
          isMainFrame: false,
        );
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      harness.sendBridgeMessage(
        messageEnvelope(nonceIn(harness.loadedHtml.single), 'x'),
        senderUrl: 'about:blank',
        isMainFrame: false,
      );
      expect(listener.messages, isEmpty);
    });

    test('us03/fr01/e11, us03/fr02/e11: without WEB_MESSAGE_LISTENER or '
        'JS_INJECTION_IN_FRAME_AND_WORLD no message arrives and every send '
        'throws naming the limit', () async {
      final limited = _Harness()..sender.supported = false;
      final limitedListener = RecordingListener(allowedOrigins: {appOrigin});
      final limitedAdapter = limited.createAdapter(limitedListener);
      await limitedAdapter.load(StratumWebViewSource.url(appPage));
      limited
        ..startPage(appPage.toString())
        ..sendBridgeMessage('hello', senderUrl: appPage.toString());
      await expectLater(
        limitedAdapter.postMessage('ping'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The bridge is disabled because the WebView lacks '
                'WEB_MESSAGE_LISTENER or JS_INJECTION_IN_FRAME_AND_WORLD '
                'support.',
          ),
        ),
      );
      expect(limitedListener.messages, isEmpty);
      expect(limited.scripts, isEmpty);
    });
  });

  group('WebviewFlutterAdapter Android reply proxy', () {
    const proxy = BridgeReplyProxy(3);
    final appOrigin = Uri.parse('https://app.example.com');
    final unallowedPage = isA<StateError>().having(
      (error) => error.message,
      'message',
      'The current page is not an allowed message destination.',
    );
    late _Harness harness;
    late RecordingListener listener;
    late PlatformStratumWebView adapter;
    late String html;

    /// Loads own HTML whose document proves the nonce with a `hello` that
    /// comes with [proxy], and makes the page shown refuse the allowlist.
    Future<void> proveOwnHtml(
      _Harness harness,
      PlatformStratumWebView adapter,
    ) async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      html = harness.loadedHtml.single;
      harness
        ..scriptResult = false
        ..sender.send(
          envelope(nonceIn(html), 'hello', documentA),
          senderUrl: 'about:blank',
          replyProxy: proxy,
        );
    }

    String tokenOnly(String data) => buildMessageDispatchScript(
      data,
      token: tokenIn(html),
      allowedOrigins: const <Uri>[],
    );

    setUp(() async {
      harness = _Harness();
      listener = RecordingListener(allowedOrigins: {appOrigin});
      adapter = harness.createAdapter(listener);
      await proveOwnHtml(harness, adapter);
    });

    test('us03/fr02/e13: the page shown gets the allowlist-only script, then '
        "the token check runs through the proving hello's reply proxy, and "
        'its true delivers', () async {
      await adapter.postMessage('ping');
      expect(harness.scripts, [
        buildMessageDispatchScript(
          'ping',
          token: null,
          allowedOrigins: {appOrigin},
        ),
      ]);
      expect(harness.sender.proxyRuns, [
        (replyProxy: proxy, script: tokenOnly('ping')),
      ]);
    });

    test('us03/fr02/e13: false, FRAME_DESTROYED, or another error from the '
        'reply proxy throws the StateError of an unallowed page', () async {
      for (final answer in <Future<bool> Function()>[
        () async => false,
        () => Future.error(PlatformException(code: 'frame-destroyed')),
        () => Future.error(PlatformException(code: 'script-failed')),
        () => Future.error(PlatformException(code: 'reply-proxy-gone')),
      ]) {
        harness.sender.proxyAnswer = answer;
        await expectLater(adapter.postMessage('ping'), throwsA(unallowedPage));
      }
      expect(harness.sender.proxyRuns, hasLength(4));
    });

    test('us03/fr02/e13: no answer from the reply proxy within 5 seconds '
        'throws the StateError of an unallowed page', () {
      fakeAsync((async) {
        // Built inside the fake zone, so every await of the adapter runs on
        // fake time.
        final zonedHarness = _Harness();
        final zonedAdapter = zonedHarness.createAdapter(listener);
        unawaited(proveOwnHtml(zonedHarness, zonedAdapter));
        async.flushMicrotasks();
        zonedHarness.sender.proxyAnswer = () => Completer<bool>().future;
        Object? failure;
        unawaited(
          zonedAdapter
              .postMessage('ping')
              .then((_) {}, onError: (Object error) => failure = error),
        );
        async.elapse(const Duration(milliseconds: 4999));
        expect(zonedHarness.sender.proxyRuns, hasLength(1));
        expect(failure, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(failure, unallowedPage);
      });
    });

    test('us03/fr02/e13, us03/fr02/e12: a first script that fails ends the '
        'send with no run through the reply proxy', () async {
      harness.scriptAnswer = () =>
          Future<Object>.error(PlatformException(code: 'evaluateJavaScript'));
      await expectLater(adapter.postMessage('ping'), throwsA(unallowedPage));
      expect(harness.sender.proxyRuns, isEmpty);
    });

    test('us03/fr02/e13, us03/fr02/e12: a first script with no answer within '
        '5 seconds ends the send with no run through the reply proxy', () {
      fakeAsync((async) {
        final zonedHarness = _Harness();
        final zonedAdapter = zonedHarness.createAdapter(listener);
        unawaited(proveOwnHtml(zonedHarness, zonedAdapter));
        async.flushMicrotasks();
        zonedHarness.scriptAnswer = () => Completer<Object>().future;
        Object? failure;
        unawaited(
          zonedAdapter
              .postMessage('ping')
              .then((_) {}, onError: (Object error) => failure = error),
        );
        async.elapse(const Duration(seconds: 6));
        expect(failure, unallowedPage);
        expect(zonedHarness.sender.proxyRuns, isEmpty);
      });
    });

    test('us03/fr02/e10, us03/fr02/e13: an allowed page shown answers true '
        'and gets the message with no run through the reply proxy', () async {
      harness.scriptResult = true;
      await adapter.postMessage('ping');
      expect(harness.sender.proxyRuns, isEmpty);
    });

    test("us03/fr04/e10, us03/fr02/e13: after the proving document's bye, a "
        'refused send runs nothing through the reply proxy', () async {
      harness.sender.send(
        envelope(nonceIn(html), 'bye', documentA),
        senderUrl: 'about:blank',
        replyProxy: proxy,
      );
      await expectLater(adapter.postMessage('ping'), throwsA(unallowedPage));
      expect(harness.sender.proxyRuns, isEmpty);
    });

    test('us03/fr02/e13: a bye that arrives while the first script runs '
        'stops the run through the reply proxy', () async {
      harness.scriptAnswer = () async {
        harness.sender.send(
          envelope(nonceIn(html), 'bye', documentA),
          senderUrl: 'about:blank',
          replyProxy: proxy,
        );
        return false;
      };
      await expectLater(adapter.postMessage('ping'), throwsA(unallowedPage));
      expect(harness.sender.proxyRuns, isEmpty);
    });

    test('us03/fr02/e17, us03/fr02/e16: a named send the page shown '
        'refuses runs nothing through the reply proxy and throws', () async {
      await expectLater(
        adapter.postMessage('ping', targetOrigin: appOrigin),
        throwsA(unallowedPage),
      );
      expect(harness.scripts, [
        buildMessageDispatchScript(
          'ping',
          token: null,
          allowedOrigins: {appOrigin},
        ),
      ]);
      expect(harness.sender.proxyRuns, isEmpty);
    });

    test('B1 us03/fr02/e13: a later loadHtml that proves while the first '
        "script is pending does not get the earlier load's send through "
        'the reply proxy', () async {
      const laterProxy = BridgeReplyProxy(9);
      harness.scriptAnswer = () async {
        await adapter.load(const StratumWebViewSource.html('<p>Later</p>'));
        harness.sender.send(
          envelope(nonceIn(harness.loadedHtml.last), 'hello', documentB),
          senderUrl: 'about:blank',
          replyProxy: laterProxy,
        );
        return false;
      };
      await expectLater(adapter.postMessage('ping'), throwsA(unallowedPage));
      expect(harness.sender.proxyRuns, isEmpty);
    });
  });

  group('WebviewFlutterAdapter B2 Android controller binding', () {
    final appOrigin = Uri.parse('https://app.example.com');

    test('B2: wired to a real Android controller, a hello with no reply proxy '
        'proves nothing, so postMessage throws unproven instead of trusting '
        'the page shown with the token', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Stands in for the native WebView and WebChromeClient the real
      // AndroidWebViewController constructor builds, through the
      // package's own testing seam, so building it sends nothing over a
      // platform channel.
      android_webview.PigeonOverrides.webView_new = ({onScrollChanged}) =>
          _FakeAndroidWebView();
      android_webview.PigeonOverrides.webChromeClient_new = ({
        onProgressChanged,
        required onShowFileChooser,
        onPermissionRequest,
        onShowCustomView,
        onHideCustomView,
        onGeolocationPermissionsShowPrompt,
        onGeolocationPermissionsHidePrompt,
        onConsoleMessage,
        onJsAlert,
        required onJsConfirm,
        onJsPrompt,
      }) => _FakeWebChromeClient();
      addTearDown(android_webview.PigeonOverrides.pigeon_reset);

      final platform = _RecordingAndroidPlatform();
      WebViewPlatform.instance = platform;
      final sender = FakeNativeSenderChannel();
      debugNativeSenderChannel = sender;
      addTearDown(() => debugNativeSenderChannel = null);
      final listener = RecordingListener(allowedOrigins: {appOrigin});
      final adapter = WebviewFlutterAdapter(listener);
      await pumpEventQueue();

      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      final html = platform.controller.loadedHtml.single;
      sender.send(
        envelope(nonceIn(html), 'hello', documentA),
        senderUrl: 'about:blank',
      );
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
    });
  });

  for (final (platform, reported) in [
    (TargetPlatform.iOS, false),
    (TargetPlatform.macOS, false),
    (TargetPlatform.android, true),
  ]) {
    test(
      'us01/fr02/e04: a -999 resource error on ${platform.name} is '
      '${reported ? 'reported' : 'dropped as a cancelled navigation'}',
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
          code: -999,
          description: 'cancelled',
          isForMainFrame: true,
          url: 'https://app.example.com/',
        );
        expect(listener.errors, hasLength(reported ? 1 : 0));
      },
    );
  }
}

/// Stands in for [_FakeAndroidWebView.settings], so every setter the real
/// `AndroidWebViewController` constructor calls on it reaches no platform
/// channel.
final class _FakeAndroidWebSettings extends android_webview.WebSettings {
  new() : super.pigeon_detached();

  @override
  Future<void> setDomStorageEnabled(bool flag) async {}

  @override
  Future<void> setJavaScriptCanOpenWindowsAutomatically(bool flag) async {}

  @override
  Future<void> setSupportMultipleWindows(bool support) async {}

  @override
  Future<void> setLoadWithOverviewMode(bool overview) async {}

  @override
  Future<void> setUseWideViewPort(bool use) async {}

  @override
  Future<void> setDisplayZoomControls(bool enabled) async {}

  @override
  Future<void> setBuiltInZoomControls(bool enabled) async {}
}

/// Stands in for the native WebView [AndroidWebViewController]'s own
/// constructor builds (`android_webview.WebView(...)`), so that eager build,
/// not any call [_RecordingAndroidWebViewController] overrides, reaches no
/// platform channel.
final class _FakeAndroidWebView extends android_webview.WebView {
  new() : super.pigeon_detached();

  final android_webview.WebSettings _settings = _FakeAndroidWebSettings();

  @override
  android_webview.WebSettings get settings => _settings;

  @override
  Future<void> setWebChromeClient(
    android_webview.WebChromeClient? client,
  ) async {}
}

/// Stands in for the native WebChromeClient [AndroidWebViewController]'s own
/// constructor builds; never exercised, because [_FakeAndroidWebView]
/// ignores the client it is handed.
final class _FakeWebChromeClient extends android_webview.WebChromeClient {
  new()
    : super.pigeon_detached(
        onShowFileChooser: (_, _, _) async => <String>[],
        onJsConfirm: (_, _, _, _) async => false,
      );
}

/// Stands in for `WebStorage.instance`, so building the creation params
/// reaches no platform channel either.
final class _FakeWebStorage extends android_webview.WebStorage {
  new() : super.pigeon_detached();
}

/// A real [AndroidWebViewController], so `WebviewFlutterAdapter`'s B2 check
/// (`_controller.platform is AndroidWebViewController`) sees the type the
/// production code tests for, not a fake that stands in for it; every
/// native-facing call it makes is overridden to record instead of reaching a
/// platform channel.
final class _RecordingAndroidWebViewController
    extends AndroidWebViewController {
  new(super.params);

  final List<String> loadedHtml = [];

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    loadedHtml.add(html);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => true;
}

/// Creates the one [_RecordingAndroidWebViewController] `webview_flutter`
/// builds, and a generic fake navigation delegate, so the controller
/// `WebviewFlutterAdapter` wires up is a genuine Android type with no
/// platform channel calls underneath.
final class _RecordingAndroidPlatform extends WebViewPlatform {
  late final _RecordingAndroidWebViewController controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = _RecordingAndroidWebViewController(
      AndroidWebViewControllerCreationParams(
        androidWebStorage: _FakeWebStorage(),
      ),
    );
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeWebViewFlutterNavigationDelegate(params);
}

final class _Harness implements NativeAdapterHarness {
  new() {
    WebViewPlatform.instance = _platform;
    debugNativeSenderChannel = sender;
    addTearDown(() => debugNativeSenderChannel = null);
  }

  final FakeWebViewFlutterPlatform _platform = FakeWebViewFlutterPlatform();
  final FakeNativeSenderChannel sender = FakeNativeSenderChannel();

  FakeWebViewFlutterController get _controller => _platform.controllers.single;

  FakeWebViewFlutterNavigationDelegate get _delegate =>
      _platform.delegates.single;

  @override
  PlatformStratumWebView createAdapter(
    PlatformStratumWebViewListener listener,
  ) => WebviewFlutterAdapter(listener);

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
  }) => sender.send(message, senderUrl: senderUrl, isMainFrame: isMainFrame);

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
