import 'dart:math';

import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Name of the JavaScript channel that pages call on native platforms.
const String bridgeChannelName = 'StratumBridge';

/// The most HTTP error candidates one session holds.
const int _maxCandidates = 16;

/// The longest a native `postMessage` waits for the dispatch script's
/// answer; no answer in time counts as a refused send (US-03 FR-02 E12).
const Duration dispatchScriptTimeout = Duration(seconds: 5);

/// Length of a hex-encoded 16-byte secret.
const int _secretLength = 32;

/// The only document id shape a `hello` or `bye` may carry: 16 bytes in
/// lowercase hex.
final RegExp _documentIdShape = RegExp(r'^[0-9a-f]{32}$');

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

  /// The native HTML proof (US-03 FR-04, `s03_domain.md` `## Lifecycle`).
  /// Only [willLoadHtml], [willLoadUrl], [willDispose], and a `hello` or
  /// `bye` envelope move it, never a page start.
  _Proof _proof = const _NoNonce();

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
    _proof = const _NoNonce();
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
  /// The nonce of an earlier load stops counting at once, and sends throw
  /// until a `hello` proves the new one.
  String willLoadHtml(String html) {
    _beginNavigation();
    final minted = _Minted(_mintSecret(), _mintSecret());
    _proof = minted;
    return injectNativeBridgeBootstrap(
      html,
      nonce: minted.nonce,
      token: minted.token,
    );
  }

  /// Call right before the adapter reloads the current page.
  ///
  /// The platform parses the same HTML string again, so the nonce stays;
  /// the old document's `bye` and the new document's `hello` move the proof.
  void willReload() => _beginNavigation();

  /// Call right before the adapter is disposed; every candidate is
  /// discarded and the nonce is revoked.
  void willDispose() {
    _candidates.clear();
    _proof = const _NoNonce();
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
  /// nonce and the proof; any other message only by the origin of the
  /// tracked page, so a host-less page never passes as the app's HTML. No
  /// page start, URL, or arrival order decides HTML trust.
  StratumWebViewMessage? acceptMessage(String data) {
    if (data.startsWith(nativeBridgeEnvelopeTag)) {
      return _receiveEnvelope(data.substring(nativeBridgeEnvelopeTag.length));
    }
    if (!isAllowedOrigin(_pageUrl, _allowedOrigins())) return null;
    return StratumWebViewMessage(data: data, origin: originOf(_pageUrl));
  }

  /// Applies an envelope body with the current nonce to the proof and
  /// returns the `message` it delivers; drops everything else, fail closed.
  ///
  /// - `hello` with a well-formed document id proves the nonce for that id.
  /// - `bye` revokes only a proof whose id it carries (FR-04 E10).
  /// - `message` passes only while proven.
  StratumWebViewMessage? _receiveEnvelope(String body) {
    final proof = _proof;
    if (proof is! _Load) return null;
    switch (_openEnvelope(body, proof.nonce)) {
      case ('hello', final id) when _documentIdShape.hasMatch(id):
        _proof = _Proven(proof.nonce, proof.token, id);
      case ('bye', final id) when proof is _Proven && id == proof.documentId:
        _proof = _Revoked(proof.nonce, proof.token);
      case ('message', final data) when proof is _Proven:
        return StratumWebViewMessage(data: data);
    }
    return null;
  }

  /// Splits `<nonce>:<kind>:<data>` into kind and data, or returns `null`
  /// when a field is missing or the envelope does not carry [nonce].
  static (String, String)? _openEnvelope(String body, String nonce) {
    if (body.length <= _secretLength || body[_secretLength] != ':') {
      return null;
    }
    if (!_sameSecret(body.substring(0, _secretLength), nonce)) return null;
    final rest = body.substring(_secretLength + 1);
    final kindEnd = rest.indexOf(':');
    if (kindEnd < 0) return null;
    return (rest.substring(0, kindEnd), rest.substring(kindEnd + 1));
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
  /// The script carries the outbound token only while the proof is proven;
  /// once revoked, or with no current nonce, only allowed origins pass.
  ///
  /// Throws a [StateError] while the current HTML load has not proven its
  /// nonce, whatever page shows (US-03 FR-02 E04).
  String scriptForMessage(String data) {
    final proof = _proof;
    if (proof is _Minted) {
      throw StateError('The HTML page has not connected the bridge yet.');
    }
    return buildMessageDispatchScript(
      data,
      token: proof is _Proven ? proof.token : null,
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

/// Where the native HTML proof stands (`s03_domain.md` `## Lifecycle`).
sealed class _Proof {
  const new();
}

/// No `loadHtml` is current, so every tagged message is dropped.
final class _NoNonce extends _Proof {
  const new();
}

/// A proof state of the current `loadHtml`, holding its two secrets.
sealed class _Load extends _Proof {
  const new(this.nonce, this.token);

  final String nonce;
  final String token;
}

/// Minted by `loadHtml`: no `hello` has proven [nonce] yet.
final class _Minted extends _Load {
  const new(super.nonce, super.token);
}

/// Proven by the `hello` of the document with [documentId].
final class _Proven extends _Load {
  const new(super.nonce, super.token, this.documentId);

  final String documentId;
}

/// Revoked by the proving document's `bye`: [token] is withheld until a
/// `hello` proves [nonce] again.
final class _Revoked extends _Load {
  const new(super.nonce, super.token);
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
