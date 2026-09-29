@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_web.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';
import 'package:web/web.dart' as web;

import '../fakes/recording_listener.dart';

void main() {
  final appOrigin = Uri.parse(web.window.location.origin);
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

  test('delivers a message from the iframe with an allowed origin', () async {
    await view.load(missingPage());
    attach();
    dispatchMessage('hello'.toJS, origin: appOrigin.toString());
    expect(listener.messages, [
      StratumWebViewMessage(data: 'hello', origin: appOrigin),
    ]);
  });

  test(
    'drops messages from other windows, other origins, and non-strings',
    () async {
      await view.load(missingPage());
      attach();
      dispatchMessage(
        'from app window'.toJS,
        origin: appOrigin.toString(),
        source: web.window,
      );
      dispatchMessage('from evil'.toJS, origin: 'https://evil.example.net');
      dispatchMessage(42.toJS, origin: appOrigin.toString());
      expect(listener.messages, isEmpty);
    },
  );

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

  test('drops a direct postMessage and a synthetic null message, '
      'keeps the bridge message', () async {
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
    dispatchMessage('spoofed'.toJS, origin: 'null');
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
      await Future<void>.delayed(const Duration(seconds: 1));
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
    web.document.body!.appendChild(view.createView());
    await secondReady.future.timeout(const Duration(seconds: 5));

    await view.postMessage('ping');
    expect(
      await echoed.future.timeout(const Duration(seconds: 5)),
      'echo:ping',
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
    await view.load(missingPage());
    attach();
    final frameWindow = view.iframe.contentWindow;
    view.dispose();
    dispatchMessage(
      'late'.toJS,
      origin: appOrigin.toString(),
      source: frameWindow,
    );
    expect(listener.messages, isEmpty);
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
