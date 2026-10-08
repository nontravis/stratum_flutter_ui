@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_web.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:web/web.dart' as web;

import '../fakes/recording_listener.dart';

void main() {
  final appOrigin = Uri.parse(web.window.location.origin);
  // A host that never resolves, so no test reaching it touches the network.
  final partner = Uri.parse('https://partner.example.invalid');
  late RecordingListener listener;
  late WebPlatformStratumWebView view;

  setUp(() {
    listener = RecordingListener(allowedOrigins: {appOrigin});
    view = WebPlatformStratumWebView(listener);
    addTearDown(() {
      view.dispose();
      view.iframe.remove();
    });
  });

  void attach() => web.document.body!.appendChild(view.iframe);

  void dispatchMessage(JSAny data, {required String origin, JSObject? source}) {
    web.window.dispatchEvent(
      web.MessageEvent(
        'message',
        web.MessageEventInit(
          data: data,
          origin: origin,
          source: source ?? view.iframe.contentWindow,
        ),
      ),
    );
  }

  StratumWebViewSource missingPage() =>
      StratumWebViewSource.url(appOrigin.replace(path: '/missing'));

  void fireFrameLoad() => view.iframe.dispatchEvent(web.Event('load'));

  /// Waits until the frame has reported [count] finishes, so a test can act
  /// right after the frame's `load` for an entry instead of racing it.
  Future<void> finishes(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (listener.pagesFinished.length < count) {
      if (DateTime.now().isAfter(deadline)) fail('no frame load $count');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Waits until the listener has recorded [count] messages, so a test can
  /// act on a real, asynchronously posted message instead of racing it.
  Future<void> waitForMessages(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (listener.messages.length < count) {
      if (DateTime.now().isAfter(deadline)) fail('no message $count');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Waits until the frame's own browsing context shows `about:blank`, the
  /// way [WebPlatformStratumWebView.dispose] leaves it: a `src`-attribute
  /// `about:blank` inherits this test page's origin, so the frame stays
  /// same-origin and script-capable after dispose.
  Future<void> waitForFrameBlank() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      final href = view.iframe.contentWindow?.location.href;
      if (href == 'about:blank') return;
      if (DateTime.now().isAfter(deadline)) fail('frame never went blank');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Loads [script] as a real `<script>` run inside a `url` source page's
  /// own JavaScript realm.
  ///
  /// The frame navigates to a `blob:` URL this test created: a Blob URL's
  /// origin is the origin of the document that created it, not of the frame
  /// that navigates to it, so the page stays on [appOrigin]. `event.source`
  /// and `event.origin` on any message [script] posts are then browser-set,
  /// never forgeable by the test (sec-m3 F3).
  Future<void> loadBlobScript(String script) async {
    final blob = web.Blob(
      <JSAny>['<script>$script</script>'.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html'),
    );
    final url = Uri.parse(web.URL.createObjectURL(blob));
    await view.load(StratumWebViewSource.url(url));
  }

  test(
    'us01/fr01: a controller load reports one start and one finish',
    () async {
      final url = appOrigin.replace(path: '/one');
      await view.load(StratumWebViewSource.url(url));
      fireFrameLoad();
      expect(listener.events, ['started $url', 'finished $url']);
    },
  );

  test('us01/fr01/e06: a frame load with no open start reports its start '
      'right before its finish', () async {
    final url = appOrigin.replace(path: '/one');
    await view.load(StratumWebViewSource.url(url));
    fireFrameLoad();
    // A link inside the frame: the frame loads again with no controller call.
    fireFrameLoad();
    expect(listener.events, [
      'started $url',
      'finished $url',
      'started $url',
      'finished $url',
    ]);
  });

  test('us01/fr01/e06: HTML whose frame reloads on re-insertion reports a '
      'start before that finish', () async {
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    fireFrameLoad();
    // The view is inserted again: srcdoc reloads with no controller call.
    fireFrameLoad();
    expect(listener.events, [
      'started null',
      'finished null',
      'started null',
      'finished null',
    ]);
  });

  test('renders HTML in a scripts-only sandbox', () async {
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    expect(view.iframe.getAttribute('sandbox'), 'allow-scripts');
    expect(view.iframe.hasAttribute('srcdoc'), isTrue);
    expect(listener.pagesStarted, [null]);
  });

  test('loads a URL without a sandbox after asking the listener', () async {
    final url = Uri.parse('https://app.example.com/home');
    await view.load(StratumWebViewSource.url(url));
    expect(view.iframe.src, url.toString());
    expect(view.iframe.hasAttribute('sandbox'), isFalse);
    expect(listener.navigationRequests, [url]);
    expect(listener.pagesStarted, [url]);
  });

  test('does not load or record a prevented URL', () async {
    listener.decision = StratumNavigationDecision.prevent;
    await view.load(
      StratumWebViewSource.url(Uri.parse('https://evil.example.net')),
    );
    expect(view.iframe.hasAttribute('src'), isFalse);
    expect(await view.canGoBack(), isFalse);
    expect(await view.currentUrl(), isNull);
  });

  test('removes scripts from the sandbox when JavaScript is off', () async {
    await view.setJavaScriptEnabled(false);
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    expect(view.iframe.getAttribute('sandbox'), '');
    await view.load(missingPage());
    expect(
      view.iframe.getAttribute('sandbox'),
      'allow-same-origin allow-forms allow-popups',
    );
  });

  test(
    'delivers a real message from the iframe with an allowed origin',
    () async {
      await loadBlobScript("parent.postMessage('hello','*');");
      attach();
      await waitForMessages(1);
      expect(listener.messages, [
        StratumWebViewMessage(data: 'hello', origin: appOrigin),
      ]);
    },
  );

  test('us03/fr05: each message reaches the listener with its sender, the '
      'origin for a URL page and the adopted render for HTML', () async {
    await loadBlobScript("parent.postMessage('hi','*');");
    attach();
    await waitForMessages(1);
    expect(
      listener.senders.single,
      isA<PlatformUrlPageSender>().having(
        (sender) => sender.origin,
        'origin',
        appOrigin,
      ),
    );
    await view.load(
      const StratumWebViewSource.html(
        "<script>StratumBridge.postMessage('ready');</script>",
      ),
    );
    await waitForMessages(2);
    expect(listener.senders.last, isA<PlatformHtmlDocumentSender>());
  });

  test('drops a real message from another window, not the frame', () async {
    await view.load(missingPage());
    attach();
    // A real, browser-authored message window posts to itself: its source
    // is the top window, never the frame.
    web.window.postMessage('from app window'.toJS, appOrigin.toString().toJS);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(listener.messages, isEmpty);
  });

  test(
    'drops a real frame message once its origin leaves the allowlist',
    () async {
      // `isAllowedOrigin` itself is covered by origin_policy_test.dart; this
      // only proves the wiring drops a real message whose real origin is not
      // in the listener's allowlist, in place of a harness-unreachable origin.
      // A raw listener is the positive control: it proves the frame's post
      // actually arrived at `window`, so the tracked listener's empty result
      // means the allowlist check ran and rejected it, not that nothing was
      // ever sent.
      listener.allowedOrigins = {};
      final arrived = Completer<void>();
      final raw = ((web.MessageEvent event) {
        final data = event.data;
        if (data != null &&
            data.isA<JSString>() &&
            (data as JSString).toDart == 'from frame' &&
            !arrived.isCompleted) {
          arrived.complete();
        }
      }).toJS;
      web.window.addEventListener('message', raw);
      addTearDown(() => web.window.removeEventListener('message', raw));
      await loadBlobScript("parent.postMessage('from frame','*');");
      attach();
      await arrived.future.timeout(const Duration(seconds: 5));
      expect(listener.messages, isEmpty);
    },
  );

  test('drops a real non-string message from the frame', () async {
    // A trailing string sentinel is the positive control: posts to one
    // target arrive in the order they were sent, so seeing `after` proves
    // the handler already judged (and dropped) `42` first, instead of the
    // frame never having posted at all within the wait.
    await loadBlobScript(
      "parent.postMessage(42,'*');parent.postMessage('after','*');",
    );
    attach();
    await waitForMessages(1);
    expect(listener.messages, [
      StratumWebViewMessage(data: 'after', origin: appOrigin),
    ]);
  });

  test('drops a real opaque-origin message while a URL is shown', () async {
    const html = '<script>parent.postMessage("opaque","*")</script>';
    final crossOrigin = Uri.parse(
      'data:text/html,${Uri.encodeComponent(html)}',
    );
    await view.load(StratumWebViewSource.url(crossOrigin));
    attach();
    await finishes(1);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(listener.messages, isEmpty);
  });

  test('us03/fr01/e13: a forged message event, with an allowed origin and '
      'the frame as source, is dropped', () async {
    await view.load(missingPage());
    attach();
    dispatchMessage('forged'.toJS, origin: appOrigin.toString());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(listener.messages, isEmpty);
  });

  test('us03/fr01/e13: a forged "null" handshake carrying the real nonce, '
      'with a real port, never adopts and never hijacks the bridge', () async {
    // An echo listener proves the genuine bridge still round-trips after
    // the forgery: a regression that closes the real port without adopting
    // the forged one (a bridge DoS) would fail this, not just the attacker
    // check below.
    await view.load(
      const StratumWebViewSource.html(
        '<script>\n'
        "window.addEventListener('message', function(e) {\n"
        "StratumBridge.postMessage('echo:' + e.data);\n"
        '});\n'
        "StratumBridge.postMessage('ready');\n"
        '</script>',
      ),
    );
    attach();
    await waitForMessages(1); // the real handshake's 'ready' message
    final srcdocValue = view.iframe.srcdoc;
    if (!srcdocValue.isA<JSString>()) fail('expected a string srcdoc');
    final srcdoc = (srcdocValue as JSString).toDart;
    final nonce = RegExp('stratum-bridge-handshake:([0-9a-f]{32})')
        .firstMatch(srcdoc)!
        .group(1)!;

    final evilChannel = web.MessageChannel();
    var attackerSawPost = false;
    evilChannel.port1.onmessage = ((web.MessageEvent event) {
      attackerSawPost = true;
    }).toJS;
    evilChannel.port1.start();
    web.window.dispatchEvent(
      web.MessageEvent(
        'message',
        web.MessageEventInit(
          data: 'stratum-bridge-handshake:$nonce'.toJS,
          origin: 'null',
          source: view.iframe.contentWindow,
          ports: [evilChannel.port2].toJS,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await view.postMessage('to-page');
    await waitForMessages(2);
    expect(listener.messages, [
      const StratumWebViewMessage(data: 'ready'),
      const StratumWebViewMessage(data: 'echo:to-page'),
    ]);
    expect(attackerSawPost, isFalse);
  });

  test('StratumBridge.postMessage from our HTML reaches the listener '
      'with origin null', () async {
    final received = Completer<StratumWebViewMessage>();
    listener.onMessageCallback = received.complete;
    await view.load(
      const StratumWebViewSource.html(
        "<script>StratumBridge.postMessage('hi');</script>",
      ),
    );
    attach();
    expect(
      await received.future.timeout(const Duration(seconds: 5)),
      const StratumWebViewMessage(data: 'hi'),
    );
  });

  test('drops a direct postMessage, keeps the bridge message', () async {
    final viaBridge = Completer<void>();
    listener.onMessageCallback = (message) {
      if (message.data == 'via-bridge' && !viaBridge.isCompleted) {
        viaBridge.complete();
      }
    };
    await view.load(
      const StratumWebViewSource.html(
        '<script>\n'
        "parent.postMessage('direct', '*');\n"
        "StratumBridge.postMessage('via-bridge');\n"
        '</script>',
      ),
    );
    attach();
    await viaBridge.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(listener.messages, [
      const StratumWebViewMessage(data: 'via-bridge'),
    ]);
  });

  test('round-trips a message through StratumBridge', () async {
    final ready = Completer<void>();
    final echoed = Completer<String>();
    listener.onMessageCallback = (message) {
      if (message.data == 'ready') {
        ready.complete();
      } else if (!echoed.isCompleted) {
        echoed.complete(message.data);
      }
    };
    await view.load(
      const StratumWebViewSource.html(
        '<script>\n'
        "window.addEventListener('message', function(e) {\n"
        "StratumBridge.postMessage('echo:' + e.data);\n"
        '});\n'
        "StratumBridge.postMessage('ready');\n"
        '</script>',
      ),
    );
    attach();
    await ready.future.timeout(const Duration(seconds: 5));
    await view.postMessage('ping');
    expect(
      await echoed.future.timeout(const Duration(seconds: 5)),
      'echo:ping',
    );
  });

  test('refuses to post before the handshake completes', () async {
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    attach();
    await expectLater(view.postMessage('ping'), throwsStateError);
  });

  test(
    'drops a forged handshake and a direct message after navigating away',
    () async {
      final ours = Completer<void>();
      listener.onMessageCallback = (message) {
        if (message.data == 'ours' && !ours.isCompleted) ours.complete();
      };
      // Positive control: prove the navigated-to page really ran and posted.
      // The view registered its listener first, so it has already judged the
      // 'evil' message (and the forged handshake before it) by the time this
      // raw listener sees it.
      final evilArrived = Completer<void>();
      final raw = ((web.MessageEvent event) {
        final data = event.data;
        if (data != null &&
            data.isA<JSString>() &&
            (data as JSString).toDart == 'evil' &&
            !evilArrived.isCompleted) {
          evilArrived.complete();
        }
      }).toJS;
      web.window.addEventListener('message', raw);
      addTearDown(() => web.window.removeEventListener('message', raw));
      await view.load(
        const StratumWebViewSource.html(r'''
<script>
StratumBridge.postMessage('ours');
location.href = 'data:text/html,' + encodeURIComponent(
  '<script>parent.postMessage("stratum-bridge-handshake:forged","*");' +
  'parent.postMessage("evil","*");<\/script>'
);
</script>
'''),
      );
      attach();
      await ours.future.timeout(const Duration(seconds: 5));
      await evilArrived.future.timeout(const Duration(seconds: 5));
      expect(listener.messages, [const StratumWebViewMessage(data: 'ours')]);
    },
  );

  test('re-inserting the view re-establishes the bridge', () async {
    final firstReady = Completer<void>();
    final secondReady = Completer<void>();
    final echoed = Completer<String>();
    listener.onMessageCallback = (message) {
      if (message.data == 'ready') {
        if (!firstReady.isCompleted) {
          firstReady.complete();
        } else if (!secondReady.isCompleted) {
          secondReady.complete();
        }
      } else if (!echoed.isCompleted) {
        echoed.complete(message.data);
      }
    };
    await view.load(
      const StratumWebViewSource.html(
        '<script>\n'
        "window.addEventListener('message', function(e) {\n"
        "StratumBridge.postMessage('echo:' + e.data);\n"
        '});\n'
        "StratumBridge.postMessage('ready');\n"
        '</script>',
      ),
    );
    attach();
    await firstReady.future.timeout(const Duration(seconds: 5));

    view.iframe.remove();
    final host = web.HTMLDivElement();
    web.document.body!.appendChild(host);
    // A tear-off of a JS interop member does not compile, so wrap it.
    // ignore: unnecessary_lambdas
    addTearDown(() => host.remove());
    view.attachTo(host);
    await secondReady.future.timeout(const Duration(seconds: 5));

    await view.postMessage('ping');
    expect(
      await echoed.future.timeout(const Duration(seconds: 5)),
      'echo:ping',
    );
  });

  test('us03/fr05/e06: a reply reaches the render whose port carried the '
      "message, and throws once a re-insertion's handshake replaced that "
      'port', () async {
    await view.load(
      const StratumWebViewSource.html(
        '<script>\n'
        "window.addEventListener('message', function(e) {\n"
        "StratumBridge.postMessage('echo:' + e.data);\n"
        '});\n'
        "StratumBridge.postMessage('ready');\n"
        '</script>',
      ),
    );
    attach();
    await waitForMessages(1);
    final first = listener.senders.last as PlatformHtmlDocumentSender;
    await view.replyToDocument(first, 'ping');
    await waitForMessages(2);
    expect(listener.messages.last.data, 'echo:ping');

    view.iframe.remove();
    final host = web.HTMLDivElement();
    web.document.body!.appendChild(host);
    // A tear-off of a JS interop member does not compile, so wrap it.
    // ignore: unnecessary_lambdas
    addTearDown(() => host.remove());
    view.attachTo(host);
    await waitForMessages(3);
    final second = listener.senders.last as PlatformHtmlDocumentSender;

    await expectLater(
      view.replyToDocument(first, 'late'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'The HTML document that sent the message is gone.',
        ),
      ),
    );
    await view.replyToDocument(second, 'pong');
    await waitForMessages(4);
    expect(listener.messages.last.data, 'echo:pong');
  });

  test(
    'us03/fr05/e06: a reply throws once a load leaves the HTML entry',
    () async {
      await view.load(
        const StratumWebViewSource.html(
          "<script>StratumBridge.postMessage('ready');</script>",
        ),
      );
      attach();
      await waitForMessages(1);
      final first = listener.senders.last as PlatformHtmlDocumentSender;
      await view.load(missingPage());
      await expectLater(
        view.replyToDocument(first, 'x'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The HTML document that sent the message is gone.',
          ),
        ),
      );
    },
  );

  test('us03/fr05/e07: after a link away inside the frame, a reply '
      'resolves and nothing arrives', () async {
    await view.load(
      const StratumWebViewSource.html(
        '<script>\n'
        "window.addEventListener('message', function(e) {\n"
        "if (e.data === 'go') {\n"
        "location.href = 'data:text/html,<p>away</p>';\n"
        '} else {\n'
        "StratumBridge.postMessage('echo:' + e.data);\n"
        '}\n'
        '});\n'
        "StratumBridge.postMessage('ready');\n"
        '</script>',
      ),
    );
    attach();
    await waitForMessages(1);
    final sender = listener.senders.last as PlatformHtmlDocumentSender;
    await view.replyToDocument(sender, 'go');
    await finishes(2);
    await view.replyToDocument(sender, 'late');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      listener.messages.any((message) => message.data == 'echo:late'),
      isFalse,
    );
  });

  test('posts to the current URL origin and refuses others', () async {
    await view.load(missingPage());
    attach();
    await view.postMessage('ping');
    listener.allowedOrigins = {Uri.parse('https://other.example.net')};
    await expectLater(view.postMessage('ping'), throwsStateError);
  });

  test('refuses to post before any content loads', () async {
    attach();
    await expectLater(view.postMessage('ping'), throwsStateError);
  });

  test('refusal error names the origin, not the full URL', () async {
    final url = appOrigin.replace(path: '/secret', query: 'x=1');
    await view.load(StratumWebViewSource.url(url));
    attach();
    listener.allowedOrigins = {};
    await expectLater(
      view.postMessage('ping'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '${originOf(url)} is not an allowed message destination.',
        ),
      ),
    );
  });

  test('navigates the controller history', () async {
    await view.load(StratumWebViewSource.url(appOrigin.replace(path: '/one')));
    await view.load(const StratumWebViewSource.html('<p>Two</p>'));
    expect(await view.canGoBack(), isTrue);
    await view.goBack();
    expect(view.iframe.hasAttribute('srcdoc'), isFalse);
    expect(view.iframe.src, endsWith('/one'));
    expect(await view.canGoForward(), isTrue);
    await view.goForward();
    expect(view.iframe.hasAttribute('srcdoc'), isTrue);
  });

  test('stops delivering messages after dispose', () async {
    // Builds a sender in the frame's own realm, after dispose, so a real
    // message can still be posted while the view's own listener is gone:
    // a positive control proves it arrives at `window` even though the
    // disposed view never records it.
    await view.load(missingPage());
    attach();
    await finishes(1);
    view.dispose();
    await waitForFrameBlank();

    final arrived = Completer<void>();
    final raw = ((web.MessageEvent event) {
      final data = event.data;
      if (data != null &&
          data.isA<JSString>() &&
          (data as JSString).toDart == 'late' &&
          !arrived.isCompleted) {
        arrived.complete();
      }
    }).toJS;
    web.window.addEventListener('message', raw);
    addTearDown(() => web.window.removeEventListener('message', raw));

    final frameWindow = view.iframe.contentWindow! as JSObject;
    final sender = (frameWindow['Function']! as JSFunction)
        .callAsConstructor<JSFunction>("parent.postMessage('late','*')".toJS);
    frameWindow.callMethod<JSAny?>('setTimeout'.toJS, sender, 0.toJS);

    await arrived.future.timeout(const Duration(seconds: 5));
    expect(listener.messages, isEmpty);
  });

  test('attachTo puts the iframe, filling it, into the host element', () {
    final host = web.HTMLDivElement();
    view.attachTo(host);
    expect(view.iframe.parentElement, host);
    expect(host.style.width, '100%');
    expect(host.style.height, '100%');
  });

  test(
    'currentUrl reports the requested URL before the frame commits',
    () async {
      final url = appOrigin.replace(path: '/missing');
      await view.load(StratumWebViewSource.url(url));
      attach();
      expect(await view.currentUrl(), url);
    },
  );

  test('us04/fr01/e02: currentUrl reports the requested URL until the '
      "frame's load for it, even while the frame shows the page it leaves, "
      "then the frame's location", () async {
    final first = appOrigin.replace(path: '/missing');
    final second = appOrigin.replace(path: '/missing', query: 'next=1');
    await view.load(StratumWebViewSource.url(first));
    attach();
    await finishes(1);
    expect(await view.currentUrl(), first);
    await view.load(StratumWebViewSource.url(second));
    expect(await view.currentUrl(), second);
    await finishes(2);
    expect(await view.currentUrl(), second);
  });

  test('us04/fr01/e02: currentUrl reports the entry URL while a '
      "re-inserted view restarts that entry's navigation, not the "
      "restarted navigation's transient about:blank", () async {
    final url = appOrigin.replace(path: '/missing');
    await view.load(StratumWebViewSource.url(url));
    attach();
    await finishes(1);
    expect(await view.currentUrl(), url);

    view.iframe.remove();
    final host = web.HTMLDivElement();
    web.document.body!.appendChild(host);
    // A tear-off of a JS interop member does not compile, so wrap it.
    // ignore: unnecessary_lambdas
    addTearDown(() => host.remove());
    view.attachTo(host);
    expect(await view.currentUrl(), url);
    await finishes(2);
    expect(await view.currentUrl(), url);
  });

  test('us04/fr01/e03: once the frame is genuinely cross-origin, currentUrl '
      'returns the last URL the controller loaded, read from the catch '
      'branch its cross-origin location throws into', () async {
    // A `data:` navigation (not `srcdoc`) gives the frame its own opaque
    // origin, distinct from this test page's origin: reading its
    // location then throws a SecurityError, the same as a real
    // cross-origin site would (US-04 FR-01 E03).
    final crossOrigin = Uri.parse('data:text/html,%3Cp%3EHi%3C%2Fp%3E');
    await view.load(StratumWebViewSource.url(crossOrigin));
    attach();
    await finishes(1);
    expect(await view.currentUrl(), crossOrigin);
  });

  test("sec-m3 F1: a same-origin outgoing page's late load, arriving after "
      "a newer entry's own load began, is ignored: currentUrl keeps "
      'reporting the entry the controller requested', () async {
    final a = appOrigin.replace(path: '/missing');
    final b = appOrigin.replace(path: '/missing', query: 'next=1');
    await view.load(StratumWebViewSource.url(a));
    attach();
    await finishes(1);
    expect(await view.currentUrl(), a);

    await view.load(StratumWebViewSource.url(b));
    // A's own in-flight load fires only now, after b's navigation began:
    // the frame has not yet committed b, so its document is still a's.
    fireFrameLoad();
    expect(listener.pagesFinished, [a]);
    expect(await view.currentUrl(), b);
  });

  test('us03/fr01/e05: an outgoing URL page message arrives with its own '
      'origin after the view moved on, to HTML or to another URL', () async {
    // Each real page posts its own message from `beforeunload`, its last
    // script run while still the page the frame shows: a real reproduction
    // of an outgoing page's late message, in place of forging the event.
    // `pagehide` and `unload` never deliver a `postMessage` sent from this
    // frame's own navigation in this harness; `beforeunload` does.
    await loadBlobScript(
      "window.addEventListener('beforeunload',function(){"
      "parent.postMessage('to html','*');});",
    );
    attach();
    // Each page's `beforeunload` listener must already be registered
    // before the next navigation leaves it, so wait for that page's load.
    await finishes(1);
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    await finishes(2);
    await loadBlobScript(
      "window.addEventListener('beforeunload',function(){"
      "parent.postMessage('to url','*');});",
    );
    await finishes(3);
    await view.load(
      StratumWebViewSource.url(appOrigin.replace(path: '/second')),
    );
    await waitForMessages(2);
    expect(listener.messages, [
      StratumWebViewMessage(data: 'to html', origin: appOrigin),
      StratumWebViewMessage(data: 'to url', origin: appOrigin),
    ]);
  });

  test('a load started just before dispose leaves the frame blank', () async {
    final pending = view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    view.dispose();
    await pending;
    expect(view.iframe.hasAttribute('srcdoc'), isFalse);
    expect(view.iframe.src, 'about:blank');
    expect(listener.pagesStarted, isEmpty);
  });

  test('history navigation started just before dispose leaves the frame '
      'blank', () async {
    await view.load(missingPage());
    await view.load(const StratumWebViewSource.html('<p>Two</p>'));
    listener.pagesStarted.clear();
    final pending = view.goBack();
    view.dispose();
    await pending;
    expect(view.iframe.src, 'about:blank');
    expect(listener.pagesStarted, isEmpty);
  });

  test('us03/fr02/e17: a named send throws before any post when the '
      'current entry has another origin', () async {
    await view.load(missingPage());
    attach();
    listener.allowedOrigins = {appOrigin, partner};
    await expectLater(
      view.postMessage('ping', targetOrigin: partner),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'The current page is not the named message destination.',
        ),
      ),
    );
  });

  test('us03/fr02/e14, us03/fr02/e18: a named send matches the current '
      'entry by origin, so another page of that origin receives it', () async {
    await view.load(missingPage());
    attach();
    await view.postMessage(
      'ping',
      targetOrigin: appOrigin.replace(
        host: appOrigin.host.toUpperCase(),
        path: '/other',
        query: 'q=1',
        fragment: 'f',
      ),
    );
  });

  test("us03/fr02/e16: a named send to the app's HTML throws, while an "
      'unnamed one still reaches it', () async {
    final ready = Completer<void>();
    listener.onMessageCallback = (message) {
      if (message.data == 'ready' && !ready.isCompleted) ready.complete();
    };
    await view.load(
      const StratumWebViewSource.html(
        "<script>window.addEventListener('message',function(e){"
        "StratumBridge.postMessage('echo:'+e.data);});"
        "StratumBridge.postMessage('ready');</script>",
      ),
    );
    attach();
    await ready.future.timeout(const Duration(seconds: 5));
    await expectLater(
      view.postMessage('ping', targetOrigin: appOrigin),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          "The app's HTML has no origin to match targetOrigin.",
        ),
      ),
    );
    final echoed = Completer<String>();
    listener.onMessageCallback = (message) {
      if (!echoed.isCompleted) echoed.complete(message.data);
    };
    await view.postMessage('pong');
    expect(
      await echoed.future.timeout(const Duration(seconds: 5)),
      'echo:pong',
    );
  });

  test('us03/s8, us03/fr02/e17: after the view moves to a page of another '
      'allowed origin, a send naming the first origin throws', () async {
    listener.allowedOrigins = {appOrigin, partner};
    await view.load(missingPage());
    attach();
    await finishes(1);
    await view.load(StratumWebViewSource.url(partner));
    await expectLater(
      view.postMessage('late', targetOrigin: appOrigin),
      throwsStateError,
    );
  });

  test(
    'sends to the loaded page origin only, never a wildcard target',
    () async {
      await view.load(missingPage());
      attach();
      final frameWindow = view.iframe.contentWindow!;
      final targets = <String>[];
      void spy(JSAny? data, JSAny? targetOrigin) {
        targets.add((targetOrigin! as JSString).toDart);
      }

      (frameWindow as JSObject)['postMessage'] = spy.toJS;
      await view.postMessage('ping');
      expect(targets, [appOrigin.toString()]);
    },
  );

  testWidgets(
    'a setState-in-onPageStarted loading indicator never rebuilds during '
    'build',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        _LoadingHarness(source: StratumWebViewSource.url(appOrigin)),
      );
      await tester.pump();
      await tester.pumpWidget(
        _LoadingHarness(
          source: StratumWebViewSource.url(appOrigin.replace(path: '/two')),
        ),
      );
      await tester.pump();

      expect(errors, isEmpty);
    },
  );
}

/// Rebuilds on every `onPageStarted` call, the way a loading indicator does.
class _LoadingHarness extends StatefulWidget {
  const new({required this.source});

  final StratumWebViewSource source;

  @override
  State<_LoadingHarness> createState() => _LoadingHarnessState();
}

class _LoadingHarnessState extends State<_LoadingHarness> {
  @override
  Widget build(BuildContext context) => StratumWebView(
    source: widget.source,
    onPageStarted: (_) => setState(() {}),
  );
}
