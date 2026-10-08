import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Displays a web page or an HTML document on Android, iOS, macOS, Windows,
/// Linux, and the web.
///
/// **Bridge.** A page calls `StratumBridge.postMessage(data)` whenever
/// `window.StratumBridge` exists: on every native platform, and for HTML
/// content on web. A `url` page on web has no injected bridge and instead
/// calls `window.parent.postMessage(data, appOrigin)`. Feature-detect both:
///
/// ```js
/// function sendToFlutter(data) {
///   if (window.StratumBridge) StratumBridge.postMessage(data);
///   else window.parent.postMessage(data, 'https://your-app.example');
/// }
/// ```
///
/// `StratumWebViewController.postMessage` delivers a `message` event to the
/// page on every platform. Answer a message with
/// `StratumWebViewController.reply`, which reaches only the page or HTML
/// document that sent it, subject to the per-platform limits below;
/// `postMessage` with a `targetOrigin` names the recipient origin. The
/// bridge stays off while [allowedOrigins] is
/// empty, HTML content included: give HTML a non-empty [allowedOrigins]
/// too. HTML content is trusted by a secret that its bootstrap script
/// carries, new for every HTML load, never by the page address: a page the
/// user reaches from that HTML never passes as it, and going back or
/// forward to the HTML of the latest load brings the bridge back. A
/// `postMessage` to HTML before its bootstrap connected the bridge throws a
/// [StateError] on every platform, so wait for a first message from the
/// page. On web, the app's own Content-Security-Policy without inline
/// scripts blocks the bootstrap and keeps the HTML bridge closed; on
/// native, a policy inside the document never reaches the bootstrap, so the
/// HTML bridge always opens. On web, scripts that run in the app's own
/// window are trusted regardless, since the handshake is visible there.
///
/// **Limitations.**
/// * Web: the page is an `<iframe>`. [onError] never fires, and
///   [onNavigationRequest] only sees loads started by the controller. A
///   `url` page runs without a sandbox, so a page reached inside the frame
///   can navigate the whole app window after a click. Many sites refuse to
///   be framed; offer an "open in new tab" fallback. Flutter overlays
///   drawn above the view need `PointerInterceptor`. An HTML page's URL is
///   always `null`; on native it is `about:blank`. A URL page that the view
///   has moved away from can still deliver a message, with its own allowed
///   origin, until it unloads. A `reply` to it throws once the view shows
///   another origin, except after an in-frame link to another origin: the
///   check still passes against the page's prior history entry, and the
///   browser drops the reply silently with no throw. A `reply` to your own
///   HTML after a link away inside it resolves the same way, without
///   delivering the data.
/// * Linux: the page is a native GTK widget, so Flutter widgets cannot draw
///   above it, and scale or rotation transforms hide it.
/// * Android, iOS, and macOS: the platform names the sender of each
///   message, so only the top-level page's messages pass, each with its
///   sender's origin, even one that arrives before [onPageStarted]. On
///   Android the system WebView needs `WEB_MESSAGE_LISTENER` and
///   `JS_INJECTION_IN_FRAME_AND_WORLD` support; without either the bridge
///   stays off, and every `postMessage` throws a [StateError]. On Android a
///   `postMessage` to HTML reaches only the document that connected the
///   bridge; once that document leaves, the next one gets nothing and the
///   send throws a [StateError]. [onError] may also report an HTTP error
///   from an embedded iframe on iOS and macOS, not only the top-level page.
/// * Windows and Linux: the bridge channel is visible to every frame of an
///   allowed page, so allow only pages that embed no untrusted iframes. A
///   message is credited to the page of the last [onPageStarted], so around
///   a navigation it can carry the origin of the page before or after the
///   one that sent it. A `reply` is credited the same way, so it can reach
///   a page other than the sender.
/// * Every native platform: treat bridge messages as untrusted input, and
///   use [onNavigationRequest] to prevent top-level navigation outside
///   [allowedOrigins] when a hard boundary is needed.
/// * Android: the platform marks no main frame on an HTTP error, so an HTTP
///   error counts for the page whose start follows it. A sub-resource that
///   failed on the address a later navigation the page starts and the
///   platform does not ask about — a history move of the page's own script,
///   a script reload, a form POST — lands on is reported through [onError]
///   as that page's error, even when the page now answers 200, unless a
///   navigation began between: a load, a reload, a controller back or
///   forward, or a main-frame navigation that [onNavigationRequest] allows.
///   A loading page's start ends only when the platform reports its finish
///   or a new page starts, so a back or forward that starts no new document
///   keeps the page's finish, and a replaced load's late finish pairs with
///   its own start. A navigation the page starts while it still loads may
///   report its HTTP error through [onError] before the new load's
///   [onPageStarted] when it goes to the page's own address, or may report
///   an [onPageFinished] that names the redirect target, paired with the
///   loading page's open start, before the target's [onPageStarted] when it
///   goes to an address the server redirects; a stray finish of a replaced
///   navigation may likewise pair with the replacement's own start.
class StratumWebView extends StatefulWidget {
  const new({
    super.key,
    required this.source,
    this.controller,
    this.allowedOrigins = const <Uri>{},
    this.javaScriptEnabled = true,
    this.onMessage,
    this.onNavigationRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onError,
  });

