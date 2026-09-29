import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

import '../../fakes/recording_listener.dart';

/// Drives one native adapter through its fake platform.
abstract interface class NativeAdapterHarness {
  PlatformStratumWebView createAdapter(PlatformStratumWebViewListener listener);
  List<Uri> get loadedUrls;
  List<String> get loadedHtml;
  List<String> get scripts;
  List<bool> get javaScriptEnabledStates;
  Set<String> get channelNames;
  int get reloadCount;
  void setCurrentUrl(String? url);
  void startPage(String url);
  void finishPage(String url);
  void changeUrl(String? url);
  void sendBridgeMessage(String message);
  Future<bool> requestNavigation(String url, {required bool isMainFrame});
  void failResource({
    required int code,
    required String description,
    required bool? isForMainFrame,
    required String? url,
  });
  void failHttp({required int statusCode, required Uri requestUrl});
}

/// Runs the behavior every native adapter must share.
void runNativeAdapterContract(
  String description,
  NativeAdapterHarness Function() createHarness,
) {
  group(description, () {
    final appOrigin = Uri.parse('https://app.example.com');
    final appPage = Uri.parse('https://app.example.com/home');
    late NativeAdapterHarness harness;
    late RecordingListener listener;
    late PlatformStratumWebView adapter;

    setUp(() async {
      harness = createHarness();
      listener = RecordingListener(allowedOrigins: {appOrigin});
      adapter = harness.createAdapter(listener);
      await pumpEventQueue();
    });

    test('enables JavaScript and registers the bridge channel', () {
      expect(harness.javaScriptEnabledStates, [true]);
      expect(harness.channelNames, contains('StratumBridge'));
    });

    test('loads URL and HTML sources', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      expect(harness.loadedUrls, [appPage]);
      expect(harness.loadedHtml, ['<p>Hi</p>']);
    });

    test('accepts a message from an allowed page', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..sendBridgeMessage('hello');
      expect(listener.messages, [
        StratumWebViewMessage(data: 'hello', origin: appOrigin),
      ]);
    });

    test('drops a message from a page outside the allowlist', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage('https://evil.example.net/')
        ..sendBridgeMessage('hello');
      expect(listener.messages, isEmpty);
    });

    test('follows URL changes reported without a page load', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness
        ..startPage(appPage.toString())
        ..changeUrl('https://evil.example.net/')
        ..sendBridgeMessage('hello');
      expect(listener.messages, isEmpty);
    });

    test('trusts loaded HTML until the page navigates away', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      harness
        ..startPage('about:blank')
        ..sendBridgeMessage('from html')
        ..startPage('https://evil.example.net/')
        ..sendBridgeMessage('spoofed');
      expect(listener.messages, [
        const StratumWebViewMessage(data: 'from html'),
      ]);
    });

    test('reloading HTML keeps the bridge open', () async {
      await adapter.load(const StratumWebViewSource.html('<p>Hi</p>'));
      harness.startPage('about:blank');
      await adapter.reload();
      harness
        ..startPage('about:blank')
        ..sendBridgeMessage('after reload');
      expect(harness.reloadCount, 1);
      expect(listener.messages, [
        const StratumWebViewMessage(data: 'after reload'),
      ]);
    });

    test('posts a message to an allowed page', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage(appPage.toString());
      await adapter.postMessage('ping');
      expect(harness.scripts, [buildMessageDispatchScript('ping')]);
    });

    test('refuses to post to a page outside the allowlist', () async {
      await adapter.load(StratumWebViewSource.url(appPage));
      harness.startPage('https://evil.example.net/');
      await expectLater(adapter.postMessage('ping'), throwsStateError);
      expect(harness.scripts, isEmpty);
    });

    test('refuses to post before any page starts', () async {
      await expectLater(adapter.postMessage('ping'), throwsStateError);
    });

    test('asks the listener about main-frame navigation', () async {
      listener.decision = StratumNavigationDecision.prevent;
      final allowed = await harness.requestNavigation(
        'https://evil.example.net/',
        isMainFrame: true,
      );
      expect(allowed, isFalse);
      expect(listener.navigationRequests, [
        Uri.parse('https://evil.example.net/'),
      ]);
    });

    test('lets sub-frame and about: navigation through', () async {
      listener.decision = StratumNavigationDecision.prevent;
      expect(
        await harness.requestNavigation(
          'https://ads.example.net/',
          isMainFrame: false,
        ),
        isTrue,
      );
      expect(
        await harness.requestNavigation('about:blank', isMainFrame: true),
        isTrue,
      );
      expect(listener.navigationRequests, isEmpty);
    });

    test('reports page start and finish', () {
      harness
        ..startPage(appPage.toString())
        ..finishPage(appPage.toString());
      expect(listener.pagesStarted, [appPage]);
      expect(listener.pagesFinished, [appPage]);
    });

    test('forwards main-frame network errors only', () {
      harness
        ..failResource(
          code: -2,
          description: 'ads offline',
          isForMainFrame: false,
          url: 'https://ads.example.net/',
        )
        ..failResource(
          code: -2,
          description: 'offline',
          isForMainFrame: true,
          url: appPage.toString(),
        );
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.network,
          description: 'offline',
          code: -2,
          url: appPage,
        ),
      ]);
    });

    test('forwards HTTP errors for the current page only', () {
      harness
        ..startPage(appPage.toString())
        ..failHttp(
          statusCode: 404,
          requestUrl: Uri.parse('https://app.example.com/logo.png'),
        )
        ..failHttp(statusCode: 500, requestUrl: appPage);
      expect(listener.errors, [
        StratumWebViewError(
          type: StratumWebViewErrorType.http,
          description: 'HTTP error 500',
          code: 500,
          url: appPage,
        ),
      ]);
    });

    test('toggles JavaScript', () async {
      await adapter.setJavaScriptEnabled(false);
      expect(harness.javaScriptEnabledStates.last, isFalse);
    });

    test('parses the current URL', () async {
      harness.setCurrentUrl('https://app.example.com/now');
      expect(
        await adapter.currentUrl(),
        Uri.parse('https://app.example.com/now'),
      );
      harness.setCurrentUrl(null);
      expect(await adapter.currentUrl(), isNull);
    });

    test('dispose loads about:blank, for parity with web', () async {
      adapter.dispose();
      await pumpEventQueue();
      expect(harness.loadedUrls, [Uri.parse('about:blank')]);
    });
  });
}
