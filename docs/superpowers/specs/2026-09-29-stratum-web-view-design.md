# StratumWebView design

- **Date:** 2026-09-29
- **Status:** Sections 1–5 approved during brainstorming; written spec awaiting owner review.
- **Location:** `lib/src/components/common/web_view/`

## 1. Goal

Provide one cross-platform web view component for stratum_ui that covers four use cases:

1. Display an external page from a URL.
2. Render an HTML string.
3. Exchange messages in both directions with a first-party page.
4. Control navigation (reload, back, forward, page lifecycle callbacks).

Target platforms: Android, iOS, macOS, Windows, Linux, and Web.

## 2. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Package location | Inside stratum_ui, under `components/common/web_view/` | Owner choice. Consequence: every consumer app links the webview plugins, and Linux builders need webkit2gtk-4.1 installed. |
| Web implementation | Own `<iframe>` built with `HtmlElementView.fromTagName` and `package:web` | `webview_flutter_web` is unendorsed and supports only `loadRequest` and `loadHtmlString`. Owning the iframe gives full control of `sandbox`, `postMessage`, and origin checks. |
| Native backend | Hybrid: `webview_flutter` on Android, iOS, macOS; `webview_all_windows` and `webview_all_linux` on Windows and Linux | Keeps the flutter.dev-maintained stable plugin on mobile, and gains texture rendering on Windows so Flutter overlays can draw above the web view. |
| Platform split | Conditional export on `dart.library.js_interop` / `dart.library.io`, then a runtime `defaultTargetPlatform` check on native | Conditional imports can only separate web from native. Native platforms are separated at runtime by federated plugin registration. |

### Native backends considered (evidence gathered 2026-09-29)

| Option | Windows overlay | Linux overlay | Mobile risk | Outcome |
|---|---|---|---|---|
| A. `webview_flutter` + `webview_win_floating` 3.0.3 | No: floating native window | No: floating native window | Low (flutter.dev, stable) | Rejected: stratum_ui popover, tooltip, and dialog would be hidden behind the web view on desktop. |
| B. `flutter_inappwebview` 6.2.0-beta.3 | Yes: texture | Yes: texture (WPE WebKit, `0.1.0-beta.1`) | High: open issue #2843 (blank web view on about half of Android release cold starts); no commits since 2026-02-10 | Rejected. |
| C. `webview_all` 1.4.3 for every platform | Yes: WebView2 + `Windows.Graphics.Capture` texture | No: GTK widget in a `GtkOverlay` | Medium: first-party Android and iOS implementations first shipped 2026-08-01 (1.3.1), single main maintainer | Rejected for mobile. |
| **D. Hybrid (chosen)** | Yes | No | Low | Accepted. The Linux limitation is shared by every non-beta option. |

`webview_all_windows` and `webview_all_linux` register themselves through `dartPluginClass`, so stratum_ui depends on them directly and does not pull in the `webview_all` app-facing package or its mobile implementations.

## 3. Architecture

```
lib/src/components/common/web_view/
  web_view.dart                       # barrel: public exports only
  stratum_web_view.dart               # StratumWebView widget (public)
  stratum_web_view_controller.dart    # StratumWebViewController (public)
  stratum_web_view_types.dart         # source, message, navigation decision, error types
  platform/
    platform_web_view_interface.dart  # internal contract: PlatformStratumWebView + listener
    platform_web_view.dart            # conditional export (see below)
    platform_web_view_stub.dart       # throws UnsupportedError
    platform_web_view_web.dart        # iframe + package:web + postMessage
    platform_web_view_io.dart         # selects a native adapter at runtime
    adapters/
      webview_flutter_adapter.dart    # Android, iOS, macOS
      webview_all_adapter.dart        # Windows, Linux
    shared/
      origin_policy.dart              # isAllowedOrigin(origin, allowed)
      html_frame_guard.dart           # tracks whether the srcdoc frame still shows our HTML
      web_view_history.dart           # controller-initiated load history for the web implementation
      message_script.dart             # builds the dispatchEvent script with jsonEncode
      native_bridge_session.dart      # bridge and error rules shared by both native adapters
```

`platform_web_view.dart` holds the only conditional directive:

```dart
export 'platform_web_view_stub.dart'
    if (dart.library.js_interop) 'platform_web_view_web.dart'
    if (dart.library.io) 'platform_web_view_io.dart';
```

Each target file defines the same internal contract: an abstract `PlatformStratumWebView` plus a factory function. The public controller delegates to it and never references a backend type.

`platform_web_view_io.dart` selects the adapter with `defaultTargetPlatform`:

- `TargetPlatform.windows`, `TargetPlatform.linux`: `webview_all_adapter.dart`.
- `TargetPlatform.android`, `TargetPlatform.iOS`, `TargetPlatform.macOS`: `webview_flutter_adapter.dart`.
- Any other platform: `UnsupportedError` naming the platform.

