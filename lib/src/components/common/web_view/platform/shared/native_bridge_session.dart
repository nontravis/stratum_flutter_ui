import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_frame_guard.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Name of the JavaScript channel that pages call on native platforms.
const String bridgeChannelName = 'StratumBridge';

/// The most HTTP error candidates one session holds.
const int _maxCandidates = 16;

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

  /// Whether a main-frame page start has had neither a page finish nor a
  /// controller action since.
  bool _pageStartOpen = false;

  /// HTTP errors held until a main-frame page start names their URL, keyed
  /// by [_comparable] URL, oldest first.
  final Map<Uri, StratumWebViewError> _candidates = {};

  /// Call right before the adapter loads a URL.
  void willLoadUrl() {
    _beginNavigation();
    _guard.expectNavigation();
  }

  /// Call right before the adapter's own `goBack` or `goForward`.
  void willNavigate() => _beginNavigation();

  /// Call when the app allows a main-frame navigation request of the
  /// platform. Every candidate is discarded, but the open page start stays:
  /// WebKit asks about a server redirect after the page start, and that
  /// load's own finish still pairs with it.
  void didAllowNavigation() => _candidates.clear();

  /// Call right before the adapter loads an HTML string.
  void willLoadHtml() {
    _beginNavigation();
    _guard.expectOwnHtml();
  }

  /// Call right before the adapter reloads the current page.
  void willReload() {
    _beginNavigation();
    // The guard only reports own HTML after an HTML load or reload.
    if (_guard.isShowingOwnHtml) _guard.expectOwnHtml();
  }

  /// Call right before the adapter is disposed; every candidate is
  /// discarded.
  void willDispose() => _candidates.clear();

  /// A controller action begins a navigation: every candidate is discarded,
  /// and the open page start closes because the load it belongs to is
  /// replaced, so a late finish of that load is unpaired and dropped.
  void _beginNavigation() {
    _candidates.clear();
    _pageStartOpen = false;
  }

  /// Call when the platform reports that a main-frame page started loading.
  ///
  /// Returns the candidate held for this page, which the adapter reports
  /// right after the page start, or `null`. Every other candidate is
  /// discarded.
  StratumWebViewError? didStartPage(String url) {
    final pageUrl = Uri.tryParse(url);
    _pageUrl = pageUrl;
    _pageUrlUnknown = false;
    _pageStartOpen = true;
    // While our HTML is still loading, a page with a real origin is the late
    // start of the load it superseded, never our HTML (which reports a
    // host-less URL). Letting it count would use up the HTML's first-load
    // slot, and our HTML's own start would then read as navigating away.
    if (!_guard.isAwaitingLoad || originOf(pageUrl) == null) {
      _guard.didLoadFrame();
    }
    final started = _comparable(pageUrl);
    final candidate = started == null ? null : _candidates[started];
    _candidates.clear();
    return candidate;
  }

  /// Call when the platform reports that a main-frame page finished loading.
  ///
  /// Returns whether the adapter reports the finish: only a finish that
  /// pairs with an open page start does. Android reports a finish for a
  /// redirect target before that page starts, and a load that a controller
  /// action replaced may still report its finish; neither releases anything.
  bool didFinishPage() {
    if (!_pageStartOpen) return false;
    _pageStartOpen = false;
    return true;
  }

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

  /// Maps a platform HTTP error, or returns `null` when it is held as a
  /// candidate.
  ///
  /// Android reports the HTTP error of a main-frame response before its
  /// page starts, on a load, a history move, and a reload alike, and
  /// `webview_flutter_android` passes no main-frame flag on it. So an error
  /// whose request URL is not the page with an open start is held as the
  /// candidate of its URL, the newest replacing an older one, and
  /// [didStartPage] returns the candidate its page names: every platform
  /// then reports page start, error, page finish, whoever started the
  /// navigation. A sub-resource error stays a candidate until a navigation
  /// begin or the next page start discards it. WebKit (iOS, macOS) reports
  /// HTTP errors only for navigation responses and never supplies a request
  /// URL, so a `null` [requestUrl] is treated as the current page instead.
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
    final url = _comparable(requestUrl)!;
    if (_pageStartOpen && url == _comparable(_pageUrl)) return error;
    _candidates
      ..remove(url)
      ..[url] = error;
    if (_candidates.length > _maxCandidates) {
      _candidates.remove(_candidates.keys.first);
    }
    return null;
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
