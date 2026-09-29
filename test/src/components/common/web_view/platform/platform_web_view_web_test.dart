@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_web.dart';
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

  Future<void> nextLoad() {
    final completer = Completer<void>();
    late final JSFunction handler;
    handler = ((web.Event _) {
      view.iframe.removeEventListener('load', handler);
      completer.complete();
    }).toJS;
    view.iframe.addEventListener('load', handler);
    return completer.future.timeout(const Duration(seconds: 5));
  }

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

  test('trusts its own HTML until the frame navigates away', () async {
    final loaded = nextLoad();
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    attach();
    await loaded;
    dispatchMessage('from html'.toJS, origin: 'null');
    view.iframe.dispatchEvent(web.Event('load'));
    dispatchMessage('after navigation'.toJS, origin: 'null');
    expect(listener.messages, [const StratumWebViewMessage(data: 'from html')]);
    await expectLater(view.postMessage('ping'), throwsStateError);
  });

  test('receives a real postMessage from sandboxed HTML', () async {
    final received = Completer<StratumWebViewMessage>();
    listener.onMessageCallback = received.complete;
    await view.load(
      const StratumWebViewSource.html(
        '<script>parent.postMessage("ready", "*");</script>',
      ),
    );
    attach();
    expect(
      await received.future.timeout(const Duration(seconds: 5)),
      const StratumWebViewMessage(data: 'ready'),
    );
  });

  test('re-inserting the view re-arms the HTML bridge', () async {
    final loaded = nextLoad();
    await view.load(const StratumWebViewSource.html('<p>Hi</p>'));
    attach();
    await loaded;
    view.iframe.dispatchEvent(web.Event('load'));
    view.createView();
    dispatchMessage('after re-insert'.toJS, origin: 'null');
    expect(listener.messages, [
      const StratumWebViewMessage(data: 'after re-insert'),
    ]);
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
}
