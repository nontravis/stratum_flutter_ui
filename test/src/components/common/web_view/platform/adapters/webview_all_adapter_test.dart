import 'package:stratum_ui/src/components/common/web_view/platform/adapters/webview_all_adapter.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

import '../../fakes/fake_webview_all_platform.dart';
import 'native_adapter_contract.dart';

void main() {
  runNativeAdapterContract('WebviewAllAdapter', _Harness.new);
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
  void setCurrentUrl(String? url) => _controller.currentUrlValue = url;

  @override
  void startPage(String url) => _delegate.pageStartedCallback!(url);

  @override
  void finishPage(String url) => _delegate.pageFinishedCallback!(url);

  @override
  void changeUrl(String? url) =>
      _delegate.urlChangeCallback!(UrlChange(url: url));

  @override
  void sendBridgeMessage(String message) =>
      _controller.channels['StratumBridge']!(
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
