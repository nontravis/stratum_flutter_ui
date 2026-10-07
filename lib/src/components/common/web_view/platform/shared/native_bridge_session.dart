import 'dart:math';

import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Name of the JavaScript channel that pages call on native platforms.
const String bridgeChannelName = 'StratumBridge';

/// The most HTTP error candidates one session holds.
const int _maxCandidates = 16;

/// Length of a hex-encoded 16-byte secret.
const int _secretLength = 32;

/// Bridge and error rules shared by the native adapters.
///
/// Adapters report platform events here and ask whether a message may pass.
/// The class holds no platform types, so both adapters use it unchanged.
final class NativeBridgeSession {
  new({required Set<Uri> Function() allowedOrigins})
    : _allowedOrigins = allowedOrigins;

  static final Random _random = Random.secure();

  final Set<Uri> Function() _allowedOrigins;
  Uri? _pageUrl;

  /// The inbound nonce of the current `loadHtml`, or `null` when no HTML
  /// load is current (US-03 FR-04).
  String? _inboundNonce;

  /// The outbound token minted beside [_inboundNonce].
  String? _outboundToken;

  /// Whether a `hello` envelope proved [_inboundNonce]. Only [willLoadHtml],
  /// [willLoadUrl], and [willDispose] clear it, never a page start.
  bool _proven = false;

  /// Whether a main-frame page start has had neither a page finish nor a
  /// new page start since, so a finish still pairs with it.
  bool _pageStartOpen = false;

  /// Whether a tracked-page HTTP error still reports at once: ended by
  /// every controller action, kept by a navigation the app allows.
  bool _atOnceErrorOpen = false;

  /// HTTP errors held until a main-frame page start names their URL, keyed
  /// by [_comparable] URL, oldest first.
  final Map<Uri, StratumWebViewError> _candidates = {};

  /// Call right before the adapter loads a URL: revokes the nonce.
  void willLoadUrl() {
    _beginNavigation();
    _revokeNonce();
  }

  /// Call right before the adapter's own `goBack` or `goForward`.
  void willNavigate() => _beginNavigation();

  /// Call when the app allows a main-frame navigation request of the
  /// platform. Every candidate is discarded, but the open page start stays:
  /// WebKit asks about a server redirect after the page start, and that
  /// load's own finish still pairs with it.
  void didAllowNavigation() => _candidates.clear();

  /// Call right before the adapter loads [html]; returns the HTML to load.
  ///
  /// Mints a fresh inbound nonce and an independent outbound token, 16
  /// bytes each from `Random.secure()`, and places the native bootstrap
  /// that carries them in the returned HTML, the only place they travel.
  /// The nonce of an earlier load stops counting at once.
  String willLoadHtml(String html) {
    _beginNavigation();
    final nonce = _mintSecret();
    final token = _mintSecret();
    _inboundNonce = nonce;
    _outboundToken = token;
    _proven = false;
    return injectNativeBridgeBootstrap(html, nonce: nonce, token: token);
  }

  /// Call right before the adapter reloads the current page.
  ///
  /// The platform parses the same HTML string again, so the nonce stays.
  void willReload() => _beginNavigation();

  /// Call right before the adapter is disposed; every candidate is
  /// discarded and the nonce is revoked.
  void willDispose() {
    _candidates.clear();
    _revokeNonce();
  }

  void _revokeNonce() {
    _inboundNonce = null;
    _outboundToken = null;
    _proven = false;
  }