The two adapters live in separate files because `webview_flutter` and `webview_platform_interface` export classes with identical names (`JavaScriptMode`, `NavigationDecision`, `WebResourceError`, and others). `webview_platform_interface` is a fork of `webview_flutter_platform_interface`, so both adapters follow the same method names: `loadRequest`, `loadHtmlString`, `addJavaScriptChannel`, `runJavaScript`, `canGoBack`, `goBack`, `goForward`, `reload`, `currentUrl`.

The barrel `web_view.dart` is exported from `common/common.dart`, matching the existing layout components. Source files import `package:stratum_ui/src/src.dart`, use `const new(...)` constructors, and group fields with `///========== Section ==========///` comments, following the repository convention.

## 4. Public API

### Usage

```dart
final controller = StratumWebViewController();

StratumWebView(
  controller: controller,
  source: StratumWebViewSource.url(Uri.parse('https://app.example.com')),
  allowedOrigins: {Uri.parse('https://app.example.com')},
  onMessage: (message) => debugPrint(message.data),
  onNavigationRequest: (url) => url.host == 'app.example.com'
      ? StratumNavigationDecision.navigate
      : StratumNavigationDecision.prevent,
  onPageStarted: (url) {},
  onPageFinished: (url) {},
  onError: (error) {},
);

await controller.postMessage('{"type":"refresh"}');
await controller.loadHtml('<h1>Terms</h1>');
if (await controller.canGoBack()) await controller.goBack();
```

### `StratumWebView` parameters

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `controller` | `StratumWebViewController?` | `null` | When `null`, the widget creates and disposes its own controller (the `TextField` pattern). |
| `source` | `StratumWebViewSource` | required | Sealed: `StratumWebViewSource.url(Uri)` or `StratumWebViewSource.html(String)`. A change in `didUpdateWidget` triggers a new load. |
| `allowedOrigins` | `Set<Uri>` | `{}` | Bridge allowlist. Empty disables the bridge: incoming messages are dropped and `postMessage` throws. |
| `javaScriptEnabled` | `bool` | `true` | When `false`, the bridge is inactive. On web, the iframe gets a `sandbox` attribute without `allow-scripts` for both source types. |
| `onMessage` | `ValueChanged<StratumWebViewMessage>?` | `null` | `StratumWebViewMessage` has `data` (`String`) and `origin` (`Uri?`). |
| `onNavigationRequest` | `StratumNavigationDecision Function(Uri url)?` | `null` | `StratumNavigationDecision` is an enum: `navigate`, `prevent`. |
| `onPageStarted` | `ValueChanged<Uri?>?` | `null` | |
| `onPageFinished` | `ValueChanged<Uri?>?` | `null` | |
| `onError` | `ValueChanged<StratumWebViewError>?` | `null` | Main-frame errors only. See section 6. |

Callbacks live on the widget and are synchronized into the controller in `initState` and `didUpdateWidget`.

### `StratumWebViewController`

| Method | Returns |
|---|---|
| `loadUrl(Uri url)` | `Future<void>` |
| `loadHtml(String html)` | `Future<void>` |
| `reload()` | `Future<void>` |
| `goBack()`, `goForward()` | `Future<void>` |
| `canGoBack()`, `canGoForward()` | `Future<bool>` |
| `currentUrl()` | `Future<Uri?>` |
| `postMessage(String data)` | `Future<void>`; throws `StateError` when the current page is not an allowed destination |
| `dispose()` | `void`; any later call throws `StateError` |

### Types

- `sealed class StratumWebViewSource` with `url` and `html` variants.
- `final class StratumWebViewMessage { String data; Uri? origin; }`
- `enum StratumNavigationDecision { navigate, prevent }`
- `final class StratumWebViewError { StratumWebViewErrorType type; String description; int? code; Uri? url; }`
- `enum StratumWebViewErrorType { network, http }`

### Out of scope

`runJavaScript` (unsafe and unavailable cross-origin on web), cookies, user agent, progress, zoom, file upload, and a built-in loading builder. Consumers build loading UI from `onPageStarted` and `onPageFinished`.

## 5. Bridge protocol

### Page-side contract

The same snippet works on web and native. Page authors include it in their own page.

```js
// Page to Flutter
function sendToFlutter(data) {
  if (window.StratumBridge) StratumBridge.postMessage(data); // native JavaScriptChannel
  else window.parent.postMessage(data, 'https://your-app.example'); // web iframe to parent
}

// Flutter to page: arrives as a normal 'message' event on both platforms
window.addEventListener('message', (event) => handle(event.data));
```

### Transport

