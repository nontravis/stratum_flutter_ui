import 'dart:js_interop';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_message.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_navigation_decision.dart';
import 'package:stratum_ui/src/components/common/model/web_view/web_view_source.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/web_view_history.dart';
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
  new(this._listener) {
    _iframe.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%';
    web.window.addEventListener('message', _messageListener);
    _iframe.addEventListener('load', _loadListener);
  }

  static final Random _random = Random.secure();

  final PlatformStratumWebViewListener _listener;
  final web.HTMLIFrameElement _iframe = web.HTMLIFrameElement();
  final WebViewHistory<StratumWebViewSource> _history =
      WebViewHistory<StratumWebViewSource>();
  late final JSFunction _messageListener = _handleMessage.toJS;
  late final JSFunction _loadListener = _handleLoad.toJS;
  bool _javaScriptEnabled = true;
  bool _disposed = false;
  String? _htmlNonce;
  _WebHtmlDocumentSender? _bridge;

  /// Whether a page start was reported that no frame `load` has finished:
  /// from a controller load, or a re-insertion that restarts a completed
  /// entry's navigation, until the frame's `load` for that entry.
  bool _pageStartOpen = false;

  /// The document the frame showed before the current entry started, or
  /// `null` for a cross-origin or disconnected frame.
  ///
  /// A same-origin outgoing page may fire its own `load` after a newer
  /// entry starts (sec-m3 F1); [_handleLoad] drops a `load` while the frame
  /// still shows this document, since it belongs to the page being left.
  web.Document? _leavingDocument;

  /// The iframe that shows the page.
  @visibleForTesting
  web.HTMLIFrameElement get iframe => _iframe;

  /// Puts the iframe into [host], the element Flutter created for a new
  /// platform view, and makes [host] fill the view.
  ///
  /// Flutter creates a fresh host each time the view is inserted into the
  /// page, so re-insertion always moves the iframe and discards its browsing
  /// context: `srcdoc` reloads, the bootstrap script runs again, and a new
  /// handshake carrying the same nonce replaces the adopted port. The old
  /// port is closed here, before the move, so a reply to the document being
  /// discarded throws at once instead of resolving into a dead port (US-03
  /// FR-05 E06). When that restart lands on a completed entry (no load
  /// already open), reopen the request-to-load window: otherwise
  /// `currentUrl()` would read the restarted navigation's transient
  /// `about:blank` instead of the entry's URL (US-04 FR-01 E02).
  @visibleForTesting
  void attachTo(web.HTMLElement host) {
    _closeBridgePort();
    host.style
      ..width = '100%'
      ..height = '100%';
    host.appendChild(_iframe);
    final current = _history.current;
    if (current != null && !_pageStartOpen) {
      _pageStartOpen = true;
      _listener.onPageStarted(
        current is StratumWebViewUrlSource ? current.url : null,
      );
    }
  }

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    _javaScriptEnabled = enabled;
    final current = _history.current;
    if (current != null) _applySandbox(current);
  }

  @override
  Future<void> load(StratumWebViewSource source) async {
    // Yield one microtask before touching the listener, so a callback that
    // runs `setState` never lands inside the caller's build phase (matches
    // native, where every adapter method awaits `_ready` first). A dispose
    // that ran during the yield wins: nothing renders into the blank frame.
    await Future<void>.value();
    if (_disposed) return;
    if (source case StratumWebViewUrlSource(:final url)) {
      final decision = _listener.onNavigationRequest(url);
      if (decision == StratumNavigationDecision.prevent) return;
    }
    _history.push(source);
    _show(source);
  }

  @override
  Future<void> reload() async {
    await Future<void>.value();
    if (_disposed) return;
    final current = _history.current;
    if (current != null) _show(current);
  }

  @override
  Future<void> goBack() async {
    await Future<void>.value();
    if (_disposed) return;
    final previous = _history.back();
    if (previous != null) _show(previous);
  }

  @override
  Future<void> goForward() async {
    await Future<void>.value();
    if (_disposed) return;
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
    // From the controller's load until the frame's `load` for that entry,
    // the frame may still show the document it is leaving (US-04 FR-01
    // E02): report the requested URL.
    if (_pageStartOpen) return current.url;
    try {
      final href = _iframe.contentWindow?.location.href;
      final frameUrl = href == null ? null : Uri.tryParse(href);
      if (frameUrl != null) return frameUrl;
    } on Object {
      // Cross-origin frame: the browser hides its location.
    }
    return current.url;
  }

  /// With [targetOrigin], the view throws when the app's own HTML is shown
  /// (it has no origin to compare) or when the current entry's origin is
  /// not [targetOrigin] (US-03 FR-02 E16, E17). The post still carries the
  /// current entry's own origin as the browser's `targetOrigin`, which
  /// drops the message when the frame changed origin after this check
  /// (US-03 FR-02 E17).
  @override
  Future<void> postMessage(String data, {Uri? targetOrigin}) async {
    final current = _history.current;
    if (current == null) {
      throw StateError('The web view has no page to receive messages.');
    }
    switch (current) {
      case StratumWebViewHtmlSource():
        if (targetOrigin != null) {
          throw StateError(
            "The app's HTML has no origin to match targetOrigin.",
          );
        }
        final port = _bridge?.port;
        if (port == null || !_iframe.isConnected) {
          throw StateError('The HTML page has not connected the bridge yet.');
        }
        port.postMessage(data.toJS);
      case StratumWebViewUrlSource(:final url):
        final frameWindow = _iframe.contentWindow;
        final origin = originOf(url);
        if (frameWindow == null ||
            origin == null ||
            !isAllowedOrigin(origin, _listener.allowedOrigins)) {
          throw StateError('$origin is not an allowed message destination.');
        }
        if (targetOrigin != null && origin != originOf(targetOrigin)) {
          throw StateError(
            'The current page is not the named message destination.',
          );
        }
        frameWindow.postMessage(data.toJS, origin.toString().toJS);
    }
  }

  /// After a link away inside the frame the port stays adopted and the
  /// browser gives no signal, so the reply resolves and is dropped (FR-05
  /// E07).
  @override
  Future<void> replyToDocument(
    PlatformHtmlDocumentSender document,
    String data,
  ) async {
    if (!identical(document, _bridge) || !_iframe.isConnected) {
      throw StateError('The HTML document that sent the message is gone.');
    }
    (document as _WebHtmlDocumentSender).port.postMessage(data.toJS);
  }

  @override
  Widget buildView(BuildContext context) => HtmlElementView.fromTagName(
    // A per-instance factory registered with `platformViewRegistry` could
    // never be unregistered, so every disposed view stayed reachable.
    tagName: 'div',
    onElementCreated: (host) => attachTo(host as web.HTMLElement),
  );

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
    _leavingDocument = _iframe.contentDocument;
    _applySandbox(source);
    _closeBridgePort();
    _pageStartOpen = true;
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
    _bridge?.port.close();
    _bridge = null;
  }

  String _generateNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _handleLoad(web.Event event) {
    if (_disposed) return;
    final leaving = _leavingDocument;
    if (leaving != null && _iframe.contentDocument == leaving) {
      // Belongs to the document being left, not the new entry; ignore it.
      return;
    }
    final current = _history.current;
    if (current == null) return;
    final url = current is StratumWebViewUrlSource ? current.url : null;
    // The web has no start event of its own: a frame load that no `_show`
    // or `attachTo` restart already opened (a link inside the frame)
    // reports its start first, so every finish pairs with one start.
    if (!_pageStartOpen) _listener.onPageStarted(url);
    _pageStartOpen = false;
    _listener.onPageFinished(url);
  }

  void _handleMessage(web.MessageEvent event) {
    if (_disposed) return;
    // A script on the app's own origin can dispatch a synthetic `message`
    // event with a forged `origin` and `source` (sec-m3 F3): drop any event
    // the browser did not author, before the handshake branch sees it too.
    // This closes only that synthetic path. A same-origin script that
    // reads the nonce off `frameElement.srcdoc` can still win a real
    // handshake by navigating this frame to a page of its own, which posts
    // it for real; the web row of `## Platform limits` in
    // s01_architecture.md covers that co-tenancy case, not this guard.
    if (!event.isTrusted) return;
    final frameWindow = _iframe.contentWindow;
    if (frameWindow == null) return;
    if (!event.source.strictEquals(frameWindow).toDart) return;
    if (event.origin == 'null') {
      _handleHandshake(event);
      return;
    }
    // The origin names the page that sent the message, whatever entry the
    // view shows now: an outgoing page may still speak before it unloads
    // (US-03 FR-01 E05).
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final text = (data as JSString).toDart;
    final origin = Uri.tryParse(event.origin);
    if (!isAllowedOrigin(origin, _listener.allowedOrigins)) return;
    // An allowed origin is never null (isAllowedOrigin).
    final sender = originOf(origin)!;
    _listener.onMessage(
      StratumWebViewMessage(data: text, origin: sender),
      PlatformUrlPageSender(sender),
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
    final sender = _WebHtmlDocumentSender(ports.first);
    sender.port.onmessage = ((web.MessageEvent event) => _handlePortMessage(
      sender,
      event,
    )).toJS;
    _bridge = sender;
  }

  void _handlePortMessage(
    _WebHtmlDocumentSender sender,
    web.MessageEvent event,
  ) {
    if (_disposed) return;
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    _listener.onMessage(
      StratumWebViewMessage(data: (data as JSString).toDart),
      sender,
    );
  }
}

/// One document of the app's own HTML, bound to the [port] its handshake's
/// adopted channel carries (US-03 FR-05 E06).
final class _WebHtmlDocumentSender extends PlatformHtmlDocumentSender {
  new(this.port);

  /// The port adopted from the document's handshake.
  final web.MessagePort port;
}
