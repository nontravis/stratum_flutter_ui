# Utilities (CO-01)

## Slot (CO-01-01)

**When to use and not:** Mark the place in a layout under construction where a widget will go: `StratumSlot` draws a
dashed purple outline with "❖" and its name centered. It takes no child; put the real widget in its place once that
widget exists.

**Short example:** `StratumSlot(name: 'Avatar', width: 120, height: 48)` shows "❖ Avatar" centered in a 120 by 48 area
inside the outline.

**Key props:** `name` (default `'Slot'`), `width` and `height` (the area inside the padding), and `padding` (between the
outline and that area, default 12 on every side).

**Variants:** —

**Slots:** —

**Responsive props:** —

**Accessibility:** —

**Related:** Placeholder page (CO-05-08) marks a whole screen not built yet.

**Catalog path:** Utility / Slot

## Web view (CO-01-02)

**When to use and not:** Show a web page or the app's own HTML in place and exchange messages with a page the app
trusts; not for third-party embeds, scripts the app injects into the page, cookies, a user agent, load progress, zoom,
file upload, or a built-in loading indicator.

**Short example:** `StratumWebView(source: StratumWebViewSource.url(Uri.parse('https://example.com/help')))`

**Key props:** `source` (required), `controller`, `allowedOrigins`, `javaScriptEnabled`, `onMessage`,
`onNavigationRequest`, `onPageStarted`, `onPageFinished`, and `onError`.

- **`StratumWebView`** — shows a URL page or the app's own HTML (`StratumWebViewSource.url`, `.html`) on Android,
  iOS, macOS, Windows, Linux, and the web, driven by an optional `StratumWebViewController`.
  Bridge: list the page origins you trust in `allowedOrigins` (empty closes the bridge, HTML included). A page calls
  `StratumBridge.postMessage(data)`; `onMessage` gets the text and the origin of the page that sent it, `null` for
  your HTML; answer the sender with `controller.reply(message, data)`: it reaches only the page or HTML document
  that sent the message, and throws `StateError` once the view shows another origin or that document is gone
  (`ArgumentError` for a message the controller did not deliver). Two limits on that guarantee: on the web, after
  an in-frame link to another origin the check still passes on stale history and the browser drops the reply
  silently with no throw; and on the web, a reply to your own HTML after a link away inside it resolves the same
  way, without delivering the data. `controller.postMessage(data, targetOrigin: origin)` names a recipient origin
  the same way; `postMessage(data)` sends to whatever page is shown. Your HTML
  connects its bridge when its bootstrap script runs: a `postMessage` before that throws `StateError` on every
  platform, so wait for the page's first message instead of sending right after `loadHtml`. On iOS and macOS a
  `reload()` of your HTML shows an empty page and the bridge stays closed until the next `loadHtml`.
  Native code: the package ships Android (Kotlin, AndroidX WebKit) and iOS and macOS (Swift) code that names the
  sender of each page message, so only the top-level page's messages pass, even one sent before `onPageStarted`; an
  app needs no setup of its own. On Android a system WebView without `WEB_MESSAGE_LISTENER` or
  `JS_INJECTION_IN_FRAME_AND_WORLD` keeps the bridge off, and every `postMessage` throws `StateError`. On Android a
  send to your HTML reaches only the document that connected the bridge; once that document leaves, the next one
  gets nothing and the send throws `StateError`. On Windows and Linux the plugin names the sending document, so
  only the top-level page's messages pass, each with its sender's origin; Linux drops a message from a document
  with an opaque origin, a page its server sandboxes included, but Windows names only the document's address: an
  allowed origin there vouches for every top-level document served at its addresses, a sandboxed one included, so
  allow no origin that serves sandboxed untrusted HTML.
  Web: `onMessage`'s origin names the page that sent the message, even a URL page the view has moved away from, and
  `currentUrl()` reports the requested URL until the frame finishes loading it. On the web, load only content the app
  trusts on the app's own origin: such a page runs with the app's privileges.

**Variants:** `StratumWebViewSource.url` for a page at an `http` or `https` address, `.html` for an HTML string;
`loadUrl` throws `ArgumentError` for any other scheme.

**Slots:** —

**Responsive props:** —

**Accessibility:** Stratum's own frame and controls meet WCAG 2.2 AA; the page's content, from the app or a third party,
is outside that.

**Related:** Web zoom (CO-01-04) leaves the page inside the web view unzoomed. On the web, a Stratum overlay above the
web view takes no pointer input; Overlay (CO-08) owns that.

