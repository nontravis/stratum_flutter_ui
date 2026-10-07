/// Prefix of every native bridge envelope: the version tag.
///
/// An envelope reads `<tag><inbound nonce>:<kind>:<data>`, where the nonce is
/// 32 lowercase hex characters and the kind is `hello` or `bye` (data: the
/// document id) or `message`. A page message that starts with this tag is
/// judged only by its nonce (US-03 FR-04, `event_bridge_messages.md`
/// `## Native envelope`).
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
/// Before any page script runs, the script removes its own element, binds
/// the platform sender and `String` once, keeps [token] in the
/// [nativeBridgeTokenProperty] window property, and defines
/// `window.StratumBridge` as a frozen, non-writable, non-configurable
/// wrapper that sends each message as an envelope carrying [nonce] (see
/// [nativeBridgeEnvelopeTag]). It draws a document id of 16 random bytes in
/// lowercase hex, posts `hello` with it to prove [nonce] for this document,
/// `bye` on `pagehide` or once a page script removes the document root, even
/// if it puts the same root back, and `hello` again on a `pageshow` that
/// restores the document from the back-forward cache (E03, E10, E11, E14).
/// No envelope carries [token]. Without the platform object the bridge stays
/// closed.
///
/// Returns [html] with the script placed by [placeBridgeBootstrap].
String injectNativeBridgeBootstrap(
  String html, {
  required String nonce,
  required String token,
}) {
  final script =
      "<script>(function(){'use strict';\n"
      'var e=document.currentScript;if(e)e.remove();\n'
      'var b=window.StratumBridge;\n'
      "if(!b||typeof b.postMessage!=='function')return;\n"
      'var send=b.postMessage.bind(b),S=String;\n'
      'function s(k,d){\n'
      "send('$nativeBridgeEnvelopeTag$nonce:'+k+':'+d);}\n"
      "var a=crypto.getRandomValues(new Uint8Array(16)),id='';\n"
      'for(var i=0;i<16;i++)id+=(a[i]|256).toString(16).slice(1);\n'
      "Object.defineProperty(window,'$nativeBridgeTokenProperty',\n"
      "{value:'$token'});\n"
      "Object.defineProperty(window,'StratumBridge',\n"
      '{value:Object.freeze({postMessage:function(d){\n'
      "s('message',S(d));}}),\n"
      'enumerable:true,writable:false,configurable:false});\n'
      "window.addEventListener('pagehide',function(){\n"
      "s('bye',id);},true);\n"
      "window.addEventListener('pageshow',function(v){\n"
      "if(v.persisted)s('hello',id);},true);\n"
      'var doc=document,root=doc.documentElement,\n'
      'removedOf=Function.prototype.call.bind(\n'
      'Object.getOwnPropertyDescriptor(\n'
      "MutationRecord.prototype,'removedNodes').get),\n"
      'countOf=Function.prototype.call.bind(\n'
      'Object.getOwnPropertyDescriptor(\n'
      "NodeList.prototype,'length').get);\n"
      'new MutationObserver(function(rs){\n'
      'for(var i=0;i<rs.length;i++){var n=removedOf(rs[i]);\n'
      'for(var j=0;j<countOf(n);j++)\n'
      "if(n[j]===root){s('bye',id);return;}}})\n"
      '.observe(doc,{childList:true});\n'
      "s('hello',id);\n"
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
/// quirks mode. Each comment ends where the HTML tokenizer ends it, so
/// markup after an early end keeps a later doctype from leading (FR-04 E12).
String placeBridgeBootstrap(String html, String script) {
  final match = _leadingDoctype.firstMatch(html);
  if (match == null) return '$script$html';
  return html.replaceRange(match.end, match.end, script);
}

/// Whitespace and comments, then a doctype, from the start of the HTML.
///
/// A comment ends at once as `<!-->` or `<!--->`, else at its first `-->`
/// or `--!>`, as in the HTML tokenizer. A pattern that ends one later lets
/// it swallow a page script that runs before the bootstrap, and letting
/// `.*?` run on to a later end backtracks exponentially with no doctype.
final RegExp _leadingDoctype = RegExp(
  r'^(?:\s|<!--(?:-?>|(?!-?>)(?:(?!--!?>)[\s\S])*--!?>))*<!doctype[^>]*>',
  caseSensitive: false,
);
