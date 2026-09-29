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
/// Returns [html] with the script inserted right after a leading
/// `<!DOCTYPE ...>` declaration (matched case-insensitively, allowing
/// leading whitespace and HTML comments before it), or prepended when
/// [html] has none.
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
  final match = RegExp(
    r'^(?:\s|<!--.*?-->)*<!doctype[^>]*>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  if (match == null) return '$script$html';
  return html.replaceRange(match.end, match.end, script);
}
