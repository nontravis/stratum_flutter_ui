import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

import '../../fakes/fake_webview_all_platform.dart';
import '../../fakes/recording_listener.dart';
import 'native_adapter_contract.dart';

void main() {
  runNativeAdapterContract('WebviewAllAdapter', _Harness.new);

  for (final (platform, reported) in [
    (TargetPlatform.windows, false),
    (TargetPlatform.linux, true),
  ]) {
    test(
      'us01/fr02/e04: a resource error with code 14 on ${platform.name} '
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
    final appPage = Uri.parse('https://app.example.com/home');
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

    test('us03/fr01/e07: a message is judged by the last main-frame page '
        'start at receipt, because the platform names no sender', () {
      harness
        ..sendBridgeMessage('before', senderUrl: appPage.toString())
        ..startPage(appPage.toString())
        ..sendBridgeMessage('after', senderUrl: 'https://evil.example.net/');
      expect(listener.messages, [
        StratumWebViewMessage(data: 'after', origin: appOrigin),
      ]);
    });

    test('us03/fr01/e06: a sub-frame message arrives stamped with the '
        'top-level origin', () {
      harness
        ..startPage(appPage.toString())
        ..sendBridgeMessage(
          'framed',
          senderUrl: 'https://ads.example.net/',
          isMainFrame: false,
        );
      expect(listener.messages, [
        StratumWebViewMessage(data: 'framed', origin: appOrigin),
      ]);
    });
  });
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
  }) => _controller.channels['StratumBridge']!(
    JavaScriptMessage(message: message),
  );

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
