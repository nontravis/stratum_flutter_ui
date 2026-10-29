// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'web_view.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StratumWebView, StoryArgs<StratumWebView>>;
typedef _Scenario = StratumWebViewScenario;
typedef _Defaults = StratumWebViewDefaults;
typedef _Story = StratumWebViewStory;
typedef _Args = WebViewKnobsArgs;
final StratumWebViewComponent =
    Component<StratumWebView, StoryArgs<StratumWebView>>(
      name: componentMeta.name ?? 'StratumWebView',
      path: componentMeta.path ?? 'utility',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''Displays a web page or an HTML document on Android, iOS, macOS, Windows,
Linux, and the web.

**Bridge.** A page calls `StratumBridge.postMessage(data)` whenever
`window.StratumBridge` exists: on every native platform, and for HTML
content on web. A `url` page on web has no injected bridge and instead
calls `window.parent.postMessage(data, appOrigin)`. Feature-detect both:

```js
function sendToFlutter(data) {
  if (window.StratumBridge) StratumBridge.postMessage(data);
  else window.parent.postMessage(data, 'https://your-app.example');
}
```

`StratumWebViewController.postMessage` delivers a `message` event to the
page on every platform. Answer a message with
`StratumWebViewController.reply`, which reaches only the page or HTML
document that sent it, subject to the per-platform limits below;
`postMessage` with a `targetOrigin` names the recipient origin. The
bridge stays off while [allowedOrigins] is
empty, HTML content included: give HTML a non-empty [allowedOrigins]
too. HTML content is trusted by a secret that its bootstrap script
carries, new for every HTML load, never by the page address: a page the
user reaches from that HTML never passes as it, and going back or
forward to the HTML of the latest load brings the bridge back. A
`postMessage` to HTML before its bootstrap connected the bridge throws a
[StateError] on every platform, so wait for a first message from the
page. On web, the app's own Content-Security-Policy without inline
scripts blocks the bootstrap and keeps the HTML bridge closed; on
native, a policy inside the document never reaches the bootstrap, so the
HTML bridge always opens. On web, scripts that run in the app's own
window are trusted regardless, since the handshake is visible there.

**Limitations.**
* Web: the page is an `<iframe>`. [onError] never fires, and
  [onNavigationRequest] only sees loads started by the controller. A
  `url` page runs without a sandbox, so a page reached inside the frame
  can navigate the whole app window after a click. Many sites refuse to
  be framed; offer an "open in new tab" fallback. Flutter overlays
  drawn above the view need `PointerInterceptor`. An HTML page's URL is
  always `null`; on native it is `about:blank`. A URL page that the view
  has moved away from can still deliver a message, with its own allowed
  origin, until it unloads. A `reply` to it throws once the view shows
  another origin, except after an in-frame link to another origin: the
  check still passes against the page's prior history entry, and the
  browser drops the reply silently with no throw. A `reply` to your own
  HTML after a link away inside it resolves the same way, without
  delivering the data.
* Linux: the page is a native GTK widget, so Flutter widgets cannot draw
  above it, and scale or rotation transforms hide it.
* Android, iOS, and macOS: the platform names the sender of each
  message, so only the top-level page's messages pass, each with its
  sender's origin, even one that arrives before [onPageStarted]. On
  Android the system WebView needs `WEB_MESSAGE_LISTENER` and
  `JS_INJECTION_IN_FRAME_AND_WORLD` support; without either the bridge
  stays off, and every `postMessage` throws a [StateError]. On Android a
  `postMessage` to HTML reaches only the document that connected the
  bridge; once that document leaves, the next one gets nothing and the
  send throws a [StateError]. [onError] may also report an HTTP error
  from an embedded iframe on iOS and macOS, not only the top-level page.
* Windows and Linux: the plugin names the sending document, so only the
  top-level page's messages pass, each with its sender's origin, even
  one that arrives before [onPageStarted]; an iframe's message never
  reaches [onMessage]. A `reply` reaches the page shown only while that
  page has the sender's origin, and throws a [StateError] otherwise.
  Linux drops a message from a document with an opaque origin, a page
  its server sandboxes included. Windows names only the document's
  address, so an allowed origin vouches for every top-level document
  served at its addresses, a sandboxed one included: allow no origin
  that serves sandboxed untrusted HTML.
* Every native platform: treat bridge messages as untrusted input, and
  use [onNavigationRequest] to prevent top-level navigation outside
  [allowedOrigins] when a hard boundary is needed.
* Android: the platform marks no main frame on an HTTP error, so an HTTP
  error counts for the page whose start follows it. A sub-resource that
  failed on the address a later navigation the page starts and the
  platform does not ask about — a history move of the page's own script,
  a script reload, a form POST — lands on is reported through [onError]
  as that page's error, even when the page now answers 200, unless a
  navigation began between: a load, a reload, a controller back or
  forward, or a main-frame navigation that [onNavigationRequest] allows.
  A loading page's start ends only when the platform reports its finish
  or a new page starts, so a back or forward that starts no new document
  keeps the page's finish, and a replaced load's late finish pairs with
  its own start. A navigation the page starts while it still loads may
  report its HTTP error through [onError] before the new load's
  [onPageStarted] when it goes to the page's own address, or may report
  an [onPageFinished] that names the redirect target, paired with the
  loading page's open start, before the target's [onPageStarted] when it
  goes to an address the server redirects; a stray finish of a replaced
  navigation may likewise pair with the replacement's own start.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $Variants..$generatedName = 'Variants',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleHelpPage..$generatedName = 'ExampleHelpPage',
      ],
    );
