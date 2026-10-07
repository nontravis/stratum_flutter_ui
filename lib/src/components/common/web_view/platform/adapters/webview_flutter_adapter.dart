import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/native_sender_channel.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;

/// [PlatformStratumWebView] for Android, iOS, and macOS, backed by
/// `webview_flutter`.
///
/// Page messages arrive through the [NativeSenderChannel], which names each
/// message's sender, never through a `webview_flutter` JavaScript channel.
final class WebviewFlutterAdapter implements PlatformStratumWebView {
  new(this._listener)
    : _session = NativeBridgeSession(
        allowedOrigins: () => _listener.allowedOrigins,
        namesSenders: true,
      ),
      _senderChannel = NativeSenderChannel.current {
    _ready = _configure();
  }

  final PlatformStratumWebViewListener _listener;
  final NativeBridgeSession _session;
  final NativeSenderChannel _senderChannel;
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
    // After two platform round trips, so the platform view exists.
    final attached = await _senderChannel.attach(
      _controller,
      _handleBridgeMessage,
    );
    if (!attached) _session.markBridgeUnsupported();
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

  /// Runs the dispatch script on the page shown; on Android, when that page
  /// refuses, the token check then runs through the reply proxy of the
  /// proving `hello`, so only that document can receive it (US-03 FR-02
  /// E13). A first script with no answer ends the send.
  @override
  Future<void> postMessage(String data) async {
    await _ready;
    final script = _session.scriptForMessage(data);
    final answer = await dispatchScriptAnswer(
      _controller.runJavaScriptReturningResult(script),
    );
    final run = answer == false
        ? _session.replyProxyScriptForMessage(data)
        : null;
    _session.confirmDelivery(
      run == null
          ? answer
          : await dispatchScriptAnswer(
              _senderChannel.runThroughReplyProxy(
                _controller,
                run.replyProxy,
                run.script,
              ),
            ),
    );
  }

  @override
  Widget buildView(BuildContext context) =>
      wf.WebViewWidget(controller: _controller);

  @override
  void dispose() {
    // webview_flutter releases the native view when WebViewWidget leaves the
    // tree. The controller ignores events that arrive after dispose. Load
    // about:blank first, so audio, video, and timers stop immediately
    // instead of running until the native view is collected (parity with
    // the web implementation, which navigates the iframe away on dispose).
    _session.willDispose();
    unawaited(_disposeLoad());
  }

  Future<void> _disposeLoad() async {
    await _ready;
    await _senderChannel.detach(_controller);
    await _controller.loadRequest(Uri.parse('about:blank'));
  }

  wf.NavigationDecision _handleNavigationRequest(wf.NavigationRequest request) {
    if (!request.isMainFrame) return wf.NavigationDecision.navigate;
    final url = Uri.tryParse(request.url);
    if (url == null) return wf.NavigationDecision.prevent;
    if (url.isScheme('about')) return wf.NavigationDecision.navigate;
    final decision = _listener.onNavigationRequest(url);
    if (decision != StratumNavigationDecision.navigate) {
      return wf.NavigationDecision.prevent;
    }
    _session.didAllowNavigation();
    return wf.NavigationDecision.navigate;
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

  void _handleBridgeMessage(String data, BridgeMessageSender sender) {
    final message = _session.acceptMessage(data, sender: sender);
    if (message != null) _listener.onMessage(message);
  }

  void _handleResourceError(wf.WebResourceError error) {
    // WebKit (iOS, macOS) reports NSURLErrorCancelled (-999) whenever a
    // navigation is superseded by another one in flight, for example a
    // second link tap or a `source` change during a load. It is not a
    // failure of the page that ends up loading, so it is dropped here.
    // Android's error codes range -1..-16 and cannot collide with it.
    if (error.errorCode == -999) return;
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
