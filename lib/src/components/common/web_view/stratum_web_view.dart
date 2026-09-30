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
/// page on every platform. The bridge stays off while [allowedOrigins] is
/// empty, HTML content included: give HTML a non-empty [allowedOrigins]
/// too. HTML content is trusted until the user navigates away from it. On
/// native, navigating back or forward to that HTML afterward does not
/// re-arm the bridge; call `loadHtml` again. On web, a strict app
/// Content-Security-Policy without inline scripts blocks the bootstrap
/// script and disables the HTML bridge; scripts that run in the app's own
/// window are trusted regardless, since the handshake is visible there.
///
/// **Limitations.**
/// * Web: the page is an `<iframe>`. [onError] never fires, and
///   [onNavigationRequest] only sees loads started by the controller. A
///   `url` page runs without a sandbox, so a page reached inside the frame
///   can navigate the whole app window after a click. Many sites refuse to
///   be framed; offer an "open in new tab" fallback. Flutter overlays
///   drawn above the view need `PointerInterceptor`. An HTML page's URL is
///   always `null`; on native it is `about:blank`.
/// * Linux: the page is a native GTK widget, so Flutter widgets cannot draw
///   above it, and scale or rotation transforms hide it.
/// * Native: the bridge channel is visible to every frame of an allowed
///   page. Allow only pages that embed no untrusted iframes. The page
///   origin is inferred from navigation events (`onPageStarted`); on iOS
///   and macOS that fires at the provisional start of a navigation, before
///   the new page commits, so a disallowed page can still be running when
///   its origin is recorded as allowed. [onError] may also report an HTTP
///   error from an embedded iframe on iOS and macOS, not only the
///   top-level page. Treat bridge messages as untrusted input, and use
///   [onNavigationRequest] to prevent top-level navigation outside
///   [allowedOrigins] when a hard boundary is needed.
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
  final Set<Uri> allowedOrigins;

  /// Whether pages may run JavaScript. The bridge needs JavaScript.
  final bool javaScriptEnabled;

  /// Receives messages from allowed pages and from loaded HTML.
  final ValueChanged<StratumWebViewMessage>? onMessage;

  ///========== Navigation ==========///
  /// Decides whether a main-frame navigation may proceed.
  final StratumNavigationDecision Function(Uri url)? onNavigationRequest;

  /// Called when a page starts loading.
  final ValueChanged<Uri?>? onPageStarted;

  /// Called when a page finishes loading.
  final ValueChanged<Uri?>? onPageFinished;

  /// Called for main-frame loading failures on native platforms.
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
