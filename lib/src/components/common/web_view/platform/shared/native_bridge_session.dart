import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Name of the JavaScript channel pages call on Windows and Linux
/// (`webview_all_adapter.dart`).
///
/// Android and macOS/iOS hard-code the same literal instead of reading this
/// constant — `StratumUiPlugin.kt`'s `BRIDGE`, `StratumUiPlugin.swift`'s
/// `bridgeName` — so a rename here must be mirrored there by hand.
const String bridgeChannelName = 'StratumBridge';

/// The most HTTP error candidates one session holds.
const int _maxCandidates = 16;

/// The longest a native `postMessage` waits for each dispatch script's
/// answer; no answer in time counts as a refused send (US-03 FR-02 E12,
/// E13).
const Duration dispatchScriptTimeout = Duration(seconds: 5);

/// Returns the dispatch script's answer from [evaluation], on the page shown
/// or through a reply proxy, or `null` when none comes within
/// [dispatchScriptTimeout] or the platform reports an error, such as
/// `FRAME_DESTROYED`; [NativeBridgeSession.confirmDelivery] turns `null`
/// into the unallowed-page [StateError] (US-03 FR-02 E12, E13).
///
/// The wait ends, not the script, so a page busy past the timeout may still
/// receive the message. Any other error propagates.
Future<Object?> dispatchScriptAnswer(Future<Object> evaluation) async {
  try {
    return await evaluation.timeout(dispatchScriptTimeout);
  } on TimeoutException {
    return null;
  } on PlatformException {
    return null;
    // WebKit, Windows, and Linux reject a `null` script result with an
    // ArgumentError, and Windows and Linux report a script that throws as
    // `null`, so this Error is the platform's error signal, not a bug.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return null;
  }
}

/// Length of a hex-encoded 16-byte secret.
const int _secretLength = 32;

/// Resource error codes that report a navigation a newer one replaced, per
/// platform (`s03_domain.md` invariant 10): `NSURLErrorCancelled` on WebKit,
/// and the index of `WebErrorStatusOperationCanceled`, which
/// `webview_all_windows` reports with type `unknown`, on WebView2. Linux
/// emits no cancelled load, and Android has no cancel code.
const Map<TargetPlatform, Set<int>> _cancelCodes = {
  TargetPlatform.iOS: {-999},
  TargetPlatform.macOS: {-999},
  TargetPlatform.windows: {14},
};

/// The only document id shape a `hello` or `bye` may carry: 16 bytes in
/// lowercase hex.
final RegExp _documentIdShape = RegExp(r'^[0-9a-f]{32}$');

/// Android's handle on the `JavaScriptReplyProxy` of the document that sent
/// a bridge message: the id the package's Kotlin code gives that proxy. A
/// script run through it runs only in that document (US-03 FR-04 E15).
extension type const BridgeReplyProxy(int id);

/// The sender a platform names for one bridge message: Android through its
/// web message listener, iOS and macOS through `WKScriptMessage.frameInfo`.
final class BridgeMessageSender {
  const new({required this.origin, required this.isMainFrame, this.replyProxy});

  /// The origin of the document that sent the message, or `null` when that
  /// origin is opaque.
  final Uri? origin;

  /// Whether the main frame sent the message.
  final bool isMainFrame;

  /// The reply proxy of the sending document on Android, which names one
  /// for every main-frame message; `null` on iOS and macOS.
  final BridgeReplyProxy? replyProxy;
}

/// A message [NativeBridgeSession.acceptMessage] accepted, with the sender
/// a reply targets.
typedef AcceptedMessage = ({
  StratumWebViewMessage message,
  PlatformMessageSender sender,
});

/// A document of the app's own HTML, named by the native bootstrap's
/// envelope (US-03 FR-05 E09).
final class NativeHtmlDocumentSender extends PlatformHtmlDocumentSender {
  const new({required this.loadNonce, required this.documentId});

