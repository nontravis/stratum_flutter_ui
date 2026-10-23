import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_navigation_decision.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
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
  var _disposed = false;

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
        onMessageReceived: _handleBridgeMessage,
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

  /// Waits for the platform's configuration; `false` once [dispose] ran, so
  /// a call started just before it reaches no platform (parity with the web
  /// view, whose load started before dispose leaves the frame blank).
  Future<bool> _live() async {
    await _ready;
    return !_disposed;
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    if (!await _live()) return;
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
    if (!await _live()) return;
    _session.willReload();
    await _controller.reload();
  }

  @override
  Future<void> goBack() async {
    if (!await _live()) return;
    _session.willNavigate();
    await _controller.goBack();
  }

  @override
  Future<void> goForward() async {
    if (!await _live()) return;
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

  /// Runs the token-and-id dispatch script that
  /// [NativeBridgeSession.scriptForReply] builds for [document], on the
  /// page shown; this session never binds sends to a document, so no reply
  /// proxy ever applies (US-03 FR-05 E08, E09).
  @override
  Future<void> replyToDocument(
    PlatformHtmlDocumentSender document,
    String data,
  ) async {
    await _ready;
    final run = _session.scriptForReply(data, document);
    _session.confirmDelivery(
      await dispatchScriptAnswer(
        _controller.runJavaScriptReturningResult(run.script),
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
    _disposed = true;
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

  void _handleBridgeMessage(wa.JavaScriptMessage message) {
    final accepted = _session.acceptMessage(
      message.message,
      sender: _senderOf(message),
    );
    if (accepted != null) {
      _listener.onMessage(accepted.message, accepted.sender);
    }
  }

  /// The sender [message] names, or `null` when it names none, which drops
  /// the message (US-05 FR-01 E04, US-06 FR-01 E04).
  ///
  /// The origin is `sourceOrigin` when the plugin passes one, with the text
  /// `"null"` meaning an opaque origin, else the origin of `sourceUrl`;
  /// with neither, the origin is opaque.
  BridgeMessageSender? _senderOf(wa.JavaScriptMessage message) {
    final isMainFrame = message.isMainFrame;
    if (isMainFrame == null) return null;
    final sourceOrigin = message.sourceOrigin;
    final sourceUrl = message.sourceUrl;
    final Uri? origin;
    if (sourceOrigin != null) {
      origin = sourceOrigin == 'null'
          ? null
          : originOf(Uri.tryParse(sourceOrigin));
    } else {
      origin = sourceUrl == null ? null : originOf(Uri.tryParse(sourceUrl));
    }
    return BridgeMessageSender(origin: origin, isMainFrame: isMainFrame);
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
