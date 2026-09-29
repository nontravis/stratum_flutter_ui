import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Receives events from a [PlatformStratumWebView].
///
/// `StratumWebViewController` implements this contract.
abstract interface class PlatformStratumWebViewListener {
  /// Origins allowed to use the bridge, read at event time.
  Set<Uri> get allowedOrigins;

  /// Delivers a message that passed the platform's origin rules.
  void onMessage(StratumWebViewMessage message);

  /// Decides whether a main-frame navigation to [url] may proceed.
  StratumNavigationDecision onNavigationRequest(Uri url);

  /// Reports that a page started loading.
  void onPageStarted(Uri? url);

  /// Reports that a page finished loading.
  void onPageFinished(Uri? url);

  /// Reports a main-frame loading failure.
  void onError(StratumWebViewError error);
}

/// One web view on the current platform.
///
/// A new instance starts with JavaScript enabled and no content.
abstract interface class PlatformStratumWebView {
  /// Enables or disables JavaScript for later loads.
  Future<void> setJavaScriptEnabled(bool enabled);

  /// Loads [source] and records it in the navigation history.
  Future<void> load(StratumWebViewSource source);

  /// Reloads the current page.
  Future<void> reload();

  /// Goes back one history entry, if any.
  Future<void> goBack();

  /// Goes forward one history entry, if any.
  Future<void> goForward();

  /// Whether [goBack] has an entry.
  Future<bool> canGoBack();

  /// Whether [goForward] has an entry.
  Future<bool> canGoForward();

  /// Best known URL of the current page.
  Future<Uri?> currentUrl();

  /// Sends [data] to the page as a `message` event.
  ///
  /// Throws a [StateError] when the current page may not receive messages.
  Future<void> postMessage(String data);

  /// Builds the widget that displays the page.
  Widget buildView(BuildContext context);

  /// Releases platform resources and stops event delivery.
  void dispose();
}

/// Creates the [PlatformStratumWebView] for the current platform.
typedef PlatformStratumWebViewFactory = PlatformStratumWebView Function(
  PlatformStratumWebViewListener listener,
);
