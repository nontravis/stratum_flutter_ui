import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Replaces the platform implementation for new controllers in tests.
@visibleForTesting
PlatformStratumWebViewFactory? debugStratumWebViewPlatformFactory;

/// Settings and callbacks that `StratumWebView` hands to its controller.
@internal
@immutable
final class StratumWebViewConfiguration {
  const new({
    this.allowedOrigins = const <Uri>{},
    this.javaScriptEnabled = true,
    this.onMessage,
    this.onNavigationRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onError,
  });

  final Set<Uri> allowedOrigins;
  final bool javaScriptEnabled;
  final ValueChanged<StratumWebViewMessage>? onMessage;
  final StratumNavigationDecision Function(Uri url)? onNavigationRequest;
  final ValueChanged<Uri?>? onPageStarted;
  final ValueChanged<Uri?>? onPageFinished;
  final ValueChanged<StratumWebViewError>? onError;
}

/// Loads content into a `StratumWebView`, controls its navigation, and sends
/// messages to the page.
///
/// A controller passed to `StratumWebView.controller` belongs to the caller,
/// who must call [dispose]. Every method throws a [StateError] after
/// [dispose].
final class StratumWebViewController {
  new() {
    final factory =
        debugStratumWebViewPlatformFactory ?? createPlatformStratumWebView;
    _platform = factory(_ControllerListener(this));
  }

  late final PlatformStratumWebView _platform;
  StratumWebViewConfiguration _configuration =
      const StratumWebViewConfiguration();
  bool _disposed = false;

  /// Sender of each message this controller delivered, keyed by the message
  /// object, so a message app code built that is equal by `==` never matches
  /// (US-03 FR-05 E01).
  final Expando<PlatformMessageSender> _senders =
      Expando<PlatformMessageSender>('StratumWebViewMessage sender');

  /// Loads the page at [url].
  ///
  /// Throws an [ArgumentError] unless [url] uses the `http` or `https`
  /// scheme. Other schemes (for example `javascript:` or a bare, scheme-less
  /// URL) are rejected because a `url` source runs without a sandbox on web.
  Future<void> loadUrl(Uri url) async {
    _ensureActive();
    if (!url.isScheme('http') && !url.isScheme('https')) {
      throw ArgumentError.value(
        url,
        'url',
        'must use the http or https scheme',
      );
    }
    await _platform.load(StratumWebViewSource.url(url));
  }

  /// Renders the [html] document.
  Future<void> loadHtml(String html) async {
    _ensureActive();
    await _platform.load(StratumWebViewSource.html(html));
  }

  /// Reloads the current page.
  ///
  /// On iOS and macOS a reload of HTML that the controller loaded shows an
  /// empty page, because WebKit reloads `about:blank`, so the bridge stays
  /// closed until the next [loadHtml].
  Future<void> reload() async {
    _ensureActive();
    await _platform.reload();
  }

  /// Goes back one page. On web, only pages the controller loaded count.
  Future<void> goBack() async {
    _ensureActive();
    await _platform.goBack();
  }

  /// Goes forward one page. On web, only pages the controller loaded count.
  Future<void> goForward() async {
    _ensureActive();
    await _platform.goForward();
  }

  /// Whether [goBack] has a page to return to.
  Future<bool> canGoBack() async {
    _ensureActive();
    return _platform.canGoBack();
  }

  /// Whether [goForward] has a page to return to.
  Future<bool> canGoForward() async {
    _ensureActive();
    return _platform.canGoForward();
  }

  /// URL of the current page.
  ///
  /// On web, from a load the controller starts until the frame finishes
  /// loading it, this is the URL the controller requested; after that, a
  /// same-origin page reports the frame's location, and a cross-origin page
  /// the last URL the controller loaded.
  Future<Uri?> currentUrl() async {
    _ensureActive();
    return _platform.currentUrl();
  }

  /// Sends [data] to the page as a `message` event.
  ///
  /// Without [targetOrigin] the page shown at delivery receives it. With
  /// [targetOrigin], only a page with that origin does: it is compared as an
  /// origin (scheme, host without case, and port; path, query, and fragment
  /// are ignored), must match an entry of `StratumWebView.allowedOrigins`,
  /// and never matches HTML the controller loaded. To answer a message, use
  /// [reply], which names the sender for you.
  ///
  /// Throws a [StateError] when `StratumWebView.allowedOrigins` is empty,
  /// when the current page is not an allowed destination, when
  /// [targetOrigin] matches no allowed entry or the page shown at delivery
  /// has another origin, on Android when the system WebView has no
  /// `WEB_MESSAGE_LISTENER` or `JS_INJECTION_IN_FRAME_AND_WORLD` support, or
  /// when HTML the controller loaded has not connected the bridge yet: wait
  /// for a first message from the page, so `await loadHtml(html)` followed
  /// at once by `postMessage` throws. On native the page itself checks that
  /// it may receive the message, or that check gives no answer within five
  /// seconds; either way the error names no origin. On Android a send to
  /// HTML reaches only the document that connected the bridge; once that
  /// document leaves, the next one gets nothing and the send throws. On
  /// web, a message sent to HTML content after the user navigated away from
  /// it is dropped without an error: the browser gives no signal that the
  /// page left. On web, a page that changes origin after the [targetOrigin]
  /// check drops the message without an error.
  Future<void> postMessage(String data, {Uri? targetOrigin}) async {
    _ensureActive();
    _ensureBridgeOpen();
    if (targetOrigin == null) {
      await _platform.postMessage(data);
    } else {
      await _sendNamed(data, targetOrigin);
    }
  }

