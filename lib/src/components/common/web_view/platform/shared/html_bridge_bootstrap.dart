/// Prefix of every native bridge envelope: the version tag.
///
/// An envelope reads `<tag><inbound nonce>:<kind>:<data>`, where the nonce is
/// 32 lowercase hex characters and the kind is `hello` (with empty data) or
/// `message`. A page message that starts with this tag is judged only by its
/// nonce (US-03 FR-04, `event_bridge_messages.md` `## Native envelope`).
const String nativeBridgeEnvelopeTag = 'stratum-bridge-envelope:1:';

/// Name of the window property where the native bootstrap keeps the
/// outbound token; the dispatch script compares it with `===` against the
/// literal it carries.
const String nativeBridgeTokenProperty = '__stratumBridgeToken';

/// Builds the bootstrap script injected into HTML content rendered on web.
///
/// The web implementation renders HTML in a `srcdoc` iframe with an opaque
/// (`"null"`) origin, so a plain `window.postMessage` bridge cannot tell our
/// HTML apart from a page reached by navigating away from it: both report
/// the same origin. This bootstrap closes that gap with a private channel.
/// It creates a `MessageChannel`, keeps `port1`, exposes
/// `window.StratumBridge.postMessage` bound to it, forwards messages
/// received on `port1` as `window` `message` events (matching the page-side
/// contract used on every platform), and hands `port2` to the parent window
/// together with a handshake string that carries [nonce]. The parent adopts
/// `port2` only when the handshake's nonce matches the one it generated for
/// this render, so a page reached by navigation — which cannot know that
/// nonce — never obtains a working bridge, even if it forges the
/// `stratum-bridge-handshake:` prefix.
///
/// Returns [html] with the script placed by [placeBridgeBootstrap].
String injectBridgeBootstrap(String html, String nonce) {
  // Each piece below ends with an explicit `\n`. A blank line between
  // statements is valid, whitespace-insensitive JavaScript, and it gives
  // every adjacent string literal a real separator instead of an implicit
  // (and lint-flagged) concatenation boundary.
  final script =
      '<script>(function(){var c=new MessageChannel();\n'
      'var p=c.port1;\n'
      'window.StratumBridge={postMessage:function(d){\n'
      'p.postMessage(String(d));}};\n'
      'p.onmessage=function(e){window.dispatchEvent(\n'
      "new MessageEvent('message',\n"
      '{data:e.data}));};\n'
      "parent.postMessage('stratum-bridge-handshake:$nonce',\n"
      "'*',[c.port2]);\n"
      '})();</script>';
  return placeBridgeBootstrap(html, script);
}

/// Builds the bootstrap script injected into HTML that a native adapter
/// loads (US-03 FR-04).
///
/// The script captures the platform's `StratumBridge` object in a closure,
/// keeps [token] in the [nativeBridgeTokenProperty] window property, replaces
/// `window.StratumBridge` with a frozen wrapper that sends every message as
/// an envelope carrying [nonce] (see [nativeBridgeEnvelopeTag]), and posts a
/// `hello` envelope that proves [nonce] to the app. The envelope never
/// carries [token]. When the platform object is missing, the script does
/// nothing, and the bridge stays closed.
///
/// Returns [html] with the script placed by [placeBridgeBootstrap].
String injectNativeBridgeBootstrap(
  String html, {
  required String nonce,
  required String token,
}) {
  final script =
      "<script>(function(){'use strict';\n"
      'var b=window.StratumBridge;\n'
      "if(!b||typeof b.postMessage!=='function')return;\n"
      'var p=b.postMessage;\n'
      'function s(k,d){\n'
      "p.call(b,'$nativeBridgeEnvelopeTag$nonce:'+k+':'+d);}\n"
      "Object.defineProperty(window,'$nativeBridgeTokenProperty',\n"
      "{value:'$token'});\n"
      "Object.defineProperty(window,'StratumBridge',\n"
      '{value:Object.freeze({postMessage:function(d){\n'
      "s('message',String(d));}}),enumerable:true});\n"
      "s('hello','');\n"
      '})();</script>';
  return placeBridgeBootstrap(html, script);
}

/// Places [script] before any page script of [html]: right after a leading
/// `<!DOCTYPE ...>` declaration (matched case-insensitively, allowing
/// leading whitespace and HTML comments before it), or first when [html]
/// has none.
///
/// One placement serves the web and native bootstraps (US-03 FR-03 E04): a
/// script before the doctype would put a top-level native document in
/// quirks mode.
String placeBridgeBootstrap(String html, String script) {
  // Each comment must end at its first `-->`. Letting `.*?` run on to a
  // later `-->` gives n comments 2^(n-1) ways to match, which backtracks
  // exponentially when no doctype follows and lets a "comment" swallow the
  // markup between two real comments.
  final match = RegExp(
    r'^(?:\s|<!--(?:(?!-->)[\s\S])*-->)*<!doctype[^>]*>',
    caseSensitive: false,
  ).firstMatch(html);
  if (match == null) return '$script$html';
  return html.replaceRange(match.end, match.end, script);
}
