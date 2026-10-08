import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Who sent one message a platform delivered (US-03 FR-05); only the
/// library reads it, and `StratumWebViewMessage` carries no sender field.
sealed class PlatformMessageSender {
  const new();
}

/// A URL page, bound by its [origin] only (US-03 FR-05 E04).
final class PlatformUrlPageSender extends PlatformMessageSender {
  const new(this.origin);

  /// The sender's origin, as `originOf` returns it.
  final Uri origin;
}

/// One document of the app's own HTML; each platform extends this with
/// the handle only it reads (US-03 FR-05 E06, E08).
abstract base class PlatformHtmlDocumentSender extends PlatformMessageSender {
  const new();
}

/// Receives events from a [PlatformStratumWebView].
///
/// `StratumWebViewController` implements this contract.
abstract interface class PlatformStratumWebViewListener {
  /// Origins allowed to use the bridge, read at event time.
  Set<Uri> get allowedOrigins;

  /// Delivers a message that passed the platform's origin rules, with the
  /// [sender] a reply targets.
  void onMessage(StratumWebViewMessage message, PlatformMessageSender sender);

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

  /// Sends [data] to the page as a `message` event. With [targetOrigin], an
  /// origin already on the allowlist, only a page shown at delivery with
  /// that origin receives it; the app's HTML never does (US-03 FR-02 E14 to
  /// E18).
  ///
  /// Throws a [StateError] when the current page may not receive messages.
  Future<void> postMessage(String data, {Uri? targetOrigin});

  /// Sends [data] as a `message` event to [document], the document of the
  /// app's HTML that sent a message this view delivered, and to no other
  /// document (US-03 FR-05).
  ///
  /// Throws a [StateError] when that document is gone, or when the page
  /// refuses.
  Future<void> replyToDocument(
    PlatformHtmlDocumentSender document,
    String data,
  );

  /// Builds the widget that displays the page.
  Widget buildView(BuildContext context);

  /// Releases platform resources and stops event delivery.
  void dispose();
}

/// Creates the [PlatformStratumWebView] for the current platform.
typedef PlatformStratumWebViewFactory = PlatformStratumWebView Function(
  PlatformStratumWebViewListener listener,
);
