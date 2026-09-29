import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart'
    as wa;

/// [PlatformStratumWebView] for Windows and Linux, backed by
/// `webview_all_windows` and `webview_all_linux`.
///
/// Those packages register themselves as `wa.WebViewPlatform.instance`, so
/// this adapter talks to the platform interface directly.
final class WebviewAllAdapter implements PlatformStratumWebView {
  new(this._listener)
    : _session = NativeBridgeSession(
        allowedOrigins: () => _listener.allowedOrigins,
      ),
      _controller = wa.PlatformWebViewController(
        const wa.PlatformWebViewControllerCreationParams(),
      ),
      _delegate = wa.PlatformNavigationDelegate(
        const wa.PlatformNavigationDelegateCreationParams(),
      ) {
    _ready = _configure();
  }

  final PlatformStratumWebViewListener _listener;
  final NativeBridgeSession _session;
  final wa.PlatformWebViewController _controller;
  final wa.PlatformNavigationDelegate _delegate;
  late final Future<void> _ready;

  Future<void> _configure() async {
    await _delegate.setOnNavigationRequest(_handleNavigationRequest);
    await _delegate.setOnPageStarted(_handlePageStarted);
    await _delegate.setOnPageFinished(_handlePageFinished);
    await _delegate.setOnUrlChange(
      (change) => _session.didChangeUrl(change.url),
    );
    await _delegate.setOnWebResourceError(_handleResourceError);
    await _delegate.setOnHttpError(_handleHttpError);
    await _controller.setPlatformNavigationDelegate(_delegate);
    await _controller.setJavaScriptMode(wa.JavaScriptMode.unrestricted);
    await _controller.addJavaScriptChannel(
      wa.JavaScriptChannelParams(
        name: bridgeChannelName,
        onMessageReceived: (message) => _handleBridgeMessage(message.message),
      ),
    );
  }

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    await _ready;
    await _controller.setJavaScriptMode(
      enabled ? wa.JavaScriptMode.unrestricted : wa.JavaScriptMode.disabled,
    );
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    await _ready;
    switch (source) {
      case StratumWebViewUrlSource(:final url):
        _session.willLoadUrl();
        await _controller.loadRequest(wa.LoadRequestParams(uri: url));
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
  Widget buildView(BuildContext context) => wa.PlatformWebViewWidget(
    wa.PlatformWebViewWidgetCreationParams(controller: _controller),
  ).build(context);

  @override
  void dispose() {
    // The native view is released when its platform view leaves the tree.
    // The controller ignores events that arrive after dispose.
  }

  wa.NavigationDecision _handleNavigationRequest(wa.NavigationRequest request) {
    if (!request.isMainFrame) return wa.NavigationDecision.navigate;
    final url = Uri.tryParse(request.url);
    if (url == null) return wa.NavigationDecision.prevent;
    if (url.isScheme('about')) return wa.NavigationDecision.navigate;
    final decision = _listener.onNavigationRequest(url);
    return decision == StratumNavigationDecision.navigate
        ? wa.NavigationDecision.navigate
        : wa.NavigationDecision.prevent;
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

  void _handleResourceError(wa.WebResourceError error) {
    final mapped = _session.networkError(
      code: error.errorCode,
      description: error.description,
      isForMainFrame: error.isForMainFrame,
      url: error.url,
    );
    if (mapped != null) _listener.onError(mapped);
  }

  void _handleHttpError(wa.HttpResponseError error) {
    final mapped = _session.httpError(
      statusCode: error.response?.statusCode,
      requestUrl: error.request?.uri,
    );
    if (mapped != null) _listener.onError(mapped);
  }
}