typedef StratumWebViewScenario = Scenario<StratumWebView, WebViewKnobsArgs>;
typedef StratumWebViewDefaults = Defaults<StratumWebView, WebViewKnobsArgs>;

class StratumWebViewStory extends Story<StratumWebView, WebViewKnobsArgs> {
  StratumWebViewStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    required super.args,
    required super.builder,
    super.scenarios,
    super.excludeFromTests,
  });
}

class WebViewKnobsArgs extends StoryArgs<StratumWebView> {
  WebViewKnobsArgs({
    required Arg<RequiredPreset<StratumWebViewSource>> source,
    required Arg<Preset<StratumWebViewController>> controller,
    required Arg<RequiredPreset<Set<Uri>>> allowedOrigins,
    Arg<bool>? javaScriptEnabled,
    Arg<bool>? onMessage,
    required Arg<Preset<StratumNavigationDecision Function(Uri)>>
    onNavigationRequest,
    Arg<bool>? onPageStarted,
    Arg<bool>? onPageFinished,
    Arg<bool>? onError,
  }) : this.sourceArg = $initArg('source', source, null)!,
       this.controllerArg = $initArg('controller', controller, null)!,
       this.allowedOriginsArg = $initArg(
         'allowedOrigins',
         allowedOrigins,
         null,
       )!,
       this.javaScriptEnabledArg = $initArg(
         'javaScriptEnabled',
         javaScriptEnabled,
         BoolArg(true),
       )!,
       this.onMessageArg = $initArg('onMessage', onMessage, BoolArg(true))!,
       this.onNavigationRequestArg = $initArg(
         'onNavigationRequest',
         onNavigationRequest,
         null,
       )!,
       this.onPageStartedArg = $initArg(
         'onPageStarted',
         onPageStarted,
         BoolArg(true),
       )!,
       this.onPageFinishedArg = $initArg(
         'onPageFinished',
         onPageFinished,
         BoolArg(true),
       )!,
       this.onErrorArg = $initArg('onError', onError, BoolArg(true))!;

  WebViewKnobsArgs.fixed({
    required RequiredPreset<StratumWebViewSource> source,
    required Preset<StratumWebViewController> controller,
    required RequiredPreset<Set<Uri>> allowedOrigins,
    bool javaScriptEnabled = true,
    bool onMessage = true,
    required Preset<StratumNavigationDecision Function(Uri)>
    onNavigationRequest,
    bool onPageStarted = true,
    bool onPageFinished = true,
    bool onError = true,
  }) : this.sourceArg = $initArg('source', Arg.fixed(source), null)!,
       this.controllerArg = $initArg(
         'controller',
         Arg.fixed(controller),
         null,
       )!,
       this.allowedOriginsArg = $initArg(
         'allowedOrigins',
         Arg.fixed(allowedOrigins),
         null,
       )!,
       this.javaScriptEnabledArg = $initArg(
         'javaScriptEnabled',
         Arg.fixed(javaScriptEnabled),
         null,
       )!,
       this.onMessageArg = $initArg('onMessage', Arg.fixed(onMessage), null)!,
       this.onNavigationRequestArg = $initArg(
         'onNavigationRequest',
         Arg.fixed(onNavigationRequest),
         null,
       )!,
       this.onPageStartedArg = $initArg(
         'onPageStarted',
         Arg.fixed(onPageStarted),
         null,
       )!,
       this.onPageFinishedArg = $initArg(
         'onPageFinished',
         Arg.fixed(onPageFinished),
         null,
       )!,
       this.onErrorArg = $initArg('onError', Arg.fixed(onError), null)!;

  final Arg<RequiredPreset<StratumWebViewSource>> sourceArg;

  final Arg<Preset<StratumWebViewController>> controllerArg;

  final Arg<RequiredPreset<Set<Uri>>> allowedOriginsArg;

  final Arg<bool> javaScriptEnabledArg;

  final Arg<bool> onMessageArg;

  final Arg<Preset<StratumNavigationDecision Function(Uri)>>
  onNavigationRequestArg;

  final Arg<bool> onPageStartedArg;

  final Arg<bool> onPageFinishedArg;

  final Arg<bool> onErrorArg;

  RequiredPreset<StratumWebViewSource> get source => sourceArg.value;

  Preset<StratumWebViewController> get controller => controllerArg.value;

  RequiredPreset<Set<Uri>> get allowedOrigins => allowedOriginsArg.value;

  bool get javaScriptEnabled => javaScriptEnabledArg.value;

  bool get onMessage => onMessageArg.value;

  Preset<StratumNavigationDecision Function(Uri)> get onNavigationRequest =>
      onNavigationRequestArg.value;

  bool get onPageStarted => onPageStartedArg.value;

  bool get onPageFinished => onPageFinishedArg.value;

  bool get onError => onErrorArg.value;

  @override
  List<Arg?> get list => [
    sourceArg,
    controllerArg,
    allowedOriginsArg,
    javaScriptEnabledArg,
    onMessageArg,
    onNavigationRequestArg,
    onPageStartedArg,
    onPageFinishedArg,
    onErrorArg,
  ];
}