  /// Sends [data] as a `message` event to the sender of [message], a
  /// message this controller delivered through `StratumWebView.onMessage`.
  ///
  /// A URL page receives it only while the page shown has the message's
  /// origin, as `postMessage(data, targetOrigin: message.origin)` would; a
  /// reload of that page, or another page of the same origin, receives it
  /// too. HTML the controller loaded receives it only in the document that
  /// sent [message], never in a later document of the same load.
  ///
  /// Throws an [ArgumentError] for a message this controller did not
  /// deliver, such as one app code built. Throws a [StateError] as
  /// [postMessage] does, and when the sender is not the page shown or is
  /// gone. On Windows and Linux a message carries the origin of the page of
  /// the last `StratumWebView.onPageStarted`, so around a navigation a reply
  /// can reach the page shown instead of the sender. On web, a reply to HTML
  /// after the user followed a link away inside it is dropped without an
  /// error.
  Future<void> reply(StratumWebViewMessage message, String data) async {
    _ensureActive();
    final sender = _senders[message];
    if (sender == null) {
      throw ArgumentError(
        'The message was not delivered by this controller.',
        'message',
      );
    }
    _ensureBridgeOpen();
    switch (sender) {
      case PlatformUrlPageSender(:final origin):
        await _sendNamed(data, origin);
      case PlatformHtmlDocumentSender():
        await _platform.replyToDocument(sender, data);
    }
  }

  void _ensureBridgeOpen() {
    if (_configuration.allowedOrigins.isEmpty) {
      throw StateError(
        'The bridge is disabled because allowedOrigins is empty.',
      );
    }
    if (!_configuration.javaScriptEnabled) {
      throw StateError(
        'The bridge is disabled because javaScriptEnabled is false.',
      );
    }
  }

  Future<void> _sendNamed(String data, Uri targetOrigin) async {
    final target = originOf(targetOrigin);
    if (!isAllowedOrigin(target, _configuration.allowedOrigins)) {
      throw StateError(
        'targetOrigin $target is not an allowed message destination.',
      );
    }
    await _platform.postMessage(data, targetOrigin: target);
  }

  /// Releases the platform web view. Later calls throw a [StateError].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _configuration = const StratumWebViewConfiguration();
    _platform.dispose();
  }

  /// The configuration from the last [configure] call, or the default after
  /// [dispose].
  @internal
  @visibleForTesting
  StratumWebViewConfiguration get debugConfiguration => _configuration;

  /// Drops the callbacks and allowlist of the `StratumWebView` that stopped
  /// showing this controller, so a page that keeps running cannot reach
  /// them. The JavaScript setting is kept because the platform still has it.
  /// Does nothing after [dispose].
  @internal
  void detach() {
    if (_disposed) return;
    _configuration = StratumWebViewConfiguration(
      javaScriptEnabled: _configuration.javaScriptEnabled,
    );
  }

  /// Applies the settings of the `StratumWebView` that shows this controller.
  @internal
  void configure(StratumWebViewConfiguration configuration) {
    _ensureActive();
    // An entry that can never match would silently disable the bridge.
    assert(
      configuration.allowedOrigins.every(
        (origin) => allowedOriginProblem(origin) == null,
      ),
      'allowedOrigins: '
      '${configuration.allowedOrigins.map(allowedOriginProblem).nonNulls}',
    );
    final javaScriptChanged =
        configuration.javaScriptEnabled != _configuration.javaScriptEnabled;
    _configuration = configuration;
    if (javaScriptChanged) {
      unawaited(
        _platform.setJavaScriptEnabled(configuration.javaScriptEnabled),
      );
    }
  }

  /// Builds the platform view that displays the page.
  @internal
  Widget buildView(BuildContext context) {
    _ensureActive();
    return _platform.buildView(context);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('A StratumWebViewController was used after dispose().');
    }
  }
}

final class _ControllerListener implements PlatformStratumWebViewListener {
  new(this._controller);

  final StratumWebViewController _controller;

  StratumWebViewConfiguration get _configuration => _controller._configuration;

  bool get _active => !_controller._disposed;

  @override
  Set<Uri> get allowedOrigins => _configuration.allowedOrigins;

  @override
  void onMessage(StratumWebViewMessage message, PlatformMessageSender sender) {
    final callback = _configuration.onMessage;
    if (!_active ||
        allowedOrigins.isEmpty ||
        !_configuration.javaScriptEnabled ||
        callback == null) {
      return;
    }
    _controller._senders[message] = sender;
    _guard('onMessage', () => callback(message));
  }

  @override
  StratumNavigationDecision onNavigationRequest(Uri url) {
    if (!_active) return StratumNavigationDecision.prevent;
    final callback = _configuration.onNavigationRequest;
    if (callback == null) return StratumNavigationDecision.navigate;
    try {
      return callback(url);
    } on Object catch (error, stack) {
      _report('onNavigationRequest', error, stack);
      return StratumNavigationDecision.prevent;
    }
  }

  @override
  void onPageStarted(Uri? url) {
    final callback = _configuration.onPageStarted;
    if (!_active || callback == null) return;
    _guard('onPageStarted', () => callback(url));
  }

  @override
  void onPageFinished(Uri? url) {
    final callback = _configuration.onPageFinished;
    if (!_active || callback == null) return;
    _guard('onPageFinished', () => callback(url));
  }

  @override
  void onError(StratumWebViewError error) {
    final callback = _configuration.onError;
    if (!_active || callback == null) return;
    _guard('onError', () => callback(error));
  }

  void _guard(String callbackName, VoidCallback body) {
    try {
      body();
    } on Object catch (error, stack) {
      _report(callbackName, error, stack);
    }
  }

  void _report(String callbackName, Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stratum_ui',
        context: ErrorDescription('while calling StratumWebView.$callbackName'),
      ),
    );
  }
}