| Direction | Web | Native |
|---|---|---|
| Page to Flutter | Page calls `parent.postMessage`; stratum_ui listens for `message` on the app window. | `addJavaScriptChannel('StratumBridge')`; `onMessageReceived`. |
| Flutter to page | `iframe.contentWindow.postMessage(data, targetOrigin)`. | `runJavaScript` with `window.dispatchEvent(new MessageEvent('message', {data: <jsonEncode(data)>}))`. |

### Acceptance rules (page to Flutter)

| Case | A message is accepted when |
|---|---|
| Web, `url` source | `event.source == iframe.contentWindow` **and** `event.origin` passes `isAllowedOrigin`. |
| Web, `html` source | `event.source == iframe.contentWindow`, `event.origin == "null"`, **and** `HtmlFrameGuard` reports that the frame still shows our HTML. |
| Native, `url` source | The origin of the current top-level page passes `isAllowedOrigin`. The origin is tracked from `onPageStarted` and `onUrlChange`, because `JavaScriptMessage` carries no origin. |
| Native, `html` source | `HtmlFrameGuard` reports that the page is still our HTML **and** the tracked page has no origin (`about:blank`). On native, the guard counts `onPageStarted` events instead of iframe `load` events; between `willLoadHtml` and the HTML's first `onPageStarted` the previous page is still live, so the origin check keeps that page from being trusted as our HTML. |

On every platform, an empty `allowedOrigins` disables the bridge entirely, including for HTML content. The controller enforces this rule before any platform rule runs.

`isAllowedOrigin` compares scheme, host (case-insensitive), and port (default 443 for `https` and 80 for `http`), and ignores path, query, and fragment.

### HTML source on web

The iframe uses `srcdoc` with `sandbox="allow-scripts"` (no `allow-same-origin`), so the document has an opaque origin serialized as `"null"`. A frame that navigates away keeps the sandbox flags and also reports `"null"`. `HtmlFrameGuard` counts iframe `load` events: the first `load` after `srcdoc` is set is our HTML. Any later `load` that the controller did not initiate marks the frame as navigated away. From then on, `"null"` messages are dropped and `postMessage` throws until the controller loads new content.

### Sending rules (Flutter to page)

- Web, `url` source: `targetOrigin` is the origin of the current URL. If the frame has moved to another origin, the browser drops the message.
- Web, `html` source: `targetOrigin` must be `'*'` because the origin is opaque. Sending is allowed only while `HtmlFrameGuard` reports our HTML.
- Native: sending is allowed only while the current page origin passes `isAllowedOrigin`, or while `HtmlFrameGuard` reports our HTML. `jsonEncode` produces the JavaScript string literal (quotes, backslashes, and control characters are escaped). U+2028 and U+2029 are escaped as well for engines older than ES2019. `</script>` needs no escaping because `runJavaScript` evaluates the script directly, without an HTML parser.
- A blocked send throws `StateError`.

### Known limitation (documented in doc comments)

On native, the JavaScript channel is visible to every frame in the page. An untrusted iframe (for example an advertisement) inside an allowed page can send messages that appear to come from the allowed top-level origin. Only the top-level origin can be verified.

The page origin is also inferred from navigation events, not from a commit signal. On iOS and macOS, `onPageStarted` is `didStartProvisionalNavigation`, which fires before the new page commits; the previous document keeps running scripts during that window. A disallowed page can navigate to an allowed origin and post messages until the navigation commits, and those messages are stamped with the new, allowed origin. Treat bridge messages as untrusted input regardless of origin, and use `onNavigationRequest` to prevent top-level navigation outside `allowedOrigins` when a hard boundary is needed.

## 6. Error handling and platform behavior

### Principles

- Security rule violations throw `StateError` (for example `postMessage` to a disallowed page, or any call after `dispose()`).
- Platform limitations never throw. The method does what the platform allows, and the doc comment states the behavior.

### Web behavior

| API | Same-origin page | Cross-origin page |
|---|---|---|
| `canGoBack`, `goBack`, `goForward` | Controller-initiated history only (`WebViewHistory`) | Same; `contentWindow.history` is not accessible. |
| `currentUrl()` | Reads `contentWindow.location` | Last URL loaded by the controller; can be stale after in-frame link clicks. |
| `onNavigationRequest` | Called for controller-initiated loads only | Same; in-frame link clicks cannot be intercepted. |
| `onPageStarted` | When `src` or `srcdoc` is set | Same |
| `onPageFinished` | iframe `load` event | Same, with the last known URL |
| `onError` | Never called | Never called; iframes expose no HTTP or `X-Frame-Options` failure. |

The doc comment recommends pairing the web view with an "open in new tab" action (`url_launcher`) as a fallback on web.

### Native errors

