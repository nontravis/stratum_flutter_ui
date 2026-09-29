import 'dart:js_interop';
import 'dart:math';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/web_view_history.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:web/web.dart' as web;

/// Creates the iframe-based web view used on the web.
PlatformStratumWebView createPlatformStratumWebView(
  PlatformStratumWebViewListener listener,
) => WebPlatformStratumWebView(listener);

/// [PlatformStratumWebView] for the web, built on an `<iframe>`.
///
/// A `url` source reaches Flutter with `window.parent.postMessage`. A
/// message is accepted only when it comes from this iframe's window and its
/// origin is allowed.
///
/// An `html` source has no verifiable origin: `srcdoc` renders with an
/// opaque origin serialized as `"null"`, and a page reached by navigating
/// away from it reports the same opaque origin. Counting iframe `load`
/// events cannot tell the two apart, because a navigated-to page controls
/// when its own `load` fires. Instead, HTML content is bootstrapped with a
/// per-render nonce and a private `MessageChannel` (see
/// [injectBridgeBootstrap]): only a handshake carrying the current nonce, on
/// a real channel port, is trusted. A `"null"`-origin `window` message that
/// is not that handshake is always dropped.
final class WebPlatformStratumWebView implements PlatformStratumWebView {
  new(this._listener) : _viewType = 'stratum-web-view-${_nextViewId++}' {
    _iframe.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => createView(),
    );
    web.window.addEventListener('message', _messageListener);
    _iframe.addEventListener('load', _loadListener);
  }

  static int _nextViewId = 0;
  static final Random _random = Random.secure();

  final PlatformStratumWebViewListener _listener;
  final String _viewType;
  final web.HTMLIFrameElement _iframe = web.HTMLIFrameElement();
  final WebViewHistory<StratumWebViewSource> _history =
      WebViewHistory<StratumWebViewSource>();
  late final JSFunction _messageListener = _handleMessage.toJS;
  late final JSFunction _loadListener = _handleLoad.toJS;
  bool _javaScriptEnabled = true;
  bool _disposed = false;
  String? _htmlNonce;
  web.MessagePort? _bridgePort;

  /// The iframe that shows the page.
  @visibleForTesting
  web.HTMLIFrameElement get iframe => _iframe;

  /// Returns the element for a new platform view.
  ///
  /// Flutter calls this each time the view is inserted into the page. The
  /// engine renders each platform view into a fresh, detached wrapper
  /// element, so re-insertion always discards the iframe's browsing
  /// context: `srcdoc` reloads, the bootstrap script runs again, and a new
  /// handshake carrying the same nonce replaces the adopted port.
  @visibleForTesting
  web.HTMLElement createView() => _iframe;

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    _javaScriptEnabled = enabled;
    final current = _history.current;
    if (current != null) _applySandbox(current);
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    if (source case StratumWebViewUrlSource(:final url)) {
      final decision = _listener.onNavigationRequest(url);
      if (decision == StratumNavigationDecision.prevent) return;
    }
    _history.push(source);
    _show(source);
  }

  @override
  Future<void> reload() async {
    final current = _history.current;
    if (current != null) _show(current);
  }

  @override
  Future<void> goBack() async {
    final previous = _history.back();
    if (previous != null) _show(previous);
  }

  @override
  Future<void> goForward() async {
    final next = _history.forward();
    if (next != null) _show(next);
  }

  @override
  Future<bool> canGoBack() async => _history.canGoBack;

  @override
  Future<bool> canGoForward() async => _history.canGoForward;

  @override
  Future<Uri?> currentUrl() async {
    final current = _history.current;
    if (current is! StratumWebViewUrlSource) return null;
    try {
      final href = _iframe.contentWindow?.location.href;
      if (href != null) return Uri.tryParse(href);
    } on Object {
      // Cross-origin frame: the browser hides its location.
    }
    return current.url;
  }

  @override
  Future<void> postMessage(String data) async {
    final current = _history.current;
    if (current == null) {
      throw StateError('The web view has no page to receive messages.');
    }
    switch (current) {
      case StratumWebViewHtmlSource():
        final port = _bridgePort;
        if (port == null) {
          throw StateError('The HTML page has not connected the bridge yet.');
        }
        port.postMessage(data.toJS);
      case StratumWebViewUrlSource(:final url):
        final frameWindow = _iframe.contentWindow;
        final origin = originOf(url);
        if (frameWindow == null ||
            origin == null ||
            !isAllowedOrigin(origin, _listener.allowedOrigins)) {
          throw StateError('$url is not an allowed message destination.');
        }
        frameWindow.postMessage(data.toJS, origin.toString().toJS);
    }
  }

  @override
  Widget buildView(BuildContext context) =>
      HtmlElementView(viewType: _viewType);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    web.window.removeEventListener('message', _messageListener);
    _iframe
      ..removeEventListener('load', _loadListener)
      ..removeAttribute('srcdoc')
      ..src = 'about:blank';
    _htmlNonce = null;
    _closeBridgePort();
  }

  void _show(StratumWebViewSource source) {
    _applySandbox(source);
    _closeBridgePort();
    switch (source) {
      case StratumWebViewUrlSource(:final url):
        _htmlNonce = null;
        _iframe
          ..removeAttribute('srcdoc')
          ..src = url.toString();
        _listener.onPageStarted(url);
      case StratumWebViewHtmlSource(:final html):
        final nonce = _generateNonce();
        _htmlNonce = nonce;
        _iframe.srcdoc = injectBridgeBootstrap(html, nonce).toJS;
        _listener.onPageStarted(null);
    }
  }

  void _applySandbox(StratumWebViewSource source) {
    final value = switch (source) {
      StratumWebViewHtmlSource() => _javaScriptEnabled ? 'allow-scripts' : '',
      StratumWebViewUrlSource() =>
        _javaScriptEnabled
            ? null
            : 'allow-same-origin allow-forms allow-popups',
    };
    if (value == null) {
      _iframe.removeAttribute('sandbox');
    } else {
      _iframe.setAttribute('sandbox', value);
    }
  }

  void _closeBridgePort() {
    _bridgePort?.close();
    _bridgePort = null;
  }

  String _generateNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _handleLoad(web.Event event) {
    if (_disposed) return;
    final current = _history.current;
    if (current == null) return;
    _listener.onPageFinished(
      current is StratumWebViewUrlSource ? current.url : null,
    );
  }

  void _handleMessage(web.MessageEvent event) {
    if (_disposed) return;
    final frameWindow = _iframe.contentWindow;
    if (frameWindow == null) return;
    if (!event.source.strictEquals(frameWindow).toDart) return;
    if (event.origin == 'null') {
      _handleHandshake(event);
      return;
    }
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final text = (data as JSString).toDart;
    final origin = Uri.tryParse(event.origin);
    if (!isAllowedOrigin(origin, _listener.allowedOrigins)) return;
    _listener.onMessage(
      StratumWebViewMessage(data: text, origin: originOf(origin)),
    );
  }

  /// Adopts the port from a genuine bootstrap handshake.
  ///
  /// Every other `"null"`-origin `window` message, including one that
  /// forges the `stratum-bridge-handshake:` prefix without a matching
  /// nonce, or without a real transferred port, is dropped here.
  void _handleHandshake(web.MessageEvent event) {
    final nonce = _htmlNonce;
    if (nonce == null || _history.current is! StratumWebViewHtmlSource) {
      return;
    }
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final text = (data as JSString).toDart;
    if (text != 'stratum-bridge-handshake:$nonce') return;
    final ports = event.ports.toDart;
    if (ports.length != 1) return;
    _closeBridgePort();
    final port = ports.first..onmessage = _handlePortMessage.toJS;
    _bridgePort = port;
  }

  void _handlePortMessage(web.MessageEvent event) {
    if (_disposed) return;
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    _listener.onMessage(StratumWebViewMessage(data: (data as JSString).toDart));
  }
}