**Catalog path:** Utility / Web view

## Caret (CO-01-03)

**When to use and not:** Show which way a disclosure, select, or dropdown points; it is not a navigation arrow.

- **`StratumCaret`** — the Figma `Caret` glyph that marks a disclosure, select, or dropdown as open or closed; for
  navigation between pages or sections, use a dedicated arrow or chevron icon instead. Key parameters: `direction`
  (`StratumCaretDirection.down`, the default, `.up`, `.start`, `.end`: `start` and `end` follow the text direction,
  so `end` points right in a left-to-right app and left in a right-to-left app), `style` (a `StratumCaretGlyph`:
  `StratumCaretGlyph.regular`, the default, a 1.5 px round chevron; `.light`, 1.0 px; `.fill`, a solid triangle),
  `size` (a `WidgetSize`: `tiny` 10 px to `huge` 32 px, `medium` 16 px; null takes the theme's `defaultWidgetSize`)
  or `customSize` (any side in logical pixels, must be finite and >= 0), and `color` (a `ColorEnum`: the theme's
  `icon.color.<name>` token, else `icon.default.primary`) or `customColor` (any color, as given). The line width
  stays the same at every size, and the glyph sits centered in its square box and never stretches. Change
  `direction` to turn it: it turns the short way over the theme's `fast` level, a half turn back the way the last
  half turn came, and shows the new direction at once under reduced motion or when the text direction flips. It
  adds nothing to the semantics tree: announce expanded or collapsed on the component that holds it. It takes no
  `state`, `feedbackState`, `loading`, or `windowSize`; `customStyle` takes a `StratumCaretStyle`, the 16
  `WidgetStyle` fields its childless box shows (no `padding`, `alignment`, `clipBehavior`, `foregroundBlur`, or min
  and max sizes), and styles the box, never the glyph: a `width` or `height` grows the box past its side, the glyph
  keeps its size and sits centered, and the box never shrinks below the glyph. `componentPartDefaults: (theme) =>
  {StratumCaret: StratumCaretStyle(...)}` restyles every caret's box; a `componentDefaults` entry under
  `StratumCaret` fails a debug assert.

**Short example:** `StratumCaret(direction: StratumCaretDirection.up, style: StratumCaretGlyph.fill)`

**Key props:** `direction`, `style`, `size` or `customSize`, `color` or `customColor`, and `customStyle`, each described
under When to use and not.

**Variants:** Three glyphs, `StratumCaretGlyph.regular`, `.light`, and `.fill`, in four directions,
`StratumCaretDirection.down`, `.up`, `.start`, and `.end`.

**Slots:** —

**Responsive props:** None: it takes no `windowSize`; `start` and `end` follow the text direction.

**Accessibility:** It adds nothing to the semantics tree, so the component that holds it announces expanded or
collapsed; under reduced motion it shows the new direction at once.

**Related:** Disclosure (CO-03) and Dropdown (CO-06-03) are the components a caret marks open or closed.

**Catalog path:** Utility / Caret

## Web zoom (CO-01-04)

**When to use and not:** Let the EndUser pinch to zoom and pan a web app to read small text and controls; not for the
page inside a web view, and not on the other five platforms.

- **`StratumWebZoom`** — wrap a web app, or the part of it to zoom, in `StratumWebZoom(child: app)`. On the web the
  EndUser pinches, on a touch screen or a trackpad, to zoom between `minScale` (default 1.0, so the app never shrinks
  below its own layout) and `maxScale` (default 2.5), pans the zoomed app, and sees it clipped to the zoom's bounds;
  the mouse wheel never zooms and keeps scrolling the list under the pointer. On Android, iOS, macOS, Windows, and
  Linux it builds the child alone. A `maxScale` below `minScale`, or a `minScale` of 0 or less, fails an assertion in
  debug builds on every platform. It does not zoom the page inside a `StratumWebView`.

**Short example:** `StratumWebZoom(maxScale: 3, child: app)`

**Key props:** `minScale` (default 1.0) and `maxScale` (default 2.5).

**Variants:** —

**Slots:** `child`: the app, or the part of it to zoom.

**Responsive props:** —

**Accessibility:** New limits that leave the zoom outside them ease it to the nearest limit, at once under reduced
motion.

**Related:** Web view (CO-01-02) keeps its page unzoomed inside the zoomed app.

**Catalog path:** Utility / Web zoom

## Planned

—
