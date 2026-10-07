import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/native_sender_channel.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_flutter_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
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
        envelope(nonceIn(harness.loadedHtml.single), 'message', 'x'),
        senderUrl: 'about:blank',
        isMainFrame: false,
      );
      expect(listener.messages, isEmpty);
    });

    test('us03/fr01/e11, us03/fr02/e11: without WEB_MESSAGE_LISTENER no '
        'message arrives and every send throws naming the limit', () async {
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
            'The bridge is disabled because the WebView has no '
                'WEB_MESSAGE_LISTENER support.',
          ),
        ),
      );
      expect(limitedListener.messages, isEmpty);
      expect(limited.scripts, isEmpty);
    });
  });

  test('drops the iOS/macOS cancelled-navigation error (-999)', () async {
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

    expect(listener.errors, isEmpty);
  });
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
