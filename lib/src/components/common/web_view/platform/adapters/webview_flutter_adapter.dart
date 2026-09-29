import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;

/// [PlatformStratumWebView] for Android, iOS, and macOS, backed by
/// `webview_flutter`.
final class WebviewFlutterAdapter implements PlatformStratumWebView {
  new(this._listener)
    : _session = NativeBridgeSession(
        allowedOrigins: () => _listener.allowedOrigins,
      ) {
    _ready = _configure();
  }

  final PlatformStratumWebViewListener _listener;
  final NativeBridgeSession _session;
  final wf.WebViewController _controller = wf.WebViewController();
  late final Future<void> _ready;

  Future<void> _configure() async {
    await _controller.setJavaScriptMode(wf.JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      wf.NavigationDelegate(
        onNavigationRequest: _handleNavigationRequest,
        onPageStarted: _handlePageStarted,
        onPageFinished: _handlePageFinished,
        onUrlChange: (change) => _session.didChangeUrl(change.url),
        onWebResourceError: _handleResourceError,
        onHttpError: _handleHttpError,
      ),
    );
    await _controller.addJavaScriptChannel(
      bridgeChannelName,
      onMessageReceived: (message) => _handleBridgeMessage(message.message),
    );
  }

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    await _ready;
    await _controller.setJavaScriptMode(
      enabled ? wf.JavaScriptMode.unrestricted : wf.JavaScriptMode.disabled,
    );
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    await _ready;
    switch (source) {
      case StratumWebViewUrlSource(:final url):
        _session.willLoadUrl();
        await _controller.loadRequest(url);
      case StratumWebViewHtmlSource(:final html):
        _session.willLoadHtml();
        await _controller.loadHtmlString(html);
    }
  }

  @override
  Future<void> reload() async {
    await _ready;
    _session.willReload();
    await _controller.reload();
  }

  @override
  Future<void> goBack() async {
    await _ready;
    await _controller.goBack();
  }

  @override
  Future<void> goForward() async {
    await _ready;
    await _controller.goForward();
  }

  @override
  Future<bool> canGoBack() async {
    await _ready;
    return _controller.canGoBack();
  }

  @override
  Future<bool> canGoForward() async {
    await _ready;
    return _controller.canGoForward();
  }

  @override
  Future<Uri?> currentUrl() async {
    await _ready;
    final url = await _controller.currentUrl();
    return url == null ? null : Uri.tryParse(url);
  }

  @override
  Future<void> postMessage(String data) async {
    await _ready;
    await _controller.runJavaScript(_session.scriptForMessage(data));
  }

  @override
  Widget buildView(BuildContext context) =>
      wf.WebViewWidget(controller: _controller);

  @override
  void dispose() {
    // webview_flutter releases the native view when WebViewWidget leaves the
    // tree. The controller ignores events that arrive after dispose.
  }

  wf.NavigationDecision _handleNavigationRequest(wf.NavigationRequest request) {
    if (!request.isMainFrame) return wf.NavigationDecision.navigate;
    final url = Uri.tryParse(request.url);
    if (url == null) return wf.NavigationDecision.prevent;
    if (url.isScheme('about')) return wf.NavigationDecision.navigate;
    final decision = _listener.onNavigationRequest(url);
    return decision == StratumNavigationDecision.navigate
        ? wf.NavigationDecision.navigate
        : wf.NavigationDecision.prevent;
  }

  void _handlePageStarted(String url) {
    _session.didStartPage(url);
    _listener.onPageStarted(Uri.tryParse(url));
  }

  void _handlePageFinished(String url) {
    _listener.onPageFinished(Uri.tryParse(url));
  }

  void _handleBridgeMessage(String data) {
    final message = _session.acceptMessage(data);
    if (message != null) _listener.onMessage(message);
  }

  void _handleResourceError(wf.WebResourceError error) {
    final mapped = _session.networkError(
      code: error.errorCode,
      description: error.description,
      isForMainFrame: error.isForMainFrame,
      url: error.url,
    );
    if (mapped != null) _listener.onError(mapped);
  }

  void _handleHttpError(wf.HttpResponseError error) {
    final mapped = _session.httpError(
      statusCode: error.response?.statusCode,
      requestUrl: error.request?.uri,
    );
    if (mapped != null) _listener.onError(mapped);
  }
}