  ///========== Content ==========///
  /// Content to display. A new value that is not equal loads again.
  final StratumWebViewSource source;

  /// Controller to drive the view. When `null`, the widget owns one.
  final StratumWebViewController? controller;

  ///========== Bridge ==========///
  /// Origins allowed to exchange messages. Empty disables the bridge.
  ///
  /// Each entry needs an http or https scheme and an ASCII host (punycode
  /// for internationalized domains, `https://xn--bcher-kva.de`); debug
  /// builds assert this, because any other entry never matches.
  final Set<Uri> allowedOrigins;

  /// Whether pages may run JavaScript. The bridge needs JavaScript.
  final bool javaScriptEnabled;

  /// Receives messages from allowed pages and from loaded HTML.
  ///
  /// A message's origin names the page that sent it, `null` for loaded
  /// HTML; it says nothing about the page the view shows now.
  final ValueChanged<StratumWebViewMessage>? onMessage;

  ///========== Navigation ==========///
  /// Decides whether a main-frame navigation may proceed.
  ///
  /// Not called for sub-frames or `about:` URLs, which always proceed, nor
  /// for a main-frame URL that cannot be parsed, which is always prevented.
  final StratumNavigationDecision Function(Uri url)? onNavigationRequest;

  /// Called when a page starts loading.
  ///
  /// On the web, also right before a frame `load` that no controller call
  /// started: a link inside the frame, or the frame's reload when the view
  /// is inserted again.
  final ValueChanged<Uri?>? onPageStarted;

  /// Called when a page finishes loading.
  ///
  /// Each call pairs with one earlier [onPageStarted] call, on every
  /// platform.
  final ValueChanged<Uri?>? onPageFinished;

  /// Called for main-frame loading failures on native platforms.
  ///
  /// On iOS and macOS an HTTP error from an embedded iframe can also arrive
  /// here, because WebKit does not mark which frame a response belongs to.
  final ValueChanged<StratumWebViewError>? onError;

  @override
  State<StratumWebView> createState() => _StratumWebViewState();
}

class _StratumWebViewState extends State<StratumWebView> {
  StratumWebViewController? _ownedController;

  StratumWebViewController get _controller =>
      widget.controller ?? (_ownedController ??= StratumWebViewController());

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(StratumWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldController = oldWidget.controller;
      if (oldController == null) {
        _ownedController?.dispose();
        _ownedController = null;
      } else {
        oldController.detach();
      }
      _attach();
      return;
    }
    _controller.configure(_configuration());
    if (oldWidget.source != widget.source) unawaited(_load());
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  void _attach() {
    _controller.configure(_configuration());
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      switch (widget.source) {
        case StratumWebViewUrlSource(:final url):
          await _controller.loadUrl(url);
        case StratumWebViewHtmlSource(:final html):
          await _controller.loadHtml(html);
      }
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stratum_ui',
          context: ErrorDescription('while loading a StratumWebView source'),
        ),
      );
    }
  }

  StratumWebViewConfiguration _configuration() => StratumWebViewConfiguration(
    allowedOrigins: widget.allowedOrigins,
    javaScriptEnabled: widget.javaScriptEnabled,
    onMessage: widget.onMessage,
    onNavigationRequest: widget.onNavigationRequest,
    onPageStarted: widget.onPageStarted,
    onPageFinished: widget.onPageFinished,
    onError: widget.onError,
  );

  @override
  Widget build(BuildContext context) => _controller.buildView(context);
}
