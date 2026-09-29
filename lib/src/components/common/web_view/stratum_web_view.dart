import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_controller.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Displays a web page or an HTML document on Android, iOS, macOS, Windows,
/// Linux, and the web.
///
/// **Bridge.** Pages send messages with `StratumBridge.postMessage(data)` on
/// native platforms and `window.parent.postMessage(data, appOrigin)` on the
/// web; both reach [onMessage]. `StratumWebViewController.postMessage`
/// delivers a `message` event to the page. The bridge stays off while
/// [allowedOrigins] is empty. HTML content is trusted until the user
/// navigates away from it.
///
/// **Limitations.**
/// * Web: the page is an `<iframe>`. [onError] never fires, and
///   [onNavigationRequest] only sees loads started by the controller. Many
///   sites refuse to be framed; offer an "open in new tab" fallback. Flutter
///   overlays drawn above the view need `PointerInterceptor`.
/// * Linux: the page is a native GTK widget, so Flutter widgets cannot draw
///   above it, and scale or rotation transforms hide it.
/// * Native: the bridge channel is visible to every frame of an allowed
///   page. Allow only pages that embed no untrusted iframes. The page
///   origin is inferred from navigation events (`onPageStarted`); on iOS
///   and macOS that fires at the provisional start of a navigation, before
///   the new page commits, so a disallowed page can still be running when
///   its origin is recorded as allowed. Treat bridge messages as untrusted
///   input, and use [onNavigationRequest] to prevent top-level navigation
///   outside [allowedOrigins] when a hard boundary is needed.
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
      if (oldWidget.controller == null) {
        _ownedController?.dispose();
        _ownedController = null;
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
