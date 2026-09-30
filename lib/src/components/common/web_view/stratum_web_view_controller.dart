import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
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

  /// URL of the current page. On web, a cross-origin page reports the last
  /// URL the controller loaded.
  Future<Uri?> currentUrl() async {
    _ensureActive();
    return _platform.currentUrl();
  }

  /// Sends [data] to the page as a `message` event.
  ///
  /// Throws a [StateError] when `StratumWebView.allowedOrigins` is empty or
  /// the current page is not an allowed destination.
  Future<void> postMessage(String data) async {
    _ensureActive();
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
    await _platform.postMessage(data);
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

  /// Applies the settings of the `StratumWebView` that shows this controller.
  @internal
  void configure(StratumWebViewConfiguration configuration) {
    _ensureActive();
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
  void onMessage(StratumWebViewMessage message) {
    final callback = _configuration.onMessage;
    if (!_active ||
        allowedOrigins.isEmpty ||
        !_configuration.javaScriptEnabled ||
        callback == null) {
      return;
    }
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
