import 'dart:async';

import 'package:flutter/foundation.dart';
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
        platform: defaultTargetPlatform,
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
        await _controller.loadHtmlString(_session.willLoadHtml(html));
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
    _session.willNavigate();
    await _controller.goBack();
  }

  @override
  Future<void> goForward() async {
    await _ready;
    _session.willNavigate();
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
  Future<void> postMessage(String data, {Uri? targetOrigin}) async {
    await _ready;
    final script = _session.scriptForMessage(data, targetOrigin: targetOrigin);
    _session.confirmDelivery(
      await dispatchScriptAnswer(
        _controller.runJavaScriptReturningResult(script),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context) => wa.PlatformWebViewWidget(
    wa.PlatformWebViewWidgetCreationParams(controller: _controller),
  ).build(context);

  @override
  void dispose() {
    // The native view is released when its platform view leaves the tree.
    // The controller ignores events that arrive after dispose. Load
    // about:blank first, so audio, video, and timers stop immediately
    // instead of running until the native view is collected (parity with
    // the web implementation, which navigates the iframe away on dispose).
    _session.willDispose();
    unawaited(_disposeLoad());
  }

  Future<void> _disposeLoad() async {
    await _ready;
    await _controller.loadRequest(
      wa.LoadRequestParams(uri: Uri.parse('about:blank')),
    );
  }

  wa.NavigationDecision _handleNavigationRequest(wa.NavigationRequest request) {
    if (!request.isMainFrame) return wa.NavigationDecision.navigate;
    final url = Uri.tryParse(request.url);
    if (url == null) return wa.NavigationDecision.prevent;
    if (url.isScheme('about')) return wa.NavigationDecision.navigate;
    final decision = _listener.onNavigationRequest(url);
    if (decision != StratumNavigationDecision.navigate) {
      return wa.NavigationDecision.prevent;
    }
    _session.didAllowNavigation();
    return wa.NavigationDecision.navigate;
  }

  void _handlePageStarted(String url) {
    final heldError = _session.didStartPage(url);
    _listener.onPageStarted(Uri.tryParse(url));
    if (heldError != null) _listener.onError(heldError);
  }

  void _handlePageFinished(String url) {
    // Android reports a finish for a redirect target before that page
    // starts; a finish with no open page start never reaches the app.
    if (!_session.didFinishPage()) return;
    _listener.onPageFinished(Uri.tryParse(url));
  }

  void _handleBridgeMessage(String data) {
    final accepted = _session.acceptMessage(data); // all: no sender
    if (accepted != null) {
      _listener.onMessage(accepted.message, accepted.sender);
    }
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