  /// The inbound nonce of the load whose envelope carried the message.
  final String loadNonce;

  /// The id the sending document's `hello` carries, 32 lowercase hex
  /// characters.
  final String documentId;
}

/// Bridge and error rules shared by the native adapters.
///
/// Adapters report platform events here and ask whether a message may pass.
/// The class holds no platform types, so both adapters use it unchanged.
final class NativeBridgeSession {
  /// [namesSenders] is whether the platform names the sender of every page
  /// message (Android, iOS, macOS); then a message without one drops,
  /// instead of being judged by the tracked page (Windows, Linux).
  ///
  /// [bindsSendsToDocument] is whether the platform can run a send through
  /// the reply proxy of the document that sent a `hello` (Android only), a
  /// platform fact the caller passes instead of one this class infers from
  /// whether a `hello` happened to carry a reply proxy. With it set, a
  /// `hello` with no reply proxy proves nothing, and [scriptForMessage]
  /// never puts the token on the page shown.
  ///
  /// [platform] picks the row of the cancel-code table.
  new({
    required Set<Uri> Function() allowedOrigins,
    required TargetPlatform platform,
    bool namesSenders = false,
    bool bindsSendsToDocument = false,
  }) : _allowedOrigins = allowedOrigins,
       _platform = platform,
       _namesSenders = namesSenders,
       _bindsSendsToDocument = bindsSendsToDocument;

  static final Random _random = Random.secure();

  final Set<Uri> Function() _allowedOrigins;
  final TargetPlatform _platform;
  final bool _namesSenders;
  final bool _bindsSendsToDocument;
  Uri? _pageUrl;

  /// The native HTML proof (US-03 FR-04, `s03_domain.md` `## Lifecycle`).
  /// Only [willLoadHtml], [willLoadUrl], [willDispose], and a `hello` or
  /// `bye` envelope move it, never a page start.
  _Proof _proof = const _NoNonce();

  /// Whether the platform view lacks a feature the bridge needs, which
  /// keeps the bridge off (Android without `WEB_MESSAGE_LISTENER` or
  /// `JS_INJECTION_IN_FRAME_AND_WORLD`).
  bool _bridgeUnsupported = false;

  /// Call when the platform view lacks a feature the bridge needs: every
  /// page message drops, and every send throws (US-03 FR-01 E11, FR-02
  /// E11).
  void markBridgeUnsupported() => _bridgeUnsupported = true;

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

  /// Returns the message to deliver for [data] and its sender, or `null` to
  /// drop it.
  ///
  /// [sender] is the sender the platform names (Android, iOS, macOS): only
  /// main-frame messages pass, and an untagged message is judged by the
  /// sender's origin; where the platform names senders, a message without
  /// one drops. Without [sender] (Windows, Linux) an untagged message is
  /// judged by the origin of the tracked page at receipt.
  /// A message that carries [nativeBridgeEnvelopeTag] is judged only by its
  /// nonce and the proof, so a host-less page never passes as the app's
  /// HTML. No page start, URL, or arrival order decides HTML trust.
  AcceptedMessage? acceptMessage(String data, {BridgeMessageSender? sender}) {
    if (_bridgeUnsupported) return null;
    if (sender == null ? _namesSenders : !sender.isMainFrame) return null;
    if (data.startsWith(nativeBridgeEnvelopeTag)) {
      return _receiveEnvelope(
        data.substring(nativeBridgeEnvelopeTag.length),
        sender?.replyProxy,
      );
    }
    final origin = originOf(sender == null ? _pageUrl : sender.origin);
    if (!isAllowedOrigin(origin, _allowedOrigins())) return null;
    return (
      message: StratumWebViewMessage(data: data, origin: origin),
      sender: PlatformUrlPageSender(origin!),
    );
  }

