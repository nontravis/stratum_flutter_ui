import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_frame_guard.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Name of the JavaScript channel that pages call on native platforms.
const String bridgeChannelName = 'StratumBridge';

/// Bridge and error rules shared by the native adapters.
///
/// Adapters report platform events here and ask whether a message may pass.
/// The class holds no platform types, so both adapters use it unchanged.
final class NativeBridgeSession {
  new({required Set<Uri> Function() allowedOrigins})
    : _allowedOrigins = allowedOrigins;

  final Set<Uri> Function() _allowedOrigins;
  final HtmlFrameGuard _guard = HtmlFrameGuard();
  Uri? _pageUrl;
  bool _lastLoadWasHtml = false;

  /// URL of the current top-level page, as last reported by the platform.
  Uri? get pageUrl => _pageUrl;

  /// Call right before the adapter loads a URL.
  void willLoadUrl() {
    _lastLoadWasHtml = false;
    _guard.expectNavigation();
  }

  /// Call right before the adapter loads an HTML string.
  void willLoadHtml() {
    _lastLoadWasHtml = true;
    _guard.expectOwnHtml();
  }

  /// Call right before the adapter reloads the current page.
  void willReload() {
    if (_lastLoadWasHtml && _guard.isShowingOwnHtml) _guard.expectOwnHtml();
  }

  /// Call when the platform reports that a main-frame page started loading.
  void didStartPage(String url) {
    _pageUrl = Uri.tryParse(url);
    _guard.didLoadFrame();
  }

  /// Call when the platform reports a URL change without a page load.
  void didChangeUrl(String? url) {
    if (url != null) _pageUrl = Uri.tryParse(url);
  }

  /// Returns the message to deliver for [data], or `null` to drop it.
  StratumWebViewMessage? acceptMessage(String data) {
    if (_guard.isShowingOwnHtml) return StratumWebViewMessage(data: data);
    if (!isAllowedOrigin(_pageUrl, _allowedOrigins())) return null;
    return StratumWebViewMessage(data: data, origin: originOf(_pageUrl));
  }

  /// Returns the script that delivers [data] to the current page.
  ///
  /// Throws a [StateError] when the current page may not receive messages.
  String scriptForMessage(String data) {
    final allowed =
        _guard.isShowingOwnHtml || isAllowedOrigin(_pageUrl, _allowedOrigins());
    if (!allowed) {
      throw StateError(
        'The current page ($_pageUrl) is not an allowed message destination.',
      );
    }
    return buildMessageDispatchScript(data);
  }

  /// Maps a platform resource error, or returns `null` for a sub-frame error.
  StratumWebViewError? networkError({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  }) {
    if (!(isForMainFrame ?? true)) return null;
    return StratumWebViewError(
      type: StratumWebViewErrorType.network,
      description: description,
      code: code,
      url: url == null ? null : Uri.tryParse(url),
    );
  }

  /// Maps a platform HTTP error, or returns `null` when it concerns a
  /// sub-resource instead of the current page.
  ///
  /// Android reports HTTP errors for images and scripts too, without a
  /// main-frame flag, so the request URL is compared with the page URL.
  StratumWebViewError? httpError({
    required int? statusCode,
    required Uri? requestUrl,
  }) {
    final pageUrl = _pageUrl;
    if (requestUrl == null || pageUrl == null) return null;
    if (requestUrl.removeFragment() != pageUrl.removeFragment()) return null;
    return StratumWebViewError(
      type: StratumWebViewErrorType.http,
      description: statusCode == null ? 'HTTP error' : 'HTTP error $statusCode',
      code: statusCode,
      url: requestUrl,
    );
  }
}