  String _mintSecret() => [
    for (var i = 0; i < _secretLength ~/ 2; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  /// A controller action begins a navigation: every candidate is discarded,
  /// and the at-once error eligibility of the tracked page ends, because
  /// the HTTP error Android reports for the new load belongs to the page it
  /// starts. The open page start stays: a history move that starts no new
  /// document keeps the loading page's finish, and a late finish of a
  /// replaced load still pairs with the start it left open.
  void _beginNavigation() {
    _candidates.clear();
    _atOnceErrorOpen = false;
  }

  /// Call when the platform reports that a main-frame page started loading.
  ///
  /// Returns the candidate held for this page, which the adapter reports
  /// right after the page start, or `null`. Every other candidate is
  /// discarded.
  StratumWebViewError? didStartPage(String url) {
    final pageUrl = Uri.tryParse(url);
    _pageUrl = pageUrl;
    _pageStartOpen = true;
    _atOnceErrorOpen = true;
    final started = _comparable(pageUrl);
    final candidate = started == null ? null : _candidates[started];
    _candidates.clear();
    return candidate;
  }

  /// Call when the platform reports that a main-frame page finished loading.
  ///
  /// Returns whether the adapter reports the finish: only a finish that
  /// pairs with an open page start does, and only while the pairing is open
  /// does a tracked-page HTTP error report at once. Android reports a
  /// finish for a redirect target before that page starts; it releases
  /// nothing.
  bool didFinishPage() {
    if (!_pageStartOpen) return false;
    _pageStartOpen = false;
    _atOnceErrorOpen = false;
    return true;
  }

  /// Call when the platform reports a URL change without a page load.
  void didChangeUrl(String? url) {
    _pageUrl = url == null ? null : Uri.tryParse(url);
  }

  /// Returns the message to deliver for [data], or `null` to drop it.
  ///
  /// A message that carries [nativeBridgeEnvelopeTag] is judged only by its
  /// nonce; any other message only by the origin of the tracked page, so a
  /// host-less page never passes as the app's HTML. No page start, URL, or
  /// arrival order decides HTML trust.
  StratumWebViewMessage? acceptMessage(String data) {
    if (data.startsWith(nativeBridgeEnvelopeTag)) {
      return _openEnvelope(data.substring(nativeBridgeEnvelopeTag.length));
    }
    if (!isAllowedOrigin(_pageUrl, _allowedOrigins())) return null;
    return StratumWebViewMessage(data: data, origin: originOf(_pageUrl));
  }

  /// Parses `<nonce>:<kind>:<data>` totally and fails closed: a missing
  /// field, an unknown kind, a `hello` that carries data, or a nonce other
  /// than the current one drops the envelope with no side effect.
  StratumWebViewMessage? _openEnvelope(String body) {
    final nonce = _inboundNonce;
    if (nonce == null || body.length <= _secretLength) return null;
    if (body[_secretLength] != ':') return null;
    if (!_sameSecret(body.substring(0, _secretLength), nonce)) return null;
    final rest = body.substring(_secretLength + 1);
    final kindEnd = rest.indexOf(':');
    if (kindEnd < 0) return null;
    final payload = rest.substring(kindEnd + 1);
    switch (rest.substring(0, kindEnd)) {
      case 'hello' when payload.isEmpty:
        _proven = true;
        return null;
      case 'message':
        return StratumWebViewMessage(data: payload);
      default:
        return null;
    }
  }

  /// Compares two secrets of equal length in time that does not depend on
  /// where they differ.
  static bool _sameSecret(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  /// Returns the one dispatch script that delivers [data] to the page the
  /// view shows, which checks inside the page whether it may receive it.
  ///
  /// Throws a [StateError] while the current HTML load has not proven its
  /// nonce, whatever page shows (US-03 FR-02 E04).
  String scriptForMessage(String data) {
    if (_inboundNonce != null && !_proven) {
      throw StateError('The HTML page has not connected the bridge yet.');
    }
    return buildMessageDispatchScript(
      data,
      token: _proven ? _outboundToken : null,
      allowedOrigins: _allowedOrigins(),
    );
  }

  /// Turns the dispatch script's [result] into the send's outcome: `true`
  /// means the page received the message; anything else throws a
  /// [StateError] that names no origin, because the page reports only a
  /// boolean (US-03 FR-02 E03).
  void confirmDelivery(Object? result) {
    if (result == true) return;
    throw StateError('The current page is not an allowed message destination.');
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
  /// whose request URL is not the tracked page with at-once eligibility
  /// open is held as the candidate of its URL, the newest replacing an
  /// older one, and [didStartPage] returns the candidate its page names:
  /// every platform then reports page start, error, page finish, whoever
  /// started the navigation. A controller action ends the at-once
  /// eligibility only, so its load's error waits for its own start while
  /// the replaced load's finish still pairs with the start it left open. A
  /// sub-resource error stays a candidate until a navigation begin or the
  /// next page start discards it. WebKit (iOS, macOS) reports HTTP errors
  /// only for navigation responses and never supplies a request URL, so a
  /// `null` [requestUrl] is treated as the current page instead.
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
    if (_atOnceErrorOpen && url == _comparable(_pageUrl)) return error;
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
