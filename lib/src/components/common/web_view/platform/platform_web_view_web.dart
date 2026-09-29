import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_frame_guard.dart';
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
/// Pages reach Flutter with `window.parent.postMessage`. A message is
/// accepted only when it comes from this iframe's window and either its
/// origin is allowed, or the iframe still shows HTML loaded by the
/// controller.
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

  final PlatformStratumWebViewListener _listener;
  final String _viewType;
  final web.HTMLIFrameElement _iframe = web.HTMLIFrameElement();
  final HtmlFrameGuard _guard = HtmlFrameGuard();
  final WebViewHistory<StratumWebViewSource> _history =
      WebViewHistory<StratumWebViewSource>();
  late final JSFunction _messageListener = _handleMessage.toJS;
  late final JSFunction _loadListener = _handleLoad.toJS;
  bool _javaScriptEnabled = true;
  bool _disposed = false;

  /// The iframe that shows the page.
  @visibleForTesting
  web.HTMLIFrameElement get iframe => _iframe;

  /// Returns the element for a new platform view.
  ///
  /// Flutter calls this each time the view is inserted into the page.
  /// Re-inserting an iframe reloads it, so loaded HTML is expected again.
  @visibleForTesting
  web.HTMLElement createView() {
    if (_history.current is StratumWebViewHtmlSource) _guard.expectOwnHtml();
    return _iframe;
  }

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
    final frameWindow = _iframe.contentWindow;
    final current = _history.current;
    if (frameWindow == null || current == null) {
      throw StateError('The web view has no page to receive messages.');
    }
    switch (current) {
      case StratumWebViewHtmlSource():
        if (!_guard.isShowingOwnHtml) {
          throw StateError('The frame navigated away from the loaded HTML.');
        }
        frameWindow.postMessage(data.toJS, '*'.toJS);
      case StratumWebViewUrlSource(:final url):
        final origin = originOf(url);
        if (origin == null ||
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
  }

  void _show(StratumWebViewSource source) {
    _applySandbox(source);
    switch (source) {
      case StratumWebViewUrlSource(:final url):
        _guard.expectNavigation();
        _iframe
          ..removeAttribute('srcdoc')
          ..src = url.toString();
        _listener.onPageStarted(url);
      case StratumWebViewHtmlSource(:final html):
        _guard.expectOwnHtml();
        _iframe.srcdoc = html.toJS;
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

  void _handleLoad(web.Event event) {
    if (_disposed) return;
    final current = _history.current;
    if (current == null) return;
    _guard.didLoadFrame();
    _listener.onPageFinished(
      current is StratumWebViewUrlSource ? current.url : null,
    );
  }

  void _handleMessage(web.MessageEvent event) {
    if (_disposed) return;
    final frameWindow = _iframe.contentWindow;
    if (frameWindow == null) return;
    if (!event.source.strictEquals(frameWindow).toDart) return;
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final text = (data as JSString).toDart;
    if (event.origin == 'null') {
      final showingHtml =
          _history.current is StratumWebViewHtmlSource &&
          _guard.isShowingOwnHtml;
      if (showingHtml) _listener.onMessage(StratumWebViewMessage(data: text));
      return;
    }
    final origin = Uri.tryParse(event.origin);
    if (!isAllowedOrigin(origin, _listener.allowedOrigins)) return;
    _listener.onMessage(
      StratumWebViewMessage(data: text, origin: originOf(origin)),
    );
  }
}