- `WebResourceError` maps to `StratumWebViewErrorType.network` (`code` = `errorCode`, `url` = `url`).
- `HttpResponseError` maps to `StratumWebViewErrorType.http` (`code` = `response.statusCode`, `url` = `request.uri`).
- Only main-frame errors are forwarded. For `WebResourceError`, a `null` `isForMainFrame` counts as main frame. `HttpResponseError` has no main-frame flag (Android reports sub-resource HTTP errors too), so a non-null `request.uri` is forwarded only when it equals the current page URL, without fragment. WebKit (iOS, macOS) reports HTTP errors only for navigation responses and never supplies a request URL; a `null` `request.uri` is treated as the current page instead of being dropped, with `url` set to the current page URL (`null` before any page has loaded).

### Native navigation requests

`onNavigationRequest` is consulted for main-frame requests only. Sub-frame requests and `about:` URLs (for example the `about:blank` document created by `loadHtml`) always navigate. Android does not report navigations started by `loadRequest`; iOS and macOS do.

### Lifecycle

- A controller created by the widget is disposed by the widget. A controller passed in is disposed by its owner.
- On web, `dispose()` removes the `message` listener from the app window.

### Consumer callback exceptions

Every consumer callback runs inside `try`/`catch`. A caught exception goes to `FlutterError.reportError`, so a throwing callback cannot break the bridge or the platform channel. A throwing `onNavigationRequest` counts as `prevent` (fail closed).

### Unsupported platforms

The controller constructor throws `UnsupportedError` naming the platform (stub target or a native platform without an adapter).

### Documented limitations

- **Linux:** the web view is a native GTK widget in a `GtkOverlay`. Flutter widgets cannot render above it, and scale, rotation, or skew transforms hide it.
- **Web:** the iframe consumes pointer events under Flutter overlays. Overlays drawn above it need `PointerInterceptor`. Wiring this into stratum_ui overlay components is a follow-up (section 9).

## 7. Dependencies

Each new dependency passes the `add-new-pubspec-decision` check before it is added.

```yaml
environment:
  sdk: ^3.13.3
  flutter: ">=3.41.0"   # webview_flutter 4.14.1 requires >=3.41.0; webview_all_* require >=3.35.0

dependencies:
  webview_flutter: ^4.14.1
  webview_all_windows: ^1.4.3
  webview_all_linux: ^1.4.3
  webview_platform_interface: ^1.4.3
  web: ^1.1.1

dev_dependencies:
  webview_flutter_platform_interface: ^2.15.1   # tests install a fake WebViewPlatform
```

## 8. Testing

Development follows TDD: each behavior starts with a failing test.

| Layer | Runner | Coverage |
|---|---|---|
| 1. Pure logic (`platform/shared/`) | `flutter test` | `isAllowedOrigin` (default ports, host case, path ignored, `null` origin), `HtmlFrameGuard` transitions, `WebViewHistory`, `message_script` escaping (`"`, `\`, `</script>`, non-ASCII). |
| 2. Adapters with a fake platform | `flutter test` | Hand-written fakes installed through `WebViewPlatform.instance` for both platform interfaces. Channel `StratumBridge` registration, origin gating, main-frame error filtering, adapter selection through `debugDefaultTargetPlatformOverride`. |
| 3. Widget | `flutter test` | Widget-owned controller created and disposed; external controller not disposed; callback sync and reload on `source` change in `didUpdateWidget`; throwing callback reported through `FlutterError.reportError`. |
| 4. Web | `flutter test --platform chrome`, `@TestOn('browser')` | iframe `srcdoc` and `sandbox` attributes; page `postMessage` reaches `onMessage`; mismatched `event.source` dropped; listener removed on dispose. |

- Test files mirror `lib/`: `test/src/components/common/web_view/...`.
- Fakes are hand-written; no mocking library is added.
- Learning mode: the owner writes the body of `isAllowedOrigin` against the prepared tests.

### Manual verification

A new `example/` app with one screen and three tabs: URL, HTML, and a bridge echo.

- Verifiable on the development machine (macOS): macOS, iOS simulator, Android emulator, Chrome.
- **Not verifiable locally: Windows and Linux.** Initial coverage for these is layer 2 only.

## 9. Risks and follow-ups

| Item | Type | Mitigation or next step |
|---|---|---|
| `webview_all_windows` and `webview_all_linux` have one main maintainer and release frequently. | Risk | Keep caret constraints (a library must not pin exact versions, or consumer apps hit resolution conflicts). Raise the lower bound only after testing a new release. The adapter boundary allows replacing the desktop backend without API changes. |
| Windows and Linux behavior is untested on real hardware. | Risk | Run the `example/` app on Windows and Linux machines, or add CI jobs, before claiming desktop support. |
| Native JavaScript channel is exposed to subframes. | Risk | Documented. Allow only pages without untrusted iframes. |
| Linux overlays cannot draw above the web view. | Limitation | Documented. |
| stratum_ui overlays (popover, tooltip, tutorial) over a web view on web. | Follow-up | Separate task: wrap overlay surfaces with `PointerInterceptor` on web. |
