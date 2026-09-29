import 'package:flutter/foundation.dart';

/// Content displayed by a `StratumWebView`.
@immutable
sealed class StratumWebViewSource {
  const new();

  /// A page loaded from [url].
  ///
  /// `StratumWebViewController.loadUrl` throws an [ArgumentError] unless
  /// [url] uses the `http` or `https` scheme; other schemes (for example
  /// `javascript:`) can run script in the app's own origin on web.
  const factory url(Uri url) = StratumWebViewUrlSource;

  /// A document rendered from an [html] string.
  const factory html(String html) = StratumWebViewHtmlSource;
}

/// A [StratumWebViewSource] that loads the page at [url].
final class StratumWebViewUrlSource extends StratumWebViewSource {
  const new(this.url);

  /// Address of the page.
  final Uri url;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewUrlSource && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'StratumWebViewSource.url($url)';
}

/// A [StratumWebViewSource] that renders an [html] string.
final class StratumWebViewHtmlSource extends StratumWebViewSource {
  const new(this.html);

  /// The HTML document.
  final String html;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewHtmlSource && other.html == html;

  @override
  int get hashCode => html.hashCode;

  @override
  String toString() => 'StratumWebViewSource.html(${html.length} chars)';
}

/// A message that the page sent through the bridge.
@immutable
final class StratumWebViewMessage {
  const new({required this.data, this.origin});

  /// Message payload. Encode structured data yourself, for example as JSON.
  final String data;

  /// Origin of the page that sent the message, or `null` for HTML content
  /// loaded from a [StratumWebViewHtmlSource].
  final Uri? origin;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewMessage &&
      other.data == data &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(data, origin);

  @override
  String toString() => 'StratumWebViewMessage(data: $data, origin: $origin)';
}

/// Whether a web view may continue a navigation.
enum StratumNavigationDecision {
  /// Continue loading the page.
  navigate,

  /// Stop the navigation.
  prevent,
}

/// Kind of failure reported through `StratumWebView.onError`.
enum StratumWebViewErrorType {
  /// The page could not be reached: DNS, TLS, connection, or timeout.
  network,

  /// The server answered the page request with an HTTP error status.
  http,
}

/// A main-frame loading failure on a native platform.
@immutable
final class StratumWebViewError {
  const new({
    required this.type,
    required this.description,
    this.code,
    this.url,
  });

  /// Kind of failure.
  final StratumWebViewErrorType type;

  /// Human-readable description from the platform.
  final String description;

  /// Platform error code for [StratumWebViewErrorType.network], HTTP status
  /// for [StratumWebViewErrorType.http].
  final int? code;

  /// Address that failed to load, when the platform reports it.
  final Uri? url;

  @override
  bool operator ==(Object other) =>
      other is StratumWebViewError &&
      other.type == type &&
      other.description == description &&
      other.code == code &&
      other.url == url;

  @override
  int get hashCode => Object.hash(type, description, code, url);

  @override
  String toString() =>
      'StratumWebViewError(${type.name}, $code, $description, $url)';
}
