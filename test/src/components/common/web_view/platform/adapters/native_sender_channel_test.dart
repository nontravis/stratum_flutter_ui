import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/adapters/native_sender_channel.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../fakes/fake_webview_flutter_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stratum_ui/web_view_bridge');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Object? attachAnswer;
  late Future<Object?> Function() proxyAnswer;
  late MethodChannelNativeSenderChannel senders;
  late wf.WebViewController controller;

  setUp(() {
    calls = [];
    attachAnswer = true;
    proxyAnswer = () async => true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'attach' => attachAnswer,
        'runThroughReplyProxy' => proxyAnswer(),
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    WebViewPlatform.instance = FakeWebViewFlutterPlatform();
    controller = wf.WebViewController();
    senders = MethodChannelNativeSenderChannel(webViewId: (_) => 7);
  });

  /// Sends a `message` call from the platform side.
  Future<void> platformSends(Object? arguments) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('message', arguments)),
        (_) {},
      );

  test('Q6: attach sends the web view id and returns the platform '
      'answer', () async {
    expect(await senders.attach(controller, (_, _) {}), isTrue);
    attachAnswer = false;
    expect(await senders.attach(controller, (_, _) {}), isFalse);
    attachAnswer = null;
    expect(await senders.attach(controller, (_, _) {}), isFalse);
    expect(calls.first.method, 'attach');
    expect(calls.first.arguments, {'webViewId': 7});
  });

  test('Q6: a message reaches the listener of its web view with the sender '
      'the platform names', () async {
    final received = <(String, BridgeMessageSender)>[];
    await senders.attach(controller, (data, sender) {
      received.add((data, sender));
    });
    await platformSends({
      'webViewId': 7,
      'data': 'ready',
      'origin': 'http://127.0.0.1:8080',
      'isMainFrame': true,
    });
    await platformSends({
      'webViewId': 8,
      'data': 'other view',
      'origin': 'http://127.0.0.1:8080',
      'isMainFrame': true,
    });
    await platformSends({
      'webViewId': 7,
      'data': 'opaque',
      'origin': null,
      'isMainFrame': false,
    });
    expect(received.map((entry) => entry.$1), ['ready', 'opaque']);
    expect(received.first.$2.origin, Uri.parse('http://127.0.0.1:8080'));
    expect(received.first.$2.isMainFrame, isTrue);
    expect(received.last.$2.origin, isNull);
    expect(received.last.$2.isMainFrame, isFalse);
  });

  test('Q6: an opaque sender crosses as a null origin, in the "null" form '
      'Android serializes and the null form of iOS and macOS', () async {
    final named = <BridgeMessageSender>[];
    await senders.attach(controller, (_, sender) => named.add(sender));
    for (final origin in ['null', null]) {
      await platformSends({
        'webViewId': 7,
        'data': 'x',
        'origin': origin,
        'isMainFrame': true,
      });
    }
    expect(named.map((sender) => sender.origin), [null, null]);
  });

  test('co01_02/us03/fr04/e15: a message carries the reply proxy Android names for '
      'its sender, and iOS and macOS name none', () async {
    final named = <BridgeMessageSender>[];
    await senders.attach(controller, (_, sender) => named.add(sender));
    await platformSends({
      'webViewId': 7,
      'data': 'x',
      'origin': null,
      'isMainFrame': true,
      'replyProxy': 4,
    });
    await platformSends({
      'webViewId': 7,
      'data': 'y',
      'origin': null,
      'isMainFrame': true,
    });
    expect(named.map((sender) => sender.replyProxy), [
      const BridgeReplyProxy(4),
      null,
    ]);
  });

  test('co01_02/us03/fr02/e13: runThroughReplyProxy sends the web view id, the '
      'reply proxy, and the script, and returns whether the script returned '
      'true', () async {
    expect(
      await senders.runThroughReplyProxy(
        controller,
        const BridgeReplyProxy(4),
        'script',
      ),
      isTrue,
    );
    expect(calls.last.method, 'runThroughReplyProxy');
    expect(calls.last.arguments, {
      'webViewId': 7,
      'replyProxy': 4,
      'script': 'script',
    });
    for (final answer in <Object?>[false, null]) {
      proxyAnswer = () async => answer;
      expect(
        await senders.runThroughReplyProxy(
          controller,
          const BridgeReplyProxy(4),
          'script',
        ),
        isFalse,
        reason: '$answer',
      );
    }
  });

  test(
    'co01_02/us03/fr02/e13: a FRAME_DESTROYED or other platform error of the '
    'reply proxy reaches the caller as a PlatformException',
    () async {
      proxyAnswer = () =>
          Future.error(PlatformException(code: 'frame-destroyed', message: ''));
      await expectLater(
        senders.runThroughReplyProxy(
          controller,
          const BridgeReplyProxy(4),
          'script',
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'frame-destroyed',
          ),
        ),
      );
    },
  );

  test('Q6: a message call with a missing or mistyped argument is '
      'dropped', () async {
    final received = <String>[];
    await senders.attach(controller, (data, _) => received.add(data));
    for (final arguments in <Object?>[
      null,
      'not a map',
      {'data': 'x', 'origin': null, 'isMainFrame': true},
      {'webViewId': '7', 'data': 'x', 'origin': null, 'isMainFrame': true},
      {'webViewId': 7, 'data': 1, 'origin': null, 'isMainFrame': true},
      {'webViewId': 7, 'data': 'x', 'origin': 1, 'isMainFrame': true},
      {'webViewId': 7, 'data': 'x', 'origin': null, 'isMainFrame': 'yes'},
      {
        'webViewId': 7,
        'data': 'x',
        'origin': null,
        'isMainFrame': true,
        'replyProxy': '4',
      },
    ]) {
      await platformSends(arguments);
    }
    expect(received, isEmpty);
  });

  test('Q6: detach stops delivery and tells the platform', () async {
    final received = <String>[];
    await senders.attach(controller, (data, _) => received.add(data));
    await senders.detach(controller);
    await platformSends({
      'webViewId': 7,
      'data': 'late',
      'origin': null,
      'isMainFrame': true,
    });
    expect(received, isEmpty);
    expect(calls.last.method, 'detach');
    expect(calls.last.arguments, {'webViewId': 7});
  });

  test('Q6: only an Android or WebKit controller has a platform web view '
      'id', () {
    expect(
      () => MethodChannelNativeSenderChannel.platformWebViewId(controller),
      throwsUnsupportedError,
    );
  });
}
