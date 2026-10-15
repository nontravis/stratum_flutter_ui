import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/web_view/redacted_url.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/web_view_source.freezed.dart';

/// Content displayed by a `StratumWebView`.
@valueModel
sealed class StratumWebViewSource with _$StratumWebViewSource {
  /// A page loaded from [url].
  ///
  /// `StratumWebViewController.loadUrl` throws an [ArgumentError] unless
  /// [url] uses the `http` or `https` scheme; other schemes (for example
  /// `javascript:`) can run script in the app's own origin on web.
  const factory url(
    /// Address of the page.
    Uri url,
  ) = StratumWebViewUrlSource;

  /// A document rendered from an [html] string.
  const factory html(
    /// The HTML document.
    String html,
  ) = StratumWebViewHtmlSource;

  const new _();

  /// `StratumWebViewSource.url(...)` with the redacted address, or
  /// `StratumWebViewSource.html(n chars)` with the length, never the
  /// document itself (NFR-Sec06).
  @override
  String toString() => switch (this) {
    StratumWebViewUrlSource(:final url) =>
      'StratumWebViewSource.url(${redactedUrl(url)})',
    StratumWebViewHtmlSource(:final html) =>
      'StratumWebViewSource.html(${html.length} chars)',
  };
}