  /// Applies an envelope body with the current nonce to the proof and
  /// returns the `message` it delivers and its sender; drops everything
  /// else, fail closed.
  ///
  /// - `hello` with a well-formed document id proves the nonce for that id
  ///   and records the [replyProxy] that came with it (FR-04 E15). On a
  ///   platform that [_bindsSendsToDocument], a `hello` with no reply proxy
  ///   proves nothing instead, so a send still throws unproven rather than
  ///   trusting the page shown with the token (B2).
  /// - `bye` revokes only a proof whose id it carries (FR-04 E10).
  /// - `message` passes only while proven, and only while its own document
  ///   id is 32 lowercase hex characters (FR-04 E05).
  AcceptedMessage? _receiveEnvelope(String body, BridgeReplyProxy? replyProxy) {
    final proof = _proof;
    if (proof is! _Load) return null;
    switch (_openEnvelope(body, proof.nonce)) {
      case ('hello', final id)
          when _documentIdShape.hasMatch(id) &&
              (!_bindsSendsToDocument || replyProxy != null):
        _proof = _Proven(proof.nonce, proof.token, id, replyProxy);
      case ('bye', final id) when proof is _Proven && id == proof.documentId:
        _proof = _Revoked(proof.nonce, proof.token);
      case ('message', final body) when proof is _Proven:
        final id = body.length > _secretLength && body[_secretLength] == ':'
            ? body.substring(0, _secretLength)
            : null;
        if (id == null || !_documentIdShape.hasMatch(id)) return null;
        return (
          message: StratumWebViewMessage(
            data: body.substring(_secretLength + 1),
          ),
          sender: NativeHtmlDocumentSender(
            loadNonce: proof.nonce,
            documentId: id,
          ),
        );
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

  /// Returns the dispatch script that delivers [data] to the page the view
  /// shows, which checks inside the page whether it may receive it.
  ///
  /// The script carries the outbound token only while the proof is proven
  /// by a `hello` with no reply proxy, on a platform that does not
  /// [_bindsSendsToDocument] (iOS, macOS, Windows, Linux); once revoked,
  /// with no current nonce, or on a platform that does, only allowed
  /// origins pass, and there [replyProxyScriptForMessage] then reaches the
  /// proving document (US-03 FR-02 E13).
  ///
  /// Throws a [StateError] when the platform view lacks a feature the
  /// bridge needs (US-03 FR-02 E11), and while the current HTML load has
  /// not proven its nonce, whatever page shows (US-03 FR-02 E04).
  ///
  /// With [targetOrigin], the page's own `location.origin` is compared
  /// against that one origin instead of the whole allowlist, and the
  /// script never carries the token, so the app's HTML never passes it
  /// (US-03 FR-02 E16, E17). [targetOrigin] is re-checked against
  /// [_allowedOrigins] here, right before the script is built, the way the
  /// web re-checks at post time: a caller awaits a platform round trip
  /// between its own allowlist check and this call, and the allowlist can
  /// change in that window (US-03 FR-02 E15, NFR-Sec02).
  String scriptForMessage(String data, {Uri? targetOrigin}) {
    if (_bridgeUnsupported) {
      throw StateError(
        'The bridge is disabled because the WebView lacks '
        'WEB_MESSAGE_LISTENER or JS_INJECTION_IN_FRAME_AND_WORLD support.',
      );
    }
    final proof = _proof;
    if (proof is _Minted) {
      throw StateError('The HTML page has not connected the bridge yet.');
    }
    if (targetOrigin != null) {
      if (!isAllowedOrigin(targetOrigin, _allowedOrigins())) {
        throw StateError(
          'targetOrigin $targetOrigin is not an allowed message destination.',
        );
      }
      return buildMessageDispatchScript(
        data,
        token: null,
        allowedOrigins: [targetOrigin],
      );
    }
    return buildMessageDispatchScript(
      data,
      token:
          !_bindsSendsToDocument && proof is _Proven && proof.replyProxy == null
          ? proof.token
          : null,
      allowedOrigins: _allowedOrigins(),
    );
  }

  /// The nonce of the current HTML load, or `null` while none is current.
  ///
  /// Read it right after [scriptForMessage] returns and pass it to
  /// [replyProxyScriptForMessage], so a reply-proxy run binds to the load
  /// the send began under, not to whichever load is current once the first
  /// script answers (B1).
  String? get currentLoadNonce {
    final proof = _proof;
    return proof is _Load ? proof.nonce : null;
  }

  /// Returns the token check of [data] and the reply proxy to run it
  /// through, for a send whose [scriptForMessage] script the page shown
  /// refused; `null` when no send goes further.
  ///
  /// Only a proof that a `hello` with a reply proxy holds right now, of the
  /// same load as [loadNonce], has one (Android): the platform runs that
  /// script only in the document that sent the `hello`, so neither its
  /// `bye` nor a page start decides delivery, and no other document ever
  /// gets the token (US-03 FR-02 E13, FR-04 E15). [loadNonce] is
  /// [currentLoadNonce] read when [scriptForMessage] built the first
  /// script; a later `loadHtml` that proves while that script is pending
  /// gets nothing, even though it is proven once this runs (B1). Ask after
  /// the first script answers, so a `bye` that arrived meanwhile stops the
  /// run.
  ({BridgeReplyProxy replyProxy, String script})? replyProxyScriptForMessage(
    String data, {
    required String? loadNonce,
  }) {
    final proof = _proof;
    if (proof is! _Proven || proof.nonce != loadNonce) return null;
    final replyProxy = proof.replyProxy;
    if (replyProxy == null) return null;
    return (
      replyProxy: replyProxy,
      script: buildMessageDispatchScript(
        data,
        token: proof.token,
        allowedOrigins: const <Uri>[],
      ),
    );
  }

  /// Returns the dispatch script that delivers [data] to [document], the
  /// document of the app's HTML that sent the message a reply targets, and
  /// the reply proxy to run it through on Android, `null` elsewhere.
  ///
  /// The reply reaches only the document whose message named it, while that
  /// document holds the proof; on Android only through its `hello`'s reply
  /// proxy (US-03 FR-05 E08, E09; R2).
  ///
  /// Throws a [StateError] when the platform view lacks a feature the
  /// bridge needs (US-03 FR-02 E11), and the gone-document [StateError]
  /// unless [document] is the one the current proof was proven by.
  ({String script, BridgeReplyProxy? replyProxy}) scriptForReply(
    String data,
    PlatformHtmlDocumentSender document,
  ) {
    if (_bridgeUnsupported) {
      throw StateError(
        'The bridge is disabled because the WebView lacks '
        'WEB_MESSAGE_LISTENER or JS_INJECTION_IN_FRAME_AND_WORLD support.',
      );
    }
    final proof = _proof;
    if (proof is! _Proven ||
        document is! NativeHtmlDocumentSender ||
        proof.nonce != document.loadNonce ||
        proof.documentId != document.documentId) {
      throw StateError('The HTML document that sent the message is gone.');
    }
    return (
      script: buildMessageDispatchScript(
        data,
        token: proof.token,
        documentId: document.documentId,
        allowedOrigins: const <Uri>[],
      ),
      replyProxy: proof.replyProxy,
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

  /// Maps a platform resource error, or returns `null` for a sub-frame error
  /// or a cancelled navigation, one that a newer navigation replaced while
  /// in flight (US-01 FR-02 E04).
  StratumWebViewError? networkError({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  }) {
    if (!(isForMainFrame ?? true)) return null;
    if (_cancelCodes[_platform]?.contains(code) ?? false) return null;
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

/// Proven by the `hello` of the document with [documentId], which came
/// with [replyProxy] on Android.
final class _Proven extends _Load {
  const new(super.nonce, super.token, this.documentId, this.replyProxy);

  final String documentId;
  final BridgeReplyProxy? replyProxy;
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
