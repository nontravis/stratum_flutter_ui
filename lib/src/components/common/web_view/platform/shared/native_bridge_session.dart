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
  bool _pageUrlUnknown = false;
  Uri? _targetUrl;
  StratumWebViewError? _heldError;

  /// Call right before the adapter loads a URL.
  void willLoadUrl() {
    // A held error belongs to the load this one replaces.
    _heldError = null;
    _guard.expectNavigation();
  }

  /// Call right before the main frame navigates to [url]: when the adapter
  /// loads it, or when the platform asks to navigate there and the app
  /// allows it.
  ///
  /// Android reports the HTTP error of a main-frame response before its page
  /// starts, and names the redirect target after a server redirect, so
  /// [httpError] matches [url] as well until the page of [url] starts.
  void willNavigate(Uri url) {
    _targetUrl = url;
  }

  /// Call right before the adapter loads an HTML string.
  void willLoadHtml() {
    // The HTML replaces any URL load in flight, and has no HTTP response.
    _targetUrl = null;
    _heldError = null;
    _guard.expectOwnHtml();
  }

  /// Call right before the adapter reloads the current page.
  void willReload() {
    // A reload loads the current page again, so its early HTTP error is
    // held like the error of any other navigation target.
    _targetUrl = _pageUrl;
    _heldError = null;
    // The guard only reports own HTML after an HTML load or reload.
    if (_guard.isShowingOwnHtml) _guard.expectOwnHtml();
  }

  /// Call right before the adapter is disposed; a held error is discarded.
  void willDispose() {
    _heldError = null;
  }

  /// Call when the platform reports that a main-frame page started loading.
  ///
  /// Returns the HTTP error held for this page, which the adapter reports
  /// right after the page start, or `null`.
  StratumWebViewError? didStartPage(String url) {
    final pageUrl = Uri.tryParse(url);
    _pageUrl = pageUrl;
    _pageUrlUnknown = false;
    // While our HTML is still loading, a page with a real origin is the late
    // start of the load it superseded, never our HTML (which reports a
    // host-less URL). Letting it count would use up the HTML's first-load
    // slot, and our HTML's own start would then read as navigating away.
    if (!_guard.isAwaitingLoad || originOf(pageUrl) == null) {
      _guard.didLoadFrame();
    }
    final started = _comparable(pageUrl);
    if (started == null) return null;
    // The late start of a replaced load leaves the newer target in place.
    if (started == _comparable(_targetUrl)) _targetUrl = null;
    if (started != _comparable(_heldError?.url)) return null;
    return _takeHeldError();
  }

  /// Call when the platform reports that a main-frame page finished loading.
  ///
  /// Returns an HTTP error still held because its page never started, which
  /// the adapter reports right before the page finish, or `null`.
  StratumWebViewError? didFinishPage() => _takeHeldError();

  /// Call when the platform reports a URL change without a page load.
  ///
  /// A `null` URL means the platform does not know the page, not that the
  /// page is our HTML, so it denies HTML trust until the next [didStartPage].
  void didChangeUrl(String? url) {
    _pageUrl = url == null ? null : Uri.tryParse(url);
    _pageUrlUnknown = url == null;
  }

  /// Whether the tracked page is still the controller's own HTML.
  ///
  /// The guard alone is not enough: between [willLoadHtml] and the HTML's
  /// first [didStartPage], the previous page is still live and the guard
  /// already reports `awaitingLoad`. A page with a real origin is never our
  /// HTML, so this also requires [_pageUrl] to be host-less (the adapters
  /// load HTML without a base URL, so our HTML reports `about:blank`).
  bool get _isTrustedHtml =>
      _guard.isShowingOwnHtml && !_pageUrlUnknown && originOf(_pageUrl) == null;

  /// Returns the message to deliver for [data], or `null` to drop it.
  StratumWebViewMessage? acceptMessage(String data) {
    if (_isTrustedHtml) return StratumWebViewMessage(data: data);
    if (!isAllowedOrigin(_pageUrl, _allowedOrigins())) return null;
    return StratumWebViewMessage(data: data, origin: originOf(_pageUrl));
  }

  /// Returns the script that delivers [data] to the current page.
  ///
  /// Throws a [StateError] when the current page may not receive messages.
  String scriptForMessage(String data) {
    final allowed =
        _isTrustedHtml || isAllowedOrigin(_pageUrl, _allowedOrigins());
    if (!allowed) {
      throw StateError(
        'The current page (${originOf(_pageUrl)}) is not an allowed '
        'message destination.',
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
  /// sub-resource instead of the current page, or is held for later.
  ///
  /// Android reports HTTP errors for images and scripts too, without a
  /// main-frame flag, so a non-null request URL is compared with the page
  /// URL and with the navigation target of [willNavigate]. An error on the
  /// target arrives before its page starts, so it is held and returned by
  /// [didStartPage] or [didFinishPage]: every platform then reports page
  /// start, error, page finish. WebKit (iOS, macOS) reports HTTP errors only
  /// for navigation responses and never supplies a request URL, so a `null`
  /// [requestUrl] is treated as the current page instead of being dropped.
  StratumWebViewError? httpError({
    required int? statusCode,
    required Uri? requestUrl,
  }) {
    final error = StratumWebViewError(
      type: StratumWebViewErrorType.http,
      description: statusCode == null ? 'HTTP error' : 'HTTP error $statusCode',
      code: statusCode,
      url: requestUrl ?? _pageUrl,
    );
    if (requestUrl == null) return error;
    final url = _comparable(requestUrl);
    if (url == _comparable(_targetUrl)) {
      _heldError = error;
      return null;
    }
    return url == _comparable(_pageUrl) ? error : null;
  }

  StratumWebViewError? _takeHeldError() {
    final held = _heldError;
    _heldError = null;
    return held;
  }
}

/// [url] in the form a platform reports it: no fragment, and `/` for the
/// empty path of a URL with an authority (Android reports a load of
/// `https://example.com` as `https://example.com/`).
Uri? _comparable(Uri? url) {
  if (url == null) return null;
  final bare = url.removeFragment();
  return bare.hasAuthority && bare.path.isEmpty
      ? bare.replace(path: '/')
      : bare;
}
